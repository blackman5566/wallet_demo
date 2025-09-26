import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../chains/sol_chain_client.dart';
import '../core/common/chains.dart';
import '../core/keyService/keyServiceProvider.dart';
import 'wallet_providers.dart';
import '../chains/chain_client.dart';
import '../chains/evm_chain_client.dart';

/// ---------------------------------------------------------------------------
/// chainClientProvider
///
/// 功能：
/// 依照「目前選擇的鏈」(currentChainProvider) 動態建立對應的鏈客戶端。
/// - 如果是 EVM 類（Ethereum 及相容鏈），回傳 EvmChainClient。
/// - 如果是 Solana 類，回傳 SolanaChainClient。
///
/// 用途：
/// UI 或上層業務邏輯只需要讀取這個 provider，就能取得正確鏈的 client，
/// 進而呼叫 sendTx、getBalance 等鏈相關操作，而不必自己判斷是哪一條鏈。
///
/// Riverpod 特性：
/// - Provider<ChainClient> 表示這是一個「單例」供應者。
/// - 每當 currentChainProvider 的值改變，
///   這個 provider 會自動重新計算並回傳新的對應 ChainClient。
/// ---------------------------------------------------------------------------
final chainClientProvider = Provider<ChainClient>((ref) {
  // 取得目前使用者在 UI 中選擇的鏈 (Chain 物件)
  final chain = ref.watch(currentChainProvider);

  // 根據鏈的種類 (EVM 或 Solana) 建立對應的鏈客戶端
  switch (chain.kind) {
     case ChainKind.evm:
        return EvmChainClient(ref);
      case ChainKind.sol:
        return SolChainClient(ref);
  }
});
