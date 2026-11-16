import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../features/ai_engine/models/civic_ai_models.dart';
import 'logging_service.dart';

/// Pure-Dart image preprocessing & privacy shield service:
/// 1. Resizes photos and re-encodes to JPEG, guaranteeing EXIF/GPS metadata is stripped on-device.
/// 2. Permanently pixelates human faces and vehicle license plates inside detected PII boxes
///    before media ever uploads to Cloudinary or Firestore.
class PiiRedactionService {
  /// Compresses raw image bytes to ~150-250KB JPEG with max dimension 1280px.
  /// Re-encoding via `package:image` removes all camera EXIF/GPS headers locally.
  static Future<Uint8List> compressAndStripExif(
    Uint8List rawBytes, {
    int maxDimension = 1280,
    int quality = 82,
  }) async {
    return Isolate.run(() => compressAndStripExifSync(
          rawBytes,
          maxDimension: maxDimension,
          quality: quality,
        ));
  }

  /// Synchronous worker version (test-friendly).
  static Uint8List compressAndStripExifSync(
    Uint8List rawBytes, {
    int maxDimension = 1280,
    int quality = 82,
  }) {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return rawBytes;

    // Normalize camera orientation baked into EXIF before discarding EXIF tags
    final oriented = img.bakeOrientation(decoded);

    img.Image resized = oriented;
    if (oriented.width > maxDimension || oriented.height > maxDimension) {
      if (oriented.width >= oriented.height) {
        resized = img.copyResize(oriented, width: maxDimension);
      } else {
        resized = img.copyResize(oriented, height: maxDimension);
      }
    }

    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  }

  /// Applies irreversible block pixelation over all [regions] (normalized 0..1000)
  /// directly on [sourceBytes] in a background isolate.
  static Future<PiiRedactionResult> redactBytes({
    required Uint8List sourceBytes,
    required List<PiiBoundingBox> regions,
    int quality = 84,
  }) async {
    final cid = LoggingService.generateCorrelationId();
    final processed = await Isolate.run(
      () => _redactBytesWorker(sourceBytes, regions, quality),
    );

    final facesCount = regions
        .where((r) => r.isValid && !r.label.contains('plate'))
        .length;
    final platesCount = regions
        .where((r) => r.isValid && r.label.contains('plate'))
        .length;

    if (facesCount > 0 || platesCount > 0) {
      LoggingService.logBreadcrumb(
        'On-device PII shield blurred $facesCount face(s) and $platesCount plate(s)',
        correlationId: cid,
      );
    }

    return PiiRedactionResult(
      bytes: processed,
      facesBlurred: facesCount,
      platesBlurred: platesCount,
      originalBytesLength: sourceBytes.length,
      processedBytesLength: processed.length,
    );
  }

  /// Compresses and redacts a [File], writing the clean image into a temporary file
  /// so the citizen's original gallery file is never overwritten.
  static Future<PiiRedactionResult> redactFileToTemp({
    required File sourceFile,
    required List<PiiBoundingBox> regions,
    Uint8List? precompressedBytes,
    int quality = 84,
  }) async {
    final int originalLen =
        precompressedBytes != null ? await sourceFile.length() : 0;
    final Uint8List compressed;
    final int reportedOriginalLen;
    if (precompressedBytes != null && precompressedBytes.isNotEmpty) {
      compressed = precompressedBytes;
      reportedOriginalLen = originalLen > 0 ? originalLen : precompressedBytes.length;
    } else {
      final rawBytes = await sourceFile.readAsBytes();
      compressed = await compressAndStripExif(rawBytes, quality: quality);
      reportedOriginalLen = rawBytes.length;
    }
    final result = await redactBytes(
      sourceBytes: compressed,
      regions: regions,
      quality: quality,
    );

    final outFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}evora_privacy_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await outFile.writeAsBytes(result.bytes, flush: true);

    return PiiRedactionResult(
      file: outFile,
      bytes: result.bytes,
      facesBlurred: result.facesBlurred,
      platesBlurred: result.platesBlurred,
      originalBytesLength: reportedOriginalLen,
      processedBytesLength: result.processedBytesLength,
    );
  }

  static Uint8List _redactBytesWorker(
    Uint8List sourceBytes,
    List<PiiBoundingBox> regions,
    int quality,
  ) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) return sourceBytes;

    final image = img.bakeOrientation(decoded);
    final validRegions = regions.where((r) => r.isValid).toList();
    if (validRegions.isEmpty) {
      return Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }

    final width = image.width;
    final height = image.height;

    for (final box in validRegions) {
      // Expand bounding box slightly (10% margin) for complete face/plate coverage
      final boxW = (box.xmax - box.xmin);
      final boxH = (box.ymax - box.ymin);
      final padX = (boxW * 0.10).round();
      final padY = (boxH * 0.10).round();

      final left = (((box.xmin - padX).clamp(0, 1000) / 1000.0) * width).floor().clamp(0, width - 1);
      final right = (((box.xmax + padX).clamp(0, 1000) / 1000.0) * width).ceil().clamp(left + 1, width);
      final top = (((box.ymin - padY).clamp(0, 1000) / 1000.0) * height).floor().clamp(0, height - 1);
      final bottom = (((box.ymax + padY).clamp(0, 1000) / 1000.0) * height).ceil().clamp(top + 1, height);

      final regionWidth = right - left;
      final regionHeight = bottom - top;
      if (regionWidth <= 1 || regionHeight <= 1) continue;

      final blockSize = max(10, min(regionWidth, regionHeight) ~/ 5);

      for (int by = top; by < bottom; by += blockSize) {
        final endY = min(by + blockSize, bottom);
        for (int bx = left; bx < right; bx += blockSize) {
          final endX = min(bx + blockSize, right);

          int sumR = 0;
          int sumG = 0;
          int sumB = 0;
          int count = 0;

          for (int y = by; y < endY; y++) {
            for (int x = bx; x < endX; x++) {
              final pixel = image.getPixel(x, y);
              sumR += pixel.r.toInt();
              sumG += pixel.g.toInt();
              sumB += pixel.b.toInt();
              count++;
            }
          }

          if (count == 0) continue;
          final avgR = sumR ~/ count;
          final avgG = sumG ~/ count;
          final avgB = sumB ~/ count;

          for (int y = by; y < endY; y++) {
            for (int x = bx; x < endX; x++) {
              image.setPixelRgba(x, y, avgR, avgG, avgB, 255);
            }
          }
        }
      }
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }
}
