import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/wallet_notifier.dart';
import '../../data/providers/wallet_providers.dart';
import 'dart:core';

class SendSheetSol extends ConsumerStatefulWidget {
  const SendSheetSol({super.key});
  @override
  ConsumerState<SendSheetSol> createState() => _SendSheetSolState();
}

class _SendSheetSolState extends ConsumerState<SendSheetSol> {
  // ---------------- 輸入控制器 ----------------
  final _to = TextEditingController();               // 收款地址（base58）
  final _amt = TextEditingController(text: '0.001'); // 金額（SOL）

  // ---------------- UI 狀態 ----------------
  bool _sending = false;

  // ---------------- 單位轉換 ----------------
  /// SOL → lamports（BigInt）
  BigInt _solToLamports(String input) {
    final s = input.trim();
    if (s.isEmpty) return BigInt.zero;

    final parts = s.split('.');
    final whole = BigInt.parse(parts[0].isEmpty ? '0' : parts[0]);
    final fracStr = parts.length > 1 ? parts[1] : '';

    // 1 SOL = 1e9 lamports
    final decimals = 9;
    final cut = fracStr.length > decimals ? fracStr.substring(0, decimals) : fracStr;
    final frac = cut.isEmpty ? BigInt.zero : BigInt.parse(cut.padRight(decimals, '0'));

    return whole * BigInt.from(10).pow(decimals) + frac;
  }

  /// lamports → SOL（字串，小數 6 位，去尾零）
  String _lamportsToSolString(BigInt lamports) {
    final d = lamports.toDouble() / 1e9;
    final s = d.toStringAsFixed(6);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  /// 簡易 base58（不含 0 O I l），長度 32–44
  bool _isBase58Address(String s) =>
      RegExp(r"^[1-9A-HJ-NP-Za-km-z]{32,44}$").hasMatch(s.trim());

  // ---------------- Clipboard ----------------
  Future<void> _pasteAddress() async {
    final data = await Clipboard.getData('text/plain');
    final txt = (data?.text ?? '').trim();
    if (txt.isEmpty) return;
    setState(() => _to.text = txt);
  }

  // ---------------- Use Max ----------------
  /// 可選：你若想保留一點手續費緩衝，可把 buffer 改成 5000 lamports 之類
  void _useMax({required BigInt buffer}) {
    final st = ref.read(walletProvider);
    final bal = st.balanceWei ?? BigInt.zero; // 這裡把 balanceWei 當「最小單位」沿用，Sol 就是 lamports
    final usable = (bal > buffer) ? (bal - buffer) : BigInt.zero;
    _amt.text = _lamportsToSolString(usable);
    setState(() {});
  }

  // ---------------- Lifecycle ----------------
  @override
  void dispose() {
    _to.dispose();
    _amt.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final chain = ref.watch(currentChainProvider);   // 應該是 Solana Devnet
    final st = ref.watch(walletProvider);

    final balSol = _lamportsToSolString(st.balanceWei ?? BigInt.zero);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------- 標題列 ----------------
          Row(
            children: [
              Text('Send ${chain.symbol}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(chain.name, style: Theme.of(context).textTheme.labelSmall),
              ),
              const Spacer(),
            ],
          ),

          const SizedBox(height: 8),
          Text('Balance: $balSol ${chain.displaySymbol}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),

          // ---------------- 收款地址輸入（base58） ----------------
          Row(children: [
            Expanded(
              child: TextField(
                controller: _to,
                decoration: const InputDecoration(
                  labelText: 'To address (base58)',
                  border: OutlineInputBorder(),
                ),
                autocorrect: false,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _pasteAddress,
              icon: const Icon(Icons.paste),
              label: const Text('Paste'),
            ),
          ]),

          const SizedBox(height: 12),

          // ---------------- 金額輸入（SOL） ----------------
          Row(children: [
            Expanded(
              child: TextField(
                controller: _amt,
                decoration: InputDecoration(
                  labelText: 'Amount ${chain.displaySymbol}',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _useMax( buffer: BigInt.from(5000)), // 可改 _useMax(buffer: BigInt.from(5000))
              child: const Text('Max'),
            ),
          ]),

          const SizedBox(height: 8),

          // Solana 費用很低；這裡不顯示估算 gas/fee，簡潔一點
          Text(
            'Network fee is minimal on Solana (auto-estimated on-chain).',
            style: Theme.of(context).textTheme.bodySmall,
          ),

          const SizedBox(height: 12),

          // ---------------- 送出按鈕 ----------------
          FilledButton.icon(
            onPressed: _sending
                ? null
                : () async {
              final addr = _to.text.trim();
              final amtLamports = _solToLamports(_amt.text);

              if (!_isBase58Address(addr)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid base58 address')),
                );
                return;
              }
              if (amtLamports <= BigInt.zero) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid amount')),
                );
                return;
              }

              final bal = st.balanceWei ?? BigInt.zero;
              if (bal < amtLamports) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Insufficient balance (need ${_lamportsToSolString(amtLamports)} ${chain.displaySymbol}, '
                          'have $balSol ${chain.displaySymbol})',
                    ),
                  ),
                );
                return;
              }

              setState(() => _sending = true);
              try {
                // sendNative(toHex: addr, amountWei: amtLamports)
                final hash = ref.read(walletProvider.notifier).sendNative(toHex: addr, amountWei: amtLamports);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Send success')),
                );

                Navigator.pop(context);
                await ref.read(walletProvider.notifier).refreshBalance();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Send failed: $e')),
                );
              } finally {
                if (mounted) setState(() => _sending = false);
              }
            },
            icon: _sending
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.call_made),
            label: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
