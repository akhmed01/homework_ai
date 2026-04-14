import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

/// Result returned after the full processing pipeline completes.
class ProcessedImage {
  final File file;

  /// Human-readable list of enhancements that were applied.
  final List<String> appliedSteps;

  ProcessedImage({required this.file, required this.appliedSteps});
}

class ImageService {
  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────────────────────

  /// Full pipeline:
  ///   1. Show interactive crop UI
  ///   2. Auto-enhance for OCR (contrast, sharpen, denoise, binarize)
  ///   3. Return [ProcessedImage] with the final file + applied steps log.
  ///
  /// Returns `null` if the user cancelled crop.
  static Future<ProcessedImage?> cropAndEnhance(String sourcePath) async {
    // ── Step 1 · Interactive crop ─────────────────────────────────────────
    final cropped = await _showCropUI(sourcePath);
    if (cropped == null) return null;

    // ── Step 2 · AI-style enhancement pipeline ───────────────────────────
    return _enhance(cropped);
  }

  /// Lightweight version — just the enhancement pipeline, no crop UI.
  static Future<ProcessedImage> enhanceOnly(File source) async {
    return _enhance(source);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CROP UI
  // ─────────────────────────────────────────────────────────────────────────

  static Future<File?> _showCropUI(String path) async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: path,
        compressQuality: 100, // keep full quality — we compress later ourselves
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '✂️ Crop Homework',
            toolbarColor: const Color(0xFF0D0D0D),
            toolbarWidgetColor: const Color(0xFF00E5FF),
            activeControlsWidgetColor: const Color(0xFF4F46E5),
            backgroundColor: const Color(0xFF0D0D0D),
            statusBarColor: const Color(0xFF0D0D0D),
            cropFrameColor: const Color(0xFF00E5FF),
            cropGridColor: const Color(0xFF4F46E5),
            cropFrameStrokeWidth: 3,
            cropGridRowCount: 3,
            cropGridColumnCount: 3,
            cropGridStrokeWidth: 1,
            showCropGrid: true,
            lockAspectRatio: false,
            hideBottomControls: false,
            dimmedLayerColor: Colors.black87,
            initAspectRatio: CropAspectRatioPreset.original,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Homework',
            doneButtonTitle: 'Enhance ✨',
            cancelButtonTitle: 'Cancel',
            resetButtonHidden: false,
            rotateButtonsHidden: false,
            aspectRatioPickerButtonHidden: false,
            resetAspectRatioEnabled: true,
            aspectRatioLockEnabled: false,
            hidesNavigationBar: false,
          ),
          WebUiSettings(
            context: _navigatorContext!,
            presentStyle: WebPresentStyle.dialog,
            size: const CropperSize(width: 520, height: 520),
          ),
        ],
      );

      if (cropped == null) return null;
      return File(cropped.path);
    } catch (e) {
      debugPrint('❌ Crop UI error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ENHANCEMENT PIPELINE
  // ─────────────────────────────────────────────────────────────────────────

  static Future<ProcessedImage> _enhance(File source) async {
    final appliedSteps = <String>[];

    try {
      final bytes = await source.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        debugPrint('⚠️  Could not decode image — returning original');
        return ProcessedImage(
          file: source,
          appliedSteps: ['Original (decode failed)'],
        );
      }

      // ── 1 · Straighten / auto-rotate based on EXIF ───────────────────
      image = img.bakeOrientation(image);
      appliedSteps.add('Auto-rotated (EXIF)');

      // ── 2 · Resize to processing target (max 2000px wide) ────────────
      if (image.width > 2000) {
        final scale = 2000 / image.width;
        image = img.copyResize(
          image,
          width: 2000,
          height: (image.height * scale).round(),
          interpolation: img.Interpolation.cubic,
        );
        appliedSteps.add('Resized for processing');
      }

      // ── 3 · Grayscale ────────────────────────────────────────────────
      image = img.grayscale(image);
      appliedSteps.add('Grayscale');

      // ── 4 · Auto-levels (stretch histogram to full range) ────────────
      image = _autoLevels(image);
      appliedSteps.add('Auto-levels');

      // ── 5 · Contrast enhancement ─────────────────────────────────────
      image = img.adjustColor(image, contrast: 1.3);
      appliedSteps.add('Contrast +30%');

      // ── 6 · Unsharp mask (sharpen edges for OCR) ─────────────────────
      image = _unsharpMask(image, sigma: 1.5, strength: 0.6);
      appliedSteps.add('Unsharp mask (sharpen)');

      // ── 7 · Adaptive binarization (Sauvola-inspired) ─────────────────
      image = _adaptiveBinarize(image, windowSize: 51, k: 0.15);
      appliedSteps.add('Adaptive binarization');

      // ── 8 · Noise removal (median-like via slight blur + re-threshold) ─
      image = img.gaussianBlur(image, radius: 1);
      image = _threshold(image, 128);
      appliedSteps.add('Noise removal');

      // ── 9 · Compress & save to temp ──────────────────────────────────
      final outFile = await _saveTmp(image, 'enhanced');
      appliedSteps.add('Saved as PNG');

      debugPrint('✅ Enhancement pipeline: ${appliedSteps.join(' → ')}');
      return ProcessedImage(file: outFile, appliedSteps: appliedSteps);
    } catch (e, st) {
      debugPrint('❌ Enhancement error: $e\n$st');
      return ProcessedImage(
        file: source,
        appliedSteps: ['Original (enhancement failed)'],
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // IMAGE ALGORITHMS
  // ─────────────────────────────────────────────────────────────────────────

  /// Stretch the image histogram so the darkest pixel → 0, brightest → 255.
  static img.Image _autoLevels(img.Image src) {
    int minV = 255, maxV = 0;

    for (final pixel in src) {
      final v = pixel.r.toInt(); // grayscale — r == g == b
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }

    final range = (maxV - minV).toDouble();
    if (range < 1) return src; // already flat

    final dst = img.Image.from(src);
    for (final pixel in dst) {
      final v = pixel.r.toInt();
      final normalized = (((v - minV) / range) * 255).clamp(0, 255).toInt();
      pixel.r = normalized;
      pixel.g = normalized;
      pixel.b = normalized;
    }
    return dst;
  }

  /// Unsharp mask: sharpen by adding (original - blurred) * strength.
  static img.Image _unsharpMask(
    img.Image src, {
    double sigma = 1.5,
    double strength = 0.5,
  }) {
    final radius = (sigma * 2).ceil();
    final blurred = img.gaussianBlur(src, radius: radius);
    final dst = img.Image.from(src);

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final orig = src.getPixel(x, y).r.toInt();
        final blur = blurred.getPixel(x, y).r.toInt();
        final sharpened = (orig + (orig - blur) * strength)
            .clamp(0, 255)
            .toInt();
        dst.setPixelRgb(x, y, sharpened, sharpened, sharpened);
      }
    }
    return dst;
  }

  /// Adaptive binarization inspired by the Sauvola method.
  /// Each pixel is thresholded against its local window's mean + variance.
  static img.Image _adaptiveBinarize(
    img.Image src, {
    int windowSize = 51,
    double k = 0.15,
  }) {
    final w = src.width;
    final h = src.height;
    final half = windowSize ~/ 2;

    // Build integral image for fast mean computation
    final integral = List.generate(h + 1, (_) => List<int>.filled(w + 1, 0));
    final integral2 = List.generate(
      h + 1,
      (_) => List<double>.filled(w + 1, 0),
    );

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final v = src.getPixel(x, y).r.toInt();
        integral[y + 1][x + 1] =
            v + integral[y][x + 1] + integral[y + 1][x] - integral[y][x];
        integral2[y + 1][x + 1] =
            v * v.toDouble() +
            integral2[y][x + 1] +
            integral2[y + 1][x] -
            integral2[y][x];
      }
    }

    final dst = img.Image(width: w, height: h);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final x1 = math.max(0, x - half);
        final y1 = math.max(0, y - half);
        final x2 = math.min(w - 1, x + half);
        final y2 = math.min(h - 1, y + half);

        final count = (x2 - x1 + 1) * (y2 - y1 + 1);
        final sum =
            integral[y2 + 1][x2 + 1] -
            integral[y1][x2 + 1] -
            integral[y2 + 1][x1] +
            integral[y1][x1];
        final sum2 =
            integral2[y2 + 1][x2 + 1] -
            integral2[y1][x2 + 1] -
            integral2[y2 + 1][x1] +
            integral2[y1][x1];

        final mean = sum / count;
        final variance = (sum2 / count) - (mean * mean);
        final stddev = math.sqrt(math.max(0, variance));

        // Sauvola threshold formula
        final threshold = mean * (1 + k * (stddev / 128.0 - 1));

        final v = src.getPixel(x, y).r.toInt();
        final out = v >= threshold ? 255 : 0;
        dst.setPixelRgb(x, y, out, out, out);
      }
    }

    return dst;
  }

  /// Hard threshold: pixels above [level] → white, below → black.
  static img.Image _threshold(img.Image src, int level) {
    final dst = img.Image.from(src);
    for (final pixel in dst) {
      final v = pixel.r.toInt() >= level ? 255 : 0;
      pixel.r = v;
      pixel.g = v;
      pixel.b = v;
    }
    return dst;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UTILITIES
  // ─────────────────────────────────────────────────────────────────────────

  static Future<File> _saveTmp(img.Image image, String tag) async {
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '${dir.path}/${tag}_$ts.png';
    final file = File(path);
    await file.writeAsBytes(img.encodePng(image));
    return file;
  }

  // Needed only for WebUiSettings — on mobile this is never called.
  static BuildContext? _navigatorContext;

  /// Call this once in your app's root widget if you target web.
  static void setContext(BuildContext ctx) => _navigatorContext = ctx;

  // ── Legacy compat: old call sites that just want a File? ──────────────
  /// Deprecated — use [cropAndEnhance] instead.
  @Deprecated('Use cropAndEnhance() which returns a ProcessedImage')
  static Future<File?> cropImage(String path) async {
    final result = await cropAndEnhance(path);
    return result?.file;
  }
}
