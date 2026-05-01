import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class PdfImportResult {
  final String fileName;
  final String extractedText;
  final String? warning;

  const PdfImportResult({
    required this.fileName,
    required this.extractedText,
    this.warning,
  });
}

class PdfService {
  static const int _maxImportedCharacters = 12000;

  static Future<PdfImportResult?> pickPdfAndExtractText() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final pickedFile = result.files.single;
    final path = pickedFile.path;
    if (path == null || path.isEmpty) {
      throw Exception('Could not open the selected PDF file.');
    }

    final bytes = await File(path).readAsBytes();
    var extracted = _extractText(bytes).trim();

    if (extracted.isEmpty) {
      throw Exception(
        'No readable text was found in that PDF. Try a text-based PDF or upload screenshots instead.',
      );
    }

    String? warning;
    if (extracted.length > _maxImportedCharacters) {
      extracted = extracted.substring(0, _maxImportedCharacters);
      warning =
          'Imported the first $_maxImportedCharacters characters from the PDF.';
    } else if (extracted.length < 120) {
      warning = 'Only a small amount of text was found in the PDF.';
    }

    return PdfImportResult(
      fileName: pickedFile.name,
      extractedText: extracted,
      warning: warning,
    );
  }

  static Future<File> exportTextAsPdf({
    required String title,
    required String text,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(
      '${docsDir.path}${Platform.pathSeparator}exports',
    );
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(
      '${exportDir.path}${Platform.pathSeparator}${_safeFileName(title)}-$timestamp.pdf',
    );

    final pdf = _buildPdfDocument(title: title, text: text);
    await file.writeAsBytes(pdf, flush: true);
    return file;
  }

  static String _extractText(Uint8List bytes) {
    final raw = latin1.decode(bytes);
    final sources = <String>[raw, ..._extractStreamSources(raw, bytes)];
    final lines = <String>[];
    final seen = <String>{};

    for (final source in sources) {
      for (final fragment in _extractFragments(source)) {
        final normalized = _normalizeFragment(fragment);
        if (_shouldKeepFragment(normalized) && seen.add(normalized)) {
          lines.add(normalized);
        }
      }
    }

    return lines.join('\n');
  }

  static List<String> _extractStreamSources(String raw, Uint8List bytes) {
    final sources = <String>[];
    var cursor = 0;

    while (true) {
      final streamIndex = raw.indexOf('stream', cursor);
      if (streamIndex == -1) {
        break;
      }

      var start = streamIndex + 'stream'.length;
      if (start < raw.length && raw[start] == '\r') {
        start += 1;
      }
      if (start < raw.length && raw[start] == '\n') {
        start += 1;
      }

      final end = raw.indexOf('endstream', start);
      if (end == -1) {
        break;
      }

      final headerStart = raw.lastIndexOf('obj', streamIndex);
      final header = raw.substring(
        headerStart == -1 ? 0 : headerStart,
        streamIndex,
      );
      final streamBytes = bytes.sublist(start, end);

      if (header.contains('/FlateDecode')) {
        try {
          sources.add(latin1.decode(zlib.decode(streamBytes)));
        } catch (_) {
          // Skip compressed streams we cannot decode safely.
        }
      } else {
        sources.add(latin1.decode(streamBytes));
      }

      cursor = end + 'endstream'.length;
    }

    return sources;
  }

  static List<String> _extractFragments(String source) {
    final fragments = <String>[];

    final singleTextPattern = RegExp(r'\(((?:\\.|[^\\)])*)\)\s*Tj');
    for (final match in singleTextPattern.allMatches(source)) {
      fragments.add(_decodeLiteral(match.group(1) ?? ''));
    }

    final arrayPattern = RegExp(r'\[(.*?)\]\s*TJ', dotAll: true);
    final chunkPattern = RegExp(r'\((?:\\.|[^\\)])*\)');
    for (final match in arrayPattern.allMatches(source)) {
      final content = match.group(1) ?? '';
      final buffer = StringBuffer();
      for (final chunk in chunkPattern.allMatches(content)) {
        final text = chunk.group(0) ?? '';
        if (text.length >= 2) {
          buffer.write(_decodeLiteral(text.substring(1, text.length - 1)));
        }
      }
      final combined = buffer.toString().trim();
      if (combined.isNotEmpty) {
        fragments.add(combined);
      }
    }

    if (fragments.isEmpty) {
      final fallbackPattern = RegExp(
        r'[A-Za-z0-9][A-Za-z0-9 ,.;:?!()/%+\-]{24,}',
      );
      for (final match in fallbackPattern.allMatches(source)) {
        fragments.add(match.group(0) ?? '');
      }
    }

    return fragments;
  }

  static String _decodeLiteral(String input) {
    final buffer = StringBuffer();

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char != '\\' || i + 1 >= input.length) {
        buffer.write(char);
        continue;
      }

      final next = input[++i];
      switch (next) {
        case 'n':
          buffer.write('\n');
          break;
        case 'r':
          buffer.write('\r');
          break;
        case 't':
          buffer.write('\t');
          break;
        case 'b':
          buffer.write('\b');
          break;
        case 'f':
          buffer.write('\f');
          break;
        case '(':
        case ')':
        case '\\':
          buffer.write(next);
          break;
        default:
          if (_isOctalDigit(next)) {
            final octal = StringBuffer()..write(next);
            for (var j = 0; j < 2 && i + 1 < input.length; j++) {
              final peek = input[i + 1];
              if (!_isOctalDigit(peek)) {
                break;
              }
              i += 1;
              octal.write(peek);
            }
            buffer.writeCharCode(
              int.tryParse(octal.toString(), radix: 8) ?? 32,
            );
          } else {
            buffer.write(next);
          }
          break;
      }
    }

    return buffer.toString();
  }

  static bool _isOctalDigit(String value) =>
      value.codeUnitAt(0) >= 48 && value.codeUnitAt(0) <= 55;

  static String _normalizeFragment(String input) {
    return input
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\s*\n\s*'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  static bool _shouldKeepFragment(String input) {
    if (input.length < 3) {
      return false;
    }

    final blockedPrefixes = [
      '%PDF',
      'endobj',
      'obj',
      'stream',
      'endstream',
      '/Type',
      '/Font',
      '/Length',
      '/Filter',
      '/Root',
      '/Pages',
      '/Kids',
    ];

    for (final prefix in blockedPrefixes) {
      if (input.startsWith(prefix)) {
        return false;
      }
    }

    return RegExp(r'[A-Za-z0-9]').hasMatch(input);
  }

  static Uint8List _buildPdfDocument({
    required String title,
    required String text,
  }) {
    final generatedAt = DateTime.now().toLocal().toString();
    final contentLines = <String>[
      title,
      'Generated by Homework AI on $generatedAt',
      '',
      ..._wrapText(text),
    ];

    final pages = <List<String>>[];
    for (var index = 0; index < contentLines.length; index += 42) {
      final end = (index + 42 < contentLines.length)
          ? index + 42
          : contentLines.length;
      pages.add(contentLines.sublist(index, end));
    }

    if (pages.isEmpty) {
      pages.add(<String>['No content']);
    }

    final objects = <int, String>{};
    final pageRefs = <String>[];
    var objectNumber = 4;

    objects[1] = '<< /Type /Catalog /Pages 2 0 R >>';
    objects[3] = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>';

    for (final pageLines in pages) {
      final pageObject = objectNumber;
      final contentObject = objectNumber + 1;
      pageRefs.add('$pageObject 0 R');

      final stream = _buildPageStream(pageLines);
      final streamLength = utf8.encode(stream).length;
      objects[pageObject] =
          '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 3 0 R >> >> /Contents $contentObject 0 R >>';
      objects[contentObject] =
          '<< /Length $streamLength >>\nstream\n$stream\nendstream';
      objectNumber += 2;
    }

    objects[2] =
        '<< /Type /Pages /Kids [${pageRefs.join(' ')}] /Count ${pages.length} >>';

    final maxObject = objectNumber - 1;
    final header = '%PDF-1.4\n';
    final renderedObjects = <String>[];

    for (var index = 1; index <= maxObject; index++) {
      final body = objects[index] ?? '';
      renderedObjects.add('$index 0 obj\n$body\nendobj\n');
    }

    final offsets = List<int>.filled(maxObject + 1, 0);
    var cursor = utf8.encode(header).length;
    for (var index = 1; index <= maxObject; index++) {
      offsets[index] = cursor;
      cursor += utf8.encode(renderedObjects[index - 1]).length;
    }

    final xrefOffset = cursor;
    final xref = StringBuffer()
      ..writeln('xref')
      ..writeln('0 ${maxObject + 1}')
      ..writeln('0000000000 65535 f ');

    for (var index = 1; index <= maxObject; index++) {
      xref.writeln('${offsets[index].toString().padLeft(10, '0')} 00000 n ');
    }

    final trailer = StringBuffer()
      ..writeln('trailer')
      ..writeln('<< /Size ${maxObject + 1} /Root 1 0 R >>')
      ..writeln('startxref')
      ..writeln(xrefOffset)
      ..write('%%EOF');

    final pdf = StringBuffer(header)
      ..writeAll(renderedObjects)
      ..write(xref)
      ..write(trailer);

    return Uint8List.fromList(utf8.encode(pdf.toString()));
  }

  static String _buildPageStream(List<String> lines) {
    final stream = StringBuffer()
      ..writeln('BT')
      ..writeln('/F1 12 Tf')
      ..writeln('14 TL')
      ..writeln('50 790 Td');

    for (var index = 0; index < lines.length; index++) {
      final escaped = _pdfEscape(lines[index]);
      if (index > 0) {
        stream.writeln('T*');
      }
      stream.writeln('($escaped) Tj');
    }

    stream.writeln('ET');
    return stream.toString();
  }

  static List<String> _wrapText(String text) {
    final normalizedText = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');

    final wrapped = <String>[];
    for (final paragraph in normalizedText.split('\n')) {
      if (paragraph.trim().isEmpty) {
        wrapped.add('');
        continue;
      }

      final words = paragraph.trim().split(RegExp(r'\s+'));
      final buffer = StringBuffer();

      for (final word in words) {
        if (buffer.isEmpty) {
          if (word.length <= 88) {
            buffer.write(word);
          } else {
            final chunks = _splitLongWord(word);
            wrapped.addAll(chunks.take(chunks.length - 1));
            buffer.write(chunks.last);
          }
          continue;
        }

        final next = '${buffer.toString()} $word';
        if (next.length <= 88) {
          buffer
            ..clear()
            ..write(next);
        } else {
          wrapped.add(buffer.toString());
          if (word.length <= 88) {
            buffer
              ..clear()
              ..write(word);
          } else {
            final chunks = _splitLongWord(word);
            wrapped.addAll(chunks.take(chunks.length - 1));
            buffer
              ..clear()
              ..write(chunks.last);
          }
        }
      }

      if (buffer.isNotEmpty) {
        wrapped.add(buffer.toString());
      }
    }

    return wrapped;
  }

  static List<String> _splitLongWord(String word) {
    final chunks = <String>[];
    for (var index = 0; index < word.length; index += 88) {
      final end = (index + 88 < word.length) ? index + 88 : word.length;
      chunks.add(word.substring(index, end));
    }
    return chunks;
  }

  static String _pdfEscape(String value) {
    final buffer = StringBuffer();
    for (final codePoint in value.runes) {
      if (codePoint == 92) {
        buffer.write(r'\\');
      } else if (codePoint == 40) {
        buffer.write(r'\(');
      } else if (codePoint == 41) {
        buffer.write(r'\)');
      } else if ((codePoint >= 32 && codePoint <= 126) ||
          (codePoint >= 160 && codePoint <= 255)) {
        buffer.writeCharCode(codePoint);
      } else {
        buffer.write('?');
      }
    }
    return buffer.toString();
  }

  static String _safeFileName(String input) {
    final normalized = input.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '-',
    );
    return normalized.replaceAll(RegExp(r'^-+|-+$'), '').isEmpty
        ? 'homework-ai-export'
        : normalized.replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
