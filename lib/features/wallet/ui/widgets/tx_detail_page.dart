import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web3dart/web3dart.dart';

import '../../data/providers/tx_status_providers.dart';
import '../../data/chains/evm_chain_client.dart';
import '../../data/providers/chain_client_provider.dart';
import '../../data/core/service/evm/tx_watcher_provider.dart';
import '../../data/providers/wallet_providers.dart'; // 可選：全域 watcher

class TxDetailPage extends ConsumerStatefulWidget {
  const TxDetailPage({super.key, required this.txHash});
  final String txHash;

  @override
  ConsumerState<TxDetailPage> createState() => _TxDetailPageState();
}

class _TxDetailPageState extends ConsumerState<TxDetailPage> {
  late String _currentHash;      // 目前追蹤（可能被替替）
  late String _originalHash;     // 進頁面的那筆（原始 hash）

  EvmChainClient _client(WidgetRef ref) =>
      ref.read(chainClientProvider) as EvmChainClient;

  @override
  void initState() {
    super.initState();
    _currentHash  = widget.txHash;
    _originalHash = widget.txHash;
  }

  @override
  Widget build(BuildContext context) {

    final detailAsync = ref.watch(txDetailProvider(_currentHash));
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Detail')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Status: Error$e'),
        ),
        data: (d) {

          final info = d.info;
          final receipt = d.receipt;
          final mined = receipt != null;
          final success = receipt?.status;
          final confs = d.confirmations;
          final cancelOk = _isCancelSuccess(d);
          final statusText = () {
            if (!mined) {
              // 可能被取代/節點暫未索引
              if (info == null) return 'Status: Not found (maybe replaced)';
              return 'Status: Pending';
            }
            if (cancelOk) return 'Status: Cancelled (replaced)';
            final ok = success == null ? '' : (success! ? '（Success）' : '（Failed）');
            final cf = confs != null ? '（Confirms $confs）' : '';
            return 'Status: On-chain$ok$cf';
          }();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 顯示目前追蹤中的 hash（可能與最初不同）
                SelectableText(_currentHash,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(statusText),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        ref.invalidate(txDetailProvider(_currentHash));
                      },
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                if (cancelOk)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Chip(
                      label: Text('Original tx cancelled $_originalHash'),
                    ),
                  ),
                const SizedBox(height: 12),
                if (info != null) _TxMeta(info: info),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: mined ? null : () async {
                          try {
                            final newHash =
                            await _client(ref).speedUpByHash(_currentHash);
                            if (!mounted) return;
                            final old = _currentHash;
                            setState(() {
                              _currentHash = newHash;
                            });
                            ref.invalidate(txDetailProvider(old));

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Speed-up sent：$newHash')),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Speed-up failed：$e')),
                            );
                          }
                        },
                        icon: const Icon(Icons.speed),
                        label: const Text('Speed up'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: mined ? null : () async {
                          try {
                            final newHash =
                            await _client(ref).cancelByHash(_currentHash);
                            if (!mounted) return;
                            final old = _currentHash;
                            setState(() {
                              _currentHash = newHash;   // 先切 key
                            });
                            ref.invalidate(txDetailProvider(old));
                            ref.invalidate(txDetailProvider(newHash));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Cancel sent：$newHash')),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Cancel failed：$e')),
                            );
                          }
                        },
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  //檢查是否要顯示成功取消
  bool _isCancelSuccess(TxDetail d) {
    final info = d.info;
    final receipt = d.receipt;
    if (info == null || receipt == null || receipt.status != true) return false;

    final isZeroValue = (info.value?.getInWei ?? BigInt.zero) == BigInt.zero;
    final toIsSelf    = info.to != null && info.to == info.from; // to == 自己
    return isZeroValue && toIsSelf;
  }
}

class _TxMeta extends ConsumerWidget {
  const _TxMeta({required this.info});
  final TransactionInformation info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chain = ref.watch(currentChainProvider);
    final to = info.to?.hexEip55 ?? '(contract creation?)';
    final valEth = info.value == null
        ? '0'
        : (info.value!.getInWei.toDouble() / 1e18).toStringAsFixed(6);
    final gasStr = info.gas?.toString() ?? '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('From: ${info.from.hexEip55}'),
        Text('To:   $to'),
        Text('Value: $valEth ${chain.displaySymbol}'),
        Text('Nonce: ${info.nonce}  •  Gas: $gasStr'),
      ],
    );
  }
}
