// test/core/keyService/account_index_store_test.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_demo/features/wallet/data/core/keyService/core/account_index_store.dart';
import 'package:wallet_demo/features/wallet/data/core/common/chains.dart'; // 需要 ChainKind
import '../../test_utils/fake_secure_storage.dart';

void main() {
  late FlutterSecureStorage storage;
  late AccountIndexStore store;

  setUp(() {
    storage = FakeSecureStorage();
    store = AccountIndexStore(storage);
  });

  test('初始 current/max 皆為 0', () async {
    for (final k in ChainKind.values) {
      expect(await store.getCurrent(k), 0);
      expect(await store.getMax(k), 0);
    }
  });

  test('set/get current 與 max', () async {
    await store.setCurrent(ChainKind.evm, 3);
    await store.setMax(ChainKind.evm, 5);

    expect(await store.getCurrent(ChainKind.evm), 3);
    expect(await store.getMax(ChainKind.evm), 5);
  });

  test('邊界值：max 很大時再 add 仍 +1', () async {
    const big = 1 << 20; // 1,048,576
    await store.setMax(ChainKind.evm, big);
    await store.setCurrent(ChainKind.evm, big);

    final next = await store.addAndSelect(ChainKind.evm);
    expect(next, big + 1);
    expect(await store.getCurrent(ChainKind.evm), big + 1);
    expect(await store.getMax(ChainKind.evm), big + 1);
  });

  test('wipe 後 current/max 回到 0', () async {
    await store.setCurrent(ChainKind.evm, 7);
    await store.setMax(ChainKind.evm, 9);
    await store.wipe();

    expect(await store.getCurrent(ChainKind.evm), 0);
    expect(await store.getMax(ChainKind.evm), 0);
  });
}
