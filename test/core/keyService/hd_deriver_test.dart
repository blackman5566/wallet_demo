// test/core/keyService/hd_deriver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_demo/features/wallet/data/core/keyService/core/hd_deriver.dart';
import 'package:wallet_demo/features/wallet/data/core/common/chains.dart'; // 若需要 kind 常數可用
import 'package:solana/solana.dart' as sol;

void main() {
  final deriver = HdDeriver();

  const mnemonic =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

  group('EVM derivation', () {
    test('index 0 產出 64 位 hex（無 0x）且可重現', () {
      final pk1 = deriver.evmPrivateHex(mnemonic: mnemonic, index: 0);
      final pk2 = deriver.evmPrivateHex(mnemonic: mnemonic, index: 0);
      final pk3 = deriver.evmPrivateHex(mnemonic: mnemonic, index: 1);

      // 格式與長度
      final hexMatcher = RegExp(r'^[0-9a-f]{64}$');
      expect(pk1.length, 64);
      expect(hexMatcher.hasMatch(pk1), isTrue);

      // 穩定且可重現
      expect(pk1, equals(pk2));

      // 不同 index 會不同
      expect(pk1, isNot(equals(pk3)));
    });
  });
}
