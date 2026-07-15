import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Future<String?> promptForText(
  BuildContext context, {
  required String title,
  required String hintText,
  TextInputType? keyboardType,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          autofocus: true,
          decoration: InputDecoration(hintText: hintText),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('확인'),
          ),
        ],
      );
    },
  );
}

Future<PhoneMultiFactorInfo?> choosePhoneFactor(
  BuildContext context,
  List<PhoneMultiFactorInfo> hints, {
  String title = '번호를 선택하세요',
}) {
  return showDialog<PhoneMultiFactorInfo>(
    context: context,
    builder: (dialogContext) {
      return SimpleDialog(
        title: Text(title),
        children: hints.map((hint) {
          return SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(hint),
            child: Text(hint.displayName ?? hint.phoneNumber),
          );
        }).toList(),
      );
    },
  );
}
