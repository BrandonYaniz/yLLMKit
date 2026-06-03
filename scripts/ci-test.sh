#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRATCH_PATH="${YLLMKIT_CI_SCRATCH_PATH:-${TMPDIR:-/tmp}/yLLMKit-ci-build}"

cd "$ROOT_DIR"

echo "Swift toolchain:"
swift --version

echo "Resetting scratch path: $SCRATCH_PATH"
rm -rf "$SCRATCH_PATH"

echo "Running package tests"
swift test \
  --scratch-path "$SCRATCH_PATH" \
  --enable-xctest \
  --disable-swift-testing
