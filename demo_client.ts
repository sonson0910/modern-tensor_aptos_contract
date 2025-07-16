/**
 * ModernTensor Optimized Contract - Demo Client
 * 
 * This demonstrates how to interact with the optimized ModernTensor contract
 * for managing 256+ miners efficiently using batch operations.
 */

import { AptosClient, AptosAccount, FaucetClient, HexString } from "aptos";

// Configuration
const NODE_URL = "https://fullnode.testnet.aptoslabs.com/v1";
const FAUCET_URL = "https://faucet.testnet.aptoslabs.com";
const CONTRACT_ADDRESS = "0x9ba2d796ed64ea00a4f7690be844174820e0729de9f37fcaae429bc15ac37c04";

// Initialize clients
const client = new AptosClient(NODE_URL);
const faucetClient = new FaucetClient(NODE_URL, FAUCET_URL);

// Demo data structures
interface MinerUpdate {
    address: string;
    trust_score: number;
    performance: number;
    rewards: number;
    weight: number;
}

interface BatchMinerUpdate {
    miner_addr: string;
    trust_score: string;
    performance: string;
    rewards: string;
    weight: string;
    status: string | null;
}

/**
 * Demo: Managing 256 miners efficiently
 */
class ModernTensorClient {
    private adminAccount: AptosAccount;
    private contractAddress: string;

    constructor(adminPrivateKey: string, contractAddress: string) {
        this.adminAccount = AptosAccount.fromAptosAccountObject({
            privateKeyHex: adminPrivateKey
        });
        this.contractAddress = contractAddress;
    }

    /**
     * Initialize the contract
     */
    async initialize(): Promise<string> {
        const payload = {
            type: "entry_function_payload",
            function: `${this.contractAddress}::moderntensor::initialize`,
            type_arguments: [],
            arguments: []
        };

        const txnRequest = await client.generateTransaction(
            this.adminAccount.address(),
            payload
        );

        const signedTxn = await client.signTransaction(this.adminAccount, txnRequest);
        const transactionRes = await client.submitTransaction(signedTxn);
        await client.waitForTransaction(transactionRes.hash);

        console.log("✅ Contract initialized successfully!");
        return transactionRes.hash;
    }

    /**
     * Create a subnet for organizing miners
     */
    async createSubnet(
        subnetId: number,
        name: string,
        description: string,
        maxValidators: number = 50,
        maxMiners: number = 1000,
        minStake: number = 1000000 // 0.01 APT
    ): Promise<string> {
        const payload = {
            type: "entry_function_payload",
            function: `${this.contractAddress}::moderntensor::create_subnet`,
            type_arguments: [],
            arguments: [
                subnetId.toString(),
                name,
                description,
                maxValidators.toString(),
                maxMiners.toString(),
                minStake.toString(),
                minStake.toString()
            ]
        };

        const txnRequest = await client.generateTransaction(
            this.adminAccount.address(),
            payload
        );

        const signedTxn = await client.signTransaction(this.adminAccount, txnRequest);
        const transactionRes = await client.submitTransaction(signedTxn);
        await client.waitForTransaction(transactionRes.hash);

        console.log(`✅ Subnet ${subnetId} created: ${name}`);
        return transactionRes.hash;
    }

    /**
     * Register multiple miners (for demo purposes)
     */
    async registerDemoMiners(count: number = 10): Promise<string[]> {
        const transactions: string[] = [];

        console.log(`📝 Registering ${count} demo miners...`);

        for (let i = 0; i < count; i++) {
            const minerAccount = new AptosAccount();

            // Fund the miner account
            await faucetClient.fundAccount(minerAccount.address(), 100000000); // 1 APT

            const payload = {
                type: "entry_function_payload",
                function: `${this.contractAddress}::moderntensor::register_miner`,
                type_arguments: [],
                arguments: [
                    Array.from(new TextEncoder().encode(`miner_${i}_uid`)),
                    "1", // subnet_uid
                    "10000000", // stake_amount (0.1 APT)
                    Array.from(new TextEncoder().encode(`miner_${i}_wallet_hash`)),
                    Array.from(new TextEncoder().encode(`http://miner${i}.example.com`))
                ]
            };

            const txnRequest = await client.generateTransaction(
                minerAccount.address(),
                payload
            );

            const signedTxn = await client.signTransaction(minerAccount, txnRequest);
            const transactionRes = await client.submitTransaction(signedTxn);
            await client.waitForTransaction(transactionRes.hash);

            transactions.push(transactionRes.hash);
            console.log(`  ✅ Miner ${i} registered: ${minerAccount.address()}`);
        }

        return transactions;
    }

    /**
     * Generate random performance updates for miners
     */
    generateRandomUpdates(minerAddresses: string[]): MinerUpdate[] {
        return minerAddresses.map(address => ({
            address,
            trust_score: Math.random() * 100, // 0-100%
            performance: Math.random() * 100, // 0-100%
            rewards: Math.floor(Math.random() * 10000000), // 0-0.1 APT
            weight: 0.5 + Math.random() * 2.0 // 0.5-2.5
        }));
    }

    /**
     * Convert updates to contract format
     */
    private convertToBatchUpdates(updates: MinerUpdate[]): BatchMinerUpdate[] {
        return updates.map(update => ({
            miner_addr: update.address,
            trust_score: Math.floor(update.trust_score * 1e6).toString(), // Scale by 1e8
            performance: Math.floor(update.performance * 1e6).toString(),
            rewards: update.rewards.toString(),
            weight: Math.floor(update.weight * 1e8).toString(),
            status: null
        }));
    }

    /**
     * Execute batch update for miners - KEY FEATURE!
     */
    async batchUpdateMiners(updates: MinerUpdate[]): Promise<string[]> {
        const BATCH_SIZE = 100; // Maximum batch size
        const batches: MinerUpdate[][] = [];

        // Split updates into batches
        for (let i = 0; i < updates.length; i += BATCH_SIZE) {
            batches.push(updates.slice(i, i + BATCH_SIZE));
        }

        console.log(`🔄 Executing ${batches.length} batch updates for ${updates.length} miners...`);

        const transactions: string[] = [];

        for (let batchIndex = 0; batchIndex < batches.length; batchIndex++) {
            const batch = batches[batchIndex];
            const batchUpdates = this.convertToBatchUpdates(batch);

            const payload = {
                type: "entry_function_payload",
                function: `${this.contractAddress}::moderntensor::batch_update_miners`,
                type_arguments: [],
                arguments: [batchUpdates]
            };

            const txnRequest = await client.generateTransaction(
                this.adminAccount.address(),
                payload
            );

            const signedTxn = await client.signTransaction(this.adminAccount, txnRequest);
            const transactionRes = await client.submitTransaction(signedTxn);
            await client.waitForTransaction(transactionRes.hash);

            transactions.push(transactionRes.hash);
            console.log(`  ✅ Batch ${batchIndex + 1}/${batches.length} completed: ${batch.length} miners updated`);
        }

        return transactions;
    }

    /**
     * Get network statistics
     */
    async getNetworkStats(): Promise<any> {
        const payload = {
            function: `${this.contractAddress}::moderntensor::get_enhanced_network_stats`,
            type_arguments: [],
            arguments: []
        };

        const result = await client.view(payload);
        return {
            total_validators: result[0],
            total_miners: result[1],
            total_subnets: result[2],
            total_stake: result[3],
            active_validators: result[4],
            active_miners: result[5]
        };
    }

    /**
     * Get paginated miners
     */
    async getMiners(start: number = 0, limit: number = 50): Promise<any[]> {
        const payload = {
            function: `${this.contractAddress}::moderntensor::get_miners_paginated`,
            type_arguments: [],
            arguments: [start.toString(), limit.toString()]
        };

        return await client.view(payload) as any[];
    }

    /**
     * Get network health using client helper
     */
    async getNetworkHealth(): Promise<any> {
        const payload = {
            function: `${this.contractAddress}::moderntensor_client::get_network_status`,
            type_arguments: [],
            arguments: []
        };

        return await client.view(payload);
    }

    /**
     * Estimate gas cost for batch operations
     */
    async estimateGasCost(batchSize: number, operationType: number = 0): Promise<number> {
        const payload = {
            function: `${this.contractAddress}::moderntensor_client::estimate_batch_gas_cost`,
            type_arguments: [],
            arguments: [batchSize.toString(), operationType.toString()]
        };

        const result = await client.view(payload);
        return parseInt(result[0] as string);
    }
}

/**
 * Demo: Managing 256 miners efficiently
 */
async function demo256MinersManagement() {
    console.log("🚀 ModernTensor Optimized Contract Demo");
    console.log("📊 Managing 256 miners efficiently with batch operations\n");

    // Initialize client (use your admin private key)
    const adminPrivateKey = "0x..."; // Replace with actual admin private key
    const mtClient = new ModernTensorClient(adminPrivateKey, CONTRACT_ADDRESS);

    try {
        // 1. Initialize contract
        console.log("1️⃣ Initializing contract...");
        await mtClient.initialize();

        // 2. Create subnet
        console.log("\n2️⃣ Creating subnet...");
        await mtClient.createSubnet(
            1,
            "AI Training Subnet",
            "Decentralized AI model training network",
            50,  // max validators
            1000, // max miners
            1000000 // min stake (0.01 APT)
        );

        // 3. Register demo miners (for testing, use smaller number)
        console.log("\n3️⃣ Registering demo miners...");
        const minerTxns = await mtClient.registerDemoMiners(20); // Start with 20 for demo

        // 4. Get initial network stats
        console.log("\n4️⃣ Initial network statistics:");
        let stats = await mtClient.getNetworkStats();
        console.log(`  📊 Total Miners: ${stats.total_miners}`);
        console.log(`  📊 Total Stake: ${stats.total_stake}`);
        console.log(`  📊 Active Miners: ${stats.active_miners}`);

        // 5. Get miner addresses (simplified for demo)
        const miners = await mtClient.getMiners(0, 50);
        const minerAddresses = miners.map(miner => miner.miner_address);

        console.log(`\n5️⃣ Retrieved ${minerAddresses.length} miner addresses`);

        // 6. Generate random performance updates
        console.log("\n6️⃣ Generating performance updates...");
        const updates = mtClient.generateRandomUpdates(minerAddresses);

        // 7. Estimate gas cost
        const estimatedGas = await mtClient.estimateGasCost(updates.length, 0);
        console.log(`💰 Estimated gas cost: ${estimatedGas} units`);

        // 8. Execute batch updates
        console.log("\n8️⃣ Executing batch updates...");
        const batchTxns = await mtClient.batchUpdateMiners(updates);

        // 9. Get final network stats
        console.log("\n9️⃣ Final network statistics:");
        stats = await mtClient.getNetworkStats();
        console.log(`  📊 Total Miners: ${stats.total_miners}`);
        console.log(`  📊 Total Stake: ${stats.total_stake}`);
        console.log(`  📊 Active Miners: ${stats.active_miners}`);

        // 10. Get network health
        console.log("\n🔟 Network health check:");
        const health = await mtClient.getNetworkHealth();
        console.log(`  ❤️  Network Health: ${health.network_health}/3`);
        console.log(`  🏃 Active Ratio: ${health.active_validators + health.active_miners}/${health.total_validators + health.total_miners}`);

        console.log("\n✅ Demo completed successfully!");
        console.log(`📋 Summary:`);
        console.log(`  • Contract initialized: ✅`);
        console.log(`  • Subnet created: ✅`);
        console.log(`  • Miners registered: ${minerTxns.length}`);
        console.log(`  • Batch updates executed: ${batchTxns.length}`);
        console.log(`  • Total miners updated: ${updates.length}`);

    } catch (error) {
        console.error("❌ Demo failed:", error);
    }
}

/**
 * Performance benchmark for batch operations
 */
async function benchmarkBatchOperations() {
    console.log("⚡ Benchmarking batch operations...\n");

    const adminPrivateKey = "0x..."; // Replace with actual admin private key
    const mtClient = new ModernTensorClient(adminPrivateKey, CONTRACT_ADDRESS);

    // Test different batch sizes
    const batchSizes = [1, 10, 50, 100];

    for (const size of batchSizes) {
        console.log(`📊 Testing batch size: ${size}`);

        const start = Date.now();
        const gasEstimate = await mtClient.estimateGasCost(size, 0);
        const end = Date.now();

        console.log(`  ⏱️  Gas estimate: ${gasEstimate} units`);
        console.log(`  ⏱️  Query time: ${end - start}ms`);
        console.log(`  📈 Gas per miner: ${Math.round(gasEstimate / size)} units`);
        console.log("");
    }
}

// Run demos
if (require.main === module) {
    console.log("Select demo to run:");
    console.log("1. Full 256 miners management demo");
    console.log("2. Performance benchmarking");

    const args = process.argv.slice(2);
    const demoType = args[0] || "1";

    if (demoType === "1") {
        demo256MinersManagement().catch(console.error);
    } else if (demoType === "2") {
        benchmarkBatchOperations().catch(console.error);
    } else {
        console.log("Invalid demo type. Use 1 or 2.");
    }
}

export { ModernTensorClient }; 