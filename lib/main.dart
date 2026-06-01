import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat_list_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final FirebaseOptions firebaseOptions = await _firebaseOptionsWithEnvApiKey();
  await Firebase.initializeApp(options: firebaseOptions);

  runApp(const MyApp());
}

Future<FirebaseOptions> _firebaseOptionsWithEnvApiKey() async {
  final Map<String, String> env = await _loadDotEnv();
  final String? apiKey = env['GEMINI_API_KEY'];

  if (apiKey == null || apiKey.isEmpty) {
    return DefaultFirebaseOptions.currentPlatform;
  }

  if (kIsWeb) {
    return FirebaseOptions(
      apiKey: apiKey,
      appId: DefaultFirebaseOptions.web.appId,
      messagingSenderId: DefaultFirebaseOptions.web.messagingSenderId,
      projectId: DefaultFirebaseOptions.web.projectId,
      authDomain: DefaultFirebaseOptions.web.authDomain,
      storageBucket: DefaultFirebaseOptions.web.storageBucket,
    );
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return FirebaseOptions(
        apiKey: apiKey,
        appId: DefaultFirebaseOptions.android.appId,
        messagingSenderId: DefaultFirebaseOptions.android.messagingSenderId,
        projectId: DefaultFirebaseOptions.android.projectId,
        storageBucket: DefaultFirebaseOptions.android.storageBucket,
      );
    case TargetPlatform.iOS:
      return FirebaseOptions(
        apiKey: apiKey,
        appId: DefaultFirebaseOptions.ios.appId,
        messagingSenderId: DefaultFirebaseOptions.ios.messagingSenderId,
        projectId: DefaultFirebaseOptions.ios.projectId,
        storageBucket: DefaultFirebaseOptions.ios.storageBucket,
        iosBundleId: DefaultFirebaseOptions.ios.iosBundleId,
      );
    case TargetPlatform.macOS:
      return FirebaseOptions(
        apiKey: apiKey,
        appId: DefaultFirebaseOptions.macos.appId,
        messagingSenderId: DefaultFirebaseOptions.macos.messagingSenderId,
        projectId: DefaultFirebaseOptions.macos.projectId,
        storageBucket: DefaultFirebaseOptions.macos.storageBucket,
        iosBundleId: DefaultFirebaseOptions.macos.iosBundleId,
      );
    case TargetPlatform.windows:
      return FirebaseOptions(
        apiKey: apiKey,
        appId: DefaultFirebaseOptions.windows.appId,
        messagingSenderId: DefaultFirebaseOptions.windows.messagingSenderId,
        projectId: DefaultFirebaseOptions.windows.projectId,
        authDomain: DefaultFirebaseOptions.windows.authDomain,
        storageBucket: DefaultFirebaseOptions.windows.storageBucket,
      );
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return DefaultFirebaseOptions.currentPlatform;
  }
}

Future<Map<String, String>> _loadDotEnv() async {
  try {
    final String raw = await rootBundle.loadString('.env');
    final Map<String, String> values = <String, String>{};

    for (final String line in raw.split('\n')) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }

      final int equalsIndex = trimmed.indexOf('=');
      if (equalsIndex <= 0) {
        continue;
      }

      final String key = trimmed.substring(0, equalsIndex).trim();
      String value = trimmed.substring(equalsIndex + 1).trim();

      if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
        value = value.substring(1, value.length - 1);
      }
      if (value.startsWith("'") && value.endsWith("'") && value.length >= 2) {
        value = value.substring(1, value.length - 1);
      }

      values[key] = value;
    }

    return values;
  } on FlutterError {
    return <String, String>{};
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gemini AI Chat',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF3F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const ChatListScreen(),
    );
  }
}
