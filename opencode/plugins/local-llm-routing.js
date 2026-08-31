import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

// The JSON override is retained for isolated plugin tests. Normal startup
// always evaluates local.nix, including when the file is absent.
const profileOverridePath = process.env.OPENCODE_LOCAL_LLM_PROFILE;
const localConfigPath =
  process.env.OPENCODE_LOCAL_CONFIG ??
  path.join(os.homedir(), ".config", "nix", "local.nix");
const evaluatorPath =
  process.env.OPENCODE_LOCAL_PROFILE_EVALUATOR ??
  path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "local-profile.nix");

function readJsonProfile(profilePath) {
  try {
    return JSON.parse(fs.readFileSync(profilePath, "utf8"));
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

function readEvaluatedProfile() {
  try {
    const output = execFileSync(
      process.env.OPENCODE_NIX ?? "nix",
      [
        "eval",
        "--impure",
        "--json",
        "--file",
        evaluatorPath,
        "--apply",
        'profile: profile { localConfigPath = builtins.getEnv "OPENCODE_LOCAL_CONFIG"; }',
      ],
      {
        encoding: "utf8",
        maxBuffer: 1024 * 1024,
        env: { ...process.env, OPENCODE_LOCAL_CONFIG: localConfigPath },
        stdio: ["ignore", "pipe", "pipe"],
      },
    );
    return JSON.parse(output);
  } catch (error) {
    const details = String(error.stderr ?? "").trim();
    throw new Error(
      `Unable to evaluate OpenCode local profile: ${details || error.message}`,
    );
  }
}

function readProfile() {
  if (profileOverridePath) return readJsonProfile(profileOverridePath);
  return readEvaluatedProfile();
}

function applyAgentSettings(agent, settings, fields) {
  for (const field of fields) {
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

  if (typeof agent.model === "string" && agent.model.startsWith("ollama/")) {
    if (agent.options) delete agent.options.reasoningEffort;
  }
}

export default async function localLlmRouting() {
  return {
    config(config) {
      const profile = readProfile();

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
      for (const name of ["build", "plan"]) {
        const settings = profile?.builtInAgents?.[name];
        if (!settings) continue;
        const agent = agents[name] ?? (agents[name] = {});
        applyAgentSettings(agent, settings, ["model"]);
      }

      for (const [name, settings] of Object.entries(profile?.agents ?? {})) {
        const agent = agents[name] ?? (agents[name] = {});
        applyAgentSettings(agent, settings, ["model", "variant", "temperature", "top_p"]);
      }
    },
  };
};
