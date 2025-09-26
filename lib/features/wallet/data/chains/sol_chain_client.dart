// lib/features/wallet/data/clients/sol_chain_client.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solana/solana.dart' as sol;
import 'package:wallet_demo/features/wallet/data/core/keyService/core/key_service.dart';
import 'package:wallet_demo/features/wallet/data/core/service/sol/sol_rpc_service.dart';

import '../core/common/chains.dart';
import '../core/keyService/keyServiceProvider.dart'; // <— 確保有這支（前面我給過）
import '../providers/wallet_providers.dart';
import 'chain_client.dart';

class SolChainClient implements ChainClient {
  SolChainClient(this.ref);
  final Ref ref;

  String? _addrCache;                 // base58
  sol.Ed25519HDKeyPair? _kpCache;     // 簽名用 keypair 快取

  @override
  ChainKind get kind => ChainKind.sol;

  @override
  void clearCache() {
    _addrCache = null;
    _kpCache = null;
  }

  @override
  Future<void> setAccountIndex(int i) async {
    await ref.read(keyServiceProvider).setIndexByKind(ChainKind.sol, i);
    clearCache();
  }

  @override
  Future<void> addNextAccountAndSelect() async {
    await ref.read(keyServiceProvider).addAccount(ChainKind.sol);
    clearCache();
  }

  @override
  Future<String> getAddress() async {
    if (_addrCache != null) return _addrCache!;
    final kp = await _deriveKeypair();
    _addrCache = kp.address; // base58
    return _addrCache!;
  }

  @override
  Future<BigInt> getNativeBalance() async {
    final addr = await getAddress();
    final solSvc = ref.read(solRpcServiceProvider);
    final lamports = await solSvc.getBalance(addr);
    return BigInt.from(lamports); // ChainClient 統一 BigInt
  }

  @override
  Future<String> sendNative({
    required String toAddress,   // base58
    required BigInt amount,      // lamports
  }) async {
    final solSvc = ref.read(solRpcServiceProvider);
    final kp = await _deriveKeypair();

    // 轉成 Ed25519HDPublicKey（新版 API 需要）
    final toPubkey = sol.Ed25519HDPublicKey.fromBase58(toAddress);

    // 建立 SystemProgram 轉帳指令
    final ix = sol.SystemInstruction.transfer(
      fundingAccount: kp.publicKey,
      recipientAccount: toPubkey,
      lamports: amount.toInt(),    // solana 方法吃 int
    );

    // ✅ 0.31.x：Message + signAndSendTransaction（不用 recentBlockhash/compile）
    final message = sol.Message(instructions: [ix]);

    final signature = await solSvc.run((c) => c.signAndSendTransaction(
      message,
      [kp],
      commitment: solSvc.commitment,
    ));

    // 如果想等 finalized 再回：
    // await solSvc.waitFinalized(signature);

    return signature; // base58 tx id
  }

  // ────────────────────────────────────────────────────────────────────────
  // internal
  Future<sol.Ed25519HDKeyPair> _deriveKeypair() async {
    if (_kpCache != null) return _kpCache!;
    _kpCache = await ref.read(keyServiceProvider).deriveSolanaKeypair();
    return _kpCache!;
  }
}
