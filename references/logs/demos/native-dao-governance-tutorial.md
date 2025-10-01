# Native DAO Governance Tutorial - Complete Guide

**Date**: September 27, 2025  
**Purpose**: Complete tutorial for using the Native DAO governance system  
**Architecture**: Arbitrum Sepolia Native DAO with cross-chain integration  
**Status**: ✅ **PRODUCTION READY** - Step-by-step governance guide

---

## 🎯 **What is Native DAO?**

The Native DAO is OpenWork's governance system that allows token holders to:
- Create and vote on proposals
- Manage system parameters
- Control contract upgrades
- Authorize oracles and integrations
- Make decisions about the platform's future

**Key Features:**
- **Dual Voting Power**: Combine staked tokens + earned tokens from job completion
- **Cross-Chain Integration**: Proposals can affect contracts across multiple chains
- **Upgradeable Governance**: Built on OpenZeppelin Governor for security and flexibility
- **Time-locked Execution**: Built-in delays for security

---

## 📋 **Contract Addresses & Setup**

### **Core Contracts**
| Contract | Network | Address | Purpose |
|----------|---------|---------|---------|
| **Native DAO** | Arbitrum Sepolia | `0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5` | Main governance contract |
| **Native Athena** | Arbitrum Sepolia | `0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE` | Dispute resolution target |
| **NOWJC** | Arbitrum Sepolia | `0x9E39B37275854449782F1a2a4524405cE79d6C1e` | Job contract (voting power source) |

### **Prerequisites**
- Arbitrum Sepolia testnet setup
- ETH for gas fees
- Voting power (staked tokens OR earned tokens from jobs)

---

## 🚀 **Phase 1: Check Your Voting Power**

Before creating proposals, verify you have sufficient voting power:

### **Step 1: Check Earned Tokens (from Job Completion)**
```bash
source .env && cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0x9E39B37275854449782F1a2a4524405cE79d6C1e \
  "getUserEarnedTokens(address)(uint256)" \
  YOUR_WALLET_ADDRESS
```

### **Step 2: Check Staked Tokens (from Native DAO)**
```bash
source .env && cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 \
  "getStakerInfo(address)" \
  YOUR_WALLET_ADDRESS
```

### **Step 3: Check Total Voting Power**
```bash
source .env && cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 \
  "getVotes(address)" \
  YOUR_WALLET_ADDRESS
```

**Expected Results:**
- Earned tokens: Tokens earned from completing jobs
- Staked tokens: Tokens staked in the DAO for governance
- Total voting power: Combined power for proposal creation/voting

---

## ⚖️ **Phase 2: Creating Governance Proposals**

### **Step 4: Prepare Your Proposal**

**Example: Create an Oracle for Dispute Resolution**

First, generate the function call data:
```bash
source .env && cast calldata \
  "addSingleOracle(string,address[],string,string,address[])" \
  "YourOracleName" \
  '[0xYourAddress1,0xYourAddress2,0xYourAddress3]' \
  "Your Oracle Description" \
  "QmYourOracleHash" \
  '[]'
```

**Example Output:**
```
0x4a9fe8f900000000000000000000000000000000000000000000000000000000000000a0...
```

### **Step 5: Submit the Proposal**
```bash
source .env && cast send 0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 \
  "propose(address[],uint256[],bytes[],string)" \
  '[0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE]' \
  '[0]' \
  '[YOUR_CALLDATA_FROM_STEP_4]' \
  "Your proposal description for voters" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $YOUR_PRIVATE_KEY
```

**What happens:**
- Proposal is created with a unique ID
- Voting delay period begins (typically 1 block)
- Proposal becomes active for voting

### **Step 6: Find Your Proposal ID**

From the transaction logs, extract the proposal ID:
```bash
# Check the transaction receipt for the proposal ID in the event logs
source .env && cast receipt YOUR_TRANSACTION_HASH --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

Convert the hex proposal ID to decimal:
```bash
cast to-dec 0xYOUR_PROPOSAL_ID_IN_HEX
```

---

## 🗳️ **Phase 3: Voting on Proposals**

### **Step 7: Check Proposal Status**
```bash
source .env && cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 \
  "state(uint256)" \
  YOUR_PROPOSAL_ID_DECIMAL
```

**Proposal States:**
- `0` = Pending (waiting for voting to start)
- `1` = Active (voting is open)
- `2` = Canceled
- `3` = Defeated (not enough votes)
- `4` = Succeeded (ready for execution)
- `5` = Queued (in timelock)
- `6` = Expired
- `7` = Executed

### **Step 8: Vote on the Proposal**
```bash
source .env && cast send 0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 \
  "castVote(uint256,uint8)" \
  YOUR_PROPOSAL_ID_DECIMAL \
  1 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $YOUR_PRIVATE_KEY
```

**Vote Options:**
- `0` = Against
- `1` = For
- `2` = Abstain

### **Step 9: Check Vote Results**
```bash
source .env && cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 \
  "proposalVotes(uint256)" \
  YOUR_PROPOSAL_ID_DECIMAL
```

**Returns:** `[againstVotes, forVotes, abstainVotes]`

---

## ✅ **Phase 4: Executing Successful Proposals**

### **Step 10: Wait for Voting Period to End**

Check when voting ends:
```bash
source .env && cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 \
  "proposalDeadline(uint256)" \
  YOUR_PROPOSAL_ID_DECIMAL
```

### **Step 11: Execute the Proposal**

Once the proposal state is `4` (Succeeded), execute it:

First, calculate the description hash:
```bash
source .env && cast keccak "Your exact proposal description from step 5"
```

Then execute:
```bash
source .env && cast send 0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 \
  "execute(address[],uint256[],bytes[],bytes32)" \
  '[0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE]' \
  '[0]' \
  '[YOUR_CALLDATA_FROM_STEP_4]' \
  YOUR_DESCRIPTION_HASH \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $YOUR_PRIVATE_KEY
```

**Success!** Your proposal is now executed and the changes are live.

---

## 🔧 **Common Proposal Types**

### **1. Oracle Management**

**Add Oracle:**
```bash
# Calldata for adding an oracle
cast calldata "addSingleOracle(string,address[],string,string,address[])" \
  "OracleName" \
  '[0xMember1,0xMember2,0xMember3]' \
  "Oracle Description" \
  "QmOracleHash" \
  '[]'
```

**Remove Oracle:**
```bash
# Calldata for removing an oracle
cast calldata "removeOracle(string[])" \
  '["OracleNameToRemove"]'
```

### **2. Parameter Updates**

**Update Voting Threshold:**
```bash
# Calldata for updating voting requirements
cast calldata "updateVotingRewardThreshold(uint256)" \
  NEW_THRESHOLD_VALUE
```

**Update Voting Period:**
```bash
# Calldata for updating voting period
cast calldata "updateVotingPeriod(uint256)" \
  NEW_PERIOD_MINUTES
```

### **3. Contract Upgrades**

**Upgrade Implementation:**
```bash
# Calldata for upgrading a contract
cast calldata "upgradeToAndCall(address,bytes)" \
  NEW_IMPLEMENTATION_ADDRESS \
  "0x"
```

---

## 📊 **Monitoring & Analytics**

### **Check All Active Proposals**
```bash
# Get recent proposal events
source .env && cast logs --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --from-block RECENT_BLOCK \
  --address 0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 \
  --topic0 0x7d84a6263ae0d98d3329bd7b46bb4e8d6f98cd35a7adb45c274c8b7fd5ebd5e0
```

### **Check Voting History**
```bash
# Get your voting history
source .env && cast logs --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --from-block RECENT_BLOCK \
  --address 0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 \
  --topic0 0xb8e138887d0aa13bab447e82de9d5c1777041ecd21ca36ba824ff1e6c07ddda4 \
  --topic1 0x000000000000000000000000YOUR_ADDRESS
```

---

## 🎯 **Best Practices**

### **For Proposal Creators**
1. **Clear Descriptions**: Write detailed, clear proposal descriptions
2. **Test Calldata**: Verify function calls work before proposing
3. **Community Engagement**: Discuss proposals with community first
4. **Adequate Voting Power**: Ensure you meet minimum requirements

### **For Voters**
1. **Research Proposals**: Understand what you're voting on
2. **Vote Responsibly**: Consider long-term platform health
3. **Participate Actively**: Don't let proposals fail due to low turnout
4. **Monitor Results**: Check if proposals execute successfully

### **Security Considerations**
1. **Verify Addresses**: Double-check all contract addresses
2. **Test on Small Amounts**: Use minimal values for testing
3. **Review Calldata**: Understand what functions you're calling
4. **Keep Keys Safe**: Protect your private keys

---

## 🚨 **Troubleshooting**

### **Common Errors**

**"Governor: proposer votes below proposal threshold"**
- **Solution**: Increase your voting power by staking tokens or completing jobs

**"Governor: vote not currently active"**
- **Solution**: Wait for voting delay period or check if proposal expired

**"GovernorUnexpectedProposalState"**
- **Solution**: Check proposal state and wait for correct timing

**"execution reverted"**
- **Solution**: Verify calldata is correct and target function exists

### **Getting Help**
1. Check contract addresses are correct
2. Verify you have sufficient gas
3. Ensure proposal timing is correct
4. Review function signatures match target contract

---

## 📈 **Example: Complete Oracle Creation Flow**

Here's a complete example of creating and executing a proposal:

```bash
# 1. Check voting power
cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 \
  "getVotes(address)" 0xYourAddress

# 2. Generate calldata
CALLDATA=$(cast calldata "addSingleOracle(string,address[],string,string,address[])" \
  "MyOracle" '[0xAddr1,0xAddr2,0xAddr3]' "My Oracle Desc" "QmHash" '[]')

# 3. Create proposal
PROPOSAL_TX=$(cast send 0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 \
  "propose(address[],uint256[],bytes[],string)" \
  '[0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE]' '[0]' "[$CALLDATA]" \
  "Create MyOracle for dispute resolution" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY)

# 4. Extract proposal ID from logs (manual step)
PROPOSAL_ID="YOUR_PROPOSAL_ID_DECIMAL"

# 5. Wait for active state, then vote
cast send 0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 \
  "castVote(uint256,uint8)" $PROPOSAL_ID 1 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# 6. Wait for voting period to end, then execute
DESC_HASH=$(cast keccak "Create MyOracle for dispute resolution")
cast send 0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 \
  "execute(address[],uint256[],bytes[],bytes32)" \
  '[0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE]' '[0]' "[$CALLDATA]" $DESC_HASH \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

---

## 🏆 **Governance Power Sources**

### **Earned Tokens (Automatic)**
- Complete jobs successfully → Earn governance tokens
- Tokens automatically count toward voting power
- No staking required

### **Staked Tokens (Manual)**
- Stake OpenWork tokens in Native DAO
- Higher commitment → Higher voting power
- Tokens locked during stake period

### **Combined Power**
- Your total voting power = Earned tokens + (Staked tokens × Duration multiplier)
- Higher participation = Greater governance influence

---

**Tutorial Created**: September 27, 2025  
**Status**: ✅ **COMPLETE** - Ready for community use  
**Next Steps**: Share with community, gather feedback, iterate based on usage

This tutorial provides everything needed to participate in OpenWork governance! 🚀