REPO_DIR=$1
BUILD_DIR=$2

swift create-xcframework --package-path "$REPO_DIR" \
  --output "$BUILD_DIR" \
  --platform ios OpenTelemetryApi OpenTelemetrySdk
