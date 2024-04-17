#!/bin/bash

# Embrace dSYM upload wrapper script
#
# Scans build output directories for dSYMs to upload
#
#
# Required environment variables
# ------------------------------
#
# BUILD_ROOT
#
# The path to the build root directory. This is an environment set by default by XCode. If you are using this script
# outside of an XCode build phase, you must specify this manually.
#
# EMBRACE_ID
#
# The app ID that dSYMs are being uploaded for. This should be a 5-character value.
#
# EMBRACE_TOKEN
#
# The API token that authenticates the upload. This a 32-digit hex number.
#
#
# Optional environment variables
# ------------------------------
#
# DEBUG_INFORMATION_FORMAT
#
# This is an environment variable set by XCode. If it is set and is not "dwarf-with-dsym", the upload is skipped since
# we won't have a dSYM for the app. If it is not set, we will scan for dSYMs. There is typically no need to set this
# manually.
#
# DISABLE_BITCODE_CHECK (default=<not set>)
#
# A warning is printed if you run this script with Bitcode support enabled since the dSYMs created during the build
# process are largely useless and you will have to download dSYMs from Apple instead. Set this variable to suppress this
# warning.
#
# EMBRACE_DEBUG_DSYM (default=<not set>)
#
# Set this to force log output from the upload binary to appear in the XCode build logs. When this is not set, stderr
# and stdout are redirected to /dev/null and the logs are written to the system log to allow the upload to occur in the
# background. When debug mode is enabled, the upload does no longer happens in the background, which will add time to
# the build process.
#
# EMBRACE_FRAMEWORK_SEARCH_DEPTH (default=2)
#
# Search depth to start at relative to the framework search path when scanning for framework dSYMs. Most configurations
# do not require this value to be set.
#
# EMBRACE_FRAMEWORK_SEARCH_PATH (default=<not set>)
#
# Use this to specify a custom path to search for framework dSYMs. Most configurations do not require this value to be
# set.

DEFAULT_FRAMEWORK_SEARCH_DEPTH=2

UPLOAD_BIN=upload
UPLOAD_RELATIVE_PATH=EmbraceIO/${UPLOAD_BIN}

# Allow override of the store host, default to empty to use default store
if [ -n "$EMBRACE_STORE_HOST" ] ; then
  host_arg="--host $EMBRACE_STORE_HOST"
else
  host_arg=""
fi

function log () {
    # xcode will mark log lines as warnings and errors if prefixed with the values below. the prefixes are removed and error and warning markers replace them.
    case $2 in
      warning)
        prefix="warning: "
        ;;
      error)
        prefix="error: "
        ;;
      *)
        prefix=""
        ;;
    esac

    echo "$(date +"%Y/%m/%d %H:%M:%S") [Embrace dSYM Upload] ${prefix}$1"
}


function log_error () {
    log "$1" "error"
}


function log_warning () {
    log "$1" "warning"
}


function run() {
    if [ -z "$EMBRACE_DEBUG_DSYM" ] ; then
        # we must redirect both stdout and stderr to /dev/null to have Xcode run this script in the background and move on to other build tasks
	eval "$1 --log-path $BUILD_ROOT" > /dev/null 2>&1 &
    else
        eval "$1"
    fi
}

function createSourceMap() {
  REACT_NATIVE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
  CLI_PATH="$REACT_NATIVE_DIR/node_modules/react-native/cli.js"

  DEST=/dev/null

  node "$CLI_PATH" bundle \
    --entry-file index.js \
    --platform ios \
    --dev false \
    --bundle-output "$react_bundle_path" \
    --assets-dest "$DEST" \
    --sourcemap-output  "$react_map_path"
}

function react_native_upload() {

    if [ "$CONFIGURATION" = "Debug" ] || [ "$REACT_NATIVE" = "0" ] ; then
      if [ "$CONFIGURATION" = "Debug" ] ; then
          log "Debug build detected. Will not upload React Native bundle."
      elif [ "$REACT_NATIVE" = "0" ] ; then
          log "REACT_NATIVE=0. Will not upload React Native bundle."
      fi
      return
    fi

    [ -n "$CONFIGURATION_BUILD_DIR" ] && [ -n "$UNLOCALIZED_RESOURCES_FOLDER_PATH" ] && REACT_NATIVE_BUNDLE_PATH_DEFAULT="$CONFIGURATION_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/main.jsbundle"

    react_bundle_path=
    # If no bundle path is provided then we check for the existence of the bundle in the default path.
    # If we find the default bundle file we assume it is a React Native app. If a bundle path is specified
    # we use that instead.
    if [ -z "$REACT_NATIVE_BUNDLE_PATH" ] ; then
        react_bundle_path="${REACT_NATIVE_BUNDLE_PATH_DEFAULT}"
    else
        react_bundle_path="${REACT_NATIVE_BUNDLE_PATH}"
    fi

    if [ ! -f "$react_bundle_path" ] ; then
      if [ -n "$REACT_NATIVE_BUNDLE_PATH" ] ; then
        log_warning "Could not find JavaScript bundle ${react_bundle_path}. Exiting early."
      fi
      log "Could not find JavaScript bundle ${react_bundle_path} when using default location derived from CONFIGURATION_BUILD_DIR and UNLOCALIZED_RESOURCES_FOLDER_PATH. Exiting early."
      return
    fi

    react_map_path="${REACT_NATIVE_MAP_PATH}"
    if [ -z "$REACT_NATIVE_MAP_PATH" ] ; then
      log "Setting react_map_path: using react bundle path \"${react_bundle_path}\" since REACT_NATIVE_MAP_PATH was not specified"
      react_map_path="${react_bundle_path}.map"
    else
      log "Setting react_map_path: using react bundle path to \"${react_map_path}\" from REACT_NATIVE_MAP_PATH"
    fi

    if [ ! -f "$react_map_path" ] ; then
      if [ -n "$REACT_NATIVE_MAP_PATH" ] ; then
        log_warning "Could not find JavaScript map at ${react_map_path}. Exiting early."
      fi
      log "Could not find JavaScript map \"$react_map_path\" when using default location derived from the bundle path \"$react_bundle_path\"." 
      log "Try to create JavaScript map in \"$react_map_path\" manually."
      
      createSourceMap

      if [ ! -f "$react_map_path" ] ; then
        log_warning "Could not create javascript map. Exiting early"
        return
      fi
      log "Sourcemap was created manually."
    fi

    react_args="--rn-bundle \"$react_bundle_path\"  --rn-map \"$react_map_path\""

    if [ -n "$react_args" ] ; then
        log "uploading react native resources with bundle at ${react_bundle_path} and map at ${react_map_path}"
        # shellcheck disable=2153
        run "\"$UPLOAD_BIN_PATH\" --app $EMBRACE_ID --token $EMBRACE_TOKEN $react_args $host_arg --log-level $EMBRACE_LOG_LEVEL"
    fi
}

function scrape_app_version() {
    if [[ -n "$EMBRACE_APP_VERSION" ]]; then
        # First, check if the user has set an environment variable app version explicitly to use
        app_version=$EMBRACE_APP_VERSION
        log "using app version set in env var EMBRACE_APP_VERSION = $app_version"
    elif [[ -n "$BUILT_PRODUCTS_DIR" ]] && [[ -n "$BUILT_PRODUCTS_DIR" ]]; then
        # PlistBuddy ships with macOS, so will be available for all macOS Xcode builds. Check it exists, just in case.
        log "using app version from your Info.plist ($BUILT_PRODUCTS_DIR/$INFOPLIST_PATH)"
        if command -v /usr/libexec/PlistBuddy &> /dev/null; then
          app_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$BUILT_PRODUCTS_DIR/$INFOPLIST_PATH")
          log "using app version (CFBundleShortVersionString) from Info.plist = $app_version"
        else
          log_error "unable to get app version from Info.plist as /usr/libexec/PlistBuddy executable was not found"
        fi
    else
      unset app_version
    fi
}

function upload() {
    react_native_upload

    # If CodePush is specified, don't bother trying to upload dSYMs.
    if [ -n "$CODE_PUSH_UPLOAD" ]; then
        return
    fi

    if [ -z "$BUILD_ROOT" ]
    then
      log_error "Missing BUILD_ROOT environment variable. Are you running this from a build step in XCode? Skipping upload."
      exit 1
    fi
    cd "$BUILD_ROOT" || { log_error "Could not cd to BUILD_ROOT ${BUILD_ROOT}. Exiting." ; return ; }

    unity_args=""
    if [ -f "$PROJECT_DIR/Classes/Native/Symbols/LineNumberMappings.json" ] && [ -f "$PROJECT_DIR/Classes/Native/Symbols/MethodMap.tsv" ] ; then
	unity_args="--cs-line-map \"$PROJECT_DIR/Classes/Native/Symbols/LineNumberMappings.json\" --cs-method-map \"$PROJECT_DIR/Classes/Native/Symbols/MethodMap.tsv\""
    fi

    # if we can't find the files we are looking for with globs, we want nulls
    shopt -s nullglob

    # XCode should provide these environment variables, but other CI setups may not provide them
    if [ -n "$DWARF_DSYM_FILE_NAME" ] && [ -n "$DWARF_DSYM_FOLDER_PATH" ] ; then
        app_dsym_path="${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/"
    else
        log "DWARF_DSYM_FILE_NAME and/or DWARF_DSYM_FOLDER_PATH envvars not defined. Attempting to find dSYM file using glob." "warning"
        app_dsym_path="*/*.dSYM/*/Resources/DWARF/"
    fi

    log "Looking for app dSYM in $app_dsym_path"

    scrape_app_version
    if [ -n "$app_version" ] ; then
      app_version_arg="--app-version $app_version"
    else
      app_version_arg=""
    fi

    # Xcode will sometimes not have completed the GenerateDSYMFile step before it runs the upload script, so we allow
    # for a small delay to occur before continuing
    found=
    for _ in {1..4} ; do
        app_dsym_file=$(find "$app_dsym_path" -type f)
        [ -n "$app_dsym_file" ] && [ -e "$app_dsym_file" ] && found=1 && break
        sleep 0.5
    done

    if [ -n "$found" ] ; then
        log "Queueing app dSYM for upload: $app_dsym_file"
        icon=$(echo "$PWD"/*/*.xcassets/AppIcon.appiconset/Icon-60@2x.png | head -n 1)
        if [ -n "$icon" ] ; then
          icon_arg="--icon $icon"
        else
          icon_arg=""
        fi
        run "\"$UPLOAD_BIN_PATH\" --app $EMBRACE_ID --token $EMBRACE_TOKEN $unity_args $icon_arg $app_version_arg $host_arg --dsym \"$app_dsym_file\" --log-level $EMBRACE_LOG_LEVEL"
    else
        log_warning "No app dSYM file was found under BUILD_ROOT ${BUILD_ROOT}. Skipping upload."
    fi

    # use `find` and a for loop to build up the list of dSYMs rather than a glob so we can properly handle escaping of spaces
    framework_search_path=$PWD
    framework_search_depth=$DEFAULT_FRAMEWORK_SEARCH_DEPTH

    if [ -n "$EMBRACE_FRAMEWORK_SEARCH_PATH" ] ; then
      if [ -e "$EMBRACE_FRAMEWORK_SEARCH_PATH" ] ; then
        framework_search_path=$EMBRACE_FRAMEWORK_SEARCH_PATH
        log "Using custom framework search path set with EMBRACE_FRAMEWORK_SEARCH_PATH"
      else
        log_error "Specified custom framework search path $EMBRACE_FRAMEWORK_SEARCH_PATH, but it does not exist. Using default ${framework_search_path}."
      fi
    elif [ -n "$DWARF_DSYM_FOLDER_PATH" ] ; then
      framework_search_path=$DWARF_DSYM_FOLDER_PATH
      log "Using DWARF_DSYM_FOLDER_PATH to set framework search path"
    elif [ -n "$BUILT_PRODUCTS_DIR" ] ; then
      framework_search_path=$BUILT_PRODUCTS_DIR
      log "Using BUILT_PRODUCTS_DIR to set framework search path"
    elif [ -n "$CI_ARCHIVE_PATH" ] ; then
      framework_search_path=$CI_ARCHIVE_PATH
      log "Using CI_ARCHIVE_PATH to set framework search path"
    fi

    if [ -n "$EMBRACE_FRAMEWORK_SEARCH_DEPTH" ] ; then
      framework_search_depth=$EMBRACE_FRAMEWORK_SEARCH_DEPTH
      log "Overriding default framework search depth and setting it to $framework_search_depth"
    fi

    log "Scanning for framework dSYMs in $framework_search_path"
    framework_dsyms=$(find "$framework_search_path" -mindepth "$framework_search_depth" -name "*.dSYM")
    if [ -n "$framework_dsyms" ] ; then
        ORIG_IFS=$IFS
        IFS=$'\n'
        dsym_args=""
        for dsym in $framework_dsyms ; do
            # we already uploaded the main dsym above, skip it here
            if [[ -n $DWARF_DSYM_FILE_NAME && $dsym == *$DWARF_DSYM_FILE_NAME ]] ; then
                continue
            fi
            dsym_full_path="$(find "${dsym}"/Contents/Resources/DWARF/*  -type f 2>/dev/null)"
            if [ -z "$dsym_full_path" ] ; then
                continue
            fi
            dsym_args="$dsym_args --dsym \"$dsym_full_path\""
            log "Queueing framework dSYM for upload: $dsym_full_path"
        done
        IFS=$ORIG_IFS
        run "\"$UPLOAD_BIN_PATH\" --app $EMBRACE_ID --token $EMBRACE_TOKEN $dsym_args $app_version_arg $host_arg --log-level $EMBRACE_LOG_LEVEL"
    fi
}

#
# start of script
#
if [ -n "$EMBRACE_DEBUG_DSYM" ] ; then
    log "Debug mode enabled"
else
    log "Logs from the upload binary will appear in $BUILD_ROOT/embrace_uploader.log"
    log "Set EMBRACE_DEBUG_DSYM=1 to display them in the XCode build logs."
fi

if [ "$ENABLE_BITCODE" = "YES" ] && [ -z "$DISABLE_BITCODE_CHECK" ] ; then
    log "\"Enable bitcode\" is set to \"YES\". You will need to download dSYMs from Apple for TestFlight and App Store builds and then upload those dSYMs to Embrace."
fi

#
# check that we have the required envvars set
#
if [ -z "$EMBRACE_ID" ] ; then
  log_error "Missing EMBRACE_ID environment variable. Skipping upload."
  exit 1
fi

if [ -z "$EMBRACE_TOKEN" ] ; then
  log_error "Missing EMBRACE_TOKEN environment variable. Skipping upload."
  exit 1
fi

#
# check if EMBRACE_LOG_LEVEL has value, if not set the default one.
#
if [ -z "$EMBRACE_LOG_LEVEL" ] ; then
  export EMBRACE_LOG_LEVEL=info
  log "Set EMBRACE_LOG_LEVEL=info to display info logs."
fi

#
# find the upload binary
#
UPLOAD_BIN_PATH=
# try using PODS_ROOT, if set, to find the upload binary
if [ -n "$PODS_ROOT" ] ; then
    PODS_UPLOAD_PATH="$PODS_ROOT"/${UPLOAD_RELATIVE_PATH}
    if [ -e "$PODS_UPLOAD_PATH" ]; then
      UPLOAD_BIN_PATH="$PODS_UPLOAD_PATH"
      log "Used PODS_ROOT to find upload binary at $UPLOAD_BIN_PATH"
    fi
fi

# if we have not found the upload binary, fall back on using the script's location to try to find the upload binary
if [ -z "$UPLOAD_BIN_PATH" ]; then
  EMBRACE_DIR=$(cd "$(dirname "$0")" && pwd -P)
  if [ -e "$EMBRACE_DIR"/${UPLOAD_BIN} ] ; then
    UPLOAD_BIN_PATH="$EMBRACE_DIR"/${UPLOAD_BIN}
    log "Used script directory to find upload binary at $UPLOAD_BIN_PATH"
  else
    log_warning "Did not find upload binary using script directory"
  fi
fi

if [ -z "$UPLOAD_BIN_PATH" ] ; then
  log_error "Could not find path to Embrace dSYM upload binary. Please add EMBRACE_DEBUG_DSYM=1 to the build phase command, re-run the build, and contact Embrace support with the build logs."
  exit 1
fi

#
# start the upload
#
log "Using app ID ${EMBRACE_ID} and API token ${EMBRACE_TOKEN}"

# if we have data about the configured debug format, use it. we may not have this setting though if we are running in certain CI environments, so do not exit if it is not set.
if [ -n "$DEBUG_INFORMATION_FORMAT" ] ; then
    if [ "$DEBUG_INFORMATION_FORMAT" != "dwarf-with-dsym" ] ; then
        log_warning "DEBUG_INFORMATION_FORMAT set to '$DEBUG_INFORMATION_FORMAT'. Skipping upload. Set it to 'dwarf-with-dsym' to generate a dSYM for your application"
        exit 0
    fi
fi

upload &
