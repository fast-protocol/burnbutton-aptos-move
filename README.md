# 🔴 BurnButton Factory (Aptos / Move)

**BurnButton Factory** is a permissionless, non-custodial **Burn-as-a-Service (BaaS)** and skill-based on-chain coordination protocol engineered in **Move** for the Aptos network.

Inspired by Reddit's legendary social psychology experiment (*The Button*), BurnButton transforms token deflation into a viral, high-retention multiplayer game of timing and strategy.

## 🎮 Core Mechanics (Skill & Game Theory)
* **Deterministic Last-Click Rules:** Zero randomness (no RNG or gambling). Every participant acts as a strategist in an open-information coordination game.
* **The Countdown Loop:** Users pay a micro-fee in a partner project's fungible asset/coin to press the button and reset a global countdown timer (e.g., 60 seconds).
* **The Endgame:** When the timer hits zero, the final strategist to press the button claims the accumulated **Arena Prize Pool**.
* **Community-Voted Weekly Arena:** Aptos users vote on-chain to select which ecosystem token takes center stage in the main weekly burn tournament.
* **Anti-Whale Fairness:** Configurable per-wallet press limits prevent large holders from monopolizing rounds, ensuring fair competition.

## 🔥 Tokenomics & Automated Deflation
Every button press executes 3 atomic on-chain transfers leveraging Aptos's parallel execution:
* **45% Permanently Burned:** Removed from circulating supply forever.
* **44% Active Arena Pool:** Rewards the final winner of the round.
* **10% Next-Round Seed:** Automatically bootstraps the next match so the pool never starts at zero.
* **1% Protocol Treasury:** Sustains indexing nodes and infrastructure.

## 🏗 Architecture (Aptos Migration v3.0)
* **`arena_factory.move`:** Enables any Aptos project or community to deploy a branded burn arena in one click.
* **`arena_template.move`:** Resource-safe Move architecture featuring **O(1) gas-optimized vault withdrawals** (no historical loop bottlenecks) and dynamic round parameters.
* **Async Indexer:** High-speed Python indexer (`aptos-sdk`) with sub-second WebSocket state synchronization and Petra/Martian wallet support.

## 🌐 Live EVM Proof-of-Work
Battle-tested v2.0 mainnet deployment: [burnbutton.xyz](https://burnbutton.xyz)
