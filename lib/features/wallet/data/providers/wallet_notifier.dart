import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reown_walletkit/reown_walletkit.dart'; // 如果實際沒用到可以刪除
import 'package:wallet_demo/features/wallet/data/core/keyService/core/key_service.dart';
import '../chains/chain_client.dart';
import '../core/keyService/keyServiceProvider.dart';
import 'wallet_state.dart';
import 'wallet_providers.dart';
import 'chain_client_provider.dart';

/// ---------------------------------------------------------------------------
/// walletProvider
///
/// 1. 提供給 UI 的「錢包狀態管理」入口。
/// 2. StateNotifierProvider<WalletNotifier, WalletState>
///    - 第一個型別：控制邏輯 (WalletNotifier)
///    - 第二個型別：公開的狀態資料 (WalletState)
/// 3. UI 只需監聽這個 provider，就能得到目前錢包地址、餘額、是否 loading/busy 等狀態。
/// ---------------------------------------------------------------------------
final walletProvider =
StateNotifierProvider<WalletNotifier, WalletState>((ref) => WalletNotifier(ref));

/// ---------------------------------------------------------------------------
/// WalletNotifier
///
/// 這是多鏈錢包的核心狀態機：
/// - 持有錢包的 UI 狀態 (WalletState)
/// - 透過 ChainClient 封裝「鏈特定」的邏輯（EVM 或 Solana）
///
/// 責任：
/// - 初始化 / 重新整理餘額
/// - 切換帳號、新增帳號、新建錢包
/// - 發送原生代幣 (ETH / SOL …)
/// ---------------------------------------------------------------------------
class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier(this.ref) : super(const WalletState());

  /// Riverpod 提供的 ref，可讀取或監聽其他 provider。
  final Ref ref;

  /// 操作鎖：避免同時執行多個需要序列化的動作（例如連點新增帳號）
  bool _opLock = false;

  /// 依目前選擇的鏈，取得對應的鏈客戶端 (EvmChainClient 或 SolanaChainClient)
  /// - 這樣上層不用自己判斷是 EVM 還是 Solana。
  ChainClient get _client => ref.read(chainClientProvider);

  /// -----------------------------------------------------------------------
  /// 初始化：
  /// 1. 檢查是否已有助記詞（沒有就代表沒建立錢包）。
  /// 2. 有錢包就從鏈上讀取地址與原生代幣餘額。
  /// -----------------------------------------------------------------------
  Future<void> init() async {
    state = state.copyWith(loading: true);

    //檢查現在有沒有助記詞
    final ks = ref.read(keyServiceProvider);
    if (!await ks.hasMnemonic()) {
      // 沒有助記詞 => 沒有錢包，直接結束
      state = const WalletState(loading: false);
      return;
    }

    //如果有助記詞繼續往下走
    try {
      final addr = await _client.getAddress();          // 取得當前帳號地址
      final bal  = await _client.getNativeBalance();    // 查詢鏈上餘額
      state = state.copyWith(addressHex: addr, balanceWei: bal, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false);
      rethrow; // 往上丟出讓 UI 或上層處理錯誤
    }
  }

  /// -----------------------------------------------------------------------
  /// 只刷新餘額：
  /// 與 init 類似，但不會重設帳號，只重新查詢地址與餘額。
  /// 給 UI 手動下拉更新用。
  /// -----------------------------------------------------------------------
  Future<void> refreshBalance() async {
    final ks = ref.read(keyServiceProvider);
    if (!await ks.hasMnemonic()) {
      state = const WalletState(loading: false);
      return;
    }

    state = state.copyWith(loading: true);
    try {
      final addr = await _client.getAddress();
      final bal  = await _client.getNativeBalance();
      state = state.copyWith(addressHex: addr, balanceWei: bal, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false);
      rethrow;
    }
  }

  /// -----------------------------------------------------------------------
  /// 切換帳號：
  /// - 接受一個索引 i，交給對應鏈的 ChainClient 去切換。
  /// - 完成後重新初始化 (重新讀取地址與餘額)。
  /// -----------------------------------------------------------------------
  Future<void> selectAccount(int i) async {
    if (_opLock) return;            // 若正在忙碌則忽略
    _opLock = true;
    state = state.copyWith(busy: true);
    try {
      await _client.setAccountIndex(i); // 交給鏈客戶端切換帳號索引
      await init();
    } finally {
      state = state.copyWith(busy: false);
      _opLock = false;
    }
  }

  /// -----------------------------------------------------------------------
  /// 新增下一個帳號並自動切換：
  /// - 由鏈客戶端自己負責「新增帳號」並把當前索引指向新帳號。
  /// - 完成後重新初始化。
  /// -----------------------------------------------------------------------
  Future<void> createAccountNext() async {
    if (_opLock) return;
    _opLock = true;
    state = state.copyWith(busy: true);
    try {
      await _client.addNextAccountAndSelect(); // 新增 + 切換
      await init();
    } finally {
      state = state.copyWith(busy: false);
      _opLock = false;
    }
  }

  /// -----------------------------------------------------------------------
  /// 建立全新的錢包：
  /// - 重新生成助記詞並清空舊帳號。
  /// - 通知 UI「已經有錢包了」，並重新初始化。
  /// -----------------------------------------------------------------------
  Future<void> createNewWallet() async {
    if (_opLock) return;
    _opLock = true;
    state = state.copyWith(busy: true);
    try {
      // 重新建立助記詞（索引從 0 開始）
      await ref.read(keyServiceProvider).createNewWallet(index: 0);
      // 通知其他監聽此 provider 的地方重新計算（例如 SetupCard → WalletCard）
      ref.invalidate(walletExistsProvider);
      // 重新初始化
      await init();
    } finally {
      state = state.copyWith(busy: false);
      _opLock = false;
    }
  }

  /// -----------------------------------------------------------------------
  /// 發送原生代幣（ETH、SOL ...）：
  /// - 參數：收款地址 toHex、金額 amountWei。
  /// - 實際發送由對應的 ChainClient 處理。
  /// - 成功後刷新餘額並回傳交易 Hash。
  /// -----------------------------------------------------------------------
  Future<String> sendNative({
    required String toHex,
    required BigInt amountWei,
  }) async {
    final txHash = await _client.sendNative(
      toAddress: toHex,
      amount: amountWei,
    );
    await refreshBalance();
    return txHash;
  }
}
