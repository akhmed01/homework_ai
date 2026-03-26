import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

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

    // 📷 OR 🖼 based on button pressed
    pickImage(widget.source);
  }

  // Pick image from camera or gallery
  Future pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);

    if (pickedFile == null) {
      Navigator.pop(context); // go back if cancelled
      return;
    }

    final imageFile = File(pickedFile.path);

    setState(() {
      image = imageFile;
    });

    processImage(imageFile);
  }

  // OCR processing
  Future processImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);

    final textRecognizer = TextRecognizer();

    final RecognizedText recognizedText = await textRecognizer.processImage(
      inputImage,
    );

    textRecognizer.close();

    String extractedText = recognizedText.text;

    // Navigate to result screen
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
            : Image.file(image!),
      ),
    );
  }
}
