#!/bin/bash
set -x

DEPENDENCIES=("KSCrash" "opentelemetry-swift")
SCRIPT_DIR=$(dirname $0)
DEPENDENCIES_DIR="${SCRIPT_DIR}/dependencies"
TEMP_DIR="${DEPENDENCIES_DIR}/temp"
BUILD_DIR="build/xcframeworks"
mkdir -p "$TEMP_DIR"
mkdir -p "$BUILD_DIR"

get_dependency_info() {
  local DEPENDENCY_NAME=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  local INFO=$(jq -r --arg NAME "$DEPENDENCY_NAME" '.pins[] | select(.identity == $NAME) | { url: .location, version: (.state.version // .state.branch) }' Package.resolved)
  echo "$INFO"
}

for NAME in "${DEPENDENCIES[@]}"; do
  echo "Processing dependency: $NAME"

  INFO=$(get_dependency_info "$NAME")
  echo $INFO
  URL=$(echo "$INFO" | jq -r '.url')
  VERSION=$(echo "$INFO" | jq -r '.version')

  if [ -z "$URL" ] || [ -z "$VERSION" ]; then
    echo "Could not find dependency $NAME in Package.resolved"
    exit 1
  fi

  echo "URL: $URL"
  echo "Version: $VERSION"

  REPO_DIR="$TEMP_DIR/$NAME"
  if git ls-remote --tags "$URL" | grep -q "refs/tags/v${VERSION}$"; then
    git clone --branch "v${VERSION}" "$URL" "$REPO_DIR"
  else
    git clone --branch "$VERSION" "$URL" "$REPO_DIR"
  fi

  LOWERCASE_NAME=$(echo "$NAME" | tr '[:upper:]' '[:lower:]')
  BUILD_SCRIPT="${DEPENDENCIES_DIR}/build_${LOWERCASE_NAME}.sh"

  if [ -f "$BUILD_SCRIPT" ]; then
    bash "$BUILD_SCRIPT" "$REPO_DIR" "$BUILD_DIR"
  else
    echo "Build script $BUILD_SCRIPT not found for $NAME"
    exit 1
  fi

  rm -rf "$REPO_DIR"
done

rm -rf "$TEMP_DIR"
