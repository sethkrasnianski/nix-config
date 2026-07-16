import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const profilePath =
  process.env.OPENCODE_LOCAL_LLM_PROFILE ??
  path.join(os.homedir(), ".config", "opencode", "local-agents.json");

function readProfile() {
  try {
    return JSON.parse(fs.readFileSync(profilePath, "utf8"));
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

export default async function localLlmRouting() {
  return {
    config(config) {
      const profile = readProfile();
      if (profile && "model" in profile) {
        config.model = profile.model;
      }

      const ollama = profile?.ollama;
      if (ollama?.enable) {
        const model = ollama.model;
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
                context: ollama.contextLength,
                output: ollama.contextLength,
              },
            },
          },
        };
      }

      const agents = config.agent ?? (config.agent = {});
      for (const [name, settings] of Object.entries(profile?.agents ?? {})) {
        const agent = agents[name] ?? (agents[name] = {});
        for (const field of ["model", "variant", "temperature", "top_p"]) {
          if (!(field in settings)) continue;
          if (settings[field] === null) delete agent[field];
          else agent[field] = settings[field];
        }

        if ("reasoningEffort" in settings) {
          if (settings.reasoningEffort === null) {
            if (agent.options) delete agent.options.reasoningEffort;
          } else {
            agent.options = agent.options ?? {};
            agent.options.reasoningEffort = settings.reasoningEffort;
          }
        }

        if (typeof settings.model === "string" && settings.model.startsWith("ollama/")) {
          if (agent.options) delete agent.options.reasoningEffort;
        }
      }
    },
  };
};
