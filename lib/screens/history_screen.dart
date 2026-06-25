import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'compare_screen.dart';
import 'history_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool selectionMode = false;
  final List<String> selectedIds = [];
  bool _isClearingAll = false; 

  void _toggleSelection(String id) {
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
      } else {
        if (selectedIds.length < 2) {
          selectedIds.add(id);
        }
      }
    });
  }

  Future<void> _deleteItem(String uid, String docId, Map<String, dynamic> data) async {
    final imagePath = (data['imagePath'] ?? '').toString();
    if (imagePath.isNotEmpty) {
      try {
        await FirebaseStorage.instance.ref().child(imagePath).delete();
      } catch (_) {}
    }
    await FirebaseFirestore.instance.collection('users').doc(uid).collection('history').doc(docId).delete();
  }

  Future<bool> _showDeleteDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('ลบประวัติรายการนี้?'),
        content: const Text('ถ้าลบแล้วจะเรียกคืนไม่ได้นะ'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ลบ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showClearAllDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28), SizedBox(width: 10), Text('ล้างประวัติทั้งหมด?')]),
        content: const Text('คุณแน่ใจหรือไม่ว่าต้องการลบประวัติการสแกน "ทั้งหมด"?\n\n⚠️ การกระทำนี้ไม่สามารถย้อนกลับได้', style: TextStyle(height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบทิ้งทั้งหมด', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == true) {
      await _clearAllHistory();
    }
  }

  // 🚨 ระบบลบทั้งหมดแบบรวดเดียวด้วย Batch 
  Future<void> _clearAllHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isClearingAll = true);

    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('history').get();
      final batch = FirebaseFirestore.instance.batch();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final imagePath = (data['imagePath'] ?? '').toString();
        if (imagePath.isNotEmpty) {
          try {
            await FirebaseStorage.instance.ref().child(imagePath).delete();
          } catch (_) {}
        }
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [Icon(Icons.check_circle_outline, color: Colors.white), SizedBox(width: 10), Text('ล้างประวัติทั้งหมดเรียบร้อยแล้ว ✨')]),
          behavior: SnackBarBehavior.floating, backgroundColor: Colors.green.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _isClearingAll = false;
          selectionMode = false;
          selectedIds.clear();
        });
      }
    }
  }

  Widget _buildImage(String url, String base64Img) {
    if (url.isNotEmpty) {
      return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(url, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image_outlined))));
    }
    if (base64Img.isNotEmpty) {
      try {
        return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(base64Decode(base64Img), fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image_outlined))));
      } catch (_) {
        return Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image_outlined));
      }
    }
    return Container(decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.image_not_supported));
  }

  String _formatConfidence(dynamic confidence) {
    final value = (confidence is num) ? confidence.toDouble() : 0.0;
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0, backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
        title: Text(selectionMode ? 'Select 2 items' : 'Scan History', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (!selectionMode)
            IconButton(tooltip: 'ล้างประวัติทั้งหมด', icon: const Icon(Icons.delete_sweep_rounded), onPressed: _showClearAllDialog),
          IconButton(
            tooltip: selectionMode ? 'ปิดโหมดเปรียบเทียบ' : 'เปรียบเทียบ',
            icon: Icon(selectionMode ? Icons.close_rounded : Icons.compare),
            onPressed: () => setState(() { selectionMode = !selectionMode; selectedIds.clear(); }),
          ),
        ],
      ),
      body: Stack(
        children: [
          user == null ? const Center(child: Text('Login first', style: TextStyle(fontSize: 16)))
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('history').orderBy('timestamp', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (snapshot.hasError) return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดประวัติ'));
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 72, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text('ยังไม่มีประวัติการสแกน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                            const SizedBox(height: 6),
                            Text('ลองสแกนรูปก่อน แล้วประวัติจะมาอยู่ตรงนี้', style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      );
                    }
                    final docs = snapshot.data!.docs;
                    return Column(
                      children: [
                        if (selectionMode)
                          Container(
                            width: double.infinity, margin: const EdgeInsets.fromLTRB(12, 12, 12, 6), padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                            child: Column(
                              children: [
                                Text(selectedIds.length < 2 ? 'เลือกให้ครบ 2 รูปเพื่อเปรียบเทียบ' : 'พร้อมเปรียบเทียบแล้ว', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, disabledBackgroundColor: Colors.grey.shade300, disabledForegroundColor: Colors.grey.shade600, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                    onPressed: selectedIds.length == 2 ? () {
                                            final selectedDocs = docs.where((d) => selectedIds.contains(d.id)).toList();
                                            if (selectedDocs.length == 2) {
                                              Navigator.push(context, MaterialPageRoute(builder: (_) => CompareScreen(latestData: selectedDocs[0].data() as Map<String, dynamic>, previousData: selectedDocs[1].data() as Map<String, dynamic>)));
                                            }
                                          } : null,
                                    icon: const Icon(Icons.compare_arrows_rounded), label: Text(selectedIds.length < 2 ? 'เลือกให้ครบ 2 รูป' : 'Compare'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final selected = selectedIds.contains(doc.id);
                              final diagnosis = (data['diagnosis'] ?? 'Unknown').toString();
                              return Dismissible(
                                key: Key(doc.id), direction: selectionMode ? DismissDirection.none : DismissDirection.endToStart,
                                confirmDismiss: (_) async => await _showDeleteDialog(),
                                onDismissed: (_) async {
                                  try {
                                    await _deleteItem(user.uid, doc.id, data);
                                    if (selectedIds.contains(doc.id)) setState(() => selectedIds.remove(doc.id));
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('ลบรายการแล้ว'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบไม่สำเร็จ: $e'), backgroundColor: Colors.red));
                                  }
                                },
                                background: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), padding: const EdgeInsets.symmetric(horizontal: 20),
                                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFE53935)]), borderRadius: BorderRadius.circular(20)),
                                  alignment: Alignment.centerRight,
                                  child: const Row(mainAxisAlignment: MainAxisAlignment.end, children: [Icon(Icons.delete_rounded, color: Colors.white, size: 28), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))]),
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180), margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                  decoration: BoxDecoration(color: selected ? AppTheme.primaryColor.withOpacity(0.12) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? AppTheme.primaryColor : Colors.transparent, width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 5))]),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: selectionMode ? () => _toggleSelection(doc.id) : () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryDetailScreen(data: data))),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            Container(width: 84, height: 84, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.grey.shade100), clipBehavior: Clip.antiAlias, child: _buildImage((data['imageUrl'] ?? '').toString(), (data['imageBase64'] ?? '').toString())),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(diagnosis, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                                  const SizedBox(height: 6),
                                                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(999)), child: Text('Conf: ${_formatConfidence(data['confidence'])}', style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.w600))),
                                                  const SizedBox(height: 8),
                                                  if (data['timestamp'] != null && data['timestamp'] is Timestamp) ...[
                                                    Text((data['timestamp'] as Timestamp).toDate().toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (selectionMode) Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked, color: selected ? AppTheme.primaryColor : Colors.grey, size: 28)
                                            else Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
          if (_isClearingAll)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('กำลังล้างประวัติทั้งหมด...', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}