# How to Update Contract Parameters - Step-by-Step Guide

**Last Updated**: November 29, 2025  
**Purpose**: Practical instructions for updating configuration values in deployed contracts

---

## 📋 **QUICK REFERENCE**

### **Governance Updates** (Require Proposal)
- **Main DAO parameters** → Create proposal on Main DAO (Base Sepolia)
- **Native DAO parameters** → Create proposal on Native DAO (Arbitrum Sepolia)

### **Owner Updates** (Direct Call)
- **Arbitrum contracts** → Cast send to Arbitrum
- **Base contracts** → Cast send to Base  
- **OP contracts** → Cast send to OP Sepolia

---

## 🏛️ **GOVERNANCE UPDATES**

### **Main DAO Parameters** (Base Sepolia)

#### Update Proposal Threshold

```bash
# Step 1: Encode the update function call
CALLDATA=$(cast calldata "updateProposalThreshold(uint256)" 200000000000000000000)

# Step 2: Create proposal
source .env && cast send 0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465 \
  "propose(address[],uint256[],bytes[],string)" \
  "[0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465]" \
  "[0]" \
  "[$CALLDATA]" \
  "Update proposal threshold to 200 OW" \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY

# Step 3: Wait for voting period (5 minutes default)

# Step 4: Vote on proposal (get proposal ID from step 2 output)
cast send 0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465 \
  "castVote(uint256,uint8,bytes)" \
  PROPOSAL_ID \
  1 \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY

# Step 5: Execute proposal (after voting period ends)
cast send 0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465 \
  "execute(address[],uint256[],bytes[],bytes32)" \
  "[0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465]" \
  "[0]" \
  "[$CALLDATA]" \
  DESCRIPTION_HASH \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

#### Update Voting Threshold
```bash
CALLDATA=$(cast calldata "updateVotingThreshold(uint256)" 75000000000000000000)

source .env && cast send 0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465 \
  "propose(address[],uint256[],bytes[],string)" \
  "[0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465]" \
  "[0]" \
  "[$CALLDATA]" \
  "Update voting threshold to 75 OW" \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

#### Update Unstake Delay
```bash
CALLDATA=$(cast calldata "updateUnstakeDelay(uint256)" 43200)  # 12 hours

source .env && cast send 0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465 \
  "propose(address[],uint256[],bytes[],string)" \
  "[0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465]" \
  "[0]" \
  "[$CALLDATA]" \
  "Reduce unstake delay to 12 hours" \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

---

### **Native DAO Parameters** (Arbitrum Sepolia)

#### Update Proposal Stake Threshold

```bash
# Step 1: Encode calldata
CALLDATA=$(cast calldata "updateProposalStakeThreshold(uint256)" 150000000000000000000)

# Step 2: Create proposal on Native DAO
source .env && cast send 0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 \
  "propose(address[],uint256[],bytes[],string)" \
  "[0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5]" \
  "[0]" \
  "[$CALLDATA]" \
  "Update proposal stake threshold to 150 OW" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY

# Step 3: Vote (after voting delay)
cast send 0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 \
  "_castVote(uint256,address,uint8,string,bytes)" \
  PROPOSAL_ID \
  $WALLET_ADDRESS \
  1 \
  "" \
  0x \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY

# Step 4: Execute (after voting period)
cast send 0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 \
  "execute(address[],uint256[],bytes[],bytes32)" \
  "[0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5]" \
  "[0]" \
  "[$CALLDATA]" \
  DESCRIPTION_HASH \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

#### Update Voting Reward Threshold
```bash
CALLDATA=$(cast calldata "updateVotingRewardThreshold(uint256)" 75000000000000000000)

source .env && cast send 0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 \
  "propose(address[],uint256[],bytes[],string)" \
  "[0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5]" \
  "[0]" \
  "[$CALLDATA]" \
  "Update voting reward threshold to 75 OW" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

---

## 🔧 **OWNER UPDATES** (Direct Calls)

### **Native Athena** (Arbitrum Sepolia)

#### Update Voting Period
```bash
source .env && cast send 0x098E52Aff44AEAd944AFf86F4A5b90dbAF5B86bd \
  "updateVotingPeriod(uint256)" \
  60 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

#### Update Min Oracle Members
```bash
source .env && cast send 0x098E52Aff44AEAd944AFf86F4A5b90dbAF5B86bd \
  "updateMinOracleMembers(uint256)" \
  5 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

#### Update Member Activity Threshold
```bash
source .env && cast send 0x098E52Aff44AEAd944AFf86F4A5b90dbAF5B86bd \
  "updateMemberActivityThreshold(uint256)" \
  120 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

---

### **NOWJC** (Arbitrum Sepolia)

#### Update Commission Percentage
```bash
# Set to 1.5% (150 basis points)
source .env && cast send 0x9E39B37275854449782F1a2a4524405cE79d6C1e \
  "setCommissionPercentage(uint256)" \
  150 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

#### Update Minimum Commission
```bash
# Set to 2 USDC (2,000,000 units - 6 decimals)
source .env && cast send 0x9E39B37275854449782F1a2a4524405cE79d6C1e \
  "setMinCommission(uint256)" \
  2000000 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

#### Update Treasury Address
```bash
source .env && cast send 0x9E39B37275854449782F1a2a4524405cE79d6C1e \
  "setTreasury(address)" \
  0xYOUR_TREASURY_ADDRESS \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

---

### **Native Rewards** (Arbitrum Sepolia)

#### Add New Reward Band
```bash
# Add band 21: $52.4288B-$104.8576B at 0.0057 OW/$
source .env && cast send 0x947cAd64a26Eae5F82aF68b7Dbf8b457a8f492De \
  "addRewardBand(uint256,uint256,uint256)" \
  52428800000000000 \
  104857600000000000 \
  5722045898437500 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

#### Update Existing Reward Band
```bash
# Update band 0 (first band)
source .env && cast send 0x947cAd64a26Eae5F82aF68b7Dbf8b457a8f492De \
  "updateRewardBand(uint256,uint256,uint256,uint256)" \
  0 \
  0 \
  100000000000 \
  350000000000000000000 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

#### Remove Last Reward Band
```bash
source .env && cast send 0x947cAd64a26Eae5F82aF68b7Dbf8b457a8f492De \
  "removeLastRewardBand()" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

---

### **Athena Client** (OP Sepolia)

#### Update Min Dispute Fee
```bash
# Set to 1 USDC (1,000,000 units - 6 decimals)
source .env && cast send 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 \
  "setMinDisputeFee(uint256)" \
  1000000 \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

#### Update CCTP Configuration
```bash
# Update CCTP sender
source .env && cast send 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 \
  "setCCTPSender(address)" \
  0xNEW_CCTP_SENDER \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY

# Update native Athena recipient
source .env && cast send 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 \
  "setNativeAthenaRecipient(address)" \
  0x098E52Aff44AEAd944AFf86F4A5b90dbAF5B86bd \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

---

### **Bridge Updates**

#### Main Chain Bridge (Base Sepolia)
```bash
# Update Native chain endpoint
source .env && cast send 0x70d30e5dAb5005b126C040f1D9b0bDDBc16679b0 \
  "updateNativeChainEid(uint32)" \
  40231 \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY

# Update DAO contract reference
source .env && cast send 0x70d30e5dAb5005b126C040f1D9b0bDDBc16679b0 \
  "setMainDaoContract(address)" \
  0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465 \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

#### Native Bridge (Arbitrum Sepolia)
```bash
# Add new local chain
source .env && cast send 0x3b2AC1d1281cA4a1188d9F09A5Af9a9E6a114D6c \
  "addLocalChain(uint32)" \
  40232 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY

# Remove local chain
source .env && cast send 0x3b2AC1d1281cA4a1188d9F09A5Af9a9E6a114D6c \
  "removeLocalChain(uint32)" \
  40232 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

---

## 📊 **VERIFICATION AFTER UPDATE**

### Check New Value Was Set
```bash
# Main DAO - check proposal threshold
cast call 0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465 \
  "proposalThresholdAmount()" \
  --rpc-url $BASE_SEPOLIA_RPC_URL

# Native Athena - check voting period
cast call 0x098E52Aff44AEAd944AFf86F4A5b90dbAF5B86bd \
  "votingPeriodMinutes()" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# NOWJC - check commission
cast call 0x9E39B37275854449782F1a2a4524405cE79d6C1e \
  "commissionPercentage()" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

---

## 🗺️ **UPDATE ROUTING BY CHAIN**

### **Arbitrum Sepolia Updates**

**Governance-Controlled** (via Native DAO):
- Native DAO thresholds (4 params)

**Owner-Controlled** (direct calls):
- Native Athena: voting config (4 params)
- NOWJC: commission settings (3 params)
- Native Rewards: reward bands (dynamic)
- Native Bridge: chain endpoints + refs
- Oracle Manager: authorized callers
- Profile Manager: contract refs
- Genesis contracts: authorized contracts

### **Base Sepolia Updates**

**Governance-Controlled** (via Main DAO):
- Main DAO thresholds (3 params)

**Owner-Controlled** (direct calls):
- Main Chain Bridge: chain endpoints + refs
- Main Rewards: authorized chains + contract refs

### **OP Sepolia Updates**

**Owner-Controlled Only** (direct calls):
- Local Bridge: chain endpoints
- LOWJC: token/CCTP config
- Athena Client: fee settings + CCTP config

---

## 🎯 **COMMON UPDATE SCENARIOS**

### Scenario 1: Increase Voting Period (for more participation)
**When**: Users need more time to vote  
**Chain**: Arbitrum  
**Who**: Owner (direct update)

```bash
source .env && cast send 0x098E52Aff44AEAd944AFf86F4A5b90dbAF5B86bd \
  "updateVotingPeriod(uint256)" \
  180 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

### Scenario 2: Adjust Commission Rate
**When**: Platform revenue adjustment needed  
**Chain**: Arbitrum  
**Who**: Owner (direct update)

```bash
# Change to 0.5% (50 basis points)
source .env && cast send 0x9E39B37275854449782F1a2a4524405cE79d6C1e \
  "setCommissionPercentage(uint256)" \
  50 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

### Scenario 3: Lower Governance Barrier
**When**: Want more users to participate in governance  
**Chain**: Base  
**Who**: Governance (requires proposal)

```bash
# Lower voting threshold to 25 OW
CALLDATA=$(cast calldata "updateVotingThreshold(uint256)" 25000000000000000000)

source .env && cast send 0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465 \
  "propose(address[],uint256[],bytes[],string)" \
  "[0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465]" \
  "[0]" \
  "[$CALLDATA]" \
  "Lower voting threshold to 25 OW for more participation" \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

---

## ⚠️ **IMPORTANT NOTES**

### **Before Any Update:**
1. ✅ Test new value on testnet first
2. ✅ Calculate impact on existing users/actions
3. ✅ Document reason for change
4. ✅ Have rollback plan ready

### **Governance Updates:**
- Require proposal creation + voting
- 1 minute voting delay (testnet)
- 5 minute voting period (testnet)
- Need quorum + majority to pass
- Affected users should be notified

### **Owner Updates:**
- Immediate effect
- Use carefully
- Document in changelog
- Consider announcing to users

### **Chain-Specific Considerations:**
- **Base Sepolia**: Main DAO proposals, slower/cheaper txs
- **Arbitrum Sepolia**: Native DAO proposals + most owner updates, faster txs
- **OP Sepolia**: Local contract updates only, no DAO

---

## 🔄 **ROLLBACK PROCEDURES**

### If Governance Update Goes Wrong:
```bash
# Create new proposal to revert to old value
CALLDATA=$(cast calldata "updateProposalThreshold(uint256)" 100000000000000000000)

source .env && cast send 0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465 \
  "propose(address[],uint256[],bytes[],string)" \
  "[0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465]" \
  "[0]" \
  "[$CALLDATA]" \
  "ROLLBACK: Revert proposal threshold to 100 OW" \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

### If Owner Update Goes Wrong:
```bash
# Just call the update function again with old value
source .env && cast send 0x098E52Aff44AEAd944AFf86F4A5b90dbAF5B86bd \
  "updateVotingPeriod(uint256)" \
  60 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

---

## 🛠️ **HELPER COMMANDS**

### Get Current Values Before Updating

```bash
# Main DAO thresholds
cast call 0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465 "proposalThresholdAmount()" --rpc-url $BASE_SEPOLIA_RPC_URL
cast call 0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465 "votingThresholdAmount()" --rpc-url $BASE_SEPOLIA_RPC_URL
cast call 0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465 "unstakeDelay()" --rpc-url $BASE_SEPOLIA_RPC_URL

# Native Athena config
cast call 0x098E52Aff44AEAd944AFf86F4A5b90dbAF5B86bd "votingPeriodMinutes()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
cast call 0x098E52Aff44AEAd944AFf86F4A5b90dbAF5B86bd "minOracleMembers()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# NOWJC commission
cast call 0x9E39B37275854449782F1a2a4524405cE79d6C1e "commissionPercentage()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
cast call 0x9E39B37275854449782F1a2a4524405cE79d6C1e "minCommission()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### Calculate Description Hash (for proposal execution)
```bash
# Get hash of proposal description
cast keccak "Update proposal threshold to 200 OW"
```

### Check Proposal State
```bash
# Main DAO
cast call 0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465 \
  "state(uint256)" \
  PROPOSAL_ID \
  --rpc-url $BASE_SEPOLIA_RPC_URL

# States: 0=Pending, 1=Active, 2=Canceled, 3=Defeated, 4=Succeeded, 5=Queued, 6=Expired, 7=Executed
```

---

## 📝 **UPDATE CHECKLIST**

### Before Governance Update:
- [ ] Determine new value
- [ ] Check current value
- [ ] Test on testnet
- [ ] Calculate user impact
- [ ] Encode calldata correctly
- [ ] Create proposal on correct DAO
- [ ] Wait for voting delay
- [ ] Vote on proposal
- [ ] Wait for voting period
- [ ] Execute proposal
- [ ] Verify new value set
- [ ] Monitor for issues

### Before Owner Update:
- [ ] Determine new value
- [ ] Check current value
- [ ] Test on testnet if possible
- [ ] Prepare rollback value
- [ ] Send transaction to correct chain
- [ ] Verify new value set
- [ ] Monitor for issues

---

## 🚨 **EMERGENCY PROCEDURES**

### If Bad Value Set (Owner Update):
```bash
# Immediate rollback - just call update function again
source .env && cast send CONTRACT_ADDRESS \
  "updateFunction(uint256)" \
  OLD_SAFE_VALUE \
  --rpc-url CORRECT_RPC_URL \
  --private-key $WALL2_KEY
```

### If Bad Value Set (Governance Update):
```bash
# Fast-track emergency proposal
CALLDATA=$(cast calldata "updateFunction(uint256)" OLD_SAFE_VALUE)

source .env && cast send DAO_ADDRESS \
  "propose(address[],uint256[],bytes[],string)" \
  "[CONTRACT_ADDRESS]" \
  "[0]" \
  "[$CALLDATA]" \
  "EMERGENCY: Rollback parameter to safe value" \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --rpc-url CORRECT_RPC_URL \
  --private-key $WALL2_KEY

# Rally voters to pass quickly
```

---

## 📚 **RELATED DOCUMENTATION**

- **Parameter List**: `references/context/updatable-configuration-parameters.md`
- **Upgrade Guide**: `references/logs/imp/deploy-upgrade-tutorial.md`
- **Cross-Chain Upgrades**: `references/logs/demos/cross-chain-upgrade-tutorial.md`
- **Contract Addresses**: `references/deployments/openwork-contracts-current-addresses.md`

---

## 💡 **PRO TIPS**

1. **Always check current value first** - avoid unnecessary updates
2. **Use testnet contracts** to test the exact command before mainnet
3. **For governance updates** - coordinate with community to ensure votes
4. **Keep update history** - document what changed and why
5. **Monitor events** - each update emits an event for tracking
6. **Have contingency** - know how to rollback before updating

---

**Total Update Functions Documented**: 15+ common updates  
**Chains Covered**: Base, Arbitrum, OP Sepolia  
**Access Types**: Governance (proposals) + Owner (direct)
