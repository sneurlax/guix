import 'dart:io';
import 'package:path/path.dart' as p;

/// Reads .env files and discovers project structure.
/// Shares configuration with the bash scripts: both read the same files.
class ProjectConfig {
  final String projectRoot;
  final String guixDir;
  final FlutterEnv flutter;
  final AndroidSdkEnv? androidSdk;
  final List<String> platforms;

  ProjectConfig._({
    required this.projectRoot,
    required this.guixDir,
    required this.flutter,
    this.androidSdk,
    required this.platforms,
  });

  /// Resolve project config from the current directory.
  /// Reads guix-flutter.conf, flutter_version.env, android_sdk_version.env.
  /// Discovers platforms from guix/<dir>/manifests/*.scm files.
  static ProjectConfig load() {
    final projectRoot = Directory.current.path;

    // Read guix-flutter.conf for the scripts directory name.
    var guixDir = 'guix';
    final confFile = File(p.join(projectRoot, 'guix-flutter.conf'));
    if (confFile.existsSync()) {
      final vars = _parseEnvFile(confFile.path);
      guixDir = vars['GUIX_FLUTTER_DIR'] ?? 'guix';
    }

    // Read flutter_version.env
    final flutterEnvFile = File(p.join(projectRoot, 'flutter_version.env'));
    final flutterVars = flutterEnvFile.existsSync()
        ? _parseEnvFile(flutterEnvFile.path)
        : <String, String>{};

    final flutter = FlutterEnv(
      version: flutterVars['FLUTTER_VERSION'] ?? '',
      channel: flutterVars['FLUTTER_CHANNEL'] ?? 'stable',
      sha256X64: flutterVars['FLUTTER_SHA256_X64'] ?? '',
      sha256Arm64: flutterVars['FLUTTER_SHA256_ARM64'] ?? '',
    );

    // Read android_sdk_version.env (optional)
    final androidEnvFile = File(p.join(projectRoot, 'android_sdk_version.env'));
    AndroidSdkEnv? androidSdk;
    if (androidEnvFile.existsSync()) {
      final vars = _parseEnvFile(androidEnvFile.path);
      androidSdk = AndroidSdkEnv(
        cmdlineToolsBuild: vars['ANDROID_CMDLINE_TOOLS_BUILD'] ?? '',
        cmdlineToolsSha256: vars['ANDROID_CMDLINE_TOOLS_SHA256'] ?? '',
        platformVersion: vars['ANDROID_PLATFORM_VERSION'] ?? '',
        buildToolsVersion: vars['ANDROID_BUILD_TOOLS_VERSION'] ?? '',
        ndkVersion: vars['ANDROID_NDK_VERSION'] ?? '',
      );
    }

    // Discover platforms from manifests/*.scm files.
    // channels.scm is not a platform, so exclude it.
    final manifestsDir = Directory(p.join(projectRoot, guixDir, 'manifests'));
    final platforms = <String>[];
    if (manifestsDir.existsSync()) {
      for (final entity in manifestsDir.listSync()) {
        if (entity is File && entity.path.endsWith('.scm')) {
          final name = p.basenameWithoutExtension(entity.path);
          if (name != 'channels') {
            platforms.add(name);
          }
        }
      }
      platforms.sort();
    }

    return ProjectConfig._(
      projectRoot: projectRoot,
      guixDir: guixDir,
      flutter: flutter,
      androidSdk: androidSdk,
      platforms: platforms,
    );
  }

  /// Path to a script in the guix scripts directory.
  String scriptPath(String name) =>
      p.join(projectRoot, guixDir, 'scripts', name);

  /// Path to the manifests directory.
  String get manifestsPath => p.join(projectRoot, guixDir, 'manifests');

  /// Path to channels.scm.
  String get channelsPath =>
      p.join(projectRoot, guixDir, 'manifests', 'channels.scm');

  /// Path to pin-channels.sh.
  String get pinChannelsScript =>
      p.join(projectRoot, guixDir, 'pin-channels.sh');

  /// Path to bootstrap.sh.
  String get bootstrapScript =>
      p.join(projectRoot, guixDir, 'bootstrap.sh');

  /// Whether the guix scripts directory exists (subtree installed).
  bool get hasScripts =>
      Directory(p.join(projectRoot, guixDir, 'scripts')).existsSync();

  /// Check if a platform has a shell script.
  bool hasShellScript(String platform) =>
      File(scriptPath('shell-$platform.sh')).existsSync();

  /// Check if a platform has a build script.
  bool hasBuildScript(String platform) =>
      File(scriptPath('build-$platform.sh')).existsSync();

  /// Parse a simple KEY="value" env file. Handles comments and blank lines.
  static Map<String, String> _parseEnvFile(String path) {
    final result = <String, String>{};
    final lines = File(path).readAsLinesSync();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final eq = trimmed.indexOf('=');
      if (eq < 0) continue;
      final key = trimmed.substring(0, eq).trim();
      var value = trimmed.substring(eq + 1).trim();
      // Strip surrounding quotes.
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
           (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      result[key] = value;
    }
    return result;
  }
}

class FlutterEnv {
  final String version;
  final String channel;
  final String sha256X64;
  final String sha256Arm64;

  const FlutterEnv({
    required this.version,
    required this.channel,
    this.sha256X64 = '',
    this.sha256Arm64 = '',
  });
}

class AndroidSdkEnv {
  final String cmdlineToolsBuild;
  final String cmdlineToolsSha256;
  final String platformVersion;
  final String buildToolsVersion;
  final String ndkVersion;

  const AndroidSdkEnv({
    required this.cmdlineToolsBuild,
    required this.cmdlineToolsSha256,
    required this.platformVersion,
    required this.buildToolsVersion,
    required this.ndkVersion,
  });
}
