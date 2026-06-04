import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../state/app_provider.dart';
import 'group_detail_screen.dart';

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppProvider>(context, listen: false).loadP2PData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            title: const Text('Split & Settle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
                onPressed: () => provider.loadP2PData(),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.mintGreen,
              labelColor: AppTheme.mintGreen,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(text: 'P2P'),
                Tab(text: 'Groups'),
                Tab(text: 'History'),
              ],
            ),
          ),
          body: provider.isP2PLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppTheme.mintGreen),
                      SizedBox(height: 16),
                      Text('Loading settlements...', style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _P2PTab(provider: provider),
                    _GroupsTab(provider: provider),
                    _HistoryTab(provider: provider),
                  ],
                ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// P2P TAB
// ═══════════════════════════════════════════════════════════
class _P2PTab extends StatelessWidget {
  final AppProvider provider;
  const _P2PTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final balanceData = provider.p2pBalanceData;
    final owesYou = balanceData?['owes_you'] as List? ?? [];
    final youOwe = balanceData?['you_owe'] as List? ?? [];
    final netBalance = balanceData?['net_balance'] ?? 0;
    final groups = provider.groups;

    // Calculate group stats
    double totalGroupCost = 0;
    double totalYourShare = 0;
    for (final g in groups) {
      final cost = (g['detected_cost'] ?? 0).toDouble();
      final members = (g['member_count'] ?? 1).toInt();
      totalGroupCost += cost;
      totalYourShare += members > 0 ? cost / members : cost;
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Net balance card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                (netBalance >= 0 ? AppTheme.mintGreen : AppTheme.alertRed).withOpacity(0.15),
                AppTheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: (netBalance >= 0 ? AppTheme.mintGreen : AppTheme.alertRed).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Text('Net Balance', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                '${netBalance >= 0 ? '+' : ''}₹${(netBalance as num).toStringAsFixed(0)}',
                style: TextStyle(
                  color: netBalance >= 0 ? AppTheme.mintGreen : AppTheme.alertRed,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                netBalance >= 0 ? 'People owe you overall' : 'You owe overall',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            _balancePill('Owed to you', '₹${balanceData?['total_owed_to_you']?.toStringAsFixed(0) ?? '0'}', AppTheme.mintGreen),
            const SizedBox(width: 12),
            _balancePill('You owe', '₹${balanceData?['total_you_owe']?.toStringAsFixed(0) ?? '0'}', AppTheme.alertRed),
          ],
        ),
        const SizedBox(height: 24),

        // ── Group Subscription Stats ──
        if (groups.isNotEmpty) ...[
          const Text('Group Subscriptions', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Tap a group to see settlement details', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 14),

          // Summary row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.lavender.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.lavender.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statCol('${groups.length}', 'Groups', AppTheme.lavender),
                Container(width: 1, height: 30, color: Colors.white12),
                _statCol('₹${totalGroupCost.toStringAsFixed(0)}', 'Total Cost', AppTheme.pastelYellow),
                Container(width: 1, height: 30, color: Colors.white12),
                _statCol('₹${totalYourShare.toStringAsFixed(0)}', 'Your Share', AppTheme.mintGreen),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Individual group cards
          ...groups.map<Widget>((group) {
            final name = group['name'] ?? 'Group';
            final serviceName = group['service_name'] ?? '';
            final cost = (group['detected_cost'] ?? 0).toDouble();
            final members = (group['member_count'] ?? 1).toInt();
            final perPerson = members > 0 ? cost / members : cost;
            final groupId = group['group_id'];

            return GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => GroupDetailScreen(group: group),
                ));
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border(left: BorderSide(color: AppTheme.lavender, width: 4)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.lavender.withOpacity(0.15),
                      child: const Icon(Icons.group_rounded, color: AppTheme.lavender, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                          if (serviceName.isNotEmpty)
                            Text(serviceName, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          Text('$members members · ₹${cost.toStringAsFixed(0)}/mo', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${perPerson.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.mintGreen, fontSize: 18, fontWeight: FontWeight.bold)),
                        const Text('your share', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                      ],
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
        ],

        // Owes you section
        if (owesYou.isNotEmpty) ...[
          const Text('People Who Owe You', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...owesYou.map<Widget>((bill) => _buildBillTile(context, bill, isOwedToYou: true)),
          const SizedBox(height: 20),
        ],

        // You owe section
        if (youOwe.isNotEmpty) ...[
          const Text('You Owe', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...youOwe.map<Widget>((bill) => _buildBillTile(context, bill, isOwedToYou: false)),
        ],

        if (owesYou.isEmpty && youOwe.isEmpty && groups.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Icon(Icons.handshake_outlined, color: AppTheme.textSecondary.withOpacity(0.4), size: 60),
                  const SizedBox(height: 16),
                  const Text('No pending settlements', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                  const SizedBox(height: 6),
                  const Text('All bills are settled!', style: TextStyle(color: AppTheme.mintGreen, fontSize: 13)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _statCol(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      ],
    );
  }

  Widget _buildBillTile(BuildContext context, dynamic bill, {required bool isOwedToYou}) {
    final color = isOwedToYou ? AppTheme.mintGreen : AppTheme.alertRed;
    final name = bill['friend_name'] ?? 'Unknown';
    final amount = bill['amount_owed'] ?? 0;
    final service = bill['service_name'];
    final billId = bill['bill_id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Text(name[0].toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                if (service != null)
                  Text('For: $service', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                Text(
                  isOwedToYou ? 'Owes you' : 'You owe',
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹$amount', style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (billId != null)
                InkWell(
                  onTap: () async {
                    final success = await provider.settleBill(billId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(success ? 'Bill settled!' : 'Failed to settle'),
                        backgroundColor: success ? AppTheme.mintGreen : AppTheme.alertRed,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ));
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.mintGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Settle', style: TextStyle(color: AppTheme.mintGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balancePill(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// GROUPS TAB — with Create and Join
// ═══════════════════════════════════════════════════════════
class _GroupsTab extends StatelessWidget {
  final AppProvider provider;
  const _GroupsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final groups = provider.groups;

    return Stack(
      children: [
        groups.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.group_outlined, color: AppTheme.textSecondary.withOpacity(0.4), size: 60),
                    const SizedBox(height: 16),
                    const Text('No groups yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                    const SizedBox(height: 6),
                    const Text('Create or join a group below', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  final name = group['name'] ?? group['service_name'] ?? 'Unknown';
                  final inviteCode = group['invite_code'] ?? '';
                  final memberCount = group['member_count'] ?? 1;
                  final serviceName = group['service_name'];
                  final cost = group['detected_cost'];

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => GroupDetailScreen(group: group),
                      ));
                    },
                    child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.lavender.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.lavender.withOpacity(0.2),
                              child: const Icon(Icons.group_rounded, color: AppTheme.lavender, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                                  if (serviceName != null)
                                    Text(serviceName, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.pastelBlue.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('$memberCount members', style: const TextStyle(color: AppTheme.pastelBlue, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        if (inviteCode.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.vpn_key_rounded, color: AppTheme.pastelYellow, size: 16),
                              const SizedBox(width: 8),
                              Text('Code: $inviteCode', style: const TextStyle(color: AppTheme.pastelYellow, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1)),
                              const Spacer(),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: inviteCode));
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: const Text('Invite code copied!'),
                                    backgroundColor: AppTheme.mintGreen,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    duration: const Duration(seconds: 1),
                                  ));
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.mintGreen.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.copy_rounded, color: AppTheme.mintGreen, size: 14),
                                      SizedBox(width: 4),
                                      Text('Copy', style: TextStyle(color: AppTheme.mintGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (cost != null) ...[
                          const SizedBox(height: 8),
                          Text('₹$cost/mo', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                  );
                },
              ),

        // FAB row — Create + Join
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mintGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Create Group', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _showCreateGroupDialog(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.lavender,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.login_rounded, size: 20),
                  label: const Text('Join Group', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _showJoinGroupDialog(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showOptimizationDialog(BuildContext context, int groupId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return FutureBuilder(
          future: provider.optimizeGroupSettlement(groupId),
          builder: (context, snapshot) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: AppTheme.mintGreen, size: 24),
                      const SizedBox(width: 10),
                      const Text('Optimized Settlement', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Powered by C++ Engine Minimum Cash Flow Algorithm', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 24),
                  if (provider.isOptimizing)
                    const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(color: AppTheme.mintGreen)))
                  else if (provider.optimizedSettlementData[groupId] == null)
                    const Center(child: Text('Failed to load data', style: TextStyle(color: AppTheme.alertRed)))
                  else ...[
                    ...((provider.optimizedSettlementData[groupId]?['transactions'] as List?) ?? []).map((t) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.lavender.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(backgroundColor: AppTheme.alertRed.withOpacity(0.2), radius: 16, child: const Icon(Icons.arrow_upward_rounded, size: 14, color: AppTheme.alertRed)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(t['from_user'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            const Icon(Icons.arrow_right_alt_rounded, color: AppTheme.textSecondary),
                            Expanded(child: Text(t['to_user'], textAlign: TextAlign.end, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppTheme.mintGreen.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                              child: Text('₹${t['amount']}', style: const TextStyle(color: AppTheme.mintGreen, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    }),
                    if ((provider.optimizedSettlementData[groupId]?['transactions'] as List?)?.isEmpty ?? true)
                      const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No settlements needed!', style: TextStyle(color: AppTheme.mintGreen, fontSize: 16)))),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.mintGreen,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('Create Group', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Choose a name and link a subscription', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  labelStyle: const TextStyle(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Link to subscription:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              ...provider.subscriptions.where((s) => s['status'] == 'active').take(5).map<Widget>((sub) {
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: AppTheme.background,
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.getBrandColor(sub['service_name']).withOpacity(0.3),
                    child: const Icon(Icons.subscriptions_rounded, color: Colors.white70, size: 14),
                  ),
                  title: Text(sub['service_name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: Text('₹${sub['detected_cost']}/mo', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  trailing: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.mintGreen, size: 20),
                  onTap: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a group name'), backgroundColor: AppTheme.alertRed));
                      return;
                    }
                    Navigator.pop(ctx);
                    final success = await provider.createGroup(name: name, subId: sub['sub_id']);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(success ? 'Group "$name" created!' : 'Failed to create group'),
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

  void _showJoinGroupDialog(BuildContext context) {
    final codeController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('Join Group', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Enter the 6-character invite code', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              TextField(
                controller: codeController,
                style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 4, fontWeight: FontWeight.bold),
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: 'ABC123',
                  hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.3), letterSpacing: 4),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  counterStyle: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.lavender,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Join', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  onPressed: () async {
                    final code = codeController.text.trim().toUpperCase();
                    if (code.length != 6) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a 6-character code'), backgroundColor: AppTheme.alertRed));
                      return;
                    }
                    Navigator.pop(ctx);
                    final success = await provider.joinGroup(inviteCode: code);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(success ? 'Joined group successfully!' : 'Invalid invite code'),
                        backgroundColor: success ? AppTheme.mintGreen : AppTheme.alertRed,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ));
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// HISTORY TAB
// ═══════════════════════════════════════════════════════════
class _HistoryTab extends StatelessWidget {
  final AppProvider provider;
  const _HistoryTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final history = provider.p2pHistory;

    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, color: AppTheme.textSecondary.withOpacity(0.4), size: 60),
            const SizedBox(height: 16),
            const Text('No transaction history', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final item = history[index];
        final isSettled = item['status'] == 'settled';
        final payer = item['payer_name'] ?? '';
        final debtor = item['debtor_name'] ?? '';
        final amount = item['amount_owed'] ?? 0;
        final service = item['service_name'];

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: (isSettled ? AppTheme.mintGreen : AppTheme.pastelYellow).withOpacity(0.15),
                child: Icon(
                  isSettled ? Icons.check_rounded : Icons.schedule_rounded,
                  color: isSettled ? AppTheme.mintGreen : AppTheme.pastelYellow,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$payer → $debtor', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                    if (service != null)
                      Text(service, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹$amount', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(
                    isSettled ? 'Settled' : 'Pending',
                    style: TextStyle(
                      color: isSettled ? AppTheme.mintGreen : AppTheme.pastelYellow,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
