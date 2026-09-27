// Redact the invocation-time GitHub MCP credential from results sent to models.
// This after hook cannot undo streamed persistence or rewrite truncation files.
function redactString(text, credential) {
  return text.split(credential).join("[REDACTED]");
}

function redactValue(value, credential, visited = new WeakSet()) {
  if (typeof value === "string") return redactString(value, credential);
  if (value === null || typeof value !== "object" || visited.has(value)) return value;

  visited.add(value);
  for (const key of Object.keys(value)) {
    value[key] = redactValue(value[key], credential, visited);
  }
  return value;
}

export default async function redactCredentials() {
  return {
    "tool.execute.after"(_input, output) {
      const credential = process.env.GITHUB_MCP_PAT;
      if (typeof credential !== "string" || credential.length === 0) return;

      redactValue(output, credential);
    },
  };
}
