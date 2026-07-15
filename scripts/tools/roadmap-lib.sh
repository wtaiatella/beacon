#!/usr/bin/env bash
# Shared helpers for roadmap numbering (ROAD-XX). Source from other scripts:
#   ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
#   # shellcheck source=roadmap-lib.sh
#   source "$(dirname "${BASH_SOURCE[0]}")/roadmap-lib.sh"
# shellcheck shell=bash

# Default roadmap tree root: ROADMAP_FILE env (directory), else docs/roadmaps under repo root.
# ROADMAP_FILE must point at the directory containing ROAD-NN-*.md and optional completed/.
roadmap_default_root() {
  local root="${1:-}"
  if [[ -n "${ROADMAP_FILE:-}" ]]; then
    if [[ "${ROADMAP_FILE}" = /* ]]; then
      echo "${ROADMAP_FILE}"
    else
      echo "${root%/}/${ROADMAP_FILE}"
    fi
    return
  fi
  echo "${root%/}/docs/roadmaps"
}

# Maximum numeric id from filenames matching ^ROAD-(\d+)-.+\.md$ in root and root/completed/.
roadmap_max_filename_id() {
  local root="$1"
  local max=0 id
  [[ -d "$root" ]] || { echo "0"; return 0; }
  local f base
  shopt -s nullglob
  for f in "$root"/*.md; do
    [[ -f "$f" ]] || continue
    base=$(basename "$f")
    [[ "$base" =~ ^ROAD-([0-9]+)-.+\.md$ ]] || continue
    id=$((10#${BASH_REMATCH[1]}))
    ((id > max)) && max=$id
  done
  if [[ -d "$root/completed" ]]; then
    for f in "$root/completed"/*.md; do
      [[ -f "$f" ]] || continue
      base=$(basename "$f")
      [[ "$base" =~ ^ROAD-([0-9]+)-.+\.md$ ]] || continue
      id=$((10#${BASH_REMATCH[1]}))
      ((id > max)) && max=$id
    done
  fi
  shopt -u nullglob
  echo "$max"
}

# Next free ROAD number: max(filename ids) + 1 across active + completed/.
roadmap_next_id() {
  local root="$1"
  local max
  max=$(roadmap_max_filename_id "$root")
  echo $((max + 1))
}
