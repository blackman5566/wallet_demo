// --- 2) 索引存取 ---
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../common/chains.dart';

class AccountIndexStore {
  final FlutterSecureStorage _storage;
  const AccountIndexStore(this._storage);

  // 依鏈別組鍵名：wallet_v1/index/{鏈名}/current, /max
  String _curKey(ChainKind k) => 'wallet_v1/index/${k.name}/current';
  String _maxKey(ChainKind k) => 'wallet_v1/index/${k.name}/max';

  /// 讀取「目前選取」的帳號索引（預設 0）
  /// - 解析失敗或不存在 → 回 0
  Future<int> getCurrent(ChainKind k) async =>
      int.tryParse(await _storage.read(key: _curKey(k)) ?? '0') ?? 0;

  /// 設定「目前選取」的帳號索引
  Future<void> setCurrent(ChainKind k, int i) =>
      _storage.write(key: _curKey(k), value: i.toString());

  /// 讀取「歷來最大」帳號索引（預設 0）
  /// - 表示目前已建立的最大 index
  Future<int> getMax(ChainKind k) async =>
      int.tryParse(await _storage.read(key: _maxKey(k)) ?? '0') ?? 0;

  /// 設定「歷來最大」帳號索引
  Future<void> setMax(ChainKind k, int i) =>
      _storage.write(key: _maxKey(k), value: i.toString());

  /// 新增下一個帳號並選取它：
  /// - next = getMax() + 1
  /// - setMax(next), setCurrent(next)
  /// - 回傳 next
  Future<int> addAndSelect(ChainKind k) async {
    final next = (await getMax(k)) + 1;
    await setMax(k, next);
    await setCurrent(k, next);
    return next;
  }

  /// 清除所有鏈別的 current / max
  Future<void> wipe() async {
    for (final k in ChainKind.values) {
      await _storage.delete(key: _curKey(k));
      await _storage.delete(key: _maxKey(k));
    }
  }
}
