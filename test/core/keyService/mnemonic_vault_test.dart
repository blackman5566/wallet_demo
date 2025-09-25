// test/core/keyService/mnemonic_vault_test.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_demo/features/wallet/data/core/keyService/core/mnemonic_vault.dart';
import '../../test_utils/fake_secure_storage.dart';

void main() {
  late FlutterSecureStorage storage;
  late MnemonicVault vault;

  // 12 字有效助記詞（英文 BIP-39 常見測試向量）
  const validMnemonic =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

  setUp(() {
    storage = FakeSecureStorage();
    vault = MnemonicVault(storage);
  });

  test('初始不存在', () async {
    expect(await vault.exists(), isFalse);
    expect(await vault.getOrNull(), isNull);
  });

  test('儲存有效助記詞 -> 可讀、exists 為真，getOrThrow 正規化', () async {
    // 混入大小寫與多空白測 normalization
    await vault.save('  Abandon  ABANDON  abandon  abandon abandon   abandon '
        'abandon abandon abandon abandon abandon   about  ');

    expect(await vault.exists(), isTrue);
    final m1 = await vault.getOrNull();
    final m2 = await vault.getOrThrow();

    expect(m1, isNotNull);
    expect(m1, equals(validMnemonic));   // 正規化為小寫單一空白
    expect(m2, equals(validMnemonic));
  });

  test('無效助記詞 -> 丟 ArgumentError', () async {
    expect(
          () => vault.save('not a valid mnemonic words here'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('wipe 之後清乾淨', () async {
    await vault.save(validMnemonic);
    expect(await vault.exists(), isTrue);

    await vault.wipe();
    expect(await vault.exists(), isFalse);
    expect(await vault.getOrNull(), isNull);
  });
}
