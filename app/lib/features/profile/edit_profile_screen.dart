import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data/social.dart';
import '../../core/widgets/user_avatar.dart';

const Color _kPrimary = Color(0xFFFF6B35);

/// Edit display name, bio and profile photo. Pops with true when something was saved.
class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const int _bioMax = 150;

  late final TextEditingController _name;
  late final TextEditingController _bio;
  String? _avatarUrl;
  File? _pickedAvatar;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: (widget.profile['display_name'] ?? '').toString());
    _bio = TextEditingController(text: (widget.profile['bio'] ?? '').toString());
    _avatarUrl = widget.profile['avatar_url']?.toString();
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      _pickedAvatar = File(picked.path);
      _error = null;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Your name cannot be empty.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_pickedAvatar != null) {
        _avatarUrl = await social.uploadMyAvatar(_pickedAvatar!);
      }
      await social.updateMyProfile(displayName: name, bio: _bio.text);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save. Check your connection and try again.';
      });
    }
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF3F3F3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        title: const Text('Edit profile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary),
                  )
                : const Text('Save', style: TextStyle(color: _kPrimary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: GestureDetector(
                onTap: _saving ? null : _pickAvatar,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    _pickedAvatar != null
                        ? CircleAvatar(radius: 48, backgroundImage: FileImage(_pickedAvatar!))
                        : UserAvatar(url: _avatarUrl, name: _name.text, radius: 48),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: _kPrimary, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _saving ? null : _pickAvatar,
                child: const Text('Change photo'),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Name', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              maxLength: 40,
              onChanged: (_) => setState(() {}),
              decoration: _decoration('Your name'),
            ),
            const SizedBox(height: 16),
            const Text('Bio', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _bio,
              maxLength: _bioMax,
              maxLines: 4,
              decoration: _decoration('Tell people about you'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}
