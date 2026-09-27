#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$ROOT/plugins/redact-credentials.js"

node --input-type=module - "$PLUGIN" <<'NODE'
import assert from "node:assert/strict";

const credential = "fake-mcp-credential-for-tests";
process.env.GITHUB_MCP_PAT = credential;

const { default: plugin } = await import(process.argv[2]);
const hooks = await plugin({});
const result = {
  title: "Resolved OpenCode configuration for fake-mcp-credential-for-tests",
  output: [
    '{"mcp":{"github":{"headers":{"Authorization":"Bearer fake-mcp-credential-for-tests"}}}}',
    "The value also appears in unrelated output: fake-mcp-credential-for-tests",
    "Repeated values: fake-mcp-credential-for-tests / fake-mcp-credential-for-tests",
    "This unrelated configuration remains readable.",
  ].join("\n"),
  metadata: {
    output: "streamed text: fake-mcp-credential-for-tests",
    nested: { detail: "nested metadata: fake-mcp-credential-for-tests" },
    exit: 0,
  },
};
const resultIdentity = result;

hooks["tool.execute.after"]({ tool: "bash" }, result);

assert.equal(result, resultIdentity, "the hook mutates the result passed back to the model");
assert.equal(result.title, "Resolved OpenCode configuration for [REDACTED]");
assert.equal(
  result.output,
  [
    '{"mcp":{"github":{"headers":{"Authorization":"Bearer [REDACTED]"}}}}',
    "The value also appears in unrelated output: [REDACTED]",
    "Repeated values: [REDACTED] / [REDACTED]",
    "This unrelated configuration remains readable.",
  ].join("\n"),
);
assert.equal(result.metadata.output, "streamed text: [REDACTED]");
assert.equal(result.metadata.nested.detail, "nested metadata: [REDACTED]");
assert.equal(result.metadata.exit, 0);

const modelVisibleResult = JSON.stringify(result);
assert(!modelVisibleResult.includes(credential), "the model-visible result must not contain the credential");
assert(modelVisibleResult.includes("Bearer [REDACTED]"));
assert(modelVisibleResult.includes("This unrelated configuration remains readable."));

delete process.env.GITHUB_MCP_PAT;
const withoutCredential = { output: "leave this unchanged", metadata: { output: "also unchanged" } };
hooks["tool.execute.after"]({ tool: "bash" }, withoutCredential);
assert.deepEqual(withoutCredential, {
  output: "leave this unchanged",
  metadata: { output: "also unchanged" },
});

process.env.GITHUB_MCP_PAT = "";
const withEmptyCredential = { output: "leave this unchanged too", metadata: { output: "unchanged" } };
hooks["tool.execute.after"]({ tool: "bash" }, withEmptyCredential);
assert.deepEqual(withEmptyCredential, {
  output: "leave this unchanged too",
  metadata: { output: "unchanged" },
});

console.log("credential redaction tests passed");
NODE
