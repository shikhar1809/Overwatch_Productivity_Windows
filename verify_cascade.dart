import 'package:flutter/widgets.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('Testing Cascade with empty and load...');

  try {
    final cascade = cv.CascadeClassifier.empty();
    print('Cascade created empty');
    
    final Path = r'C:\Users\royal\Documents\FocusOS\models\haarcascade_frontalface_default.xml';
    final success = cascade.load(Path);
    print('Cascade loaded? $success');
    
    File(r'C:\Users\royal\Desktop\Productive\debug.txt').writeAsStringSync('Cascade loaded: $success\n', mode: FileMode.append);
    exit(0);
  } catch(e) {
    print('Exception: $e');
    File(r'C:\Users\royal\Desktop\Productive\debug.txt').writeAsStringSync('Cascade Error: $e\n', mode: FileMode.append);
    exit(1);
  }
}
