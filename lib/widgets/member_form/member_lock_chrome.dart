import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/member.dart';
import '../../providers/providers.dart';
import '../../services/temporary_access_service.dart';
import '../cancel_button.dart';
import '../member_lock_banners.dart';

/// Lock / temporary-access banners shown above the member form.
///
/// Renders nothing unless the member is locked.
class MemberLockChrome extends ConsumerWidget {
  const MemberLockChrome({
    super.key,
    required this.member,
    required this.onMemberUpdated,
    required this.onAccessVerified,
  });

  final Member member;

  /// Called with the refreshed member after unlock / grant / revoke.
  final ValueChanged<Member> onMemberUpdated;

  /// Called once a temporary access code has been accepted.
  final VoidCallback onAccessVerified;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider);
    final verified = ref.watch(verifiedTempAccessIdsProvider).contains(member.id);
    final users = ref.watch(appUsersProvider).valueOrNull ?? const [];
    final logs = (ref.watch(temporaryAccessLogsProvider).valueOrNull ?? const [])
        .where((l) => l.memberId == member.id)
        .toList();
    String? nameOf(String? id) {
      if (id == null) return null;
      for (final u in users) {
        if (u.id == id) return u.displayName;
      }
      return id;
    }

    if (!member.isLocked) return const SizedBox.shrink();

    if (user?.isAdmin == true) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AdminLockedBanner(
          member: member,
          lockedByName: nameOf(member.lockedBy),
          recentLogs: logs,
          onUnlock: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Unlock Member'),
                content: Text('Unlock ${member.fullName}?'),
                actions: [
                  CancelButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    text: 'Cancel',
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Unlock'),
                  ),
                ],
              ),
            );
            if (ok != true || user == null) return;
            final unlocked = await ref
                .read(memberLockServiceProvider)
                .unlock(member: member, actor: user);
            onMemberUpdated(unlocked);
            ref.invalidate(membersProvider);
            ref.invalidate(lockedMembersProvider);
            ref.invalidate(temporaryAccessLogsProvider);
          },
          onGrantAccess: () async {
            await showGrantTemporaryAccessDialog(
              context: context,
              ref: ref,
              member: member,
            );
            final refreshed =
                await ref.read(memberRepositoryProvider).getById(member.id);
            if (refreshed != null) {
              onMemberUpdated(refreshed);
            }
            ref.invalidate(lockedMembersProvider);
            ref.invalidate(temporaryAccessLogsProvider);
          },
          onRevokeAccess: () async {
            if (user == null) return;
            final cleared = await ref
                .read(temporaryAccessServiceProvider)
                .revoke(member: member, actor: user);
            final next = {...ref.read(verifiedTempAccessIdsProvider)}
              ..remove(member.id);
            ref.read(verifiedTempAccessIdsProvider.notifier).state = next;
            onMemberUpdated(cleared);
            ref.invalidate(lockedMembersProvider);
            ref.invalidate(temporaryAccessLogsProvider);
          },
        ),
      );
    }

    if (verified &&
        TemporaryAccessService.isGrantValidFor(member, user!.id)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TemporaryAccessActiveBanner(
          member: member,
          grantedByName: nameOf(member.temporaryAccessGrantedBy),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LockedMemberBanner(
        member: member,
        lockedByName: nameOf(member.lockedBy),
        onEnterCode: user == null
            ? null
            : () async {
                final ok = await showEnterTemporaryAccessCodeDialog(
                  context: context,
                  ref: ref,
                  member: member,
                  secretary: user,
                );
                if (ok) {
                  final next = {...ref.read(verifiedTempAccessIdsProvider)}
                    ..add(member.id);
                  ref.read(verifiedTempAccessIdsProvider.notifier).state =
                      next;
                  onAccessVerified();
                }
              },
        onRequestAccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Contact the System Administrator for a temporary access code.',
              ),
            ),
          );
        },
      ),
    );
  }
}
