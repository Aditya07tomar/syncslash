import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/theme.dart';
import '../state/app_provider.dart';
import 'f1_core/dashboard_tab.dart';
import 'f1_core/virtual_cards_screen.dart';
import 'f2_social/split_screen.dart';
import 'f3_analytics/analytics_tab.dart';
import 'auth/login_screen.dart';

class MainScaffold extends StatefulWidget {
  @override
  _MainScaffoldState createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    DashboardTab(),
    const AnalyticsTab(),
    const VirtualCardsScreen(),
    const SplitScreen(),
  ];

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to sign out?', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: AppTheme.alertRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // Clear all stored credentials
      const storage = FlutterSecureStorage();
      await storage.deleteAll();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.sync_rounded, color: AppTheme.mintGreen, size: 24),
            const SizedBox(width: 8),
            const Text('SyncSlash', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              icon: CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.mintGreen.withOpacity(0.2),
                child: Text(
                  provider.userName.isNotEmpty ? provider.userName[0].toUpperCase() : 'U',
                  style: const TextStyle(color: AppTheme.mintGreen, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              color: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              offset: const Offset(0, 50),
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(provider.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('User ID: ${provider.currentUserId}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded, color: AppTheme.alertRed, size: 20),
                      const SizedBox(width: 10),
                      const Text('Logout', style: TextStyle(color: AppTheme.alertRed, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
              onSelected: (val) {
                if (val == 'logout') _logout();
              },
            ),
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.background,
          border: const Border(top: BorderSide(color: Colors.white12, width: 1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, -2)),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.background,
          selectedItemColor: AppTheme.mintGreen,
          unselectedItemColor: AppTheme.textSecondary,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.insert_chart_rounded), label: 'Analytics'),
            BottomNavigationBarItem(icon: Icon(Icons.credit_card_rounded), label: 'Cards'),
            BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Split'),
          ],
        ),
      ),
    );
  }
}