import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:guix/src/config/guix_config.dart';
import 'package:guix/src/guix/guix_runner.dart';

String flutterDownloadUrl(String version, String channel, String arch) {
  final archSuffix = arch == 'arm64' ? 'arm64_$version' : version;
  return 'https://storage.googleapis.com/flutter_infra_release/releases/'
      '$channel/linux/flutter_linux_$archSuffix-$channel.tar.xz';
}

class SetupCommand extends Command<int> {
  @override
  final String name = 'setup';

  @override
  final String description = 'Fetch Flutter SDK and platform-specific SDKs.';

  @override
  Future<int> run() async {
    final config = GuixConfig.load();
    final platforms = argResults!.rest;

    // Determine which platforms to set up
    final targetPlatforms = platforms.isEmpty
        ? config.platformNames
        : platforms;

    // Always fetch Flutter SDK
    print('Setting up Flutter SDK ${config.flutter.version}...');
    final exitCode = await _fetchFlutter(config);
    if (exitCode != 0) return exitCode;

    // Fetch platform-specific SDKs
    for (final name in targetPlatforms) {
      final platform = config.platforms[name];
      if (platform == null) {
        stderr.writeln('Unknown platform: $name');
        stderr.writeln('Available: ${config.platformNames.join(', ')}');
        return 1;
      }
      if (platform.sdk.isNotEmpty) {
        print('Setting up $name SDK...');
        if (name == 'android') {
          final sdkExit = await _fetchAndroidSdk(config, platform);
          if (sdkExit != 0) return sdkExit;
        } else {
          print('  (platform SDK setup not yet implemented for $name)');
        }
      }
    }

    print('Setup complete.');
    return 0;
  }

  Future<int> _fetchFlutter(GuixConfig config) async {
    final sdkDir = Directory('.flutter-sdk/flutter');
    if (sdkDir.existsSync()) {
      // Check version
      final versionFile = File('.flutter-sdk/flutter/version');
      if (versionFile.existsSync()) {
        final currentVersion = versionFile.readAsStringSync().trim();
        if (currentVersion == config.flutter.version) {
          print('  Flutter ${config.flutter.version} already present.');
          return 0;
        }
      }
    }

    // Detect architecture
    final archResult = await Process.run('uname', ['-m']);
    final uname = (archResult.stdout as String).trim();
    final arch = (uname == 'aarch64' || uname == 'arm64') ? 'arm64' : 'x64';

    final version = config.flutter.version;
    final channel = config.flutter.channel;
    final url = flutterDownloadUrl(version, channel, arch);

    print('  Downloading Flutter $version ($arch)...');
    print('  $url');

    // Download
    final tmpDir = Directory('.flutter-sdk');
    if (!tmpDir.existsSync()) tmpDir.createSync(recursive: true);

    final downloadResult = await Process.start(
      'curl', ['-fSL', '-o', '.flutter-sdk/flutter.tar.xz', url],
      mode: ProcessStartMode.inheritStdio,
    );
    final dlExit = await downloadResult.exitCode;
    if (dlExit != 0) {
      stderr.writeln('  Failed to download Flutter SDK.');
      return dlExit;
    }

    // Verify checksum if configured
    final expectedHash = arch == 'arm64'
        ? config.flutter.checksumArm64
        : config.flutter.checksumX64;
    if (expectedHash.isNotEmpty) {
      print('  Verifying SHA-256...');
      final shaResult = await Process.run(
        'sha256sum', ['.flutter-sdk/flutter.tar.xz'],
      );
      final computedHash = (shaResult.stdout as String).split(' ').first;
      if (computedHash != expectedHash) {
        stderr.writeln('  Checksum mismatch!');
        stderr.writeln('  Expected: $expectedHash');
        stderr.writeln('  Got:      $computedHash');
        return 1;
      }
    } else {
      // Print computed hash for user to add to config
      final shaResult = await Process.run(
        'sha256sum', ['.flutter-sdk/flutter.tar.xz'],
      );
      final computedHash = (shaResult.stdout as String).split(' ').first;
      print('  SHA-256: $computedHash');
      print('  (add this to guix.yaml checksums.$arch for verification)');
    }

    // Extract
    print('  Extracting...');
    if (sdkDir.existsSync()) sdkDir.deleteSync(recursive: true);
    final extractResult = await Process.start(
      'tar', ['xf', '.flutter-sdk/flutter.tar.xz', '-C', '.flutter-sdk/'],
      mode: ProcessStartMode.inheritStdio,
    );
    final extExit = await extractResult.exitCode;
    if (extExit != 0) {
      stderr.writeln('  Failed to extract Flutter SDK.');
      return extExit;
    }

    // Clean up archive
    File('.flutter-sdk/flutter.tar.xz').deleteSync();
    print('  Flutter $version ready at .flutter-sdk/flutter/');
    return 0;
  }

  Future<int> _fetchAndroidSdk(
      GuixConfig config, PlatformConfig platform) async {
    final sdk = platform.sdk;
    final build = sdk['cmdline_tools_build'] ?? '';
    final sha256 = sdk['cmdline_tools_sha256'] ?? '';
    final platformVersion = sdk['platform_version'] ?? '';
    final buildToolsVersion = sdk['build_tools_version'] ?? '';
    final ndkVersion = sdk['ndk_version'] ?? '';

    if (build.isEmpty) {
      stderr.writeln('  Missing cmdline_tools_build in android sdk config.');
      return 1;
    }

    final sdkDir = '.android-sdk';
    final sdkmanager = '$sdkDir/cmdline-tools/latest/bin/sdkmanager';

    // Skip if everything is already installed.
    if (File(sdkmanager).existsSync() &&
        Directory('$sdkDir/platforms/$platformVersion').existsSync() &&
        Directory('$sdkDir/build-tools/$buildToolsVersion').existsSync() &&
        Directory('$sdkDir/ndk/$ndkVersion').existsSync()) {
      print('  Android SDK already configured in $sdkDir');
      return 0;
    }

    // Download cmdline-tools archive.
    final archive = 'commandlinetools-linux-${build}_latest.zip';
    final url = 'https://dl.google.com/android/repository/$archive';

    print('  Downloading Android cmdline-tools (build $build)...');
    print('  $url');

    final dir = Directory(sdkDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final dlResult = await Process.start(
      'curl',
      ['-fSL', '-o', '$sdkDir/$archive', url],
      mode: ProcessStartMode.inheritStdio,
    );
    final dlExit = await dlResult.exitCode;
    if (dlExit != 0) {
      stderr.writeln('  Failed to download Android cmdline-tools.');
      File('$sdkDir/$archive').deleteSync();
      return dlExit;
    }

    // Verify checksum if configured.
    if (sha256.isNotEmpty) {
      print('  Verifying SHA-256...');
      final shaResult =
          await Process.run('sha256sum', ['$sdkDir/$archive']);
      final computedHash =
          (shaResult.stdout as String).split(' ').first;
      if (computedHash != sha256) {
        stderr.writeln('  Checksum mismatch!');
        stderr.writeln('  Expected: $sha256');
        stderr.writeln('  Got:      $computedHash');
        File('$sdkDir/$archive').deleteSync();
        return 1;
      }
    } else {
      final shaResult =
          await Process.run('sha256sum', ['$sdkDir/$archive']);
      final computedHash =
          (shaResult.stdout as String).split(' ').first;
      print('  SHA-256: $computedHash');
      print(
          '  (add this to guix.yaml sdk.cmdline_tools_sha256 for verification)');
    }

    // Extract cmdline-tools.
    print('  Extracting cmdline-tools...');
    final cmdlineDir = Directory('$sdkDir/cmdline-tools');
    if (cmdlineDir.existsSync()) cmdlineDir.deleteSync(recursive: true);

    final unzipResult = await Process.start(
      'unzip',
      ['-q', '$sdkDir/$archive', '-d', sdkDir],
      mode: ProcessStartMode.inheritStdio,
    );
    final unzipExit = await unzipResult.exitCode;
    if (unzipExit != 0) {
      stderr.writeln('  Failed to extract cmdline-tools.');
      return unzipExit;
    }

    // Google's archive extracts to cmdline-tools/; sdkmanager expects
    // cmdline-tools/latest/, so move contents into place.
    Directory('$sdkDir/cmdline-tools/latest').createSync(recursive: true);
    for (final name in ['bin', 'lib']) {
      final src = Directory('$sdkDir/cmdline-tools/$name');
      if (src.existsSync()) {
        src.renameSync('$sdkDir/cmdline-tools/latest/$name');
      }
    }
    // Clean up leftover top-level files.
    for (final f in ['NOTICE.txt', 'source.properties']) {
      final file = File('$sdkDir/cmdline-tools/$f');
      if (file.existsSync()) file.deleteSync();
    }

    // Clean up archive.
    File('$sdkDir/$archive').deleteSync();

    // Pre-create license files for non-interactive acceptance.
    print('  Accepting Android SDK licenses...');
    final licensesDir = Directory('$sdkDir/licenses');
    licensesDir.createSync(recursive: true);
    File('$sdkDir/licenses/android-sdk-license')
        .writeAsStringSync('\n24333f8a63b6825ea9c5514f83c2829b004d1fee');
    File('$sdkDir/licenses/android-sdk-preview-license')
        .writeAsStringSync('\n84831b9409646a918e30573bab4c9c91346d8abd');
    File('$sdkDir/licenses/android-sdk-arm-dbt-license')
        .writeAsStringSync('\nd975f751698a77e662f1cd748a3e6214bff89f2f');
    File('$sdkDir/licenses/android-ndk-license')
        .writeAsStringSync('\ne9acab5b5fbb560a72797e892a6e86da757adb8a');

    // Run sdkmanager inside a guix shell (provides Java).
    print('  Installing SDK components via sdkmanager...');
    final verbose = globalResults!['verbose'] as bool;
    final guix = GuixRunner(verbose: verbose);
    final sdkRoot = Directory(sdkDir).absolute.path;

    final components = [
      'platform-tools',
      if (platformVersion.isNotEmpty) 'platforms;$platformVersion',
      if (buildToolsVersion.isNotEmpty) 'build-tools;$buildToolsVersion',
      if (ndkVersion.isNotEmpty) 'ndk;$ndkVersion',
    ];
    final sdkmanagerCmd =
        '$sdkRoot/cmdline-tools/latest/bin/sdkmanager '
        '--sdk_root="$sdkRoot" '
        '${components.map((c) => '"$c"').join(' ')}';

    final sdkExit = await guix.runInShell(
      manifest: platform.manifest,
      command: sdkmanagerCmd,
    );
    if (sdkExit != 0) {
      stderr.writeln('  sdkmanager failed with exit code $sdkExit');
      return sdkExit;
    }

    print('  Android SDK ready at $sdkDir');
    return 0;
  }
}
