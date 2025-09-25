// lib/features/wallet/data/providers/tx_status_providers.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_demo/features/wallet/data/providers/wallet_providers.dart';
import 'package:web3dart/web3dart.dart';

// 類型一樣
class TxDetail {
  final TransactionInformation? info;
  final TransactionReceipt? receipt;
  final int? confirmations;
  const TxDetail({this.info, this.receipt, this.confirmations});
}

final txDetailProvider =
StreamProvider.autoDispose.family<TxDetail, String>((ref, txHash) async* {
  final web3 = ref.read(web3ServiceProvider);

  var cancelled = false;
  ref.onDispose(() => cancelled = true);

  // --- 先嘗試拿到 info（含 to/value/nonce），避免剛送出時抓不到 ---
  TransactionInformation? info;
  for (var i = 0; i < 8 && !cancelled; i++) { // 最多重試 ~8次 ≈ 6~7秒
    try {
      info = await web3.client.getTransactionByHash(txHash);
      if (info != null) break;
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 800));
  }

  // --- 之後固定輪詢 receipt（輕量） ---
  while (!cancelled) {
    TransactionReceipt? receipt;
    try {
      receipt = await web3.client.getTransactionReceipt(txHash);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('not found')) {
        // 可能還未索引或被替換，先維持原樣
      } else {
        // 其他錯誤不讓它炸掉 UI
      }
    }

    int? confs;
    if (receipt != null) {
      final current = await web3.client.getBlockNumber();
      final blk = receipt.blockNumber?.blockNum;
      if (blk != null) confs = current - blk + 1;
    }

    if (cancelled) break;
    yield TxDetail(info: info, receipt: receipt, confirmations: confs);

    // 你要更即時可以調 1~2 秒
    await Future.delayed(const Duration(seconds: 2));
  }
});


