import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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

  // 📷 Pick → ✂️ Crop → 🔍 OCR
  Future pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);

    if (pickedFile == null) {
      Navigator.pop(context);
      return;
    }

    // 👉 ORIGINAL IMAGE
    final originalFile = File(pickedFile.path);

    // ✂️ CROP IMAGE (NEW)
    final croppedFile = await ImageService.cropImage(originalFile.path);

    if (croppedFile == null) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      image = croppedFile;
    });

    processImage(croppedFile);
  }

  // 🔍 OCR
  Future processImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);

    final textRecognizer = TextRecognizer();

    final RecognizedText recognizedText = await textRecognizer.processImage(
      inputImage,
    );

    textRecognizer.close();

    String extractedText = recognizedText.text;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(text: extractedText),
      ),
    );
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
                  const Text("Processing OCR..."),
                ],
              ),
      ),
    );
  }
}
