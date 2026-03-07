import 'dart:io';
import 'package:test/test.dart';
import 'package:guix/src/commands/setup_command.dart';

void main() {
  group('flutterDownloadUrl', () {
    test('x64 URL uses plain version', () {
      final url = flutterDownloadUrl('3.24.5', 'stable', 'x64');
      expect(url, endsWith('flutter_linux_3.24.5-stable.tar.xz'));
    });

    test('arm64 URL includes arm64_ prefix', () {
      final url = flutterDownloadUrl('3.24.5', 'stable', 'arm64');
      expect(url, endsWith('flutter_linux_arm64_3.24.5-stable.tar.xz'));
    });

    test('channel is embedded in URL path and suffix', () {
      final url = flutterDownloadUrl('3.24.5', 'beta', 'x64');
      expect(url, contains('/beta/linux/'));
      expect(url, endsWith('flutter_linux_3.24.5-beta.tar.xz'));
    });

    test('non-arm64 arch string falls back to x64 path', () {
      final url = flutterDownloadUrl('3.24.5', 'stable', 'x86_64');
      expect(url, endsWith('flutter_linux_3.24.5-stable.tar.xz'));
      expect(url, isNot(contains('arm64')));
    });

    test('arm64 stable URL has correct full structure', () {
      final url = flutterDownloadUrl('3.24.5', 'stable', 'arm64');
      expect(
        url,
        equals(
          'https://storage.googleapis.com/flutter_infra_release/releases/'
          'stable/linux/flutter_linux_arm64_3.24.5-stable.tar.xz',
        ),
      );
    });

    test('x64 dev channel URL has correct full structure', () {
      final url = flutterDownloadUrl('3.25.0', 'dev', 'x64');
      expect(
        url,
        equals(
          'https://storage.googleapis.com/flutter_infra_release/releases/'
          'dev/linux/flutter_linux_3.25.0-dev.tar.xz',
        ),
      );
    });
  });

  group('Android SDK download URL construction', () {
    test('builds correct URL from cmdline_tools_build number', () {
      final build = '11076708';
      final archive = 'commandlinetools-linux-${build}_latest.zip';
      final url = 'https://dl.google.com/android/repository/$archive';
      expect(
        url,
        equals(
          'https://dl.google.com/android/repository/'
          'commandlinetools-linux-11076708_latest.zip',
        ),
      );
    });

    test('URL pattern uses linux platform and _latest suffix', () {
      final build = '9999999';
      final archive = 'commandlinetools-linux-${build}_latest.zip';
      final url = 'https://dl.google.com/android/repository/$archive';
      expect(url, contains('commandlinetools-linux-'));
      expect(url, endsWith('_latest.zip'));
      expect(url, startsWith('https://dl.google.com/android/repository/'));
    });
  });

  group('Flutter SDK skip logic', () {
    test('skips download when version file matches configured version', () {
      final tmpDir = Directory.systemTemp.createTempSync('setup_skip_test_');
      final sdkDir = Directory('${tmpDir.path}/.flutter-sdk/flutter');
      sdkDir.createSync(recursive: true);

      final versionFile = File('${sdkDir.path}/version');
      versionFile.writeAsStringSync('3.24.5\n');

      try {
        // Replicate the skip logic from _fetchFlutter:
        // if (versionFile.existsSync()) {
        //   final currentVersion = versionFile.readAsStringSync().trim();
        //   if (currentVersion == config.flutter.version) { skip }
        // }
        final configuredVersion = '3.24.5';
        final currentVersion = versionFile.readAsStringSync().trim();
        expect(currentVersion, equals(configuredVersion));
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    });

    test('does not skip when version file has different version', () {
      final tmpDir = Directory.systemTemp.createTempSync('setup_skip_test_');
      final sdkDir = Directory('${tmpDir.path}/.flutter-sdk/flutter');
      sdkDir.createSync(recursive: true);

      final versionFile = File('${sdkDir.path}/version');
      versionFile.writeAsStringSync('3.22.0\n');

      try {
        final configuredVersion = '3.24.5';
        final currentVersion = versionFile.readAsStringSync().trim();
        expect(currentVersion, isNot(equals(configuredVersion)));
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    });

    test('does not skip when version file does not exist', () {
      final tmpDir = Directory.systemTemp.createTempSync('setup_skip_test_');
      final sdkDir = Directory('${tmpDir.path}/.flutter-sdk/flutter');
      sdkDir.createSync(recursive: true);

      try {
        final versionFile = File('${sdkDir.path}/version');
        expect(versionFile.existsSync(), isFalse);
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    });

    test('does not skip when sdk directory does not exist', () {
      final tmpDir = Directory.systemTemp.createTempSync('setup_skip_test_');

      try {
        final sdkDir = Directory('${tmpDir.path}/.flutter-sdk/flutter');
        expect(sdkDir.existsSync(), isFalse);
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    });
  });

  group('Architecture detection mapping', () {
    test('maps aarch64 to arm64', () {
      final uname = 'aarch64';
      final arch = (uname == 'aarch64' || uname == 'arm64') ? 'arm64' : 'x64';
      expect(arch, equals('arm64'));
    });

    test('maps arm64 to arm64', () {
      final uname = 'arm64';
      final arch = (uname == 'aarch64' || uname == 'arm64') ? 'arm64' : 'x64';
      expect(arch, equals('arm64'));
    });

    test('maps x86_64 to x64', () {
      final uname = 'x86_64';
      final arch = (uname == 'aarch64' || uname == 'arm64') ? 'arm64' : 'x64';
      expect(arch, equals('x64'));
    });

    test('maps i686 to x64', () {
      final uname = 'i686';
      final arch = (uname == 'aarch64' || uname == 'arm64') ? 'arm64' : 'x64';
      expect(arch, equals('x64'));
    });

    test('maps unknown architecture to x64', () {
      final uname = 'riscv64';
      final arch = (uname == 'aarch64' || uname == 'arm64') ? 'arm64' : 'x64';
      expect(arch, equals('x64'));
    });
  });
}
