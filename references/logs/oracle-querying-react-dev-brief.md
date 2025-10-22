# Oracle Querying Guide for React Frontend

**Date**: October 20, 2025  
**Purpose**: How to fetch and display all available oracles in the UI

## Contract Addresses

| Contract | Address | Chain | Purpose |
|----------|---------|-------|---------|
| **Oracle Manager** (Proxy) | `0x70F6fa515120efeA3e404234C318b7745D23ADD4` | Arbitrum Sepolia | Oracle creation events |
| **Genesis Contract** | `0xB4f27990af3F186976307953506A4d5759cf36EA` | Arbitrum Sepolia | Oracle data storage |

## RPC URL
```
https://arbitrum-sepolia.infura.io/v3/c74477fe73794a5b897b6037f564c7d0
```

## Method 1: Query Events (Recommended)

### Step 1: Get All Oracle Names
Query `OracleCreated` events from Oracle Manager:

```javascript
// Using ethers.js v6
import { ethers } from 'ethers';

const provider = new ethers.JsonRpcProvider('https://arbitrum-sepolia.infura.io/v3/c74477fe73794a5b897b6037f564c7d0');

// Oracle Manager ABI (only need the event)
const oracleManagerABI = [
  "event OracleCreated(string indexed oracleName, uint256 memberCount)"
];

const oracleManagerContract = new ethers.Contract(
  '0x70F6fa515120efeA3e404234C318b7745D23ADD4',
  oracleManagerABI,
  provider
);

// Query all OracleCreated events
async function getAllOracleNames() {
  try {
    const filter = oracleManagerContract.filters.OracleCreated();
    const events = await oracleManagerContract.queryFilter(filter, 0, 'latest');
    
    const oracleNames = events.map(event => event.args.oracleName);
    return [...new Set(oracleNames)]; // Remove duplicates
  } catch (error) {
    console.error('Error fetching oracle names:', error);
    return [];
  }
}
```

### Step 2: Get Individual Oracle Details
For each oracle name, fetch full details from Genesis:

```javascript
// Genesis Contract ABI (only need getOracle function)
const genesisABI = [
  "function getOracle(string memory oracleName) external view returns (tuple(string name, address[] members, string shortDescription, string hashOfDetails, address[] skillVerifiedAddresses))"
];

const genesisContract = new ethers.Contract(
  '0xB4f27990af3F186976307953506A4d5759cf36EA',
  genesisABI,
  provider
);

async function getOracleDetails(oracleName) {
  try {
    const oracle = await genesisContract.getOracle(oracleName);
    return {
      name: oracle.name,
      members: oracle.members,
      shortDescription: oracle.shortDescription,
      hashOfDetails: oracle.hashOfDetails,
      skillVerifiedAddresses: oracle.skillVerifiedAddresses,
      memberCount: oracle.members.length,
      verifiedCount: oracle.skillVerifiedAddresses.length
    };
  } catch (error) {
    console.error(`Error fetching oracle ${oracleName}:`, error);
    return null;
  }
}
```

### Step 3: Complete Implementation
```javascript
async function getAllOracles() {
  try {
    // Get all oracle names from events
    const oracleNames = await getAllOracleNames();
    
    // Fetch details for each oracle
    const oracles = await Promise.all(
      oracleNames.map(name => getOracleDetails(name))
    );
    
    // Filter out any failed requests
    return oracles.filter(oracle => oracle !== null);
  } catch (error) {
    console.error('Error fetching all oracles:', error);
    return [];
  }
}

// Usage in React component
function OracleList() {
  const [oracles, setOracles] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadOracles() {
      setLoading(true);
      const allOracles = await getAllOracles();
      setOracles(allOracles);
      setLoading(false);
    }
    
    loadOracles();
  }, []);

  if (loading) return <div>Loading oracles...</div>;

  return (
    <div>
      <h2>Available Oracles ({oracles.length})</h2>
      {oracles.map(oracle => (
        <div key={oracle.name} className="oracle-card">
          <h3>{oracle.name}</h3>
          <p>{oracle.shortDescription}</p>
          <p>Members: {oracle.memberCount}</p>
          <p>Verified Users: {oracle.verifiedCount}</p>
        </div>
      ))}
    </div>
  );
}
```

## Method 2: Direct Cast Query (For Testing)

Use this cast command to verify oracle names exist:

```bash
# Get oracle names from events (replace with your RPC)
cast logs --from-block 0 --to-block latest \
  --address 0x70F6fa515120efeA3e404234C318b7745D23ADD4 \
  --signature "OracleCreated(string,uint256)" \
  --rpc-url https://arbitrum-sepolia.infura.io/v3/c74477fe73794a5b897b6037f564c7d0

# Get specific oracle details
cast call 0xB4f27990af3F186976307953506A4d5759cf36EA \
  "getOracle(string)" "General" \
  --rpc-url https://arbitrum-sepolia.infura.io/v3/c74477fe73794a5b897b6037f564c7d0
```

## Known Oracles

Based on our current deployment, these oracles exist:
- **"General"** - General skill verification oracle

## Error Handling

```javascript
// Handle cases where oracle might be empty/removed
function isValidOracle(oracle) {
  return oracle && 
         oracle.name && 
         oracle.name.length > 0 && 
         oracle.members.length > 0;
}

// Filter valid oracles only
const validOracles = oracles.filter(isValidOracle);
```

## Performance Notes

1. **Cache Results**: Oracle data doesn't change frequently, cache for 5-10 minutes
2. **Batch Requests**: Use Promise.all() to fetch oracle details in parallel
3. **Error Boundaries**: Wrap oracle components in error boundaries
4. **Loading States**: Always show loading indicators for better UX

## Skill Verification Check

To check if a user is verified for a specific skill:

```javascript
function isUserVerifiedForSkill(userAddress, oracle) {
  return oracle.skillVerifiedAddresses
    .map(addr => addr.toLowerCase())
    .includes(userAddress.toLowerCase());
}
```

## Testing

Test with these known addresses:
- **WALL2**: `0xfD08836eeE6242092a9c869237a8d122275b024A` (verified for General)
- **WALL3**: `0x1D06bb4395AE7BFe9264117726D069C251dC27f5` (verified for General)