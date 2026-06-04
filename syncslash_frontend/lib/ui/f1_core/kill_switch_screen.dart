import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../state/app_provider.dart';

class KillSwitchScreen extends StatefulWidget {
  final dynamic subscription;

  const KillSwitchScreen({Key? key, required this.subscription}) : super(key: key);

  @override
  State<KillSwitchScreen> createState() => _KillSwitchScreenState();
}

class _KillSwitchScreenState extends State<KillSwitchScreen> {
  bool _isProcessing = false;
  late Map<String, dynamic> _sub;

  @override
  void initState() {
    super.initState();
    // Make a mutable copy so we can update status locally after API call
    _sub = Map<String, dynamic>.from(widget.subscription);
  }

  @override
  Widget build(BuildContext context) {
    Color brandColor = AppTheme.getBrandColor(_sub['service_name']);
    bool isFrozen = _sub['status'] == 'frozen';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Service icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [brandColor.withOpacity(0.6), brandColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CircleAvatar(radius: 38, backgroundColor: brandColor, child: Icon(isFrozen ? Icons.lock_rounded : Icons.subscriptions_rounded, size: 38, color: Colors.black87)),
            ),
            const SizedBox(height: 20),
            Text(_sub['service_name'], style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'Next Renewal: ${_sub['days_until_renewal'] ?? '?'} days',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 30),

            // Info cards row
            Row(
              children: [
                _infoCard('Cost', '₹${_sub['detected_cost'] ?? 0}/mo', AppTheme.pastelYellow),
                const SizedBox(width: 12),
                _infoCard('Status', isFrozen ? 'Frozen' : 'Active', isFrozen ? AppTheme.alertRed : AppTheme.mintGreen),
                const SizedBox(width: 12),
                _infoCard('Detection', _sub['detected_by_b1'] == true ? 'B1 Engine' : 'Manual', AppTheme.pastelBlue),
              ],
            ),
            const SizedBox(height: 24),

            // Category info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.category_rounded, color: AppTheme.lavender, size: 20),
                      const SizedBox(width: 10),
                      Text('Category: ${_sub['category'] ?? 'Unknown'}', style: const TextStyle(color: AppTheme.lavender, fontSize: 15, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.credit_card_rounded, color: AppTheme.textSecondary, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _sub['virtual_card_id'] != null ? 'Virtual card linked' : 'No virtual card',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Kill switch / Resume buttons
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: CircularProgressIndicator(color: AppTheme.mintGreen),
              )
            else ...[
              // Freeze button (when active)
              if (!isFrozen)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.alertRed,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.ac_unit_rounded),
                    label: const Text('FREEZE SUBSCRIPTION', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    onPressed: () => _handleAction(context, freeze: true),
                  ),
                ),

              // Resume button (when frozen)
              if (isFrozen) ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.mintGreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('RESUME SUBSCRIPTION', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    onPressed: () => _handleAction(context, freeze: false),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.alertRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.ac_unit_rounded, color: AppTheme.alertRed, size: 16),
                      SizedBox(width: 8),
                      Text('CURRENTLY FROZEN — PAYMENTS BLOCKED', style: TextStyle(color: AppTheme.alertRed, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Actually calls the backend API to freeze/unfreeze via subscription status update
  void _handleAction(BuildContext context, {required bool freeze}) async {
    setState(() => _isProcessing = true);

    final provider = Provider.of<AppProvider>(context, listen: false);
    final api = ApiService();
    bool success = false;

    try {
      final subId = _sub['sub_id'];
      final cardId = _sub['virtual_card_id'];

      if (cardId != null) {
        // Has a linked virtual card — freeze/unfreeze it via B3 API
        if (freeze) {
          success = await provider.freezeCard(cardId);
        } else {
          success = await provider.unfreezeCard(cardId);
        }
      } else {
        // No virtual card — directly update subscription status via backend
        if (freeze) {
          await api.freezeSubscription(provider.currentUserId, subId);
        } else {
          await api.unfreezeSubscription(provider.currentUserId, subId);
        }
        // Refresh dashboard data
        await provider.loadInitialData();
        success = true;
      }

      // Update local state
      if (success) {
        setState(() {
          _sub['status'] = freeze ? 'frozen' : 'active';
        });
      }
    } catch (e) {
      debugPrint('Kill switch error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          success
            ? (freeze ? '🔒 Subscription frozen — payments blocked!' : '✅ Subscription resumed — payments enabled!')
            : 'Action failed. Try again.',
        ),
        backgroundColor: success ? (freeze ? AppTheme.alertRed : AppTheme.mintGreen) : AppTheme.alertRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      if (success) Navigator.pop(context);
    }
  }

  Widget _infoCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}