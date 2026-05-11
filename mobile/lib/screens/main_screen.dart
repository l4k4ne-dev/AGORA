import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final IdentityService _identityService = IdentityService();
  final HomeNodeService _homeNodeService = HomeNodeService();
  List<dynamic> _contacts = [];
  Map<String, String> _identity = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _identity = await _identityService.getIdentity();
    _contacts = await _homeNodeService.getContacts(_identity['peer_id']!);
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Agora - ${_identity['peer_id'] ?? '?'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => Navigator.pushNamed(context, '/add_contact'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _contacts.length,
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                return ListTile(
                  title: Text(contact['alias'] ?? 'Unknown'),
                  subtitle: Text(contact['peer_id'] ?? ''),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/chat',
                      arguments: contact,
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadData,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
