import 'package:file_picker/file_picker.dart';

class FileService {
  static Future<String?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image, // only images for now
    );

    if (result != null && result.files.single.path != null) {
      return result.files.single.path!;
    }

    return null;
  }
}
