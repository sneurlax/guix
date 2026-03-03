import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:guix/src/config/project_config.dart';

class BuildCommand extends Command<int> {
  @override
  final String name = 'build';

  @override
  final String description = 'Build inside a reproducible Guix environment.';

  BuildCommand() {
    argParser.addFlag('pinned', abbr: 'p', defaultsTo: true,
        help: 'Use pinned Guix channels (default: on)');
  }

  @override
  String get invocation => '${runner!.executableName} build <platform>';

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      stderr.writeln('Error: platform argument required.');
      stderr.writeln('Available: ${_availablePlatforms()}');
      return 1;
    }

    final platform = argResults!.rest.first;
    final pinned = argResults!['pinned'] as bool;
    final config = ProjectConfig.load();

    if (!config.hasBuildScript(platform)) {
      stderr.writeln('No build script for platform: $platform');
      stderr.writeln('Available: ${config.platforms.join(', ')}');
      return 1;
    }

    final script = config.scriptPath('build-$platform.sh');
    final args = pinned ? ['--pinned'] : <String>[];

    print('Building $platform${pinned ? ' (pinned)' : ''}...');
    final process = await Process.start(
      'bash', [script, ...args],
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }

  String _availablePlatforms() {
    try {
      return ProjectConfig.load().platforms.join(', ');
    } catch (_) {
      return '(unknown)';
    }
  }
}
