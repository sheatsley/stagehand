# Shortcuts for common tasks. Run `make help` to list them.
.PHONY: help build run clean release

help: ## List available targets
	@grep -E '^[a-z]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

build: ## Build build/Stagehand.app
	@scripts/build.sh

run: build ## Build, quit any running copy, and launch
	@pkill -x Stagehand || true
	@open build/Stagehand.app

clean: ## Remove build products
	@rm -rf .build build

release: ## Publish a release: make release VERSION=X.Y.Z
	@test -n "$(VERSION)" || (echo "usage: make release VERSION=X.Y.Z" && exit 1)
	@scripts/release.sh $(VERSION)
