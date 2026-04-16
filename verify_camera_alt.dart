import 'dart:io';
import 'package:opencv_dart/opencv_dart.dart' as cv;

void main() async {
  print('Testing webcam alt...');
  try {
    final cap = cv.VideoCapture.empty();
    print('Empty cap created');
    final opened = cap.openIndex(0);
    print('Camera 0 open? $opened');
    
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
