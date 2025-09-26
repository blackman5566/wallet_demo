# 多鏈錢包 Flutter App

> Flutter/Riverpod 多鏈錢包作品，支援 Ethereum、Polygon、Solana 等測試網，著重在金鑰安全、交易可靠性與友善的錢包體驗。

## UI 預覽
<p align="center">
  <img src="images/Simulator%20Screenshot1.png" width="30%" alt="啟動畫面"/>
  <img src="images/Simulator%20Screenshot4.png" width="30%" alt="錢包主畫面"/>
  <img src="images/Simulator%20Screenshot7.png" width="30%" alt="發送介面"/>
</p>

更多畫面請參考 `images/` 目錄下的其餘截圖。

## Demo 影片
- [點我觀看操作影片](images/wallet_demo.mp4)
  
## 專案特色與技術棧
- **Flutter 3 + Material 3**：使用 `MaterialApp` 建立主題與啟動畫面，整個 App 以 Riverpod 管理狀態。首次啟動會清空安全儲存、載入 `.env`，再進入主畫面。 【F:lib/main.dart†L1-L52】
- **Riverpod 狀態管理**：`walletProvider`/`WalletNotifier` 是錢包中樞，負責初始化、刷新餘額、帳號切換與發送交易，並透過操作鎖避免重複觸發。 【F:lib/features/wallet/data/providers/wallet_notifier.dart†L1-L162】
- **多鏈抽象**：`supportedChains` 列出預設的 Ethereum Sepolia、Polygon Amoy、Solana Devnet，依 `ChainKind` 分辨 EVM/SOL，讓 UI 可以動態切換。 【F:lib/features/wallet/data/core/common/chains.dart†L1-L63】
- **金鑰與帳號管理**：`KeyService` 封裝助記詞保管、帳號索引與跨鏈金鑰推導，使用 `FlutterSecureStorage` 提供加密儲存。 【F:lib/features/wallet/data/core/keyService/core/key_service.dart†L1-L160】
- **EVM 交易管線**：`EvmChainClient` 會嘗試 EIP-1559 → Legacy fallback、搭配 `SecureNonceStore` 確保 nonce 單調並追蹤 pending；`Web3Service` 則提供逾時/重試/備援/熔斷的 RPC 呼叫。 【F:lib/features/wallet/data/chains/evm_chain_client.dart†L1-L125】【F:lib/features/wallet/data/core/service/evm/nonce_store.dart†L1-L115】【F:lib/features/wallet/data/core/service/evm/evm_rpc_service.dart†L1-L160】
- **交易監控與操作**：`TxWatcher` 週期拉取 pending 交易並在落塊後清除，配合 `txWatcherProvider` 自動啟動；`TxDetailPage` 可檢視交易、加速或取消。 【F:lib/features/wallet/data/core/service/evm/tx_watcher.dart†L1-L70】【F:lib/features/wallet/data/core/service/evm/tx_watcher_provider.dart†L1-L22】【F:lib/features/wallet/ui/widgets/tx_detail_page.dart†L1-L155】
- **Solana 整合**：`SolChainClient` 快速導出 Base58 地址並透過 `SolRpcService` 的 retry/fallback 設計送出交易。 【F:lib/features/wallet/data/chains/sol_chain_client.dart†L1-L88】【F:lib/features/wallet/data/core/service/sol/sol_rpc_service.dart†L1-L173】
- **安全導向 UX**：啟動時清除舊金鑰、設定頁的 `ExportMnemonicSheet` 會防截圖、顯示倒數、自動清空剪貼簿。 【F:lib/main.dart†L29-L52】【F:lib/features/wallet/ui/sheets/ExportMnemonicSheet.dart†L1-L137】

## 快速開始
1. 安裝 Flutter 開發環境（本專案使用 Stable 3.x）。
2. 取得依賴：
   ```bash
   flutter pub get
   ```
3. 準備環境變數：複製 `assets/env/.env`，視需求設定 `RPC_URL`、`CHAIN_ID`。若缺檔會使用預設 Ethereum Sepolia。 【F:lib/features/wallet/data/core/common/env.dart†L1-L33】
4. 執行 App：
   ```bash
   flutter run
   ```
5. 首次啟動會自動清空安全儲存；若想重新初始化，可刪除 App 後重裝。 【F:lib/main.dart†L29-L52】

## 架構總覽
- **啟動流程**：`StartupPage` 做 600ms 過場後導向 `MainScaffold`；`IndexedStack + NavigationBar` 管理「錢包 / 設定」分頁並保留狀態。 【F:lib/features/startup/ui/startup_page.dart†L1-L32】【F:lib/features/main/ui/main_scaffold.dart†L1-L36】
- **狀態層**：`walletProvider` 搭配 `walletExistsProvider`、`currentChainProvider` 等 provider，讓 UI 能即時獲得餘額、帳號與鏈別資訊。 【F:lib/features/wallet/data/providers/wallet_providers.dart†L1-L78】
- **服務層**：EVM 走 `Web3Service`，Solana 走 `SolRpcService`，統一透過 `run` 函式提供重試與備援邏輯。 【F:lib/features/wallet/data/core/service/evm/evm_rpc_service.dart†L1-L160】【F:lib/features/wallet/data/core/service/sol/sol_rpc_service.dart†L1-L112】
- **UI 層**：主頁 `WalletPage` 根據是否已有助記詞顯示 `SetupCard` 或 `WalletCard`，並決定開啟哪種 Send Sheet。 【F:lib/features/wallet/ui/wallet_page.dart†L1-L119】

- 以 `ChainClient` 介面抽象 EVM/Solana 的共用操作，`EvmChainClient`、`SolChainClient` 各自實作取得地址、餘額、送交易等功能。 【F:lib/features/wallet/data/chains/evm_chain_client.dart†L1-L99】【F:lib/features/wallet/data/chains/sol_chain_client.dart†L1-L63】
- `AccountSelector` 提供帳號切換、新增、刷新餘額，並透過 `ProviderScope.containerOf` 在 UI dispose 後仍能安全刷新 provider。 【F:lib/features/wallet/ui/widgets/account_selector.dart†L1-L139】
- `ImportMnemonicSheet` 支援匯入助記詞並重新初始化狀態；`SetupCard` 則提供建立/匯入入口。 【F:lib/features/wallet/ui/sheets/import_mnemonic_sheet.dart†L1-L118】【F:lib/features/wallet/ui/widgets/setup_card.dart†L1-L82】

### 交易體驗
- `SendSheet` 會自動估算 gas（加 20% buffer）、提供貼上地址與最大金額等輔助。成功送出後導向 `TxDetailPage` 追蹤狀態。 【F:lib/features/wallet/ui/sheets/send_sheet.dart†L1-L167】【F:lib/features/wallet/ui/widgets/tx_detail_page.dart†L1-L155】
- `SendSheetSol` 負責 SOL 轉帳，支援 base58 驗證、最大金額、lamports/SOL 轉換。 【F:lib/features/wallet/ui/sheets/sol_send_sheet.dart†L1-L145】
- `TxWatcher` 定期檢查 pending 交易並呼叫 `NonceStore.resolve`，確保本地 nonce 與鏈上同步。 【F:lib/features/wallet/data/core/service/evm/tx_watcher.dart†L1-L70】【F:lib/features/wallet/data/core/service/evm/nonce_store.dart†L25-L115】


### 安全與設定
- 所有助記詞與索引資料都儲存在 `FlutterSecureStorage`，iOS 使用 `unlocked_this_device`，Android 使用 `EncryptedSharedPreferences`。 【F:lib/features/wallet/data/core/keyService/core/key_service.dart†L1-L48】
- `ExportMnemonicSheet` 要求使用者確認風險、開啟防截圖、顯示倒數並自動清空剪貼簿。 【F:lib/features/wallet/ui/sheets/ExportMnemonicSheet.dart†L1-L137】
- 設定頁 (`SettingsPage`) 提供助記詞匯出入口，搭配底部彈窗流程完成驗證。 【F:lib/features/settings/ui/settings_page.dart†L1-L40】

## 使用流程（User Journey）
1. **首次啟動**：若沒有錢包，`WalletPage` 顯示 `SetupCard`，可建立新錢包或匯入助記詞。 【F:lib/features/wallet/ui/wallet_page.dart†L41-L99】【F:lib/features/wallet/ui/widgets/setup_card.dart†L1-L82】
2. **建立/匯入後**：顯示 `WalletCard`，提供地址複製、餘額展示、帳號切換與新增。 【F:lib/features/wallet/ui/widgets/wallet_card.dart†L1-L120】【F:lib/features/wallet/ui/widgets/account_selector.dart†L1-L139】
3. **發送交易**：依鏈別開啟 `SendSheet` 或 `SendSheetSol` 填寫資訊並送出，成功後進入 `TxDetailPage`。 【F:lib/features/wallet/ui/wallet_page.dart†L101-L118】【F:lib/features/wallet/ui/sheets/send_sheet.dart†L1-L214】【F:lib/features/wallet/ui/sheets/sol_send_sheet.dart†L1-L191】
4. **追蹤狀態**：`TxDetailPage` 可刷新、加速或取消交易，並透過 `TxWatcher` 背景同步 pending。 【F:lib/features/wallet/ui/widgets/tx_detail_page.dart†L1-L155】【F:lib/features/wallet/data/core/service/evm/tx_watcher.dart†L1-L70】
5. **安全備份**：在設定頁開啟 `ExportMnemonicSheet`，通過驗證後可暫時顯示助記詞並自動清除。 【F:lib/features/settings/ui/settings_page.dart†L1-L40】【F:lib/features/wallet/ui/sheets/ExportMnemonicSheet.dart†L1-L137】

## 待辦與改進方向
- Solana 轉帳目前未等待交易完成就提示成功，未來可補上 `await` 與詳情導流。 【F:lib/features/wallet/ui/sheets/sol_send_sheet.dart†L146-L191】
- 調整 EVM 發送面板的 UI 細節（如欄位文案、餘額提示），並補上更多自動化測試。
