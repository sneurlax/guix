# guix
Reproducible Flutter builds using GNU Guix.

## Option 1: Dart CLI (pub.dev)
```sh
dart pub global activate guix
```

Then in your Flutter project:
```sh
guix_dart init        # Creates config files
guix_dart setup       # Fetches Flutter SDK
guix_dart shell linux # Enters reproducible dev shell
guix_dart build linux # Reproducible build
guix_dart doctor      # Checks prerequisites
```

## Option 2: Git subtree (no dependencies)
```sh
git subtree add --prefix=guix <repo-url> main --squash
```

Add to your Makefile:
```makefile
GUIX_FLUTTER_DIR ?= guix
include $(GUIX_FLUTTER_DIR)/Makefile.inc
```

Then:
```sh
make guix-setup           # pins channels, fetches Flutter SDK
make guix-shell           # enters dev shell
make guix-build           # reproducible build
```

No Dart dependency, just Bash and Guix. S ee [guix/README.md](guix/README.md) 
for the full script reference.

# Is it any good?
Yes.
