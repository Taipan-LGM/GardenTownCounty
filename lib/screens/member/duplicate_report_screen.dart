import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/member.dart';
import '../../providers/providers.dart';
import '../../widgets/form_dialog_title.dart';

/// Admin dashboard listing SA ID / Global Record collisions (data repair).
class DuplicateReportScreen extends ConsumerStatefulWidget {
  const DuplicateReportScreen({super.key});

  @override
  ConsumerState<DuplicateReportScreen> createState() =>
      _DuplicateReportScreenState();
}

class _DuplicateReportScreenState extends ConsumerState<DuplicateReportScreen> {
  late Future<List<({String field, String value, List<Member> members})>>
      _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(databaseServiceProvider).findDuplicateMemberGroups();
  }

  Future<void> _openMember(Member member) async {
    ref.read(selectedMemberIdProvider.notifier).state = member.id;
    ref.read(appSectionProvider.notifier).state = AppSection.memberInfo;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppTheme.forestGreen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Duplicate Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.labelText,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  color: AppTheme.labelText,
                  onPressed: () => setState(_reload),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final groups = snapshot.data ?? const [];
              if (groups.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 64,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Duplicates Found',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.bodyText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'All members have unique SA IDs and Global Record Nos.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '⚠️ ${groups.length} potential duplicate group(s) found. Please review.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final g = groups[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ExpansionTile(
                            leading: Icon(
                              Icons.copy_all,
                              color: Colors.red.shade700,
                            ),
                            title: Text(
                              'Duplicate ${g.field}: ${g.value}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('${g.members.length} members'),
                            children: [
                              for (final m in g.members)
                                ListTile(
                                  title: Text(m.fullName),
                                  subtitle: Text(
                                    'SA: ${m.saId} · GR: ${m.globalRecordNo}',
                                  ),
                                  trailing: TextButton(
                                    onPressed: () => _openMember(m),
                                    child: const Text('Open'),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Optional dialog wrapper if opened as modal.
Future<void> showDuplicateReportDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Column(
          children: [
            const Padding(
              padding: formDialogTitlePadding,
              child: FormDialogTitle(title: 'Duplicate Management'),
            ),
            const Divider(height: 1),
            const Expanded(child: DuplicateReportScreen()),
          ],
        ),
      ),
    ),
  );
}
