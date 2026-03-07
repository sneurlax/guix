import 'dart:io';
import 'package:test/test.dart';
import 'package:guix/src/config/guix_config.dart';

void main() {
  group('PinCommand channels path resolution', () {
    test('falls back to guix/channels.scm when config file is missing', () {
      // Simulate the fallback logic from PinCommand.run():
      // try { config = GuixConfig.load(); } on FileSystemException { ... }
      String channelsPath;
      try {
        GuixConfig.load('nonexistent_config_file.yaml');
        fail('Should have thrown FileSystemException');
      } on FileSystemException {
        channelsPath = 'guix/channels.scm';
      }
      expect(channelsPath, equals('guix/channels.scm'));
    });

    test('uses channelsPath from config when config exists', () {
      // Create a temporary guix.yaml with a custom channels path
      final tmpDir = Directory.systemTemp.createTempSync('pin_test_');
      final configFile = File('${tmpDir.path}/guix.yaml');
      configFile.writeAsStringSync('''
project:
  name: test-project
flutter:
  version: "3.24.5"
guix:
  channels: custom/path/channels.scm
''');

      try {
        final config = GuixConfig.load(configFile.path);
        expect(config.channelsPath, equals('custom/path/channels.scm'));
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    });

    test('defaults channelsPath to guix/channels.scm when guix.channels is not set in config', () {
      final tmpDir = Directory.systemTemp.createTempSync('pin_test_');
      final configFile = File('${tmpDir.path}/guix.yaml');
      configFile.writeAsStringSync('''
project:
  name: test-project
flutter:
  version: "3.24.5"
''');

      try {
        final config = GuixConfig.load(configFile.path);
        expect(config.channelsPath, equals('guix/channels.scm'));
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    });
  });

  group('PinCommand directory creation logic', () {
    test('creates parent directories for channels file', () {
      final tmpDir = Directory.systemTemp.createTempSync('pin_dir_test_');
      final channelsPath = '${tmpDir.path}/deeply/nested/dir/channels.scm';

      try {
        // Replicate the logic from PinCommand.run():
        // final dir = File(channelsPath).parent;
        // if (!dir.existsSync()) dir.createSync(recursive: true);
        final dir = File(channelsPath).parent;
        expect(dir.existsSync(), isFalse);

        dir.createSync(recursive: true);
        expect(dir.existsSync(), isTrue);
        expect(Directory('${tmpDir.path}/deeply/nested/dir').existsSync(), isTrue);
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    });

    test('does not fail when parent directory already exists', () {
      final tmpDir = Directory.systemTemp.createTempSync('pin_dir_test_');
      final channelsPath = '${tmpDir.path}/channels.scm';

      try {
        final dir = File(channelsPath).parent;
        expect(dir.existsSync(), isTrue);

        // Should not throw
        if (!dir.existsSync()) dir.createSync(recursive: true);
        expect(dir.existsSync(), isTrue);
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    });

    test('File.parent extracts correct directory from channels path', () {
      final parent = File('guix/channels.scm').parent;
      expect(parent.path, equals('guix'));

      final nestedParent = File('some/deep/path/channels.scm').parent;
      expect(nestedParent.path, equals('some/deep/path'));
    });
  });

  group('PinCommand commit regex extraction', () {
    test('extracts commit hash from channels file content', () {
      final content = '''
(list (channel
        (name 'guix)
        (url "https://git.savannah.gnu.org/git/guix.git")
        (branch "master")
        (commit "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2")
        (introduction
          (make-channel-introduction
            "9edb3f66fd807b096b48283debdcddccfea34bad"))))
''';
      final match = RegExp(r'\(commit\s+"([a-f0-9]+)"\)').firstMatch(content);
      expect(match, isNotNull);
      expect(match!.group(1), equals('a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'));
    });

    test('returns null when no commit found in content', () {
      final content = '(list (channel (name \'guix)))';
      final match = RegExp(r'\(commit\s+"([a-f0-9]+)"\)').firstMatch(content);
      expect(match, isNull);
    });
  });
}
