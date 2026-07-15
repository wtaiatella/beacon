---
description: Clone a target repository into the workspace root and register it in the multi-repo inventory
argument-hint: "<git-ssh-or-https-url> [target-dir]"
---

Treat `$ARGUMENTS` as a git repository URL (SSH or HTTPS), optionally followed by a target directory name.

## Workflow

1. If `$ARGUMENTS` is empty, ask the user for the repo URL and show the usage: `/clone <git-ssh-or-https-url> [target-dir]`.
2. Run the clone helper (it clones into the workspace root, derives the folder name from the URL unless a target dir is given, refuses to overwrite an existing folder, records the clone in session memory, and prints the updated inventory):

   ```bash
   scripts/tools/clone-repo.sh $ARGUMENTS
   ```

3. On failure, report the exact error and suggest a concrete fix — do not retry blindly:
   - **auth / permission denied:** check SSH key access to the remote (e.g. `ssh -T git@…`) or use the HTTPS URL.
   - **target already exists:** re-run with an explicit different target dir.
   - **bad URL:** confirm the repo path.
4. On success, confirm the repo name and branch, and remind the user it will now appear automatically in the session-start repo inventory.

## Guardrails

- Only clone into a single folder directly under the workspace root — never outside it, never a nested path.
- Child (target) repos are gitignored by the workspace **by design**; do **not** `git add` them to the workspace repo.
- Do not run any other git write operations on the cloned repo beyond the clone itself.
