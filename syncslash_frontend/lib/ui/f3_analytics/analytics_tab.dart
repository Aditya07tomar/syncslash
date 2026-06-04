import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../state/app_provider.dart';
import 'knowledge_graph_screen.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppProvider>(context, listen: false).loadAnalytics();
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
            title: const Text('Analytics Engine', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.hub_rounded, color: AppTheme.mintGreen),
                tooltip: 'Knowledge Graph',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KnowledgeGraphScreen())),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
                onPressed: () => provider.loadAnalytics(),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.mintGreen,
              labelColor: AppTheme.mintGreen,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(text: 'Fatigue'),
                Tab(text: 'Ghosts'),
                Tab(text: 'Report'),
              ],
            ),
          ),
          body: provider.isAnalyticsLoading
              ? const Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppTheme.mintGreen),
                    SizedBox(height: 16),
                    Text('Crunching analytics...', style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _FatigueTab(data: provider.fatigueData),
                    _GhostTab(data: provider.ghostData),
                    _ReportTab(data: provider.reportData),
                  ],
                ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// FATIGUE TAB
// ═══════════════════════════════════════════════════════════
class _FatigueTab extends StatelessWidget {
  final Map<String, dynamic>? data;
  const _FatigueTab({this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null) return _emptyState('No fatigue data available');

    final scores = data!['scores'] as List? ?? [];
    final avgFatigue = data!['average_fatigue_score'] ?? 0;
    final ghostCount = data!['ghost_subscriptions'] ?? 0;
    final totalSpend = data!['total_monthly_spend'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Summary cards
        Row(
          children: [
            _statCard('Avg Fatigue', avgFatigue.toStringAsFixed(1), AppTheme.pastelYellow, Icons.speed_rounded),
            const SizedBox(width: 12),
            _statCard('Ghosts', ghostCount.toString(), AppTheme.alertRed, Icons.visibility_off_rounded),
            const SizedBox(width: 12),
            _statCard('Monthly', '₹${totalSpend.toStringAsFixed(0)}', AppTheme.mintGreen, Icons.currency_rupee_rounded),
          ],
        ),
        const SizedBox(height: 24),

        const Text('Per-Subscription Scores', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        ...scores.map<Widget>((score) {
          double fatigueScore = double.tryParse(score['fatigue_score'].toString()) ?? 0;
          String verdict = score['verdict'] ?? '';
          Color barColor = fatigueScore > 500 ? AppTheme.alertRed
              : fatigueScore > 100 ? AppTheme.pastelYellow
              : AppTheme.mintGreen;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: barColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(score['service_name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: barColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text(fatigueScore.toStringAsFixed(1), style: TextStyle(color: barColor, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Fatigue bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (fatigueScore / 1000).clamp(0.0, 1.0),
                    backgroundColor: Colors.white10,
                    color: barColor,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${score['category'] ?? ''} • ₹${score['monthly_cost'] ?? 0}/mo', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    Text('Used ${score['usage_count'] ?? 0}x', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(verdict, style: TextStyle(color: barColor, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// GHOSTS TAB
// ═══════════════════════════════════════════════════════════
class _GhostTab extends StatelessWidget {
  final Map<String, dynamic>? data;
  const _GhostTab({this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null) return _emptyState('No ghost data available');

    final ghosts = data!['ghosts'] as List? ?? [];
    final totalWaste = data!['total_monthly_waste'] ?? 0;
    final message = data!['message'] ?? '';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.alertRed.withOpacity(0.15), AppTheme.surface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.alertRed.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.visibility_off_rounded, color: AppTheme.alertRed, size: 40),
              const SizedBox(height: 12),
              Text('₹${totalWaste.toStringAsFixed(0)}/mo wasted', style: const TextStyle(color: AppTheme.alertRed, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13), textAlign: TextAlign.center),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (ghosts.isNotEmpty) ...[
          const Text('Ghost Subscriptions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...ghosts.map<Widget>((ghost) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: const Border(left: BorderSide(color: AppTheme.alertRed, width: 4)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.alertRed.withOpacity(0.2),
                    child: const Icon(Icons.visibility_off_rounded, color: AppTheme.alertRed, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ghost['service_name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          'Used ${ghost['usage_count'] ?? 0} times • ${ghost['ghost_reason'] ?? 'unknown'}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text('₹${ghost['detected_cost'] ?? 0}', style: const TextStyle(color: AppTheme.alertRed, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// REPORT TAB
// ═══════════════════════════════════════════════════════════
class _ReportTab extends StatelessWidget {
  final Map<String, dynamic>? data;
  const _ReportTab({this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null) return _emptyState('No report data available');

    final categories = data!['categories'] as List? ?? [];
    final summary = data!['summary'] as Map<String, dynamic>? ?? {};

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Summary stats
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Text('Monthly Summary', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _miniStat('Total Spend', '₹${(summary['total_monthly_spend'] ?? 0).toStringAsFixed(0)}', AppTheme.pastelBlue),
                  _miniStat('Savings', '₹${(summary['total_potential_savings'] ?? 0).toStringAsFixed(0)}', AppTheme.mintGreen),
                  _miniStat('Ghosts', '${summary['total_ghost_subscriptions'] ?? 0}', AppTheme.alertRed),
                ],
              ),
              if (summary['savings_percentage'] != null) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ((summary['savings_percentage'] ?? 0) / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.white10,
                    color: AppTheme.mintGreen,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Text('${summary['savings_percentage']}% potential savings', style: const TextStyle(color: AppTheme.mintGreen, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Category chart
        if (categories.isNotEmpty) ...[
          const Text('Spend by Category', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 40,
                sections: _buildChartSections(categories),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Category list
          ...categories.map<Widget>((cat) {
            final cost = double.tryParse(cat['total_category_cost'].toString()) ?? 0;
            final ghosts = int.tryParse(cat['ghost_count'].toString()) ?? 0;
            final savings = double.tryParse(cat['potential_savings'].toString()) ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 40,
                    decoration: BoxDecoration(
                      color: _categoryColor(cat['category'] ?? ''),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat['category'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('${cat['service_count']} services • ${ghosts} ghosts', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${cost.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      if (savings > 0)
                        Text('Save ₹${savings.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.mintGreen, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  List<PieChartSectionData> _buildChartSections(List categories) {
    final colors = [AppTheme.mintGreen, AppTheme.lavender, AppTheme.pastelYellow, AppTheme.pastelBlue, AppTheme.alertRed];
    return categories.asMap().entries.map((entry) {
      final i = entry.key;
      final cat = entry.value;
      final cost = double.tryParse(cat['total_category_cost'].toString()) ?? 0;
      return PieChartSectionData(
        color: colors[i % colors.length],
        value: cost,
        title: '₹${cost.toStringAsFixed(0)}',
        titleStyle: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
        radius: 55,
      );
    }).toList();
  }
}

// ═══════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════

Widget _statCard(String label, String value, Color color, IconData icon) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    ),
  );
}

Widget _miniStat(String label, String value, Color color) {
  return Column(
    children: [
      Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
    ],
  );
}

Widget _emptyState(String message) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.analytics_outlined, color: AppTheme.textSecondary.withOpacity(0.4), size: 60),
        const SizedBox(height: 16),
        Text(message, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
      ],
    ),
  );
}

Color _categoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'streaming': return AppTheme.lavender;
    case 'music': return AppTheme.mintGreen;
    case 'productivity': return AppTheme.pastelYellow;
    case 'fitness': return AppTheme.alertRed;
    case 'cloud': return AppTheme.pastelBlue;
    default: return AppTheme.lavender;
  }
}
