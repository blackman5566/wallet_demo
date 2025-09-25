import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/common/chains.dart';

/// ---------------------------------------------------------------------------
/// AccountNameStore（帳號名稱存取服務）
///
/// 功能：
/// - 將使用者自訂的帳號名稱（如「主帳號」、「測試帳號」）存到 SharedPreferences。
/// - 以 `(鏈種類 + 帳號索引)` 當 key，確保跨鏈時名稱不會衝突。
/// - 若沒有設定名稱，則回傳預設的 `Account X`。
///
/// 為什麼要這樣做：
/// - 助記詞導出的地址通常是隨機的，對使用者不直覺。
/// - 讓使用者可自己命名帳號，提升 UX。
/// ---------------------------------------------------------------------------
final accountNameStoreProvider = Provider((_) => AccountNameStore());

class AccountNameStore {
  // 產生唯一 key，例如 name_evm_0 / name_solana_1
  static String _key(ChainKind kind, int index) => 'name_${kind.name}_$index';

  /// 取得帳號名稱
  /// - 若使用者有設定 → 回傳自訂名稱
  /// - 否則 → 回傳 `Account ${index+1}`
  Future<String> getName(ChainKind kind, int index) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_key(kind, index)) ?? 'Account ${index + 1}';
  }

  /// 設定帳號名稱（會自動 trim 空白）
  Future<void> setName(ChainKind kind, int index, String name) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key(kind, index), name.trim());
  }
}