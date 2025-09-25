import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/key_service.dart';

/// 金鑰服務：負責助記詞、私鑰、索引的讀寫與導出
final keyServiceProvider = Provider((ref) => KeyService());