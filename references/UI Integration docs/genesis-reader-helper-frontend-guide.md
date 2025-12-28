# GenesisReaderHelper - Frontend Integration Guide

**Last Updated**: November 26, 2025  
**Contract Address**: `0xCcf7Fa75C6b31f58bd43847fA6602258ee46A715` (Arbitrum Sepolia)  
**Genesis Proxy**: `0x1f23683C748fA1AF99B7263dea121eCc5Fe7564C` (Arbitrum Sepolia)

---

## Overview

GenesisReaderHelper provides efficient batch data retrieval for disputes, skill verifications, and Ask Athena applications **without requiring any job IDs or dispute IDs upfront**.

**Key Features:**
- ✅ Get all disputes in 1 RPC call (vs 100+ calls)
- ✅ Filter for active disputes only
- ✅ Support for multi-disputes per job (e.g., `40232-243-1`, `40232-243-2`)
- ✅ Pagination support for large datasets
- ✅ No manual ID tracking required

---

## Contract Addresses

| Contract | Address | Chain | Purpose |
|----------|---------|-------|---------|
| **GenesisReaderHelper** | `0xCcf7Fa75C6b31f58bd43847fA6602258ee46A715` | Arbitrum Sepolia | Batch data queries |
| **OpenworkGenesis** | `0x1f23683C748fA1AF99B7263dea121eCc5Fe7564C` | Arbitrum Sepolia | Data storage |

---

## Quick Start

### 1. Initialize Contract

```javascript
import { ethers } from 'ethers';

const READER_ADDRESS = '0xCcf7Fa75C6b31f58bd43847fA6602258ee46A715';
const GENESIS_ADDRESS = '0x1f23683C748fA1AF99B7263dea121eCc5Fe7564C';
const RPC_URL = 'https://sepolia-rollup.arbitrum.io/rpc';

const provider = new ethers.JsonRpcProvider(RPC_URL);
const readerContract = new ethers.Contract(READER_ADDRESS, READER_ABI, provider);
const genesisContract = new ethers.Contract(GENESIS_ADDRESS, GENESIS_ABI, provider);
```

### 2. Get All Disputes (Simple)

```javascript
// Get all dispute IDs (single call)
const disputeIds = await readerContract.getAllDisputeIds();
console.log('Found disputes:', disputeIds);
// Example output: ['40232-243-1', '40232-243-2']

// Get full data for each dispute
const disputes = await Promise.all(
  disputeIds.map(id => genesisContract.getDispute(id))
);
```

### 3. Get Only Active Disputes (Recommended)

```javascript
// Get active disputes with full data in one call
const activeDisputes = await readerContract.getActiveDisputes();

// activeDisputes is an array of Dispute structs:
activeDisputes.forEach(dispute => {
  console.log('Dispute ID:', dispute.jobId);
  console.log('Votes For:', dispute.votesFor);
  console.log('Votes Against:', dispute.votesAgainst);
  console.log('Fee:', ethers.formatUnits(dispute.fees, 6), 'USDC');
  console.log('Disputed Amount:', ethers.formatUnits(dispute.disputedAmount, 6), 'USDC');
  console.log('Is Active:', dispute.isVotingActive);
});
```

---

## Function Reference

### Dispute Functions

#### `getAllDisputeIds()`
Returns all dispute IDs across all jobs.

```javascript
const disputeIds = await readerContract.getAllDisputeIds();
// Returns: string[] - e.g., ['40232-243-1', '40232-243-2', '40232-244-1']
```

**Use Case:** Loading dispute dashboard, showing dispute history

---

#### `getActiveDisputes()`
Returns full data for all active disputes (voting in progress).

```javascript
const activeDisputes = await readerContract.getActiveDisputes();
// Returns: Dispute[] with full struct data
```

**Dispute Struct:**
```typescript
interface Dispute {
  jobId: string;           // e.g., "40232-243-2"
  disputedAmount: bigint;  // Amount being disputed (6 decimals)
  hash: string;            // IPFS hash of evidence
  disputeRaiserAddress: string; // Who raised the dispute
  votesFor: bigint;        // Votes supporting dispute
  votesAgainst: bigint;    // Votes against dispute
  result: boolean;         // Final result (if finalized)
  isVotingActive: boolean; // True if voting ongoing
  isFinalized: boolean;    // True if dispute settled
  timeStamp: bigint;       // Block timestamp
  fees: bigint;            // Dispute fee amount (6 decimals)
}
```

**Use Case:** "Active Disputes" tab, voting dashboard

---

### Skill Verification Functions

#### `getAllSkillApplicationIds()`
Returns all skill verification application IDs.

```javascript
const skillAppIds = await readerContract.getAllSkillApplicationIds();
// Returns: bigint[] - e.g., [0n, 1n, 2n, 3n]
```

#### `getActiveSkillApplications()`
Returns full data for active skill verification applications.

```javascript
const activeSkillApps = await readerContract.getActiveSkillApplications();
// Returns: SkillVerificationApplication[]

activeSkillApps.forEach(app => {
  console.log('Application ID:', app.id);
  console.log('Applicant:', app.applicant);
  console.log('Target Oracle:', app.targetOracleName);
  console.log('Fee:', ethers.formatUnits(app.feeAmount, 6), 'USDC');
  console.log('Votes For:', app.votesFor);
  console.log('Votes Against:', app.votesAgainst);
});
```

**Use Case:** Skill verification voting dashboard

---

### Ask Athena Functions

#### `getAllAskAthenaIds()`
Returns all Ask Athena application IDs.

```javascript
const athenaIds = await readerContract.getAllAskAthenaIds();
// Returns: bigint[]
```

#### `getActiveAskAthenaApplications()`
Returns full data for active Ask Athena applications.

```javascript
const activeAthenaApps = await readerContract.getActiveAskAthenaApplications();
// Returns: AskAthenaApplication[]
```

**Use Case:** Oracle consultation voting dashboard

---

## Complete Example: Dispute Dashboard

```javascript
async function loadDisputeDashboard() {
  try {
    // 1. Get all active disputes (single call, full data)
    const activeDisputes = await readerContract.getActiveDisputes();
    
    // 2. Format for UI
    const formattedDisputes = activeDisputes.map(dispute => ({
      id: dispute.jobId,
      disputedAmount: ethers.formatUnits(dispute.disputedAmount, 6) + ' USDC',
      fee: ethers.formatUnits(dispute.fees, 6) + ' USDC',
      raiser: dispute.disputeRaiserAddress,
      votesFor: dispute.votesFor.toString(),
      votesAgainst: dispute.votesAgainst.toString(),
      timestamp: new Date(Number(dispute.timeStamp) * 1000).toLocaleString(),
      evidence: dispute.hash, // IPFS hash
      canVote: dispute.isVotingActive && !dispute.isFinalized
    }));
    
    // 3. Render in UI
    return formattedDisputes;
    
  } catch (error) {
    console.error('Failed to load disputes:', error);
    return [];
  }
}
```

---

## Performance Comparison

### Old Method (Without Helper)
```javascript
// ❌ Slow: 100+ RPC calls
const allJobIds = await genesis.getAllJobIds(); // 1 call
const disputes = [];

for (const jobId of allJobIds) {
  for (let counter = 1; counter <= 10; counter++) {
    const disputeId = `${jobId}-${counter}`;
    try {
      const dispute = await genesis.getDispute(disputeId); // 100+ calls!
      if (dispute.jobId) disputes.push(dispute);
    } catch {}
  }
}
// Total: 100+ calls, 10-20 seconds
```

### New Method (With Helper)
```javascript
// ✅ Fast: 1 RPC call
const disputes = await readerContract.getActiveDisputes(); // 1 call!
// Total: 1 call, <1 second
```

**Performance Gain:** 100x faster, 100x fewer RPC calls

---

## React Hook Example

```typescript
import { useEffect, useState } from 'react';
import { ethers } from 'ethers';

interface Dispute {
  jobId: string;
  disputedAmount: string;
  votesFor: string;
  votesAgainst: string;
  isVotingActive: boolean;
  raiser: string;
}

export function useActiveDisputes() {
  const [disputes, setDisputes] = useState<Dispute[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function fetchDisputes() {
      try {
        const provider = new ethers.JsonRpcProvider(
          'https://sepolia-rollup.arbitrum.io/rpc'
        );
        
        const readerContract = new ethers.Contract(
          '0xCcf7Fa75C6b31f58bd43847fA6602258ee46A715',
          READER_ABI,
          provider
        );

        // Single call gets everything
        const activeDisputes = await readerContract.getActiveDisputes();
        
        const formatted = activeDisputes.map(d => ({
          jobId: d.jobId,
          disputedAmount: ethers.formatUnits(d.disputedAmount, 6) + ' USDC',
          votesFor: d.votesFor.toString(),
          votesAgainst: d.votesAgainst.toString(),
          isVotingActive: d.isVotingActive,
          raiser: d.disputeRaiserAddress
        }));
        
        setDisputes(formatted);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    }

    fetchDisputes();
  }, []);

  return { disputes, loading, error };
}
```

**Usage in Component:**
```tsx
function DisputeDashboard() {
  const { disputes, loading } = useActiveDisputes();
  
  if (loading) return <div>Loading disputes...</div>;
  
  return (
    <div>
      {disputes.map(dispute => (
        <DisputeCard key={dispute.jobId} dispute={dispute} />
      ))}
    </div>
  );
}
```

---

## ABI Files

### GenesisReaderHelper ABI (Key Functions)

```json
[
  {
    "type": "function",
    "name": "getAllDisputeIds",
    "inputs": [],
    "outputs": [{"type": "string[]"}],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getActiveDisputes",
    "inputs": [],
    "outputs": [{
      "type": "tuple[]",
      "components": [
        {"name": "jobId", "type": "string"},
        {"name": "disputedAmount", "type": "uint256"},
        {"name": "hash", "type": "string"},
        {"name": "disputeRaiserAddress", "type": "address"},
        {"name": "votesFor", "type": "uint256"},
        {"name": "votesAgainst", "type": "uint256"},
        {"name": "result", "type": "bool"},
        {"name": "isVotingActive", "type": "bool"},
        {"name": "isFinalized", "type": "bool"},
        {"name": "timeStamp", "type": "uint256"},
        {"name": "fees", "type": "uint256"}
      ]
    }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getActiveSkillApplications",
    "inputs": [],
    "outputs": [{"type": "tuple[]"}],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getActiveAskAthenaApplications",
    "inputs": [],
    "outputs": [{"type": "tuple[]"}],
    "stateMutability": "view"
  }
]
```

---

## Common Use Cases

### 1. Dashboard: Show All Active Disputes

```javascript
const activeDisputes = await readerContract.getActiveDisputes();
// Render table/cards with dispute data
```

### 2. Notification: New Disputes

```javascript
// Poll every 30 seconds
setInterval(async () => {
  const disputes = await readerContract.getAllDisputeIds();
  if (disputes.length > previousCount) {
    showNotification('New dispute raised!');
  }
}, 30000);
```

### 3. User-Specific: Check if User Voted

```javascript
const activeDisputes = await readerContract.getActiveDisputes();

for (const dispute of activeDisputes) {
  const hasVoted = await genesisContract.hasUserVotedOnDispute(
    dispute.jobId,
    userAddress
  );
  
  if (!hasVoted) {
    // Show "Vote Now" button
  }
}
```

### 4. Oracle Dashboard: Skill Verifications

```javascript
const activeSkillApps = await readerContract.getActiveSkillApplications();

// Filter by oracle
const myOracleApps = activeSkillApps.filter(
  app => app.targetOracleName === 'General'
);

// Display applications awaiting votes
```

---

## Error Handling

```javascript
async function fetchDisputesSafely() {
  try {
    const disputes = await readerContract.getActiveDisputes();
    return disputes;
  } catch (error) {
    if (error.code === 'CALL_EXCEPTION') {
      console.error('Contract call failed - check RPC connection');
    } else if (error.code === 'NETWORK_ERROR') {
      console.error('Network error - retry connection');
    }
    return [];
  }
}
```

---

## TypeScript Types

```typescript
interface Dispute {
  jobId: string;
  disputedAmount: bigint;
  hash: string;
  disputeRaiserAddress: string;
  votesFor: bigint;
  votesAgainst: bigint;
  result: boolean;
  isVotingActive: boolean;
  isFinalized: boolean;
  timeStamp: bigint;
  fees: bigint;
}

interface SkillVerificationApplication {
  id: bigint;
  applicant: string;
  applicationHash: string;
  feeAmount: bigint;
  targetOracleName: string;
  votesFor: bigint;
  votesAgainst: bigint;
  isVotingActive: boolean;
  timeStamp: bigint;
  result: boolean;
  isFinalized: boolean;
}

interface AskAthenaApplication {
  id: bigint;
  applicant: string;
  description: string;
  hash: string;
  targetOracle: string;
  fees: string;
  votesFor: bigint;
  votesAgainst: bigint;
  isVotingActive: boolean;
  timeStamp: bigint;
  result: boolean;
  isFinalized: boolean;
}
```

---

## Testing Commands

### Test in Browser Console

```javascript
// Connect to contract
const provider = new ethers.BrowserProvider(window.ethereum);
const reader = new ethers.Contract(
  '0xCcf7Fa75C6b31f58bd43847fA6602258ee46A715',
  ['function getAllDisputeIds() view returns (string[])',
   'function getActiveDisputes() view returns (tuple(string,uint256,string,address,uint256,uint256,bool,bool,bool,uint256,uint256)[])'],
  provider
);

// Get all disputes
const disputes = await reader.getAllDisputeIds();
console.log(disputes);

// Get active disputes
const active = await reader.getActiveDisputes();
console.log(active);
```

### Test with curl

```bash
# Get all dispute IDs
curl -X POST https://sepolia-rollup.arbitrum.io/rpc \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "eth_call",
    "params": [{
      "to": "0xCcf7Fa75C6b31f58bd43847fA6602258ee46A715",
      "data": "0x8c1d2e38"
    }, "latest"],
    "id": 1
  }'
```

---

## Advanced: Pagination

For large datasets, use batch functions:

```javascript
// Get disputes in pages of 50
async function getDisputesPaginated(page = 0, pageSize = 50) {
  const allIds = await readerContract.getAllDisputeIds();
  const start = page * pageSize;
  const pageIds = allIds.slice(start, start + pageSize);
  
  const disputes = await Promise.all(
    pageIds.map(id => genesisContract.getDispute(id))
  );
  
  return {
    disputes,
    totalPages: Math.ceil(allIds.length / pageSize),
    currentPage: page
  };
}

// Usage
const { disputes, totalPages } = await getDisputesPaginated(0, 20);
```

---

## Real-World Example: Dispute Voting UI

```javascript
async function renderDisputeVotingUI(userAddress) {
  // 1. Get all active disputes
  const activeDisputes = await readerContract.getActiveDisputes();
  
  // 2. Check which ones user hasn't voted on
  const votableDisputes = [];
  
  for (const dispute of activeDisputes) {
    const hasVoted = await genesisContract.hasUserVotedOnDispute(
      dispute.jobId,
      userAddress
    );
    
    if (!hasVoted) {
      votableDisputes.push({
        id: dispute.jobId,
        amount: ethers.formatUnits(dispute.disputedAmount, 6),
        fee: ethers.formatUnits(dispute.fees, 6),
        raiser: dispute.disputeRaiserAddress,
        votesFor: dispute.votesFor.toString(),
        votesAgainst: dispute.votesAgainst.toString(),
        timeLeft: calculateTimeLeft(dispute.timeStamp)
      });
    }
  }
  
  return votableDisputes;
}

function calculateTimeLeft(timestamp) {
  const votingPeriod = 60 * 60; // 60 minutes in seconds
  const now = Math.floor(Date.now() / 1000);
  const elapsed = now - Number(timestamp);
  const remaining = votingPeriod - elapsed;
  
  if (remaining <= 0) return 'Expired';
  
  const minutes = Math.floor(remaining / 60);
  return `${minutes} minutes left`;
}
```

---

## Key Benefits for Frontend

1. **Zero Configuration** - No need to track dispute IDs manually
2. **Single Call** - `getActiveDisputes()` returns everything needed
3. **Auto-Discovery** - Finds all disputes across all jobs automatically
4. **Multi-Dispute Support** - Handles multiple disputes per job
5. **Real-Time** - Always returns current blockchain state
6. **Gas-Free** - All view functions, no transaction fees

---

## Migration from Old Code

### Before (Manual Tracking)
```javascript
// ❌ Had to track dispute IDs manually
const knownDisputeIds = ['40232-243-1', '40232-243-2'];
const disputes = await Promise.all(
  knownDisputeIds.map(id => genesis.getDispute(id))
);
```

### After (Automatic Discovery)
```javascript
// ✅ Automatically discovers all disputes
const disputes = await readerContract.getActiveDisputes();
```

---

## Troubleshooting

### Q: `getActiveDisputes()` returns empty array
**A:** No active disputes exist. Try `getAllDisputeIds()` to see all disputes including finalized ones.

### Q: Function reverts with "out of bounds"
**A:** You're using an old reader address. Use the latest: `0xCcf7Fa75C6b31f58bd43847fA6602258ee46A715`

### Q: Dispute data seems outdated
**A:** These are view functions - data is always live from blockchain. Clear cache or refresh.

### Q: How to get dispute details from ID?
**A:** Use Genesis contract directly:
```javascript
const dispute = await genesisContract.getDispute('40232-243-2');
```

---

## Contract Updates

| Version | Address | Date | Changes |
|---------|---------|------|---------|
| **v2** | `0xCcf7Fa75C6b31f58bd43847fA6602258ee46A715` | Nov 26, 2025 | Multi-dispute support |
| v1 | `0x24D53dCd6d53fc35108CA295D7170E8D0d093D08` | Nov 23, 2025 | Initial version |

**Always use the latest version** for best performance and features.

---

## Support

For issues or questions:
- Check transaction on [Arbiscan](https://sepolia.arbiscan.io/address/0xCcf7Fa75C6b31f58bd43847fA6602258ee46A715)
- Verify RPC endpoint is responsive
- Ensure contract addresses are correct

**Contract is immutable** - no owner, no upgrades needed. Just works!
