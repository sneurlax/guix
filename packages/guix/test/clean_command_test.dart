import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:guix/src/commands/clean_command.dart';

void main() {
  late Directory tmp;
  late CommandRunner<int> runner;
  late String origDir;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('clean_test_');
    origDir = Directory.current.path;
    Directory.current = tmp.path;
    runner = CommandRunner<int>('guix_dart', 'test');
    runner.addCommand(CleanCommand());
  });

  tearDown(() {
    Directory.current = origDir;
    tmp.deleteSync(recursive: true);
  });

  group('CleanCommand', () {
    test('--all removes .flutter-sdk, .android-sdk, and build/', () async {
      // Create the directories that --all should clean
      Directory('${tmp.path}/.flutter-sdk').createSync();
      Directory('${tmp.path}/.android-sdk').createSync();
      Directory('${tmp.path}/build').createSync();

      final code = await runner.run(['clean', '--all']);
      expect(code, 0);
      expect(Directory('${tmp.path}/.flutter-sdk').existsSync(), isFalse);
      expect(Directory('${tmp.path}/.android-sdk').existsSync(), isFalse);
      expect(Directory('${tmp.path}/build').existsSync(), isFalse);
    });

    test('no args (no targets) cleans same as --all', () async {
      Directory('${tmp.path}/.flutter-sdk').createSync();
      Directory('${tmp.path}/.android-sdk').createSync();
      Directory('${tmp.path}/build').createSync();

      final code = await runner.run(['clean']);
      expect(code, 0);
      expect(Directory('${tmp.path}/.flutter-sdk').existsSync(), isFalse);
      expect(Directory('${tmp.path}/.android-sdk').existsSync(), isFalse);
      expect(Directory('${tmp.path}/build').existsSync(), isFalse);
    });

    test('linux target only removes build/linux/', () async {
      // Create dirs: build/linux should be removed, others should remain
      Directory('${tmp.path}/build/linux').createSync(recursive: true);
      Directory('${tmp.path}/.flutter-sdk').createSync();
      Directory('${tmp.path}/.android-sdk').createSync();

      final code = await runner.run(['clean', 'linux']);
      expect(code, 0);
      expect(Directory('${tmp.path}/build/linux').existsSync(), isFalse);
      // Other dirs should survive
      expect(Directory('${tmp.path}/.flutter-sdk').existsSync(), isTrue);
      expect(Directory('${tmp.path}/.android-sdk').existsSync(), isTrue);
    });

    test('android target removes .android-sdk and build/app', () async {
      Directory('${tmp.path}/.android-sdk').createSync();
      Directory('${tmp.path}/build/app').createSync(recursive: true);
      Directory('${tmp.path}/.flutter-sdk').createSync();

      final code = await runner.run(['clean', 'android']);
      expect(code, 0);
      expect(Directory('${tmp.path}/.android-sdk').existsSync(), isFalse);
      expect(Directory('${tmp.path}/build/app').existsSync(), isFalse);
      // Flutter SDK should survive
      expect(Directory('${tmp.path}/.flutter-sdk').existsSync(), isTrue);
    });

    test('flutter target only removes .flutter-sdk', () async {
      Directory('${tmp.path}/.flutter-sdk').createSync();
      Directory('${tmp.path}/.android-sdk').createSync();

      final code = await runner.run(['clean', 'flutter']);
      expect(code, 0);
      expect(Directory('${tmp.path}/.flutter-sdk').existsSync(), isFalse);
      expect(Directory('${tmp.path}/.android-sdk').existsSync(), isTrue);
    });

    test('unknown target maps to build/<target>', () async {
      Directory('${tmp.path}/build/web').createSync(recursive: true);

      final code = await runner.run(['clean', 'web']);
      expect(code, 0);
      expect(Directory('${tmp.path}/build/web').existsSync(), isFalse);
    });

    test('non-existent directories do not cause an error', () async {
      // No directories exist at all -- should still return 0
      final code = await runner.run(['clean', '--all']);
      expect(code, 0);
    });

    test('non-existent target directory does not cause an error', () async {
      final code = await runner.run(['clean', 'linux']);
      expect(code, 0);
    });

    test('multiple targets can be specified at once', () async {
      Directory('${tmp.path}/build/linux').createSync(recursive: true);
      Directory('${tmp.path}/.flutter-sdk').createSync();
      Directory('${tmp.path}/.android-sdk').createSync();

      final code = await runner.run(['clean', 'linux', 'flutter']);
      expect(code, 0);
      expect(Directory('${tmp.path}/build/linux').existsSync(), isFalse);
      expect(Directory('${tmp.path}/.flutter-sdk').existsSync(), isFalse);
      // android-sdk was not targeted
      expect(Directory('${tmp.path}/.android-sdk').existsSync(), isTrue);
    });

    test('--all with nested contents removes recursively', () async {
      final nested = Directory('${tmp.path}/build/linux/release/bundle');
      nested.createSync(recursive: true);
      File('${nested.path}/my_app').writeAsStringSync('binary');

      final code = await runner.run(['clean', '--all']);
      expect(code, 0);
      expect(Directory('${tmp.path}/build').existsSync(), isFalse);
    });
  });
}
