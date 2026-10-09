.DEFAULT_GOAL := all

.PHONY: all setup dev build open close clean help

all: dev

setup:
	@./scripts/setup-build.sh

dev: setup
	@./scripts/build-app.sh Debug
	@open -n "build/Build/Products/Debug/MediaCoder.app"

build: setup
	@./scripts/build-app.sh Release

open: build
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
	  '  make / make all  Set up build tools, build for development, and open the app.' \
	  '  make setup       Check Xcode and install XcodeGen if needed (requires Homebrew).' \
	  '' \
	  'Build and run' \
	  '  make dev         Build Debug and open a new app instance.' \
	  '  make build       Build the optimized Release app for production.' \
	  '  make open        Build Release and open a new app instance.' \
	  '  make close       Stop running Debug and Release app instances from this project.' \
	  '' \
	  'Maintenance' \
	  '  make clean       Remove all local build artifacts; keep sources and settings.' \
	  '  make help        Show this grouped command reference.' \
	  '' \
	  'Apps: build/Build/Products/{Debug,Release}/MediaCoder.app' \
	  'Xcode updates existing build products automatically; dev does not need a clean.'
