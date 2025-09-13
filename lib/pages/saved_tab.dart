import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _host = 'https://weerispost.online';
const _productsApi = '$_host/api/products.php'; // ✅ products endpoint
const _ordersApi   = '$_host/api/orders.php';   // ✅ orders endpoint

class SavedTab extends StatefulWidget {
  final bool active;                       // ✅ รับสถานะ active เข้ามา
  const SavedTab({super.key, this.active = false});

  @override
  State<SavedTab> createState() => _SavedTabState();
}

class _SavedTabState extends State<SavedTab> {
  bool _loading = true;
  List<ProductRow> _items = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();                       // โหลดครั้งแรก
  }

  @override
  void didUpdateWidget(covariant SavedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ เมื่อสลับมาหน้านี้ (active เปลี่ยนจาก false -> true) ให้รีโหลดทันที
    if (widget.active && !oldWidget.active) {
      _loadProducts();
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse(_productsApi).replace(queryParameters: {
        'limit': '50',
        'offset': '0',
      });
      final r = await http.get(uri).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final arr = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      _items = arr.map(ProductRow.fromJson).toList();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดสินค้าไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  void _openHistory(ProductRow p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => _CenteredSheet(
        maxWidth: 520,
        heightFactor: 0.55,
        child: _HistorySheet(code: _digitsOnly(p.code), name: p.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const Center(child: Text('ยังไม่มีสินค้าในคลัง'));

    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
  final p = _items[i];

  return Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: (p.image == null || p.image!.isEmpty)
              ? const Icon(Icons.inventory_2, size: 48)
              : Image.network(
                  p.image!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, size: 48),
                ),
        ),
        title: Text(
          p.name.isEmpty ? '(ไม่มีชื่อสินค้า)' : p.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            'รหัส: ${p.code}',
            'สต๊อก: ${p.stock}',          // ← ใช้ p.stock โดยตรง
            'ราคา: ${_fmtPrice(p.price)}',
            'อัปเดตล่าสุด: ${_fmtDate(p.updatedAt)}',
          ].join('\n'),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: SizedBox(
          height: 44,
          child: IconButton(
            icon: const Icon(Icons.history, color: Colors.blue),
            tooltip: 'ดูประวัติ 7 วัน',
            onPressed: () => _openHistory(p),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ),
      ),
    ),
  );
},
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _fmtPrice(double v) {
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }
}

/// ===== การ์ดชีตกึ่งกลางจอ =====
class _CenteredSheet extends StatelessWidget {
  final Widget child;
  final double heightFactor; // 0.0 - 1.0
  final double maxWidth;
  const _CenteredSheet({
    required this.child,
    this.heightFactor = 0.6,
    this.maxWidth = 600,
  });

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * heightFactor;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: h),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 12,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// ===== Model =====
class ProductRow {
  final String code;
  final String name;
  final double price;
  final int stock;
  final String? image;
  final DateTime updatedAt;

  ProductRow({
    required this.code,
    required this.name,
    required this.price,
    required this.stock,
    required this.image,
    required this.updatedAt,
  });

  factory ProductRow.fromJson(Map<String, dynamic> j) => ProductRow(
        code: (j['code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        price: double.tryParse(j['price']?.toString() ?? '') ?? 0.0,
        stock: int.tryParse(j['stock']?.toString() ?? '') ?? 0,
        image: ((j['image']?.toString() ?? '').isEmpty) ? null : j['image'].toString(),
        updatedAt: _parseMysqlDateTime(
          (j['updated_at'] ?? j['created_at'] ?? DateTime.now().toString()).toString(),
        ),
      );
}

DateTime _parseMysqlDateTime(String s) {
  final normalized = s.contains('T') ? s : s.replaceFirst(' ', 'T');
  return DateTime.tryParse(normalized) ?? DateTime.now();
}

/// ===== History sheet =====
class _HistorySheet extends StatelessWidget {
  final String code;
  final String name;
  const _HistorySheet({required this.code, required this.name});

  Future<List<_HistoryEntry>> _fetch() async {
    final r = await http
        .get(Uri.parse(_ordersApi).replace(queryParameters: {
          'history': code,
          'days': '7',
        }))
        .timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final data = jsonDecode(r.body);
    if (data['ok'] != true) throw Exception(data['error'] ?? 'load fail');
    final arr = (data['history'] as List).cast<Map<String, dynamic>>();
    return arr.map(_HistoryEntry.fromJson).toList();
  }

  String _fmt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              const Icon(Icons.history),
              const SizedBox(width: 8),
              Expanded(
                child: Text('ประวัติ 7 วัน: $name ($code)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                tooltip: 'ปิด',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<_HistoryEntry>>(
            future: _fetch(),
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('ผิดพลาด: ${snap.error}'),
                  ),
                );
              }
              final list = snap.data ?? const <_HistoryEntry>[];
              if (list.isEmpty) {
                return const Center(child: Text('ไม่พบประวัติในช่วง 7 วัน'));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final h = list[i];
                  final dir = h.direction == 'in' ? 'เพิ่มสต๊อก' : 'ลบสต๊อก';
                  return ListTile(
                    leading: Icon(h.direction == 'in' ? Icons.upload : Icons.download),
                    title: Text('$dir | ${h.qty} ชิ้น (฿${h.price})'),
                    subtitle: Text('เมื่อ: ${_fmt(h.at)}'),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryEntry {
  final int qty;
  final double price;
  final String direction; // 'in' | 'out'
  final DateTime at;

  _HistoryEntry({
    required this.qty,
    required this.price,
    required this.direction,
    required this.at,
  });

  factory _HistoryEntry.fromJson(Map<String, dynamic> j) => _HistoryEntry(
        qty: int.tryParse(j['qty']?.toString() ?? '') ?? 0,
        price: double.tryParse(j['price']?.toString() ?? '') ?? 0.0,
        direction: (j['direction'] as String?) ?? 'in',
        at: _parseMysqlDateTime(j['at']?.toString() ?? DateTime.now().toString()),
      );
}
