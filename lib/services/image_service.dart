import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

class ProcessedImage {
  final File file;
  final List<String> appliedSteps;

  ProcessedImage({required this.file, required this.appliedSteps});
}

class ImageService {
  static const int _visionMaxDimension = 2400;
  static const int _ocrMaxWidth = 2000;

  static Future<File?> cropForHomework(String sourcePath) async {
    final cropped = await _showCropUI(sourcePath);
    if (cropped == null) {
      return null;
    }
    return _normalizeForVision(cropped);
  }

  static Future<ProcessedImage?> cropAndEnhance(String sourcePath) async {
    final cropped = await cropForHomework(sourcePath);
    if (cropped == null) {
      return null;
    }
    return enhanceForOcr(cropped);
  }

  static Future<ProcessedImage> enhanceForOcr(File source) async {
    return _enhance(source);
  }

  @Deprecated('Use enhanceForOcr() instead.')
  static Future<ProcessedImage> enhanceOnly(File source) async {
    return enhanceForOcr(source);
  }

  static Future<File?> _showCropUI(String path) async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: path,
        compressQuality: 100,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Homework',
            toolbarColor: const Color(0xFF0D0D0D),
            toolbarWidgetColor: const Color(0xFF00E5FF),
            activeControlsWidgetColor: const Color(0xFF4F46E5),
            backgroundColor: const Color(0xFF0D0D0D),
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
            doneButtonTitle: 'Use Crop',
            cancelButtonTitle: 'Cancel',
            resetButtonHidden: false,
            rotateButtonsHidden: false,
            aspectRatioPickerButtonHidden: false,
            resetAspectRatioEnabled: true,
            aspectRatioLockEnabled: false,
            hidesNavigationBar: false,
          ),
          if (kIsWeb && _navigatorContext != null)
            WebUiSettings(
              context: _navigatorContext!,
              presentStyle: WebPresentStyle.dialog,
              size: const CropperSize(width: 520, height: 520),
            ),
        ],
      );

      if (cropped == null) {
        return null;
      }

      return File(cropped.path);
    } catch (e) {
      debugPrint('Crop UI error: $e');
      return null;
    }
  }

  static Future<File> _normalizeForVision(File source) async {
    try {
      final bytes = await source.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        return source;
      }

      image = img.bakeOrientation(image);

      final longestSide = math.max(image.width, image.height);
      if (longestSide > _visionMaxDimension) {
        final scale = _visionMaxDimension / longestSide;
        image = img.copyResize(
          image,
          width: (image.width * scale).round(),
          height: (image.height * scale).round(),
          interpolation: img.Interpolation.cubic,
        );
      }

      return _saveTmp(image, 'cropped', asPng: true);
    } catch (e) {
      debugPrint('Vision prep error: $e');
      return source;
    }
  }

  static Future<ProcessedImage> _enhance(File source) async {
    final appliedSteps = <String>[];

    try {
      final bytes = await source.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        return ProcessedImage(
          file: source,
          appliedSteps: ['Original image kept'],
        );
      }

      image = img.bakeOrientation(image);
      appliedSteps.add('Auto-rotated');

      if (image.width > _ocrMaxWidth) {
        final scale = _ocrMaxWidth / image.width;
        image = img.copyResize(
          image,
          width: _ocrMaxWidth,
          height: (image.height * scale).round(),
          interpolation: img.Interpolation.cubic,
        );
        appliedSteps.add('Resized for OCR');
      }

      image = img.grayscale(image);
      appliedSteps.add('Grayscale');

      image = _autoLevels(image);
      appliedSteps.add('Auto-levels');

      image = img.adjustColor(image, contrast: 1.3);
      appliedSteps.add('Contrast boost');

      image = _unsharpMask(image, sigma: 1.5, strength: 0.6);
      appliedSteps.add('Sharpened text');

      image = _adaptiveBinarize(image, windowSize: 51, k: 0.15);
      appliedSteps.add('Adaptive threshold');

      image = img.gaussianBlur(image, radius: 1);
      image = _threshold(image, 128);
      appliedSteps.add('Noise cleanup');

      final outFile = await _saveTmp(image, 'enhanced', asPng: true);
      appliedSteps.add('Saved as PNG');

      return ProcessedImage(file: outFile, appliedSteps: appliedSteps);
    } catch (e, st) {
      debugPrint('Enhancement error: $e\n$st');
      return ProcessedImage(
        file: source,
        appliedSteps: ['Original image kept'],
      );
    }
  }

  static img.Image _autoLevels(img.Image src) {
    int minV = 255;
    int maxV = 0;

    for (final pixel in src) {
      final value = pixel.r.toInt();
      if (value < minV) {
        minV = value;
      }
      if (value > maxV) {
        maxV = value;
      }
    }

    final range = (maxV - minV).toDouble();
    if (range < 1) {
      return src;
    }

    final dst = img.Image.from(src);
    for (final pixel in dst) {
      final value = pixel.r.toInt();
      final normalized = (((value - minV) / range) * 255).clamp(0, 255).toInt();
      pixel.r = normalized;
      pixel.g = normalized;
      pixel.b = normalized;
    }
    return dst;
  }

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
        final original = src.getPixel(x, y).r.toInt();
        final blurredValue = blurred.getPixel(x, y).r.toInt();
        final sharpened = (original + (original - blurredValue) * strength)
            .clamp(0, 255)
            .toInt();
        dst.setPixelRgb(x, y, sharpened, sharpened, sharpened);
      }
    }

    return dst;
  }

  static img.Image _adaptiveBinarize(
    img.Image src, {
    int windowSize = 51,
    double k = 0.15,
  }) {
    final width = src.width;
    final height = src.height;
    final halfWindow = windowSize ~/ 2;

    final integral = List.generate(
      height + 1,
      (_) => List<int>.filled(width + 1, 0),
    );
    final integralSquares = List.generate(
      height + 1,
      (_) => List<double>.filled(width + 1, 0),
    );

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final value = src.getPixel(x, y).r.toInt();
        integral[y + 1][x + 1] =
            value + integral[y][x + 1] + integral[y + 1][x] - integral[y][x];
        integralSquares[y + 1][x + 1] =
            value * value.toDouble() +
            integralSquares[y][x + 1] +
            integralSquares[y + 1][x] -
            integralSquares[y][x];
      }
    }

    final dst = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final x1 = math.max(0, x - halfWindow);
        final y1 = math.max(0, y - halfWindow);
        final x2 = math.min(width - 1, x + halfWindow);
        final y2 = math.min(height - 1, y + halfWindow);

        final count = (x2 - x1 + 1) * (y2 - y1 + 1);
        final sum =
            integral[y2 + 1][x2 + 1] -
            integral[y1][x2 + 1] -
            integral[y2 + 1][x1] +
            integral[y1][x1];
        final squareSum =
            integralSquares[y2 + 1][x2 + 1] -
            integralSquares[y1][x2 + 1] -
            integralSquares[y2 + 1][x1] +
            integralSquares[y1][x1];

        final mean = sum / count;
        final variance = (squareSum / count) - (mean * mean);
        final stddev = math.sqrt(math.max(0, variance));
        final threshold = mean * (1 + k * (stddev / 128.0 - 1));

        final value = src.getPixel(x, y).r.toInt();
        final output = value >= threshold ? 255 : 0;
        dst.setPixelRgb(x, y, output, output, output);
      }
    }

    return dst;
  }

  static img.Image _threshold(img.Image src, int level) {
    final dst = img.Image.from(src);
    for (final pixel in dst) {
      final value = pixel.r.toInt() >= level ? 255 : 0;
      pixel.r = value;
      pixel.g = value;
      pixel.b = value;
    }
    return dst;
  }

  static Future<File> _saveTmp(
    img.Image image,
    String tag, {
    required bool asPng,
  }) async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = asPng ? 'png' : 'jpg';
    final path = '${dir.path}/${tag}_$timestamp.$extension';
    final file = File(path);
    final bytes = asPng
        ? img.encodePng(image)
        : img.encodeJpg(image, quality: 95);
    await file.writeAsBytes(bytes);
    return file;
  }

  static BuildContext? _navigatorContext;

  static void setContext(BuildContext ctx) => _navigatorContext = ctx;

  @Deprecated('Use cropForHomework() instead.')
  static Future<File?> cropImage(String path) async {
    return cropForHomework(path);
  }
}
