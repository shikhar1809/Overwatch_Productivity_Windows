import 'dart:io';

void main() {
  var dir = Directory('c:/Users/royal/Desktop/Productive/focus_os/lib/features');
  var files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (var file in files) {
    var content = file.readAsStringSync();
    var newContent = content
        .replaceAll('Colors.white70', 'Colors.black87')
        .replaceAll('Colors.white60', 'Colors.black54')
        .replaceAll('Colors.white54', 'Colors.black54')
        .replaceAll('Colors.white38', 'Colors.black38')
        .replaceAll('Colors.white24', 'Colors.black26')
        .replaceAll('Colors.white', 'Colors.black');
    
    if (content != newContent) {
      file.writeAsStringSync(newContent);
      print('Updated \${file.path}');
    }
  }
}
