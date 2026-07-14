const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const profilePath =
  process.env.OPENCODE_LOCAL_LLM_PROFILE ??
  path.join(os.homedir(), ".config", "opencode", "local-llm.json");

function readProfile() {
  try {
    return JSON.parse(fs.readFileSync(profilePath, "utf8"));
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

module.exports = async function localLlmRouting() {
  return {
    config(config) {
      const profile = readProfile();
      if (!profile?.enable) return;

      const model = profile.model;
      const provider = config.provider ?? (config.provider = {});
      provider.ollama = {
        npm: "@ai-sdk/openai-compatible",
        name: "Ollama",
        options: {
          baseURL: "http://127.0.0.1:11434/v1",
          apiKey: "ollama",
        },
        models: {
          [model]: {
            id: model,
            name: model,
            reasoning: false,
            temperature: true,
            tool_call: true,
            limit: {
              context: profile.contextLength,
              output: profile.contextLength,
            },
          },
        },
      };

      const agents = config.agent ?? (config.agent = {});
      for (const name of profile.agents ?? []) {
        const agent = agents[name] ?? (agents[name] = {});
        agent.model = `ollama/${model}`;
        delete agent.reasoningEffort;
        if (agent.options) delete agent.options.reasoningEffort;
      }
    },
  };
};
