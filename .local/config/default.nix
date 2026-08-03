{ pkgs, ... }:
{
  local.llm = {
    enable = true;
    package = pkgs.ollama;
    model = "qwen3-coder:30b";
    agents = [
      "auto-history-finalizer"
      "auto-committer"
      "auto-test-writer"
    ];
  };
}
