import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import './pages/Home_page.dart';

const baseApi = 'https://www.weerispost.online/api/api-login-register.php';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    themeMode: ThemeMode.light,
    darkTheme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF000000),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF111214),
        border: OutlineInputBorder(),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    ),
    home: const LoginPage(),
    routes: {
      '/home': (_) => const Home_page(), // ✅ ไปหน้า Home_page
    },
  ),
);

/// ---------------- API ----------------
Future<void> apiRegister(String username, String email, String password) async {
  final resp = await http
      .post(
        Uri.parse('$baseApi?action=register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      )
      .timeout(const Duration(seconds: 20));

  if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
  final data = jsonDecode(resp.body) as Map<String, dynamic>;
  if (data['ok'] != true) throw Exception(data['error'] ?? 'Register failed');
}

Future<(String token, int userId)> apiLogin(
  String identity,
  String password,
) async {
  final key = identity.contains('@') ? 'email' : 'username';
  final resp = await http
      .post(
        Uri.parse('$baseApi?action=login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({key: identity, 'password': password}),
      )
      .timeout(const Duration(seconds: 20));

  if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
  final data = jsonDecode(resp.body) as Map<String, dynamic>;
  if (data['ok'] == true && data['token'] != null) {
    return (data['token'] as String, (data['userId'] as num).toInt());
  }
  throw Exception(data['error'] ?? 'Invalid credentials');
}

/// ---------------- LOGIN PAGE ----------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identity = TextEditingController(); // email or username
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _identity.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final (token, userId) = await apiLogin(
        _identity.text.trim(),
        _password.text,
      );
      if (!mounted) return;

      //  ล็อกอินสำเร็จ -> ไปหน้า Home_page และล้างสแตก
      final identity = _identity.text.trim();
      // ถ้าเป็นอีเมล ใช้ส่วนหน้าก่อน @ เป็นชื่อ, ถ้าเป็นยูสเซอร์ก็ใช้ตรง ๆ
      final displayName = identity.contains('@')
          ? identity.split('@').first
          : identity;

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
        arguments: {'name': displayName}, // ✅ ส่งชื่อไปหน้า Home
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เข้าสู่ระบบไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goRegister() async {
    final email = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const RegisterPage()));
    if (email != null && email.isNotEmpty) {
      _identity.text = email;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('สมัครสมาชิกสำเร็จ — ลองล็อกอินเลย')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FlutterLogo(size: 96),
                  const SizedBox(height: 16),
                  const Text(
                    'Welcome My Application Weeris',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _identity,
                          decoration: const InputDecoration(
                            labelText: 'อีเมลหรือยูสเซอร์เนม',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'กรอกอีเมลหรือยูสเซอร์เนม'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'รหัสผ่าน',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'กรอกรหัสผ่าน'
                              : (v.length < 6 ? 'อย่างน้อย 6 ตัวอักษร' : null),
                          onFieldSubmitted: (_) => _doLogin(),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _doLogin,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: const Text('เข้าสู่ระบบ'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _loading ? null : _goRegister,
                    child: const Text('ยังไม่มีบัญชี? สมัครสมาชิก'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------- REGISTER PAGE ----------------
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _doRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('รหัสผ่านไม่ตรงกัน')));
      return;
    }
    setState(() => _loading = true);
    try {
      await apiRegister(
        _username.text.trim(),
        _email.text.trim(),
        _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop<String>(_email.text.trim());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('สมัครไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('สมัครสมาชิก'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  const FlutterLogo(size: 72),
                  const SizedBox(height: 16),
                  const Text(
                    'สร้างบัญชีใหม่',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _username,
                          decoration: const InputDecoration(
                            labelText: 'ยูสเซอร์เนม',
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'กรอกยูสเซอร์เนม'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _email,
                          decoration: const InputDecoration(
                            labelText: 'อีเมล',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) {
                            final s = v?.trim() ?? '';
                            if (s.isEmpty) return 'กรอกอีเมล';
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(s))
                              return 'รูปแบบอีเมลไม่ถูกต้อง';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'รหัสผ่าน (อย่างน้อย 6 ตัว)',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (v) => (v == null || v.length < 6)
                              ? 'อย่างน้อย 6 ตัวอักษร'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirm,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'ยืนยันรหัสผ่าน',
                            prefixIcon: Icon(Icons.lock_person_outlined),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'กรอกยืนยันรหัสผ่าน'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _doRegister,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.person_add_alt_1),
                            label: const Text('สมัครสมาชิก'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
