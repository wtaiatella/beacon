#!/usr/bin/env node
/**
 * Dual-protocol helpers for agentic hooks (Claude Code + Cursor).
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
   return Boolean(
      input.hook_event_name ||
      input.cursor_version ||
      (Array.isArray(input.workspace_roots) && input.workspace_roots.length)
   );
}

function toolInput(input) {
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
   if (typeof ti.command === 'string' && ti.command) return ti.command;
   if (typeof input.command === 'string' && input.command) return input.command;
   return '';
}

function filePathOf(input) {
   const ti = toolInput(input);
   return (
      ti.file_path ||
      ti.filePath ||
      (input && (input.file_path || input.filePath)) ||
      ''
   );
}

function cwdOf(input, fallback) {
   const ti = toolInput(input);
   return (
      (input && input.cwd) || ti.working_directory || ti.cwd || fallback || ''
   );
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

function ideOf(input) {
   return isCursor(input) ? 'cursor' : 'claude';
}

function toolNameOf(input) {
   const raw =
      (input &&
         (input.tool_name ||
            input.toolName ||
            input.tool ||
            input.name ||
            input.hook_tool_name)) ||
      '';
   const s = String(raw || '').trim();
   if (!s) return 'unknown';
   // Normalize enough for cross-IDE summaries without hiding native details.
   if (s === 'Bash') return 'Shell';
   if (s === 'ReadFile') return 'Read';
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
   if (isCursor(input)) {
      // Gating hooks expect a permission decision; observers can ignore it.
      process.stdout.write(JSON.stringify({ permission: 'allow' }));
   }
   process.exit(0);
}

function deny(input, reason) {
   const msg = String(reason || 'Blocked by hook');
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
   if (isCursor(input)) {
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
   toolInput,
   commandOf,
   filePathOf,
   cwdOf,
   sessionIdOf,
   ideOf,
   toolNameOf,
   durationOf,
   allow,
   deny,
   emitSessionStartContext,
};
