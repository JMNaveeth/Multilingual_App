import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multilingual_chat_app/providers/auth_provider.dart';
import 'package:multilingual_chat_app/screens/auth/login_screen.dart';
import 'package:multilingual_chat_app/screens/auth/register_screen.dart';
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
      home: authState.when(
        data: (user) => user == null ? const LoginScreen() : const HomeScreen(),
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

