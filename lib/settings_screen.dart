import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'utils/login_method.dart';
import 'utils/mfa_challenge.dart';
import 'utils/prompt_dialog.dart';

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

  Future<void> _enrollPhoneMultiFactor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('먼저 로그인해주세요.');
      return;
    }

    final phoneNumber = await promptForText(
      context,
      title: '새로 등록할 휴대폰 번호',
      hintText: '+821012345678',
      keyboardType: TextInputType.phone,
    );
    if (phoneNumber == null || phoneNumber.isEmpty || !mounted) {
      return;
    }

    setState(() => _isBusy = true);
    try {
      // MFA 등록은 민감한 작업이라 최근 로그인 상태가 필요하다.
      // 오래된 세션이면 requires-recent-login 오류가 나므로 먼저 재인증한다.
      final reauthenticated = await _reauthenticate(
        user,
        dialogTitle: '① 기존 번호로 받은 인증번호',
      );
      if (!reauthenticated || !mounted) {
        return;
      }

      await _loginMethod.startPhoneMultiFactorEnrollment(
        user: user,
        phoneNumber: phoneNumber,
        onVerificationFailed: (FirebaseAuthException e) {
          _showMessage('인증번호 발송에 실패했습니다: ${e.message}');
        },
        onCodeSent: (String verificationId, int? resendToken) async {
          final smsCode = await promptForText(
            context,
            title: '② 새 번호로 받은 인증번호',
            hintText: '6자리 인증번호',
            keyboardType: TextInputType.number,
          );
          if (smsCode == null || smsCode.isEmpty || !mounted) {
            return;
          }

          try {
            await _loginMethod.confirmPhoneMultiFactorEnrollment(
              user: user,
              verificationId: verificationId,
              smsCode: smsCode,
            );
            _showMessage('다중 인증 등록이 완료되었습니다.');
          } on FirebaseAuthException catch (e) {
            _showMessage('다중 인증 등록에 실패했습니다: ${e.message}');
          }
        },
      );
    } on FirebaseAuthException catch (e) {
      _showMessage('인증번호 발송에 실패했습니다: ${e.message}');
    } catch (e) {
      _showMessage('재인증에 실패했습니다: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  /// 민감한 작업 직전에 재인증한다. 이 계정에 이미 다중 인증이 등록되어 있으면
  /// 재인증 자체가 2차인증을 요구하는데, 그 경우 여기서 SMS로 먼저 해소한다.
  Future<bool> _reauthenticate(User user, {required String dialogTitle}) async {
    try {
      await _loginMethod.reauthenticateWithGoogle(user);
      return true;
    } on FirebaseAuthMultiFactorException catch (e) {
      if (!mounted) {
        return false;
      }
      final credential = await resolveSecondFactorChallenge(
        context: context,
        loginMethod: _loginMethod,
        resolver: e.resolver,
        onMessage: _showMessage,
        dialogTitle: dialogTitle,
      );
      return credential != null;
    }
  }

  Future<void> _unenrollPhoneFactor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('먼저 로그인해주세요.');
      return;
    }

    setState(() => _isBusy = true);
    try {
      final factors = await _loginMethod.getEnrolledFactors(user);
      if (!mounted) {
        return;
      }
      final phoneFactors = factors.whereType<PhoneMultiFactorInfo>().toList();
      if (phoneFactors.isEmpty) {
        _showMessage('등록된 다중 인증 수단이 없습니다.');
        return;
      }

      PhoneMultiFactorInfo target;
      if (phoneFactors.length == 1) {
        target = phoneFactors.first;
      } else {
        final selected = await choosePhoneFactor(
          context,
          phoneFactors,
          title: '해제할 번호를 선택하세요',
        );
        if (selected == null || !mounted) {
          return;
        }
        target = selected;
      }

      final confirmed = await _confirmUnenroll(target);
      if (confirmed != true || !mounted) {
        return;
      }

      final reauthenticated = await _reauthenticate(
        user,
        dialogTitle: '본인 확인을 위한 인증번호',
      );
      if (!reauthenticated || !mounted) {
        return;
      }

      await _loginMethod.unenrollFactor(user, target);
      _showMessage('다중 인증이 해제되었습니다.');
    } on FirebaseAuthException catch (e) {
      _showMessage('다중 인증 해제에 실패했습니다: ${e.message}');
    } catch (e) {
      _showMessage('다중 인증 해제에 실패했습니다: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<bool?> _confirmUnenroll(PhoneMultiFactorInfo factor) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('다중 인증 해제'),
          content: Text(
            '${factor.displayName ?? factor.phoneNumber} 번호를 다중 인증에서 해제할까요?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                '해제',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signOut() async {
    setState(() => _isBusy = true);
    try {
      await _loginMethod.signOut();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      _showMessage('로그아웃에 실패했습니다: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
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
                onPressed: _isBusy ? null : _enrollPhoneMultiFactor,
                child: const Text('휴대폰 다중 인증 등록'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isBusy ? null : _unenrollPhoneFactor,
                child: const Text('다중 인증 해제'),
              ),
              const SizedBox(height: 12),
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
