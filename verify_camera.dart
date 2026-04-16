import 'dart:io';
import 'package:opencv_dart/opencv_dart.dart' as cv;

void main() async {
  print('Testing webcam...');
  try {
    final cap = cv.VideoCapture.fromDevice(0);
    print('Camera open? ${cap.isOpened}');
    
    if (cap.isOpened) {
      final (grabbed, frame) = cap.read();
      print('Frame grabbed? $grabbed. Size: ${frame.width}x${frame.height}');
      frame.dispose();
    }
    
    cap.release();
    print('Camera released.');
  } catch(e) {
    print('Exception: $e');
  }
}
