// Prints a pipeline harness report (see integration_test/pipeline_harness_test.dart).
//
// Used by the flutter drive driver (test_driver/integration_test.dart) after a
// run, and by tool/harness_report.dart to re-print a saved run.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Print [data] and compare it with the reference run for its video, if one
/// exists under integration_test/references/.
void printReportWithReference(Map<String, dynamic> data) {
  final id = videoId(data['url'] as String? ?? 'unknown');
  final reference = File('integration_test/references/$id.md');
  printReport(
    data,
    reference.existsSync() ? reference.readAsStringSync() : null,
    referencePath: reference.path,
  );
}

/// A stable id for a URL: the YouTube video id, or a sanitized host + path.
String videoId(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return 'unknown';
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (uri.host.contains('youtube.com')) {
    final v = uri.queryParameters['v'];
    if (v != null) return v;
    if (segments.length >= 2) return segments[1]; // shorts/<id>, live/<id>
  }
  if (uri.host.contains('youtu.be') && segments.isNotEmpty) {
    return segments.first;
  }
  return '${uri.host}_${segments.join('_')}'
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}

// ─────────────────────────────────────────────────────────────
// Report
// ─────────────────────────────────────────────────────────────

void printReport(
  Map<String, dynamic> data,
  String? reference, {
  required String referencePath,
}) {
  final bar = '═' * 64;
  print('\n$bar\nPIPELINE HARNESS  ${data['url']}\n$bar');
  print('Total: ${seconds(data['totalMs'])}');

  final metadata = data['metadata'] as Map<String, dynamic>?;
  if (metadata != null) {
    heading('Download + metadata');
    print('Title: ${metadata['title']}');
    print('Duration: ${seconds(metadata['durationMs'])}   '
        'Resolution: ${metadata['resolution']}   '
        'Size: ${megabytes(metadata['fileSizeBytes'])}');
    final description = metadata['description'] as String?;
    print('Description (${description?.length ?? 0} chars):');
    print(indent(description ?? '(none)'));
  }

  final webRecipe = data['webRecipe'] as Map<String, dynamic>?;
  if (webRecipe != null) {
    heading('Web page recipe (${webRecipe['extractionMethod']})');
    print('No video to process; the recipe came straight from the page.');
  }

  for (final event in (data['trace'] as List<dynamic>? ?? [])) {
    printEvent(event as Map<String, dynamic>);
  }

  final error = data['error'];
  if (error != null) {
    heading('ERROR');
    print(error);
    print(indent(data['stack'] as String? ?? ''));
  }

  final recipe =
      (data['recipe'] ?? (webRecipe?['recipe'])) as Map<String, dynamic>?;
  if (recipe != null) {
    printRecipe(recipe);
    if (reference != null) {
      compareWithReference(recipe, reference, referencePath);
    } else {
      heading('Reference');
      print('No reference at $referencePath. Save a Python CLI run there '
          '(its Markdown output) to compare.');
    }
  }
}

void printEvent(Map<String, dynamic> event) {
  final stage = event['stage'] as String;
  final at = '@ ${seconds(event['elapsedMs'])}';
  final d = event['data'] as Map<String, dynamic>;

  switch (stage) {
    case 'pipeline.start':
      heading('Processing starts $at');
      print('LLM: ${d['llmService'] ?? 'none'} '
          '(${d['llmAvailable'] == true ? 'available' : 'NOT available'})');
      print('Video title passed to the pipeline: ${d['videoTitle']}');
    case 'description.filtered':
      heading('Description fast path $at');
      final text = d['text'] as String;
      print(text.trim().isEmpty
          ? 'Nothing left after the noise filter, so the fast path is skipped.'
          : 'Sending the description (${text.length} chars after the noise '
              'filter) to the LLM on its own.');
    case 'description.result':
      final accepted = d['accepted'] == true;
      print(
          'Fast path ${accepted ? 'ACCEPTED: skipping transcript and OCR' : 'rejected'}'
          ' (success: ${d['success']}, '
          '${(d['ingredients'] as List).length} ingredients, '
          '${(d['directions'] as List).length} directions'
          '${d['error'] != null ? ', error: ${d['error']}' : ''})');
      final grounding = d['grounding'] as Map<String, dynamic>?;
      if (grounding != null) {
        final ungrounded = grounding['ungrounded'] as List;
        print('Grounding: ${grounding['grounded']}/${grounding['total']} '
            'ingredients appear in the description, '
            '${grounding['quantified']} of them with quantities'
            '${ungrounded.isEmpty ? '' : '; not in it: ${ungrounded.join(', ')}'}');
        if (grounding['rejectionReason'] != null) {
          print('Rejected because ${grounding['rejectionReason']}');
        }
      }
    case 'audio':
      heading('Audio extracted (FFmpeg) $at');
    case 'transcript.error':
      heading('Transcription error $at');
      print('${d['code']}: ${d['message']}\n${indent('${d['details']}')}');
    case 'transcript':
      heading('Transcript (Speech) $at  ${d['chars']} chars, '
          'confidence ${d['confidence']}');
      print(indent(d['text'] as String));
    case 'ocr':
      heading('On-screen text (Vision OCR) $at  ${d['frameCount']} frames, '
          '${d['chars']} chars');
      print(indent(clip(d['text'] as String, 3000)));
    case 'llm.input':
      heading('Full extraction $at');
      print('Combined input: ${d['chars']} chars');
    case 'llm.retry':
      print(
          'Retrying with shorter input (${d['reason']}, ${d['chars']} chars)');
    case 'llm.request':
      print('\n› Request to ${d['service']} $at');
      if (d['instructions'] != null) {
        print('Instructions:\n${indent(d['instructions'] as String)}');
      }
      print('Prompt:\n${indent(d['prompt'] as String)}');
    case 'llm.response':
      print('\n‹ Raw response $at');
      print(indent((d['raw'] as String?) ?? '(null)'));
    case 'llm.error':
      print('\n‹ LLM error $at: ${d['code']} ${d['message']}');
    case 'llm.result':
      print('\nParsed: success ${d['success']}, '
          '${(d['ingredients'] as List).length} ingredients, '
          '${(d['directions'] as List).length} directions'
          '${d['error'] != null ? ', error: ${d['error']}' : ''}');
    case 'postprocess':
      heading('Post-processing $at (${d['processingMethod']})');
      final added = d['autoAddedIngredients'] as List;
      print('Cross-reference added: '
          '${added.isEmpty ? 'nothing' : added.join(', ')}');
      final warnings = d['warnings'] as List;
      if (warnings.isNotEmpty) {
        print('Warnings:\n${indent(warnings.join('\n'))}');
      }
      final raw = d['rawDirections'] as List;
      final converted = d['imperativeDirections'] as List;
      for (var i = 0; i < raw.length && i < converted.length; i++) {
        if (raw[i] != converted[i]) {
          print('Rewrote step ${i + 1}: "${raw[i]}" → "${converted[i]}"');
        }
      }
    case 'heuristic':
      heading('Heuristic fallback $at (${d['reason']})');
    case 'pipeline.done':
      final score = d['confidenceScore'] as Map<String, dynamic>?;
      heading('Done $at  method: ${d['processingMethod']}, '
          'confidence: ${(score?['overall'] as num?)?.toStringAsFixed(2) ?? '?'}');
    case 'pipeline.error':
      heading('Pipeline error $at');
      print(d['error']);
    default:
      heading('$stage $at');
      print(indent(const JsonEncoder.withIndent('  ').convert(d)));
  }
}

void printRecipe(Map<String, dynamic> recipe) {
  final ingredients = recipe['ingredients'] as List<dynamic>;
  final directions = recipe['directions'] as List<dynamic>;
  final metadata = recipe['metadata'] as Map<String, dynamic>?;

  heading('FINAL RECIPE');
  print('Title: ${recipe['title']}');
  print('\nIngredients (${ingredients.length}):');
  for (final i in ingredients) {
    print('  - ${describeIngredient(i as Map<String, dynamic>)}');
  }
  print('\nDirections (${directions.length}):');
  for (final d in directions) {
    final step = d as Map<String, dynamic>;
    print('  ${step['stepNumber']}. ${step['text']}');
  }
  final warnings = metadata?['warnings'] as List<dynamic>? ?? [];
  if (warnings.isNotEmpty) {
    print('\nWarnings:');
    for (final w in warnings) {
      print('  ! $w');
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Reference comparison
// ─────────────────────────────────────────────────────────────

void compareWithReference(
  Map<String, dynamic> recipe,
  String reference,
  String referencePath,
) {
  final refIngredients = markdownSection(reference, 'Ingredients')
      .where((l) => l.startsWith('- '))
      .map((l) => l.substring(2).trim())
      .toList();
  final refDirections = markdownSection(reference, 'Directions')
      .where((l) => RegExp(r'^\d+\.').hasMatch(l))
      .toList();
  final appIngredients = (recipe['ingredients'] as List<dynamic>)
      .map((i) => describeIngredient(i as Map<String, dynamic>))
      .toList();
  final appDirections = recipe['directions'] as List<dynamic>;

  // Pair ingredients by name overlap, best matches first.
  final pairs = <(int, int, double)>[];
  for (var r = 0; r < refIngredients.length; r++) {
    for (var a = 0; a < appIngredients.length; a++) {
      final score = similarity(refIngredients[r], appIngredients[a]);
      if (score >= 0.5) pairs.add((r, a, score));
    }
  }
  pairs.sort((x, y) => y.$3.compareTo(x.$3));
  final matchedRef = <int, int>{};
  final usedApp = <int>{};
  for (final (r, a, _) in pairs) {
    if (matchedRef.containsKey(r) || usedApp.contains(a)) continue;
    matchedRef[r] = a;
    usedApp.add(a);
  }

  heading('VS REFERENCE  $referencePath');
  print('Ingredients: ${matchedRef.length}/${refIngredients.length} '
      'reference ingredients found (app has ${appIngredients.length})');
  for (var r = 0; r < refIngredients.length; r++) {
    final a = matchedRef[r];
    print(a == null
        ? '  ✗ missing   ${refIngredients[r]}'
        : '  ✓ ${refIngredients[r].padRight(32)} app: ${appIngredients[a]}');
  }
  for (var a = 0; a < appIngredients.length; a++) {
    if (!usedApp.contains(a)) print('  + extra     ${appIngredients[a]}');
  }
  print('Directions: app ${appDirections.length}, '
      'reference ${refDirections.length}');
}

/// Lines under a `## <name>` heading, up to the next heading.
List<String> markdownSection(String markdown, String name) {
  final lines = markdown.split('\n');
  final start = lines.indexWhere((l) => l.trim() == '## $name');
  if (start < 0) return [];
  final section = <String>[];
  for (final line in lines.skip(start + 1)) {
    if (line.startsWith('#')) break;
    if (line.trim().isNotEmpty) section.add(line.trim());
  }
  return section;
}

const _ignoredWords = {
  'to', 'taste', 'of', 'a', 'an', 'the', 'and', 'or', 'some', 'little', //
  'bit', 'g', 'gram', 'kg', 'lb', 'pound', 'oz', 'ounce', 'cup', 'tbsp',
  'tablespoon', 'tsp', 'teaspoon', 'slice', 'packet', 'can', 'pinch',
  'ml', 'l', 'clove', 'piece',
};

/// Jaccard overlap of the ingredient-name words in two ingredient lines.
double similarity(String a, String b) {
  final x = nameWords(a);
  final y = nameWords(b);
  if (x.isEmpty || y.isEmpty) return 0;
  return x.intersection(y).length / x.union(y).length;
}

Set<String> nameWords(String line) => withoutAccents(line.toLowerCase())
    .replaceAll(RegExp(r'[^a-z ]'), ' ')
    .split(' ')
    .where((w) => w.isNotEmpty)
    .map((w) =>
        w.length > 3 && w.endsWith('s') ? w.substring(0, w.length - 1) : w)
    .where((w) => !_ignoredWords.contains(w))
    .toSet();

const _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ñ': 'n', 'ç': 'c',
};

/// "jalapeño" → "jalapeno", so accented and plain spellings match.
String withoutAccents(String text) =>
    text.split('').map((c) => _accents[c] ?? c).join();

// ─────────────────────────────────────────────────────────────
// Formatting helpers
// ─────────────────────────────────────────────────────────────

String describeIngredient(Map<String, dynamic> i) {
  final quantity = i['quantity'] as num?;
  final quantityText = quantity == null
      ? null
      : quantity == quantity.roundToDouble()
          ? quantity.toInt().toString()
          : quantity.toString();
  return [
    quantityText,
    i['unit'] as String?,
    i['item'] as String?,
    if (i['notes'] != null) '(${i['notes']})',
  ].where((p) => p != null && p.isNotEmpty).join(' ');
}

void heading(String title) =>
    print('\n── $title ${'─' * (60 - title.length).clamp(0, 60)}');

String indent(String text) => text.split('\n').map((l) => '    $l').join('\n');

String clip(String text, int max) => text.length <= max
    ? text
    : '${text.substring(0, max)}… (${text.length - max} more chars in the JSON)';

String seconds(Object? ms) =>
    ms is num ? '${(ms / 1000).toStringAsFixed(1)}s' : '?';

String megabytes(Object? bytes) =>
    bytes is num ? '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB' : '?';
