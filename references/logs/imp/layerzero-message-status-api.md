# LayerZero Message Status API

**Docs**: https://docs.layerzero.network/v2/tools/layerzeroscan/api

---

## API Endpoints

### Testnet
```
https://scan-testnet.layerzero-api.com/v1/messages/tx/{txHash}
```

### Mainnet
```
https://scan.layerzero-api.com/v1/messages/tx/{txHash}
```

---

## Quick Check Command

```bash
# Testnet
curl -s "https://scan-testnet.layerzero-api.com/v1/messages/tx/0xYOUR_TX_HASH" | jq .

# Status only
curl -s "https://scan-testnet.layerzero-api.com/v1/messages/tx/0xYOUR_TX_HASH" | jq '.data[0].status'
```

---

## Message Statuses

| Status | Meaning |
|--------|---------|
| `INFLIGHT` | Message sent, waiting for DVN verification/delivery |
| `DELIVERED` | Message successfully received on destination chain |
| `FAILED` | Message delivery failed |
| `BLOCKED` | Message blocked (config issue) |

---

## Response Structure

```json
{
  "data": [{
    "pathway": {
      "srcEid": 40232,           // Source endpoint ID (OP Sepolia)
      "dstEid": 40231,           // Destination endpoint ID (Arbitrum Sepolia)
      "sender": {
        "address": "0x...",
        "chain": "optimism-sepolia"
      },
      "receiver": {
        "address": "0x...",
        "chain": "arbitrum-sepolia"
      }
    },
    "source": {
      "status": "SUCCEEDED",
      "tx": {
        "txHash": "0x...",
        "blockNumber": "...",
        "blockTimestamp": 1234567890
      }
    },
    "destination": {
      "status": "SUCCEEDED",
      "tx": {
        "txHash": "0x...",
        "blockNumber": "...",
        "blockTimestamp": 1234567890
      }
    },
    "status": {
      "name": "DELIVERED",
      "message": "Executor transaction confirmed"
    },
    "guid": "0x...",
    "created": "2025-12-26T11:41:49.000Z",
    "updated": "2025-12-26T11:42:11.000Z"
  }]
}
```

---

## Endpoint IDs (Testnets)

| Chain | Endpoint ID |
|-------|-------------|
| Arbitrum Sepolia | 40231 |
| OP Sepolia | 40232 |
| Base Sepolia | 40245 |
| Ethereum Sepolia | 40161 |

---

## Example Usage

### Check if message delivered
```bash
TX="0x3df4c85b128c6dccb6e0df1e5bd624e94f1f49e38a4b874670f1591ed3170f0f"
curl -s "https://scan-testnet.layerzero-api.com/v1/messages/tx/$TX" | jq '.data[0].status.name'
# Output: "DELIVERED"
```

### Get destination tx hash
```bash
curl -s "https://scan-testnet.layerzero-api.com/v1/messages/tx/$TX" | jq '.data[0].destination.tx.txHash'
```

### Check source and destination status
```bash
curl -s "https://scan-testnet.layerzero-api.com/v1/messages/tx/$TX" | jq '{
  source: .data[0].source.status,
  destination: .data[0].destination.status,
  overall: .data[0].status.name
}'
```

---

## Other Endpoints

### List messages by status
```
GET /v1/messages/status/{status}
```

### Swagger UI (Full API Docs)
- Testnet: https://scan-testnet.layerzero-api.com/swagger
- Mainnet: https://scan.layerzero-api.com/swagger

---

**Created**: December 26, 2025
