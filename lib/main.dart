import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multilingual_chat_app/providers/auth_provider.dart';
import 'package:multilingual_chat_app/screens/auth/login_screen.dart';
import 'package:multilingual_chat_app/screens/auth/register_screen.dart';
import 'package:multilingual_chat_app/screens/home/home_screen.dart';
import 'package:multilingual_chat_app/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Allow local .env config when app is run without --dart-define.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // It's okay if .env is missing as long as --dart-define values are provided.
  }

  if (SupabaseService.isConfigured) {
    await Supabase.initialize(
      url: SupabaseService.supabaseUrl,
      anonKey: SupabaseService.supabaseAnonKey,
    );
  }

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
    if (kDebugMode) {
      authState.when(
        data: (user) =>
            debugPrint('[App] authState=data hasUser=${user != null}'),
        loading: () => debugPrint('[App] authState=loading'),
        error: (e, _) => debugPrint('[App] authState=error $e'),
      );
    }

    return MaterialApp(
      title: 'ec communication',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: authState.when(
        data: (user) => user != null ? const HomeScreen() : const LoginScreen(),
        loading: () => const Scaffold(
          backgroundColor: Color(0xFF0D0E1A),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text(
                  'Loading...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        error: (e, st) => Scaffold(
          appBar: AppBar(title: const Text('Connection error')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off, size: 64, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  const Text(
                    'Unable to connect to Supabase',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.toString(),
                    style: const TextStyle(color: Colors.black54),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      await ref.read(authProvider.notifier).refreshUser();
                    },
                    child: const Text('Retry'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Configure Supabase'),
                          content: const SelectableText(
                            'Run app with:\n\nflutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY\n\nThen press Retry.',
                          ),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close')),
                          ],
                        ),
                      );
                    },
                    child: const Text('How to configure Supabase'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
