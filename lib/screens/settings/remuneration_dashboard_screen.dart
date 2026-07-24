import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/secretary_remuneration.dart';
import '../../providers/providers.dart';

/// Admin-only overview of RS earnings (paid / pending / approved).
///
/// // NEW ADDITION - Delete this file to revert remuneration dashboard UI.
class RemunerationDashboardScreen extends ConsumerStatefulWidget {
  const RemunerationDashboardScreen({super.key});

  @override
  ConsumerState<RemunerationDashboardScreen> createState() =>
      _RemunerationDashboardScreenState();
}

class _RemunerationDashboardScreenState
    extends ConsumerState<RemunerationDashboardScreen> {
  RemunerationDashboard? _dashboard;
  List<SecretaryRemuneration> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(remunerationServiceProvider);
      final dashboard = await service.getDashboardData();
      final records =
          await ref.read(databaseServiceProvider).getAllRemunerationRecords();
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _records = records;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approve(SecretaryRemuneration record) async {
    final admin = ref.read(authUserProvider);
    if (admin == null) return;
    await ref
        .read(remunerationServiceProvider)
        .approveRemuneration(record.id, admin.id);
    await _loadDashboard();
  }

  Future<void> _pay(SecretaryRemuneration record) async {
    final admin = ref.read(authUserProvider);
    if (admin == null) return;
    await ref
        .read(remunerationServiceProvider)
        .payRemuneration(record.id, admin.id);
    await _loadDashboard();
  }

  Widget _buildSummaryCard(String label, String amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              amount,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _dashboard == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Remuneration Dashboard')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final dash = _dashboard!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remuneration Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboard,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildSummaryCard(
                  'Total Paid',
                  'R ${dash.totalPaid.toStringAsFixed(2)}',
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _buildSummaryCard(
                  'Pending',
                  'R ${dash.totalPending.toStringAsFixed(2)}',
                  Colors.orange,
                ),
                const SizedBox(width: 8),
                _buildSummaryCard(
                  'Approved',
                  'R ${dash.totalApproved.toStringAsFixed(2)}',
                  Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Secretary Earnings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (dash.secretaryTotals.isEmpty)
                      Text(
                        'No remuneration records yet.',
                        style: TextStyle(color: Colors.grey.shade600),
                      )
                    else
                      ...dash.secretaryTotals.entries.map((entry) {
                        final name = dash.secretaryNames[entry.key] ??
                            'Secretary ${entry.key.substring(0, entry.key.length.clamp(0, 8))}';
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: Icon(
                                  Icons.person,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                'R ${entry.value.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Recent Records',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._records.take(20).map((record) {
              return Card(
                child: ListTile(
                  title: Text(
                    '${record.secretaryName} — ${record.description}',
                  ),
                  subtitle: Text(
                    '${record.memberName} · ${record.status} · '
                    'R ${record.amount.toStringAsFixed(2)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (record.status == 'pending')
                        TextButton(
                          onPressed: () => _approve(record),
                          child: const Text('Approve'),
                        ),
                      if (record.status == 'approved' ||
                          record.status == 'pending')
                        TextButton(
                          onPressed: () => _pay(record),
                          child: const Text('Pay'),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
