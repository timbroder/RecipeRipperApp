// Re-print a saved pipeline harness run.
//
//   dart run tool/harness_report.dart harness_runs/<video-id>/<timestamp>.json
//
// With no argument it prints the most recent run.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import '../test_driver/harness_report.dart';

void main(List<String> args) {
  final path = args.isNotEmpty ? args.first : latestRun();
  if (path == null) {
    print('No runs in harness_runs/. Run tool/harness.sh <url> first.');
    exit(1);
  }
  final data =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  printReportWithReference(data);
  print('\n(from $path)');
}

String? latestRun() {
  final dir = Directory('harness_runs');
  if (!dir.existsSync()) return null;
  final runs = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  return runs.isEmpty ? null : runs.first.path;
}
