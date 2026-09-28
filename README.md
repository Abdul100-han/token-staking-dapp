# Token Staking DApp (Synthetix Staking Algorithm)

A full-stack staking protocol on **Ethereum Sepolia**. Users deposit `$STK`, accrue `$RWD` every second using Synthetix-style O(1) reward accounting, and claim through a Next.js + Wagmi interface.

[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-363636?logo=solidity)](https://docs.soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-forge-black?logo=ethereum)](https://book.getfoundry.sh/)
[![Next.js](https://img.shields.io/badge/Next.js-16-black?logo=nextdotjs)](https://nextjs.org/)
[![Sepolia](https://img.shields.io/badge/Network-Sepolia-blue?logo=ethereum)](https://sepolia.etherscan.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Live demo:** [https://your-vercel-app.vercel.app](https://your-vercel-app.vercel.app)

**Sepolia contracts (verified / source links):**

| Contract | Address |
| --- | --- |
| Staking Token (`STK`) | [0xB25E5D7374c0B6B88819C6Bf774AEf4f4d3fBF18](https://sepolia.etherscan.io/address/0xB25E5D7374c0B6B88819C6Bf774AEf4f4d3fBF18) |
| Reward Token (`RWD`) | [0xA3cD5A33b9bDDb8214041ba79aFC468dB7F5DD55](https://sepolia.etherscan.io/address/0xA3cD5A33b9bDDb8214041ba79aFC468dB7F5DD55) |
| Staking Engine | [0xB8B39f6d8a225DBFe418d5E0A658D34b6b13c79e](https://sepolia.etherscan.io/address/0xB8B39f6d8a225DBFe418d5E0A658D34b6b13c79e) |

---

## Architecture & System Flow

```text
┌─────────────────────────────────────────────────────────────────┐
│                         User Wallet                              │
│                    (RainbowKit / MetaMask)                       │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Next.js App Router UI                        │
│         Header + StakingDashboard (approve / stake / claim)      │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Wagmi + Viem + React Query                   │
│              Reads, writes, and tx receipt tracking              │
└──────────────────────────────┬──────────────────────────────────┘
                               │  JSON-RPC (Alchemy / public RPC)
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Ethereum Sepolia                           │
│                                                                  │
│   $STK ERC-20  ──transferFrom──►  StakingEngine  ──mint──► $RWD  │
│   (faucet mint)                   stake / withdraw / earned      │
└─────────────────────────────────────────────────────────────────┘
```

1. The UI reads balances, allowance, total staked, and `earned(user)` through Wagmi.
2. The user mints test `$STK`, approves the engine, then calls `stake`.
3. Rewards accrue continuously while tokens remain in the vault.
4. `claimReward` asks `RewardToken` to mint `$RWD` to the caller. Only the engine can mint rewards.

---

## Core Smart Contract Mechanics & Math

`StakingEngine` follows the Synthetix staking rewards model. Instead of looping over stakers each second, it stores a global **reward-per-token** index and snapshots each user against that index.

**Global index**

```text
rewardPerToken = rewardPerTokenStored
               + ((lastTimeRewardApplicable - lastUpdateTime) * rewardRate * 1e18)
                 / totalStaked
```

If `totalStaked == 0`, the index is left unchanged so time without deposits does not mint phantom yield.

**User claimable amount**

```text
earned(account) = rewards[account]
                + (balances[account] * (rewardPerToken - userRewardPerTokenPaid[account]))
                  / 1e18
```

The `1e18` factor preserves precision while dividing by total stake.

**Why this is O(1)**

- Updating the global index is a constant-time write on `stake`, `withdraw`, and `claimReward` (`updateReward` modifier).
- Each user pays for their own snapshot. There is no `for` loop over N depositors.
- That matters on L1: reward accounting does not grow with the number of stakers.

`rewardRate` is currently `100` wei of `$RWD` per second across the whole pool. A lone staker receives the full stream; multiple stakers split it pro-rata by their share of `totalSupply()`.

---

## Tech Stack & Tooling

**Smart contracts**

- Solidity `0.8.20`
- OpenZeppelin Contracts (`ERC20`, `Ownable`, `ReentrancyGuard`, `IERC20`)
- Foundry (`forge test`, `forge script`, gas reports)
- Sepolia testnet
- Alchemy (or compatible) JSON-RPC + Etherscan verification keys

**Frontend**

- Next.js App Router (TypeScript)
- Tailwind CSS
- Wagmi + Viem
- RainbowKit wallet modal
- TanStack React Query

---

## Security & Smart Contract Safeguards

- **`ReentrancyGuard`**: `stake`, `withdraw`, `claimReward`, and `exit` use `nonReentrant`. Token transfers happen after storage updates.
- **Access control**: `RewardToken.mint` is `onlyOwner`. Ownership is transferred to `StakingEngine` at deploy time, so only the vault can mint `$RWD`. `$STK` keeps a public faucet `mint` for Sepolia testing.
- **Checks-Effects-Interactions**: balances and `totalSupply` are updated and events emitted before `transfer` / `transferFrom` / `mint`.
- **OpenZeppelin custom errors**: `Ownable` reverts with typed errors such as `OwnableUnauthorizedAccount`. Engine user paths still use explicit `require` messages (`Cannot stake 0`, `Insufficient staked balance`).
- **Foundry coverage**: unit tests, revert tests, and fuzz tests for stake/withdraw amount and caller address.

This is unaudited educational / portfolio code. Do not use it with mainnet funds.

---

## Local Development & Testing Instructions

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js 20+ (nvm recommended)
- Git, with submodules initialized

```bash
git clone https://github.com/Abdul100-han/token-staking-dapp.git
cd token-staking-dapp
git submodule update --init --recursive
```

### Smart contracts

```bash
cd contracts
forge test -vvv
forge test --gas-report
```

Copy `contracts/.env.example` to `contracts/.env` and fill `PRIVATE_KEY`, `RPC_URL`, and `ETHERSCAN_API_KEY` before broadcasting. Never commit `.env`.

```bash
source .env
forge script script/DeployStaking.s.sol:DeployStaking \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --slow \
  --verify \
  --etherscan-api-key "$ETHERSCAN_API_KEY" \
  -vv
```

### Frontend

```bash
cd frontend
cp .env.example .env.local
# set NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID (and optional Alchemy RPC)
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000), connect a Sepolia wallet, mint test `$STK`, approve, then stake.

WalletConnect project IDs: [cloud.walletconnect.com](https://cloud.walletconnect.com).

---

## Project Directory Layout

```text
token_staking_dapp/
├── .github/
│   └── workflows/
│       └── test.yml              # Foundry CI on push / PR
├── contracts/
│   ├── src/
│   │   ├── StakingToken.sol      # $STK faucet ERC-20
│   │   ├── RewardToken.sol       # $RWD, engine-owned mint
│   │   └── StakingEngine.sol     # Synthetix-style vault
│   ├── script/
│   │   └── DeployStaking.s.sol   # Sepolia bundle deploy
│   ├── test/
│   │   └── StakingEngine.t.sol
│   ├── lib/                      # forge-std, OpenZeppelin (submodules)
│   ├── foundry.toml
│   └── .env.example
├── frontend/
│   ├── src/
│   │   ├── app/                  # App Router layout + page
│   │   ├── components/
│   │   │   ├── Header.tsx
│   │   │   └── StakingDashboard.tsx
│   │   ├── config.ts             # Wagmi / RainbowKit / Sepolia
│   │   ├── constants.ts          # Addresses + ABIs
│   │   └── providers.tsx
│   ├── package.json
│   └── .env.example
└── README.md
```
