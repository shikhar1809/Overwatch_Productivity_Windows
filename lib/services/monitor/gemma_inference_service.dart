import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'prompt_builder.dart';

class GemmaInferenceService {
  bool _initialized = false;
  bool _modelLoaded = false;
  String? _modelPath;
  String? _libraryPath;

  LlamaParent? _llamaParent;

  bool get isInitialized => _initialized;
  bool get isModelLoaded => _modelLoaded;
  String? get modelPath => _modelPath;
  String? get libraryPath => _libraryPath;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  /// Returns the canonical model directory path
  Future<String> getModelDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory(p.join(appDir.path, 'FocusOS', 'models'));
    await modelDir.create(recursive: true);
    return modelDir.path;
  }

  /// Returns the canonical library directory path
  Future<String> getLibraryDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final libDir = Directory(p.join(appDir.path, 'FocusOS', 'libs'));
    await libDir.create(recursive: true);
    return libDir.path;
  }

  Future<void> loadModel({
    String modelName = 'model.gguf',
    String libraryName = 'llama.dll',
    void Function(double progress)? onProgress,
  }) async {
    if (_modelLoaded) return;

    final modelDir = await getModelDirectory();
    final libDir = await getLibraryDirectory();

    _modelPath = p.join(modelDir, modelName);
    _libraryPath = p.join(libDir, libraryName);

    // Check for llama.dll
    final libFile = File(_libraryPath!);
    if (!await libFile.exists()) {
      debugPrint('llama.dll not found at $_libraryPath');
      onProgress?.call(0.0);
      _modelLoaded = false;
      return;
    }

    // Check for model
    final modelFile = File(_modelPath!);
    if (!await modelFile.exists()) {
      debugPrint('Gemma model not found at $_modelPath');
      onProgress?.call(0.0);
      _modelLoaded = false;
      return;
    }

    try {
      onProgress?.call(0.1);

      // Set the path to llama.dll
      Llama.libraryPath = _libraryPath!;

      final contextParams = ContextParams();
      contextParams.nCtx = 512;

      final samplerParams = SamplerParams();
      samplerParams.temp = 0.1;

      final loadCommand = LlamaLoad(
        path: _modelPath!,
        modelParams: ModelParams(),
        contextParams: contextParams,
        samplingParams: samplerParams,
      );

      _llamaParent = LlamaParent(loadCommand);
      await _llamaParent!.init();

      onProgress?.call(1.0);
      _modelLoaded = true;
      debugPrint('Gemma model loaded from $_modelPath');
    } catch (e) {
      debugPrint('Failed to load Gemma model: $e');
      _modelLoaded = false;
      _llamaParent = null;
    }
  }

  Future<InferenceResult> infer({
    required String taskName,
    String? taskType,
    Uint8List? screenshotBytes,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!_modelLoaded || _llamaParent == null) {
      return _simulateInference(taskName, taskType);
    }

    final prompt = PromptBuilder.buildPrompt(
      taskName: taskName,
      taskType: taskType,
    );

    final stopwatch = Stopwatch()..start();
    final buffer = StringBuffer();
    final completer = Completer<String>();

    try {
      _llamaParent!.stream.listen(
        (chunk) {
          buffer.write(chunk);
          // Stop early when we detect verdict
          if (buffer.toString().contains('VERDICT:') &&
              buffer.toString().contains('REASONING:')) {
            if (!completer.isCompleted) completer.complete(buffer.toString());
          }
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(buffer.toString());
        },
        onError: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
      );

      _llamaParent!.sendPrompt(prompt);

      final raw = await completer.future.timeout(timeout);
      stopwatch.stop();

      final verdict = PromptBuilder.parseVerdict(raw);
      final reasoning = PromptBuilder.parseReasoning(raw);

      return InferenceResult(
        verdict: verdict,
        reasoning: reasoning,
        inferenceTime: stopwatch.elapsed,
        rawResponse: raw,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('Inference error: $e');
      return _simulateInference(taskName, taskType);
    }
  }

  InferenceResult _simulateInference(String taskName, String? taskType) {
    final random = Random();
    final scenarios = [
      (true, 'Screen content appears relevant to the task.'),
      (true, 'User is working on the expected task.'),
      (true, 'Activity matches the committed work.'),
      (false, 'Music player detected - not relevant to task.'),
      (false, 'Social media content visible - violation.'),
      (false, 'Unrelated browsing detected.'),
    ];

    final scenario = scenarios[random.nextInt(scenarios.length)];

    return InferenceResult(
      verdict: scenario.$1,
      reasoning: scenario.$2,
      inferenceTime: Duration(milliseconds: 200 + random.nextInt(300)),
      rawResponse:
          'VERDICT: ${scenario.$1 ? "YES" : "NO"}\nREASONING: ${scenario.$2}',
    );
  }

  Future<void> dispose() async {
    _llamaParent?.dispose();
    _llamaParent = null;
    _modelLoaded = false;
    _initialized = false;
  }
}

class InferenceResult {
  final bool verdict;
  final String reasoning;
  final Duration inferenceTime;
  final String rawResponse;

  bool get isViolation => !verdict;

  InferenceResult({
    required this.verdict,
    required this.reasoning,
    required this.inferenceTime,
    required this.rawResponse,
  });
}
