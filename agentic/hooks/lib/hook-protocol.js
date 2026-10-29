#!/usr/bin/env node
/**
 * Tri-protocol helpers for agentic hooks (Claude Code + Cursor + Google Antigravity).
 *
 * Claude Code (typical):
 *   input:  { tool_input: { command | file_path }, ... }
 *   block:  exit 2 + reason on stderr
 *   allow:  exit 0 (no stdout)
 *   sessionStart out: { hookSpecificOutput: { hookEventName, additionalContext } }
 *
 * Cursor:
 *   input:  { hook_event_name, command | file_path | tool_input, ... }
 *   block:  stdout JSON { permission: "deny", user_message, agent_message } (+ exit 0)
 *           OR exit 2 (also treated as deny)
 *   allow:  stdout JSON { permission: "allow" } (for gating hooks) or exit 0
 *   sessionStart out: { additional_context: "..." }
 *
 * Google Antigravity (AGY):
 *   input:  { toolCall: { name, args: { CommandLine | TargetFile | AbsolutePath } }, conversationId, workspacePaths, ... }
 *   block:  stdout JSON { decision: "deny", reason: "..." } (+ exit 0)
 *   allow:  stdout JSON { decision: "allow" } (+ exit 0)
 *   preInvocation out: { injectSteps: [ { ephemeralMessage: "..." } ] }
 *
 * Usage from hook scripts:
 *   const proto = require("./lib/hook-protocol");
 *   const input = proto.readStdinJson();
 *   const cmd = proto.commandOf(input);
 *   proto.deny(input, "reason"); // or proto.allow(input)
 */
'use strict';

const fs = require('fs');

function readStdinJson() {
   try {
      const raw = fs.readFileSync(0, 'utf8');
      if (!raw || !raw.trim()) return {};
      return JSON.parse(raw);
   } catch (_) {
      return {};
   }
}

/** Prefer HOOK_INPUT env (when the script uses a node heredoc that steals stdin). */
function readInput() {
   if (
      typeof process.env.HOOK_INPUT === 'string' &&
      process.env.HOOK_INPUT.length
   ) {
      try {
         return JSON.parse(process.env.HOOK_INPUT);
      } catch (_) {
         return {};
      }
   }
   return readStdinJson();
}

function isCursor(input) {
   if (!input || typeof input !== 'object') return false;
   const event = String(input.hook_event_name || input.hookEventName || '');
   return Boolean(
      input.cursor_version ||
      (Array.isArray(input.workspace_roots) && input.workspace_roots.length) ||
      // Cursor event names are lower camel-case (postToolUse, beforeReadFile).
      // Claude Code may also send hook_event_name, but values are PascalCase
      // (PostToolUse, SessionEnd), so do not treat mere presence as Cursor.
      /^[a-z]/.test(event)
   );
}

function isAntigravity(input) {
   if (!input || typeof input !== 'object') return false;
   return Boolean(
      input.toolCall ||
      (Array.isArray(input.workspacePaths) && input.workspacePaths.length) ||
      input.artifactDirectoryPath ||
      input.invocationNum !== undefined ||
      input.initialNumSteps !== undefined ||
      input.executionNum !== undefined ||
      (input.conversationId && !isCursor(input))
   );
}

function toolInput(input) {
   if (input && input.toolCall && typeof input.toolCall.args === 'object' && input.toolCall.args !== null) {
      return input.toolCall.args;
   }
   const ti = input && input.tool_input;
   if (!ti) return {};
   if (typeof ti === 'string') {
      try {
         return JSON.parse(ti);
      } catch (_) {
         return {};
      }
   }
   return typeof ti === 'object' ? ti : {};
}

function commandOf(input) {
   const ti = toolInput(input);
   if (typeof ti.CommandLine === 'string' && ti.CommandLine) return ti.CommandLine;
   if (typeof ti.command === 'string' && ti.command) return ti.command;
   if (typeof input.command === 'string' && input.command) return input.command;
   return '';
}

function filePathOf(input) {
   const ti = toolInput(input);
   return (
      ti.Path ||
      ti.TargetFile ||
      ti.AbsolutePath ||
      ti.file_path ||
      ti.filePath ||
      (input &&
         (input.Path ||
            input.file_path ||
            input.filePath ||
            input.TargetFile ||
            input.AbsolutePath)) ||
      ''
   );
}

function cwdOf(input, fallback) {
   const ti = toolInput(input);
   return (
      (input && input.cwd) ||
      ti.Cwd ||
      ti.working_directory ||
      ti.cwd ||
      (Array.isArray(input && input.workspacePaths) && input.workspacePaths[0]) ||
      fallback ||
      ''
   );
}

const path = require('path');

/**
 * Walk up from a candidate directory looking for a Beacon workspace marker
 * (scripts/tools/spec-status.sh or WORKSPACE.md). When a user opens Claude/Cursor/AGY
 * inside a child repo (e.g. <workspace>/br-tax-engine), this resolves the outer
 * workspace root. If the candidate does not exist on disk (e.g. unit test virtual path)
 * or no ancestor has a marker, returns the original candidate unchanged.
 */
function findBeaconWorkspaceRoot(candidate) {
   if (!candidate || typeof candidate !== 'string') return '';
   try {
      if (!fs.existsSync(candidate)) return candidate;
      let cur = path.resolve(candidate);
      while (cur && cur !== path.dirname(cur)) {
         if (
            fs.existsSync(path.join(cur, 'scripts', 'tools', 'spec-status.sh')) ||
            fs.existsSync(path.join(cur, 'WORKSPACE.md')) ||
            fs.existsSync(path.join(cur, 'agentic', 'AGENTS.md'))
         ) {
            return cur;
         }
         cur = path.dirname(cur);
      }
   } catch (_) {
      // fail-open
   }
   return candidate;
}

function isBeaconWorkspace(root) {
   if (!root || typeof root !== 'string') return false;
   try {
      return (
         fs.existsSync(path.join(root, 'scripts', 'tools', 'spec-status.sh')) ||
         fs.existsSync(path.join(root, 'WORKSPACE.md')) ||
         fs.existsSync(path.join(root, 'agentic', 'AGENTS.md')) ||
         fs.existsSync(path.join(root, 'docs', 'specs'))
      );
   } catch (_) {
      return false;
   }
}

function workspaceRootOf(input, fallback = process.cwd()) {
   if (input && Array.isArray(input.workspacePaths) && input.workspacePaths.length > 0) {
      return findBeaconWorkspaceRoot(input.workspacePaths[0]);
   }
   if (input && Array.isArray(input.workspace_roots) && input.workspace_roots.length > 0) {
      return findBeaconWorkspaceRoot(input.workspace_roots[0]);
   }
   if (process.env.HOOK_ROOT) {
      return findBeaconWorkspaceRoot(process.env.HOOK_ROOT);
   }
   if (process.env.CLAUDE_PROJECT_DIR) {
      return findBeaconWorkspaceRoot(process.env.CLAUDE_PROJECT_DIR);
   }
   if (input && typeof input.cwd === 'string' && input.cwd) {
      return findBeaconWorkspaceRoot(input.cwd);
   }
   return fallback ? findBeaconWorkspaceRoot(fallback) : fallback;
}

function sessionIdOf(input) {
   return (
      (input &&
         (input.session_id ||
            input.conversation_id ||
            input.sessionId ||
            input.conversationId)) ||
      ''
   );
}

function ideOf(input, runtimeHint = '') {
   if (runtimeHint === 'claude' || runtimeHint === 'cursor' || runtimeHint === 'antigravity') return runtimeHint;
   if (isAntigravity(input)) return 'antigravity';
   return isCursor(input) ? 'cursor' : 'claude';
}

function toolNameOf(input) {
   let raw = '';
   if (input && input.toolCall && input.toolCall.name) {
      raw = input.toolCall.name;
   } else {
      raw =
         (input &&
            (input.tool_name ||
               input.toolName ||
               input.tool ||
               input.name ||
               input.hook_tool_name)) ||
         '';
   }
   const s = String(raw || '').trim();
   if (!s) return 'unknown';
   if (s === 'Bash' || s === 'run_command') return 'Shell';
   if (s === 'ReadFile' || s === 'view_file' || s === 'read_file') return 'Read';
   if (
      s === 'Write' ||
      s === 'Edit' ||
      s === 'MultiEdit' ||
      s === 'write_to_file' ||
      s === 'replace_file_content' ||
      s === 'multi_replace_file_content' ||
      s === 'write_file' ||
      s === 'edit_file'
   )
      return 'Write';
   return s;
}

function durationOf(input) {
   const raw =
      input &&
      (input.duration_ms ??
         input.durationMs ??
         input.duration ??
         input.elapsed_ms ??
         input.elapsedMs);
   if (raw === undefined || raw === null || raw === '') return '';
   const n = Number(raw);
   return Number.isFinite(n) ? String(Math.round(n)) : '';
}

function allow(input) {
   if (isAntigravity(input)) {
      process.stdout.write(JSON.stringify({ decision: 'allow' }));
   } else if (isCursor(input)) {
      // Gating hooks expect a permission decision; observers can ignore it.
      process.stdout.write(JSON.stringify({ permission: 'allow' }));
   }
   process.exit(0);
}

function postToolUseDone(input) {
   if (isAntigravity(input)) {
      process.stdout.write(JSON.stringify({}));
   }
   process.exit(0);
}

function deny(input, reason) {
   const msg = String(reason || 'Blocked by hook');
   if (isAntigravity(input)) {
      process.stdout.write(
         JSON.stringify({
            decision: 'deny',
            reason: msg,
         })
      );
      process.exit(0);
   }
   if (isCursor(input)) {
      process.stdout.write(
         JSON.stringify({
            permission: 'deny',
            user_message: msg,
            agent_message: msg,
         })
      );
      process.exit(0);
   }
   process.stderr.write(msg.endsWith('\n') ? msg : msg + '\n');
   process.exit(2);
}

function emitSessionStartContext(input, text) {
   const ctx = String(text || '');
   if (isAntigravity(input)) {
      // Avoid re-injecting the full workspace context on tool-call continuation steps within the same turn
      if (Number(input.executionNum) > 0 || !ctx.trim()) {
         process.stdout.write(JSON.stringify({}));
         process.exit(0);
      }
      process.stdout.write(
         JSON.stringify({
            injectSteps: [
               {
                  ephemeralMessage: ctx,
               },
            ],
         })
      );
   } else if (isCursor(input)) {
      process.stdout.write(JSON.stringify({ additional_context: ctx }));
   } else {
      process.stdout.write(
         JSON.stringify({
            hookSpecificOutput: {
               hookEventName: 'SessionStart',
               additionalContext: ctx,
            },
         })
      );
   }
   process.exit(0);
}

module.exports = {
   readStdinJson,
   readInput,
   isCursor,
   isAntigravity,
   toolInput,
   commandOf,
   filePathOf,
   cwdOf,
   findBeaconWorkspaceRoot,
   isBeaconWorkspace,
   workspaceRootOf,
   sessionIdOf,
   ideOf,
   toolNameOf,
   durationOf,
   allow,
   postToolUseDone,
   deny,
   emitSessionStartContext,
};
