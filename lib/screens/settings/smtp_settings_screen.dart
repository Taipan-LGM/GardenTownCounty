import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_strings.dart';
import '../../providers/providers.dart';
import '../../services/lro_email_service.dart' as email;

/// Admin-only SMTP configuration for LRO email publishing.
///
/// All fields are required. The password is stored in the OS secure store
/// (flutter_secure_storage). A successful Test Connection is required before
/// the configuration can be saved.
class SmtpSettingsScreen extends ConsumerStatefulWidget {
  const SmtpSettingsScreen({super.key});

  @override
  ConsumerState<SmtpSettingsScreen> createState() => _SmtpSettingsScreenState();
}

class _SmtpSettingsScreenState extends ConsumerState<SmtpSettingsScreen> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '587');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _fromNameCtrl = TextEditingController(text: 'Garden Town County LRO');
  final _testRecipientCtrl = TextEditingController();

  bool _ssl = true;
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  String? _testError;
  String? _testSuccess;
  bool _testedOk = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await email.LroEmailService.loadSmtpConfig();
    if (!mounted) return;
    setState(() {
      if (cfg != null) {
        _hostCtrl.text = cfg.host;
        _portCtrl.text = cfg.port.toString();
        _userCtrl.text = cfg.username;
        _passCtrl.text = cfg.password;
        _fromCtrl.text = cfg.fromAddress;
        _fromNameCtrl.text = cfg.fromName;
        _ssl = cfg.ssl;
        // Pre-fill the test recipient with the From address for convenience.
        _testRecipientCtrl.text = cfg.fromAddress;
      }
      _loading = false;
    });
  }

  int? _parsePort() {
    final v = int.tryParse(_portCtrl.text.trim());
    return (v == null || v <= 0 || v > 65535) ? null : v;
  }

  bool get _formValid {
    final port = _parsePort();
    return _hostCtrl.text.trim().isNotEmpty &&
        port != null &&
        _userCtrl.text.trim().isNotEmpty &&
        _passCtrl.text.isNotEmpty &&
        _fromCtrl.text.trim().isNotEmpty &&
        _fromNameCtrl.text.trim().isNotEmpty;
  }

  Future<void> _test() async {
    final port = _parsePort();
    if (!_formValid || port == null) {
      setState(() {
        _testError = 'Fill in all fields with valid values before testing.';
        _testSuccess = null;
      });
      return;
    }
    setState(() {
      _testing = true;
      _testError = null;
      _testSuccess = null;
    });
    try {
      final result = await email.LroEmailService.testConnection(
        host: _hostCtrl.text.trim(),
        port: port,
        username: _userCtrl.text.trim(),
        password: _passCtrl.text,
        fromAddress: _fromCtrl.text.trim(),
        fromName: _fromNameCtrl.text.trim(),
        ssl: _ssl,
        recipient: _testRecipientCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _testing = false;
        if (result.sent) {
          _testedOk = true;
          _testSuccess = 'Test email sent to ${_testRecipientCtrl.text.trim()}.';
          _testError = null;
        } else {
          _testedOk = false;
          _testError = result.reason;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testedOk = false;
        _testError = 'Test failed: $e';
      });
    }
  }

  Future<void> _save() async {
    final port = _parsePort();
    if (!_formValid || port == null) {
      setState(() => _testError = 'Fill in all fields with valid values.');
      return;
    }
    if (!_testedOk) {
      setState(() => _testError =
          'Run a successful Test Connection before saving SMTP settings.');
      return;
    }
    setState(() => _saving = true);
    try {
      await email.LroEmailService.saveSmtpConfig(
        host: _hostCtrl.text.trim(),
        port: port,
        username: _userCtrl.text.trim(),
        password: _passCtrl.text,
        fromAddress: _fromCtrl.text.trim(),
        fromName: _fromNameCtrl.text.trim(),
        ssl: _ssl,
      );
      if (!mounted) return;
      // Also send a confirmation test email to the configured From address.
      await email.LroEmailService.testConnection(
        host: _hostCtrl.text.trim(),
        port: port,
        username: _userCtrl.text.trim(),
        password: _passCtrl.text,
        fromAddress: _fromCtrl.text.trim(),
        fromName: _fromNameCtrl.text.trim(),
        ssl: _ssl,
        recipient: _fromCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings(ref.read(appLanguageProvider)).smtpSaved),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _testError = 'Could not save SMTP settings: $e';
      });
    }
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _fromCtrl.dispose();
    _fromNameCtrl.dispose();
    _testRecipientCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ref.watch(appLanguageProvider));
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.email_outlined, size: 24),
            const SizedBox(width: 8),
            Text(strings.smtpSettings),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: isAdmin
          ? _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(strings)
          : _buildNotFound(strings),
    );
  }

  Widget _buildNotFound(AppStrings strings) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                strings.adminOnlyCountySettings,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Only Administrators can configure SMTP email.',
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  Widget _buildBody(AppStrings strings) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.smtpSettingsSubtitle,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _hostCtrl,
                  decoration: const InputDecoration(
                    labelText: 'SMTP Host',
                    hintText: 'smtp.gmail.com',
                    prefixIcon: Icon(Icons.dns),
                  ),
                  onChanged: (_) => setState(() => _testedOk = false),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _portCtrl,
                  decoration: const InputDecoration(
                    labelText: 'SMTP Port',
                    hintText: '587',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() => _testedOk = false),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(
                    labelText: 'SMTP Username',
                    hintText: 'admin@county.org',
                    prefixIcon: Icon(Icons.person),
                  ),
                  onChanged: (_) => setState(() => _testedOk = false),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  decoration: const InputDecoration(
                    labelText: 'SMTP Password',
                    hintText: '••••••••',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  onChanged: (_) => setState(() => _testedOk = false),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _fromCtrl,
                  decoration: const InputDecoration(
                    labelText: 'From Email Address',
                    hintText: 'noreply@county.org',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  onChanged: (_) => setState(() => _testedOk = false),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _fromNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'From Name',
                    hintText: 'Garden Town County LRO',
                    prefixIcon: Icon(Icons.badge),
                  ),
                  onChanged: (_) => setState(() => _testedOk = false),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text(strings.smtpEnableTls),
                  subtitle: Text(strings.smtpEnableTlsHint),
                  value: _ssl,
                  onChanged: (v) => setState(() {
                    _ssl = v;
                    _testedOk = false;
                  }),
                  secondary: const Icon(Icons.enhanced_encryption),
                ),
                const Divider(height: 24),
                Text(
                  strings.smtpTestSection,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _testRecipientCtrl,
                  decoration: InputDecoration(
                    labelText: strings.smtpTestRecipient,
                    hintText: 'you@county.org',
                    prefixIcon: const Icon(Icons.send),
                  ),
                ),
                const SizedBox(height: 8),
                if (_testError != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_testSuccess != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testSuccess!,
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _testing ? null : _test,
                        icon: _testing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: Text(_testing
                            ? strings.testing
                            : strings.testConnection),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: (_saving || !_formValid || !_testedOk) ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? strings.smtpSaving : strings.save),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
                if (!_testedOk)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      strings.smtpMustTest,
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange.shade700),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}
