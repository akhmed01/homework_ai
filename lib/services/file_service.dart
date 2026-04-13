// NOTE: FileService is currently unused — CameraScreen handles image picking
// directly via ImagePicker. Either wire this in as an alternative entry
// point (e.g., for PDF support later) or remove it.
//
// Kept here as a placeholder for future PDF/document upload feature.

import 'package:file_picker/file_picker.dart';

class FileService {
  /// Pick an image file from the device file system.
  static Future<String?> pickImageFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);

    return result?.files.single.path;
  }

  /// Pick a PDF file (for future homework PDF upload feature).
  static Future<String?> pickPdfFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    return result?.files.single.path;
  }
}
