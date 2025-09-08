# Taken and modified from KSCrash: https://github.com/kstenerud/KSCrash
#
# Directories to search
SEARCH_DIRS = Sources Tests Examples
SWIFT_SEARCH_DIRS = Sources Tests Examples

# File extensions to format
FILE_EXTENSIONS = c cpp h m mm

# Check for clang-format-18 first, then fall back to clang-format
# brew install clang-format
CLANG_FORMAT := $(shell command -v clang-format-18 2> /dev/null || command -v clang-format 2> /dev/null)

# Swift format command (using toolchain)
# brew install swift-format
SWIFT_FORMAT_CMD = swift format

HOOKS_DIR := $(shell git rev-parse --show-toplevel)/.githooks
GIT_HOOKS_DIR := $(shell git rev-parse --git-path hooks)

# Define the default target
.PHONY: format check-format swift-format check-swift-format

all: format swift-format

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

.PHONY: install-hooks
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