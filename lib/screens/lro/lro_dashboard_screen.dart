import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/lro/lro_theme.dart';
import '../../models/lro_case.dart';
import '../../providers/providers.dart';
import '../../widgets/lro/lro_stat_card.dart';
import '../../widgets/lro/lro_status_badge.dart';
import 'lro_notice_detail_screen.dart';
import 'lro_notice_list_screen.dart';
import 'lro_reports_screen.dart';

/// Document generators hosted on the LRO-SA website, opened externally.
const _generatorLinks = <(String, String)>[
  (
    '528 Status Correction Generator',
    'https://lro-sa.co.za/content/10-528-status-correction-document-generator',
  ),
  (
    '928 Emancipation Generator',
    'https://lro-sa.co.za/content/11-928-emancipation-document-generator',
  ),
  (
    'Full Armour Document Generator',
    'https://lro-sa.co.za/content/12-full-armour-document-generator',
  ),
  ('Credential Card', 'https://lro-sa.co.za/content/3-Credential-card'),
];

class LroDashboardScreen extends ConsumerWidget {
  const LroDashboardScreen({super.key});

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(lroStatsProvider);
    final feedAsync = ref.watch(lroNoticeFeedProvider);
    final dateFmt = DateFormat('yyyy-MM-dd');

    return LroThemed(
      child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'LRO Dashboard',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: LroTheme.text(context),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  ref.invalidate(lroStatsProvider);
                  ref.invalidate(lroNoticeFeedProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          statsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error loading stats: $e'),
            data: (stats) {
              final pending = stats.statusCount(
                    LroCaseType.status528,
                    LroCaseStatus.submitted,
                  ) +
                  stats.statusCount(
                    LroCaseType.status528,
                    LroCaseStatus.underReview,
                  ) +
                  stats.statusCount(
                    LroCaseType.status528,
                    LroCaseStatus.processing,
                  ) +
                  stats.statusCount(
                    LroCaseType.emancipation928,
                    LroCaseStatus.submitted,
                  ) +
                  stats.statusCount(
                    LroCaseType.emancipation928,
                    LroCaseStatus.underReview,
                  ) +
                  stats.statusCount(
                    LroCaseType.emancipation928,
                    LroCaseStatus.processing,
                  );
              final published = stats.statusCount(
                    LroCaseType.status528,
                    LroCaseStatus.published,
                  ) +
                  stats.statusCount(
                    LroCaseType.emancipation928,
                    LroCaseStatus.published,
                  );
              final rejected = stats.statusCount(
                    LroCaseType.status528,
                    LroCaseStatus.rejected,
                  ) +
                  stats.statusCount(
                    LroCaseType.emancipation928,
                    LroCaseStatus.rejected,
                  );
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 170,
                    child: LroStatCard(
                      title: 'Total 528',
                      count: stats.total528,
                      icon: Icons.description_outlined,
                      onTap: () => ref
                          .read(appSectionProvider.notifier)
                          .state = AppSection.global528,
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: LroStatCard(
                      title: 'Total 928',
                      count: stats.total928,
                      icon: Icons.gavel_outlined,
                      onTap: () => ref
                          .read(appSectionProvider.notifier)
                          .state = AppSection.global928,
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: LroStatCard(
                      title: 'Pending',
                      count: pending,
                      icon: Icons.hourglass_empty,
                      color: AppTheme.gold,
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: LroStatCard(
                      title: 'Published',
                      count: published,
                      icon: Icons.verified_outlined,
                      color: LroTheme.text(context),
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: LroStatCard(
                      title: 'Rejected',
                      count: rejected,
                      icon: Icons.cancel_outlined,
                      color: AppTheme.brick,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => ref
                      .read(appSectionProvider.notifier)
                      .state = AppSection.global528,
                  icon: const Icon(Icons.list_alt),
                  label: const Text('View All 528'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => ref
                      .read(appSectionProvider.notifier)
                      .state = AppSection.global928,
                  icon: const Icon(Icons.list_alt),
                  label: const Text('View All 928'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LroNoticeListScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('Manage Notices'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LroReportsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.summarize_outlined),
                  label: const Text('Reports'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Public Notice Feed',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: LroTheme.text(context),
                  fontWeight: FontWeight.bold,
                ),
          ),
          const Divider(),
          Expanded(
            child: feedAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (notices) {
                if (notices.isEmpty) {
                  return const Center(
                    child: Text('No published notices yet.'),
                  );
                }
                final sorted = [...notices]..sort(
                    (a, b) => (b.publicationDate ?? b.createdAt)
                        .compareTo(a.publicationDate ?? a.createdAt),
                  );
                return ListView.separated(
                  itemCount: sorted.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final n = sorted[index];
                    return ListTile(
                      title: Text(
                        n.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${n.content}\n'
                        '${n.publicationDate != null ? dateFmt.format(n.publicationDate!.toLocal()) : ''}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: LroStatusBadge(
                        status: n.status,
                        label: n.statusEnum.label,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LroNoticeDetailScreen(
                            noticeId: n.id,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Document Generators (LRO-SA)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _generatorLinks.map((entry) {
              return OutlinedButton.icon(
                onPressed: () => _openLink(context, entry.$2),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text('Open on LRO-SA website: ${entry.$1}'),
              );
            }).toList(),
          ),
        ],
      ),
    ),
    );
  }
}
