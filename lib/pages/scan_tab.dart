import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/services.dart';

const baseApi =
    'https://www.weerispost.online/api/api-app-mobile.php'; // item_save, product_get
const uploadApi =
    'https://weerispost.online/api/upload.php'; // รับ multipart -> {ok,url}
const productApi =
    'https://weerispost.online/api/products.php'; // upsert image ให้สินค้า

class ScanTab extends StatefulWidget {
  final bool active;
  const ScanTab({super.key, required this.active});

  @override
  State<ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<ScanTab> {
  final MobileScannerController _controller = MobileScannerController();
  bool _lock = false;

  final codeCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController();

  DateTime? _scannedAt; // เวลาแสกนล่าสุด
  String? _imageUrl; // URL หลังอัปโหลดแล้ว
  bool _uploading = false; // สถานะระหว่างอัปโหลด

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.start();
  }

  @override
  void didUpdateWidget(covariant ScanTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.start();
    } else if (!widget.active && oldWidget.active) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    codeCtrl.dispose();
    nameCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  void _onDetect(BarcodeCapture cap) async {
    if (_lock) return;
    final code = cap.barcodes
        .map((b) => b.rawValue ?? '')
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    if (code.isEmpty) return;

    _lock = true;
    codeCtrl.text = code;
    _scannedAt = DateTime.now();
    setState(() {});

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('สแกนได้: $code')));

    try {
      final r = await http
          .get(Uri.parse('$baseApi?action=product_get&code=$code'))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data['ok'] == true && data['product'] != null) {
          final p = data['product'] as Map<String, dynamic>;
          nameCtrl.text = (p['name'] ?? '') as String;
          final price = (p['price'] as num?)?.toDouble();
          if (price != null) priceCtrl.text = price.toStringAsFixed(2);
          _imageUrl = (p['image'] as String?)?.isNotEmpty == true
              ? p['image'] as String
              : null;
          setState(() {});
        }
      }
    } catch (_) {
      // ignore
    } finally {
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) _lock = false;
    }
  }

  /// เลือกรูป -> บีบอัด -> อัปโหลด -> ได้ URL กลับมา
  Future<void> _pickAndUpload() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (x == null) return;

      setState(() => _uploading = true);

      final raw = await x.readAsBytes();
      Uint8List? compressed = await FlutterImageCompress.compressWithList(
        raw,
        minWidth: 900,
        minHeight: 900,
        quality: 70,
        format: _inferFormat(x.name),
      );
      compressed ??= raw;

      final req = http.MultipartRequest('POST', Uri.parse(uploadApi));
      req.files.add(
        http.MultipartFile.fromBytes(
          'file',
          compressed,
          filename: _suggestFileName(x.name),
        ),
      );
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode != 200) {
        throw Exception('HTTP ${streamed.statusCode}: $body');
      }
      final data = jsonDecode(body);
      if (data['ok'] != true) throw Exception(data['error'] ?? 'upload failed');

      _imageUrl = data['url'] as String;
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('อัปโหลดรูปสำเร็จ')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('อัปโหลดรูปไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _saveItem() async {
    final code = codeCtrl.text.trim();
    final name = nameCtrl.text.trim();
    final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
    final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;

    if (code.isEmpty || name.isEmpty || qty <= 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรอกข้อมูลให้ครบและถูกต้อง')),
      );
      return;
    }

    final when = _scannedAt ?? DateTime.now();
    final body = {
      'code': code,
      'name': name,
      'qty': qty,
      'price': price,
      'updated_at': _fmt(when),
    };

    try {
      // 1) บันทึกแถวรายการ
      final resp = await http
          .post(
            Uri.parse('$baseApi?action=item_save'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      final data = jsonDecode(resp.body);
      if (!(resp.statusCode == 200 && data['ok'] == true)) {
        throw Exception(data['error'] ?? 'unknown');
      }

      // 2) ถ้ามีอัปโหลดรูปไว้แล้ว -> ผูกให้สินค้าผ่าน products.php (upsert)
      if (_imageUrl != null && _imageUrl!.isNotEmpty) {
        await http.post(
          Uri.parse(productApi),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'code': code,
            'name': name,
            'price': price, // ต้องส่งค่าครบตาม schema
            'stock': 0, // ไม่ปรับสต๊อกที่นี่
            'image': _imageUrl,
          }),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกสำเร็จ (order #${data['orderId']})')),
      );
      qtyCtrl.text = '1';
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: AbsorbPointer(
            absorbing: !widget.active,
            child: Stack(
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withOpacity(0.8),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Row(
                    children: [
                      IconButton.filled(
                        onPressed: () => _controller.toggleTorch(),
                        icon: const Icon(Icons.flash_on),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () => _controller.switchCamera(),
                        icon: const Icon(Icons.cameraswitch),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: codeCtrl,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'บาร์โค้ด',
            prefixIcon: Icon(Icons.qr_code_2),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'ชื่อสินค้า',
            prefixIcon: Icon(Icons.inventory_2_outlined),
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter
                      .digitsOnly, // ✅ อนุญาตเฉพาะตัวเลข (จำนวนเต็ม)
                ],
                decoration: const InputDecoration(
                  labelText: 'จำนวน',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  // ✅ อนุญาตตัวเลข + จุดทศนิยมสูงสุด 2 หลัก
                ],
                decoration: const InputDecoration(
                  labelText: 'ราคา/หน่วย',
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // วันที่อ่านอย่างเดียว
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'วันที่อัปเดต',
            prefixIcon: Icon(Icons.event),
            border: OutlineInputBorder(),
          ),
          child: Text(
            _fmt(_scannedAt ?? DateTime.now()),
            style: const TextStyle(fontSize: 16),
          ),
        ),

        const SizedBox(height: 12),

        // พรีวิว + ปุ่มอัปโหลดรูป
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 72,
                height: 72,
                color: Colors.grey.withOpacity(0.15),
                child: _uploading
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (_imageUrl == null
                          ? const Icon(Icons.image, size: 32)
                          : Image.network(_imageUrl!, fit: BoxFit.cover)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _uploading ? null : _pickAndUpload,
                icon: const Icon(Icons.upload),
                label: const Text('เลือกรูป/อัปโหลด'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: _saveItem,
            icon: const Icon(Icons.save),
            label: const Text('บันทึกลงฐานข้อมูล'),
          ),
        ),
      ],
    );
  }
}

/* ---------- helpers for compression ---------- */
CompressFormat _inferFormat(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return CompressFormat.png;
  if (lower.endsWith('.webp')) return CompressFormat.webp;
  return CompressFormat.jpeg;
}

String _suggestFileName(String original) {
  final ts = DateTime.now().millisecondsSinceEpoch;
  final lower = original.toLowerCase();
  if (lower.endsWith('.png')) return 'scan_$ts.png';
  if (lower.endsWith('.webp')) return 'scan_$ts.webp';
  return 'scan_$ts.jpg';
}
