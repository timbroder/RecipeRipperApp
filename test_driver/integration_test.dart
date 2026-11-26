// Host-side driver for integration_test/pipeline_harness_test.dart.
//
// The harness runs on the simulator or device and reports what each pipeline
// stage saw and produced. This driver runs on the Mac: it prints that report,
// saves it to harness_runs/<video-id>/<timestamp>.json, and, if
// integration_test/references/<video-id>.md exists (a Python CLI run in its
// Markdown output format), compares the ingredients with it.
//
// Printing here rather than on the device avoids device log truncation.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

import 'harness_report.dart';

Future<void> main() => integrationDriver(
      timeout: const Duration(minutes: 20),
      responseDataCallback: (data) async {
        if (data == null) {
          print('The harness reported no data.');
          exit(1);
        }

        final id = videoId(data['url'] as String? ?? 'unknown');
        final stamp = DateTime.now()
            .toIso8601String()
            .split('.')
            .first
            .replaceAll(':', '-');
        final file = File('harness_runs/$id/$stamp.json')
          ..createSync(recursive: true)
          ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));

        printReportWithReference(data);
        print('\nSaved ${file.path}');

        if (data['error'] != null) exit(1);
      },
    );
