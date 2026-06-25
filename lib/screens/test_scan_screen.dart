import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:my_mobile_app/models/recognition.dart';
import 'package:my_mobile_app/screens/result_screen.dart';

class TestScanScreenState extends StatelessWidget {
  final Uint8List imageBytes;

  const TestScanScreenState({
    super.key,
    required this.imageBytes,
  });

  @override
  Widget build(BuildContext context) {
    final mockRecognitions = <Recognition>[
      const Recognition(
        id: '1',
        label: 'สิวหัวขาว',
        confidence: 0.35,
        x: 0.50,
        y: 0.21,
        width: 0.05,
        height: 0.06,
      ),
      const Recognition(
        id: '2',
        label: 'สิวหัวขาว',
        confidence: 0.37,
        x: 0.46,
        y: 0.30,
        width: 0.04,
        height: 0.05,
      ),
      const Recognition(
        id: '3',
        label: 'สิวหัวดำ',
        confidence: 0.34,
        x: 0.18,
        y: 0.34,
        width: 0.03,
        height: 0.04,
      ),
      const Recognition(
        id: '4',
        label: 'สิวหัวดำ',
        confidence: 0.49,
        x: 0.43,
        y: 0.73,
        width: 0.04,
        height: 0.05,
      ),
      const Recognition(
        id: '5',
        label: 'สิวหัวขาว',
        confidence: 0.26,
        x: 0.33,
        y: 0.05,
        width: 0.03,
        height: 0.04,
      ),
    ];

    return ResultScreen(
      imageBytes: imageBytes,
      recognitions: mockRecognitions,
    );
  }
}
