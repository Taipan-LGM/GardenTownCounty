import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_strings.dart';
import '../../providers/providers.dart';
import '../home/lro_publications_screen.dart';
import '../../widgets/legal_disclaimer_dialog.dart';
import '../../widgets/standard_buttons.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _userController;
  late final TextEditingController _passwordController;
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  /// Demo credentials are only pre-filled / hinted in debug builds.
  static bool get _showDemoHint => kDebugMode;

  @override
  void initState() {
    super.initState();
    _userController = TextEditingController(
      text: _showDemoHint ? AppConstants.demoUsername : '',
    );
    _passwordController = TextEditingController(
      text: _showDemoHint ? AppConstants.demoPassword : '',
    );
  }

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await ref
          .read(authServiceProvider)
          .signIn(
            usernameOrEmail: _userController.text,
            password: _passwordController.text,
          );

      if (!mounted) return;
      final accepted = await ensureConfidentialityAccepted(
        context,
        onReject: () {
          ref.read(authServiceProvider).signOut();
          ref.read(authUserProvider.notifier).state = null;
        },
      );
      if (!accepted) {
        if (mounted) {
          setState(
            () => _error = AppStrings(
              ref.read(appLanguageProvider),
            ).mustAcceptAgreement,
          );
        }
        return;
      }

      ref.read(authUserProvider.notifier).state = user;

      unawaited(
        ref
            .read(activityServiceProvider)
            .record(
              userName: user.displayName,
              action: 'Login',
              captureGps: true,
            )
            .then((_) => ref.invalidate(activitiesProvider)),
      );

      if (!mounted) return;
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ref.watch(appLanguageProvider));
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.forestGreen, Color(0xFF0E2A22)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        strings.appName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textTheme.headlineSmall?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.appSlogan,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: textTheme.bodyMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppConstants.versionLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.lightBlue.shade200
                              : Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.signInToContinue,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textTheme.bodyMedium?.color),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _userController,
                        decoration: InputDecoration(
                          labelText: strings.usernameOrEmail,
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? strings.requiredField
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: strings.password,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? strings.requiredField
                            : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SubmitButton(
                        onPressed: _loading ? null : _submit,
                        text: strings.signIn,
                        isLoading: _loading,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: const Text('LRO Publications'),
                              ),
                              body: const LroPublicationsScreen(),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('LRO Publications'),
                      ),
                      if (_showDemoHint) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Debug: ${AppConstants.demoUsername} / ${AppConstants.demoPassword}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
