# OpenWork Mainnet Deployment Documentation

**Version:** 26-Dec-2025
**Network:** Production Mainnet (Ethereum, Base, Arbitrum, Optimism, Polygon, Avalanche)

---

## 🚀 Quick Start

### For Deploying the System

**Start here for actual deployment:**

1. **[DEPLOYMENT_EXECUTION_CHECKLIST.md](./DEPLOYMENT_EXECUTION_CHECKLIST.md)** ⭐ **PRIMARY DOCUMENT**
   - Complete step-by-step checklist with every command
   - Checkbox tracking for each deployment step
   - Address recording variables
   - Configuration commands in correct order
   - Cross-chain LayerZero peer setup
   - Final verification commands
   - Template-based approach for local chains

### For Understanding the System

2. **[OPENWORK_MULTICHAIN_DEPLOYMENT_PLAN.md](./OPENWORK_MULTICHAIN_DEPLOYMENT_PLAN.md)**
   - System architecture overview
   - Chain configuration details
   - Contract deployment order and dependencies
   - Conceptual understanding of multichain deployment
   - UUPS proxy deployment patterns

### For Reference

3. **[DEPLOYMENT_COMMAND_TEMPLATES.md](./DEPLOYMENT_COMMAND_TEMPLATES.md)**
   - Command templates and syntax examples
   - UUPS 3-step deployment patterns
   - Chain-specific constants (EIDs, CCTP domains, addresses)
   - Configuration command patterns
   - Verification commands

---

## 📋 Deployment Overview

**Total Contracts:** 51 contracts across 6 chains
- **Main Chain (Ethereum):** 4 contracts
- **Native Chain (Base):** 19 contracts
- **Each Local Chain:** 7 contracts × 4 chains = 28 contracts

**Deployment Phases:**
1. Main Chain (Ethereum) - Governance & Rewards
2. Native Chain (Base) - Job Hub & Core Storage
3. Local Chains - Job Execution (Arbitrum, Optimism, Polygon, Avalanche)
4. Cross-Chain Configuration - LayerZero peers
5. Final Verification - System health checks

---

## 🔑 Key Requirements

### Before Starting

1. **Environment Setup**
   - RPC URLs for all 6 chains
   - Deployer private key with sufficient gas tokens
   - Multisig addresses for each chain
   - Forge/Cast installed (Foundry)

2. **Chain Requirements**
   - All local chains MUST support both LayerZero V2 and Circle CCTP
   - Sufficient gas tokens on each chain
   - USDC addresses verified for each chain

3. **Security**
   - Test deployment flow on testnet first
   - Use hardware wallet or secure key management
   - Verify all contract addresses after deployment
   - Transfer ownership to multisigs after verification

---

## 📊 Document Flow

```
START HERE
    ↓
[DEPLOYMENT_EXECUTION_CHECKLIST.md]  ← Run every command in order
    ↓
    ├─ Reference: [DEPLOYMENT_COMMAND_TEMPLATES.md] (for syntax help)
    └─ Reference: [OPENWORK_MULTICHAIN_DEPLOYMENT_PLAN.md] (for conceptual understanding)
    ↓
DEPLOYMENT COMPLETE
```

---

## ⚠️ Important Notes

### 🚨 CRITICAL: Documentation is Mandatory

**Before deploying a single contract:**
1. Set up deployment log file (see checklist Section 0)
2. Install logging helper functions
3. Record EVERY command and output
4. Create contract address registry

**Mainnet deployment without comprehensive logs is extremely risky and should never be attempted.**

### General Requirements

1. **Sequential Execution:** Follow the exact order - dependencies matter
2. **Address Tracking:** Export each deployed address immediately
3. **Command Logging:** Use `tee` to capture all outputs to deployment log
4. **Verification:** Run verification commands after each major step
5. **Backup:** Save all addresses, transaction hashes, and logs
6. **Multisig:** Transfer ownership to multisigs after complete verification
7. **Gas Management:** Monitor gas prices, especially on Ethereum
8. **CCTP Funding:** Ensure CCTP transceivers have sufficient ETH for rewards
9. **LayerZero Peers:** All peer configurations must be bidirectional
10. **Post-Deployment:** Complete all documentation (Section 7 of checklist)

---

## 🔗 Cross-Chain Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    MAIN CHAIN (Ethereum)                     │
│  OpenWork Token, Main DAO, Main Rewards, Main Bridge        │
└──────────────────────┬──────────────────────────────────────┘
                       │ LayerZero V2
                       ↓
┌─────────────────────────────────────────────────────────────┐
│                     NATIVE CHAIN (Base)                      │
│  Job Hub: NOWJC, Native Athena, Native DAO, Genesis, etc.   │
└───┬──────────────┬──────────────┬──────────────┬────────────┘
    │              │              │              │
    │ LayerZero +  │ LayerZero +  │ LayerZero +  │ LayerZero +
    │ CCTP         │ CCTP         │ CCTP         │ CCTP
    ↓              ↓              ↓              ↓
┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐
│Arbitrum │  │Optimism │  │ Polygon │  │Avalanche│
│ LOWJC   │  │ LOWJC   │  │ LOWJC   │  │ LOWJC   │
│ Client  │  │ Client  │  │ Client  │  │ Client  │
│ Bridge  │  │ Bridge  │  │ Bridge  │  │ Bridge  │
└─────────┘  └─────────┘  └─────────┘  └─────────┘
 LOCAL CHAIN  LOCAL CHAIN  LOCAL CHAIN  LOCAL CHAIN
```

---

## 📞 Support

For issues or questions:
- Check the execution checklist first - it has troubleshooting notes
- Review the deployment plan for conceptual understanding
- Verify all environment variables are set correctly
- Ensure sufficient gas tokens on all chains

---

**Document Status:** Ready for production mainnet deployment
**Last Updated:** 28-Dec-2025
