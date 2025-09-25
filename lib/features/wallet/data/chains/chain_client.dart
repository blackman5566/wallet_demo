import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/common/chains.dart';

/// 各鏈共用最小介面
abstract class ChainClient {
  ChainKind get kind;

  Future<String> getAddress();        // 統一回傳字串（EVM: 0x..；Solana: base58）
  Future<BigInt> getNativeBalance();  // 統一最小單位（wei/lamports）

  Future<void> setAccountIndex(int i);
  Future<void> addNextAccountAndSelect();

  Future<String> sendNative({
    required String toAddress,
    required BigInt amount,
  });

  /// 可選：切帳號/切鏈時清快取
  void clearCache() {}
}
