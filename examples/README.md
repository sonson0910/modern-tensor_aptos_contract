# ModernTensor Contract Examples

This directory contains examples of how to interact with the ModernTensor smart contract using different programming languages.

## 📋 Available Examples

### 1. TypeScript Client (`typescript_client.ts`)

A comprehensive TypeScript client using the Aptos SDK.

**Setup:**
```bash
npm install
npm run dev
```

**Features:**
- Full contract interaction
- Account management
- Balance checking
- Network statistics
- Fee information
- Treasury statistics
- Subnet creation
- Miner/Validator registration
- Permit purchasing

### 2. Python Client (`python_client.py`)

A Python client using the Aptos SDK for Python.

**Setup:**
```bash
pip install aptos-sdk
python3 python_client.py
```

**Features:**
- Async/await support
- Complete contract interaction
- Error handling
- Balance management
- Network monitoring

### 3. Shell Scripts (`shell_examples.sh`)

Direct Aptos CLI commands for quick testing.

**Usage:**
```bash
chmod +x shell_examples.sh
./shell_examples.sh
```

## 🚀 Quick Start

### Prerequisites

1. **Aptos CLI** installed
2. **Testnet account** with APT
3. **Contract deployed** (use `../deploy.py`)

### TypeScript Setup

```bash
cd examples/
npm install
npm run dev
```

### Python Setup

```bash
cd examples/
pip install aptos-sdk
python3 python_client.py
```

## 📚 Contract Functions

### View Functions (No Gas Cost)

- `get_enhanced_network_stats()` - Network statistics
- `get_registration_fee_info()` - Fee information
- `get_treasury_stats()` - Treasury statistics
- `get_subnet_info(subnet_id)` - Subnet details
- `check_validator_permit(address, subnet_id)` - Permit status

### Entry Functions (Require Gas)

- `create_subnet(...)` - Create new subnet
- `register_miner(...)` - Register as miner
- `register_validator(...)` - Register as validator
- `purchase_validator_permit(subnet_id)` - Buy permit
- `batch_update_miners(...)` - Update multiple miners
- `batch_update_validators(...)` - Update multiple validators
- `recycle_node(...)` - Recycle inactive nodes

## 💰 Testing Mode Fees

| Operation | Fee (APT) | Bond (APT) |
|-----------|-----------|------------|
| Miner Registration | 0.01 | - |
| Validator Registration | 0.05 | 0.1-10 |
| Subnet Creation | 0.1 | - |
| Validator Permit | 0.02 | - |

## 🔍 Common Use Cases

### 1. Network Monitoring

```typescript
// Get network statistics
const stats = await client.getNetworkStats();
console.log(`Total Miners: ${stats.totalMiners}`);
console.log(`Total Validators: ${stats.totalValidators}`);
```

### 2. Create Subnet

```typescript
await client.createSubnet(
    1,                    // subnet_id
    "My Subnet",         // name
    "Description",       // description
    10,                  // max_validators
    100,                 // max_miners
    1000000,            // min_stake_validator (0.01 APT)
    1000000,            // min_stake_miner (0.01 APT)
    false               // permits_required
);
```

### 3. Register Miner

```typescript
await client.registerMiner(
    "miner_001",        // uid
    1,                  // subnet_id
    10000000,          // stake (0.1 APT)
    "wallet_hash",     // wallet_hash
    "http://api.com"   // api_endpoint
);
```

### 4. Register Validator

```typescript
await client.registerValidator(
    "validator_001",    // uid
    1,                  // subnet_id
    50000000,          // stake (0.5 APT)
    10000000,          // bond (0.1 APT)
    "wallet_hash",     // wallet_hash
    "http://api.com"   // api_endpoint
);
```

### 5. Batch Operations

```typescript
// Update multiple miners at once (75% gas savings)
const updates = [
    { address: "0x123...", trust_score: 85, performance: 90 },
    { address: "0x456...", trust_score: 78, performance: 85 },
    // ... up to 100 miners
];

await client.batchUpdateMiners(1, updates);
```

## 🛠️ Development Tips

### 1. Account Management

```typescript
// Create client with existing private key
const client = new ModernTensorClient("0x123...private_key");

// Create client with new account
const client = new ModernTensorClient();
console.log(`Address: ${client.getAddress()}`);
console.log(`Private Key: ${client.getPrivateKey()}`);
```

### 2. Error Handling

```typescript
try {
    await client.registerMiner(...);
} catch (error) {
    if (error.message.includes("insufficient funds")) {
        console.log("Fund your account with testnet APT");
    } else if (error.message.includes("already registered")) {
        console.log("Wait for cooldown period");
    }
}
```

### 3. Balance Management

```typescript
const balance = await client.getBalance();
const minRequired = 100000000; // 1 APT

if (balance < minRequired) {
    console.log("Fund account:");
    console.log(`aptos account fund-with-faucet --account ${client.getAddress()}`);
}
```

## 📊 Monitoring & Analytics

### Network Health Dashboard

```typescript
setInterval(async () => {
    const stats = await client.getNetworkStats();
    const treasury = await client.getTreasuryStats();
    
    console.log(`Active Miners: ${stats.activeMiners}`);
    console.log(`Active Validators: ${stats.activeValidators}`);
    console.log(`Total Burned: ${treasury.totalBurned}`);
}, 60000); // Update every minute
```

### Fee Tracking

```typescript
const feeInfo = await client.getFeeInfo();
console.log(`Current Fees:`);
console.log(`- Miner: ${feeInfo.minerFee / 100000000} APT`);
console.log(`- Validator: ${feeInfo.validatorFee / 100000000} APT`);
```

## 🐛 Troubleshooting

### Common Issues

1. **"Module not found"**
   - Ensure contract is deployed
   - Check contract address

2. **"Insufficient funds"**
   - Fund account with testnet APT
   - Check minimum balance requirements

3. **"Already registered"**
   - Wait for cooldown period (5 minutes in testing)
   - Use different UID

4. **"Invalid subnet"**
   - Create subnet first
   - Check subnet ID exists

### Debug Commands

```bash
# Check account balance
aptos account list --profile default

# Check contract deployment
aptos move view --profile default \
  --function-id 0x...::moderntensor::get_enhanced_network_stats

# Check transaction history
aptos account list --profile default --query transactions
```

## 🤝 Contributing

1. Add new examples to this directory
2. Update this README
3. Test with both testnet and local development
4. Add error handling and documentation

## 📄 License

MIT License - see LICENSE file for details

---

**Happy Coding!** 🚀 