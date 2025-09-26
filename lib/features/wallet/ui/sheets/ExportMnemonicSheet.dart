import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:wallet_demo/features/wallet/data/core/keyService/core/key_service.dart';
import '../../data/core/keyService/keyServiceProvider.dart';
import 'package:screen_protector/screen_protector.dart';

class ExportMnemonicSheet extends ConsumerStatefulWidget {
  const ExportMnemonicSheet({super.key});
  @override
  ConsumerState<ExportMnemonicSheet> createState() => _ExportMnemonicSheetState();
}

class _ExportMnemonicSheetState extends ConsumerState<ExportMnemonicSheet> {
  final _auth = LocalAuthentication();
  String? _mnemonic;
  bool _revealed = false;
  bool _ackRisk = false;
  Timer? _autoHideTimer;
  int _seconds = 30;

  @override
  void initState() {
    super.initState();
    _protectScreen(true);
    _authenticateAndLoad();
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _protectScreen(false);
    super.dispose();
  }

  Future<void> _protectScreen(bool on) async {
    try {
      if (on) {
        await ScreenProtector.preventScreenshotOn();
      } else {
        await ScreenProtector.preventScreenshotOff();
      }
    } catch (_) {}
  }

  Future<void> _authenticateAndLoad() async {
    try {
      final ks = ref.read(keyServiceProvider);
      final m = await ks.exportMnemonic();
      if (!mounted) return;
      setState(() => _mnemonic = m);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed：$e')));
        Navigator.pop(context);
      }
    }
  }

  void _startAutoHide() {
    _autoHideTimer?.cancel();
    _seconds = 30;
    _autoHideTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_seconds <= 1) {
        setState(() {
          _revealed = false;
        });
        t.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  Future<void> _copyWithAutoClear() async {
    if (_mnemonic == null) return;
    await Clipboard.setData(ClipboardData(text: _mnemonic!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied. Clears in 30s.')),
    );
    Future.delayed(const Duration(seconds: 30), () {
      Clipboard.setData(const ClipboardData(text: '')); // 清空
    });
  }

  @override
  Widget build(BuildContext context) {
    final words = (_mnemonic ?? '').split(' ').where((w) => w.isNotEmpty).toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _mnemonic == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export seed', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Do not screenshot/share. Anyone with this seed owns your funds.'),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _ackRisk,
              onChanged: (v) => setState(() => _ackRisk = v ?? false),
              title: const Text('I understand the risk.'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: _revealed
                    ? Column(
                  children: [
                    if (_revealed) Text('Auto-hide in: $_seconds s'),
                    const SizedBox(height: 8),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, childAspectRatio: 3.3, crossAxisSpacing: 8, mainAxisSpacing: 8,
                        ),
                        itemCount: words.length,
                        itemBuilder: (_, i) {
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Center(child: Text('${i + 1}. ${words[i]}')),
                          );
                        },
                      ),
                    ),
                  ],
                )
                    : const Center(child: Text('"Hidden • Check risk and tap「Show」')),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: !_ackRisk ? null : () {
                      setState(() => _revealed = true);
                      _startAutoHide();
                    },
                    child: const Text('Show'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: !_ackRisk || !_revealed ? null : _copyWithAutoClear,
                    child: const Text('Copied. Clears in 30s'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
