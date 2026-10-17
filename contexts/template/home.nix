# Shared user settings on Linux and macOS. Packages here apply everywhere.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Add user tools here, or use flake.nix for folder-only tools.
  ];

  # Git identity for repositories under ~/@DIRECTORY@.
  # Use your work account's approved address (a GitHub noreply address works).
  # workspace.gitProfiles.@NAME@ = {
  #   directory = "@DIRECTORY@";
  #   name = "Your Name";
  #   email = "your-work-account@users.noreply.github.com";
  # };
}
