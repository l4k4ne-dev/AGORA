import 'package:flutter/material.dart';
import 'screens/conversations_list.dart';
import 'services/storage_service.dart';

void main() {
  runApp(const AgoraApp());
}

class AgoraApp extends StatelessWidget {
  const AgoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agora',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isInitializing = true;
  String _statusMessage = 'Initializing...';
  bool _showMigrationDialog = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _statusMessage = 'Loading identity...';
      });

      // Real cryptographic identity via secure storage.
      // Auto-migrates legacy SharedPreferences identity (destructive).
      final (_, wasNewlyGenerated) =
          await StorageService.loadOrCreateIdentity();

      if (wasNewlyGenerated) {
        // Clear stale contacts — they were tied to invalid legacy keys.
        await StorageService.clearContacts();
      }

      setState(() {
        _statusMessage =
            wasNewlyGenerated ? 'Identity created!' : 'Identity loaded';
        _showMigrationDialog = wasNewlyGenerated;
      });
      
      // Așteaptă puțin pentru UX
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      if (_showMigrationDialog) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('🔐 Identity regenerated'),
            content: const Text(
              'Your Agora identity has been regenerated with real cryptographic keys.\n\n'
              '• Old contacts must re-add you (you have a new peer ID)\n'
              '• Your keys are stored securely on this device only\n'
              '• Current build is NOT E2E yet — rebuild in progress',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const ConversationsListScreen(),
        ),
      );
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              'Agora',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_isInitializing)
              const CircularProgressIndicator()
            else
              const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
