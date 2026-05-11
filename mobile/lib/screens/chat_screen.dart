import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final dynamic contact;
  const ChatScreen({super.key, required this.contact});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final IdentityService _identityService = IdentityService();
  final HomeNodeService _homeNodeService = HomeNodeService();
  List<dynamic> _messages = [];
  final _controller = TextEditingController();
  String _myPeerId = '';

  @override
  void initState() {
    super.initState();
    _loadIdentity();
  }

  Future<void> _loadIdentity() async {
    final identity = await _identityService.getIdentity();
    setState(() {
      _myPeerId = identity['peer_id']!;
    });
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final msgs = await _homeNodeService.getMessages(widget.contact['peer_id']);
    if (mounted) {
      setState(() {
        _messages = msgs;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;
    
    final success = await _homeNodeService.sendMessage(
      _myPeerId,
      widget.contact['peer_id'],
      _controller.text,
    );

    if (success) {
      _controller.clear();
      _loadMessages();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contact['alias'] ?? 'Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['from_id'] == _myPeerId;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue[100] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(msg['content']),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
