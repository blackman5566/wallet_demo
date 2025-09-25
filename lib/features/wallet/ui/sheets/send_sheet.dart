import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_demo/features/wallet/data/core/keyService/core/key_service.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/credentials.dart';
import 'package:wallet_demo/features/wallet/data/providers/wallet_providers.dart';

import '../../data/core/keyService/keyServiceProvider.dart';
import '../../data/providers/wallet_notifier.dart';
import '../widgets/tx_detail_page.dart';

/// ---------------------------------------------------------------------------
/// SendSheet（ETH 轉帳 BottomSheet）
///
/// 功能特色：
/// 1) 使用者輸入收款地址與金額，會自動估算 Gas 與手續費（加 20% buffer）。
/// 2) 提供「貼上地址」與「用最大金額」兩種輔助功能。
/// 3) 基本輸入驗證（地址格式正確、金額大於 0、餘額足夠）。
/// 4) 按下送出後會呼叫 provider 發送交易並更新餘額。
///
/// 為什麼用 ConsumerStatefulWidget？
/// - 需要管理本地 UI 狀態（例如：TextEditingController、_sending 標記、估算結果）。
/// - 又需要 Riverpod 的 ref，所以繼承 ConsumerStatefulWidget 最合適。
/// ---------------------------------------------------------------------------
class SendSheet extends ConsumerStatefulWidget {
  const SendSheet({super.key});
  @override
  ConsumerState<SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends ConsumerState<SendSheet> {
  // ---------------- 輸入控制器 ----------------
  final _to = TextEditingController();      // 收款地址輸入框
  final _amt = TextEditingController(text: '0.001'); // 金額輸入框，預設填入 0.001 ETH

  // ---------------- UI 狀態 ----------------
  bool _sending = false;          // 是否正在送出交易
  BigInt? _estFeeWei;             // 預估的手續費（wei）
  int? _estGasRaw;                // RPC 回傳的原始 gas（未加 buffer）

  // ---------------- 工具方法 ----------------
  /// ETH 字串 → wei（BigInt）
  BigInt _ethToWei(String input) {
    final s = input.trim();
    if (s.isEmpty) return BigInt.zero;

    final parts = s.split('.');
    final whole = BigInt.parse(parts[0].isEmpty ? '0' : parts[0]);
    final fracStr = parts.length > 1 ? parts[1] : '';

    final cut = fracStr.length > 18 ? fracStr.substring(0, 18) : fracStr;
    final frac = cut.isEmpty ? BigInt.zero : BigInt.parse(cut.padRight(18, '0'));

    return whole * BigInt.from(10).pow(18) + frac;
  }

  /// wei → ETH 字串（小數 6 位，去掉尾零）
  String _weiToEthString(BigInt wei) {
    final d = wei.toDouble() / 1e18;
    final s = d.toStringAsFixed(6);
    return s.replaceFirst(RegExp(r'\.?0+\$'), '');
  }

  /// 驗證是否為正確 0x 地址
  bool _isHexAddress(String s) => RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(s.trim());

  // ---------------- Clipboard ----------------
  Future<void> _pasteAddress() async {
    final data = await Clipboard.getData('text/plain');
    final txt = (data?.text ?? '').trim();
    if (txt.isEmpty) return;
    setState(() => _to.text = txt);
    _recalcFee();
  }

  // ---------------- Gas 估算 ----------------
  Future<void> _estimateFee(String toHex, BigInt amountWei) async {
    try {
      final web3 = ref.read(web3ServiceProvider);
      final gasPrice = await web3.client.getGasPrice();

      // 用目前錢包私鑰推導出地址
      final ks = ref.read(keyServiceProvider);
      final privHex = await ks.deriveEvmPrivHex();
      final creds = EthPrivateKey.fromHex(privHex);
      final sender = await creds.extractAddress();

      // RPC 試算交易 gas
      final estimatedGas = await web3.client.estimateGas(
        sender: sender,
        to: EthereumAddress.fromHex(toHex),
        value: EtherAmount.inWei(amountWei),
      );

      // 加 buffer 避免 out-of-gas
      final gasWithBuffer = (estimatedGas.toInt() * 12 ~/ 10);

      if (!mounted) return;
      setState(() {
        _estGasRaw = estimatedGas.toInt();
        _estFeeWei = gasPrice.getInWei * BigInt.from(gasWithBuffer);
      });
    } catch (e) {
      debugPrint('⚠️ Gas estimation failed: $e');
      if (!mounted) return;
      setState(() {
        _estGasRaw = null;
        _estFeeWei = null;
      });
    }
  }

  /// 依輸入自動估算手續費
  void _recalcFee() {
    final addr = _to.text.trim();
    final amtWei = _ethToWei(_amt.text);

    if (!_isHexAddress(addr) || amtWei <= BigInt.zero) {
      setState(() {
        _estGasRaw = null;
        _estFeeWei = null;
      });
      return;
    }

    // 非阻塞呼叫
    unawaited(_estimateFee(addr, amtWei));
  }

  // ---------------- Use Max ----------------
  void _useMax() {
    final st = ref.read(walletProvider);
    final bal = st.balanceWei ?? BigInt.zero;
    final fee = _estFeeWei ?? BigInt.zero;
    final usable = (bal > fee) ? (bal - fee) : BigInt.zero;
    _amt.text = _weiToEthString(usable);
    setState(() {});
    _recalcFee();
  }

  // ---------------- Lifecycle ----------------
  @override
  void initState() {
    super.initState();
    Future.microtask(_recalcFee);
    _to.addListener(_recalcFee);
    _amt.addListener(_recalcFee);
  }

  @override
  void dispose() {
    _to.dispose();
    _amt.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final chain = ref.watch(currentChainProvider);
    final st = ref.watch(walletProvider);
    final balEth = _weiToEthString(st.balanceWei ?? BigInt.zero);

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
              IconButton(
                tooltip: 'Re-estimate gas',
                onPressed: _recalcFee,
                icon: const Icon(Icons.local_gas_station),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Text('Balance: $balEth ${chain.symbol}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),

          // ---------------- 收款地址輸入 ----------------
          Row(children: [
            Expanded(
              child: TextField(
                controller: _to,
                decoration: const InputDecoration(
                  labelText: 'To address (0x...)',
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

          // ---------------- 金額輸入 ----------------
          Row(children: [
            Expanded(
              child: TextField(
                controller: _amt,
                decoration: const InputDecoration(
                  labelText: 'Amount (ETH)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _useMax, child: const Text('Max')),
          ]),

          const SizedBox(height: 8),

          // ---------------- 顯示估算手續費 ----------------
          if (_estFeeWei != null)
            Text(
              'Estimated fee: ${_weiToEthString(_estFeeWei!)} ETH'
                  '${_estGasRaw != null ? ' (gas ≈ $_estGasRaw + 20%)' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),

          const SizedBox(height: 12),

          // ---------------- 送出按鈕 ----------------
          FilledButton.icon(
            onPressed: _sending
                ? null
                : () async {
              final addr = _to.text.trim();
              final amtWei = _ethToWei(_amt.text);
              if (!_isHexAddress(addr)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid 0x address')),
                );
                return;
              }

              if (amtWei <= BigInt.zero) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid amount')),
                );
                return;
              }

              final bal = st.balanceWei ?? BigInt.zero;
              final need = amtWei + (_estFeeWei ?? BigInt.zero);
              if (bal < need) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Insufficient balance (need ${_weiToEthString(need)} ETH，have $balEth ETH）')),
                );
                return;
              }

              setState(() => _sending = true);
              try {
                final hash = await ref.read(walletProvider.notifier).sendNative(
                  toHex: addr,
                  amountWei: amtWei,
                );

                if (!mounted) return;

                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TxDetailPage(txHash: hash)),
                );

                await ref.read(walletProvider.notifier).refreshBalance();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Send failed：$e')),
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