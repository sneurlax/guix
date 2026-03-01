# Unified entry point for Guix-based Flutter development.
# All targets wrap the scripts/ directory.

.PHONY: setup shell shell-pinned build build-fast pin clean

# Fetch Flutter SDK + pin Guix channels (first-time setup).
setup:
	./guix/pin-channels.sh
	./scripts/fetch-flutter.sh

# Interactive dev shell (uses latest local Guix).
shell:
	./scripts/shell-linux.sh

# Interactive dev shell (fully pinned — reproducible).
shell-pinned:
	./scripts/shell-linux.sh --pinned

# CI-friendly build (fully pinned).
build:
	./scripts/build-linux.sh --pinned

# Build with latest local Guix (faster, less reproducible).
build-fast:
	./scripts/build-linux.sh

# Re-pin Guix channels to current versions.
pin:
	./guix/pin-channels.sh

# Remove fetched Flutter SDK and build artifacts.
clean:
	rm -rf .flutter-sdk build
