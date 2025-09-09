import 'package:flutter/material.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // โลโก้หรือไอคอนหลัก
                const FlutterLogo(size: 100),
                const SizedBox(height: 24),

                // ข้อความทักทาย
                const Text(
                  'ยินดีต้อนรับสู่ระบบจัดการสินค้า',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'คุณสามารถสแกนบาร์โค้ดเพื่อเพิ่มสินค้า\n'
                  'ดูรายการสินค้าที่บันทึกไว้ หรือจัดการสต๊อกของคุณ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
