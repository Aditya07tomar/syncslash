import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../state/app_provider.dart';

class KnowledgeGraphScreen extends StatefulWidget {
  const KnowledgeGraphScreen({super.key});

  @override
  State<KnowledgeGraphScreen> createState() => _KnowledgeGraphScreenState();
}

class _KnowledgeGraphScreenState extends State<KnowledgeGraphScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      provider.loadGraphData();
      provider.loadRedundancy();
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
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Knowledge Graph', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          body: provider.graphData == null && provider.redundancyData == null
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppTheme.mintGreen),
                      SizedBox(height: 16),
                      Text('Building knowledge graph...', style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildGraphVisualization(provider.graphData),
                    const SizedBox(height: 24),
                    _buildRedundancySection(provider.redundancyData),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildGraphVisualization(Map<String, dynamic>? data) {
    if (data == null) return const SizedBox();

    final graph = data['graph'] as Map<String, dynamic>? ?? {};
    final nodes = graph['nodes'] as List? ?? [];
    final edges = graph['edges'] as List? ?? [];

    if (nodes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(20)),
        child: const Center(child: Text('No graph data yet. Sync your bank data first.', style: TextStyle(color: AppTheme.textSecondary))),
      );
    }

    // Group nodes by type
    final userNodes = nodes.where((n) => n['type'] == 'user').toList();
    final serviceNodes = nodes.where((n) => n['type'] == 'service').toList();
    final categoryNodes = nodes.where((n) => n['type'] == 'category').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.lavender.withOpacity(0.15), AppTheme.mintGreen.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.lavender.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.hub_rounded, color: AppTheme.lavender, size: 40),
              const SizedBox(height: 12),
              const Text('Subscription Topology', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                '${serviceNodes.length} services across ${categoryNodes.length} categories',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legendDot(Colors.redAccent.shade100, 'User'),
                  const SizedBox(width: 20),
                  _legendDot(AppTheme.pastelBlue, 'Service'),
                  const SizedBox(width: 20),
                  _legendDot(AppTheme.mintGreen, 'Category'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Category nodes with services
        const Text('Graph Structure', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        // User node
        if (userNodes.isNotEmpty)
          _buildNodeTile(userNodes[0]['label'], 'user', null),

        // Services grouped by category edges
        ...categoryNodes.map<Widget>((catNode) {
          // Find services connected to this category
          final catId = catNode['id'];
          final connectedServiceIds = edges
              .where((e) => e['to'] == catId && e['label'] == 'BELONGS_TO')
              .map((e) => e['from'])
              .toSet();
          final connectedServices = serviceNodes.where((s) => connectedServiceIds.contains(s['id'])).toList();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category header
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.mintGreen.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: AppTheme.mintGreen.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.category_rounded, color: AppTheme.mintGreen, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(catNode['label'] ?? '', style: const TextStyle(color: AppTheme.mintGreen, fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text('${connectedServices.length} services', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                // Services
                ...connectedServices.map<Widget>((svc) {
                  final cost = svc['cost'];
                  // Find edge with usage info
                  final subEdge = edges.firstWhere(
                    (e) => e['to'] == svc['id'] && e['label'] == 'SUBSCRIBED_TO',
                    orElse: () => {},
                  );
                  final usage = subEdge is Map ? subEdge['usage'] : null;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white10)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 20),
                        Icon(Icons.arrow_right_rounded, color: AppTheme.textSecondary.withOpacity(0.5), size: 20),
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(color: AppTheme.pastelBlue.withOpacity(0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.subscriptions_rounded, color: AppTheme.pastelBlue, size: 14),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(svc['label'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ),
                        if (cost != null)
                          Text('₹${cost}', style: const TextStyle(color: AppTheme.pastelYellow, fontSize: 13, fontWeight: FontWeight.w600)),
                        if (usage != null) ...[
                          const SizedBox(width: 10),
                          Text('${usage}x', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRedundancySection(Map<String, dynamic>? data) {
    if (data == null) return const SizedBox();

    final hasRedundancy = data['has_redundancy'] ?? false;
    final overlaps = data['overlaps'] as List? ?? [];
    final totalSavings = data['total_potential_savings'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Redundancy Analysis', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        if (!hasRedundancy)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.mintGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.mintGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.mintGreen, size: 30),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('No redundant subscriptions detected!', style: TextStyle(color: AppTheme.mintGreen, fontSize: 15, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),

        if (hasRedundancy) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.pastelYellow.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.pastelYellow.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.pastelYellow, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You could save ₹${totalSavings.toStringAsFixed(0)}/mo by removing overlapping services',
                    style: const TextStyle(color: AppTheme.pastelYellow, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          ...overlaps.map<Widget>((overlap) {
            final services = overlap['services'] as List? ?? [];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.lavender.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: Text(overlap['category'] ?? '', style: const TextStyle(color: AppTheme.lavender, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const Spacer(),
                      Text('${overlap['overlap_count']} overlapping', style: const TextStyle(color: AppTheme.alertRed, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...services.map<Widget>((svc) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          svc['name'] == overlap['most_used_service'] ? Icons.star_rounded : Icons.circle_outlined,
                          color: svc['name'] == overlap['most_used_service'] ? AppTheme.mintGreen : AppTheme.textSecondary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(svc['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14))),
                        Text('₹${svc['cost']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    ),
                  )),
                  const Divider(color: Colors.white10),
                  Text(
                    overlap['recommendation'] ?? '',
                    style: const TextStyle(color: AppTheme.pastelYellow, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildNodeTile(String label, String type, dynamic cost) {
    Color color;
    IconData icon;
    switch (type) {
      case 'user':
        color = Colors.redAccent.shade100;
        icon = Icons.person_rounded;
        break;
      case 'service':
        color = AppTheme.pastelBlue;
        icon = Icons.subscriptions_rounded;
        break;
      case 'category':
        color = AppTheme.mintGreen;
        icon = Icons.category_rounded;
        break;
      default:
        color = AppTheme.lavender;
        icon = Icons.circle;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }
}
