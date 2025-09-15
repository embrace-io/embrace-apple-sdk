# Taken and modified from KSCrash: https://github.com/kstenerud/KSCrash
#
# Directories to search
SEARCH_DIRS = Sources Tests Examples
SWIFT_SEARCH_DIRS = Sources Tests Examples

# File extensions to format
FILE_EXTENSIONS = c cpp h m mm
FORMAT_EXTS := '\.(c|cc|cpp|cxx|h|hh|hpp|hxx|m|mm)$$'
SWIFT_FILE_RE := '(\.swift$$|(^|/)Package\.swift$$|(^|/)Dangerfile\.swift$$)'

# Check for clang-format-18 first, then fall back to clang-format
# brew install clang-format
CLANG_FORMAT := $(shell command -v clang-format-18 2> /dev/null || command -v clang-format 2> /dev/null)

# Swift format command (using toolchain)
# brew install swift-format
SWIFT_FORMAT_CMD = swift format

HOOKS_DIR := $(shell git rev-parse --show-toplevel)/.githooks
GIT_HOOKS_DIR := $(shell git rev-parse --git-path hooks)

# Default base branch if not in Actions
BASE_BRANCH ?= main

# If running in GitHub Actions, prefer github.base_ref
ifdef GITHUB_BASE_REF
  BASE_BRANCH := $(GITHUB_BASE_REF)
endif

DIFF_RANGE ?= $(shell \
	git fetch origin $(BASE_BRANCH) >/dev/null 2>&1 || true; \
	BASE=$$(git merge-base HEAD origin/$(BASE_BRANCH)); \
	echo $$BASE...HEAD \
)

# Define the default target
.PHONY: format check-format check-format-changes swift-format check-swift-format check-swift-format-changes install-hooks uninstall-hooks

all: format swift-format

# Format source code using clang-format
format:
ifeq ($(CLANG_FORMAT),)
	@echo "Error: clang-format or clang-format-18 is not installed. Please install it and try again."
	@exit 1
else
	@echo "Running format with clang-format..."
	find $(SEARCH_DIRS) $(foreach ext,$(FILE_EXTENSIONS),-name '*.$(ext)' -o) -false | \
	xargs -r $(CLANG_FORMAT) -style=file -i
endif

check-format:
ifeq ($(CLANG_FORMAT),)
	@echo "Error: clang-format or clang-format-18 is not installed. Please install it and try again."
	@exit 1
else
	@echo "Running check-format with clang-format..."
	@find $(SEARCH_DIRS) $(foreach ext,$(FILE_EXTENSIONS),-name '*.$(ext)' -o) -false | \
	xargs -r $(CLANG_FORMAT) -style=file -n -Werror
endif

check-format-changes:
	@echo "Running clang-format on changes..."
	@set -e; \
	changed=$$(git diff --name-only -z --diff-filter=ACMR $(DIFF_RANGE) -- \
	  | grep -zE $(FORMAT_EXTS) || true); \
	if [ -n "$$changed" ]; then \
	  printf "%s\0" $$changed \
	    | xargs -0 -r $(CLANG_FORMAT) -style=file -n -Werror --; \
	else \
	  echo "No matching files changed."; \
	fi

# Format Swift source code using swift-format
swift-format:
	@echo "Running swift-format with swift-format..."
	@{ find $(SWIFT_SEARCH_DIRS) -name '*.swift' -type f -not -path '*/.build/*'; \
	   [ -f Package.swift ] && echo Package.swift; \
	   [ -f Dangerfile.swift ] && echo Dangerfile.swift; } | \
	while read file; do \
		$(SWIFT_FORMAT_CMD) format --in-place --configuration .swift-format "$$file"; \
	done

check-swift-format:
	@echo "Running check-swift-format with swift-format..."
	@{ find $(SWIFT_SEARCH_DIRS) -name '*.swift' -type f -not -path '*/.build/*'; \
	   [ -f Package.swift ] && echo Package.swift; \
	   [ -f Dangerfile.swift ] && echo Dangerfile.swift; } | \
	while read file; do \
		$(SWIFT_FORMAT_CMD) lint --configuration .swift-format "$$file" --strict; \
	done

check-swift-format-changes:
	@echo "Running swift-format on changes..."
	@set -e; \
	changed=$$(git diff --name-only -z --diff-filter=ACMR $(DIFF_RANGE) -- \
	  | grep -zv '/\.build/' \
	  | grep -zE $(SWIFT_FILE_RE) || true); \
	if [ -n "$$changed" ]; then \
	  printf "%s\0" $$changed \
	    | xargs -0 -r $(SWIFT_FORMAT_CMD) lint --configuration .swift-format --strict --; \
	else \
	  echo "No Swift files changed."; \
	fi

# hooks
install-hooks:
	@echo "Installing Git hooks..."
	@for hook in $(HOOKS_DIR)/*; do \
		hook_name=$$(basename $$hook); \
		target="$(GIT_HOOKS_DIR)/$$hook_name"; \
		mkdir -p "$(GIT_HOOKS_DIR)"; \
		rm -f $$target; \
		ln -s $$hook $$target; \
		chmod +x $$hook; \
		echo " → Installed $$hook_name"; \
	done
	@echo "Done!"

# remove hooks
uninstall-hooks:
	@echo "Uninstalling Git hooks..."
	@for hook in $(HOOKS_DIR)/*; do \
		hook_name=$$(basename $$hook); \
		target="$(GIT_HOOKS_DIR)/$$hook_name"; \
		if [ -L "$$target" ] || [ -f "$$target" ]; then \
			rm -f "$$target"; \
			echo " ✗ Removed $$hook_name"; \
		else \
			echo " (skipped) $$hook_name not installed"; \
		fi; \
	done
	@echo "Done!"