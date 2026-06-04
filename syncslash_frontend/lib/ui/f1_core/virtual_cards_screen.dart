import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../state/app_provider.dart';

class VirtualCardsScreen extends StatefulWidget {
  const VirtualCardsScreen({super.key});

  @override
  State<VirtualCardsScreen> createState() => _VirtualCardsScreenState();
}

class _VirtualCardsScreenState extends State<VirtualCardsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppProvider>(context, listen: false).loadVirtualCards();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.background,
            elevation: 0,
            title: const Text('Virtual Cards', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
                onPressed: () => provider.loadVirtualCards(),
              ),
            ],
          ),
          body: provider.isCardsLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppTheme.mintGreen),
                      SizedBox(height: 16),
                      Text('Loading cards...', style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : provider.virtualCards.isEmpty
                  ? _buildEmptyState(provider)
                  : _buildCardsList(context, provider),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppTheme.mintGreen,
            foregroundColor: Colors.black,
            icon: const Icon(Icons.add_card_rounded),
            label: const Text('New Card', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _showCreateCardDialog(context, provider),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(AppProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card_off_rounded, color: AppTheme.textSecondary.withOpacity(0.4), size: 70),
          const SizedBox(height: 16),
          const Text('No virtual cards yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 17)),
          const SizedBox(height: 6),
          const Text('Create one to manage subscription payments', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCardsList(BuildContext context, AppProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: provider.virtualCards.length,
      itemBuilder: (context, index) {
        final card = provider.virtualCards[index];
        return _buildCardWidget(context, card, provider);
      },
    );
  }

  Widget _buildCardWidget(BuildContext context, Map<String, dynamic> card, AppProvider provider) {
    final isFrozen = card['status'] == 'frozen';
    final serviceName = card['service_name'] ?? 'Unknown';
    final cardNumber = card['card_number'] ?? '****';
    final cost = card['detected_cost'];
    final cardId = card['card_id'];

    Color statusColor = isFrozen ? AppTheme.alertRed : AppTheme.mintGreen;
    Color brandColor = AppTheme.getBrandColor(serviceName);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            brandColor.withOpacity(0.2),
            AppTheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: brandColor.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: brandColor.withOpacity(0.3),
                  child: Icon(isFrozen ? Icons.lock_rounded : Icons.credit_card_rounded, color: brandColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(serviceName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(cardNumber, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, letterSpacing: 1)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isFrozen ? Icons.ac_unit_rounded : Icons.check_circle_rounded, color: statusColor, size: 14),
                      const SizedBox(width: 4),
                      Text(isFrozen ? 'FROZEN' : 'ACTIVE', style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (cost != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.currency_rupee_rounded, color: AppTheme.textSecondary, size: 14),
                  Text('$cost/mo', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ),

          // Action buttons
          const Divider(color: Colors.white10, height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                // Freeze / Resume
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: isFrozen ? AppTheme.mintGreen : AppTheme.pastelYellow,
                    ),
                    icon: Icon(isFrozen ? Icons.play_arrow_rounded : Icons.ac_unit_rounded, size: 18),
                    label: Text(isFrozen ? 'Resume' : 'Freeze', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    onPressed: () async {
                      bool success;
                      if (isFrozen) {
                        success = await provider.unfreezeCard(cardId);
                      } else {
                        success = await provider.freezeCard(cardId);
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(success
                              ? (isFrozen ? '✅ Card resumed' : '🔒 Card frozen')
                              : 'Action failed'),
                          backgroundColor: success ? AppTheme.mintGreen : AppTheme.alertRed,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                      }
                    },
                  ),
                ),
                Container(width: 1, height: 24, color: Colors.white10),
                // Cancel
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppTheme.alertRed),
                    icon: const Icon(Icons.cancel_rounded, size: 18),
                    label: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    onPressed: () => _confirmCancel(context, cardId, serviceName, provider),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context, int cardId, String name, AppProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Card?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will permanently delete the virtual card for $name. This action cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed, foregroundColor: Colors.black),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.cancelCard(cardId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success ? 'Card cancelled' : 'Failed to cancel'),
                  backgroundColor: success ? AppTheme.mintGreen : AppTheme.alertRed,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ));
              }
            },
            child: const Text('Cancel Card', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCreateCardDialog(BuildContext context, AppProvider provider) {
    final activeSubs = provider.subscriptions.where((s) => s['status'] == 'active').toList();

    if (activeSubs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No active subscriptions to link a card to'),
        backgroundColor: AppTheme.alertRed,
      ));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('Create Virtual Card', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Select a subscription to link:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              ...activeSubs.take(6).map<Widget>((sub) {
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: AppTheme.background,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.getBrandColor(sub['service_name']).withOpacity(0.3),
                    child: const Icon(Icons.subscriptions_rounded, color: Colors.white70, size: 16),
                  ),
                  title: Text(sub['service_name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15)),
                  subtitle: Text('₹${sub['detected_cost']}/mo', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  trailing: const Icon(Icons.add_card_rounded, color: AppTheme.mintGreen, size: 22),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final success = await provider.createVirtualCard(sub['sub_id']);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(success ? 'Card created!' : 'Failed'),
                        backgroundColor: success ? AppTheme.mintGreen : AppTheme.alertRed,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ));
                    }
                  },
                );
              }),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}
