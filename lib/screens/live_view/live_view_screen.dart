import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/activity_log.dart';
import '../../models/live_view_data.dart';
import '../../providers/providers.dart';

class LiveViewScreen extends ConsumerStatefulWidget {
  const LiveViewScreen({super.key});

  @override
  ConsumerState<LiveViewScreen> createState() => _LiveViewScreenState();
}

class _LiveViewScreenState extends ConsumerState<LiveViewScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) ref.invalidate(liveViewDataProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(isAdminProvider)) {
      return const Center(child: Text('Live View is available to Admin only.'));
    }
    final dataAsync = ref.watch(liveViewDataProvider);
    return ColoredBox(
      color: const Color(0xFF090D10),
      child: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(liveViewDataProvider),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(liveViewDataProvider.future),
          child: _Dashboard(
            data: data,
            onRefresh: () => ref.invalidate(liveViewDataProvider),
          ),
        ),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.data, required this.onRefresh});

  final LiveViewData data;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const PageStorageKey('live-view-dashboard'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        _Header(data: data, onRefresh: onRefresh),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 4
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            final width =
                (constraints.maxWidth - ((columns - 1) * 12)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricTile(
                  width: width,
                  icon: Icons.groups_2_outlined,
                  label: 'Combined Total',
                  value: '${data.totalMembers}',
                  detail: 'Active members in the system',
                  color: const Color(0xFF49B6FF),
                ),
                _MetricTile(
                  width: width,
                  icon: Icons.verified_user_outlined,
                  label: 'Existing Members',
                  value: '${data.existingMembers}',
                  detail: 'Complete and fully fledged',
                  color: const Color(0xFF5FD39B),
                ),
                _MetricTile(
                  width: width,
                  icon: Icons.person_add_alt_1,
                  label: 'New Members',
                  value: '${data.newMembers}',
                  detail: 'Currently in onboarding',
                  color: const Color(0xFFFFC857),
                ),
                _MetricTile(
                  width: width,
                  icon: Icons.route_outlined,
                  label: 'Tracked by Step',
                  value: '${data.trackedNewMembers}',
                  detail: 'Members with step activity',
                  color: const Color(0xFFFF7B72),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'New Members by Step',
          subtitle:
              '${data.trackedNewMembers} members represented in active step records',
          icon: Icons.stacked_bar_chart,
          child: _StepBars(metrics: data.stepMetrics),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 840;
            final financial = _Section(
              title: 'RS Financial Breakdown',
              subtitle: 'Earned, paid and currently outstanding',
              icon: Icons.account_balance_wallet_outlined,
              child: _FinancialTable(data: data),
            );
            final bottlenecks = _Section(
              title: 'Bottleneck Analysis',
              subtitle: 'Average elapsed time between step completions',
              icon: Icons.timer_outlined,
              child: _BottleneckTable(metrics: data.stepMetrics),
            );
            if (!wide) {
              return Column(
                children: [financial, const SizedBox(height: 16), bottlenecks],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: financial),
                const SizedBox(width: 16),
                Expanded(child: bottlenecks),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 840;
            final payment = _Section(
              title: 'Payment Status',
              subtitle: '${data.activeRecords.length} active payment records',
              icon: Icons.donut_large,
              child: _PaymentStatus(data: data),
            );
            final growth = _Section(
              title: 'Six-Week Member Growth',
              subtitle: 'New member records created per week',
              icon: Icons.show_chart,
              child: _GrowthChart(points: data.weeklyGrowth),
            );
            if (!wide) {
              return Column(
                children: [payment, const SizedBox(height: 16), growth],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: payment),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: growth),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 840;
            final leaderboard = _Section(
              title: 'RS Performance Leaderboard',
              subtitle: 'Ranked by average step completion time',
              icon: Icons.emoji_events_outlined,
              child: _Leaderboard(metrics: data.secretaryMetrics),
            );
            final timeline = _Section(
              title: 'Live Activity Timeline',
              subtitle: 'Most recent system events',
              icon: Icons.bolt,
              child: _ActivityTimeline(activities: data.recentActivities),
            );
            if (!wide) {
              return Column(
                children: [leaderboard, const SizedBox(height: 16), timeline],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: leaderboard),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: timeline),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Figures refresh automatically every 60 seconds.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data, required this.onRefresh});

  final LiveViewData data;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm:ss').format(data.generatedAt.toLocal());
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF143D2C),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.monitor_heart, color: Color(0xFF5FD39B)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live View Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Bird\'s-eye operational view',
                style: TextStyle(color: Colors.white60),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF123426),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2B7654)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 8,
                height: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF5FD39B),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'LIVE · $time',
                style: const TextStyle(color: Color(0xFF9DE8C2), fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh Live View',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh, color: Colors.white70),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 116,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12181D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF29343D)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12181D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF29343D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFFC857), size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StepBars extends StatelessWidget {
  const _StepBars({required this.metrics});

  final List<LiveViewStepMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final maxCount = metrics.fold<int>(
      1,
      (value, item) => math.max(value, item.count),
    );
    return Column(
      children: metrics.map((metric) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: Row(
            children: [
              SizedBox(
                width: 178,
                child: Text(
                  _stepName(metric.step),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    minHeight: 12,
                    value: metric.count / maxCount,
                    backgroundColor: const Color(0xFF263038),
                    color: _stepColor(metric.step),
                  ),
                ),
              ),
              SizedBox(
                width: 46,
                child: Text(
                  '${metric.count}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _FinancialTable extends StatelessWidget {
  const _FinancialTable({required this.data});

  final LiveViewData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...data.secretaryMetrics.map(
          (metric) => _DataRow(
            title: metric.secretaryName,
            subtitle:
                '${metric.membersCompleted} member payments · Due ${_money(metric.amountOutstanding)}',
            value: _money(metric.totalEarned),
            color: const Color(0xFF5FD39B),
          ),
        ),
        const Divider(color: Color(0xFF303A42)),
        _DataRow(
          title: 'TOTAL EARNED',
          subtitle:
              'Paid ${_money(data.totalPaid)} · Outstanding ${_money(data.totalOutstanding)}',
          value: _money(data.totalEarned),
          color: const Color(0xFFFFC857),
          bold: true,
        ),
      ],
    );
  }
}

class _BottleneckTable extends StatelessWidget {
  const _BottleneckTable({required this.metrics});

  final List<LiveViewStepMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: metrics.map((metric) {
        final color = switch (metric.status) {
          'Good' => const Color(0xFF5FD39B),
          'Average' => const Color(0xFFFFC857),
          'Bottleneck' => const Color(0xFFFF7B72),
          _ => Colors.white38,
        };
        return _DataRow(
          title: _stepName(metric.step),
          subtitle: metric.status,
          value: metric.averageDays == null
              ? 'No data'
              : '${metric.averageDays!.toStringAsFixed(1)} days',
          color: color,
        );
      }).toList(),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.color,
    this.bold = false,
  });

  final String title;
  final String subtitle;
  final String value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentStatus extends StatelessWidget {
  const _PaymentStatus({required this.data});

  final LiveViewData data;

  @override
  Widget build(BuildContext context) {
    final total = data.totalEarned;
    final ratio = total == 0 ? 0.0 : data.totalPaid / total;
    return SizedBox(
      height: 170,
      child: Row(
        children: [
          SizedBox(
            width: 142,
            height: 142,
            child: CustomPaint(
              painter: _DonutPainter(value: ratio),
              child: Center(
                child: Text(
                  '${(ratio * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Legend(
                  color: const Color(0xFF5FD39B),
                  label: 'Paid',
                  value: _money(data.totalPaid),
                ),
                const SizedBox(height: 12),
                _Legend(
                  color: const Color(0xFFFF7B72),
                  label: 'Unpaid',
                  value: _money(data.totalOutstanding),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;
    final background = Paint()
      ..color = const Color(0xFF342329)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15;
    final foreground = Paint()
      ..color = const Color(0xFF5FD39B)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 15;
    canvas.drawCircle(center, radius, background);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      foreground,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.value != value;
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 9, height: 9, color: color),
      const SizedBox(width: 7),
      Expanded(
        child: Text(label, style: const TextStyle(color: Colors.white60)),
      ),
      Text(
        value,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _GrowthChart extends StatelessWidget {
  const _GrowthChart({required this.points});

  final List<LiveViewGrowthPoint> points;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: _GrowthPainter(points),
              child: const SizedBox.expand(),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: points
                .map(
                  (point) => Text(
                    DateFormat('d MMM').format(point.weekStart),
                    style: const TextStyle(color: Colors.white38, fontSize: 9),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _GrowthPainter extends CustomPainter {
  const _GrowthPainter(this.points);

  final List<LiveViewGrowthPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final maxValue = points.fold<int>(
      1,
      (value, point) => math.max(value, point.count),
    );
    final grid = Paint()
      ..color = const Color(0xFF29343D)
      ..strokeWidth = 1;
    for (var index = 1; index <= 3; index++) {
      final y = size.height * index / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final path = Path();
    final line = Paint()
      ..color = const Color(0xFF49B6FF)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = const Color(0xFFFFC857);
    for (var index = 0; index < points.length; index++) {
      final x = points.length == 1
          ? size.width / 2
          : size.width * index / (points.length - 1);
      final y =
          size.height -
          14 -
          ((size.height - 28) * points[index].count / maxValue);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, dot);
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _GrowthPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _Leaderboard extends StatelessWidget {
  const _Leaderboard({required this.metrics});

  final List<LiveViewSecretaryMetric> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return const Text(
        'No RS performance data yet.',
        style: TextStyle(color: Colors.white54),
      );
    }
    return Column(
      children: metrics.asMap().entries.map((entry) {
        final rank = entry.key + 1;
        final metric = entry.value;
        return _DataRow(
          title: '$rank. ${metric.secretaryName}',
          subtitle:
              '${metric.membersCompleted} members · ${_money(metric.totalEarned)} earned',
          value: metric.averageCompletionDays == null
              ? 'No timing'
              : '${metric.averageCompletionDays!.toStringAsFixed(1)} days',
          color: rank == 1 ? const Color(0xFFFFC857) : const Color(0xFF49B6FF),
        );
      }).toList(),
    );
  }
}

class _ActivityTimeline extends StatelessWidget {
  const _ActivityTimeline({required this.activities});

  final List<ActivityLog> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const Text(
        'No recent activity yet.',
        style: TextStyle(color: Colors.white54),
      );
    }
    return Column(
      children: activities.map((activity) {
        final local = activity.occurredAt.toLocal();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.circle, size: 9, color: Color(0xFF5FD39B)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.action,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      '${activity.userName} · ${DateFormat('d MMM, HH:mm').format(local)}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Color(0xFFFF7B72), size: 42),
        const SizedBox(height: 10),
        Text(
          'Live View could not load: $message',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}

String _stepName(int step) => switch (step) {
  1 => 'Step 1_Global 528',
  2 => 'Step 2_Global 528',
  3 => 'Step 3_Global 928',
  4 => 'Step 4_LRO',
  _ => 'Step 5_Credential Card',
};

Color _stepColor(int step) => switch (step) {
  1 => const Color(0xFF49B6FF),
  2 => const Color(0xFF5FD39B),
  3 => const Color(0xFFFFC857),
  4 => const Color(0xFFFF9F68),
  _ => const Color(0xFFFF7B72),
};

String _money(double value) => 'R ${NumberFormat('#,##0.00').format(value)}';
