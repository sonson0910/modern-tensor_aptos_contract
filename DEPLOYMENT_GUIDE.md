# ModernTensor Contract - Deployment & Usage Guide

## 🚀 Quick Start

### Prerequisites
1. **Aptos CLI** installed:
   ```bash
   curl -fsSL https://aptos.dev/scripts/install_cli.py | python3
   ```

2. **Aptos Wallet** configured:
   ```bash
   aptos init --profile default --network testnet
   ```

3. **Testnet APT** for gas fees:
   ```bash
   aptos account fund-with-faucet --profile default
   ```

### 📦 Deploy Contract

1. **Clone and setup:**
   ```bash
   cd full_moderntensor_contract
   chmod +x deploy.py demo.py
   ```

2. **Deploy automatically:**
   ```bash
   python3 deploy.py
   ```

3. **Run demo:**
   ```bash
   python3 demo.py
   ```

## 📋 Contract Features

### 🏗️ Core Architecture
- **Batch Operations**: Process up to 100 miners/validators per transaction
- **O(1) Performance**: SmartTable-based storage for fast queries
- **Economic Constraints**: Bittensor-like fee system with burn mechanism
- **Testing Mode**: Ultra-low fees for development

### 💰 Testing Mode Economics

| Operation | Fee | Bond | Cooldown |
|-----------|-----|------|----------|
| Miner Registration | 0.01 APT | - | 5 minutes |
| Validator Registration | 0.05 APT | 0.1-10 APT | 5 minutes |
| Subnet Creation | 0.1 APT | - | - |
| Validator Permit | 0.02 APT | - | 5 minutes |

### ⚡ Performance Benefits
- **75% Gas Reduction**: Batch 256 miners in 3 transactions vs 256
- **Scalable**: Handle 1000+ nodes efficiently
- **Fast Queries**: O(1) lookups with pagination support

## 🛠️ Manual Commands

### View Functions (No Gas Cost)

```bash
# Network statistics
aptos move view --profile default \
  --function-id 0x9ba2d796ed64ea00a4f7690be844174820e0729de9f37fcaae429bc15ac37c04::moderntensor::get_enhanced_network_stats

# Fee information
aptos move view --profile default \
  --function-id 0x9ba2d796ed64ea00a4f7690be844174820e0729de9f37fcaae429bc15ac37c04::moderntensor::get_registration_fee_info

# Treasury stats
aptos move view --profile default \
  --function-id 0x9ba2d796ed64ea00a4f7690be844174820e0729de9f37fcaae429bc15ac37c04::moderntensor::get_treasury_stats

# Subnet information
aptos move view --profile default \
  --function-id 0x9ba2d796ed64ea00a4f7690be844174820e0729de9f37fcaae429bc15ac37c04::moderntensor::get_subnet_info \
  --args u64:1
```

### Write Functions (Require Gas)

#### 1. Create Subnet
```bash
aptos move run --profile default \
  --function-id 0x9ba2d796ed64ea00a4f7690be844174820e0729de9f37fcaae429bc15ac37c04::moderntensor::create_subnet \
  --args u64:1 \
  --args string:"My Subnet" \
  --args string:"Description of my subnet" \
  --args u64:10 \
  --args u64:100 \
  --args u64:1000000 \
  --args u64:1000000 \
  --args bool:false
```

#### 2. Register Miner
```bash
aptos move run --profile default \
  --function-id 0x9ba2d796ed64ea00a4f7690be844174820e0729de9f37fcaae429bc15ac37c04::moderntensor::register_miner \
  --args hex:"6d696e65725f31" \
  --args u64:1 \
  --args u64:10000000 \
  --args hex:"77616c6c65745f68617368" \
  --args hex:"687474703a2f2f6d696e65722e6578616d706c652e636f6d"
```

#### 3. Register Validator
```bash
aptos move run --profile default \
  --function-id 0x9ba2d796ed64ea00a4f7690be844174820e0729de9f37fcaae429bc15ac37c04::moderntensor::register_validator \
  --args hex:"76616c696461746f725f31" \
  --args u64:1 \
  --args u64:50000000 \
  --args u64:10000000 \
  --args hex:"77616c6c65745f68617368" \
  --args hex:"687474703a2f2f76616c696461746f722e6578616d706c652e636f6d"
```

#### 4. Purchase Validator Permit
```bash
aptos move run --profile default \
  --function-id 0x9ba2d796ed64ea00a4f7690be844174820e0729de9f37fcaae429bc15ac37c04::moderntensor::purchase_validator_permit \
  --args u64:1
```

## 🔧 Advanced Usage

### Batch Operations

For updating multiple miners efficiently:

```bash
# Note: Batch operations require creating structs
# Use TypeScript/Python clients for easier batch operations
```

### Production Mode

To switch to production mode with higher fees:

1. Edit `sources/moderntensor_test_config.move`
2. Change constants to production values
3. Recompile and redeploy

## 🏗️ Client Development

### TypeScript Example

```typescript
import { AptosClient, HexString } from "aptos";

const client = new AptosClient("https://fullnode.testnet.aptoslabs.com");
const contractAddress = "0x9ba2d796ed64ea00a4f7690be844174820e0729de9f37fcaae429bc15ac37c04";

// Get network stats
async function getNetworkStats() {
  const stats = await client.view({
    function: `${contractAddress}::moderntensor::get_enhanced_network_stats`,
    arguments: [],
    type_arguments: []
  });
  return stats;
}

// Register miner
async function registerMiner(account, uid, subnetId, stake) {
  const payload = {
    type: "entry_function_payload",
    function: `${contractAddress}::moderntensor::register_miner`,
    arguments: [
      HexString.fromUint8Array(new TextEncoder().encode(uid)).hex(),
      subnetId,
      stake,
      HexString.fromUint8Array(new TextEncoder().encode("wallet_hash")).hex(),
      HexString.fromUint8Array(new TextEncoder().encode("http://api.example.com")).hex()
    ],
    type_arguments: []
  };
  
  return await client.generateSignSubmitTransaction(account, payload);
}
```

### Python Example

```python
import requests
import json

class ModernTensorClient:
    def __init__(self, node_url, contract_address):
        self.node_url = node_url
        self.contract_address = contract_address
    
    def get_network_stats(self):
        response = requests.post(f"{self.node_url}/v1/view", json={
            "function": f"{self.contract_address}::moderntensor::get_enhanced_network_stats",
            "arguments": [],
            "type_arguments": []
        })
        return response.json()
    
    def register_miner(self, uid, subnet_id, stake, wallet_hash, api_endpoint):
        # Implementation for miner registration
        pass
```

## 🔍 Testing

### Unit Tests
```bash
aptos move test
```

### Integration Tests
```bash
python3 demo.py  # Full integration test
```

## 🐛 Troubleshooting

### Common Issues

1. **"Insufficient funds" error**
   ```bash
   aptos account fund-with-faucet --profile default
   ```

2. **"Already registered" error**
   - Check cooldown period (5 minutes in testing mode)
   - Use different UID/address

3. **"Invalid subnet" error**
   - Create subnet first
   - Check subnet ID exists

4. **Compilation errors**
   - Check Aptos CLI version: `aptos --version`
   - Ensure correct Move.toml configuration

### Debug Commands

```bash
# Check account balance
aptos account list --profile default

# Check transaction history
aptos account list --profile default --query transactions

# Verify contract deployment
aptos move view --profile default \
  --function-id 0x9ba2d796ed64ea00a4f7690be844174820e0729de9f37fcaae429bc15ac37c04::moderntensor::get_enhanced_network_stats
```

## 📚 Documentation

- **Contract Source**: `sources/moderntensor.move`
- **Test Configuration**: `sources/moderntensor_test_config.move`
- **Demo Script**: `demo.py`
- **Deployment Script**: `deploy.py`

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Add tests for new features
4. Ensure all tests pass
5. Submit pull request

## 📄 License

MIT License - see LICENSE file for details

## 🆘 Support

- **Issues**: Create GitHub issue
- **Questions**: Discussion forum
- **Documentation**: Full docs in `docs/` folder

---

**Happy Building with ModernTensor!** 🚀 