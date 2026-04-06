import 'dart:convert';
import 'package:image_picker/image_picker.dart';

class StorageService {
  // We are COMPLETELY bypassing Firebase Storage to avoid the billing requirement!
  // Instead, we convert the image to raw text (Base64) and save it inside the free Text database!
  Future<String?> uploadImage(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final String base64String = base64Encode(bytes);
      // Prepend a flag so the UI knows how to decode it
      return 'BASE64:$base64String';
    } catch (e) {
      print('Error encoding image: $e');
      throw Exception('Failed to compress image data: $e');
    }
  }
}
