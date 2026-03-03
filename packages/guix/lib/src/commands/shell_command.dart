import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:guix/src/config/project_config.dart';

class ShellCommand extends Command<int> {
  @override
  final String name = 'shell';

  @override
  final String description = 'Enter an interactive Guix development shell.';

  ShellCommand() {
    argParser.addFlag('pinned', abbr: 'p',
        help: 'Use pinned Guix channels (slower, reproducible)');
  }

  @override
  String get invocation => '${runner!.executableName} shell <platform>';

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

    if (!config.hasShellScript(platform)) {
      stderr.writeln('No shell script for platform: $platform');
      stderr.writeln('Available: ${config.platforms.join(', ')}');
      return 1;
    }

    final script = config.scriptPath('shell-$platform.sh');
    final args = pinned ? ['--pinned'] : <String>[];

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
      return '(unknown: no config found)';
    }
  }
}
