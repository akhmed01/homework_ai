import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/image_service.dart';
import 'result_screen.dart';

enum _CaptureStage { openingSource, cropping, review, preparingOcr, readingOcr }

class CameraScreen extends StatefulWidget {
  final ImageSource source;

  const CameraScreen({super.key, required this.source});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin {
  File? _sourceImage;
  File? _croppedImage;
  File? _preview;
  String _status = 'Preparing...';
  List<String> _steps = [];
  _CaptureStage _stage = _CaptureStage.openingSource;

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _startCapture();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startCapture() async {
    try {
      if (widget.source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Camera permission is required to scan homework'),
              ),
            );
            Navigator.pop(context);
          }
          return;
        }
      }

      _updateStage(
        _CaptureStage.openingSource,
        widget.source == ImageSource.camera
            ? 'Opening camera...'
            : 'Opening gallery...',
      );

      final picked = await ImagePicker().pickImage(
        source: widget.source,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.rear,
        requestFullMetadata: true,
      );

      if (!mounted) {
        return;
      }

      if (picked == null) {
        Navigator.pop(context);
        return;
      }

      _sourceImage = File(picked.path);
      await _cropCapturedImage();
    } catch (e) {
      _handleFatalError('Could not open image source: $e');
    }
  }

  Future<void> _cropCapturedImage({bool exitOnCancel = true}) async {
    final sourceImage = _sourceImage;
    if (sourceImage == null) {
      return;
    }

    _updateStage(_CaptureStage.cropping, 'Adjust crop and framing...');

    final cropped = await ImageService.cropForHomework(sourceImage.path);

    if (!mounted) {
      return;
    }

    if (cropped == null) {
      if (exitOnCancel) {
        Navigator.pop(context);
      } else {
        _updateStage(
          _CaptureStage.review,
          'Kept current crop. Choose how to continue.',
        );
      }
      return;
    }

    setState(() {
      _croppedImage = cropped;
      _preview = cropped;
      _steps = const ['Cropped'];
      _stage = _CaptureStage.review;
      _status = 'Choose how to continue';
    });
  }

  Future<void> _solveFromImage() async {
    final cropped = _croppedImage;
    if (cropped == null || !mounted) {
      return;
    }

    await Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => ResultScreen(text: '', sourceImage: cropped),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  Future<void> _runOcr() async {
    final cropped = _croppedImage;
    if (cropped == null) {
      return;
    }

    _updateStage(_CaptureStage.preparingOcr, 'Enhancing image for OCR...');

    final processed = await ImageService.enhanceForOcr(cropped);

    if (!mounted) {
      return;
    }

    setState(() {
      _preview = processed.file;
      _steps = ['Cropped', ...processed.appliedSteps];
    });

    _updateStage(_CaptureStage.readingOcr, 'Comparing OCR results...');

    try {
      final ocrResult = await _extractBestText(
        original: cropped,
        enhanced: processed.file,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _steps = [
          'Cropped',
          ...processed.appliedSteps,
          ocrResult.usedEnhancedImage
              ? 'Best OCR: enhanced image'
              : 'Best OCR: original crop',
        ];
        _status = ocrResult.usedEnhancedImage
            ? 'Using enhanced OCR result...'
            : 'Using original OCR result...';
      });

      if (ocrResult.text.trim().isEmpty) {
        setState(() {
          _preview = cropped;
          _steps = const ['Cropped'];
          _stage = _CaptureStage.review;
          _status = 'No text found. Try a tighter crop or image mode.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No readable text found. Try adjusting the crop.'),
          ),
        );
        return;
      }

      await Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) =>
              ResultScreen(text: ocrResult.text, sourceImage: cropped),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _preview = cropped;
        _steps = const ['Cropped'];
        _stage = _CaptureStage.review;
        _status = 'OCR failed. You can retry or solve from image.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read text from image: $e')),
      );
    }
  }

  Future<_OcrChoice> _extractBestText({
    required File original,
    required File enhanced,
  }) async {
    final recognizer = TextRecognizer();

    try {
      final originalText = (await recognizer.processImage(
        InputImage.fromFile(original),
      )).text.trim();
      final enhancedText = (await recognizer.processImage(
        InputImage.fromFile(enhanced),
      )).text.trim();

      final originalScore = _scoreText(originalText);
      final enhancedScore = _scoreText(enhancedText);

      if (enhancedScore > originalScore) {
        return _OcrChoice(text: enhancedText, usedEnhancedImage: true);
      }

      return _OcrChoice(text: originalText, usedEnhancedImage: false);
    } finally {
      await recognizer.close();
    }
  }

  double _scoreText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 0;
    }

    final letters = RegExp(r'[A-Za-z]').allMatches(trimmed).length;
    final digits = RegExp(r'[0-9]').allMatches(trimmed).length;
    final mathSymbols = RegExp(
      r'[=+\-*/^()%[\]{}<>]',
    ).allMatches(trimmed).length;
    final lines = trimmed
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .length;
    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .length;
    final junk = RegExp(
      r'''[^A-Za-z0-9\s=+\-*/^()%[\]{}<>.,:;!?"'#&]''',
    ).allMatches(trimmed).length;

    return letters +
        (digits * 1.2) +
        (mathSymbols * 1.1) +
        (lines * 2) +
        (words * 0.5) -
        (junk * 0.2);
  }

  void _updateStage(_CaptureStage stage, String status) {
    if (!mounted) {
      return;
    }
    setState(() {
      _stage = stage;
      _status = status;
    });
  }

  void _handleFatalError(String message) {
    debugPrint(message);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceFirst('Exception: ', ''))),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = _stage == _CaptureStage.review
        ? 'Review Capture'
        : 'Scanning';
    final retakeLabel = widget.source == ImageSource.camera
        ? 'Retake'
        : 'Choose another';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        elevation: 0,
        actions: [
          if (_stage == _CaptureStage.review)
            IconButton(
              tooltip: retakeLabel,
              icon: Icon(
                widget.source == ImageSource.camera
                    ? Icons.photo_camera_back_outlined
                    : Icons.photo_library_outlined,
              ),
              onPressed: _startCapture,
            ),
        ],
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
            if (_stage == _CaptureStage.review)
              _ReviewActions(
                onSolveFromImage: _solveFromImage,
                onRunOcr: _runOcr,
                onAdjustCrop: () => _cropCapturedImage(exitOnCancel: false),
              ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class _OcrChoice {
  final String text;
  final bool usedEnhancedImage;

  const _OcrChoice({required this.text, required this.usedEnhancedImage});
}

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
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
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
            children: steps.map((step) => _StepChip(label: step)).toList(),
          ),
      ],
    );
  }
}

class _ReviewActions extends StatelessWidget {
  final VoidCallback onSolveFromImage;
  final VoidCallback onRunOcr;
  final VoidCallback onAdjustCrop;

  const _ReviewActions({
    required this.onSolveFromImage,
    required this.onRunOcr,
    required this.onAdjustCrop,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSolveFromImage,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Solve From Image'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRunOcr,
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Run OCR First'),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onAdjustCrop,
            icon: const Icon(Icons.crop_outlined),
            label: const Text('Adjust Crop'),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Image mode is best for diagrams or mixed content. OCR is best for clean text and equations.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 12.5),
            ),
          ),
        ],
      ),
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
        color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4F46E5).withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        label,
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
          color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
          width: 2,
        ),
        color: Colors.white.withValues(alpha: 0.04),
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
            Text(
              'Waiting for image...',
              style: TextStyle(color: Colors.white54),
            ),
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
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: pulseController,
              builder: (_, _) => Container(
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
                      ).withValues(alpha: 0.6 * pulseController.value),
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
