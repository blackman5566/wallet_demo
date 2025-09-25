/// ─────────────────────────────────────────────────────────────
/// WalletState
///
/// 角色：
/// 1. **純資料模型 (Immutable State)**
///    - 保存錢包目前的狀態，供 UI 讀取。
///    - 不包含任何商業邏輯或網路請求。
///
/// 2. **搭配 Riverpod 的 StateNotifier**
///    - `walletProvider` (StateNotifierProvider) 會持有這個物件的實例。
///    - UI 只要監聽 `walletProvider` 就能即時拿到最新的狀態。
///
/// 為何要 Immutable：
///    - 每次狀態更新都建立一個全新的 WalletState，
///      方便比對與 UI 重繪，避免「部分修改導致 UI 沒更新」的問題。
/// ─────────────────────────────────────────────────────────────
class WalletState {
  /// 錢包地址
  /// - EVM 鏈：例如 0x1234... (EIP-55 格式)
  /// - Solana 鏈：base58 編碼
  final String? addressHex;

  /// 餘額
  /// - EVM：單位為 wei (1 ETH = 1e18 wei)
  /// - Solana：單位為 lamports (1 SOL = 1e9 lamports)
  final BigInt? balanceWei;

  /// 是否正在讀取中
  /// - 例如剛打開 App 或手動下拉更新餘額時為 true
  /// - UI 可據此顯示 Loading 指示器
  final bool loading;

  /// 是否正執行「切換帳號 / 新增帳號 / 建立新錢包」等需要鎖定 UI 的操作
  /// - true 時 UI 可禁用按鈕或顯示遮罩避免使用者連點
  final bool busy;

  /// 建構子
  /// - 預設 loading、busy 為 false，表示一般靜止狀態
  const WalletState({
    this.addressHex,
    this.balanceWei,
    this.loading = false,
    this.busy = false,
  });

  /// 產生一份新的 WalletState（Immutable）
  ///
  /// 用途：
  /// - StateNotifier 在更新時不會直接修改舊值，
  ///   而是呼叫 copyWith(...) 產生新的實例。
  /// - 只需填入要變更的欄位，未指定的欄位會保留舊值。
  ///
  /// 範例：
  ///   state = state.copyWith(loading: true);
  WalletState copyWith({
    String? addressHex,
    BigInt? balanceWei,
    bool? loading,
    bool? busy,
  }) =>
      WalletState(
        addressHex: addressHex ?? this.addressHex,
        balanceWei: balanceWei ?? this.balanceWei,
        loading: loading ?? this.loading,
        busy: busy ?? this.busy,
      );
}
