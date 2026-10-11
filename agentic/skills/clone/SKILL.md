---
name: clone
description: "Clone a target repository into the workspace root and register it in the multi-repo inventory. Use when the user runs /clone with a git URL (and optional target dir)."
disable-model-invocation: true
---

# Clone

Clone a git repository into a single folder directly under the workspace root so it joins the
dynamically detected child-repo inventory (see root `CLAUDE.md` / session-init). The workspace
tracks everything by default (it doubles as a real project's own repo — specs, knowledge, etc.),
so child (target) repos are explicitly excluded: the clone helper appends a `/<dir>/` entry to
`.gitignore` for each one.

## Trigger & Input

- **Trigger:** `/clone <git-ssh-or-https-url> [target-dir]` — arrives as `$ARGUMENTS`.
- **Required:** a git repository URL (SSH or HTTPS).
- **Optional:** target directory name (single path segment under the workspace root). If omitted,
  the helper derives the folder name from the URL (last path segment, without `.git`).

## Workflow

1. If `$ARGUMENTS` is empty, ask the user for the repo URL and show the usage:
   `/clone <git-ssh-or-https-url> [target-dir]`.
2. Run the clone helper (clones into the workspace root, derives the folder name unless a target
   dir is given, refuses to overwrite an existing folder, appends `/<dir>/` to `.gitignore`,
   registers the folder in `.vscode/settings.json` → `git.scanRepositories` for Cursor/VS Code
   Source Control, records the clone in session memory, and prints the updated inventory):

   ```bash
   scripts/tools/clone-repo.sh $ARGUMENTS
   ```

3. On failure, report the exact error and suggest a concrete fix — do not retry blindly:
   - **auth / permission denied:** check SSH key access to the remote (e.g. `ssh -T git@…`) or use
     the HTTPS URL.
   - **target already exists:** re-run with an explicit different target dir.
   - **bad URL:** confirm the repo path.
4. On success, confirm the repo name and branch, remind the user it will appear in the session-start
   repo inventory, and that Source Control may need **Developer: Reload Window** once if the new
   repo does not show up immediately.

## Guardrails

- Only clone into a single folder directly under the workspace root — never outside it, never a
  nested path.
- Child (target) repos must be excluded from the workspace's own history — the clone helper handles
  this by appending a `.gitignore` entry; do **not** `git add` them to the workspace repo.
- Do not run any other git write operations on the cloned repo beyond the clone itself.
