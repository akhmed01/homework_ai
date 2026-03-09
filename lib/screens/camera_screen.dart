import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  File? image;
  String extractedText = "";

  Future pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
    );

    if (pickedFile == null) return;

    final imageFile = File(pickedFile.path);

    setState(() {
      image = imageFile;
    });

    processImage(imageFile);
  }

  Future processImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);

    final textRecognizer = TextRecognizer();

    final RecognizedText recognizedText = await textRecognizer.processImage(
      inputImage,
    );

    setState(() {
      extractedText = recognizedText.text;
    });

    textRecognizer.close();
  }

  @override
  void initState() {
    super.initState();
    pickImage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Homework"),
        backgroundColor: const Color(0xFF4F46E5),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (image != null) Image.file(image!),

            const SizedBox(height: 20),

            const Text(
              "Detected Text:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),

            const SizedBox(height: 10),

            Text(extractedText),
          ],
        ),
      ),
    );
  }
}
