import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Directory('${Directory.systemTemp.path}/liquid-material-pass');
  await output.create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await File('${output.path}/$name.png').writeAsBytes(bytes);
      return true; // Captures for human review, not a golden-image assertion.
    },
    responseDataCallback: (_) async {},
  );
}
