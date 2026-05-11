import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'screens/add_contact_screen.dart';
import 'screens/chat_screen.dart';

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
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MainScreen(),
      routes: {
        '/add_contact': (context) => const AddContactScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/chat') {
          return MaterialPageRoute(
            builder: (context) => ChatScreen(contact: settings.arguments),
          );
        }
        return null;
      },
    );
  }
}
