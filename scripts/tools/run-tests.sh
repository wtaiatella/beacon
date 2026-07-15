#!/usr/bin/env bash
# Auto-detect test framework in a target directory and run tests.
# Supports: npm/yarn/pnpm test, pytest, go test, mvn test, gradle test, cargo test.
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <target-directory>"
  echo "  Auto-detects the test framework in the directory and runs tests."
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
  usage
  exit 0
fi

TARGET="$1"
if [[ ! -d "$TARGET" ]]; then
  echo "Error: not a directory: $TARGET" >&2
  exit 1
fi
cd "$TARGET"

run_npm_test() {
  if [[ -f yarn.lock ]]; then yarn test; elif [[ -f pnpm-lock.yaml ]]; then pnpm test; else npm test; fi
}

if [[ -f package.json ]] && grep -qE '"test"[[:space:]]*:' package.json; then
  run_npm_test
elif [[ -f pytest.ini ]] || { [[ -f pyproject.toml ]] && grep -qE '\[tool\.pytest|pytest' pyproject.toml 2>/dev/null; }; then
  python -m pytest
elif [[ -f go.mod ]]; then
  go test ./...
elif [[ -f pom.xml ]]; then
  mvn test
elif [[ -f build.gradle ]] || [[ -f build.gradle.kts ]]; then
  if [[ -x ./gradlew ]]; then ./gradlew test; else gradle test; fi
elif [[ -f Cargo.toml ]]; then
  cargo test
else
  echo "Warning: No test framework detected in $TARGET" >&2
  exit 0
fi
