import 'dart:io';
import 'package:path/path.dart' as path;

void main() async {
  final projectPath = '.';
  final libDir = Directory(path.join(projectPath, 'lib'));
  
  final filesChanged = <String>[];
  
  // Get all .dart files recursively
  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      try {
        final content = await entity.readAsString();
        
        // Check for non-breaking space (U+00A0)
        if (content.contains('\u00A0')) {
          // Replace with regular space
          final newContent = content.replaceAll('\u00A0', ' ');
          await entity.writeAsString(newContent);
          filesChanged.add(entity.path);
          print('Fixed: ${entity.path}');
        }
      } catch (e) {
        print('Error processing ${entity.path}: $e');
      }
    }
  }
  
  if (filesChanged.isEmpty) {
    print('No files needed fixing.');
  } else {
    print('\n✓ ${filesChanged.length} file(s) fixed:');
    for (final file in filesChanged) {
      print('  $file');
    }
  }
}
