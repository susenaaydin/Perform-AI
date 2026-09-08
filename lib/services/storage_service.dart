import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Start upload task and return it to let UI monitor progress
  UploadTask uploadVideoTask({
    required String uid,
    required XFile file,
  }) {
    final fileExtension = file.path.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_rehearsal.$fileExtension';
    final ref = _storage.ref().child('users/$uid/videos/$fileName');
    
    // We upload using putFile since we're targeting mobile platforms
    // For large videos, this is memory-efficient as it streams directly from file
    return ref.putFile(File(file.path));
  }
}
