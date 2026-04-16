import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

void main() async {
  final url = 'https://storage.googleapis.com/download.tensorflow.org/models/tflite_11_05_08/coco_ssd_mobilenet_v1_1.0_quant_2018_06_29.zip';
  final response = await http.get(Uri.parse(url));
  final archive = ZipDecoder().decodeBytes(response.bodyBytes);
  
  for (final file in archive) {
    if (file.name.endsWith('.txt')) {
      final content = String.fromCharCodes(file.content as List<int>);
      File(r'C:\Users\royal\Desktop\Productive\labels.txt').writeAsStringSync(content);
      print('Extracted ${file.name}');
    }
  }
}
