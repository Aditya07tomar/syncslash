import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../state/app_provider.dart';
import 'kill_switch_screen.dart';

//to load data
class DashboardTab extends StatefulWidget {
  @override
  _DashboardTabState createState() => _DashboardTabState();
}

//fetches info
class _DashboardTabState extends State<DashboardTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppProvider>(context, listen: false).loadInitialData();
    });
  }

  //loading screen while fetching, rebuilds ui after done
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppTheme.mintGreen),
                SizedBox(height: 20),
                Text("Syncing secure data...", style: TextStyle(color: AppTheme.textSecondary))
              ],
            ),
          );
        }

        // Error state
        if (provider.errorMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_rounded, color: AppTheme.alertRed.withOpacity(0.6), size: 60),
                  const SizedBox(height: 20),
                  Text(provider.errorMessage!, style: const TextStyle(color: AppTheme.alertRed, fontSize: 15), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.mintGreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => provider.loadInitialData(),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: RefreshIndicator(
            color: AppTheme.mintGreen,
            backgroundColor: AppTheme.surface,
            onRefresh: () => provider.triggerBankSync(),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildHeader(context, provider),
                const SizedBox(height: 30),
                _buildQuickStats(provider.summaryData),
                const SizedBox(height: 25),
                _buildCategoryBreakdown(provider.summaryData),
                const SizedBox(height: 25),
                // Active groups
                if (provider.groups.isNotEmpty) ...[
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Active Groups', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                      Text('${provider.groups.length} groups', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: provider.groups.length,
                      itemBuilder: (context, index) {
                        final group = provider.groups[index];
                        return Container(
                          width: 200,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.lavender.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.group_rounded, color: AppTheme.lavender, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      group['name'] ?? group['service_name'] ?? 'Group',
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Text(
                                    '${group['member_count'] ?? 1} members',
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                  ),
                                  const Spacer(),
                                  if (group['invite_code'] != null)
                                    Text(
                                      '${group['invite_code']}',
                                      style: const TextStyle(color: AppTheme.pastelYellow, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 25),
                ],
                const Text('All Subscriptions', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                if (provider.subscriptions.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        Icon(Icons.inbox_rounded, color: AppTheme.textSecondary.withOpacity(0.5), size: 40),
                        const SizedBox(height: 12),
                        const Text("No active subscriptions found", style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                        const SizedBox(height: 6),
                        const Text("Pull down to sync your bank data", style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ...provider.subscriptions.map((sub) => _buildSubCard(context, sub)).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  //avatar and greeting
  Widget _buildHeader(BuildContext context, AppProvider provider) {
    // Determine greeting based on time of day
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning,';
    } else if (hour < 17) {
      greeting = 'Good Afternoon,';
    } else {
      greeting = 'Good Evening,';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppTheme.surface,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                Text(provider.userName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.sync_rounded, color: AppTheme.textSecondary),
              tooltip: 'Sync Bank Data',
              onPressed: () => provider.triggerBankSync(),
            ),
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStats(Map<String, dynamic>? summary) {
    if (summary == null) return const SizedBox();
    final nextBill = summary['next_renewal'];

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Monthly Burn', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                const SizedBox(height: 8),
                Text('₹${summary['total_monthly_burn'].toInt()}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${summary['total_subscriptions']} Active Services', style: const TextStyle(color: AppTheme.mintGreen, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.lavender, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Next Bill', style: TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(nextBill != null ? nextBill['service_name'] : 'None', style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Text(nextBill != null ? '₹${nextBill['detected_cost']}' : '', style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBreakdown(Map<String, dynamic>? summary) {
    if (summary == null || summary['by_category'] == null) return const SizedBox();
    List<dynamic> categories = summary['by_category'];

    if (categories.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Spend by Category', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        SizedBox(
          height: 45,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text('${cat['category']}: ₹${cat['category_total']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubCard(BuildContext context, dynamic sub) {
    bool isFrozen = sub['status'] == 'frozen';
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => KillSwitchScreen(subscription: sub))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isFrozen ? AppTheme.surface : AppTheme.getBrandColor(sub['service_name']),
          borderRadius: BorderRadius.circular(20),
          border: isFrozen ? Border.all(color: AppTheme.alertRed, width: 2) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: Colors.black12, child: Icon(isFrozen ? Icons.lock : Icons.subscriptions, color: Colors.black87)),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub['service_name'], style: TextStyle(color: isFrozen ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('₹${sub['detected_cost']} / mo', style: TextStyle(color: isFrozen ? AppTheme.alertRed : Colors.black54, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: isFrozen ? Colors.white38 : Colors.black38, size: 16)
          ],
        ),
      ),
    );
  }
}