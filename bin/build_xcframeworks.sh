#!/bin/bash

set -e

# Array of all targets to build
PRODUCTS=(
    # Public products
    "EmbraceIO"
    "EmbraceCore"
    "EmbraceSemantics"
    "EmbraceMacros"
    "EmbraceCrash"
    "EmbraceKSCrashBacktraceSupport"
    "EmbraceCrashlyticsSupport"

    # Internal targets
    "EmbraceCommonInternal"
    "EmbraceAtomicsShim"
    "EmbraceCaptureService"
    "EmbraceConfiguration"
    "EmbraceConfigInternal"
    "EmbraceOTelInternal"
    "EmbraceStorageInternal"
    "EmbraceUploadInternal"
    "EmbraceCoreDataInternal"
    "EmbraceObjCUtilsInternal"
    
    # External dependencies - OpenTelemetry
    "OpenTelemetrySdk"
    "OpenTelemetryApi"
    
    # External dependencies - KSCrash
    "KSCrashRecording"
    "KSCrashRecordingCore"
    "KSCrashCore"
    "KSCrashDemangleFilter"
)

# SDKs to build for
SDKS="iphoneos,iphonesimulator"

# ==============================================================================
# Prepare KSCrash source for patching
# ==============================================================================

echo "=========================================="
echo "Preparing KSCrash source..."
echo "=========================================="

# Get KSCrash dependency info from Package.resolved
get_dependency_info() {
  local DEPENDENCY_NAME=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  local INFO=$(jq -r --arg NAME "$DEPENDENCY_NAME" '.pins[] | select(.identity == $NAME) | { url: .location, version: (.state.version // .state.branch) }' Package.resolved)
  echo "$INFO"
}

KSCRASH_INFO=$(get_dependency_info "KSCrash")
KSCRASH_URL=$(echo "$KSCRASH_INFO" | jq -r '.url')
KSCRASH_VERSION=$(echo "$KSCRASH_INFO" | jq -r '.version')

if [ -z "$KSCRASH_URL" ] || [ -z "$KSCRASH_VERSION" ]; then
  echo "Error: Could not find KSCrash dependency in Package.resolved"
  exit 1
fi

echo "KSCrash Version: $KSCRASH_VERSION"

# Create temporary directory for KSCrash source
TEMP_KSCRASH_DIR="temp_kscrash"
rm -rf "$TEMP_KSCRASH_DIR"
mkdir -p "$TEMP_KSCRASH_DIR"

# Clone KSCrash at the specific version
echo "Cloning KSCrash v${KSCRASH_VERSION}..."
if git ls-remote --tags "$KSCRASH_URL" | grep -q "refs/tags/v${KSCRASH_VERSION}$"; then
    git clone --branch "v${KSCRASH_VERSION}" --depth 1 "$KSCRASH_URL" "$TEMP_KSCRASH_DIR/KSCrash"
else
    git clone --branch "$KSCRASH_VERSION" --depth 1 "$KSCRASH_URL" "$TEMP_KSCRASH_DIR/KSCrash"
fi

echo "✓ KSCrash source ready"
echo ""

# ==============================================================================
# Build XCFrameworks
# ==============================================================================

echo "Starting XCFramework build process..."
echo "SDKs: ${SDKS}"
echo "Products: ${PRODUCTS[@]}"
echo ""

echo "=========================================="
echo "Building all XCFrameworks..."
echo "=========================================="

xccache pkg build "${PRODUCTS[@]}" --sdk="${SDKS}" --out="binaries"

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✓ All XCFrameworks built successfully!"
    echo "=========================================="
    echo ""
else
    echo "✗ XCFramework build failed"
    exit 1
fi

# ==============================================================================
# Patch KSCrash XCFrameworks
# ==============================================================================

echo "=========================================="
echo "Patching KSCrash XCFrameworks..."
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "$SCRIPT_DIR/patch-kscrash-xcframeworks.sh" "$TEMP_KSCRASH_DIR/KSCrash" "binaries"

# Cleanup
rm -rf "$TEMP_KSCRASH_DIR"

echo "=========================================="
echo "Build complete!"
echo "=========================================="
