#!/usr/bin/env bash
# Self-test for hook-protocol.js with Antigravity payloads.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
PROTO="$ROOT/agentic/hooks/lib/hook-protocol.js"

echo "Running hook-protocol Antigravity tests..."

# 1. Test detection of Antigravity payload and command extraction
RES=$(node -e '
const proto = require(process.argv[1]);
const input = {
  conversationId: "conv-12345",
  workspacePaths: ["/Users/test/workspace"],
  stepIdx: 1,
  toolCall: {
    name: "run_command",
    args: { CommandLine: "echo hello", Cwd: "/Users/test/workspace" }
  }
};
if (!proto.isAntigravity(input)) { console.error("isAntigravity failed"); process.exit(1); }
if (proto.ideOf(input) !== "antigravity") { console.error("ideOf failed"); process.exit(1); }
if (proto.commandOf(input) !== "echo hello") { console.error("commandOf failed"); process.exit(1); }
if (proto.toolNameOf(input) !== "Shell") { console.error("toolNameOf failed"); process.exit(1); }
if (proto.workspaceRootOf(input) !== "/Users/test/workspace") { console.error("workspaceRootOf failed"); process.exit(1); }
console.log("OK1");
' "$PROTO")

[[ "$RES" == "OK1" ]] || { echo "Failed test 1"; exit 1; }

# 2. Test file path extraction (TargetFile & AbsolutePath)
RES=$(node -e '
const proto = require(process.argv[1]);
const writeCall = {
  conversationId: "conv-12345",
  toolCall: {
    name: "write_to_file",
    args: { TargetFile: "/path/to/file.ts", CodeContent: "foo" }
  }
};
if (proto.filePathOf(writeCall) !== "/path/to/file.ts") { console.error("filePathOf TargetFile failed"); process.exit(1); }
if (proto.toolNameOf(writeCall) !== "Write") { console.error("toolNameOf Write failed"); process.exit(1); }

const readCall = {
  conversationId: "conv-12345",
  toolCall: {
    name: "view_file",
    args: { AbsolutePath: "/path/to/readme.md" }
  }
};
if (proto.filePathOf(readCall) !== "/path/to/readme.md") { console.error("filePathOf AbsolutePath failed"); process.exit(1); }
if (proto.toolNameOf(readCall) !== "Read") { console.error("toolNameOf Read failed"); process.exit(1); }

console.log("OK2");
' "$PROTO")

[[ "$RES" == "OK2" ]] || { echo "Failed test 2"; exit 1; }

# 3. Test allow output
ALLOW_OUT=$(node -e '
const proto = require(process.argv[1]);
const input = {
  conversationId: "conv-12345",
  toolCall: { name: "run_command", args: { CommandLine: "ls" } }
};
proto.allow(input);
' "$PROTO")

[[ "$ALLOW_OUT" == '{"decision":"allow"}' ]] || { echo "Failed allow test: $ALLOW_OUT"; exit 1; }

# 4. Test deny output
DENY_OUT=$(node -e '
const proto = require(process.argv[1]);
const input = {
  conversationId: "conv-12345",
  toolCall: { name: "run_command", args: { CommandLine: "rm -rf /" } }
};
proto.deny(input, "Dangerous command");
' "$PROTO")

[[ "$DENY_OUT" == '{"decision":"deny","reason":"Dangerous command"}' ]] || { echo "Failed deny test: $DENY_OUT"; exit 1; }

# 5. Test emitSessionStartContext (PreInvocation) output
INIT_OUT=$(node -e '
const proto = require(process.argv[1]);
const input = {
  conversationId: "conv-12345",
  invocationNum: 1
};
proto.emitSessionStartContext(input, "Welcome to Beacon");
' "$PROTO")

[[ "$INIT_OUT" == '{"injectSteps":[{"ephemeralMessage":"Welcome to Beacon"}]}' ]] || { echo "Failed emitSessionStartContext test: $INIT_OUT"; exit 1; }

# 6. Verify backward compatibility with Claude & Cursor
RES=$(node -e '
const proto = require(process.argv[1]);
// Claude
const claudeInput = { tool_input: { command: "npm test" } };
if (proto.isAntigravity(claudeInput)) { console.error("Claude misidentified as AGY"); process.exit(1); }
if (proto.ideOf(claudeInput) !== "claude") { console.error("Claude ideOf failed"); process.exit(1); }

// Cursor
const cursorInput = { hook_event_name: "beforeShellExecution", command: "npm test" };
if (proto.isAntigravity(cursorInput)) { console.error("Cursor misidentified as AGY"); process.exit(1); }
if (proto.ideOf(cursorInput) !== "cursor") { console.error("Cursor ideOf failed"); process.exit(1); }

console.log("OK6");
' "$PROTO")

[[ "$RES" == "OK6" ]] || { echo "Failed backward compatibility test"; exit 1; }

echo "All hook-protocol Antigravity self-tests passed!"
