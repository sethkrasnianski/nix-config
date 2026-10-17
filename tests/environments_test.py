"""Check environment ownership and folder inheritance through the real direnv."""

import importlib.util
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "context_envrcs", ROOT / "scripts/context_envrcs.py"
)
assert SPEC is not None and SPEC.loader is not None
envrcs = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(envrcs)


class EnvironmentTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name).resolve()
        self.state = self.home / ".local/state/envrcs.json"
        self.spec = [
            {
                "name": "work",
                "directory": "Work Space",
                "flake": "/locked/build#context-work",
            }
        ]
        self.path = self.home / "Work Space/.envrc"

    def test_existing_file_is_never_overwritten(self):
        self.path.parent.mkdir()
        self.path.write_text("export USER_FILE=keep\n")
        with self.assertRaisesRegex(ValueError, "user-owned"):
            envrcs.reconcile(self.home, self.state, self.spec)
        self.assertEqual(self.path.read_text(), "export USER_FILE=keep\n")
        self.assertFalse(self.state.exists())

    def test_rebuild_replaces_only_owned_content(self):
        envrcs.reconcile(self.home, self.state, self.spec)
        self.spec[0]["flake"] = "/locked/new-build#context-work"
        envrcs.reconcile(self.home, self.state, self.spec)
        self.assertIn("path:/locked/new-build#context-work", self.path.read_text())
        self.path.write_text("# user edits\n")
        with self.assertRaisesRegex(ValueError, "user-owned"):
            envrcs.reconcile(self.home, self.state, self.spec)

    def test_removal_deletes_owned_file_and_preserves_modified_file(self):
        envrcs.reconcile(self.home, self.state, self.spec)
        envrcs.reconcile(self.home, self.state, [])
        self.assertFalse(self.path.exists())
        envrcs.reconcile(self.home, self.state, self.spec)
        self.path.write_text("# keep user edits\n")
        envrcs.reconcile(self.home, self.state, [])
        self.assertEqual(self.path.read_text(), "# keep user edits\n")

    def test_check_is_read_only(self):
        envrcs.reconcile(self.home, self.state, self.spec, check=True)
        self.assertFalse(self.path.exists())
        self.assertFalse(self.state.exists())

    def test_removal_preserves_a_user_replacement_symlink(self):
        envrcs.reconcile(self.home, self.state, self.spec)
        self.path.unlink()
        target = self.home / "custom-envrc"
        target.write_text("# user file\n")
        self.path.symlink_to(target)
        envrcs.reconcile(self.home, self.state, [])
        self.assertTrue(self.path.is_symlink())
        self.assertEqual(target.read_text(), "# user file\n")

    def test_all_conflicts_are_checked_before_any_writes(self):
        conflict = self.home / "Conflict/.envrc"
        conflict.parent.mkdir()
        conflict.write_text("keep")
        self.spec.append(
            {
                "name": "conflict",
                "directory": "Conflict",
                "flake": "/locked/build#conflict",
            }
        )
        with self.assertRaises(ValueError):
            envrcs.reconcile(self.home, self.state, self.spec)
        self.assertFalse(self.path.exists())

    def test_symlinks_and_directory_traversal_are_rejected(self):
        target = self.home / "user-file"
        target.write_text("keep")
        self.path.parent.mkdir()
        self.path.symlink_to(target)
        with self.assertRaisesRegex(ValueError, "symlink"):
            envrcs.reconcile(self.home, self.state, self.spec)
        self.spec[0]["directory"] = "../outside"
        with self.assertRaisesRegex(ValueError, "Invalid context"):
            envrcs.reconcile(self.home, self.state, self.spec)

    @unittest.skipUnless(shutil.which("direnv"), "direnv is required")
    def test_real_direnv_parent_child_project_and_environment_restoration(self):
        direnv = shutil.which("direnv")
        assert direnv is not None
        config = self.home / ".config/direnv"
        config.mkdir(parents=True)
        # Replace only the Nix build adapter. Exercise real direnv chaining,
        # approval, exports, and restoration with deterministic marker tools.
        (config / "direnvrc").write_text("""use_flake() {
  case "$1" in
    *context-work) export CONTEXT_PARENT=loaded ;;
    *context-client) export CONTEXT_CHILD=loaded ;;
  esac
}
""")
        self.spec.append(
            {
                "name": "client",
                "directory": "Work Space/Client",
                "flake": "/locked/build#context-client",
            }
        )
        environment = os.environ | {
            "HOME": str(self.home),
            "DIRENV_CONFIG": str(config),
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "XDG_DATA_HOME": str(self.home / ".local/share"),
            "DIRENV_LOG_FORMAT": "",
        }
        # The allow database uses this same isolated home in both processes.
        with patch.dict(os.environ, environment):
            envrcs.reconcile(self.home, self.state, self.spec, direnv=direnv)
        project = self.home / "Work Space/Client/project"
        outside = self.home / "Personal"
        project.mkdir()
        outside.mkdir()
        (project / ".envrc").write_text(
            "source_up_if_exists\nexport PROJECT_MARKER=loaded\n"
        )
        subprocess.run([direnv, "allow", str(project)], env=environment, check=True)
        loaded = subprocess.check_output(
            [direnv, "exec", str(project), "env"], text=True, env=environment
        )
        for marker in (
            "CONTEXT_PARENT=loaded",
            "CONTEXT_CHILD=loaded",
            "PROJECT_MARKER=loaded",
        ):
            self.assertIn(marker, loaded.splitlines())
        script = """cd "$1"
eval "$(direnv export bash)"
test "$CONTEXT_PARENT/$CONTEXT_CHILD/$PROJECT_MARKER" = loaded/loaded/loaded || exit 1
cd "$2"
eval "$(direnv export bash)"
test -z "${CONTEXT_PARENT+x}${CONTEXT_CHILD+x}${PROJECT_MARKER+x}"
"""
        subprocess.run(
            ["bash", "-c", script, "test", str(project), str(outside)],
            env=environment,
            check=True,
        )


if __name__ == "__main__":
    unittest.main()
