#!/usr/bin/env python3
"""Reconcile generated .envrc files without overwriting unrelated user files."""

import argparse
import hashlib
import json
import os
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path


def digest(text):
    return hashlib.sha256(text.encode()).hexdigest()


def owned_path(home, path, *, allow_symlink=False):
    path = Path(path)
    if (
        not path.is_absolute()
        or path.name != ".envrc"
        or not path.parent.resolve().is_relative_to(home)
    ):
        raise ValueError(f"Invalid managed environment path: {path}")
    if path.is_symlink() and not allow_symlink:
        raise ValueError(f"Refusing to replace a symlink: {path}")
    return path


def atomic_write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as handle:
        temporary = Path(handle.name)
        try:
            handle.write(content)
            handle.flush()
            os.fchmod(handle.fileno(), 0o644)
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def reconcile(home, state, specifications, *, check=False, direnv=None):
    home = Path(home).resolve()
    state = Path(state)
    previous = (
        json.loads(state.read_text()) if state.exists() else {"version": 1, "files": {}}
    )
    if previous.get("version") != 1 or not isinstance(previous.get("files"), dict):
        raise ValueError(f"Invalid environment ownership state: {state}")
    desired = {}
    for spec in specifications:
        directory = Path(spec["directory"])
        if (
            directory.is_absolute()
            or not directory.parts
            or any(p in (".", "..") for p in directory.parts)
        ):
            raise ValueError(f"Invalid context directory: {directory}")
        path = owned_path(home, home / directory / ".envrc")
        if path in desired:
            raise ValueError(f"Duplicate context environment: {path}")
        flake = spec["flake"]
        if not isinstance(flake, str) or not flake.startswith("/"):
            raise ValueError(
                f"Context shell must reference its locked composition: {flake}"
            )
        text = (
            f"# Managed by nix-config for context {spec['name']}.\n"
            "source_up_if_exists\n"
            f"use flake {shlex.quote('path:' + flake)}\n"
        )
        if path.exists():
            actual = path.read_text()
            if actual != text and previous["files"].get(str(path)) != digest(actual):
                raise ValueError(
                    f"Existing user-owned file: {path}. Move it aside or integrate its settings before rebuilding."
                )
        desired[path] = text
    # Validate stale paths too, before making any changes.
    stale = [
        owned_path(home, path, allow_symlink=True)
        for path in previous["files"]
        if Path(path) not in desired
    ]
    if check:
        return
    for path in stale:
        if (
            not path.is_symlink()
            and path.is_file()
            and digest(path.read_text()) == previous["files"][str(path)]
        ):
            path.unlink()
    for path, text in desired.items():
        if not path.exists() or path.read_text() != text:
            atomic_write(path, text)
        if direnv:
            # Trust this exact generated content, rather than whitelist a mutable path.
            subprocess.run([direnv, "allow", str(path)], check=True)
    atomic_write(
        state,
        json.dumps(
            {
                "version": 1,
                "files": {str(path): digest(text) for path, text in desired.items()},
            },
            indent=2,
        )
        + "\n",
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", type=Path, required=True)
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--spec", type=Path, required=True)
    parser.add_argument("--direnv")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    try:
        reconcile(
            args.home,
            args.state,
            json.loads(args.spec.read_text()),
            check=args.check,
            direnv=args.direnv,
        )
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"config environments: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
