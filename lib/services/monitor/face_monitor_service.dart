import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:flutter_litert/flutter_litert.dart';

const _phoneClassId = 77;
const _altPhoneClassId = 67;
const _phoneConfidenceThreshold = 0.20;
const _phoneDetectionThreshold = 2;
const _normalCheckIntervalSeconds = 15;
const _urgentCheckIntervalSeconds = 5;
const _anyObjectThreshold = 0.50;

class FaceMonitorService {
  bool _initialized = false;
  bool _isRunning = false;
  bool _alarmPlaying = false;
  final List<bool> _recentDetections = [];
  bool _phoneWasDetected = false;

  String? _snapDir;
  String? _modelPath;
  Timer? _timer;
  Timer? _statusTimer;
  CameraController? _cameraController;
  Interpreter? _interpreter;
  bool _isBusy = false;
  bool _modelReady = false;
  int _consecutiveCameraErrors = 0;
  int _cameraRetryDelay = 0;
  bool _cameraReinitializing = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _soundPath;
  String? _dayId;
  void Function(String snapPath, String reason)? onPhoneDetected;

  bool get isRunning => _isRunning;
  bool get isAlarmPlaying => _alarmPlaying;
  bool get isInitialized => _initialized;
  bool get isModelReady => _modelReady;
  CameraController? get cameraController => _cameraController;

  final ValueNotifier<String> statusText = ValueNotifier<String>('Offline');
  final ValueNotifier<int> snapCount = ValueNotifier<int>(0);
  int _totalSnaps = 0;

  Future<bool> initialize({
    required String soundPath,
    String? dayId,
    void Function(String snapPath, String reason)? onPhoneDetectedCallback,
  }) async {
    if (_initialized) return true;
    _soundPath = soundPath;
    _dayId = dayId;
    onPhoneDetected = onPhoneDetectedCallback;

    try {
      _modelPath = r'C:\Users\royal\Documents\FocusOS\model\detect.tflite';
      _snapDir = r'C:\Users\royal\Documents\FocusOS\snapshots';

      await Directory(r'C:\Users\royal\Documents\FocusOS\model').create(recursive: true);
      await Directory(_snapDir!).create(recursive: true);

      statusText.value = 'Loading model...';
      await _loadInterpreter();

      if (!_modelReady) {
        debugPrint('Face monitor: TFLite model failed to load');
        statusText.value = 'Model error';
        return false;
      }

      _initialized = true;
      statusText.value = 'Ready - tap toggle to start';
      debugPrint('Face monitor initialized successfully');
      return true;
    } catch (e, stack) {
      debugPrint('Face monitor init error: $e');
      statusText.value = 'Init error: $e';
      return false;
    }
  }

  Future<void> _loadInterpreter() async {
    try {
      final modelFile = File(_modelPath!);
      final exists = await modelFile.exists();
      if (!exists) {
        debugPrint('Model file not found at $_modelPath');
        return;
      }
      
      _interpreter = await Interpreter.fromFile(modelFile);
      _modelReady = true;
      debugPrint('TFLite interpreter loaded successfully');
      
      final inputs = _interpreter!.getInputTensors();
      final outputs = _interpreter!.getOutputTensors();
      String tinfo = "INPUTS:\n";
      for (var t in inputs) tinfo += " - ${t.name}: ${t.shape} (type: ${t.type})\n";
      tinfo += "OUTPUTS:\n";
      for (var t in outputs) tinfo += " - ${t.name}: ${t.shape} (type: ${t.type})\n";
      debugPrint(tinfo);
    } catch (e, stack) {
      debugPrint('TFLite load error: $e');
      _modelReady = false;
    }
  }

  Future<void> start() async {
    if (!_initialized || _isRunning) return;

    debugPrint('Starting face monitor...');
    statusText.value = 'Initializing camera...';

    _isRunning = true;
    _recentDetections.clear();
    _phoneWasDetected = false;
    _consecutiveCameraErrors = 0;
    _cameraRetryDelay = 0;
    _cameraReinitializing = false;

    await _ensureCameraInitialized();

    _scheduleNextCheck(_normalCheckIntervalSeconds);

    _statusTimer = Timer.periodic(const Duration(seconds: 1), (_timer) {
      if (!_isRunning) {
        _timer.cancel();
        statusText.value = 'Face monitor offline';
        return;
      }
      
      if (_cameraReinitializing) {
        statusText.value = 'Camera reconnecting...';
      } else if (_isBusy) {
        statusText.value = 'Analyzing frame...';
      } else {
        final interval = _phoneWasDetected ? _urgentCheckIntervalSeconds : _normalCheckIntervalSeconds;
        final remaining = interval - (DateTime.now().second % interval);
        statusText.value = _phoneWasDetected 
            ? 'Phone detected! Checking in ${remaining}s...' 
            : 'Active - next check in ${remaining}s';
      }
    });

    debugPrint('Face monitor started successfully');
  }

  Future<void> _ensureCameraInitialized() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      return;
    }

    try {
      statusText.value = 'Finding camera...';
      final cameras = await availableCameras();
      
      if (cameras.isEmpty) {
        debugPrint('No cameras found');
        statusText.value = 'No camera found';
        return;
      }

      debugPrint('Found ${cameras.length} camera(s)');
      
      await _initializeCameraController(cameras.first);
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      statusText.value = 'Camera error: $e';
    }
  }

  Future<void> _initializeCameraController(CameraDescription camera) async {
    if (_cameraController != null) {
      try {
        await _cameraController!.dispose();
      } catch (_) {}
    }

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();
      _consecutiveCameraErrors = 0;
      _cameraRetryDelay = 0;
      debugPrint('Camera initialized successfully');
      statusText.value = 'Camera ready';
    } catch (e) {
      debugPrint('Camera initialize failed: $e');
      _cameraController = null;
      rethrow;
    }
  }

  void _scheduleNextCheck(int seconds) {
    _timer?.cancel();
    _timer = Timer(Duration(seconds: seconds), () {
      if (_isRunning) {
        _check().then((_) {
          final interval = _phoneWasDetected ? _urgentCheckIntervalSeconds : _normalCheckIntervalSeconds;
          _scheduleNextCheck(interval);
        });
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _statusTimer?.cancel();
    _statusTimer = null;
    _isRunning = false;
    _recentDetections.clear();
    _phoneWasDetected = false;
    _stopAlarm();
    _cleanup();
    statusText.value = 'Stopped';
    debugPrint('Face monitor stopped');
  }

  void _cleanup() {
    try { 
      _cameraController?.dispose(); 
    } catch (_) {}
    _cameraController = null;
  }

  Future<void> _check() async {
    if (!_isRunning || _isBusy) return;
    
    if (_cameraReinitializing) {
      debugPrint('Skipping check - camera reinitializing');
      return;
    }
    
    _isBusy = true;
    bool phoneDetected = false;
    String? lastSnapPath;

    try {
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        debugPrint('Camera not ready, attempting reinit...');
        await _handleCameraError();
        _isBusy = false;
        return;
      }

      statusText.value = 'Capturing frame...';
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      final xfile = await _cameraController!.takePicture();
      _consecutiveCameraErrors = 0;
      _cameraRetryDelay = 0;
      
      final bytes = await File(xfile.path).readAsBytes();

      try { File(xfile.path).deleteSync(); } catch (_) {}

      debugPrint('Captured frame (${bytes.length} bytes)');

      if (_modelReady && _interpreter != null) {
        statusText.value = 'Analyzing frame...';
        debugPrint('Running inference...');
        final result = await _runInference(bytes);
        phoneDetected = result;
        debugPrint('Inference complete. Phone detected: $phoneDetected');
        
        if (phoneDetected) {
          debugPrint('Phone detected!');
          _phoneWasDetected = true;
          
          final ts = DateTime.now().millisecondsSinceEpoch;
          final snapPath = p.join(_snapDir!, 'phone_$ts.jpg');
          await File(snapPath).writeAsBytes(bytes);
          lastSnapPath = snapPath;
          _totalSnaps++;
          snapCount.value = _totalSnaps;
          debugPrint('Saved phone snapshot: phone_$ts.jpg');
        } else {
          _phoneWasDetected = false;
          debugPrint('No significant objects detected');
        }
      }

    } catch (e) {
      debugPrint('Face check error: $e');
      await _handleCameraError();
    } finally {
      _isBusy = false;
    }

    _recentDetections.add(phoneDetected);
    if (_recentDetections.length > 3) {
      _recentDetections.removeAt(0);
    }
    
    final hits = _recentDetections.where((d) => d).length;

    if (phoneDetected) {
      debugPrint('Recent phone hits: $hits/3 (Threshold: $_phoneDetectionThreshold)');
    }

    if (hits >= _phoneDetectionThreshold && !_alarmPlaying) {
      statusText.value = 'PHONE DETECTED!';
      _startAlarm();
      
      if (onPhoneDetected != null && lastSnapPath != null) {
        onPhoneDetected!(lastSnapPath, 'Phone detected during focus session');
      }
    } else if (hits == 0) {
      if (_alarmPlaying) {
        _stopAlarm();
        statusText.value = 'Phone removed - alarm stopped';
      }
    }
  }

  Future<void> _handleCameraError() async {
    if (_cameraReinitializing) return;

    _consecutiveCameraErrors++;
    debugPrint('Camera error count: $_consecutiveCameraErrors');

    if (_consecutiveCameraErrors >= 2) {
      _cameraReinitializing = true;
      statusText.value = 'Camera error - reconnecting...';
      
      await Future.delayed(Duration(seconds: _cameraRetryDelay + 2));
      _cameraRetryDelay = (_cameraRetryDelay + 2).clamp(0, 10);
      
      try {
        await _ensureCameraInitialized();
        debugPrint('Camera reinitialized successfully');
      } catch (e) {
        debugPrint('Camera reinit failed: $e');
        statusText.value = 'Camera error - will retry';
      } finally {
        _cameraReinitializing = false;
      }
    }
  }

  Future<bool> _runInference(Uint8List jpegBytes) async {
    try {
      final image = img.decodeImage(jpegBytes);
      if (image == null) {
        debugPrint('Failed to decode image');
        return false;
      }
      
      final resized = img.copyResize(image, width: 300, height: 300);

      final inputTensor = List.generate(
        300,
        (y) => List.generate(300, (x) {
          final pixel = resized.getPixel(x, y);
          return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
        }),
      );
      final input = [inputTensor];

      final outputBoxes = List.generate(1, (_) => List.generate(10, (_) => List.filled(4, 0.0)));
      final outputClasses = List.generate(1, (_) => List.filled(10, 0.0));
      final outputScores = List.generate(1, (_) => List.filled(10, 0.0));
      final outputCount = List.filled(1, 0.0);

      final outputs = {
        0: outputBoxes,
        1: outputClasses,
        2: outputScores,
        3: outputCount,
      };

      _interpreter!.runForMultipleInputs([input], outputs);

      final count = outputCount[0].toInt().clamp(0, 10);
      
      String allDetections = 'Detections: ';
      double maxNonPersonScore = 0;
      
      for (int i = 0; i < count; i++) {
        final classId = outputClasses[0][i].toInt();
        final score = outputScores[0][i];
        
        allDetections += '[class=$classId score=${score.toStringAsFixed(2)}] ';
        
        if (classId != 0 && score > maxNonPersonScore) {
          maxNonPersonScore = score;
        }
        
        if ((classId == _phoneClassId || classId == _altPhoneClassId) && score >= _phoneConfidenceThreshold) {
          debugPrint('PHONE DETECTED! class=$classId score=${score.toStringAsFixed(2)}');
          return true;
        }
      }
      
      debugPrint(allDetections.trim());
      
      if (maxNonPersonScore > _anyObjectThreshold) {
        debugPrint('Non-person object detected (score: $maxNonPersonScore) - treating as phone');
        return true;
      }
      
      debugPrint('No significant objects detected');
      return false;
    } catch (e, stack) {
      debugPrint('Inference error: $e');
      return false;
    }
  }

  void _startAlarm() {
    if (_soundPath == null || _alarmPlaying) return;
    
    try {
      _alarmPlaying = true;
      _audioPlayer.setReleaseMode(ReleaseMode.loop);
      _audioPlayer.play(DeviceFileSource(_soundPath!));
      debugPrint('ALARM STARTED - phone detected');
    } catch (e) {
      debugPrint('Alarm playback error: $e');
      _alarmPlaying = false;
    }
  }

  void _stopAlarm() {
    if (!_alarmPlaying) return;
    
    try {
      _alarmPlaying = false;
      _audioPlayer.stop();
      debugPrint('Alarm stopped');
    } catch (e) {
      debugPrint('Alarm stop error: $e');
    }
  }

  Future<void> dispose() async {
    stop();
    _interpreter?.close();
    await _audioPlayer.dispose();
    _initialized = false;
  }
}
