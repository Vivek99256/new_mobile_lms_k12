import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/auth_controller.dart';
import '../core/config.dart';
import 'design.dart';
import 'theme.dart';

/// Sign in: navy header with the mark, then a white sheet with the form.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AuthController>().login(
      _email.text,
      _password.text,
    );
    if (!mounted) return;
    // On success AuthController flips to signedIn and the root swaps this page out.
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  Future<void> _forgot() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ForgotPasswordSheet(initialEmail: _email.text),
    );
  }

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 18),
        prefixIconConstraints: const BoxConstraints(minWidth: 46),
        suffixIcon: suffix,
      );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        height: 1.38,
        fontWeight: FontWeight.w500,
        color: Brand.ink2,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Brand.navy,
        resizeToAvoidBottomInset: true,
        body: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        28,
                        MediaQuery.paddingOf(context).top + 32,
                        28,
                        32,
                      ),
                      child: const Rise(
                        offset: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LogoTile(),
                            SizedBox(height: 16),
                            Text(
                              AppConfig.appName,
                              style: TextStyle(
                                fontSize: 26,
                                height: 1.31,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: -.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 1, end: 0),
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, child) => Transform.translate(
                          offset: Offset(0, v * 60),
                          child: child,
                        ),
                        child: Container(
                          padding: EdgeInsets.fromLTRB(
                            24,
                            32,
                            24,
                            24 + MediaQuery.paddingOf(context).bottom,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                          ),
                          child: Form(
                            key: _form,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Rise(
                                  delay: Duration(milliseconds: 200),
                                  child: Text(
                                    'Welcome back',
                                    style: TextStyle(
                                      fontSize: 24,
                                      height: 1.33,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Sign in to continue to your account.',
                                  style: TextStyle(color: Brand.ink2),
                                ),
                                const SizedBox(height: 20),
                                if (_error != null) ...[
                                  Shake(
                                    trigger: _error,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Brand.err0,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFFCA5A5),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.only(top: 1),
                                            child: Icon(
                                              Icons.warning_amber_rounded,
                                              size: 18,
                                              color: Brand.err,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _error!,
                                              style: const TextStyle(
                                                color: Brand.err,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                _label('Email address'),
                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [
                                    AutofillHints.username,
                                    AutofillHints.email,
                                  ],
                                  textInputAction: TextInputAction.next,
                                  decoration: _decoration(
                                    'you@example.com',
                                    Icons.mail_outline_rounded,
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? 'Enter your email address.'
                                      : null,
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(child: _label('Password')),
                                    TextButton(
                                      onPressed: _busy ? null : _forgot,
                                      child: const Text('Forgot password?'),
                                    ),
                                  ],
                                ),
                                TextFormField(
                                  controller: _password,
                                  obscureText: !_show,
                                  autofillHints: const [AutofillHints.password],
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  decoration: _decoration(
                                    'Enter your password',
                                    Icons.lock_outline_rounded,
                                    suffix: IconButton(
                                      tooltip: _show
                                          ? 'Hide password'
                                          : 'Show password',
                                      color: const Color(0xFF64748B),
                                      icon: Icon(
                                        _show
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                      onPressed: () =>
                                          setState(() => _show = !_show),
                                    ),
                                  ),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Enter your password.'
                                      : null,
                                ),
                                const SizedBox(height: 20),
                                FilledButton(
                                  onPressed: _busy ? null : _submit,
                                  child: _busy
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Sign in'),
                                ),
                                const Spacer(),
                                const SizedBox(height: 20),
                                const Text(
                                  'Your session ends after 30 minutes of inactivity.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.33,
                                    fontWeight: FontWeight.w500,
                                    color: Brand.ink3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet({required this.initialEmail});
  final String initialEmail;

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AuthController>().sendPasswordReset(
      _email.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      _sent = error == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        32 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _sent ? 'Check your email' : 'Forgot your password?',
            style: const TextStyle(
              fontSize: 20,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _sent
                ? 'If ${_email.text.trim()} matches an account, a reset link is on its way.'
                : "Enter the email tied to your account and we'll send you a reset link.",
            style: const TextStyle(color: Brand.ink2),
          ),
          if (!_sent) ...[
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Email address',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.38,
                  fontWeight: FontWeight.w500,
                  color: Brand.ink2,
                ),
              ),
            ),
            TextField(
              controller: _email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.mail_outline_rounded,
                  size: 18,
                  color: Brand.primaryDark,
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 46),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _send,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send reset link'),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    );
  }
}
