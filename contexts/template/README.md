# @NAME@ context

This separate repository extends nix-config on the machines where you register it.
Its directory scope is `~/@DIRECTORY@`.

| File | Scope |
| --- | --- |
| `home.nix` | User packages and settings on Linux and macOS |
| `nixos.nix` | NixOS system settings |
| `darwin.nix` | macOS system settings and Homebrew casks |
| `flake.nix` | Folder-only tools, loaded through direnv |

Packages in the three modules apply across the machine. Git profiles and direnv
shells apply within the context directory. Contexts do not isolate processes.
Keep credentials outside this repository and the Nix store.

Stage new files before testing. Flakes do not see untracked files.

```sh
config check
config rebuild
config contexts
```

Commit changes in this repository. Clone and register this repository separately
on each machine that needs it:

```sh
config contexts add ~/@DIRECTORY@/config
config check
config rebuild
```
