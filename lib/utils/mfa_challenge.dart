import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_method.dart';
import 'prompt_dialog.dart';

/// 로그인/재인증 도중 던져진 [FirebaseAuthMultiFactorException]을
/// SMS 2차인증으로 해소한다. 성공하면 [UserCredential]을,
/// 실패하거나 사용자가 취소하면 null을 반환한다.
Future<UserCredential?> resolveSecondFactorChallenge({
  required BuildContext context,
  required LoginMethod loginMethod,
  required MultiFactorResolver resolver,
  required void Function(String message) onMessage,
  String dialogTitle = '인증번호 입력',
}) async {
  final phoneHints = resolver.hints.whereType<PhoneMultiFactorInfo>().toList();
  if (phoneHints.isEmpty) {
    onMessage('지원하지 않는 다중 인증 수단입니다.');
    return null;
  }

  PhoneMultiFactorInfo hint;
  if (phoneHints.length == 1) {
    hint = phoneHints.first;
  } else {
    final selected = await choosePhoneFactor(
      context,
      phoneHints,
      title: '인증에 사용할 번호를 선택하세요',
    );
    if (selected == null) {
      return null;
    }
    hint = selected;
  }

  final completer = Completer<UserCredential?>();

  try {
    await loginMethod.verifyPhoneSecondFactor(
      resolver: resolver,
      hint: hint,
      onVerificationFailed: (FirebaseAuthException e) {
        onMessage('인증번호 발송에 실패했습니다: ${e.message}');
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
      onCodeSent: (String verificationId, int? resendToken) async {
        final smsCode = await promptForText(
          context,
          title: dialogTitle,
          hintText: '6자리 인증번호',
          keyboardType: TextInputType.number,
        );
        if (smsCode == null || smsCode.isEmpty) {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
          return;
        }

        try {
          final credential = await loginMethod.confirmSecondFactorSignIn(
            resolver: resolver,
            verificationId: verificationId,
            smsCode: smsCode,
          );
          if (!completer.isCompleted) {
            completer.complete(credential);
          }
        } on FirebaseAuthException catch (e) {
          onMessage('2차 인증에 실패했습니다: ${e.message}');
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }
      },
    );
  } on FirebaseAuthException catch (e) {
    onMessage('인증번호 발송에 실패했습니다: ${e.message}');
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  }

  return completer.future;
}
