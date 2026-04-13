import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import '../services/image_service.dart';
import 'result_screen.dart';

class CameraScreen extends StatefulWidget {
  final ImageSource source;

  const CameraScreen({super.key, required this.source});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  File? _image;
  String _status = 'Preparing…';

  @override
  void initState() {
    super.initState();
    _pickAndProcess(widget.source);
  }

  Future<void> _pickAndProcess(ImageSource source) async {
    try {
      await Permission.camera.request();
      await Permission.photos.request();

      _setStatus('Opening camera…');

      final pickedFile = await ImagePicker().pickImage(source: source);

      if (pickedFile == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final originalFile = File(pickedFile.path);
      _setStatus('Cropping image…');

      final croppedFile = await ImageService.cropImage(originalFile.path);
      final finalFile = croppedFile ?? originalFile;

      setState(() => _image = finalFile);

      _setStatus('Reading text…');
      await _runOCR(finalFile);
    } catch (e) {
      debugPrint('❌ PICK IMAGE ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to process image')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _setStatus(String msg) {
    if (mounted) setState(() => _status = msg);
  }

  Future<void> _runOCR(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final textRecognizer = TextRecognizer();
      final recognized = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(text: recognized.text)),
      );
    } catch (e) {
      debugPrint('❌ OCR ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read text from image')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Scanning…')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_image!, height: 280, fit: BoxFit.cover),
              ),
              const SizedBox(height: 24),
            ],
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(_status, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
