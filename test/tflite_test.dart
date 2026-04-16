import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_litert/flutter_litert.dart';

void main() {
  test('Inspect TFLite Tensors', () async {
    final modelFile = File(r'C:\Users\royal\Documents\FocusOS\model\detect.tflite');
    if (!modelFile.existsSync()) {
      print('Model file not found!');
      return;
    }
    
    final interpreter = await Interpreter.fromFile(modelFile);
    print('Interpreter loaded successfully.');

    final inputs = interpreter.getInputTensors();
    final outputs = interpreter.getOutputTensors();

    print('\nINPUTS:');
    for (var t in inputs) {
      print(' - ${t.name}: shape=${t.shape}, type=${t.type}');
    }

    print('\nOUTPUTS:');
    for (var i = 0; i < outputs.length; i++) {
        var t = outputs[i];
      print(' - Index $i: ${t.name}, shape=${t.shape}, type=${t.type}');
    }
  });
}
