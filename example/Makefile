.PHONY: guix-setup guix-build hash-linux verify-linux

GUIX_DART = dart run ../packages/guix/bin/guix_dart.dart

guix-setup:
	$(GUIX_DART) setup linux

guix-build:
	$(GUIX_DART) build linux

hash-linux:
	./tool/hash_linux_bundle.sh

verify-linux:
	./tool/hash_linux_bundle.sh --check
