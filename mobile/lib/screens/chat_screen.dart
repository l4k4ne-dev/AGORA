import 'package:flutter/material.dart';
import 'package:agora_app/services/api_service.dart';
import 'package:agora_app/services/storage_service.dart';
import 'package:pointycastle/export.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

class ChatScreen extends StatefulWidget {
  final String peerId;
  final String publicKey;

  const ChatScreen({
    super.key,
    required this.peerId,
    required this.publicKey,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  Uint8List? _sharedKey;

  // ── Crypto helpers ──────────────────────────────────────────────

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  static String _bytesToHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _deriveSharedKey(Uint8List myPrivKey, Uint8List theirPubKey) {
    final x25519 = X25519();
    final sharedSecret = x25519.scalarMult(myPrivKey, theirPubKey);
    // HKDF-SHA256 to derive 32-byte key
    final hkdf = HKDFKeyDerivator(SHA256Digest());
    hkdf.init(HkdfParameters(sharedSecret, 32, Uint8List(0), utf8.encode('agora-chat')));
    final key = Uint8List(32);
    hkdf.deriveKey(null, 0, key, 0);
    return key;
  }

  static String _encrypt(String plaintext, Uint8List key) {
    final rng = Random.secure();
    final nonce = Uint8List.fromList(List<int>.generate(12, (_) => rng.nextInt(256)));
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));
    final input = utf8.encode(plaintext) as Uint8List;
    final output = cipher.process(input);
    return _bytesToHex(Uint8List.fromList([...nonce, ...output]));
  }

  static String _decrypt(String hexData, Uint8List key) {
    try {
      final data = _hexToBytes(hexData);
      final nonce = data.sublist(0, 12);
      final ciphertextWithTag = data.sublist(12);
      final cipher = GCMBlockCipher(AESEngine())
        ..init(false, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));
      final output = cipher.process(ciphertextWithTag);
      return utf8.decode(output);
    } catch (_) {
      return hexData; // fallback: afișează raw dacă nu poate decripta
    }
  }

  // ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initCrypto();
    _loadMessages();
    _startPolling();
  }

  Future<void> _initCrypto() async {
    final identity = await StorageService.getIdentity();
    if (identity != null && widget.publicKey.isNotEmpty) {
      try {
        final myPriv = identity.privateKeyBytes;
        final theirPub = _hexToBytes(widget.publicKey);
        setState(() {
          _sharedKey = _deriveSharedKey(myPriv, theirPub);
        });
      } catch (_) {
        // crypto init failed, fallback to plaintext
      }
    }
  }

  Timer? _pollingTimer;

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _loadMessages());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final pending = await ApiService.getPendingMessages(widget.peerId);
      setState(() {
        _messages.clear();
        _messages.addAll(pending.map((m) {
          final raw = m['encrypted_content'] as String? ?? '';
          final content = _sharedKey != null ? _decrypt(raw, _sharedKey!) : raw;
          return {
            'content': content,
            'isMe': false,
            'timestamp': DateTime.now(),
          };
        }));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // În producție, aici ar trebui criptat mesajul cu cheia publică
      // Pentru MVP, trimitem ca text simplu (simulat criptat)
      final payload = _sharedKey != null ? _encrypt(content, _sharedKey!) : content;
      final success = await ApiService.sendMessage(widget.peerId, payload);
    
      if (success) {
        setState(() {
          _messages.add({
            'content': content,
            'isMe': true,
            'timestamp': DateTime.now(),
          });
          _messageController.clear();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to send message');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.peerId),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['isMe'] as bool;
                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.blue : Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                msg['content'] as String,
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: Colors.blue),
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
