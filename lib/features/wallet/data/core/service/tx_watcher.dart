// lib/features/wallet/data/tx_watcher.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_demo/features/wallet/data/core/service/web3_service.dart';
import 'package:web3dart/web3dart.dart';
import '../../providers/chain_client_provider.dart';
import 'nonce_store.dart';

/// 輪詢交易監控：定期讀本地 pending，查鏈上收據，有結果就 resolve。
class TxWatcher {
  TxWatcher({
    required this.ref,
    required this.store,
    required this.web3,
    this.interval = const Duration(seconds: 8),
  });

  final Ref ref;
  final NonceStore store;
  final Web3Service web3;
  final Duration interval;

  Timer? _timer;
  bool _busy = false;

  void start() {
    _timer ??= Timer.periodic(interval, (_) => _tick());
    _tick(); // 立即跑一次
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    try {
      // 1) 取目前地址與 chainId
      final chainClient = ref.read(chainClientProvider);
      final addrHex = await chainClient.getAddress();
      final addr = EthereumAddress.fromHex(addrHex);

      final cidAny = await web3.client.getChainId();
      final chainId = cidAny is BigInt ? cidAny.toInt() : cidAny as int;

      // 2) 讀本地 pending
      final pendings = await store.list(addr.hexEip55, chainId);
      if (pendings.isEmpty) return;

      // 3) 逐筆查收據，成功/失敗皆 resolve
      for (final p in pendings) {
        try {
          final receipt = await web3.client.getTransactionReceipt(p.txHash);
          if (receipt == null) continue; // 還在 pending
          await store.resolve(p.addr, p.chainId, p.nonce);

          // 提醒上層刷新（餘額/列表等）；你已有 notifier 可用：
          // ignore: unawaited_futures
          //ref.read(walletNotifierProvider.notifier).refresh(); // 若你有這個方法
        } catch (_) {
          // 單筆查詢失敗不影響整體
        }
      }
    } finally {
      _busy = false;
    }
  }
}
