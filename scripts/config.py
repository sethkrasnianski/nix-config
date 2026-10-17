#!/usr/bin/env python3
"""Compose explicit, machine-local context repositories with the shared flake."""

import argparse
import contextlib
import datetime
import fcntl
import hashlib
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

TARGETS = ("nixos", "nixos-headless", "nixos-default", "macbook")
NAME = re.compile(r"[a-z][a-z0-9-]*\Z")


class ConfigError(Exception):
    pass


def run(args, *, capture=False, check=True):
    result = subprocess.run(
        [str(arg) for arg in args],
        text=True,
        stdout=subprocess.PIPE if capture else None,
        check=False,
    )
    if check and result.returncode:
        raise ConfigError(
            f"Command failed ({result.returncode}): {' '.join(map(str, args))}"
        )
    return result


def read_json(path, default=None) -> Any:
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        return default
    except (ValueError, OSError) as error:
        raise ConfigError(f"Cannot read {path}: {error}") from error


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as handle:
        temporary = Path(handle.name)
        try:
            json.dump(value, handle, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


class Config:
    def __init__(self, repo=None, home=None):
        self.home = Path(home or Path.home()).resolve()
        self.repo = (
            Path(
                repo
                or os.environ.get(
                    "NIX_CONFIG_REPO",
                    os.environ.get(
                        "NIX_CONFIG_REPO_DEFAULT", self.home / "oss/nix-config"
                    ),
                )
            )
            .expanduser()
            .resolve()
        )
        config_home = Path(os.environ.get("XDG_CONFIG_HOME", self.home / ".config"))
        state_home = Path(os.environ.get("XDG_STATE_HOME", self.home / ".local/state"))
        self.registry = config_home / "nix/contexts.json"
        self.local = config_home / "nix/local.nix"
        self.state = state_home / "nix-config"
        self.applied = Path(
            os.environ.get("NIX_CONFIG_MANIFEST", "/etc/nix-config/manifest.json")
        )
        self.template = Path(
            os.environ.get("NIX_CONFIG_TEMPLATE", self.repo / "contexts/template")
        )

    @contextlib.contextmanager
    def registry_lock(self):
        self.registry.parent.mkdir(parents=True, exist_ok=True)
        with self.registry.with_suffix(".lock").open("a") as handle:
            fcntl.flock(handle, fcntl.LOCK_EX)
            yield

    def context(self, path, *, resolve=True):
        path = Path(path).expanduser()
        if not path.is_absolute():
            path = Path.cwd() / path
        path = path.resolve() if resolve else path.absolute()
        try:
            directory = str(path.parent.relative_to(self.home))
        except ValueError as error:
            raise ConfigError(
                "A context repository must be inside a directory under your home."
            ) from error
        if directory == "." or any(ord(c) < 32 for c in str(path)):
            raise ConfigError(
                "Use a context directory such as ~/Work/config, without control characters."
            )
        name = re.sub(r"[^a-z0-9]+", "-", directory.lower()).strip("-")
        if not name or not name[0].isalpha():
            name = f"context-{name}"
        return {"name": name, "path": str(path), "directory": directory}

    def registrations(self):
        value = read_json(self.registry, {"version": 1, "contexts": []})
        if (
            not isinstance(value, dict)
            or value.get("version") != 1
            or not isinstance(value.get("contexts"), list)
        ):
            raise ConfigError(f"Invalid context registry: {self.registry}")
        result = []
        for item in value["contexts"]:
            if not isinstance(item, dict) or not isinstance(item.get("path"), str):
                raise ConfigError(f"Invalid context entry in {self.registry}")
            normalized = self.context(item["path"], resolve=False)
            if item != normalized:
                raise ConfigError(
                    f"Invalid or moved context registration: {item['path']}. Remove and add it again."
                )
            if any(
                c["path"] == normalized["path"]
                or c["directory"] == normalized["directory"]
                for c in result
            ):
                raise ConfigError(
                    "Each context path and directory must be registered only once."
                )
            result.append(normalized)
        return result

    @staticmethod
    def validate_repo(path):
        path = Path(path)
        if not (path / "flake.nix").is_file() or not (path / ".git").exists():
            raise ConfigError(
                f"Missing context repository: {path}. Restore it or run 'config contexts remove {path}'."
            )
        root = run(
            ["git", "-C", path, "rev-parse", "--show-toplevel"], capture=True
        ).stdout.strip()
        if Path(root).resolve() != path:
            raise ConfigError(
                f"A context must be the root of its own Git repository: {path}"
            )
        tracked = run(
            ["git", "-C", path, "ls-files", "--error-unmatch", "flake.nix"],
            capture=True,
            check=False,
        )
        if tracked.returncode:
            raise ConfigError(
                f"Stage flake.nix before building: git -C '{path}' add flake.nix"
            )

    def add(self, path):
        item = self.context(path)
        self.validate_repo(item["path"])
        with self.registry_lock():
            items = self.registrations()
            if not any(c["path"] == item["path"] for c in items):
                if any(c["directory"] == item["directory"] for c in items):
                    raise ConfigError(
                        f"A context is already registered for {item['directory']}."
                    )
                items.append(item)
            write_json(self.registry, {"version": 1, "contexts": items})
        print(
            f"Registered {item['path']} for ~/{item['directory']}. Apply with config rebuild."
        )

    def remove(self, path):
        item = self.context(path, resolve=False)
        candidates = {item["path"]}
        try:
            candidates.add(self.context(path)["path"])
        except ConfigError:
            # A replaced symlink can now point outside the allowed scope.
            pass
        with self.registry_lock():
            # Removal must work even if the repository is missing.
            items = self.registrations()
            remaining = [c for c in items if c["path"] not in candidates]
            if len(remaining) == len(items):
                raise ConfigError(f"Context is not registered: {item['path']}")
            write_json(self.registry, {"version": 1, "contexts": remaining})
        print(f"Unregistered {item['path']}. Apply with config rebuild.")

    def new(self, path):
        item = self.context(path)
        destination = Path(item["path"])
        if destination.exists() and any(destination.iterdir()):
            raise ConfigError(f"Context directory must be empty: {destination}")
        if not self.template.is_dir():
            raise ConfigError(f"Context template is missing: {self.template}")
        # Reject scope text that would require escaping inside the Nix template.
        if any(c in item["directory"] for c in ('"', "\\", "$")):
            raise ConfigError(
                "The scaffold directory cannot contain quotes, backslashes, or dollar signs."
            )
        destination.mkdir(parents=True, exist_ok=True)
        for source in self.template.iterdir():
            if source.is_file():
                text = (
                    source.read_text()
                    .replace("@NAME@", item["name"])
                    .replace("@DIRECTORY@", item["directory"])
                )
                (destination / source.name).write_text(text)
        (destination / ".gitignore").write_text(".direnv/\nresult\nresult-*\n")
        run(["git", "-C", destination, "init", "-b", "main"])
        run(["git", "-C", destination, "add", "."])
        self.add(destination)
        print(
            f"Created {destination}. Edit home.nix and flake.nix, then run config check."
        )

    @staticmethod
    def git_state(path):
        head = run(
            ["git", "-C", path, "rev-parse", "--verify", "--quiet", "HEAD"],
            capture=True,
            check=False,
        )
        dirty = run(
            ["git", "-C", path, "status", "--porcelain", "--untracked-files=no"],
            capture=True,
        )
        return head.stdout.strip() if head.returncode == 0 else "uncommitted", bool(
            dirty.stdout
        )

    def target(self, requested=None):
        if requested:
            return requested
        applied = read_json(self.applied, {})
        target = (
            os.environ.get("NIX_CONFIG_TARGET")
            or applied.get("target")
            or os.environ.get("NIX_CONFIG_DEFAULT_TARGET")
        )
        if target in TARGETS:
            return target
        if platform.system() == "Darwin":
            return "macbook"
        if "microsoft" in platform.release().lower():
            return "nixos"
        raise ConfigError(
            "Select the host with --target nixos-default (or another configured target)."
        )

    def status(self, contexts_only=False):
        applied = read_json(self.applied, {})
        if not contexts_only:
            print(f"Repository: {self.repo}")
            print(f"Target: {self.target()}")
            revision, dirty = self.git_state(self.repo)
            print(f"Base: {revision}{' (modified)' if dirty else ''}")
            print(f"Applied base: {applied.get('baseRevision', 'not recorded')}")
            if self.local.exists():
                digest = hashlib.sha256(self.local.read_bytes()).hexdigest()
                print(
                    f"Local settings: {'applied' if applied.get('localConfigHash') == digest else 'changed or not applied'}"
                )
        print(f"Registry: {self.registry}")
        active = {c["path"]: c for c in applied.get("contexts", [])}
        items = self.registrations()
        for item in items:
            previous = active.pop(item["path"], None)
            try:
                self.validate_repo(item["path"])
                revision, dirty = self.git_state(item["path"])
                if dirty:
                    state = "modified files (run config check, then config rebuild)"
                elif previous and previous["revision"] == revision:
                    state = f"applied @ {revision[:12]}"
                else:
                    state = f"not applied @ {revision[:12]}"
            except ConfigError as error:
                state = str(error)
            print(
                f"  {item['name']}: {item['path']} -> ~/{item['directory']} [{state}]"
            )
        for item in active.values():
            print(f"  {item['name']}: removal pending (run config rebuild)")
        if not items and not active:
            print("  No contexts registered.")

    @staticmethod
    def snapshot_source(path, flags=()):
        Config.validate_repo(path)
        shallow = (
            run(
                ["git", "-C", path, "rev-parse", "--is-shallow-repository"],
                capture=True,
            ).stdout.strip()
            == "true"
        )
        uri = f"git+{Path(path).as_uri()}"
        if shallow:
            # Nix cannot calculate revCount from incomplete Git history.
            uri += "?shallow=1"
        value = json.loads(
            run(
                [
                    "nix",
                    "flake",
                    "prefetch",
                    "--json",
                    uri,
                    *flags,
                ],
                capture=True,
            ).stdout
        )
        locked = value["locked"]
        revision = locked.get("rev") or locked.get("dirtyRev") or "uncommitted"
        return value["storePath"], {
            "revision": revision,
            "sourceHash": value["hash"],
            "dirty": "rev" not in locked,
        }

    def compose(self, target, flags=()):
        registrations = self.registrations()
        # Validate all registrations before generating or evaluating any system.
        for item in registrations:
            self.validate_repo(item["path"])
        root, base = self.snapshot_source(self.repo, flags)
        self.state.joinpath("builds").mkdir(parents=True, exist_ok=True)
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S-")
        snapshot = Path(
            tempfile.mkdtemp(prefix=stamp, dir=self.state / "builds")
        ).resolve()
        composition = snapshot / "flake"
        composition.mkdir()
        metadata = {
            "basePath": str(self.repo),
            "baseRevision": base["revision"],
            "baseSourceHash": base["sourceHash"],
            "baseDirty": base["dirty"],
            "compositionPath": str(composition),
            "localConfigHash": None,
            "target": target,
            "contexts": [],
        }
        inputs = [f'    root.url = "path:{root}";']
        if self.local.is_file():
            composition.joinpath("local").mkdir()
            data = self.local.read_bytes()
            composition.joinpath("local/default.nix").write_bytes(data)
            metadata["localConfigHash"] = hashlib.sha256(data).hexdigest()
            inputs.append(
                '    local-config = { url = "path:./local"; flake = false; };'
            )
            inputs.append('    root.inputs.local-config.follows = "local-config";')
        expressions = []
        for index, item in enumerate(registrations):
            source, info = self.snapshot_source(item["path"], flags)
            metadata["contexts"].append(item | info)
            inputs.extend(
                [
                    f'    ctx{index}.url = "path:{source}";',
                    f'    ctx{index}.inputs.nixpkgs.follows = "root/nixpkgs";',
                ]
            )
            expressions.append(
                f"(context inputs.ctx{index} (builtins.elemAt metadata.contexts {index}))"
            )
        write_json(composition / "request.json", metadata)
        system = "aarch64-darwin" if target == "macbook" else "x86_64-linux"
        output = (
            "darwinConfigurations" if target == "macbook" else "nixosConfigurations"
        )
        # Paths from users live in JSON, never interpolated into Nix expressions.
        wrapper = """{
  inputs = {
@INPUTS@
  };
  outputs = inputs:
    let
      metadata = builtins.fromJSON (builtins.readFile ./request.json);
      system = "@SYSTEM@";
      context = input: item:
        let
          name = input.context.name or item.name;
          hasShell = builtins.hasAttr "default" (input.devShells.${system} or { });
          compatible = input ? homeManagerModules.default ||
            builtins.hasAttr "default" (input.@MODULES@ or { }) || hasShell;
        in
        if !compatible then throw "Context ${name} has no modules or shell for ${system}"
        else if input ? devShells && !hasShell then throw "Context ${name} has no default shell for ${system}"
        else item // {
          inherit name hasShell;
          flake = input;
          shell = if hasShell then "${metadata.compositionPath}#context-${name}" else null;
        };
      contexts = [ @CONTEXTS@ ];
      host = inputs.root.lib.mkHost {
        target = metadata.target;
        inherit contexts;
        buildMetadata = builtins.removeAttrs metadata [ "contexts" "target" ];
      };
    in {
      @OUTPUT@.@TARGET@ = host;
      contextManifest = host.config.contexts.manifest;
      devShells.${system} = builtins.listToAttrs (map (c: {
        name = "context-${c.name}";
        value = c.flake.devShells.${system}.default;
      }) (builtins.filter (c: c.hasShell) contexts));
    };
}
"""
        for key, value in {
            "INPUTS": "\n".join(inputs),
            "SYSTEM": system,
            "CONTEXTS": " ".join(expressions),
            "OUTPUT": output,
            "TARGET": target,
            "MODULES": "darwinModules" if target == "macbook" else "nixosModules",
        }.items():
            wrapper = wrapper.replace(f"@{key}@", value)
        composition.joinpath("flake.nix").write_text(wrapper)
        reference = f"path:{composition}"
        run(["nix", "flake", "lock", reference, *flags])
        manifest = json.loads(
            run(
                [
                    "nix",
                    "eval",
                    "--json",
                    "--no-update-lock-file",
                    f"{reference}#contextManifest",
                    *flags,
                ],
                capture=True,
            ).stdout
        )
        names = [c["name"] for c in manifest["contexts"]]
        if len(set(names)) != len(names) or any(
            not NAME.fullmatch(name) for name in names
        ):
            raise ConfigError(
                "Context names must be unique lowercase names with letters, digits, or hyphens."
            )
        write_json(snapshot / "manifest.json", manifest)
        specifications = [
            {"name": c["name"], "directory": c["directory"], "flake": c["shell"]}
            for c in manifest["contexts"]
            if c["hasShell"]
        ]
        write_json(snapshot / "envrcs.json", specifications)
        helper = os.environ.get(
            "NIX_CONFIG_ENVRC_HELPER",
            str(Path(__file__).with_name("context_envrcs.py")),
        )
        run(
            [
                sys.executable,
                helper,
                "--check",
                "--home",
                self.home,
                "--state",
                self.state / "context-envrcs.json",
                "--spec",
                snapshot / "envrcs.json",
            ]
        )
        self.pin_sources(snapshot, flags)
        print(f"Composition: {snapshot}", flush=True)
        if base["dirty"] or any(c["dirty"] for c in metadata["contexts"]):
            print(
                "This composition contains modified files. Commit them in their own repositories to reproduce it elsewhere.",
                flush=True,
            )
        return snapshot

    @staticmethod
    def pin_sources(snapshot, flags=()):
        archive = json.loads(
            run(
                [
                    "nix",
                    "flake",
                    "archive",
                    "--json",
                    "--no-update-lock-file",
                    f"path:{snapshot / 'flake'}",
                    *flags,
                ],
                capture=True,
            ).stdout
        )
        paths = set()

        def collect(node):
            if "path" in node:
                paths.add(node["path"])
            for child in node.get("inputs", {}).values():
                collect(child)

        collect(archive)
        snapshot.joinpath("sources").mkdir()
        for index, path in enumerate(sorted(paths)):
            run(
                [
                    "nix-store",
                    "--realise",
                    path,
                    "--add-root",
                    snapshot / f"sources/{index}",
                ],
                capture=True,
            )

    def build(self, target, *, activate=False, evaluate=False, flags=()):
        if activate and (platform.system() == "Darwin") != (target == "macbook"):
            raise ConfigError(f"Cannot activate {target} on {platform.system()}.")
        backend = None
        if activate:
            name = "darwin-rebuild" if target == "macbook" else "nixos-rebuild"
            backend = shutil.which(name)
            if backend is None:
                raise ConfigError(
                    f"{name} is not installed. Bootstrap the host before using config rebuild."
                )
        snapshot = self.compose(
            target,
            flags=[flag for flag in flags if flag in ("--offline", "--show-trace")],
        )
        output = (
            f"darwinConfigurations.{target}.system"
            if target == "macbook"
            else f"nixosConfigurations.{target}.config.system.build.toplevel"
        )
        reference = f"path:{snapshot / 'flake'}"
        manifest = read_json(snapshot / "manifest.json", {"contexts": []})
        shells = [c for c in manifest["contexts"] if c["hasShell"]]
        system = "aarch64-darwin" if target == "macbook" else "x86_64-linux"
        if evaluate:
            run(
                [
                    "nix",
                    "eval",
                    "--raw",
                    "--no-update-lock-file",
                    f"{reference}#{output}.drvPath",
                    *flags,
                ]
            )
            for context in shells:
                run(
                    [
                        "nix",
                        "eval",
                        "--raw",
                        "--no-update-lock-file",
                        f"{reference}#devShells.{system}.context-{context['name']}.drvPath",
                        *flags,
                    ]
                )
            print()
            return snapshot
        run(
            [
                "nix",
                "build",
                "--no-update-lock-file",
                f"{reference}#{output}",
                "--out-link",
                snapshot / "result",
                *flags,
            ]
        )
        for context in shells:
            run(
                [
                    "nix",
                    "build",
                    "--no-update-lock-file",
                    f"{reference}#devShells.{system}.context-{context['name']}",
                    "--out-link",
                    snapshot / f"shell-{context['name']}",
                    *flags,
                ]
            )
        if activate:
            # The backend sees immutable store inputs, not private Git checkouts.
            run(
                [
                    "sudo",
                    backend,
                    "switch",
                    "--flake",
                    f"{reference}#{target}",
                    "--no-update-lock-file",
                    *flags,
                ]
            )
            write_json(
                self.state / "last-applied.json", {"compositionPath": str(snapshot)}
            )
        else:
            print(f"Built without activation: {snapshot / 'result'}")
        return snapshot


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="config",
        description="Manage this host and its separate context repositories.",
    )
    parser.add_argument(
        "--repo", type=Path, help="base repository (defaults to ~/oss/nix-config)"
    )
    parser.add_argument("--target", choices=TARGETS)
    commands = parser.add_subparsers(dest="command")
    contexts = commands.add_parser(
        "contexts", help="list or change this machine's registered contexts"
    )
    operations = contexts.add_subparsers(dest="operation")
    for name in ("add", "remove"):
        operations.add_parser(name).add_argument("path")
    context = commands.add_parser(
        "context", help="create a separate context repository"
    )
    create = context.add_subparsers(dest="operation", required=True).add_parser("new")
    create.add_argument("path")
    for name in ("check", "rebuild"):
        build = commands.add_parser(
            name,
            help="evaluate/build without activation"
            if name == "check"
            else "build and activate",
        )
        build.add_argument("--target", choices=TARGETS, default=argparse.SUPPRESS)
        build.add_argument("-L", "--print-build-logs", action="store_true")
        build.add_argument("--show-trace", action="store_true")
        build.add_argument("--offline", action="store_true")
        if name == "check":
            build.add_argument(
                "--eval",
                action="store_true",
                help="evaluate the derivation without building",
            )
    commands.add_parser("help", help="show command help")
    args = parser.parse_args(argv)
    config = Config(repo=args.repo)
    try:
        if args.command == "help":
            parser.print_help()
        elif args.command == "context":
            config.new(args.path)
        elif args.command == "contexts":
            if args.operation == "add":
                config.add(args.path)
            elif args.operation == "remove":
                config.remove(args.path)
            else:
                config.status(contexts_only=True)
        elif args.command in ("check", "rebuild"):
            flags = [
                flag
                for flag, enabled in (
                    ("-L", args.print_build_logs),
                    ("--show-trace", args.show_trace),
                    ("--offline", args.offline),
                )
                if enabled
            ]
            config.build(
                config.target(args.target),
                activate=args.command == "rebuild",
                evaluate=getattr(args, "eval", False),
                flags=flags,
            )
        else:
            config.status()
    except (ConfigError, OSError) as error:
        print(f"config: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
