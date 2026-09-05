import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:resq/services/api_service.dart';

/// Tappable circular avatar that lets the donor pick a new photo from the
/// camera or gallery.
///
/// In "upload mode" (`token` provided — the Profile screen), a picked
/// photo is uploaded immediately via [ApiService.uploadProfilePhoto] and
/// [onUploaded] fires with the new URL once it succeeds.
///
/// In "local-only mode" (`token` null — the registration wizard, before
/// any session token exists yet), the picked file is just kept as a local
/// preview and [onLocalFilePicked] fires with its path; the actual upload
/// happens later once account creation grants a real token (see
/// otp_ver_view.dart, right after ApiService.completeProfile succeeds).
class EditableAvatar extends StatefulWidget {
  final String? photoUrl;
  final String? localPhotoPath;
  final double radius;
  final String? token;
  final ValueChanged<String>? onLocalFilePicked;
  final ValueChanged<String>? onUploaded;

  const EditableAvatar({
    super.key,
    this.photoUrl,
    this.localPhotoPath,
    this.radius = 38,
    this.token,
    this.onLocalFilePicked,
    this.onUploaded,
  });

  @override
  State<EditableAvatar> createState() => _EditableAvatarState();
}

class _EditableAvatarState extends State<EditableAvatar> {
  String? _localPreviewPath;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _localPreviewPath = widget.localPhotoPath;
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Update Profile Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: Color(0xFF9B1B20)),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF9B1B20)),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 800, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _localPreviewPath = picked.path);

    final token = widget.token;
    if (token == null || token.isEmpty) {
      // Registration flow — no session token yet, just hand the local path
      // up; the actual upload happens once account creation succeeds.
      widget.onLocalFilePicked?.call(picked.path);
      return;
    }

    setState(() => _uploading = true);
    try {
      final url = await ApiService.uploadProfilePhoto(token, picked.path);
      if (!mounted) return;
      widget.onUploaded?.call(url);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update photo: ${e.message}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reach the ResQ server. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _localPreviewPath;
    ImageProvider? provider;
    if (path != null) {
      provider = FileImage(File(path));
    } else if (widget.photoUrl != null && widget.photoUrl!.isNotEmpty) {
      provider = NetworkImage(widget.photoUrl!);
    }

    return GestureDetector(
      onTap: _uploading ? null : _pickPhoto,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: widget.radius,
            backgroundColor: const Color(0xFFF3E5E6),
            backgroundImage: provider,
            child: provider == null
                ? Icon(Icons.person_rounded, size: widget.radius * 1.15, color: const Color(0xFF9B1B20))
                : null,
          ),
          if (_uploading)
            CircleAvatar(
              radius: widget.radius,
              backgroundColor: Colors.black.withValues(alpha: 0.35),
              child: const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              ),
            ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(color: Color(0xFF9B1B20), shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}