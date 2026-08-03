# Global agent instructions

Tool-agnostic guidance applied across every project. Source of truth lives in
this repo's `agents/AGENTS.md`; each agent CLI reads it through an alias into
`~/.agents` (see `home/default.nix`).

## General guidelines

- Favor quality, simplicity, robustness, scalability, and long-term maintainability when making technical decisions; do not over-optimize for short-term development cost.
- Begin bug fixes by reproducing the issue. Prefer an end-to-end reproduction that closely matches the affected user experience.
- Hold end-to-end tests to a high visual standard, including pixel-level accuracy. If an unrelated visual defect is clearly apparent, consider addressing it as a separate atomic fix.
- Treat lint errors, test failures, and flaky tests as engineering defects that require resolution. When unrelated failures surface, consider addressing them as a separate atomic fix.

## Code search

Prefer semantic search for initial discovery when the current repository
provides it. Do not assume a project contains this configuration repository's
scripts or directory layout.

Before using `semble`, check for a repository-documented invocation in its
`AGENTS.md`, `README.md`, development shell, or scripts. If `./scripts/semble`
exists, invoke it from the project root; otherwise use `semble` from `PATH` if
available. If neither exists, use the client's built-in file/content search
tools and fall back to `grep` or `rg` for exhaustive literal matches.

```sh
./scripts/semble search "user validation" .
semble search "drizzle schema" . --top-k 10
```

Use `find-related` to discover code similar to a known location:

```sh
semble find-related src/lib/server/users/repository.ts 12 .
```

Do not prepend `nix develop -c` unless the current repository documents that
its search tooling must run through a Nix development shell.

When adding Semble to a Nix flake, include `pkgs.uv` and expose a wrapper from
the development shell instead of assuming a globally installed package:

```nix
let
  semble = pkgs.writeShellScriptBin "semble" ''
    set -euo pipefail
    exec uvx --from "semble[mcp]" semble "$@"
  '';
in
{
  devShells.default = pkgs.mkShell {
    packages = [ pkgs.uv semble ];
  };
}
```

With direnv active, invoke `semble` directly. Without it, use
`nix develop -c semble ...` only after confirming the project defines this
wrapper.
