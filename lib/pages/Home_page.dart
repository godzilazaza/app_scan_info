import 'package:flutter/material.dart';
import 'home_tab.dart';
import 'scan_tab.dart';
import 'saved_tab.dart';

class Home_page extends StatefulWidget {
  const Home_page({super.key});
  @override
  State<Home_page> createState() => _Home_pageState();
}

class _Home_pageState extends State<Home_page> {
  int _index = 0;
  String _displayName = 'User';

  // ถ้าส่งชื่อมาจากหน้า Login ผ่าน arguments: {'name': ...}
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['name'] is String && (args['name'] as String).trim().isNotEmpty) {
      _displayName = (args['name'] as String).trim();
    }
  }

  String get _initial => _displayName.isNotEmpty ? _displayName.characters.first.toUpperCase() : '?';

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ออกจากระบบ'),
        content: const Text('ต้องการออกจากระบบใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ออกจากระบบ')),
        ],
      ),
    );
    if (ok == true && mounted) {
      // TODO: ถ้าเก็บ token ไว้ใน SharedPreferences ให้ล้างที่นี่ก่อน
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['หน้าหลัก', 'สแกน', 'บันทึกแล้ว'];

    return Scaffold(
      // AppBar อยู่ทุกหน้า + ปุ่ม logout
      appBar: AppBar(
  titleSpacing: 0,
  title: Row(
    children: [
      InkWell(
        onTap: () {
          setState(() => _index = 0); // ✅ กดแล้วกลับไปหน้าแรก
        },
        borderRadius: BorderRadius.circular(20),
        child: CircleAvatar(radius: 30, child: Text(_initial)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          _displayName,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  ),
  actions: [
    IconButton(
      tooltip: 'ออกจากระบบ',
      onPressed: _logout,
      icon: const Icon(Icons.logout),
    ),
  ],
),


      // เนื้อหาแต่ละเมนู (อย่าให้แท็บสร้าง Scaffold เอง)
      body: IndexedStack(
        index: _index,
        children: [
          const HomeTab(),
          ScanTab(active: _index == 1), // ส่ง active เพื่อ start/stop กล้อง
          SavedTab(active: _index == 2), 
          const SavedTab(),
        ],
      ),

      // Bottom Nav อยู่ทุกหน้า
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'หน้าหลัก'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner), selectedIcon: Icon(Icons.qr_code), label: 'สแกน'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'บันทึกแล้ว'),
        ],
      ),
    );
  }
}
