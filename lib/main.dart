import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_demo/features/wallet/data/core/common/env.dart';
import 'features/startup/ui/startup_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await clearKeychainOnFreshInstall();
  await Env.load();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Wallet',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6851FF)),
      ),
      home: const StartupPage(),
    );
  }
}

Future<void> clearKeychainOnFreshInstall() async {
  // 1️⃣ 讀取本地 SharedPreferences（存放簡單 key-value 設定）
  final prefs = await SharedPreferences.getInstance();

  // 2️⃣ 檢查是否已經初始化過
  //    讀取布林值 'did_init'，若不存在就視為 false
  final didInit = prefs.getBool('did_init') ?? false;

  // 3️⃣ 如果「沒有初始化過」= 第一次啟動 App
  if (!didInit) {
    // 建立 FlutterSecureStorage 物件
    // Android: 使用 EncryptedSharedPreferences 保障安全
    // iOS: 設定 Keychain Accessibility 為 first_unlock
    const appSecureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    );

    // 4️⃣ 清空 SecureStorage
    //    刪除所有舊的敏感資料（私鑰、助記詞、Token 等）
    await appSecureStorage.deleteAll();

    // 5️⃣ 記錄已初始化過
    //    下次啟動時就不會再重複清空
    await prefs.setBool('did_init', true);
  }
}

