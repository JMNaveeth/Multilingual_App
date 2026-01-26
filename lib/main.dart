import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multilingual_chat_app/providers/auth_provider.dart';
import 'package:multilingual_chat_app/screens/auth/login_screen.dart';
import 'package:multilingual_chat_app/screens/home/home_screen.dart';
import 'package:multilingual_chat_app/services/auth_service.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MultilingualChatApp(),
    ),
  );
}

class MultilingualChatApp extends ConsumerWidget {
  const MultilingualChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Multilingual Chat App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
      routes: {
       // '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

