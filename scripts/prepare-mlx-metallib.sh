#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_PATH="${YLLMKIT_MLX_METALLIB_OUTPUT:-${ROOT_DIR}/default.metallib}"
BUILD_DIR="${YLLMKIT_MLX_METAL_BUILD_DIR:-${ROOT_DIR}/.mlx-metal-build}"
MODULE_CACHE="${BUILD_DIR}/module-cache"

find_mlx_checkout() {
    local candidates=(
        "${YLLMKIT_MLX_SWIFT_CHECKOUT:-}"
        "${ROOT_DIR}/.build/checkouts/mlx-swift"
        "/private/tmp/yLLMKit-smoke-build/checkouts/mlx-swift"
    )

    for candidate in "${candidates[@]}"; do
        if [[ -n "${candidate}" && -d "${candidate}/Source/Cmlx/mlx/mlx/backend/metal/kernels" ]]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done

    local discovered
    discovered="$(find "${ROOT_DIR}/.build" /private/tmp -path '*/checkouts/mlx-swift/Source/Cmlx/mlx/mlx/backend/metal/kernels' -type d 2>/dev/null | head -n 1 || true)"
    if [[ -n "${discovered}" ]]; then
        printf '%s\n' "${discovered%/Source/Cmlx/mlx/mlx/backend/metal/kernels}"
        return 0
    fi

    return 1
}

find_metal_tool() {
    if [[ -n "${YLLMKIT_METAL_TOOL:-}" && -x "${YLLMKIT_METAL_TOOL}" ]]; then
        printf '%s\n' "${YLLMKIT_METAL_TOOL}"
        return 0
    fi

    if [[ -n "${METAL_TOOLCHAIN_DIR:-}" && -x "${METAL_TOOLCHAIN_DIR}/usr/bin/metal" ]]; then
        printf '%s\n' "${METAL_TOOLCHAIN_DIR}/usr/bin/metal"
        return 0
    fi

    local xcrun_metal
    xcrun_metal="$(DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" xcrun -sdk macosx --find metal 2>/dev/null || true)"
    if [[ -n "${xcrun_metal}" && -x "${xcrun_metal}" ]] && "${xcrun_metal}" --version >/dev/null 2>&1; then
        printf '%s\n' "${xcrun_metal}"
        return 0
    fi

    local discovered
    discovered="$(find /Volumes /private/tmp -path '*/Metal.xctoolchain/usr/bin/metal' -type f 2>/dev/null | head -n 1 || true)"
    if [[ -n "${discovered}" && -x "${discovered}" ]]; then
        printf '%s\n' "${discovered}"
        return 0
    fi

    return 1
}

MLX_CHECKOUT="$(find_mlx_checkout)" || {
    echo "Could not find the mlx-swift checkout. Run swift build once, or set YLLMKIT_MLX_SWIFT_CHECKOUT." >&2
    exit 1
}

METAL_TOOL="$(find_metal_tool)" || {
    cat >&2 <<'EOF'
Could not find a working Metal compiler.

Try:
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -downloadComponent MetalToolchain -exportPath /private/tmp/yLLMKit-MetalToolchain
  hdiutil attach /private/tmp/yLLMKit-MetalToolchain/MetalToolchain-*.exportedBundle/Restore/*.dmg -nobrowse -readonly -mountpoint /private/tmp/yLLMKit-MetalToolchainMount
  METAL_TOOLCHAIN_DIR=/private/tmp/yLLMKit-MetalToolchainMount/Metal.xctoolchain ./scripts/prepare-mlx-metallib.sh
EOF
    exit 1
}

KERNEL_DIR="${MLX_CHECKOUT}/Source/Cmlx/mlx/mlx/backend/metal/kernels"
INCLUDE_DIR="${MLX_CHECKOUT}/Source/Cmlx/mlx"

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}" "${MODULE_CACHE}" "$(dirname "${OUTPUT_PATH}")"

kernels=()
while IFS= read -r kernel; do
    kernels+=("${kernel}")
done < <(find "${KERNEL_DIR}" -name '*.metal' ! -name '*_nax.metal' | sort)

echo "Using MLX checkout: ${MLX_CHECKOUT}"
echo "Using Metal compiler: ${METAL_TOOL}"
echo "Compiling ${#kernels[@]} Metal kernels..."

air_files=()
for kernel in "${kernels[@]}"; do
    relative="${kernel#"${KERNEL_DIR}/"}"
    air_name="${relative%.metal}.air"
    air_path="${BUILD_DIR}/${air_name//\//_}"
    echo "  ${relative}"

    "${METAL_TOOL}" \
        -x metal \
        -Wall \
        -Wextra \
        -fno-fast-math \
        -Wno-c++17-extensions \
        -Wno-c++20-extensions \
        -fmodules-cache-path="${MODULE_CACHE}" \
        -c "${kernel}" \
        -I"${INCLUDE_DIR}" \
        -o "${air_path}"

    air_files+=("${air_path}")
done

"${METAL_TOOL}" "${air_files[@]}" -o "${OUTPUT_PATH}"

echo "Wrote ${OUTPUT_PATH}"
