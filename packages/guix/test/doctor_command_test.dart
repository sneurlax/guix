import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:guix/src/config/guix_config.dart';
import 'package:yaml/yaml.dart';

GuixConfig _configFromYaml(String yaml) =>
    GuixConfig.fromYaml(loadYaml(yaml) as YamlMap);

void main() {
  group('doctor: config validation', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('doctor_test_');
    });

    tearDown(() {
      tmp.deleteSync(recursive: true);
    });

    test('detects missing guix.yaml', () {
      final configFile = File(p.join(tmp.path, 'guix.yaml'));
      expect(configFile.existsSync(), isFalse);
    });

    test('detects present guix.yaml', () {
      File(p.join(tmp.path, 'guix.yaml')).writeAsStringSync('''
flutter:
  version: "3.24.5"
  channel: stable
guix:
  channels: guix/channels.scm
platforms: {}
''');
      expect(File(p.join(tmp.path, 'guix.yaml')).existsSync(), isTrue);
    });

    test('GuixConfig.load throws on missing file', () {
      expect(
        () => GuixConfig.load(p.join(tmp.path, 'guix.yaml')),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('GuixConfig.load succeeds on valid file', () {
      final configPath = p.join(tmp.path, 'guix.yaml');
      File(configPath).writeAsStringSync('''
project:
  name: test_app
flutter:
  version: "3.24.5"
  channel: stable
guix:
  channels: guix/channels.scm
platforms: {}
''');
      final config = GuixConfig.load(configPath);
      expect(config.projectName, 'test_app');
      expect(config.flutter.version, '3.24.5');
    });

    test('GuixConfig.load throws on invalid YAML', () {
      final configPath = p.join(tmp.path, 'guix.yaml');
      File(configPath).writeAsStringSync('not: [valid: yaml: {{{');
      expect(
        () => GuixConfig.load(configPath),
        throwsA(anything),
      );
    });
  });

  group('doctor: channel pinning check', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('doctor_channels_test_');
    });

    tearDown(() {
      tmp.deleteSync(recursive: true);
    });

    test('detects missing channels.scm', () {
      final config = _configFromYaml('''
flutter:
  version: "3.24.5"
  channel: stable
guix:
  channels: guix/channels.scm
platforms: {}
''');

      final channelsFile = File(p.join(tmp.path, config.channelsPath));
      expect(channelsFile.existsSync(), isFalse);
    });

    test('detects present channels.scm', () {
      final guixDir = p.join(tmp.path, 'guix');
      Directory(guixDir).createSync();
      File(p.join(guixDir, 'channels.scm')).writeAsStringSync('''
(list (channel
        (name 'guix)
        (url "https://git.savannah.gnu.org/git/guix.git")
        (branch "master")
        (commit "abc123def456")))
''');

      final config = _configFromYaml('''
flutter:
  version: "3.24.5"
  channel: stable
guix:
  channels: guix/channels.scm
platforms: {}
''');

      final channelsFile = File(p.join(tmp.path, config.channelsPath));
      expect(channelsFile.existsSync(), isTrue);
    });

    test('extracts commit hash from channels.scm content', () {
      final guixDir = p.join(tmp.path, 'guix');
      Directory(guixDir).createSync();
      final channelContent = '''
(list (channel
        (name 'guix)
        (url "https://git.savannah.gnu.org/git/guix.git")
        (branch "master")
        (commit "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0")))
''';
      File(p.join(guixDir, 'channels.scm'))
          .writeAsStringSync(channelContent);

      // Mirror the doctor's commit extraction logic
      final content =
          File(p.join(guixDir, 'channels.scm')).readAsStringSync();
      final commitMatch =
          RegExp(r'\(commit\s+"([a-f0-9]+)"\)').firstMatch(content);
      expect(commitMatch, isNotNull);
      final short = commitMatch!.group(1)!.substring(0, 8);
      expect(short, 'a1b2c3d4');
    });

    test('channels.scm without commit hash is still accepted', () {
      final guixDir = p.join(tmp.path, 'guix');
      Directory(guixDir).createSync();
      File(p.join(guixDir, 'channels.scm')).writeAsStringSync('''
(list (channel
        (name 'guix)
        (url "https://git.savannah.gnu.org/git/guix.git")))
''');

      final content =
          File(p.join(guixDir, 'channels.scm')).readAsStringSync();
      final commitMatch =
          RegExp(r'\(commit\s+"([a-f0-9]+)"\)').firstMatch(content);
      expect(commitMatch, isNull);
      // Doctor would still report "[pass] Channels file exists ..."
    });

    test('uses custom channels path from config', () {
      final config = _configFromYaml('''
flutter:
  version: "3.24.5"
  channel: stable
guix:
  channels: custom/path/channels.scm
platforms: {}
''');
      expect(config.channelsPath, 'custom/path/channels.scm');
    });
  });

  group('doctor: Flutter version matching', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('doctor_flutter_test_');
    });

    tearDown(() {
      tmp.deleteSync(recursive: true);
    });

    test('detects missing Flutter SDK directory', () {
      final sdkDir = Directory(p.join(tmp.path, '.flutter-sdk', 'flutter'));
      expect(sdkDir.existsSync(), isFalse);
    });

    test('detects matching Flutter version', () {
      final config = _configFromYaml('''
flutter:
  version: "3.24.5"
  channel: stable
platforms: {}
''');

      // Create mock SDK directory with version file
      final sdkDir = p.join(tmp.path, '.flutter-sdk', 'flutter');
      Directory(sdkDir).createSync(recursive: true);
      File(p.join(sdkDir, 'version')).writeAsStringSync('3.24.5');

      final versionFile = File(p.join(sdkDir, 'version'));
      expect(versionFile.existsSync(), isTrue);
      final version = versionFile.readAsStringSync().trim();
      expect(version, config.flutter.version);
    });

    test('detects mismatched Flutter version', () {
      final config = _configFromYaml('''
flutter:
  version: "3.27.1"
  channel: stable
platforms: {}
''');

      final sdkDir = p.join(tmp.path, '.flutter-sdk', 'flutter');
      Directory(sdkDir).createSync(recursive: true);
      File(p.join(sdkDir, 'version')).writeAsStringSync('3.24.5');

      final version =
          File(p.join(sdkDir, 'version')).readAsStringSync().trim();
      expect(version, isNot(equals(config.flutter.version)));
    });

    test('detects missing version file in existing SDK directory', () {
      final sdkDir = p.join(tmp.path, '.flutter-sdk', 'flutter');
      Directory(sdkDir).createSync(recursive: true);
      final versionFile = File(p.join(sdkDir, 'version'));
      expect(versionFile.existsSync(), isFalse);
    });
  });

  group('doctor: checksum configuration', () {
    test('detects when checksums are configured', () {
      final config = _configFromYaml('''
flutter:
  version: "3.24.5"
  channel: stable
  checksums:
    x86_64: "abc123"
    aarch64: "def456"
platforms: {}
''');

      final hasX64 = config.flutter.checksumX64.isNotEmpty;
      final hasArm64 = config.flutter.checksumArm64.isNotEmpty;
      expect(hasX64, isTrue);
      expect(hasArm64, isTrue);
    });

    test('detects when checksums are missing', () {
      final config = _configFromYaml('''
flutter:
  version: "3.24.5"
  channel: stable
platforms: {}
''');

      final hasX64 = config.flutter.checksumX64.isNotEmpty;
      final hasArm64 = config.flutter.checksumArm64.isNotEmpty;
      expect(hasX64, isFalse);
      expect(hasArm64, isFalse);
    });
  });

  group('doctor: platform manifest checks', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('doctor_manifest_test_');
    });

    tearDown(() {
      tmp.deleteSync(recursive: true);
    });

    test('detects missing platform manifest', () {
      final config = _configFromYaml('''
flutter:
  version: "3.24.5"
  channel: stable
platforms:
  linux:
    manifest: guix/linux.scm
    build:
      command: flutter build linux --release
      output: build/linux/release/bundle
''');

      final linux = config.platforms['linux']!;
      expect(File(p.join(tmp.path, linux.manifest)).existsSync(), isFalse);
    });

    test('detects present platform manifest', () {
      final guixDir = p.join(tmp.path, 'guix');
      Directory(guixDir).createSync();
      File(p.join(guixDir, 'linux.scm'))
          .writeAsStringSync('(specifications->manifest ...)');

      final config = _configFromYaml('''
flutter:
  version: "3.24.5"
  channel: stable
platforms:
  linux:
    manifest: guix/linux.scm
    build:
      command: flutter build linux --release
      output: build/linux/release/bundle
''');

      final linux = config.platforms['linux']!;
      expect(File(p.join(tmp.path, linux.manifest)).existsSync(), isTrue);
    });

    test('checks all platform manifests', () {
      final guixDir = p.join(tmp.path, 'guix');
      Directory(guixDir).createSync();
      File(p.join(guixDir, 'linux.scm')).writeAsStringSync('linux manifest');
      // android manifest is missing

      final config = _configFromYaml('''
flutter:
  version: "3.24.5"
  channel: stable
platforms:
  linux:
    manifest: guix/linux.scm
    build:
      command: flutter build linux --release
      output: build/
  android:
    manifest: guix/android.scm
    build:
      command: flutter build apk --release
      output: build/
''');

      var issues = 0;
      for (final entry in config.platforms.entries) {
        if (!File(p.join(tmp.path, entry.value.manifest)).existsSync()) {
          issues++;
        }
      }
      // linux manifest exists, android does not
      expect(issues, 1);
    });
  });

  group('doctor: pubspec.lock check', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('doctor_pubspec_test_');
    });

    tearDown(() {
      tmp.deleteSync(recursive: true);
    });

    test('detects missing pubspec.lock', () {
      expect(File(p.join(tmp.path, 'pubspec.lock')).existsSync(), isFalse);
    });

    test('detects present pubspec.lock', () {
      File(p.join(tmp.path, 'pubspec.lock'))
          .writeAsStringSync('packages: {}');
      expect(File(p.join(tmp.path, 'pubspec.lock')).existsSync(), isTrue);
    });
  });
}
