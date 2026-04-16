import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/logo.png');
  final bytes = file.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) return;
  
  // Create a new image with alpha channel
  final result = img.Image(width: image.width, height: image.height, numChannels: 4);

  // Background removal: finding pixels that are nearly white
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      if (p.r > 240 && p.g > 240 && p.b > 240) {
        result.setPixelRgba(x, y, p.r, p.g, p.b, 0); // Transparent
      } else {
        result.setPixelRgba(x, y, p.r, p.g, p.b, p.a); // Keep original
      }
    }
  }

  File('assets/logo_transparent.png').writeAsBytesSync(img.encodePng(result));
}
