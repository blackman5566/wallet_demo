// --- 3) 金鑰導出 ---
// 套件用途：
//  - bip32:  BIP-32 規範，用來從 seed 派生階層式金鑰 (HD Wallet)。
//  - bip39:  BIP-39 規範，把助記詞(mnemonic) 轉成種子(seed)。
//  - hex:    將位元組陣列轉成十六進位字串。
//  - solana: (目前這裡沒用到) Solana SDK，可建立 Ed25519HDKeyPair。
import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:hex/hex.dart';
import 'package:solana/solana.dart' as sol;

/// ---------------------------------------------------------------------------
/// HdDeriver
/// 用途：從 BIP-39 助記詞推導出對應鏈的私鑰。
/// 這裡實作了 Ethereum/EVM 鏈的私鑰推導流程。
/// ---------------------------------------------------------------------------
class HdDeriver {
  // EVM (Ethereum 及相容鏈) 的標準推導路徑前綴
  // 完整路徑 = m / 44' / 60' / 0' / 0 / {index}
  // 44'：BIP-44 規範
  // 60'：SLIP-0044 裡 Ethereum 的 coin type
  static const evmPathPrefix = "m/44'/60'/0'/0";

  /// 從助記詞產生「單一帳號索引」的 EVM 私鑰
  ///
  /// 參數：
  ///   mnemonic   - BIP-39 助記詞（字串）
  ///   index      - 要取的帳號索引，例如 0 代表第一個帳號
  ///   passphrase - (可選) BIP-39 的額外密語；不填就當空字串
  ///
  /// 流程：
  /// 1. 把助記詞 (mnemonic) 轉成 seed (位元組)。
  /// 2. 用 BIP-32 從 seed 建立根節點 (master node)。
  /// 3. 依 BIP-44 標準路徑 m/44'/60'/0'/0/{index} 取得子節點。
  /// 4. 讀取該子節點的 secp256k1 私鑰 (32 bytes)。
  /// 5. 以 hex 編碼 (不含「0x」前綴) 回傳。
  ///
  /// 回傳：
  ///   32 bytes 的 **EVM 私鑰**，型別為 `String`，
  ///   例如 "4f3edf983ac636a65a842ce7c78d9aa706d3b113b37e02bfb..."。
  String evmPrivateHex({
    required String mnemonic,
    required int index,
    String? passphrase,
  }) {
    // 1. 助記詞 -> 種子 (seed)。可選 passphrase (通常留空)。
    final seed = bip39.mnemonicToSeed(mnemonic, passphrase: passphrase ?? "");

    // 2. 用 seed 建立 BIP-32 根節點 (master node)。
    final root = bip32.BIP32.fromSeed(seed);

    // 3. 依 EVM 標準路徑 + index 派生出子節點。
    final node = root.derivePath("$evmPathPrefix/$index");

    // 4. 取得該子節點的 secp256k1 私鑰 (32 bytes)。
    final pk = node.privateKey;

    // 如果派生失敗，拋出錯誤。
    if (pk == null) throw StateError('Failed to derive EVM private key');

    // 5. 轉成十六進位字串 (不含 0x 前綴) 並回傳。
    return HEX.encode(pk);
  }
}
