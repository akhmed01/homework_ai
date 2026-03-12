import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';

import 'result_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  File? image;

  // Opens camera and captures image
  Future pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
    );

    if (pickedFile == null) return;

    final imageFile = File(pickedFile.path);

    setState(() {
      image = imageFile;
    });

    // Process OCR
    processImage(imageFile);
  }

  // OCR text recognition
  Future processImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);

    final textRecognizer = TextRecognizer();

    final RecognizedText recognizedText = await textRecognizer.processImage(
      inputImage,
    );

    textRecognizer.close();

    String extractedText = recognizedText.text;

    // Navigate to result screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(text: extractedText),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    // Automatically open camera
    pickImage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Homework"),
        backgroundColor: const Color(0xFF4F46E5),
      ),
      body: Center(
        child: image == null
            ? const Text("Opening camera...")
            : Image.file(image!),
      ),
    );
  }
}
