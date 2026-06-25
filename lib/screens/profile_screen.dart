import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  // 🚨 ตัวแปรใหม่สำหรับเก็บค่า "เพศ"
  String _selectedGender = 'ไม่ระบุ';
  final List<String> _genderOptions = ['ชาย', 'หญิง', 'ไม่ระบุ'];

  bool _isLoading = true;
  bool _isSaving = false;
  String _profileImageBase64 = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _nameController.text =
            (data['username'] ?? user!.displayName ?? '').toString();
        _ageController.text = (data['age'] ?? '').toString();
        _weightController.text = (data['weight'] ?? '').toString();
        _heightController.text = (data['height'] ?? '').toString();
        _profileImageBase64 = (data['profileImage'] ?? '').toString();

        // 🚨 โหลดค่าเพศจาก Firebase
        String loadedGender = (data['gender'] ?? 'ไม่ระบุ').toString();
        if (_genderOptions.contains(loadedGender)) {
          _selectedGender = loadedGender;
        }
      } else {
        _nameController.text = user!.displayName?.trim().isNotEmpty == true
            ? user!.displayName!.trim()
            : (user!.email?.split('@')[0] ?? 'Guest');
      }
    } catch (e) {
      debugPrint('Load profile error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 40,
      );

      if (image == null) return;

      final originalBytes = await image.readAsBytes();

      if (!mounted) return;
      setState(() {
        _profileImageBase64 = base64Encode(originalBytes);
      });
    } catch (e) {
      debugPrint('Pick/compress image error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เลือกรูปไม่สำเร็จ: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (user == null) return;

    final username = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim()) ?? 0;
    final weight = double.tryParse(_weightController.text.trim()) ?? 0.0;
    final height = double.tryParse(_heightController.text.trim()) ?? 0.0;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'username': username,
        'gender': _selectedGender, // 🚨 บันทึกค่าเพศลง Firebase
        'age': age,
        'weight': weight,
        'height': height,
        'profileImage': _profileImageBase64,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user!.updateDisplayName(username);
      await user!.reload();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ บันทึกโปรไฟล์เรียบร้อยแล้ว'),
          backgroundColor: brandCyanDark,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Save profile error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ บันทึกโปรไฟล์ไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  ImageProvider? _buildProfileImage() {
    if (_profileImageBase64.isEmpty) return null;
    try {
      return MemoryImage(base64Decode(_profileImageBase64));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileImage = _buildProfileImage();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: brandCyan))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 55,
                          backgroundColor: brandCyan.withOpacity(0.2),
                          backgroundImage: profileImage,
                          child: profileImage == null
                              ? const Icon(
                                  Icons.person,
                                  size: 55,
                                  color: brandCyanDark,
                                )
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: brandCyanDark,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(user?.email ?? ''),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  const SizedBox(height: 16),

                  // 🚨 เพิ่มช่องเลือกเพศ (Dropdown) 🚨
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration:
                        const InputDecoration(labelText: 'Gender (เพศ)'),
                    items: _genderOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedGender = newValue!;
                      });
                    },
                  ),

                  const SizedBox(height: 16),
                  TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _weightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Weight (kg)'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _heightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Height (cm)'),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save Profile'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
