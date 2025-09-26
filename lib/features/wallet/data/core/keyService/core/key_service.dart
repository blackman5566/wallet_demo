import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bip39/bip39.dart' as bip39;        // BIP-39：產生 / 驗證助記詞，並可轉成種子 (seed)
import 'package:solana/solana.dart' as sol;
import '../../common/chains.dart';
import 'account_index_store.dart';
import 'hd_deriver.dart';
import 'mnemonic_vault.dart';

/// ===========================================================================
/// KeyService = 助記詞 + 帳號索引 + EVM 私鑰推導 的總控台
/// KeyService：跨鏈金鑰與帳號索引的「統一入口」
/// ---------------------------------------------------------------------------
/// 主要職責：
/// 1. **助記詞管理**：建立、匯入、讀取、刪除助記詞，並安全存放在系統金鑰圈/Keystore。
/// 2. **帳號索引管理**：針對不同鏈別(EVM / Solana...)，記錄「目前使用中的帳號索引」
///    以及「目前已建立過的最大索引」。例如 m/44'/60'/0'/0/{index} 的 index。
/// 3. **金鑰推導**：透過 HdDeriver，根據助記詞與索引產生 EVM 私鑰 (hex)。
///
/// 設計理念：
/// 將三個責任模組化解耦：
///   - MnemonicVault  : 助記詞的安全儲存與讀取
///   - AccountIndexStore : 每條鏈的 current / max index 管理
///   - HdDeriver      : 從助記詞推導對應鏈的私鑰
///
/// 對外只需要操作 KeyService，即可完成所有金鑰與索引相關的需求。
/// ===========================================================================
///
class KeyService {
  final FlutterSecureStorage _storage;  // 與平台金鑰圈/Keystore 互動的底層安全儲存
  late final MnemonicVault _vault;      // 封裝「助記詞安全存取」邏輯
  late final AccountIndexStore _store;  // 封裝「帳號索引存取」邏輯
  final HdDeriver _deriver = HdDeriver();// 封裝「BIP-44 私鑰推導」邏輯

  // 只有在「螢幕已解鎖」狀態下可讀，鎖螢幕立即不可讀。
  // 不會隨 iCloud 備份轉移到新裝置 → 防止助記詞在更換手機時自動外流。
  // 符合「用戶自行備份助記詞」的錢包安全模型。
  /// 建構子：可傳入自訂的 FlutterSecureStorage（方便測試），
  /// 若未提供，使用預設安全設定（iOS: keychain、Android: encryptedSharedPreferences）。
  KeyService({FlutterSecureStorage? storage})
      : _storage = storage ??
      const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
      ) {
    _vault = MnemonicVault(_storage);
    _store = AccountIndexStore(_storage);
  }
}

// ---------------------------------------------------------------------------
// 助記詞管理：建立、讀取、匯入、刪除
// ---------------------------------------------------------------------------
extension KeyServiceMnemonic on KeyService {
  /// 檢查是否已存在助記詞
  /// 回傳：true = 已存在；false = 尚未建立或已被清除
  Future<bool> hasMnemonic() => _vault.exists();

  /// 讀取並回傳助記詞字串（若不存在會丟 StateError）
  Future<String> exportMnemonic() => _vault.getOrThrow();

  /// 嘗試讀取助記詞；不存在時回傳 null（不拋錯）
  Future<String?> exportMnemonicOrNull() => _vault.getOrNull();

  /// 建立一組新的錢包：
  ///   - 產生 strength 位元的助記詞 (預設 128 bits ≈ 12 字)
  ///   - 儲存到安全儲存
  ///   - 將 EVM / Solana 兩條鏈的 current 與 max 索引初始化為指定 index (預設 0)
  Future<void> createNewWallet({int index = 0, int strength = 128}) async {
    final mnemonic = bip39.generateMnemonic(strength: strength);
    await _vault.save(mnemonic);
    await _store.setCurrent(ChainKind.evm, index);
    await _store.setMax(ChainKind.evm, index);
  }

  /// 匯入既有的助記詞：
  ///   - 將傳入字串 raw 儲存到安全儲存（內部會 normalize 並驗證格式）
  ///   - 將 EVM 鏈 current/max 索引初始化為指定 index (預設 0)
  Future<void> importMnemonic(String raw, {int index = 0}) async {
    await _vault.save(raw);
    await _store.setCurrent(ChainKind.evm, index);
    await _store.setMax(ChainKind.evm, index);
  }

  /// 清除所有金鑰資料：
  ///   - 刪除安全儲存中的助記詞
  ///   - 清除所有鏈別的索引紀錄
  Future<void> wipe() async {
    await _vault.wipe();
    await _store.wipe();
  }
}

// ---------------------------------------------------------------------------
// 帳號索引管理：讀取 / 設定 / 自動新增
// ---------------------------------------------------------------------------
extension KeyServiceIndex on KeyService {
  /// 取得指定鏈 (如 EVM) 目前使用的帳號索引
  Future<int> getIndexByKind(ChainKind k) => _store.getCurrent(k);

  /// 設定指定鏈的「目前使用索引」
  /// 注意：呼叫前最好自行檢查 i 是否在 0..max 範圍
  Future<void> setIndexByKind(ChainKind k, int i) => _store.setCurrent(k, i);

  /// 取得指定鏈目前已建立過的最大索引
  Future<int> getMaxIndexByKind(ChainKind k) => _store.getMax(k);

  /// 手動設定最大索引（一般不直接呼叫，通常由 addAccount 維護）
  Future<void> setMaxIndexByKind(ChainKind k, int i) => _store.setMax(k, i);

  /// 新增下一個帳號：
  ///   - max + 1 → 設為新的 current
  ///   - 並回傳這個新的索引值
  Future<int> addAccount(ChainKind k) => _store.addAndSelect(k);
}

// ---------------------------------------------------------------------------
// 金鑰導出：從助記詞 + 索引推導出 EVM 私鑰
// ---------------------------------------------------------------------------
extension KeyServiceDeriveEvmPrivHex on KeyService {
  /// 依照目前或指定的 index，導出對應帳號的 **EVM 私鑰 (hex)**。
  ///
  /// 參數：
  ///   index     - 指定帳號索引；若不指定，使用該鏈的 current index
  ///   passphrase- (可選) BIP-39 的密語（第 25 字），預設為空字串
  ///
  /// 回傳：
  ///   32 bytes 的 **secp256k1 私鑰**，以 **不含 0x 的十六進位字串** 表示。
  ///   例如："4f3edf983ac636a65a842ce7c78d9aa706d3b113b37e02bfb..."
  ///
  /// 注意：此私鑰能直接控制對應地址的資產，務必妥善保管。
  Future<String> deriveEvmPrivHex({int? index, String? passphrase}) async {
    final m = await exportMnemonic();                        // 1. 取得助記詞
    final i = index ?? await getIndexByKind(ChainKind.evm);   // 2. 取得索引（預設 current）
    // 3. 透過 HdDeriver 依 BIP-44 路徑推導出 32 bytes 私鑰，並轉成 hex
    return _deriver.evmPrivateHex(mnemonic: m, index: i, passphrase: passphrase);
  }
}

extension SolanaDerivation on KeyService {
  /// 依照目前索引從助記詞推導 Solana Keypair
  Future<sol.Ed25519HDKeyPair> deriveSolanaKeypair() async {
    final m = await exportMnemonic();      // 你原本存的助記詞
    final seed = bip39.mnemonicToSeed(m);  // BIP-39 → seed
    // Solana 使用 path: m/44'/501'/0'/0' + index
    final index = await getIndexByKind(ChainKind.sol);
    return sol.Ed25519HDKeyPair.fromMnemonic(
      m,
      account: index,
    );
  }
}