# Multi-Chain Wallet -- Flutter App

> A Flutter/Riverpod multi-chain wallet supporting Ethereum, Polygon,
> and Solana testnets.\
> Focused on **key security**, **transaction reliability**, and a
> **smooth wallet experience**.

## UI Preview

<p align="center">
  <img src="images/Simulator%20Screenshot1.png" width="30%" alt="啟動畫面"/>
  <img src="images/Simulator%20Screenshot4.png" width="30%" alt="錢包主畫面"/>
  <img src="images/Simulator%20Screenshot7.png" width="30%" alt="發送介面"/>
</p>
More screenshots are available in the `images/` directory.

## Demo Video

-   [Watch the demo](images/wallet_demo.mp4)

## Features & Tech Stack

-   **Flutter 3 + Material 3**\
    Built with `MaterialApp` and Riverpod for state management. On first
    launch, the app clears secure storage, loads `.env`, and then enters
    the main screen.

-   **Riverpod State Management**\
    `walletProvider` / `WalletNotifier` act as the wallet
    core---handling initialization, balance refresh, account switching,
    and transaction sending with an operation lock to prevent duplicate
    triggers.

-   **Multi-Chain Abstraction**\
    `supportedChains` lists default Ethereum Sepolia, Polygon Amoy, and
    Solana Devnet networks. `ChainKind` distinguishes EVM vs. Solana so
    the UI can switch dynamically.

-   **Key & Account Management**\
    `KeyService` handles mnemonic storage, account indexes, and
    cross-chain key derivation using `FlutterSecureStorage` for
    encrypted persistence.

-   **EVM Transaction Pipeline**\
    `EvmChainClient` attempts EIP-1559 first, then falls back to Legacy.
    It works with `SecureNonceStore` to ensure monotonic nonces and
    track pending transactions. `Web3Service` provides timeout, retry,
    fallback, and circuit-breaker logic.

-   **Transaction Monitoring & Control**\
    `TxWatcher` periodically polls pending transactions and clears them
    once finalized. `txWatcherProvider` starts it automatically.
    `TxDetailPage` lets users view, speed up, or cancel transactions.

-   **Solana Integration**\
    `SolChainClient` quickly derives Base58 addresses and sends
    transactions via `SolRpcService` with built-in retry and fallback.

-   **Security-Focused UX**\
    Startup wipes old keys. The settings page's `ExportMnemonicSheet`
    disables screenshots, shows a countdown, and automatically clears
    the clipboard.

## Quick Start

1.  Install a Flutter 3.x stable environment.

2.  Fetch dependencies:

    ``` bash
    flutter pub get
    ```

3.  Prepare environment variables: copy `assets/env/.env` and set
    `RPC_URL` and `CHAIN_ID` as needed.\
    If missing, Ethereum Sepolia defaults are used.

4.  Run the app:

    ``` bash
    flutter run
    ```

5.  On first launch secure storage is cleared. To re-initialize, delete
    and reinstall the app.

## Architecture Overview

-   **Startup Flow**\
    `StartupPage` shows a 600 ms splash and then navigates to
    `MainScaffold`.\
    `IndexedStack + NavigationBar` manage the "Wallet / Settings" tabs
    while preserving state.

-   **State Layer**\
    `walletProvider` works with helpers such as `walletExistsProvider`
    and `currentChainProvider` to keep balances, accounts, and chain
    information in sync.

-   **Service Layer**\
    EVM calls use `Web3Service`, Solana calls use `SolRpcService`. Both
    share a unified `run` function with retry and fallback logic.

-   **UI Layer**\
    `WalletPage` decides whether to show `SetupCard` or `WalletCard`,
    and which send sheet to open.\
    `AccountSelector` supports account switching/adding and balance
    refreshing even after UI disposal using `ProviderScope.containerOf`.

-   **Abstraction**\
    `ChainClient` defines common EVM/Solana operations.\
    `EvmChainClient` and `SolChainClient` each implement address
    retrieval, balance queries, and transaction sending.

-   **Setup & Import**\
    `ImportMnemonicSheet` imports an existing mnemonic and
    re-initializes state.\
    `SetupCard` offers create/import entry points.

### Transaction Experience

-   **EVM**: `SendSheet` estimates gas (adds a 20 % buffer), provides
    "Paste Address" and "Max Amount," and navigates to `TxDetailPage`
    after submission.
-   **Solana**: `SendSheetSol` validates Base58, supports max amount,
    and handles lamports/SOL conversion.
-   **Watcher**: `TxWatcher` periodically checks pending transactions
    and calls `NonceStore.resolve` to keep local nonces in sync.

### Security & Settings

-   All mnemonics and indexes are stored in `FlutterSecureStorage`
    (`unlocked_this_device` on iOS, `EncryptedSharedPreferences` on
    Android).
-   `ExportMnemonicSheet` enforces a warning, disables screenshots,
    shows a countdown, and clears the clipboard after display.
-   `SettingsPage` provides a secure export flow with a bottom-sheet
    dialog.

## User Journey

1.  **First Launch**: If no wallet exists, `WalletPage` shows
    `SetupCard` to create or import.
2.  **After Setup**: `WalletCard` displays address, balance, and allows
    switching or adding accounts.
3.  **Send Transaction**: Opens `SendSheet` or `SendSheetSol` depending
    on the chain, then navigates to `TxDetailPage`.
4.  **Track Status**: `TxDetailPage` refreshes, accelerates, or cancels
    transactions while `TxWatcher` keeps pending ones synced.
5.  **Secure Backup**: From Settings, open `ExportMnemonicSheet`, pass
    verification, and view the mnemonic with auto-cleanup.

## Future Improvements

-   Solana transfers currently mark success before confirmation; will
    add `await` and detailed navigation.
-   Refine EVM send-panel UI (labels, balance hints) and add more
    automated tests.
