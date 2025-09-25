// test/test_utils/fake_secure_storage.dart
import 'package:flutter/src/foundation/basic_types.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _db = {};

  @override
  Future<String?> read({required String key, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async {
    return _db[key];
  }

  @override
  Future<void> write({required String key, required String? value, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async {
    if (value == null) {
      _db.remove(key);
    } else {
      _db[key] = value;
    }
  }

  @override
  Future<void> delete({required String key, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async {
    _db.remove(key);
  }

  // 其餘未用到的方法可丟 UnimplementedError（或留空）
  @override
  Future<Map<String, String>> readAll({IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) =>
      Future.value(Map.from(_db));

  @override
  Future<void> deleteAll({IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async {
    _db.clear();
  }

  @override
  // TODO: implement aOptions
  AndroidOptions get aOptions => throw UnimplementedError();

  @override
  Future<bool> containsKey({required String key, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) {
    // TODO: implement containsKey
    throw UnimplementedError();
  }

  @override
  // TODO: implement iOptions
  IOSOptions get iOptions => throw UnimplementedError();

  @override
  Future<bool?> isCupertinoProtectedDataAvailable() {
    // TODO: implement isCupertinoProtectedDataAvailable
    throw UnimplementedError();
  }

  @override
  // TODO: implement lOptions
  LinuxOptions get lOptions => throw UnimplementedError();

  @override
  // TODO: implement mOptions
  MacOsOptions get mOptions => throw UnimplementedError();

  @override
  // TODO: implement onCupertinoProtectedDataAvailabilityChanged
  Stream<bool>? get onCupertinoProtectedDataAvailabilityChanged => throw UnimplementedError();

  @override
  void registerListener({required String key, required ValueChanged<String?> listener}) {
    // TODO: implement registerListener
  }

  @override
  void unregisterAllListeners() {
    // TODO: implement unregisterAllListeners
  }

  @override
  void unregisterAllListenersForKey({required String key}) {
    // TODO: implement unregisterAllListenersForKey
  }

  @override
  void unregisterListener({required String key, required ValueChanged<String?> listener}) {
    // TODO: implement unregisterListener
  }

  @override
  // TODO: implement wOptions
  WindowsOptions get wOptions => throw UnimplementedError();

  @override
  // TODO: implement webOptions
  WebOptions get webOptions => throw UnimplementedError();
}
