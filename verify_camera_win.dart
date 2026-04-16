import 'package:camera_windows/camera_windows.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/widgets.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('Testing alternative camera_windows...');

  try {
    final cameras = await CameraPlatform.instance.availableCameras();
    print('Found cameras: ${cameras.length}');

    if (cameras.isNotEmpty) {
      final cameraId = await CameraPlatform.instance.createCameraWithSettings(
        cameras.first,
        MediaSettings(
          resolutionPreset: ResolutionPreset.low,
          enableAudio: false,
        ),
      );
      print('Camera created: $cameraId');

      await CameraPlatform.instance.initializeCamera(cameraId);
      print('Camera fully initialized');

      final xfile = await CameraPlatform.instance.takePicture(cameraId);
      print('Picture taken: ${xfile.path}');
      
      File(r'C:\Users\royal\Desktop\Productive\debug.txt').writeAsStringSync('Picture OK\n', mode: FileMode.append);
      exit(0);
    }
  } catch(e) {
    print('Exception: $e');
    File(r'C:\Users\royal\Desktop\Productive\debug.txt').writeAsStringSync('Pic Error: $e\n', mode: FileMode.append);
    exit(1);
  }
}
