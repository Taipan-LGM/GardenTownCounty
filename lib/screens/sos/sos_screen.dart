import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/member.dart';
import '../../models/sos_preset.dart';
import '../../providers/providers.dart';
import '../../services/messaging_service.dart';

enum SosAudience { single, selected, all }

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  final _messageController = TextEditingController();
  final _presetTitleController = TextEditingController();
  SosAudience _audience = SosAudience.single;
  String? _singleMemberId;
  final Set<String> _selectedIds = {};
  MessageChannel _channel = MessageChannel.whatsapp;
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _presetTitleController.dispose();
    super.dispose();
  }

  Future<void> _createPreset() async {
    final title = _presetTitleController.text.trim();
    final message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preset needs a title and message.')),
      );
      return;
    }
    await ref.read(databaseServiceProvider).upsertSosPreset(
          SosPreset.create(title: title, message: message),
        );
    await ref.read(syncEngineProvider).pushPending();
    _presetTitleController.clear();
    ref.invalidate(sosPresetsProvider);
  }

  Future<void> _send(List<Member> allMembers) async {
    final recipients = _resolveRecipients(allMembers);
    setState(() => _sending = true);
    try {
      await ref.read(messagingServiceProvider).send(
            channel: _channel,
            message: _messageController.text,
            recipients: recipients,
          );
      final user = ref.read(authUserProvider);
      if (user != null) {
        await ref.read(activityServiceProvider).record(
              userName: user.displayName,
              action:
                  'Sent SOS via ${_channel.name} to ${recipients.length} member(s)',
              captureGps: false,
            );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Opened ${_channel.name} for ${recipients.length} recipient(s).',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  List<Member> _resolveRecipients(List<Member> all) {
    switch (_audience) {
      case SosAudience.single:
        return all.where((m) => m.id == _singleMemberId).toList();
      case SosAudience.selected:
        return all.where((m) => _selectedIds.contains(m.id)).toList();
      case SosAudience.all:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider);
    final presetsAsync = ref.watch(sosPresetsProvider);

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (members) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'SOS Messaging',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.bodyText,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _messageController,
                                maxLines: 8,
                                decoration: const InputDecoration(
                                  labelText: 'SOS Message',
                                  alignLabelWithHint: true,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _presetTitleController,
                                      decoration: const InputDecoration(
                                        labelText: 'Standardised SOS title',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: _createPreset,
                                    child: const Text('Save Preset'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Presets',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Expanded(
                                child: presetsAsync.when(
                                  data: (presets) => ListView.builder(
                                    itemCount: presets.length,
                                    itemBuilder: (context, index) {
                                      final preset = presets[index];
                                      return ListTile(
                                        dense: true,
                                        title: Text(preset.title),
                                        subtitle: Text(
                                          preset.message,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onTap: () => setState(
                                          () => _messageController.text =
                                              preset.message,
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete_outline),
                                          onPressed: () async {
                                            await ref
                                                .read(databaseServiceProvider)
                                                .softDeleteSosPreset(preset.id);
                                            ref.invalidate(sosPresetsProvider);
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                  loading: () => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  error: (e, _) => Text('$e'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Recipients'),
                              RadioListTile<SosAudience>(
                                title: const Text('Single Member'),
                                value: SosAudience.single,
                                groupValue: _audience,
                                onChanged: (v) =>
                                    setState(() => _audience = v!),
                              ),
                              if (_audience == SosAudience.single)
                                DropdownButtonFormField<String>(
                                  initialValue: _singleMemberId,
                                  decoration: const InputDecoration(
                                    labelText: 'Member',
                                  ),
                                  items: members
                                      .map(
                                        (m) => DropdownMenuItem(
                                          value: m.id,
                                          child: Text(m.fullName),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _singleMemberId = v),
                                ),
                              RadioListTile<SosAudience>(
                                title: const Text('Selected Individuals'),
                                value: SosAudience.selected,
                                groupValue: _audience,
                                onChanged: (v) =>
                                    setState(() => _audience = v!),
                              ),
                              if (_audience == SosAudience.selected)
                                Expanded(
                                  child: ListView(
                                    children: members.map((m) {
                                      return CheckboxListTile(
                                        dense: true,
                                        value: _selectedIds.contains(m.id),
                                        title: Text(m.fullName),
                                        onChanged: (checked) {
                                          setState(() {
                                            if (checked == true) {
                                              _selectedIds.add(m.id);
                                            } else {
                                              _selectedIds.remove(m.id);
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ),
                              RadioListTile<SosAudience>(
                                title: const Text('All Members'),
                                value: SosAudience.all,
                                groupValue: _audience,
                                onChanged: (v) =>
                                    setState(() => _audience = v!),
                              ),
                              const Divider(),
                              SegmentedButton<MessageChannel>(
                                segments: const [
                                  ButtonSegment(
                                    value: MessageChannel.whatsapp,
                                    label: Text('WhatsApp'),
                                    icon: Icon(Icons.chat),
                                  ),
                                  ButtonSegment(
                                    value: MessageChannel.email,
                                    label: Text('Email'),
                                    icon: Icon(Icons.email_outlined),
                                  ),
                                ],
                                selected: {_channel},
                                onSelectionChanged: (value) => setState(
                                  () => _channel = value.first,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed:
                                    _sending ? null : () => _send(members),
                                icon: const Icon(Icons.send),
                                label: Text(
                                  _sending ? 'Sending…' : 'Send SOS',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
