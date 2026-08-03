import 'activity_log.dart';
import 'member.dart';
import 'secretary_remuneration.dart';

class LiveViewData {
  const LiveViewData({
    required this.members,
    required this.remunerationRecords,
    required this.activities,
    required this.generatedAt,
  });

  final List<Member> members;
  final List<SecretaryRemuneration> remunerationRecords;
  final List<ActivityLog> activities;
  final DateTime generatedAt;

  List<Member> get activeMembers => members
      .where((member) => !member.deleted && !member.isCancelled)
      .toList(growable: false);

  List<SecretaryRemuneration> get activeRecords => remunerationRecords
      .where((record) => !record.isDeleted)
      .toList(growable: false);

  int get totalMembers => activeMembers.length;

  int get existingMembers => activeMembers
      .where(
        (member) =>
            member.registrationStatus == 'complete' ||
            member.registrationStatus == 'fully_fledged',
      )
      .length;

  int get newMembers => totalMembers - existingMembers;

  Map<int, int> get membersByStep {
    final counts = <int, int>{for (var step = 1; step <= 5; step++) step: 0};
    final memberIdsByStep = <int, Set<String>>{
      for (var step = 1; step <= 5; step++) step: <String>{},
    };
    for (final record in activeRecords) {
      final step = _stepFromType(record.type);
      if (step != null) memberIdsByStep[step]!.add(record.memberId);
    }
    for (final entry in memberIdsByStep.entries) {
      counts[entry.key] = entry.value.length;
    }
    return counts;
  }

  int get trackedNewMembers =>
      membersByStep.values.fold(0, (sum, count) => sum + count);

  double get totalEarned =>
      activeRecords.fold(0, (sum, record) => sum + record.amount);

  double get totalPaid => activeRecords
      .where((record) => record.status == 'paid')
      .fold(0, (sum, record) => sum + record.amount);

  double get totalOutstanding => activeRecords
      .where((record) => record.status != 'paid')
      .fold(0, (sum, record) => sum + record.amount);

  List<LiveViewSecretaryMetric> get secretaryMetrics {
    final grouped = <String, List<SecretaryRemuneration>>{};
    final membersById = {for (final member in activeMembers) member.id: member};
    for (final record in activeRecords) {
      grouped.putIfAbsent(record.secretaryId, () => []).add(record);
    }
    final metrics = grouped.entries.map((entry) {
      final records = entry.value;
      final name = records
          .map((record) => record.secretaryName.trim())
          .firstWhere((value) => value.isNotEmpty, orElse: () => 'Unassigned');
      final completionDays = <double>[];
      for (final record in records) {
        final member = membersById[record.memberId];
        final step = _stepFromType(record.type);
        if (member == null || step == null) continue;
        final end = _completionDate(member, step);
        final start = step == 1
            ? (member.registrationDate ?? member.createdAt)
            : _completionDate(member, step - 1);
        if (start == null || end == null || end.isBefore(start)) continue;
        completionDays.add(
          end.difference(start).inMinutes / Duration.minutesPerDay,
        );
      }
      return LiveViewSecretaryMetric(
        secretaryId: entry.key,
        secretaryName: name,
        membersCompleted: records
            .map((record) => record.memberId)
            .toSet()
            .length,
        totalEarned: records.fold(0, (sum, record) => sum + record.amount),
        amountPaid: records
            .where((record) => record.status == 'paid')
            .fold(0, (sum, record) => sum + record.amount),
        amountOutstanding: records
            .where((record) => record.status != 'paid')
            .fold(0, (sum, record) => sum + record.amount),
        averageCompletionDays: completionDays.isEmpty
            ? null
            : completionDays.fold(0.0, (sum, days) => sum + days) /
                  completionDays.length,
      );
    }).toList();
    metrics.sort((a, b) {
      final aDays = a.averageCompletionDays ?? double.infinity;
      final bDays = b.averageCompletionDays ?? double.infinity;
      return aDays.compareTo(bDays);
    });
    return metrics;
  }

  List<LiveViewStepMetric> get stepMetrics {
    final counts = membersByStep;
    return List.generate(5, (index) {
      final step = index + 1;
      final durations = <double>[];
      for (final member in activeMembers) {
        final end = _completionDate(member, step);
        final start = step == 1
            ? (member.registrationDate ?? member.createdAt)
            : _completionDate(member, step - 1);
        if (start == null || end == null || end.isBefore(start)) continue;
        durations.add(end.difference(start).inMinutes / Duration.minutesPerDay);
      }
      final averageDays = durations.isEmpty
          ? null
          : durations.fold(0.0, (sum, value) => sum + value) / durations.length;
      final count = counts[step] ?? 0;
      return LiveViewStepMetric(
        step: step,
        count: count,
        averageDays: averageDays,
        completionRate: trackedNewMembers == 0 ? 0 : count / trackedNewMembers,
      );
    });
  }

  List<LiveViewGrowthPoint> get weeklyGrowth {
    final now = generatedAt.toLocal();
    final startOfThisWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));
    return List.generate(6, (index) {
      final weekStart = startOfThisWeek.subtract(
        Duration(days: (5 - index) * 7),
      );
      final weekEnd = weekStart.add(const Duration(days: 7));
      final count = activeMembers.where((member) {
        final created = (member.createdAt ?? member.registrationDate)
            ?.toLocal();
        return created != null &&
            !created.isBefore(weekStart) &&
            created.isBefore(weekEnd);
      }).length;
      return LiveViewGrowthPoint(weekStart: weekStart, count: count);
    });
  }

  List<ActivityLog> get recentActivities {
    final result = [...activities]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return result.take(8).toList(growable: false);
  }

  static int? _stepFromType(String type) {
    final match = RegExp(r'^step([1-5])$').firstMatch(type.toLowerCase());
    return match == null ? null : int.parse(match.group(1)!);
  }

  static DateTime? _completionDate(Member member, int step) => switch (step) {
    1 => member.step1CompletionDate,
    2 => member.step2CompletionDate,
    3 => member.step3CompletionDate,
    4 => member.step4CompletionDate,
    5 => member.step5CompletionDate,
    _ => null,
  };
}

class LiveViewSecretaryMetric {
  const LiveViewSecretaryMetric({
    required this.secretaryId,
    required this.secretaryName,
    required this.membersCompleted,
    required this.totalEarned,
    required this.amountPaid,
    required this.amountOutstanding,
    required this.averageCompletionDays,
  });

  final String secretaryId;
  final String secretaryName;
  final int membersCompleted;
  final double totalEarned;
  final double amountPaid;
  final double amountOutstanding;
  final double? averageCompletionDays;
}

class LiveViewStepMetric {
  const LiveViewStepMetric({
    required this.step,
    required this.count,
    required this.averageDays,
    required this.completionRate,
  });

  final int step;
  final int count;
  final double? averageDays;
  final double completionRate;

  String get status {
    final days = averageDays;
    if (days == null) return 'No data';
    if (days <= 3.5) return 'Good';
    if (days <= 6) return 'Average';
    return 'Bottleneck';
  }
}

class LiveViewGrowthPoint {
  const LiveViewGrowthPoint({required this.weekStart, required this.count});

  final DateTime weekStart;
  final int count;
}
