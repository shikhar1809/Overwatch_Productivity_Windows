import 'package:flutter/widgets.dart';
import 'package:camera/camera.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final cameras = await availableCameras();
    final c = CameraController(cameras.first, ResolutionPreset.low);
    await c.initialize();
    
    // Test if startImageStream is available and runs
    c.startImageStream((CameraImage image) {
      File(r'C:\Users\royal\Desktop\Productive\debug_stream.txt').writeAsStringSync('Stream returned image bytes: ${image.planes.first.bytes.length}\n', mode: FileMode.append);
      c.stopImageStream();
      exit(0);
    });
    
    await Future.delayed(Duration(seconds: 5));
    File(r'C:\Users\royal\Desktop\Productive\debug_stream.txt').writeAsStringSync('Stream did not return image within 5 seconds.\n', mode: FileMode.append);
    exit(0);
  } catch(e) {
    File(r'C:\Users\royal\Desktop\Productive\debug_stream.txt').writeAsStringSync('Stream error: $e\n', mode: FileMode.append);
    exit(1);
  }
}
