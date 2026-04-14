import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/image_service.dart';
import 'result_screen.dart';

class CameraScreen extends StatefulWidget {
  final ImageSource source;

  const CameraScreen({super.key, required this.source});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin {
  File? _preview;
  String _status = 'Preparing…';
  List<String> _steps = [];

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    try {
      await Permission.camera.request();
      await Permission.photos.request();

      _setStatus('Opening camera…');

      final picked = await ImagePicker().pickImage(source: widget.source);
      if (picked == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      _setStatus('Crop & framing…');

      // ✨ New pipeline — crop UI + auto-enhance
      final result = await ImageService.cropAndEnhance(picked.path);

      if (result == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      setState(() {
        _preview = result.file;
        _steps = result.appliedSteps;
      });

      _setStatus('Reading text with OCR…');
      await _runOCR(result.file);
    } catch (e) {
      debugPrint('❌ Camera screen error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        Navigator.pop(context);
      }
    }
  }

  void _setStatus(String msg) {
    if (mounted) setState(() => _status = msg);
  }

  Future<void> _runOCR(File file) async {
    try {
      final inputImage = InputImage.fromFile(file);
      final recognizer = TextRecognizer();
      final result = await recognizer.processImage(inputImage);
      await recognizer.close();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) => ResultScreen(text: result.text),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } catch (e) {
      debugPrint('❌ OCR error: $e');
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Scanning', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _preview != null
                    ? _EnhancedPreview(file: _preview!, steps: _steps)
                    : const _ScannerPlaceholder(),
              ),
            ),
            _StatusBar(status: _status, pulseController: _pulseController),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EnhancedPreview extends StatelessWidget {
  final File file;
  final List<String> steps;
  const _EnhancedPreview({required this.file, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.35),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(
                color: const Color(0xFF00E5FF).withOpacity(0.6),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(file, fit: BoxFit.contain),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (steps.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: steps.map((s) => _StepChip(label: s)).toList(),
          ),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  final String label;
  const _StepChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5).withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.5)),
      ),
      child: Text(
        '✓ $label',
        style: const TextStyle(
          color: Color(0xFF00E5FF),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ScannerPlaceholder extends StatelessWidget {
  const _ScannerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00E5FF).withOpacity(0.3),
          width: 2,
        ),
        color: Colors.white.withOpacity(0.04),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.document_scanner_outlined,
              size: 64,
              color: Color(0xFF00E5FF),
            ),
            SizedBox(height: 16),
            Text('Waiting for image…', style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final String status;
  final AnimationController pulseController;
  const _StatusBar({required this.status, required this.pulseController});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: pulseController,
              builder: (_, __) => Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(
                    const Color(0xFF4F46E5),
                    const Color(0xFF00E5FF),
                    pulseController.value,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFF00E5FF,
                      ).withOpacity(0.6 * pulseController.value),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                status,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
