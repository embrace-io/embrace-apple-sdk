#!/bin/bash
set -x

# We could add some way to parametrize this
OUTPUT="build"
PLATFORM="iOS"

# Local variables
ARCHIVE_OUTPUT="$OUTPUT/archives"
XCFRAMEWORK_OUTPUT="$OUTPUT/xcframeworks"

# Clean up previous runs
rm -rf $OUTPUT

function archive {
    echo "Archiving: \n- scheme: $1 \n- destination: $2;\n- Archive path: $3.xcarchive"
    xcodebuild archive \
        -workspace EmbraceIO.xcworkspace \
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

    xcodebuild -create-xcframework ${xcoptions[@]} -output "$XCFRAMEWORK_OUTPUT/$PRODUCT.xcframework"
}

function install_prerequisites {
    # Ensure Tuist is already installed
    if ! command tuist &> /dev/null; then
        echo "Installing Tuist"
        mise install
    fi

    # Ensure create-xcframework plugin is installed
    swift create-xcframework --help &> /dev/null
    if [ $? -ne 0 ]; then
        echo "create-xcframework is not present. Installing it..."
        brew install segment-integrations/formulae/swift-create-xcframework
    fi
}

install_prerequisites

bash "$(dirname $0)/build_dependencies.sh"

tuist install
tuist generate --no-open

create_xcframework EmbraceCommonInternal
create_xcframework EmbraceObjCUtilsInternal
create_xcframework EmbraceStorageInternal
create_xcframework EmbraceOTelInternal
create_xcframework EmbraceUploadInternal
create_xcframework EmbraceConfigInternal
create_xcframework EmbraceCrash
create_xcframework EmbraceCrashlyticsSupport
create_xcframework EmbraceCaptureService
create_xcframework EmbraceCore
create_xcframework EmbraceIO


