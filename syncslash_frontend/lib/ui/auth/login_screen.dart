import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../state/app_provider.dart';
import '../main_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _isGoogleInitialized = false;
  String? _errorMessage;
  String? _statusText;
  final storage = const FlutterSecureStorage();
  final ApiService _api = ApiService();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  static const String webClientId =
      "652174449722-sihsgdr8efdob8idg3p9sjdn4es0s5s8.apps.googleusercontent.com";

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initializeGoogleSignIn();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      await _googleSignIn.initialize(serverClientId: webClientId);
      if (mounted) setState(() => _isGoogleInitialized = true);
      debugPrint('✅ Google Sign-In initialized');
    } catch (e) {
      debugPrint("⚠️ Google Sign-In Init Error: $e");
    }
  }

  /// Google OAuth flow with correct v7.2.0 API
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusText = 'Opening Google Sign-In...';
    });

    try {
      if (!_isGoogleInitialized) {
        await _initializeGoogleSignIn();
      }

      // authenticate() returns GoogleSignInAccount (non-null), throws on cancel
      debugPrint('🔄 Calling authenticate()...');
      final GoogleSignInAccount account = await _googleSignIn.authenticate()
          .timeout(const Duration(seconds: 60), onTimeout: () {
        throw TimeoutException('Sign-in timed out. Please try again.');
      });

      debugPrint('✅ Got account: ${account.email}');
      if (mounted) setState(() => _statusText = 'Signed in as ${account.email}');

      // authentication is a SYNC getter in v7.x — no await needed
      final GoogleSignInAuthentication auth = account.authentication;
      final String? idToken = auth.idToken;

      debugPrint('🔑 idToken present: ${idToken != null}');

      if (idToken == null || idToken.isEmpty) {
        // No idToken — use direct login with Google email + name
        debugPrint('⚠️ No idToken — using direct login with email: ${account.email}');
        if (mounted) setState(() => _statusText = 'Logging in as ${account.displayName}...');
        await _directLoginWithGoogle(account);
        return;
      }

      // We have an idToken — try full backend verification
      if (mounted) setState(() => _statusText = 'Verifying with server...');

      try {
        final result = await _api.googleLogin(idToken);
        await _completeLogin(result, account.displayName);
      } catch (backendError) {
        // idToken verification failed — try direct login instead
        debugPrint('⚠️ Token verify failed: $backendError — trying direct login');
        if (mounted) setState(() => _statusText = 'Connecting with Google account...');
        await _directLoginWithGoogle(account);
      }
    } on GoogleSignInException catch (e) {
      debugPrint('❌ GoogleSignInException: ${e.code} - ${e.description}');
      if (mounted) {
        setState(() {
          if (e.code == GoogleSignInExceptionCode.canceled) {
            _errorMessage = 'Sign-in was cancelled';
          } else {
            _errorMessage = 'Google sign-in error: ${e.description ?? e.code.name}';
          }
          _statusText = null;
        });
      }
    } on TimeoutException catch (e) {
      debugPrint('❌ Timeout: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Sign-in timed out. Please try again.';
          _statusText = null;
        });
      }
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Sign-in failed: ${e.toString().replaceAll('Exception: ', '')}';
          _statusText = null;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Login via backend using Google email + name (no idToken needed)
  Future<void> _directLoginWithGoogle(GoogleSignInAccount account) async {
    try {
      final result = await _api.directLogin(
        account.email,
        account.displayName ?? account.email.split('@')[0],
      );
      await _completeLogin(result, account.displayName);
    } catch (e) {
      debugPrint('⚠️ Direct login failed: $e — falling back to dev mode');
      if (mounted) setState(() => _statusText = 'Server unavailable, using offline mode...');
      await _loginAsDev(name: account.displayName ?? account.email);
    }
  }

  /// Complete login with backend response (shared by both auth paths)
  Future<void> _completeLogin(Map<String, dynamic> result, String? displayName) async {
    final token = result['access_token'];
    final user = result['user'];
    final name = user['name'] ?? displayName ?? 'User';

    await storage.write(key: 'jwt_token', value: token);
    await storage.write(key: 'user_id', value: user['user_id'].toString());
    await storage.write(key: 'user_name', value: name);

    if (mounted) {
      Provider.of<AppProvider>(context, listen: false).setAuthData(
        user['user_id'],
        name,
        token,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainScaffold()),
      );
    }
  }

  /// Dev bypass login (offline only — no backend needed)
  Future<void> _loginAsDev({String name = 'Aditya'}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusText = 'Setting up dev mode...';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    await storage.write(key: 'jwt_token', value: 'debug_token_iiita_2024');
    await storage.write(key: 'user_id', value: '1');
    await storage.write(key: 'user_name', value: name);

    if (mounted) {
      Provider.of<AppProvider>(context, listen: false).setAuthData(
        1,
        name,
        'debug_token_iiita_2024',
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainScaffold()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppTheme.mintGreen.withOpacity(0.2), AppTheme.lavender.withOpacity(0.2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.insights_rounded, size: 80, color: AppTheme.mintGreen),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'SyncSlash',
              style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: -1),
            ),
            const SizedBox(height: 6),
            const Text(
              'SUBSCRIPTION FATIGUE OPTIMIZER',
              style: TextStyle(color: AppTheme.textSecondary, letterSpacing: 2.5, fontSize: 11, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(6)),
              child: const Text(
                'DBMS PROJECT • IIIT ALLAHABAD',
                style: TextStyle(color: AppTheme.textSecondary, letterSpacing: 1.5, fontSize: 10),
              ),
            ),
            const SizedBox(height: 60),

            // Error
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.alertRed.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.alertRed, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.alertRed, fontSize: 13))),
                  ],
                ),
              ),

            // Status
            if (_isLoading && _statusText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_statusText!, style: const TextStyle(color: AppTheme.mintGreen, fontSize: 13)),
              ),

            // Google Sign-In
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 3,
                ),
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                child: _isLoading
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.network('https://www.google.com/favicon.ico', width: 22, height: 22,
                            errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata_rounded, size: 28)),
                          const SizedBox(width: 12),
                          const Text('Sign in with Google', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Dev Mode
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.mintGreen,
                  side: BorderSide(color: AppTheme.mintGreen.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isLoading ? null : () => _loginAsDev(),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.developer_mode_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Dev Mode (Skip Auth)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('v1.0.0 — DBMS Mini Project', style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}