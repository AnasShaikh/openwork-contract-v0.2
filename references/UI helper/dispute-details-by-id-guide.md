# Fetch Dispute Details by ID - Quick Guide

**Last Updated**: November 27, 2025  
**Contract**: OpenworkGenesis `0x1f23683C748fA1AF99B7263dea121eCc5Fe7564C` (Arbitrum Sepolia)

---

## Quick Reference

**Function**: `getDispute(string memory disputeId)`  
**Returns**: Full Dispute struct with 11 parameters  
**Gas**: Free (view function)

---

## Basic Usage

### JavaScript/TypeScript

```javascript
import { ethers } from 'ethers';

const GENESIS_ADDRESS = '0x1f23683C748fA1AF99B7263dea121eCc5Fe7564C';
const provider = new ethers.JsonRpcProvider('https://sepolia-rollup.arbitrum.io/rpc');
const genesis = new ethers.Contract(GENESIS_ADDRESS, GENESIS_ABI, provider);

// Fetch dispute by ID
const dispute = await genesis.getDispute('40232-243-2');

console.log({
  id: dispute.jobId,
  disputedAmount: ethers.formatUnits(dispute.disputedAmount, 6) + ' USDC',
  fee: ethers.formatUnits(dispute.fees, 6) + ' USDC',
  raiser: dispute.disputeRaiserAddress,
  votesFor: dispute.votesFor.toString(),
  votesAgainst: dispute.votesAgainst.toString(),
  isActive: dispute.isVotingActive,
  winner: dispute.result ? 'Job Giver' : 'Applicant'
});
```

---

## Dispute Struct Parameters

| Parameter | Type | Description | Example Value |
|-----------|------|-------------|---------------|
| `jobId` | string | Unique dispute ID | "40232-243-2" |
| `disputedAmount` | uint256 | Amount being disputed (6 decimals) | 300000 (0.3 USDC) |
| `hash` | string | IPFS hash of evidence | "QmDisputeEvidence..." |
| `disputeRaiserAddress` | address | Who initiated dispute | "0xfD08..." |
| `votesFor` | uint256 | Votes supporting dispute | 689062500000000000000 |
| `votesAgainst` | uint256 | Votes against dispute | 0 |
| `result` | bool | Final outcome (true = raiser wins) | true |
| `isVotingActive` | bool | Voting in progress | true |
| `isFinalized` | bool | Dispute settled | false |
| `timeStamp` | uint256 | Creation timestamp | 1763700619 |
| `fees` | uint256 | Dispute processing fee (6 decimals) | 300000 (0.3 USDC) |

---

## TypeScript Interface

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
```

---

## Related Queries

### Check if User Voted

```javascript
const hasVoted = await genesis.hasUserVotedOnDispute(
  '40232-243-2',
  userAddress
);
```

### Get All Voters

```javascript
const voters = await genesis.getDisputeVoters('40232-243-2');

voters.forEach(v => {
  console.log('Voter:', v.voter);
  console.log('Claim Address:', v.claimAddress);
  console.log('Voting Power:', v.votingPower.toString());
  console.log('Voted For:', v.voteFor);
});
```

### Get Voter Count

```javascript
const voterCount = await genesis.getDisputeVoterCount('40232-243-2');
console.log(`Total voters: ${voterCount}`);
```

---

## Complete Example

```javascript
async function getDisputeFullDetails(disputeId) {
  // Get main dispute data
  const dispute = await genesis.getDispute(disputeId);
  
  // Get voter data
  const voters = await genesis.getDisputeVoters(disputeId);
  
  // Format for UI
  return {
    // Basic info
    id: dispute.jobId,
    evidence: dispute.hash,
    raiser: dispute.disputeRaiserAddress,
    
    // Amounts
    disputedAmount: ethers.formatUnits(dispute.disputedAmount, 6),
    fee: ethers.formatUnits(dispute.fees, 6),
    
    // Voting
    votesFor: dispute.votesFor.toString(),
    votesAgainst: dispute.votesAgainst.toString(),
    totalVoters: voters.length,
    voters: voters.map(v => ({
      address: v.voter,
      claimAddress: v.claimAddress,
      power: v.votingPower.toString(),
      votedFor: v.voteFor
    })),
    
    // Status
    isActive: dispute.isVotingActive,
    isFinalized: dispute.isFinalized,
    result: dispute.result ? 'Raiser Wins' : 'Opponent Wins',
    
    // Timing
    createdAt: new Date(Number(dispute.timeStamp) * 1000),
    timeRemaining: calculateTimeRemaining(dispute.timeStamp)
  };
}

function calculateTimeRemaining(timestamp) {
  const votingPeriod = 3 * 60; // 3 minutes in seconds
  const now = Math.floor(Date.now() / 1000);
  const elapsed = now - Number(timestamp);
  const remaining = votingPeriod - elapsed;
  
  if (remaining <= 0) return 'Voting Ended';
  return `${remaining} seconds left`;
}
```

---

## React Component Example

```tsx
import { useEffect, useState } from 'react';
import { ethers } from 'ethers';

function DisputeDetailView({ disputeId }: { disputeId: string }) {
  const [dispute, setDispute] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      const provider = new ethers.JsonRpcProvider(
        'https://sepolia-rollup.arbitrum.io/rpc'
      );
      const genesis = new ethers.Contract(GENESIS_ADDRESS, ABI, provider);
      
      const data = await genesis.getDispute(disputeId);
      const voters = await genesis.getDisputeVoters(disputeId);
      
      setDispute({
        ...data,
        voters,
        disputedUSDC: ethers.formatUnits(data.disputedAmount, 6),
        feeUSDC: ethers.formatUnits(data.fees, 6)
      });
      setLoading(false);
    }
    load();
  }, [disputeId]);

  if (loading) return <div>Loading...</div>;

  return (
    <div className="dispute-detail">
      <h2>Dispute {dispute.jobId}</h2>
      <p>Disputed: {dispute.disputedUSDC} USDC</p>
      <p>Fee: {dispute.feeUSDC} USDC</p>
      <p>Votes For: {dispute.votesFor.toString()}</p>
      <p>Votes Against: {dispute.votesAgainst.toString()}</p>
      <p>Status: {dispute.isVotingActive ? 'Voting' : 'Closed'}</p>
      
      <h3>Voters ({dispute.voters.length})</h3>
      {dispute.voters.map(v => (
        <div key={v.voter}>
          {v.voter}: {v.voteFor ? 'FOR' : 'AGAINST'}
        </div>
      ))}
    </div>
  );
}
```

---

## Cast Command (Testing)

```bash
# Get dispute details
source .env && cast call 0x1f23683C748fA1AF99B7263dea121eCc5Fe7564C \
  "getDispute(string)" \
  "40232-243-2" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

---

## Decode Helper

```javascript
// Decode raw response
function decodeDispute(rawData) {
  const iface = new ethers.Interface([
    'function getDispute(string) view returns (tuple(string,uint256,string,address,uint256,uint256,bool,bool,bool,uint256,uint256))'
  ]);
  
  const decoded = iface.decodeFunctionResult('getDispute', rawData);
  return decoded[0];
}
```

---

## Common Patterns

### Check Dispute Status
```javascript
if (dispute.isVotingActive && !dispute.isFinalized) {
  // Voting in progress - show vote button
} else if (dispute.isFinalized) {
  // Show result
  const winner = dispute.result ? dispute.disputeRaiserAddress : 'Opponent';
} else {
  // Voting ended but not settled yet
}
```

### Display Vote Progress
```javascript
const totalVotes = dispute.votesFor + dispute.votesAgainst;
const forPercentage = totalVotes > 0n 
  ? (Number(dispute.votesFor) / Number(totalVotes) * 100).toFixed(1)
  : 0;

console.log(`${forPercentage}% voting FOR`);
```

### Check User Can Vote
```javascript
const hasVoted = await genesis.hasUserVotedOnDispute(disputeId, userAddress);
const canVote = dispute.isVotingActive && !hasVoted;
```

---

## Error Handling

```javascript
async function getDisputeSafely(disputeId) {
  try {
    const dispute = await genesis.getDispute(disputeId);
    
    // Check if dispute exists
    if (!dispute.jobId || dispute.jobId === '') {
      return { error: 'Dispute not found' };
    }
    
    return { data: dispute };
  } catch (error) {
    return { error: error.message };
  }
}
```

---

## Performance Tips

1. **Cache Results**: Dispute data doesn't change except for votes
2. **Batch Requests**: Use `Promise.all()` for multiple disputes
3. **Subscribe to Events**: Listen for vote events instead of polling
4. **Use Helper First**: Get IDs from ReaderHelper, then fetch details

---

## Complete Data Flow

```javascript
// 1. Get all active dispute IDs
const helper = new ethers.Contract(HELPER_ADDRESS, HELPER_ABI, provider);
const disputeIds = await helper.getAllDisputeIds();

// 2. Fetch details for each
const disputes = await Promise.all(
  disputeIds.map(async (id) => {
    const dispute = await genesis.getDispute(id);
    const voters = await genesis.getDisputeVoters(id);
    return { ...dispute, voters };
  })
);

// 3. Display in UI
disputes.forEach(d => renderDisputeCard(d));
```

---

## Web3.js Example

```javascript
const Web3 = require('web3');
const web3 = new Web3('https://sepolia-rollup.arbitrum.io/rpc');

const genesis = new web3.eth.Contract(GENESIS_ABI, GENESIS_ADDRESS);

const dispute = await genesis.methods.getDispute('40232-243-2').call();
console.log(dispute);
```

---

## Contract Addresses Reference

| Contract | Address | Purpose |
|----------|---------|---------|
| **OpenworkGenesis** | `0x1f23683C748fA1AF99B7263dea121eCc5Fe7564C` | Dispute storage |
| **GenesisReaderHelper** | `0xCcf7Fa75C6b31f58bd43847fA6602258ee46A715` | Batch queries |
| **Native Athena** | `0x098E52Aff44AEAd944AFf86F4A5b90dbAF5B86bd` | Dispute management |

---

## Related Guides

- **Batch Fetching**: `genesis-reader-helper-frontend-guide.md`
- **Contract Addresses**: `references/deployments/openwork-contracts-current-addresses.md`

---

**Summary**: Use `getDispute(disputeId)` on Genesis to fetch all 11 parameters for a specific dispute. Combine with voter queries for complete data.
