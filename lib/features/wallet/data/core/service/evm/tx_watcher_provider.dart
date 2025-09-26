import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../providers/wallet_providers.dart';
import 'nonce_store.dart';
import 'tx_watcher.dart';

// NonceStore 也用 provider 管（可替換成你的 SecureNonceStore）
final nonceStoreProvider = Provider<NonceStore>((ref) {
  return SecureNonceStore(const FlutterSecureStorage());
});

// 讓 TxWatcher 在 provider 建立時自動 start，在釋放時 stop
final txWatcherProvider = Provider.autoDispose<TxWatcher>((ref) {
  final web3 = ref.watch(web3ServiceProvider);
  final store = ref.watch(nonceStoreProvider);

  final watcher = TxWatcher(ref: ref, store: store, web3: web3);
  watcher.start();

  ref.onDispose(() => watcher.stop());
  return watcher;
});
