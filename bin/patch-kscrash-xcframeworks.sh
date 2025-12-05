#!/bin/bash
set -e

# ==============================================================================
# Script: patch-kscrash-xcframeworks.sh
# ==============================================================================
# Purpose: Automatically patch KSCrash XCFrameworks to fix cross-module header imports
#
# Problem: KSCrash uses quote-style imports (#import "Header.h") which work in
# Swift Package Manager but fail in XCFrameworks. XCFrameworks need framework-
# style imports (#import <Framework/Header.h>) to locate headers across modules.
#
# This script solves the issue by:
# 1. Scanning all source headers to build a map of which header belongs to which module
# 2. Copying `KSCrashNamespace.h` to all frameworks (needed by all modules)
# 3. Rewriting cross-module imports from quote-style to framework-style
#
# Example transformation:
#   Before: #import "KSCrashReportFilter.h"
#   After:  #import <KSCrashRecording/KSCrashReportFilter.h>
# ==============================================================================

# Expect the KSCrash source directory as first argument
KSCRASH_SOURCE_DIR="${1:-.}"
XCFRAMEWORKS_DIR="${2:-binaries}"

echo "Patching KSCrash XCFrameworks for cross-module imports..."
echo "Source directory: $KSCRASH_SOURCE_DIR"
echo "XCFrameworks directory: $XCFRAMEWORKS_DIR"

# ------------------------------------------------------------------------------
# Step 1: Locate the KSCrashNamespace.h header
# ------------------------------------------------------------------------------
# This header is needed by almost all modules. It defines namespace macros to
# prevent symbol conflicts when multiple versions of KSCrash exist in the same binary.
# This is included since KSCrash 2.4.0, so this is also needed to be copied to each
# framework's Headers directory.
NAMESPACE_HEADER="$KSCRASH_SOURCE_DIR/Sources/KSCrashCore/include/KSCrashNamespace.h"

# Verify the file exists before proceeding
if [ ! -f "$NAMESPACE_HEADER" ]; then
    echo "Error: KSCrashNamespace.h not found at $NAMESPACE_HEADER"
    exit 1
fi

echo "Analyzing source structure..."

# ------------------------------------------------------------------------------
# Step 2: Build a header-to-module mapping
# ------------------------------------------------------------------------------
# We need to know which module each header belongs to, so we can determine
# when an import crosses module boundaries.
#
# Example mapping:
#   KSCrashReportFilter.h -> KSCrashRecording
#   KSJSONCodecObjC.h -> KSCrashRecordingCore
#   KSCrashNamespace.h -> KSCrashCore

# Use process ID to create a unique temp file
HEADER_MAP_FILE="/tmp/kscrash_header_map_$$.txt"
rm -f "$HEADER_MAP_FILE"

# Scan all 'include' directories under Sources/
for source_dir in "$KSCRASH_SOURCE_DIR"/Sources/*/include; do
    if [ -d "$source_dir" ]; then
        # Extract module name from path
        # Example: Sources/KSCrashRecording/include -> KSCrashRecording
        module_name=$(basename $(dirname "$source_dir"))

        # Find all .h files in this module's include directory
        find "$source_dir" -name "*.h" -type f | while read -r header_path; do
            # Get just the filename (e.g., "KSCrash.h")
            header_name=$(basename "$header_path")

            # Write to map file: HeaderName=ModuleName
            echo "$header_name=$module_name" >> "$HEADER_MAP_FILE"
        done
    fi
done

header_count=$(wc -l < "$HEADER_MAP_FILE" | tr -d ' ')
echo "Found $header_count public headers across modules"

# ------------------------------------------------------------------------------
# Helper function: get_module_for_header
# ------------------------------------------------------------------------------
# Given a header filename, returns which module it belongs to
# Example: get_module_for_header "KSCrash.h" -> "KSCrashRecording"
get_module_for_header() {
    local header="$1"
    # Search the map file for this header and extract the module name
    grep "^${header}=" "$HEADER_MAP_FILE" 2>/dev/null | cut -d'=' -f2 | head -1
}

# ------------------------------------------------------------------------------
# Main function: patch_framework_headers
# ------------------------------------------------------------------------------
# Processes all headers in a single framework, patching cross-module imports
# and copying necessary shared headers.
#
# Parameters:
#   $1 - framework_path: Path to .framework directory
#   $2 - current_module: Name of the module this framework belongs to
#
# Example: patch_framework_headers "KSCrashRecording.framework" "KSCrashRecording"
patch_framework_headers() {
    local framework_path="$1"
    local current_module="$2"

    # Validate framework path exists
    if [ ! -d "$framework_path" ]; then
        echo "Framework not found: $framework_path"
        return
    fi

    # All framework headers are in the Headers/ subdirectory
    local headers_dir="$framework_path/Headers"

    # Validate Headers directory exists
    if [ ! -d "$headers_dir" ]; then
        echo "Headers directory not found in $framework_path"
        return
    fi

    echo "Patching headers in $current_module..."

    # --------------------------------------------------------------------------
    # Copy KSCrashNamespace.h to frameworks that need it
    # --------------------------------------------------------------------------
    # KSCrashNamespace.h lives in KSCrashCore, but all other modules include it
    # with quotes: #include "KSCrashNamespace.h"
    # So we need to copy it to each framework's Headers directory
    if [ "$current_module" != "KSCrashCore" ]; then
        if [ ! -f "$headers_dir/KSCrashNamespace.h" ]; then
            cp "$NAMESPACE_HEADER" "$headers_dir/"
            echo "- Copied KSCrashNamespace.h"
        fi
    fi

    # --------------------------------------------------------------------------
    # Process each header file in the framework
    # --------------------------------------------------------------------------
    find "$headers_dir" -name "*.h" -type f | while read -r header; do
        local modified=false             # Track if we made any changes
        local temp_file="${header}.tmp"  # Write to temp file first

        # Read the header line by line
        while IFS= read -r line; do
            # Use regex to detect import/include statements with quotes
            # Matches: #import "Foo.h" or #include "Foo.h" (with optional whitespace)
            if [[ "$line" =~ ^[[:space:]]*#(import|include)[[:space:]]+\"([^\"]+\.h)\" ]]; then
                # Extract matched groups:
                local import_type="${BASH_REMATCH[1]}"      # "import" or "include"
                local imported_header="${BASH_REMATCH[2]}"  # "Path/To/Header.h"
                local base_header=$(basename "$imported_header")  # "Header.h"

                # ----------------------------------------------------------
                # Special case: KSCrashNamespace.h
                # ----------------------------------------------------------
                # This header should ALWAYS use quote-style include because:
                # 1. We copied it to the same directory
                # 2. It's included with #include (not #import)
                # 3. It's not a cross-module dependency (we copied it locally)
                if [ "$base_header" != "KSCrashNamespace.h" ]; then
                    # Lookup which module owns this header
                    local target_module=$(get_module_for_header "$base_header")

                    # Check if this is a cross-module import
                    # Conditions:
                    # 1. target_module is not empty (header exists in our map)
                    # 2. target_module != current_module (it's in a different module)
                    if [ -n "$target_module" ] && [ "$target_module" != "$current_module" ]; then
                        # This is a cross-module import - rewrite it!
                        # Example: #import "KSCrash.h" -> #import <KSCrashRecording/KSCrash.h>
                        local new_line="#${import_type} <${target_module}/${base_header}>"
                        echo "$new_line" >> "$temp_file"
                        modified=true
                    else
                        # Same-module import or unknown header - leave unchanged
                        echo "$line" >> "$temp_file"
                    fi
                else
                    # KSCrashNamespace.h - leave unchanged
                    echo "$line" >> "$temp_file"
                fi
            else
                # Not an import/include line - copy as-is
                echo "$line" >> "$temp_file"
            fi
        done < "$header"

        # ------------------------------------------------------------------
        # Replace original file if we made changes
        # ------------------------------------------------------------------
        if [ "$modified" = true ]; then
            mv "$temp_file" "$header"
            echo "- Patched: $(basename "$header")"
        else
            # No changes made - remove temp file
            rm -f "$temp_file"
        fi
    done
}

# ------------------------------------------------------------------------------
# Cleanup function
# ------------------------------------------------------------------------------
# Removes temporary files created during script execution
# This is called automatically on script exit via the trap below
cleanup() {
    rm -f "$HEADER_MAP_FILE"
}

# Set trap to ensure cleanup happens even if script fails
# This guarantees we don't leave tmp files behind
trap cleanup EXIT

# ==============================================================================
# Main execution: Process all KSCrash XCFrameworks
# ==============================================================================
# Loop through KSCrash .xcframework bundles in the binaries directory

KSCRASH_FRAMEWORKS=(
    "KSCrashRecording"
    "KSCrashRecordingCore"
    "KSCrashCore"
    "KSCrashDemangleFilter"
)

for framework_name in "${KSCRASH_FRAMEWORKS[@]}"; do
    xcframework="$XCFRAMEWORKS_DIR/${framework_name}.xcframework"

    # Verify it's actually a directory
    if [ -d "$xcframework" ]; then
        # Extract module name from xcframework filename
        module_name=$(basename "$xcframework" .xcframework)

        echo "Processing $xcframework..."

        # An XCFramework contains multiple .framework bundles (one per platform/architecture)
        # Example structure:
        #   KSCrashRecording.xcframework/
        #     ├── ios-arm64/
        #     │   └── KSCrashRecording.framework/
        #     └── ios-arm64-simulator/
        #         └── KSCrashRecording.framework/
        #
        # We need to patch headers in ALL framework bundles
        find "$xcframework" -name "*.framework" -type d | while read -r framework; do
            patch_framework_headers "$framework" "$module_name"
        done
    else
        echo "Warning: XCFramework not found: $xcframework"
    fi
done

echo "KSCrash XCFrameworks patched successfully!"
echo ""
echo "What was done:"
echo "  1. Scanned $header_count headers across all modules"
echo "  2. Copied KSCrashNamespace.h to frameworks that need it"
echo "  3. Rewrote cross-module imports from quote-style to framework-style"
echo ""
