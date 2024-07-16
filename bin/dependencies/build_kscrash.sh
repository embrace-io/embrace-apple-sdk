REPO_DIR=$1
BUILD_DIR=$2
PLATFORM="iOS"

# Local variables
ARCHIVE_OUTPUT="$REPO_DIR/archives"

# Clean up previous runs
rm -rf $OUTPUT

function archive {
    echo "Archiving: \n- scheme: $1 \n- destination: $2;\n- Archive path: $3.xcarchive"
    xcodebuild archive \
        -workspace "$REPO_DIR/KSCrash.xcworkspace" \
        -scheme "$1" \
        -destination "$2" \
        -archivePath "$3" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ONLY_ACTIVE_ARCH=NO \
    | xcpretty
}

function create_xcframework {
    PRODUCT=$1
    xcoptions=()

    # This will always be true; we should improve this in the future
    if [[ $PLATFORM == *"iOS"* ]]; then
        echo "Archive $PRODUCT iOS"

        archive "$PRODUCT" "generic/platform=iOS" "$ARCHIVE_OUTPUT/$PRODUCT/ios"
        xcoptions+=(-archive "$ARCHIVE_OUTPUT/$PRODUCT/ios.xcarchive" -framework "$PRODUCT.framework")

        archive "$PRODUCT" "generic/platform=iOS Simulator" "$ARCHIVE_OUTPUT/$PRODUCT/ios-simulator"
        xcoptions+=(-archive "$ARCHIVE_OUTPUT/$PRODUCT/ios-simulator.xcarchive" -framework "$PRODUCT.framework")
    fi

    echo "Create $PRODUCT.xcframework"

    xcodebuild -create-xcframework -allow-internal-distribution ${xcoptions[@]} -output "$BUILD_DIR/$PRODUCT.xcframework"
}

mise install
tuist install -p "$REPO_DIR"
tuist generate --no-open -p "$REPO_DIR"

create_xcframework KSCrashCore
create_xcframework KSCrashFilters
create_xcframework KSCrashSinks
create_xcframework KSCrashInstallations 
create_xcframework KSCrashRecordingCore
create_xcframework KSCrashReportingCore
create_xcframework KSCrashRecording
