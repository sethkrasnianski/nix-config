"""Context lifecycle tests. Opt in to real Nix evaluation with NIX_CONFIG_INTEGRATION=1."""

import contextlib
import importlib.util
import io
import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("config_cli", ROOT / "scripts/config.py")
assert SPEC is not None and SPEC.loader is not None
cli = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cli)


class ContextTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name).resolve()
        self.env = patch.dict(
            os.environ,
            {
                "HOME": str(self.home),
                "XDG_CONFIG_HOME": str(self.home / ".config"),
                "XDG_STATE_HOME": str(self.home / ".local/state"),
                "XDG_DATA_HOME": str(self.home / ".local/share"),
                "NIX_CONFIG_MANIFEST": str(self.home / "applied.json"),
                "NIX_CONFIG_TEMPLATE": str(ROOT / "contexts/template"),
            },
        )
        self.env.start()
        self.addCleanup(self.env.stop)
        self.config = cli.Config(repo=ROOT, home=self.home)
        self.output = contextlib.redirect_stdout(io.StringIO())
        self.output.__enter__()
        self.addCleanup(self.output.__exit__, None, None, None)

    def create(self, directory="Work"):
        path = self.home / directory / "config"
        self.config.new(path)
        return path

    def test_scaffold_is_separate_staged_and_registered(self):
        path = self.create()
        self.assertEqual(
            self.config.registrations(),
            [{"name": "work", "path": str(path), "directory": "Work"}],
        )
        tracked = subprocess.check_output(["git", "-C", path, "ls-files"], text=True)
        self.assertIn("flake.nix", tracked)
        self.assertIn("home.nix", tracked)
        self.assertIn('context.name = "work"', (path / "flake.nix").read_text())
        self.assertNotIn("@DIRECTORY@", (path / "home.nix").read_text())

    def test_missing_registration_stops_before_any_nix_command(self):
        path = self.create()
        (path / "flake.nix").unlink()
        with patch.object(cli, "run") as command:
            with self.assertRaisesRegex(cli.ConfigError, "Missing context"):
                self.config.compose("nixos")
            command.assert_not_called()
        self.config.remove(path)
        self.assertEqual(self.config.registrations(), [])

    def test_refuses_to_overwrite_existing_files(self):
        path = self.home / "Work/config"
        path.mkdir(parents=True)
        (path / "notes").write_text("keep me")
        with self.assertRaisesRegex(cli.ConfigError, "must be empty"):
            self.config.new(path)
        self.assertEqual((path / "notes").read_text(), "keep me")

    def test_registration_is_idempotent(self):
        path = self.create()
        self.config.add(path)
        self.assertEqual(len(self.config.registrations()), 1)

    def test_spaces_and_nested_scopes(self):
        self.create("Work Space/Client")
        item = self.config.registrations()[0]
        self.assertEqual(item["name"], "work-space-client")
        self.assertEqual(item["directory"], "Work Space/Client")

    def test_rejects_outside_home_and_home_scope(self):
        for path in ("/outside/config", self.home / "config"):
            with self.assertRaises(cli.ConfigError):
                self.config.context(path)

    def test_invalid_registry_does_not_get_overwritten(self):
        self.config.registry.parent.mkdir(parents=True)
        self.config.registry.write_text("not json")
        with self.assertRaisesRegex(cli.ConfigError, "Cannot read"):
            self.config.registrations()
        self.assertEqual(self.config.registry.read_text(), "not json")

    def test_moved_repository_can_be_unregistered_after_symlink_replacement(self):
        path = self.create()
        replacement = self.home / "moved-context"
        path.rename(replacement)
        path.symlink_to(replacement, target_is_directory=True)
        self.config.remove(path)
        self.assertEqual(self.config.registrations(), [])

    def test_duplicate_directory_is_rejected(self):
        self.create()
        second = self.home / "Work/other-config"
        second.mkdir()
        (second / "flake.nix").write_text("{}")
        subprocess.run(["git", "-C", second, "init", "-q"], check=True)
        subprocess.run(["git", "-C", second, "add", "."], check=True)
        with self.assertRaisesRegex(cli.ConfigError, "already registered"):
            self.config.add(second)

    def test_target_tracks_active_host_variant(self):
        cli.write_json(self.config.applied, {"target": "nixos-headless"})
        self.assertEqual(self.config.target(), "nixos-headless")
        self.assertEqual(self.config.target("nixos"), "nixos")

    def test_removal_is_reported_until_activation(self):
        path = self.create()
        cli.write_json(self.config.applied, {"contexts": self.config.registrations()})
        self.config.remove(path)
        stream = io.StringIO()
        with contextlib.redirect_stdout(stream):
            self.config.status(contexts_only=True)
        self.assertIn("removal pending", stream.getvalue())

    def test_check_never_activates(self):
        with (
            patch.object(self.config, "compose", return_value=self.home),
            patch.object(cli, "run") as command,
        ):
            self.config.build("nixos-headless")
        self.assertEqual(command.call_count, 1)
        self.assertEqual(command.call_args.args[0][:2], ["nix", "build"])
        self.assertIn("--no-update-lock-file", command.call_args.args[0])

    def test_failed_build_never_runs_sudo(self):
        with (
            patch.object(self.config, "compose", return_value=self.home),
            patch.object(cli.platform, "system", return_value="Linux"),
            patch.object(cli.shutil, "which", return_value="/tools/nixos-rebuild"),
            patch.object(
                cli, "run", side_effect=cli.ConfigError("build failed")
            ) as command,
            self.assertRaises(cli.ConfigError),
        ):
            self.config.build("nixos", activate=True)
        self.assertEqual(command.call_count, 1)

    def test_failed_shell_build_never_activates(self):
        cli.write_json(
            self.home / "manifest.json",
            {"contexts": [{"hasShell": True, "name": "work"}]},
        )
        with (
            patch.object(self.config, "compose", return_value=self.home),
            patch.object(cli.platform, "system", return_value="Linux"),
            patch.object(cli.shutil, "which", return_value="/tools/nixos-rebuild"),
            patch.object(
                cli, "run", side_effect=[None, cli.ConfigError("shell failed")]
            ) as command,
            self.assertRaises(cli.ConfigError),
        ):
            self.config.build("nixos", activate=True)
        self.assertEqual(command.call_count, 2)
        self.assertTrue(
            all(call.args[0][0] == "nix" for call in command.call_args_list)
        )

    def test_rebuild_uses_correct_backend_and_locked_snapshot(self):
        for target, system, backend in (
            ("nixos-headless", "Linux", "nixos-rebuild"),
            ("macbook", "Darwin", "darwin-rebuild"),
        ):
            with (
                self.subTest(target=target),
                patch.object(self.config, "compose", return_value=self.home),
                patch.object(cli.platform, "system", return_value=system),
                patch.object(cli.shutil, "which", return_value=f"/tools/{backend}"),
                patch.object(cli, "run") as command,
            ):
                self.config.build(target, activate=True)
                activation = command.call_args.args[0]
                self.assertEqual(
                    activation[:3], ["sudo", f"/tools/{backend}", "switch"]
                )
                self.assertIn(f"path:{self.home / 'flake'}#{target}", activation)
                self.assertIn("--no-update-lock-file", activation)

    @unittest.skipUnless(
        os.environ.get("NIX_CONFIG_INTEGRATION") == "1", "real Nix evaluation is opt-in"
    )
    def test_real_locked_composition_with_local_override_and_spaces(self):
        self.create("Work Space")
        self.config.local.write_text(
            '{ ... }: { local.opencode.build.model = "github-copilot/context-test"; }'
        )
        snapshot = self.config.build("nixos-headless", evaluate=True)
        manifest = json.loads((snapshot / "manifest.json").read_text())
        self.assertEqual(manifest["contexts"][0]["name"], "work-space")
        self.assertTrue(manifest["contexts"][0]["hasShell"])
        self.assertIsNotNone(manifest["localConfigHash"])
        reference = f"path:{snapshot / 'flake'}#nixosConfigurations.nixos-headless.config.local.opencode.build.model"
        model = subprocess.check_output(
            ["nix", "eval", "--raw", "--no-update-lock-file", reference], text=True
        )
        self.assertEqual(model, "github-copilot/context-test")
        subprocess.run(
            [
                "nix",
                "eval",
                "--raw",
                "--no-update-lock-file",
                f"path:{snapshot / 'flake'}#devShells.x86_64-linux.context-work-space.drvPath",
            ],
            check=True,
        )
        self.assertTrue((snapshot / "flake/flake.lock").is_file())
        self.assertTrue(any((snapshot / "sources").iterdir()))

    @unittest.skipUnless(
        os.environ.get("NIX_CONFIG_INTEGRATION") == "1" and shutil.which("direnv"),
        "Nix and direnv integration is opt-in",
    )
    def test_real_nix_direnv_nested_tools_use_immutable_sources(self):
        for directory, tool in (
            ("Work Space", "context-parent-tool"),
            ("Work Space/Client", "context-child-tool"),
        ):
            path = self.create(directory)
            flake = path / "flake.nix"
            flake.write_text(
                flake.read_text().replace(
                    "packages = with pkgs; [",
                    f'packages = with pkgs; [ (writeShellScriptBin "{tool}" "true")',
                )
            )
        target = "macbook" if platform.system() == "Darwin" else "nixos-headless"
        system = "aarch64-darwin" if target == "macbook" else "x86_64-linux"
        output = (
            f"darwinConfigurations.{target}"
            if target == "macbook"
            else f"nixosConfigurations.{target}"
        )
        snapshot = self.config.compose(target)
        # Later checkout edits must not change the already composed shells.
        child = self.home / "Work Space/Client/config/flake.nix"
        child.write_text("This is no longer valid Nix")
        nix_direnv = subprocess.check_output(
            [
                "nix",
                "build",
                "--no-link",
                "--print-out-paths",
                str(ROOT) + f"#{output}.pkgs.nix-direnv",
            ],
            text=True,
        ).strip()
        config = self.home / ".config/direnv"
        config.mkdir(parents=True)
        (config / "direnvrc").write_text(
            f'source "{nix_direnv}/share/nix-direnv/direnvrc"\n'
        )
        environment = os.environ | {
            "DIRENV_CONFIG": str(config),
            "DIRENV_WARN_TIMEOUT": "60s",
        }
        subprocess.run(
            [
                sys.executable,
                str(ROOT / "scripts/context_envrcs.py"),
                "--home",
                str(self.home),
                "--state",
                str(self.home / "envrcs.json"),
                "--spec",
                str(snapshot / "envrcs.json"),
                "--direnv",
                "direnv",
            ],
            check=True,
            env=environment,
        )
        project = self.home / "Work Space/Client/project"
        project.mkdir()
        nixpkgs = subprocess.check_output(
            [
                "nix",
                "eval",
                "--raw",
                "--impure",
                "--expr",
                f'(builtins.getFlake "path:{snapshot / "flake"}").inputs.root.inputs.nixpkgs.outPath',
            ],
            text=True,
        ).strip()
        (project / "flake.nix").write_text(
            """{
  inputs.nixpkgs.url = "path:@NIXPKGS@";
  outputs = { nixpkgs, ... }: {
    devShells.@SYSTEM@.default = let pkgs = nixpkgs.legacyPackages.@SYSTEM@; in pkgs.mkShellNoCC {
      packages = [ (pkgs.writeShellScriptBin "project-tool" "true") ];
    };
  };
}
""".replace("@NIXPKGS@", nixpkgs).replace("@SYSTEM@", system)
        )
        (project / ".envrc").write_text("source_up_if_exists\nuse flake\n")
        subprocess.run(
            ["git", "-C", str(project), "init", "-q"], check=True, env=environment
        )
        subprocess.run(
            ["git", "-C", str(project), "add", "flake.nix", ".envrc"],
            check=True,
            env=environment,
        )
        subprocess.run(["direnv", "allow", str(project)], env=environment, check=True)
        result = json.loads(
            subprocess.check_output(
                [
                    "direnv",
                    "exec",
                    str(project),
                    sys.executable,
                    "-c",
                    'import json, shutil; print(json.dumps([shutil.which("context-parent-tool"), shutil.which("context-child-tool"), shutil.which("project-tool")]))',
                ],
                text=True,
                env=environment,
            )
        )
        self.assertTrue(all(result), result)


if __name__ == "__main__":
    unittest.main()
