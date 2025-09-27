# OpenWork Multi-Chain System Architecture

**Last Updated**: September 27, 2025  
**Version**: 2.0 - Base Sepolia Main Chain Integration

---

## 🏗️ **System Overview**

The OpenWork protocol is a sophisticated multi-chain decentralized freelancing platform that operates across multiple blockchain networks using LayerZero for cross-chain messaging and Circle's CCTP (Cross-Chain Transfer Protocol) for USDC transfers.

---

## 📋 **Chain Roles & Responsibilities**

### **🌟 Main Chain (Base Sepolia)**
**Role**: Governance & Rewards Hub  
**EID**: 40245  
**CCTP Domain**: N/A  

**Contracts:**
- **OpenWork Token (OW)** - Governance token for staking and voting
- **Main DAO** - Primary governance contract with cross-chain voting power
- **Main Rewards** - Token distribution and rewards management
- **Main Chain Bridge** - LayerZero hub for cross-chain governance coordination

**Responsibilities:**
- ✅ **Governance Decisions** - All major protocol decisions
- ✅ **Token Distribution** - OpenWork token rewards and staking
- ✅ **Cross-Chain Coordination** - Governs all connected chains
- ✅ **Voting Power Aggregation** - Combines stake + earned rewards for voting

---

### **⚡ Native Chain (Arbitrum Sepolia)**
**Role**: Job Hub & Dispute Resolution  
**EID**: 40231  
**CCTP Domain**: 3  

**Contracts:**
- **Genesis** - Core data storage contract
- **Native DAO** - Local governance with earned token voting power
- **NOWJC** - Native OpenWork Job Contract (job coordination hub)
- **Native Athena** - Decentralized dispute resolution system
- **Native Rewards** - Local rewards calculation and distribution
- **CCTP Transceiver** - Cross-chain USDC payment processing
- **Native Bridge** - LayerZero messaging to Main Chain and Local Chains

**Responsibilities:**
- ✅ **Job Coordination** - Central hub for all job lifecycle management
- ✅ **Dispute Resolution** - Automated dispute settlement via Native Athena
- ✅ **Payment Processing** - USDC distribution via CCTP
- ✅ **Rewards Calculation** - Earned token rewards based on job completion
- ✅ **Cross-Chain Messaging** - Routes job events to appropriate chains

---

### **🔗 Local Chain(s) (OP Sepolia, Ethereum Sepolia)**
**Role**: Job Execution & User Interface  
**EIDs**: 40232 (OP), 40161 (ETH)  
**CCTP Domains**: 2 (OP), 0 (ETH)  

**Contracts:**
- **LOWJC** - Local OpenWork Job Contract (job posting and applications)
- **Athena Client** - Local dispute interface
- **CCTP Transceiver** - Local USDC payment handling
- **Local Bridge** - LayerZero messaging to Native Chain

**Responsibilities:**
- ✅ **Job Posting** - Users post jobs on preferred chains
- ✅ **Job Applications** - Workers apply from any local chain
- ✅ **Local Payments** - Users can pay/receive on preferred chains
- ✅ **Dispute Initiation** - Raise disputes that route to Native Chain

---

## 🔄 **Cross-Chain Message Flow**

```mermaid
graph TB
    subgraph "Base Sepolia (Main Chain)"
        A[Main DAO] 
        B[Main Rewards]
        C[Main Bridge]
        D[OpenWork Token]
    end
    
    subgraph "Arbitrum Sepolia (Native Chain)"
        E[Native DAO]
        F[NOWJC]
        G[Native Athena]
        H[Native Rewards]
        I[Native Bridge]
    end
    
    subgraph "OP Sepolia (Local Chain)"
        J[LOWJC]
        K[Athena Client]
        L[Local Bridge]
    end
    
    subgraph "Ethereum Sepolia (Local Chain)"
        M[LOWJC]
        N[Athena Client]
        O[Local Bridge]
    end
    
    C ↔ I
    I ↔ L
    I ↔ O
    L ↔ J
    O ↔ M
```

### **Message Types:**

#### **1. Job Lifecycle Messages**
- **Local → Native**: Job posting, applications, work submissions
- **Native → Local**: Job approvals, payment releases, dispute outcomes

#### **2. Governance Messages**
- **Native → Main**: Voting power sync (earned tokens), governance actions
- **Main → Native**: Governance decisions, parameter updates, upgrades

#### **3. Payment Messages**
- **Local ↔ Native**: CCTP USDC transfers for job payments
- **Native → Main**: Rewards token distribution requests

#### **4. Dispute Messages**
- **Local → Native**: Dispute initiation, evidence submission
- **Native → Local**: Dispute outcomes, fund releases

---

## 💰 **Payment & Token Flow**

### **USDC Payments (via CCTP)**
```
Job Giver (Local Chain) → LOWJC → CCTP → NOWJC (Native) → CCTP → Job Taker (Any Chain)
```

### **OpenWork Token Rewards**
```
Job Completion (Native) → Native Rewards → Native DAO → Main Bridge → Main Rewards → Token Distribution
```

### **Governance Voting Power**
```
Staked Tokens (Main) + Earned Tokens (Native) = Combined Voting Power
```

---

## 🎯 **Data Flow Examples**

### **Example 1: Job Posting Flow**
1. **User posts job** on OP Sepolia LOWJC
2. **LOWJC** sends message via Local Bridge → Native Bridge → NOWJC
3. **NOWJC** validates and stores job data in Genesis
4. **NOWJC** sends confirmation back to LOWJC
5. **Job is live** across all connected chains

### **Example 2: Dispute Resolution Flow**
1. **Dispute raised** on Ethereum Sepolia Athena Client
2. **Message routed** via Local Bridge → Native Bridge → Native Athena
3. **Native Athena** handles voting and resolution
4. **Outcome sent** back to all relevant chains
5. **Funds released** automatically via CCTP

### **Example 3: Governance Flow**
1. **User earns tokens** completing jobs on Native Chain
2. **Native DAO** tracks earned tokens for voting power
3. **Voting power synced** to Main DAO on Base Sepolia
4. **Combined voting power** (stake + earned) used for governance
5. **Governance decisions** executed across all chains

---

## 🔐 **Security & Trust Model**

### **LayerZero Security**
- **Peer Configuration**: Each bridge only accepts messages from authorized peers
- **Message Verification**: All cross-chain messages are cryptographically verified
- **Upgrade Protection**: Only Main DAO can upgrade contracts across chains

### **Economic Security**
- **Dispute Stakes**: Users stake tokens to participate in dispute resolution
- **Governance Stakes**: Minimum stake required for proposal creation
- **Earned Token Voting**: Voting power tied to actual platform usage

### **Contract Ownership**
- **Main Chain**: Owned by Main DAO (decentralized governance)
- **Native Chain**: Owned by Native DAO with Main DAO oversight
- **Local Chains**: Owned by respective bridges with cross-chain governance

---

## 📊 **Contract Deployment Matrix**

| Contract Type | Base Sepolia | Arbitrum Sepolia | OP Sepolia | Ethereum Sepolia |
|---------------|--------------|------------------|------------|------------------|
| **DAO** | Main DAO ✅ | Native DAO ✅ | ❌ | ❌ |
| **Job Contract** | ❌ | NOWJC ✅ | LOWJC ✅ | LOWJC ✅ |
| **Dispute System** | ❌ | Native Athena ✅ | Athena Client ✅ | Athena Client ✅ |
| **Rewards** | Main Rewards ✅ | Native Rewards ⚠️ | ❌ | ❌ |
| **Bridge** | Main Bridge ✅ | Native Bridge ✅ | Local Bridge ✅ | Local Bridge ✅ |
| **CCTP** | ❌ | Transceiver ✅ | Transceiver ✅ | Transceiver ✅ |
| **Token** | OpenWork ✅ | ❌ | ❌ | ❌ |

**Legend:**
- ✅ **Deployed & Active**
- ⚠️ **Needs Deployment**
- ❌ **Not Required**

---

## 🚀 **Deployment Status**

### **✅ Completed**
- **Base Sepolia**: Main Chain infrastructure complete
- **Arbitrum Sepolia**: Job hub operational (missing Native DAO & Native Rewards)
- **OP Sepolia**: Local chain operational
- **Ethereum Sepolia**: Local chain operational

### **⚠️ Pending**
- **Native DAO**: Deploy on Arbitrum Sepolia (correct location)
- **Native Rewards**: Deploy on Arbitrum Sepolia
- **Cross-Chain Integration**: Connect Native DAO ↔ Main DAO

### **🔧 Configuration Required**
- LayerZero peer configuration between all chains
- CCTP transceiver configuration for payment flows
- Genesis contract integration with Native DAO

---

**Architecture Status**: 90% Complete - Missing Native Chain DAO & Rewards  
**Next Priority**: Deploy Native DAO on Arbitrum Sepolia  
**Integration Status**: Main ↔ Native bridge configured, Local ↔ Native operational