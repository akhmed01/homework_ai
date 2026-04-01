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
  File? image;

  @override
  void initState() {
    super.initState();
    pickImage(widget.source);
  }

  // 📷 Pick → ✂️ Crop → 🔍 OCR (SAFE VERSION)
  Future pickImage(ImageSource source) async {
    try {
      // 🔐 Request permissions
      await Permission.camera.request();
      await Permission.photos.request();

      final pickedFile = await ImagePicker().pickImage(source: source);

      if (pickedFile == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final originalFile = File(pickedFile.path);

      // ✂️ Crop (safe)
      final croppedFile = await ImageService.cropImage(originalFile.path);

      // 👉 If crop fails → fallback to original image
      final finalFile = croppedFile ?? originalFile;

      setState(() {
        image = finalFile;
      });

      await processImage(finalFile);
    } catch (e) {
      debugPrint("❌ PICK IMAGE ERROR: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to process image")),
        );
        Navigator.pop(context);
      }
    }
  }

  // 🔍 OCR (SAFE VERSION)
  Future processImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final textRecognizer = TextRecognizer();

      final recognizedText = await textRecognizer.processImage(inputImage);

      textRecognizer.close();

      final extractedText = recognizedText.text;

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(text: extractedText),
        ),
      );
    } catch (e) {
      debugPrint("❌ OCR ERROR: $e");

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("OCR failed")));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scanning..."),
        backgroundColor: const Color(0xFF4F46E5),
      ),
      body: Center(
        child: image == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Processing image..."),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.file(image!),
                  const SizedBox(height: 16),
                  Text("Processing OCR..."),
                ],
              ),
      ),
    );
  }
}
