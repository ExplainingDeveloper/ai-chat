import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'utils/login_method.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LoginMethod _loginMethod = LoginMethod();
  bool _isBusy = false;

  void _showMessage(String message) {
    print(message);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signOut() async {
    setState(() => _isBusy = true);
    try {
      await _signOutAndGoToLogin();
    } catch (e) {
      _showMessage('로그아웃에 실패했습니다: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _signOutAndGoToLogin() async {
    await _loginMethod.signOut();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              OutlinedButton(
                onPressed: _isBusy ? null : _signOut,
                child: const Text('로그아웃'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
