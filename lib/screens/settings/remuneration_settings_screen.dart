import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/remuneration_settings.dart';
import '../../providers/providers.dart';

/// Admin screen to configure RS step amounts + extra services.
///
/// // NEW ADDITION - Delete this file to revert RS remuneration settings UI.
class RemunerationSettingsScreen extends ConsumerStatefulWidget {
  const RemunerationSettingsScreen({super.key});

  @override
  ConsumerState<RemunerationSettingsScreen> createState() =>
      _RemunerationSettingsScreenState();
}

class _RemunerationSettingsScreenState
    extends ConsumerState<RemunerationSettingsScreen> {
  RemunerationSettings? _settings;
  List<ExtraService> _extraServices = [];
  bool _isLoading = true;
  bool _saving = false;

  final _step2Controller = TextEditingController();
  final _step3Controller = TextEditingController();
  final _step4Controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _step2Controller.dispose();
    _step3Controller.dispose();
    _step4Controller.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings =
          await ref.read(remunerationServiceProvider).getSettings();
      _settings = settings;
      _extraServices = List.of(settings.extraServices);
      _step2Controller.text = settings.step2Amount.toStringAsFixed(2);
      _step3Controller.text = settings.step3Amount.toStringAsFixed(2);
      _step4Controller.text = settings.step4Amount.toStringAsFixed(2);
    } catch (_) {
      _settings = RemunerationSettings.defaults();
      _extraServices = [];
      _step2Controller.text = '200.00';
      _step3Controller.text = '300.00';
      _step4Controller.text = '250.00';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      final settings = RemunerationSettings(
        id: _settings?.id ?? const Uuid().v4(),
        firestoreId: _settings?.firestoreId,
        step2Amount: double.parse(_step2Controller.text),
        step3Amount: double.parse(_step3Controller.text),
        step4Amount: double.parse(_step4Controller.text),
        extraServices: _extraServices,
        lastUpdated: DateTime.now().toUtc(),
        syncStatus: 'pending',
      );
      await ref.read(remunerationServiceProvider).saveSettings(settings);
      _settings = settings;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Remuneration settings saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<ExtraService?> _showExtraServiceDialog({ExtraService? service}) async {
    final descriptionController = TextEditingController(
      text: service?.description ?? '',
    );
    final amountController = TextEditingController(
      text: service?.amount.toStringAsFixed(2) ?? '0.00',
    );

    return showDialog<ExtraService>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(service == null ? 'Add Extra Service' : 'Edit Extra Service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Service Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: 'R ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final desc = descriptionController.text.trim();
              final amount = double.tryParse(amountController.text.trim());
              if (desc.isEmpty || amount == null) return;
              Navigator.pop(
                context,
                ExtraService(
                  id: service?.id ?? const Uuid().v4(),
                  description: desc,
                  amount: amount,
                  isActive: true,
                  createdAt: service?.createdAt ?? DateTime.now().toUtc(),
                ),
              );
            },
            child: Text(service == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _addExtraService() async {
    final result = await _showExtraServiceDialog();
    if (result != null) setState(() => _extraServices.add(result));
  }

  Future<void> _editExtraService(ExtraService service) async {
    final result = await _showExtraServiceDialog(service: service);
    if (result == null) return;
    final index = _extraServices.indexWhere((e) => e.id == service.id);
    if (index >= 0) {
      setState(() => _extraServices[index] = result);
    }
  }

  Future<void> _deleteExtraService(ExtraService service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Extra Service?'),
        content: Text('Delete "${service.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _extraServices.removeWhere((e) => e.id == service.id));
    }
  }

  Widget _buildAmountField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue),
        prefixText: 'R ',
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('RS Remuneration Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Step Completion Amounts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildAmountField(
                      label: 'Step 2 (Global 528)',
                      controller: _step2Controller,
                      icon: Icons.numbers,
                    ),
                    const SizedBox(height: 12),
                    _buildAmountField(
                      label: 'Step 3 (Global 928)',
                      controller: _step3Controller,
                      icon: Icons.numbers,
                    ),
                    const SizedBox(height: 12),
                    _buildAmountField(
                      label: 'Step 4 (LRO)',
                      controller: _step4Controller,
                      icon: Icons.gavel,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Extra Services',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addExtraService,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Service'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_extraServices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No extra services added yet.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      )
                    else
                      ..._extraServices.map((service) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.work, color: Colors.blue),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      service.description,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'R ${service.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editExtraService(service),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteExtraService(service),
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
            ElevatedButton.icon(
              onPressed: _saving ? null : _saveSettings,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save Remuneration Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
