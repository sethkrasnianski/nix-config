{
  github-copilot = {
    auto = {
      model = "github-copilot/claude-sonnet-5";
      reasoningEffort = "medium";
    };
    cleanup = {
      model = "github-copilot/gpt-5.6-sol";
      reasoningEffort = "low";
    };
    auto-researcher = {
      model = "github-copilot/gpt-5.6-sol";
      reasoningEffort = "high";
    };
    auto-planner = {
      model = "github-copilot/claude-fable-5";
      reasoningEffort = "max";
    };
    auto-test-writer = {
      model = "github-copilot/gpt-5.6-luna";
      reasoningEffort = "medium";
    };
    auto-implementer = {
      model = "github-copilot/gpt-5.3-codex";
      reasoningEffort = "high";
    };
    auto-test-fixer = {
      model = "github-copilot/gpt-5.6-luna";
      reasoningEffort = "medium";
    };
    auto-reviewer = {
      model = "github-copilot/gpt-5.6-sol";
      reasoningEffort = "max";
    };
    auto-committer = {
      model = "github-copilot/gpt-5.6-luna";
      reasoningEffort = "low";
    };
    auto-history-finalizer = {
      model = "github-copilot/gpt-5.6-terra";
      reasoningEffort = "medium";
    };
  };
}
