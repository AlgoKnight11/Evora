import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import 'logging_service.dart';

/// Service for uploading photos directly to Cloudinary using an unsigned preset.
/// Automatically strips EXIF/GPS metadata and delivers optimized images via CDN.
class CloudinaryService {
  static final http.Client _client = http.Client();

  /// Uploads an image file to Cloudinary.
  ///
  /// [imageFile] - The local file to upload.
  /// [folder] - Optional subfolder tag (e.g. 'civic_reports', 'missions').
  ///
  /// Returns the secure HTTPS URL of the uploaded image.
  static Future<UploadResult> uploadImage(
    File imageFile, {
    String folder = 'civic_evidence',
  }) async {
    final correlationId = LoggingService.generateCorrelationId();
    LoggingService.logBreadcrumb(
      'Uploading image to Cloudinary (size: ${await imageFile.length()} bytes, tag: $folder)',
      correlationId: correlationId,
    );

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConstants.cloudinaryUploadUrl),
      );

      // Unsigned upload parameters
      request.fields['upload_preset'] = AppConstants.cloudinaryUploadPreset;
      request.fields['folder'] = folder;

      // Attach file
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
      );
      request.files.add(multipartFile);

      final streamedResponse = await _client.send(request).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Image upload timed out after 30 seconds.');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final String secureUrl = responseData['secure_url'] as String;
        final String publicId = responseData['public_id'] as String;

        LoggingService.logBreadcrumb(
          'Image uploaded successfully: $publicId',
          correlationId: correlationId,
        );

        return UploadResult.success(
          url: secureUrl,
          publicId: publicId,
          correlationId: correlationId,
        );
      } else {
        LoggingService.logError(
          'Cloudinary upload failed: ${response.statusCode} - ${response.body}',
          correlationId: correlationId,
        );
        return UploadResult.failure(
          'Upload failed (${response.statusCode}): ${response.reasonPhrase}',
          correlationId: correlationId,
        );
      }
    } catch (e, stackTrace) {
      LoggingService.logError(
        'Cloudinary upload exception: $e',
        stackTrace: stackTrace,
        correlationId: correlationId,
      );
      return UploadResult.failure(
        'Failed to upload image. Please check your internet connection.',
        correlationId: correlationId,
      );
    }
  }
}

/// Result envelope for Cloudinary uploads
class UploadResult {
  final bool isSuccess;
  final String? url;
  final String? publicId;
  final String? errorMessage;
  final String correlationId;

  UploadResult.success({
    required this.url,
    required this.publicId,
    required this.correlationId,
  })  : isSuccess = true,
        errorMessage = null;

  UploadResult.failure(
    this.errorMessage, {
    required this.correlationId,
  })  : isSuccess = false,
        url = null,
        publicId = null;
}
