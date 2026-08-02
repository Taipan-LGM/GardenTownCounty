import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/remuneration_settings.dart';
import '../../providers/providers.dart';
import '../../widgets/standard_buttons.dart';

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

  final List<_StepFormRow> _stepRows = [];
  final List<RemunerationStep> _inactiveSteps = [];
  final _bankAccountNameController = TextEditingController();
  final _bankAccountNumberController = TextEditingController();
  final _bankAccountCodeController = TextEditingController();
  String _selectedBankName = 'Capitec Bank';

  static const List<String> _bankNames = <String>[
    'Capitec Bank',
    'Standard Bank',
    'FNB',
    'ABSA',
    'Nedbank',
    'TymeBank',
    'African Bank',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    for (final row in _stepRows) {
      row.dispose();
    }
    _bankAccountNameController.dispose();
    _bankAccountNumberController.dispose();
    _bankAccountCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await ref
          .read(remunerationServiceProvider)
          .getSettings();
      _settings = settings;
      _extraServices = List.of(settings.extraServices);
      _replaceStepRows(settings.allSteps);
      _bankAccountNameController.text = settings.bankAccountName;
      _bankAccountNumberController.text = settings.bankAccountNumber;
      _bankAccountCodeController.text = settings.bankAccountCode;
      _selectedBankName = _bankNames.contains(settings.bankName)
          ? settings.bankName
          : _bankNames.first;
    } catch (_) {
      _settings = RemunerationSettings.defaults();
      _extraServices = [];
      _replaceStepRows(_settings!.allSteps);
      _bankAccountNameController.text = 'Garden Town County';
      _bankAccountNumberController.text = '';
      _bankAccountCodeController.text = '';
      _selectedBankName = _bankNames.first;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final activeSteps = _stepRows
        .map(
          (row) => RemunerationStep(
            number: row.number,
            name: row.nameController.text.trim(),
            amount: double.tryParse(row.amountController.text.trim()) ?? -1,
          ),
        )
        .toList();
    final steps = [...activeSteps, ..._inactiveSteps]
      ..sort((a, b) => a.number.compareTo(b.number));

    if (activeSteps.isEmpty || activeSteps.any((step) => step.name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All step names are required.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (activeSteps.any((step) => step.amount < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All step amounts must be valid numbers.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    RemunerationStep legacyStep(int number, String name, double amount) =>
        activeSteps.where((step) => step.number == number).firstOrNull ??
        RemunerationStep(number: number, name: name, amount: amount);
    final step1 = legacyStep(1, RemunerationSettings.defaultStep1Name, 100);
    final step2 = legacyStep(2, RemunerationSettings.defaultStep2Name, 200);
    final step3 = legacyStep(3, RemunerationSettings.defaultStep3Name, 300);
    final step4 = legacyStep(4, RemunerationSettings.defaultStep4Name, 250);
    final step5 = legacyStep(5, RemunerationSettings.defaultStep5Name, 250);

    if (_bankAccountNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bank account name is required.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final settings = RemunerationSettings(
        id: _settings?.id ?? const Uuid().v4(),
        firestoreId: _settings?.firestoreId,
        step1Name: step1.name,
        step2Name: step2.name,
        step3Name: step3.name,
        step4Name: step4.name,
        step5Name: step5.name,
        step1Amount: step1.amount,
        step2Amount: step2.amount,
        step3Amount: step3.amount,
        step4Amount: step4.amount,
        step5Amount: step5.amount,
        steps: steps,
        bankAccountName: _bankAccountNameController.text.trim(),
        bankName: _selectedBankName,
        bankAccountNumber: _bankAccountNumberController.text.trim(),
        bankAccountCode: _bankAccountCodeController.text.trim(),
        extraServices: _extraServices,
        lastUpdated: DateTime.now().toUtc(),
        syncStatus: 'pending',
      );
      await ref.read(remunerationSettingsProvider.notifier).save(settings);
      _settings = settings;
      ref.read(appRefreshTickProvider.notifier).state++;
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

  void _replaceStepRows(List<RemunerationStep> steps) {
    for (final row in _stepRows) {
      row.dispose();
    }
    _stepRows
      ..clear()
      ..addAll(steps.where((step) => step.active).map(_StepFormRow.fromStep));
    _inactiveSteps
      ..clear()
      ..addAll(steps.where((step) => !step.active));
  }

  void _addStep() {
    final nextNumber =
        [
          ..._stepRows.map((row) => row.number),
          ..._inactiveSteps.map((step) => step.number),
        ].fold<int>(
          0,
          (highest, number) => number > highest ? number : highest,
        ) +
        1;
    setState(() {
      _stepRows.add(
        _StepFormRow.fromStep(
          RemunerationStep(
            number: nextNumber,
            name: 'Step $nextNumber',
            amount: 0,
          ),
        ),
      );
    });
  }

  void _removeStep(_StepFormRow row) {
    if (_stepRows.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one step is required.')),
      );
      return;
    }
    setState(() {
      _stepRows.remove(row);
      _inactiveSteps.add(
        RemunerationStep(
          number: row.number,
          name: row.nameController.text.trim().isEmpty
              ? 'Step ${row.number}'
              : row.nameController.text.trim(),
          amount: double.tryParse(row.amountController.text.trim()) ?? 0,
          active: false,
        ),
      );
      row.dispose();
    });
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
        title: Text(
          service == null ? 'Add Extra Service' : 'Edit Extra Service',
        ),
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: 'R ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          CancelButton(onPressed: () => Navigator.pop(context), text: 'Cancel'),
          service == null
              ? AddButton(
                  onPressed: () {
                    final desc = descriptionController.text.trim();
                    final amount = double.tryParse(
                      amountController.text.trim(),
                    );
                    if (desc.isEmpty || amount == null) return;
                    Navigator.pop(
                      context,
                      ExtraService(
                        id: const Uuid().v4(),
                        description: desc,
                        amount: amount,
                        isActive: true,
                        createdAt: DateTime.now().toUtc(),
                      ),
                    );
                  },
                  text: 'Add',
                )
              : EditButton(
                  onPressed: () {
                    final desc = descriptionController.text.trim();
                    final amount = double.tryParse(
                      amountController.text.trim(),
                    );
                    if (desc.isEmpty || amount == null) return;
                    Navigator.pop(
                      context,
                      ExtraService(
                        id: service.id,
                        description: desc,
                        amount: amount,
                        isActive: true,
                        createdAt: service.createdAt,
                      ),
                    );
                  },
                  text: 'Update',
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
          CancelButton(
            onPressed: () => Navigator.pop(context, false),
            text: 'Cancel',
          ),
          DeleteButton(
            onPressed: () => Navigator.pop(context, true),
            text: 'Delete',
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

  Widget _buildStepFields({required _StepFormRow row}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: row.nameController,
            decoration: InputDecoration(
              labelText: 'Step ${row.number} Description',
              prefixIcon: const Icon(Icons.route_outlined, color: Colors.blue),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _buildAmountField(
            label: 'Amount',
            controller: row.amountController,
            icon: Icons.payments_outlined,
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Remove Step ${row.number}',
          onPressed: () => _removeStep(row),
          icon: const Icon(Icons.delete_outline, color: Colors.red),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('RS Remuneration Settings')),
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
                      'RS Remuneration Setup',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (var index = 0; index < _stepRows.length; index++) ...[
                      _buildStepFields(row: _stepRows[index]),
                      if (index != _stepRows.length - 1)
                        const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        AddButton(
                          onPressed: _addStep,
                          text: 'Add Step',
                          icon: Icons.add_circle_outline,
                        ),
                        AddButton(
                          onPressed: _addExtraService,
                          text: 'Add Service',
                          icon: Icons.add,
                        ),
                        SaveButton(
                          onPressed: _saving ? null : _saveSettings,
                          text: 'Save Remuneration Settings',
                          isLoading: _saving,
                          icon: Icons.save,
                        ),
                      ],
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
                    const Text(
                      'Extra Services',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                ),
                                onPressed: () => _editExtraService(service),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bank Particulars',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _bankAccountNameController,
                      decoration: const InputDecoration(
                        labelText: 'Bank Account Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedBankName,
                      decoration: const InputDecoration(
                        labelText: 'Bank Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_balance),
                      ),
                      items: _bankNames
                          .map(
                            (name) => DropdownMenuItem<String>(
                              value: name,
                              child: Text(name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedBankName = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bankAccountNumberController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Bank Account Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bankAccountCodeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Bank Account Code',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.qr_code_2_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepFormRow {
  _StepFormRow.fromStep(RemunerationStep step)
    : number = step.number,
      nameController = TextEditingController(text: step.name),
      amountController = TextEditingController(
        text: step.amount.toStringAsFixed(2),
      );

  final int number;
  final TextEditingController nameController;
  final TextEditingController amountController;

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}
