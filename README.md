# BlockEstate Protocol

BlockEstate is a modular smart contract system for tokenizing real-world real estate assets into ERC20 tokens with built-in compliance, referral rewards, and revenue distribution.

---

## Overview

The protocol enables:

- Fractional ownership of real estate via ERC20 tokens
- On-chain and fiat-based investments
- KYC and blacklist enforcement
- Automated referral reward tracking
- Revenue distribution to token holders

The system is designed with a router-based architecture to allow flexible upgrades and clean separation of concerns.

---

## Architecture

### Core Contracts

- **BlockEstateAccessControl**
  - Manages roles, KYC, blacklist, and protocol pause

- **BlockEstateRouter**
  - Central registry for all protocol addresses

---

### Modules

- **BlockEstateTokenizationFactory**
  - Creates property tokens
  - Handles investments (on-chain and fiat)

- **BlockEstateAssetIssuance**
  - Deploys new property token contracts

- **BlockEstatePropertyToken**
  - ERC20 token representing ownership in a property
  - Enforces compliance on transfers

- **BlockEstateRevenueDistributor**
  - Distributes revenue to token holders

- **BlockEstateReferralRewards**
  - Tracks and distributes referral rewards

---

## Key Features

### Compliance Layer
- KYC enforcement
- Blacklist protection
- Global pause mechanism

### Investment System
- On-chain stablecoin investments
- Fiat-backed investments with signature verification

### Revenue Distribution
- Proportional distribution based on token holdings
- Precision accounting with accumulated rewards

### Referral System
- Configurable referral percentage
- On-chain reward tracking and claiming

---

## Configuration

After deployment, configure:

- Router addresses (factory, treasury, modules)
- Backend signer
- Role assignments in AccessControl
- Stable token address

---

## Development

### Requirements

- Solidity `0.8.33`
- Foundry

### Install Dependencies

```bash
forge install
```

### Build

```bash
forge build
```

### Test

```bash
forge test
```

### Deploy

```bash
forge script script/DeployBlockEstate.s.sol \
  --rpc-url <RPC_URL> \
  --private-key <PRIVATE_KEY> \
  --broadcast
```

---

## Security Notes

- Ensure multisig is used for admin roles in production
- Backend signer must be securely managed
- Stable token must be trusted and verified
- Audit recommended before mainnet deployment

---

## License

MIT
