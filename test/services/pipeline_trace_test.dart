import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/services/llm/llm_prompts.dart';
import 'package:recipe_ripper/services/llm/llm_service.dart';
import 'package:recipe_ripper/services/llm_recipe_extraction_service.dart';
import 'package:recipe_ripper/services/pipeline_trace.dart';

/// Returns a canned JSON reply, like a real model would.
class _CannedLlm extends LlmService {
  final String reply;
  _CannedLlm(this.reply);

  @override
  String get name => 'Canned';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<LlmExtractionResult> extractRecipe(String text,
          {String? videoTitle}) async =>
      LlmExtractionResult.fromJson(LlmPrompts.parseResponse(reply)!);

  @override
  Future<LlmExtractionResult> extractRecipeFromDescription(String description,
          {String? videoTitle}) =>
      extractRecipe(description, videoTitle: videoTitle);
}

const _reply =
    '{"title":"Toast","ingredients":["2 slices bread","1 tbsp butter"],'
    '"directions":["Toast the bread.","Spread the butter."]}';

void main() {
  group('PipelineTrace', () {
    test('record does nothing without a trace', () {
      expect(PipelineTrace.current, isNull);
      PipelineTrace.record('stage', {'a': 1}); // must not throw
    });

    test('capture records events, including after awaits', () async {
      final trace = PipelineTrace();
      final result = await trace.capture(() async {
        PipelineTrace.record('first', {'n': 1});
        await Future<void>.delayed(const Duration(milliseconds: 5));
        PipelineTrace.record('second', {'n': 2});
        return 'done';
      });

      expect(result, 'done');
      expect(trace.events.map((e) => e.stage), ['first', 'second']);
      expect(trace.events.last.data, {'n': 2});
      expect(trace.events.last.elapsedMs,
          greaterThanOrEqualTo(trace.events.first.elapsedMs));
      expect(PipelineTrace.current, isNull);
    });

    test('toJson is a list of stage/elapsedMs/data maps', () async {
      final trace = PipelineTrace();
      await trace.capture(() async => PipelineTrace.record('x', {'y': 'z'}));
      final json = trace.toJson().single;
      expect(json['stage'], 'x');
      expect(json['data'], {'y': 'z'});
      expect(json['elapsedMs'], isA<int>());
    });

    test('LLM extraction records its input, result and post-processing',
        () async {
      final trace = PipelineTrace();
      final recipe = await trace.capture(
        () => LlmRecipeExtractionService.tryFullLlm(
          transcript: 'Toast two slices of bread and spread butter on them.',
          ocrText: null,
          description: null,
          llmService: _CannedLlm(_reply),
          videoTitle: 'Toast',
        ),
      );

      expect(recipe, isNotNull);
      expect(trace.events.map((e) => e.stage),
          containsAllInOrder(['llm.input', 'llm.result', 'postprocess']));
      final result =
          trace.events.firstWhere((e) => e.stage == 'llm.result').data;
      expect(result['success'], isTrue);
      expect(result['ingredients'], ['2 slices bread', '1 tbsp butter']);
    });

    test('description fast path records whether it was accepted', () async {
      final trace = PipelineTrace();
      await trace.capture(
        () => LlmRecipeExtractionService.tryDescriptionOnly(
          description:
              'Toast: 2 slices bread, 1 tbsp butter. Toast and butter.',
          llmService: _CannedLlm(_reply),
        ),
      );

      final result =
          trace.events.firstWhere((e) => e.stage == 'description.result').data;
      expect(result['accepted'], isTrue);
    });
  });
}
