#!/bin/bash

#
#  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
#

# Change directory to git root
cd "$(git rev-parse --show-toplevel)"

# Get `git sha` for current repo
git_sha=$(git rev-parse HEAD)

# Get the number of files that are added, modified, or deleted in the `Sources` directory
git_dirty_count=$((git diff --name-only Sources; git diff --cached --name-only Sources) | sort -u | wc -l | sed 's/^[ \t]*//')

# Get the current branch name
git_branch=$(git rev-parse --abbrev-ref HEAD)

# Get Info.plist path
info_plist_path="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"

# Use plutil to inject git info into Info.plist inside "GitInfo" key
plutil -replace GitInfo -json "{ \"sha\": \"${git_sha}\", \"dirty_count\": ${git_dirty_count}, \"branch\": \"${git_branch}\" }" "${info_plist_path}"
