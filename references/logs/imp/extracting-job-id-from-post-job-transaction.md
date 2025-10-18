# Extracting Job ID from PostJob Transaction

**Purpose**: Guide for extracting the automatically generated Job ID from a `postJob` transaction using Web3/Ethers in browser environments.

**Last Updated**: October 9, 2025  
**Contract**: LOWJC on OP Sepolia - `0x896a3Bc6ED01f549Fe20bD1F25067951913b793C`

---

## 🎯 **Overview**

When you call the `postJob` function on the LOWJC contract, the system automatically generates a numeric Job ID in the format `[sequence]-[number]` (e.g., `40232-124`). This Job ID is embedded in the LayerZero message data within the transaction logs and needs to be extracted programmatically.

---

## 📋 **Transaction Flow**

1. **Call `postJob`** → Contract generates Job ID
2. **LayerZero message sent** → Job ID embedded in message data
3. **Extract from logs** → Decode hex data to get readable Job ID

---

## 🔍 **Step-by-Step Extraction Process**

### **Step 1: Execute PostJob Transaction**

```javascript
// Example postJob call using ethers.js
const tx = await lowjcContract.postJob(
  "test-job-" + Date.now(),
  ["Milestone 1: Initial deliverable", "Milestone 2: Final completion"],
  [500000, 500000],
  "0x0003010011010000000000000000000000000007a120",
  { value: ethers.utils.parseEther("0.001") }
);

const receipt = await tx.wait();
console.log("Transaction Hash:", receipt.transactionHash);
```

### **Step 2: Find LayerZero Message Log**

Look for the log with LayerZero event signature:
- **Event Signature**: `0x1ab700d4ced0c005b164c0f789fd09fcbb0156d4c2041b8a3bfbcd961cd1567f`
- **Contract Address**: LayerZero Endpoint (varies by chain)

```javascript
// Find LayerZero message log
const layerZeroLog = receipt.logs.find(log => 
  log.topics[0] === "0x1ab700d4ced0c005b164c0f789fd09fcbb0156d4c2041b8a3bfbcd961cd1567f"
);

if (!layerZeroLog) {
  throw new Error("LayerZero message log not found");
}
```

### **Step 3: Extract Job ID from Log Data**

The Job ID is embedded in the `data` field of the LayerZero log. You need to:

1. **Parse the log data** (it's ABI-encoded)
2. **Find the Job ID string** in the decoded data
3. **Convert hex to ASCII** to get readable Job ID

```javascript
// Method 1: Manual hex parsing (more reliable)
function extractJobIdFromLayerZeroData(logData) {
  // The Job ID appears as a hex-encoded string in the LayerZero message
  // Look for the pattern that matches job ID format (numbers-numbers)
  
  // Convert full data to string and search for job ID pattern
  const dataStr = logData.slice(2); // Remove 0x prefix
  
  // Look for hex sequences that decode to job ID format
  // Job IDs are typically in format: 40232-124
  const chunks = dataStr.match(/.{1,64}/g); // Split into 32-byte chunks
  
  for (const chunk of chunks) {
    try {
      const decoded = ethers.utils.toUtf8String("0x" + chunk.replace(/00+$/, ""));
      if (decoded.match(/^\d+-\d+$/)) {
        return decoded;
      }
    } catch (e) {
      // Skip invalid UTF8 sequences
      continue;
    }
  }
  
  // Alternative: Look for specific hex pattern
  // Job ID "40232-124" = hex "34303233322d313234"
  const jobIdMatch = dataStr.match(/34303233322d\d+/);
  if (jobIdMatch) {
    return ethers.utils.toUtf8String("0x" + jobIdMatch[0]);
  }
  
  throw new Error("Job ID not found in LayerZero data");
}

// Method 2: ABI decoding (if you have the LayerZero message ABI)
function extractJobIdFromABI(logData) {
  // If you have the LayerZero endpoint ABI:
  const abiCoder = new ethers.utils.AbiCoder();
  
  // LayerZero message structure (approximate)
  const decoded = abiCoder.decode(
    ["bytes", "bytes", "address"], 
    logData
  );
  
  // The job ID should be in the message payload
  const messagePayload = decoded[0];
  // Parse the payload to extract job ID...
  
  return parseJobIdFromPayload(messagePayload);
}
```

### **Step 4: Complete Extraction Function**

```javascript
async function extractJobIdFromTransaction(txHash) {
  // Get transaction receipt
  const receipt = await provider.getTransactionReceipt(txHash);
  
  if (!receipt || !receipt.logs) {
    throw new Error("Transaction receipt not found or has no logs");
  }
  
  // Find LayerZero message log
  const layerZeroLog = receipt.logs.find(log => 
    log.topics[0] === "0x1ab700d4ced0c005b164c0f789fd09fcbb0156d4c2041b8a3bfbcd961cd1567f"
  );
  
  if (!layerZeroLog) {
    throw new Error("LayerZero message log not found in transaction");
  }
  
  // Extract Job ID from the log data
  try {
    const jobId = extractJobIdFromLayerZeroData(layerZeroLog.data);
    console.log("Extracted Job ID:", jobId);
    return jobId;
  } catch (error) {
    console.error("Failed to extract Job ID:", error);
    throw error;
  }
}

// Usage
const jobId = await extractJobIdFromTransaction("0x5e405e0e788c37ba891bdcee0c1b652dfaa3561145d79a9949aaf826caf772ee");
console.log("Job ID:", jobId); // Output: "40232-124"
```

---

## 🛠 **Alternative Method: Contract Events**

If LayerZero parsing is complex, you can also listen to the contract's JobPosted event:

```javascript
// Listen for JobPosted event
const filter = lowjcContract.filters.JobPosted();
const events = await lowjcContract.queryFilter(filter, receipt.blockNumber, receipt.blockNumber);

const jobPostedEvent = events.find(event => event.transactionHash === txHash);
if (jobPostedEvent) {
  // The job ID might be in the event args
  console.log("Job Posted Event:", jobPostedEvent.args);
  
  // Note: You may still need to extract from LayerZero data
  // as the contract event might only contain the job hash
}
```

---

## 📝 **Real Example**

From our test transaction `0x5e405e0e788c37ba891bdcee0c1b652dfaa3561145d79a9949aaf826caf772ee`:

```javascript
// LayerZero log data contained:
const logData = "0x000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000003c0000000000000000000000000b31d2cb502e25b30c651842c7c3293c51fe6d16f000000000000000000000000000000000000000000000000000000000000033101000000000000002000009d280000000000000000000000006601cf4156160cf43fd024bac30851d3ee0f866800009d270000000000000000000000003b2ac1d1281ca4a1188d9f09a5af9a9e6a114d6c3669bfc156bb3233b81ec95bb9b3a9ec02e3b4c1fce58beb6c79ee203c50ebc900000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000fd08836eee6242092a9c869237a8d122275b024a0000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000002600000000000000000000000000000000000000000000000000000000000000007706f73744a6f6200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000934303233322d31323400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000013746573742d6a6f622d313736303035303139370000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000204d696c6573746f6e6520313a20496e697469616c2064656c6976657261626c65000000000000000000000000000000000000000000000000000000000000001d4d696c6573746f6e6520323a2046696e616c20636f6d706c6574696f6e0000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000007a120000000000000000000000000000000000000000000000000000000000007a12000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000160003010011010000000000000000000000000007a12000000000000000000000";

// The hex sequence "34303233322d313234" decodes to "40232-124"
const jobIdHex = "34303233322d313234";
const jobId = ethers.utils.toUtf8String("0x" + jobIdHex);
console.log("Job ID:", jobId); // "40232-124"
```

---

## ⚠️ **Important Notes**

1. **LayerZero Integration**: The Job ID is sent via LayerZero messaging, so it appears in LayerZero logs, not direct contract events.

2. **Hex Encoding**: The Job ID is hex-encoded within the LayerZero message data.

3. **Log Filtering**: Always filter for the correct LayerZero event signature to find the right log.

4. **Error Handling**: Include proper error handling for missing logs or invalid data.

5. **Chain Specific**: LayerZero endpoint addresses may vary between chains.

---

## 🔧 **Debugging Tips**

1. **Check all logs**: If LayerZero log is not found, check all logs in the transaction.

2. **Verify contract address**: Ensure you're calling the correct LOWJC contract.

3. **Check transaction status**: Verify the transaction was successful before extracting data.

4. **Use block explorer**: Compare with block explorer log data for verification.

---

## 📚 **Contract Addresses**

- **LOWJC (OP Sepolia)**: `0x896a3Bc6ED01f549Fe20bD1F25067951913b793C`
- **LayerZero Endpoint (OP Sepolia)**: `0x6EDCE65403992e310A62460808c4b910D972f10f`

---

This documentation provides everything needed to extract Job IDs from `postJob` transactions in browser environments using Web3.js or Ethers.js! 🚀