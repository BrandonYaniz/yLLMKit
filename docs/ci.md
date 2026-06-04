# Continuous Integration

yLLMKit runs package validation through GitHub Actions on macOS. The workflow checks out the package, reports the selected Xcode and Swift toolchain, resolves package dependencies, and runs the same test script contributors can run locally.

The shared entry point is `scripts/ci-test.sh`. It resets a scratch build path before invoking `swift test --enable-xctest --disable-swift-testing`, which keeps CI runs from passing or failing because of stale local build products. Contributors can override the scratch path with `YLLMKIT_CI_SCRATCH_PATH` when they want build artifacts outside the default temporary directory.

Local XCTest execution requires a complete Xcode or Command Line Tools installation that can resolve the macOS SDK platform path through `xcrun`. If `swift test` builds successfully but fails while launching XCTest, check `xcrun --sdk macosx --show-sdk-platform-path` and select a complete Xcode installation with `DEVELOPER_DIR` or `xcode-select`.

Live smoke tests are intentionally opt-in and are not part of the default CI workflow.

MLX live smoke downloads model data and requires the Metal toolchain:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer YLLMKIT_RUN_MLX_SMOKE=1 swift test --enable-xctest --disable-swift-testing --filter yLLMKitMLXTests.testLiveMLXSmokeWhenEnabled
```

OpenAI and Anthropic live smokes use real hosted provider requests. Provide credentials and the exact model to validate at runtime:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer OPENAI_API_KEY=... YLLMKIT_RUN_OPENAI_SMOKE=1 YLLMKIT_OPENAI_SMOKE_MODEL=... swift test --enable-xctest --disable-swift-testing --filter yLLMKitOpenAITests.testLiveOpenAISmokeWhenEnabled
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ANTHROPIC_API_KEY=... YLLMKIT_RUN_ANTHROPIC_SMOKE=1 YLLMKIT_ANTHROPIC_SMOKE_MODEL=... swift test --enable-xctest --disable-swift-testing --filter yLLMKitAnthropicTests.testLiveAnthropicSmokeWhenEnabled
```
