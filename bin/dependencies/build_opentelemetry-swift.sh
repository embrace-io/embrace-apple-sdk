REPO_DIR=$1
BUILD_DIR=$2

# We replace the `package` keyword because it's not supported by the `create-xcframework` command.
# We tried using "OTHER_SWIFT_FLAGS" and setting the package and module names, but it ends up creating problems
# since we are building two frameworks at the same time.
# Until the `package` keyword is supported directly, we'll replace the `package` keyword with just `public`
# so the frameworks compile.
# We realize this exposes something that is not meant to be exposed, we think it's harmless.

grep -rl 'package static' "$REPO_DIR/Sources/" | xargs sed -i '' 's/package static/public static/g'
grep -rl 'package var' "$REPO_DIR/Sources/" | xargs sed -i '' 's/package var/public var/g'

swift create-xcframework --package-path "$REPO_DIR" \
  --output "$BUILD_DIR" \
  --platform ios OpenTelemetryApi OpenTelemetrySdk 