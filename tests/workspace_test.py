"""Apply evaluated profile definitions to Git, including a linked worktree."""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(
    os.environ.get("NIX_CONFIG_INTEGRATION") == "1", "real Nix evaluation is opt-in"
)
class GitProfilesTests(unittest.TestCase):
    def test_default_work_nested_boundary_and_linked_worktree(self):
        definitions = json.loads(
            subprocess.check_output(
                [
                    "nix",
                    "eval",
                    "--impure",
                    "--json",
                    "--file",
                    str(ROOT / "tests/workspace-eval.nix"),
                ],
                text=True,
            )
        )
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary).resolve()
            global_config = home / ".gitconfig"
            environment = os.environ | {
                "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_CONFIG_GLOBAL": str(global_config),
            }

            def git(*args):
                return subprocess.check_output(
                    ["git", *map(str, args)], text=True, env=environment
                ).strip()

            for key, value in definitions["base"].items():
                git(
                    "config",
                    "--file",
                    global_config,
                    f"user.{key}",
                    str(value).lower() if isinstance(value, bool) else value,
                )
            for index, profile in enumerate(definitions["includes"]):
                include = home / f"profile-{index}"
                for section, values in profile["contents"].items():
                    for key, value in values.items():
                        git("config", "--file", include, f"{section}.{key}", value)
                condition = profile["condition"].replace("/home/nixos", str(home))
                git(
                    "config",
                    "--file",
                    global_config,
                    "--add",
                    f"includeIf.{condition}.path",
                    str(include),
                )

            repos = {}
            for scope, email in (
                ("Personal/project", definitions["base"]["email"]),
                ("Work/project", "work@users.noreply.github.com"),
                ("Work/Client/project", "client@users.noreply.github.com"),
                ("Workish/project", definitions["base"]["email"]),
            ):
                repo = home / scope
                repo.mkdir(parents=True)
                git("init", "-q", repo)
                self.assertEqual(git("-C", repo, "config", "user.email"), email)
                self.assertIn(
                    "file:", git("-C", repo, "config", "--show-origin", "user.email")
                )
                repos[scope] = repo
            original = repos["Work/project"]
            git(
                "-C",
                original,
                "commit",
                "--allow-empty",
                "-m",
                "Test worktree identity",
            )
            worktree = home / "linked-worktree"
            git("-C", original, "worktree", "add", "--detach", worktree)
            self.assertEqual(
                git("-C", worktree, "config", "user.email"),
                "work@users.noreply.github.com",
            )


if __name__ == "__main__":
    unittest.main()
