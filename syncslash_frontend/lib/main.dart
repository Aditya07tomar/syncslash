import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'core/theme.dart';
import 'state/app_provider.dart';
import 'ui/main_scaffold.dart';
import 'ui/auth/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppProvider())],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SyncSlash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppTheme.background,
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      home: const AuthGate(),
    );
  }
}

/// Checks SecureStorage for saved JWT on app start.
/// If found → go to dashboard. If not → login screen.
class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkExistingLogin();
  }

  Future<void> _checkExistingLogin() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'jwt_token');
    final userId = await storage.read(key: 'user_id');
    final userName = await storage.read(key: 'user_name');

    if (token != null && userId != null && mounted) {
      // Restore session from saved credentials
      Provider.of<AppProvider>(context, listen: false).setAuthData(
        int.tryParse(userId) ?? 1,
        userName ?? 'User',
        token,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainScaffold()),
      );
    } else {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sync_rounded, color: AppTheme.mintGreen, size: 48),
              const SizedBox(height: 16),
              const Text('SyncSlash', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: AppTheme.mintGreen),
            ],
          ),
        ),
      );
    }
    return LoginScreen();
  }
}