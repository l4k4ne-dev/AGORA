import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final TextEditingController _peerIdController = TextEditingController();
  final TextEditingController _publicKeyController = TextEditingController();
  MobileScannerController _scannerController = MobileScannerController();
  bool _showQrScanner = false;
  bool _isLoading = false;
  String? _scannedData;
  bool _isSuccess = false;

  @override
  void dispose() {
    _peerIdController.dispose();
    _publicKeyController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null && mounted) {
        setState(() {
          _scannedData = barcode.rawValue;
        });
        // Stop scanning after first successful scan
        _scannerController.stop();
        break;
      }
    }
  }

  Future<void> _addContact() async {
    final peerId = _peerIdController.text.trim();
    final publicKey = _publicKeyController.text.trim();

    if (peerId.isEmpty || publicKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isSuccess = false;
    });

    try {
      // Save locally
      await StorageService.addContact(peerId, publicKey);
      
      // Send to backend
      final success = await ApiService.addContact(peerId, publicKey);
      
      if (success) {
        setState(() {
          _isSuccess = true;
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contact added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) Navigator.pop(context);
          });
        }
      } else {
        throw Exception('Backend returned error');
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

  void _showMyQRCode() async {
    // Get user's peer ID from storage to show in QR code
    final identity = await StorageService.getIdentity();
    final peerId = identity?.peerId ?? 'No identity yet';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: peerId,
              version: QrVersions.auto,
              size: 200.0,
            ),
            const SizedBox(height: 16),
            Text(
              peerId,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Contact'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: _showMyQRCode,
            tooltip: 'Show My QR Code',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_showQrScanner) ...[
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),
              ),
              const SizedBox(height: 16),
              if (_scannedData != null) ...[
                Text(
                  'Scanned: $_scannedData',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    // Try to parse scanned data as peer_id:public_key
                    final parts = _scannedData!.split(':');
                    if (parts.length == 2) {
                      _peerIdController.text = parts[0];
                      _publicKeyController.text = parts[1];
                    } else {
                      // If just peer ID, user needs to enter public key manually
                      _peerIdController.text = _scannedData!;
                    }
                    setState(() {
                      _showQrScanner = false;
                      _scannedData = null;
                    });
                    // Restart controller for next use
                    _scannerController = MobileScannerController();
                  },
                  child: const Text('Use Scanned Data'),
                ),
              ],
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showQrScanner = false;
                    _scannedData = null;
                  });
                  // Restart controller for next use
                  _scannerController = MobileScannerController();
                },
                icon: const Icon(Icons.close),
                label: const Text('Cancel Scanner'),
              ),
              const SizedBox(height: 24),
            ],
            TextField(
              controller: _peerIdController,
              decoration: const InputDecoration(
                labelText: 'Peer ID',
                hintText: 'Enter peer ID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _publicKeyController,
              decoration: const InputDecoration(
                labelText: 'Public Key',
                hintText: 'Enter public key (base64)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _addContact,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.person_add),
              label: Text(_isLoading ? 'Adding...' : 'Add Contact'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _showQrScanner = true;
                  _scannedData = null;
                });
                // Start scanning
                _scannerController.start();
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tip: Share your Peer ID and Public Key with your friend, or scan their QR code.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
