import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme.dart';
import '../utils/ai_service.dart';
import 'result_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _controller;
  bool _isAnalyzing = false;
  bool _isFrontCamera = true;
  bool _isCameraReady = false;
  bool _isSwitchingCamera = false;

  List<CameraDescription> _cameras = [];

  @override
  void initState() {
    super.initState();
    _initCamera();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showCameraGuidelines();
    });
  }

  void _showCameraGuidelines() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(
                Icons.face_retouching_natural,
                size: 50,
                color: brandCyanDark,
              ),
              const SizedBox(height: 15),
              const Text(
                'เคล็ดลับสแกนให้แม่นยำเป๊ะ! ✨',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: brandCyanDark,
                ),
              ),
              const SizedBox(height: 20),
              _buildGuideItem(
                Icons.wb_sunny_outlined,
                'ใช้แสงธรรมชาติ',
                'หรือแสงไฟสีขาวที่สว่างเพียงพอ ไม่มืดหรือจ้าเกินไป',
              ),
              _buildGuideItem(
                Icons.filter_b_and_w,
                'ผิวจริงดีที่สุด',
                'งดใช้ฟิลเตอร์แต่งภาพ เพื่อให้ AI เห็นสภาพผิวที่แท้จริง',
              ),
              _buildGuideItem(
                Icons.face,
                'ถ่ายให้เห็นเต็มใบหน้า',
                'หน้าตรง ไม่เอียง ไม่ไกลเกินไป และไม่มีผมปรกหน้า',
              ),
              _buildGuideItem(
                Icons.crop_free,
                'สแกนส่วนอื่นได้ด้วยนะ!',
                'ถ่ายสิวที่หน้าอก แผ่นหลัง หรือแขนให้อยู่กึ่งกลางภาพได้เลย',
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandCyan,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'เข้าใจแล้ว ลุยเลย!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuideItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: brandCyan.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: brandCyan, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initCamera() async {
    try {
      final status = await Permission.camera.request();

      if (!status.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('กรุณาอนุญาตการใช้งานกล้องก่อน'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      final front = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      await AiService.instance.init();

      if (!mounted) return;
      setState(() {
        _isCameraReady = true;
      });
    } catch (e) {
      debugPrint('Init camera error: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_isAnalyzing || _isSwitchingCamera || _cameras.isEmpty) return;

    setState(() {
      _isSwitchingCamera = true;
      _isFrontCamera = !_isFrontCamera;
      _isCameraReady = false;
    });

    final targetDirection =
        _isFrontCamera ? CameraLensDirection.front : CameraLensDirection.back;

    CameraDescription targetCamera;
    try {
      targetCamera =
          _cameras.firstWhere((c) => c.lensDirection == targetDirection);
    } catch (_) {
      targetCamera = _cameras.first;
    }

    final oldController = _controller;
    _controller = null;

    try {
      await oldController?.dispose();

      final newController = CameraController(
        targetCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await newController.initialize();

      if (!mounted) {
        await newController.dispose();
        return;
      }

      setState(() {
        _controller = newController;
        _isCameraReady = true;
      });
    } catch (e) {
      debugPrint('Switch camera error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('สลับกล้องไม่สำเร็จ: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingCamera = false;
        });
      }
    }
  }

  Future<void> _analyzeAndGo(String imagePath) async {
    if (_isAnalyzing || _isSwitchingCamera) return;

    setState(() => _isAnalyzing = true);

    final progress = ValueNotifier<double>(0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (_, v, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: brandCyan),
                const SizedBox(height: 16),
                const Text('กำลังวิเคราะห์สภาพผิว...'),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: v,
                  color: brandCyan,
                  backgroundColor: Colors.grey[200],
                ),
                const SizedBox(height: 8),
                Text('${(v * 100).toStringAsFixed(0)}%'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      for (int i = 1; i <= 5; i++) {
        await Future.delayed(const Duration(milliseconds: 150));
        progress.value = i / 10;
      }

      final Uint8List bytes = await File(imagePath).readAsBytes();
      final result = await AiService.instance.analyzeImage(bytes);

      for (int i = 6; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
        progress.value = i / 10;
      }

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            imageBytes: bytes,
            recognitions: result.recognitions,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      progress.dispose();
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Future<void> _capture() async {
    if (_isAnalyzing || _isSwitchingCamera) return;
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final XFile file = await _controller!.takePicture();
      await _analyzeAndGo(file.path);
    } catch (e) {
      debugPrint('Capture error: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isAnalyzing || _isSwitchingCamera) return;

    final picker = ImagePicker();
    final XFile? img = await picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;

    await _analyzeAndGo(img.path);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canUseCamera = _controller != null &&
        _controller!.value.isInitialized &&
        _isCameraReady;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: canUseCamera
                ? CameraPreview(_controller!)
                : Container(
                    color: Colors.grey[900],
                    alignment: Alignment.center,
                    child: _isSwitchingCamera
                        ? const CircularProgressIndicator(color: brandCyan)
                        : const Icon(
                            Icons.camera_alt,
                            size: 80,
                            color: Colors.white24,
                          ),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: (_isAnalyzing || _isSwitchingCamera)
                          ? null
                          : () => Navigator.pop(context),
                    ),
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: const Icon(
                            Icons.info_outline,
                            color: Colors.white,
                          ),
                          onPressed: (_isAnalyzing || _isSwitchingCamera)
                              ? null
                              : _showCameraGuidelines,
                        ),
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: const Icon(
                            Icons.flip_camera_ios,
                            color: Colors.white,
                          ),
                          onPressed: (_isAnalyzing || _isSwitchingCamera)
                              ? null
                              : _switchCamera,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _iconBtn(Icons.photo_library, _pickFromGallery),
                  GestureDetector(
                    onTap:
                        (_isAnalyzing || _isSwitchingCamera) ? null : _capture,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (_isAnalyzing || _isSwitchingCamera)
                              ? Colors.grey
                              : brandCyan,
                          width: 4,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: (_isAnalyzing || _isSwitchingCamera)
                            ? Colors.grey
                            : brandCyan,
                        child: (_isAnalyzing || _isSwitchingCamera)
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 30,
                              ),
                      ),
                    ),
                  ),
                  _iconBtn(
                    Icons.history,
                    () => Navigator.pushReplacementNamed(context, '/history'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback action) {
    return CircleAvatar(
      backgroundColor: Colors.grey[100],
      child: IconButton(
        icon: Icon(icon, color: Colors.black87),
        onPressed: (_isAnalyzing || _isSwitchingCamera) ? null : action,
      ),
    );
  }
}
