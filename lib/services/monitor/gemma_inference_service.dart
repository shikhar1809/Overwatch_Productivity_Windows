// GemmaInferenceService — stubbed out.
// The llama_cpp_dart package is not installed; this file is kept for
// future re-integration but is not used by the app.

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'prompt_builder.dart';

class GemmaInferenceService {
  bool _initialized = false;
  bool _modelLoaded = false;
  String? _modelPath;
  String? _libraryPath;

  bool get isInitialized => _initialized;
  bool get isModelLoaded => _modelLoaded;
  String? get modelPath => _modelPath;
  String? get libraryPath => _libraryPath;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  Future<String> getModelDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, 'FocusOS', 'models');
  }

  Future<String> getLibraryDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, 'FocusOS', 'libs');
  }

  Future<void> loadModel({
    String modelName = 'model.gguf',
    String libraryName = 'llama.dll',
    void Function(double progress)? onProgress,
  }) async {
    // llama_cpp_dart not installed — model cannot be loaded
    debugPrint('GemmaInferenceService: llama_cpp_dart not available. Stubbed.');
    _modelLoaded = false;
    onProgress?.call(0.0);
  }

  Future<InferenceResult> infer({
    required String taskName,
    String? taskType,
    Uint8List? screenshotBytes,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return _simulateInference(taskName, taskType);
  }

  InferenceResult _simulateInference(String taskName, String? taskType) {
    final random = Random();
    final scenarios = [
      (true,  'Screen content appears relevant to the task.'),
      (true,  'User is working on the expected task.'),
      (true,  'Activity matches the committed work.'),
      (false, 'Music player detected — not relevant to task.'),
      (false, 'Social media content visible — violation.'),
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
