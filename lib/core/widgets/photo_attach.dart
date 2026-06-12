import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_client.dart';
import '../theme.dart';

/// One photo picked for upload. A form owns one controller, renders a
/// [PhotoAttachField], and calls [upload] while saving; the returned
/// public URL goes into the row's image_url.
class PhotoAttachController extends ChangeNotifier {
  Uint8List? _bytes;
  String? _mime;
  String? error;

  bool get hasPhoto => _bytes != null;
  Uint8List? get bytes => _bytes;

  Future<void> pick() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.lengthInBytes > 10 * 1024 * 1024) {
      error = 'Photo must be 10 MB or smaller.';
      notifyListeners();
      return;
    }
    _bytes = bytes;
    _mime = picked.mimeType ?? 'image/jpeg';
    error = null;
    notifyListeners();
  }

  void clear() {
    _bytes = null;
    _mime = null;
    error = null;
    notifyListeners();
  }

  /// Uploads under the caller's own uid folder (what the bucket policy
  /// requires) and returns the public URL. Call only when [hasPhoto].
  Future<String> upload() async {
    final path = '${supabase.auth.currentUser!.id}/'
        '${DateTime.now().millisecondsSinceEpoch}';
    await supabase.storage.from('media').uploadBinary(
          path,
          _bytes!,
          fileOptions: FileOptions(contentType: _mime),
        );
    return supabase.storage.from('media').getPublicUrl(path);
  }
}

/// The quiet attach control: an image icon until a photo is picked, then
/// a small thumbnail with a remove ✕. [existingUrl] previews what is
/// already saved in edit flows; the ✕ then calls [onCleared] so the form
/// can null the stored URL.
class PhotoAttachField extends StatelessWidget {
  const PhotoAttachField({
    super.key,
    required this.controller,
    this.existingUrl,
    this.onCleared,
  });

  final PhotoAttachController controller;
  final String? existingUrl;
  final VoidCallback? onCleared;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.hasPhoto &&
            (existingUrl == null || existingUrl!.isEmpty)) {
          return IconButton(
            tooltip: 'Attach photo',
            icon: const Icon(
              Icons.image_outlined,
              size: 20,
              color: KColors.memberTextSecondary,
            ),
            onPressed: controller.pick,
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: controller.hasPhoto
                  ? Image.memory(
                      controller.bytes!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      existingUrl!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
            ),
            IconButton(
              tooltip: 'Remove photo',
              icon: const Icon(Icons.close, size: 16),
              onPressed: () {
                controller.clear();
                onCleared?.call();
              },
            ),
          ],
        );
      },
    );
  }
}

/// An attached photo as feeds and detail pages render it: full width,
/// rounded corners, capped height, and silently absent when the URL is
/// dead.
class AttachedPhoto extends StatelessWidget {
  const AttachedPhoto({super.key, required this.url, this.maxHeight = 320});

  final String url;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Image.network(
            url,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
