.DEFAULT_GOAL := all

.PHONY: all setup dev build open close clean help

all: dev

setup:
	@./scripts/setup-build.sh

dev:
	@$(MAKE) open

build: setup
	@./scripts/build-app.sh Release

open:
	@$(MAKE) close
	@$(MAKE) build
	@open -n "build/Build/Products/Release/MediaCoder.app"

close:
	@./scripts/close-app.sh

clean:
	@rm -rf -- build .build DerivedData
	@printf 'Removed development, production, and Swift package build artifacts.\n'

help:
	@printf '%s\n' \
	  'Media Coder commands' \
	  '' \
	  'Getting started' \
	  '  make / make all  Run dev: close the app, build Release, and open it.' \
	  '  make setup       Check Xcode and install XcodeGen if needed (requires Homebrew).' \
	  '' \
	  'Build and run' \
	  '  make dev         Run make open (close, build Release, and launch).' \
	  '  make build       Build the optimized Release app for production.' \
	  '  make open        Run make close, build Release, and launch the app.' \
	  '  make close       Stop running Debug and Release app instances from this project.' \
	  '' \
	  'Maintenance' \
	  '  make clean       Remove all local build artifacts; keep sources and settings.' \
	  '  make help        Show this grouped command reference.' \
	  '' \
	  'Apps: build/Build/Products/{Debug,Release}/MediaCoder.app' \
	  'Xcode updates existing build products automatically; dev does not need a clean.'
