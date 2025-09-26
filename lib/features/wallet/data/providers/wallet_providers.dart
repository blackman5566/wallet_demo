import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solana/dto.dart' as sol;
import '../core/common/chains.dart';
import '../core/keyService/keyServiceProvider.dart';
import '../core/keyService/core/key_service.dart';
import '../core/service/evm/evm_rpc_service.dart';
import '../core/service/sol/sol_rpc_service.dart';
import 'account_name_store.dart';

// ============================================================================
// 多鏈錢包 Provider 統整版（中文註解）
// 功能：集中管理金鑰、鏈資訊、客戶端與帳號資料，方便 UI 使用。
// 分類：鏈資訊 → 服務層 → 錢包狀態 → 帳號資料
// ============================================================================

// -----------------------------------------------------------------------------
// 鏈資訊（目前選擇的鏈）
// -----------------------------------------------------------------------------

/// 目前鏈 ID，預設 Ethereum Sepolia (11155111)
final currentChainIdProvider = StateProvider<int>((_) => 11155111);

/// 目前鏈物件，依鏈 ID 對應到 supportedChains 裡的設定
final currentChainProvider = Provider<Chain>((ref) {
  final id = ref.watch(currentChainIdProvider);
  return supportedChains.firstWhere((c) => c.id == id);
});

// -----------------------------------------------------------------------------
// 服務層
// -----------------------------------------------------------------------------

// wallet_providers.dart（或原本放 web3 的地方）
final web3ServiceProvider = Provider<Web3Service>((ref) {
  final c = ref.watch(currentChainProvider);
  return Web3Service(
    rpcs: [c.rpc],
    chainId: c.id,
    callTimeout: const Duration(seconds: 8),
    maxAttempts: 3,
    baseBackoff: const Duration(milliseconds: 300),
    cooldown: const Duration(seconds: 8),
  );
});

final solRpcServiceProvider = Provider<SolRpcService>((ref) {
  final chain = ref.watch(currentChainProvider);
  if (chain.kind != ChainKind.sol) {
    throw StateError('目前鏈不是 Solana，無法建立 SolRpcService');
  }

  // 這裡可以放多個 RPC 端點，前面是主，後面是備援
  return SolRpcService(
    rpcs: [
      chain.rpc,
    ],
    callTimeout: const Duration(seconds: 8),
    maxAttempts: 3,
    baseBackoff: const Duration(milliseconds: 300),
    cooldown: const Duration(seconds: 8),
    commitment: sol.Commitment.confirmed,
  );
});

// -----------------------------------------------------------------------------
// 錢包狀態 / 是否存在
// -----------------------------------------------------------------------------

/// 是否已經有助記詞（用於 UI 決定顯示 SetupCard 或 WalletCard）
final walletExistsProvider = FutureProvider<bool>((ref) async {
  final ks = ref.watch(keyServiceProvider);
  return await ks.hasMnemonic();
});

// -----------------------------------------------------------------------------
// 帳號資料
// -----------------------------------------------------------------------------

/// 目前帳號索引（依鏈別分開管理）
final currentAccountIndexProvider = FutureProvider<int>((ref) async {
  final kind = ref.watch(currentChainProvider).kind;
  final ks = ref.read(keyServiceProvider);
  return await ks.getIndexByKind(kind);
});

/// 帳號名稱儲存服務
final accountNameStoreProvider = Provider((_) => AccountNameStore());

/// 目前帳號名稱（例如 Account 1 或使用者自訂名稱）
final currentAccountNameProvider = FutureProvider<String>((ref) async {
  final chain = ref.watch(currentChainProvider);
  final idx = await ref.watch(currentAccountIndexProvider.future);
  final store = ref.read(accountNameStoreProvider);
  return await store.getName(chain.kind, idx);
});

/// 帳號清單（下拉選單）
/// 只回傳 index + name，不即時 derive 地址以避免卡頓
final accountsListProvider =
FutureProvider<List<({int index, String name})>>((ref) async {
  final chain = ref.watch(currentChainProvider);
  final ks = ref.read(keyServiceProvider);
  final store = ref.read(accountNameStoreProvider);
  final max = await ks.getMaxIndexByKind(chain.kind);
  final items = <({int index, String name})>[];
  for (var i = 0; i <= max; i++) {
    final name = await store.getName(chain.kind, i);
    items.add((index: i, name: name));
  }
  return items;
});