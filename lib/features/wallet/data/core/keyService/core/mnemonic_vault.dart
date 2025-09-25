import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ===========================================================================
/// MnemonicVault：助記詞保管庫
/// ===========================================================================
/// 功能定位：
///   - 負責「單一助記詞」的安全存取
///   - 將助記詞存放在裝置的 **安全儲存區**（Keychain / Android Keystore）
///   - 提供讀取、驗證、刪除、正規化 (normalize) 功能
///
/// 為整個錢包模組提供唯一入口，確保助記詞不會出現在不安全的地方。
class MnemonicVault {
  // 安全儲存的 key
  static const _mnemonicKey = 'wallet_v1/mnemonic';

  final FlutterSecureStorage _storage;
  const MnemonicVault(this._storage);

  /// 是否已存在助記詞
  /// - 讀取 secure storage 中的值
  /// - 判斷是否非空字串
  Future<bool> exists() async {
    final m = await _storage.read(key: _mnemonicKey);
    return m != null && m.trim().isNotEmpty;
  }

  /// 讀取助記詞；若不存在則丟 StateError
  /// - 自動做 normalize：小寫、去多餘空白
  Future<String> getOrThrow() async {
    final m = await _storage.read(key: _mnemonicKey);
    if (m == null || m.trim().isEmpty) throw StateError('No mnemonic');
    return normalize(m);
  }

  /// 讀取助記詞；若不存在則回 null
  /// - 一樣做 normalize
  Future<String?> getOrNull() async {
    final m = await _storage.read(key: _mnemonicKey);
    if (m == null || m.trim().isEmpty) return null;
    return normalize(m);
  }

  /// 保存助記詞到安全儲存
  /// - 先 normalize
  /// - 再用 bip39.validateMnemonic 驗證格式正確
  /// - 不合法則丟 ArgumentError
  Future<void> save(String raw) async {
    final m = normalize(raw);
    if (!bip39.validateMnemonic(m)) {
      throw ArgumentError('Invalid mnemonic');
    }
    await _storage.write(key: _mnemonicKey, value: m);
  }

  /// 從安全儲存刪除助記詞
  Future<void> wipe() async => _storage.delete(key: _mnemonicKey);

  /// normalize：統一格式
  /// - 全轉小寫
  /// - trim 前後空白
  /// - 多重空白以單一空白分隔
  static String normalize(String raw) => raw
      .toLowerCase()
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .join(' ');
}
