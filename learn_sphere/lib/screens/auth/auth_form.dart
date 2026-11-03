import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/tokens.dart';

enum AuthMode { signIn, register, reset }

/// Email + password + Google sign-in, shared by the phone and web layouts.
class AuthForm extends StatefulWidget {
  const AuthForm({super.key});

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  AuthMode _mode = AuthMode.signIn;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _setMode(AuthMode m) => setState(() {
        _mode = m;
        _error = null;
        _info = null;
      });

  String get _title {
    switch (_mode) {
      case AuthMode.signIn:
        return 'Welcome back';
      case AuthMode.register:
        return 'Create your account';
      case AuthMode.reset:
        return 'Reset your password';
    }
  }

  String get _subtitle {
    switch (_mode) {
      case AuthMode.signIn:
        return 'Sign in to see where your time went today.';
      case AuthMode.register:
        return 'Your usage and limits stay in sync on every device.';
      case AuthMode.reset:
        return "Enter your email and we'll send you a reset link.";
    }
  }

  String get _submitLabel {
    switch (_mode) {
      case AuthMode.signIn:
        return 'Sign in';
      case AuthMode.register:
        return 'Create account';
      case AuthMode.reset:
        return 'Send reset link';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      switch (_mode) {
        case AuthMode.signIn:
          await auth.signIn(_email.text, _password.text);
          break;
        case AuthMode.register:
          await auth.register(_name.text, _email.text, _password.text);
          break;
        case AuthMode.reset:
          await auth.sendPasswordReset(_email.text);
          if (mounted) {
            setState(() => _info =
                'Reset link sent to ${_email.text.trim()}. Check your inbox and spam folder.');
          }
          break;
      }
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    final auth = context.read<AuthService>();
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await auth.signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final register = _mode == AuthMode.register;
    final reset = _mode == AuthMode.reset;

    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_title, style: display(30)),
            const SizedBox(height: 6),
            Text(_subtitle, style: body(15, color: LS.slate, height: 1.4)),
            const SizedBox(height: 24),
            if (register) ...[
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                style: body(16),
                decoration: fieldDecoration('Your name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter your name.' : null,
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: reset ? TextInputAction.done : TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              style: body(16),
              decoration: fieldDecoration('Email'),
              onFieldSubmitted: reset ? (_) => _submit() : null,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Enter your email.';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                  return 'That email address does not look right.';
                }
                return null;
              },
            ),
            if (!reset) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: !_showPassword,
                textInputAction: TextInputAction.done,
                autofillHints: [
                  register ? AutofillHints.newPassword : AutofillHints.password
                ],
                style: body(16),
                onFieldSubmitted: (_) => _submit(),
                decoration: fieldDecoration(
                  'Password',
                  suffix: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    icon: Icon(_showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter your password.';
                  if (register && v.length < 6) {
                    return 'Use at least 6 characters.';
                  }
                  return null;
                },
              ),
            ],
            if (_mode == AuthMode.signIn)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _setMode(AuthMode.reset),
                  child: const Text('Forgot password?'),
                ),
              )
            else
              const SizedBox(height: 8),
            if (_error != null) _message(_error!, LS.rose, Icons.error_outline_rounded),
            if (_info != null) _message(_info!, LS.lagoon, Icons.mark_email_read_outlined),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(_submitLabel),
              ),
            ),
            if (!reset) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Divider(color: LS.line)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or', style: body(13, color: LS.slate)),
                  ),
                  const Expanded(child: Divider(color: LS.line)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _google,
                  icon: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        color: LS.paper, shape: BoxShape.circle),
                    child: Text('G',
                        style: display(15, color: LS.periwinkle, letterSpacing: 0)),
                  ),
                  label: const Text('Continue with Google'),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Center(child: _switcher()),
          ],
        ),
      ),
    );
  }

  Widget _message(String text, Color color, IconData icon) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: body(13.5,
                      weight: FontWeight.w600,
                      color: Color.lerp(color, LS.ink, 0.3)!,
                      height: 1.35)),
            ),
          ],
        ),
      );

  Widget _switcher() {
    switch (_mode) {
      case AuthMode.signIn:
        return _link('New to Learn Sphere?', 'Create an account', AuthMode.register);
      case AuthMode.register:
        return _link('Already have an account?', 'Sign in', AuthMode.signIn);
      case AuthMode.reset:
        return _link('Remembered it?', 'Back to sign in', AuthMode.signIn);
    }
  }

  Widget _link(String lead, String action, AuthMode target) => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('$lead ', style: body(14, color: LS.slate)),
          TextButton(
            onPressed: () => _setMode(target),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(action),
          ),
        ],
      );
}
