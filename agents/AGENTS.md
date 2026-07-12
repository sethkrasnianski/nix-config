# Global agent instructions

Tool-agnostic guidance applied across every project. Source of truth lives in
this repo's `agents/AGENTS.md`; each agent CLI reads it through an alias into
`~/.agents` (see `home/default.nix`).

## Code search

Prefer semantic search over `grep` for initial discovery. Always start from
the project root with the `./scripts/semble` wrapper, which works whether or
not the dev shell is already active. Inside the shell, `semble` is also on
`$PATH`.

```sh
nix develop -c ./scripts/semble search "user validation" .
nix develop -c ./scripts/semble search "drizzle schema" . --top-k 10
```

Use `find-related` to discover code similar to a known location:

```sh
nix develop -c ./scripts/semble find-related src/lib/server/users/repository.ts 12 .
```

Fall back to `grep` only for exhaustive literal matches.
