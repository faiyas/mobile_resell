import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/theme.dart';

class ImageHelper {
  static final ImagePicker _picker = ImagePicker();
  static final Map<int, Uint8List> _decodedCache = <int, Uint8List>{};
  static const int _maxCacheEntries = 150;

  /// Prompts user to pick an image from Gallery or Camera, converts to Base64 data URL
  static Future<String?> pickImageAsBase64({
    ImageSource source = ImageSource.gallery,
    int imageQuality = 75,
    double maxWidth = 800,
    double maxHeight = 800,
  }) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

      if (file == null) return null;

      final Uint8List bytes = await file.readAsBytes();
      final pathLower = file.path.toLowerCase();
      String mime = 'image/jpeg';
      if (pathLower.endsWith('.png')) {
        mime = 'image/png';
      } else if (pathLower.endsWith('.webp')) {
        mime = 'image/webp';
      }

      final base64Data = base64Encode(bytes);
      return 'data:$mime;base64,$base64Data';
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Extracts pure Base64 bytes from a raw Base64 string or data URL (LRU cached in RAM)
  static Uint8List? decodeBase64(String? base64String) {
    if (base64String == null || base64String.trim().isEmpty) return null;
    final key = base64String.hashCode;
    final cached = _decodedCache[key];
    if (cached != null) return cached;
    try {
      String cleanStr = base64String.trim();
      if (cleanStr.contains(',')) {
        cleanStr = cleanStr.split(',').last;
      }
      final bytes = base64Decode(cleanStr);
      if (_decodedCache.length >= _maxCacheEntries) {
        _decodedCache.remove(_decodedCache.keys.first);
      }
      _decodedCache[key] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Shows a modal sheet offering Gallery or Camera
  static Future<String?> showImageSourceDialog(BuildContext context) async {
    return showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Image Source',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Upload JPG, JPEG, or PNG from your device. It will be converted to Base64 automatically.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.lightGreen,
                      foregroundColor: AppTheme.darkGreen,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryGreen, semanticLabel: 'accessibilityLabel: Gallery Photo Source'),
                    label: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.bold), semanticsLabel: 'accessibilityLabel'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final res = await pickImageAsBase64(source: ImageSource.gallery);
                      if (context.mounted && res != null) {
                        Navigator.of(context).pop(res);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                    label: const Text('Camera', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final res = await pickImageAsBase64(source: ImageSource.camera);
                      if (context.mounted && res != null) {
                        Navigator.of(context).pop(res);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
