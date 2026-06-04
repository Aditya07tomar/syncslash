import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../state/app_provider.dart';

class GroupDetailScreen extends StatefulWidget {
  final Map<String, dynamic> group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    // Auto-fetch optimized settlement on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final groupId = widget.group['group_id'];
      if (groupId != null) {
        provider.optimizeGroupSettlement(groupId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.group['name'] ?? 'Group';
    final inviteCode = widget.group['invite_code'] ?? '';
    final memberCount = widget.group['member_count'] ?? 1;
    final serviceName = widget.group['service_name'] ?? 'Subscription';
    final cost = widget.group['detected_cost'];
    final groupId = widget.group['group_id'];

    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final settlement = provider.optimizedSettlementData[groupId];
        final transactions = (settlement?['transactions'] as List?) ?? [];
        final perPerson = settlement?['per_person_share'];
        final totalCost = settlement?['total_cost'];
        final engine = settlement?['engine'] ?? 'Loading...';
        final netBalances = settlement?['net_balances'] as Map<String, dynamic>? ?? {};

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.background,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            actions: [
              if (inviteCode.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.share_rounded, color: AppTheme.mintGreen),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Invite code "$inviteCode" copied!'),
                      backgroundColor: AppTheme.mintGreen,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ));
                  },
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Group Info Card ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.lavender.withOpacity(0.15), AppTheme.mintGreen.withOpacity(0.08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.lavender.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.lavender.withOpacity(0.2),
                      child: const Icon(Icons.group_rounded, color: AppTheme.lavender, size: 28),
                    ),
                    const SizedBox(height: 12),
                    Text(serviceName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    if (cost != null)
                      Text('₹$cost/month', style: const TextStyle(color: AppTheme.pastelYellow, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _infoChip(Icons.people_alt_rounded, '$memberCount members', AppTheme.pastelBlue),
                        const SizedBox(width: 12),
                        if (inviteCode.isNotEmpty)
                          _infoChip(Icons.vpn_key_rounded, inviteCode, AppTheme.pastelYellow),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Per-Person Share ──
              if (perPerson != null) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppTheme.mintGreen.withOpacity(0.15), shape: BoxShape.circle),
                        child: const Icon(Icons.pie_chart_rounded, color: AppTheme.mintGreen, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(child: Text('Per-person share', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14))),
                      Text('₹$perPerson', style: const TextStyle(color: AppTheme.mintGreen, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Net Balances ──
              if (netBalances.isNotEmpty) ...[
                const Text('Net Balances', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Positive = owed money · Negative = owes money', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                const SizedBox(height: 12),
                ...netBalances.entries.map((e) {
                  final isPositive = (e.value as num) >= 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: (isPositive ? AppTheme.mintGreen : AppTheme.alertRed).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isPositive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          color: isPositive ? AppTheme.mintGreen : AppTheme.alertRed,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(e.key, style: const TextStyle(color: Colors.white, fontSize: 15))),
                        Text(
                          '${isPositive ? "+" : ""}₹${(e.value as num).toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isPositive ? AppTheme.mintGreen : AppTheme.alertRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 24),
              ],

              // ── Settlement Transactions (C++ Engine Output) ──
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppTheme.lavender, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Optimized Settlements', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                ],
              ),
              const SizedBox(height: 4),
              Text('Engine: $engine', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              const SizedBox(height: 14),

              if (provider.isOptimizing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: AppTheme.mintGreen)),
                )
              else if (transactions.isEmpty && settlement != null)
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: AppTheme.mintGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('✅ All settled! No transactions needed.', style: TextStyle(color: AppTheme.mintGreen, fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                )
              else
                ...transactions.map((t) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _settled ? AppTheme.mintGreen.withOpacity(0.08) : AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _settled ? AppTheme.mintGreen.withOpacity(0.3) : AppTheme.lavender.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        // From user
                        Expanded(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppTheme.alertRed.withOpacity(0.15),
                                child: Text(
                                  (t['from_user'] ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(color: AppTheme.alertRed, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(t['from_user'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                              const Text('pays', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                            ],
                          ),
                        ),
                        // Arrow + Amount
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: _settled ? AppTheme.mintGreen.withOpacity(0.2) : AppTheme.pastelYellow.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '₹${t['amount']}',
                                style: TextStyle(
                                  color: _settled ? AppTheme.mintGreen : AppTheme.pastelYellow,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: _settled ? AppTheme.mintGreen : AppTheme.textSecondary,
                              size: 20,
                            ),
                            if (_settled)
                              const Text('SETTLED', style: TextStyle(color: AppTheme.mintGreen, fontSize: 9, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        // To user
                        Expanded(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppTheme.mintGreen.withOpacity(0.15),
                                child: Text(
                                  (t['to_user'] ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(color: AppTheme.mintGreen, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(t['to_user'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                              const Text('receives', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 30),

              // ── Settle Button ──
              if (transactions.isNotEmpty && !_settled)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.mintGreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 22),
                    label: const Text('Settle All Debts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    onPressed: () {
                      setState(() => _settled = true);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Row(
                          children: const [
                            Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                            SizedBox(width: 10),
                            Text('All debts settled! 🎉', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        backgroundColor: AppTheme.mintGreen,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 3),
                      ));
                    },
                  ),
                ),

              if (_settled)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.mintGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.mintGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.check_circle_rounded, color: AppTheme.mintGreen, size: 28),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'All debts have been settled!\nTransactions processed via C++ Engine.',
                          style: TextStyle(color: AppTheme.mintGreen, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: label.length <= 6 ? 1 : 0)),
        ],
      ),
    );
  }
}
