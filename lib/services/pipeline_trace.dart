import 'dart:async';

/// One thing a pipeline stage saw or produced.
class PipelineTraceEvent {
  /// Dotted stage name, e.g. `transcript` or `llm.response`.
  final String stage;

  /// Milliseconds since the trace started.
  final int elapsedMs;

  /// JSON-encodable details (strings, numbers, bools, lists, maps).
  final Map<String, Object?> data;

  PipelineTraceEvent(this.stage, this.elapsedMs, this.data);

  Map<String, Object?> toJson() => {
        'stage': stage,
        'elapsedMs': elapsedMs,
        'data': data,
      };
}

/// Records the inputs and outputs of each processing pipeline stage.
///
/// The app never installs a trace, so [record] does nothing in normal use and
/// the pipeline behaves exactly the same. The pipeline harness
/// (`integration_test/pipeline_harness_test.dart`) runs the real pipeline
/// inside [capture] to see the description fast path, transcript, OCR text,
/// prompts, raw model responses and post-processing.
class PipelineTrace {
  static final Object _zoneKey = Object();

  final List<PipelineTraceEvent> events = [];
  final Stopwatch _clock = Stopwatch()..start();

  /// Run [body] with this trace installed for everything it calls,
  /// including async work.
  Future<T> capture<T>(Future<T> Function() body) =>
      runZoned(body, zoneValues: {_zoneKey: this});

  /// The trace installed by [capture], if any.
  static PipelineTrace? get current => Zone.current[_zoneKey] as PipelineTrace?;

  /// Record an event on the current trace. Does nothing without one.
  static void record(String stage, Map<String, Object?> data) {
    final trace = current;
    if (trace == null) return;
    trace.events
        .add(PipelineTraceEvent(stage, trace._clock.elapsedMilliseconds, data));
  }

  List<Map<String, Object?>> toJson() => events.map((e) => e.toJson()).toList();
}
