import 'package:flutter/material.dart';
import 'package:agora_app/services/api_service.dart';
import 'package:agora_app/services/storage_service.dart';
import 'package:cryptography/cryptography.dart';
import 'dart:async';
import 'dart:convert';
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
  List<int>? _sharedKey;
  Timer? _pollingTimer;

  // ── Crypto ────────────────────────────────────────────────────

  static String _bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }

  static Future<List<int>> _deriveSharedKey(
      List<int> myPrivKey, List<int> theirPubKey) async {
    final x25519 = X25519();
    final keyPair = await x25519.newKeyPairFromSeed(myPrivKey);
    final remotePublicKey =
        SimplePublicKey(theirPubKey, type: KeyPairType.x25519);
    final sharedSecret = await x25519.sharedSecretKey(
        keyPair: keyPair, remotePublicKey: remotePublicKey);
    final sharedBytes = await sharedSecret.extractBytes();
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(sharedBytes),
      info: utf8.encode('agora-chat'),
    );
    return derived.extractBytes();
  }

  static Future<String> _encrypt(String plaintext, List<int> key) async {
    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(key);
    final nonce = algorithm.newNonce();
    final box = await algorithm.encrypt(utf8.encode(plaintext),
        secretKey: secretKey, nonce: nonce);
    return _bytesToHex([...nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  static Future<String> _decrypt(String hexData, List<int> key) async {
    try {
      final data = _hexToBytes(hexData);
      final nonce = data.sublist(0, 12);
      final mac = data.sublist(data.length - 16);
      final cipherText = data.sublist(12, data.length - 16);
      final algorithm = AesGcm.with256bits();
      final secretKey = SecretKey(key);
      final box = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));
      final plain = await algorithm.decrypt(box, secretKey: secretKey);
      return utf8.decode(plain);
    } catch (_) {
      return hexData;
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────

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
        final myPriv = identity.privateKeyBytes.toList();
        final theirPub = _hexToBytes(widget.publicKey);
        final key = await _deriveSharedKey(myPriv, theirPub);
        if (mounted) setState(() => _sharedKey = key);
      } catch (_) {}
    }
  }

  void _startPolling() {
    _pollingTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _loadMessages());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final pending = await ApiService.getPendingMessages(widget.peerId);
      final decrypted = <Map<String, dynamic>>[];
      for (final m in pending) {
        final raw = m['encrypted_content'] as String? ?? '';
        final content =
            _sharedKey != null ? await _decrypt(raw, _sharedKey!) : raw;
        decrypted.add({
          'content': content,
          'isMe': false,
          'timestamp': DateTime.now(),
        });
      }
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(decrypted);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final payload =
          _sharedKey != null ? await _encrypt(content, _sharedKey!) : content;
      final success = await ApiService.sendMessage(widget.peerId, payload);
      if (success) {
        if (mounted) {
          setState(() {
            _messages.add({
              'content': content,
              'isMe': true,
              'timestamp': DateTime.now(),
            });
            _messageController.clear();
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to send');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── UI ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.peerId),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMessages),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('No messages yet',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['isMe'] as bool;
                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    isMe ? Colors.blue : Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                msg['content'] as String,
                                style: TextStyle(
                                    color: isMe
                                        ? Colors.white
                                        : Colors.black),
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
                    offset: const Offset(0, -2))
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
                          horizontal: 12, vertical: 8),
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
                          child: CircularProgressIndicator(strokeWidth: 2))
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
