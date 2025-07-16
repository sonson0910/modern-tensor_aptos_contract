/**
 * ModernTensor TypeScript Client Example
 * ====================================
 * 
 * This example shows how to interact with the ModernTensor contract
 * using TypeScript and the Aptos SDK.
 */

import { AptosClient, AptosAccount, HexString, TxnBuilderTypes, BCS } from "aptos";

// Configuration
const NODE_URL = "https://fullnode.testnet.aptoslabs.com";
const CONTRACT_ADDRESS = "0x87819820371c5ab2332da6ffdbaec7ce315da129bc1dfa47b7c726df77abe597";

class ModernTensorClient {
    private client: AptosClient;
    private account: AptosAccount;

    constructor(privateKey?: string) {
        this.client = new AptosClient(NODE_URL);
        this.account = privateKey ?
            new AptosAccount(HexString.ensure(privateKey).toUint8Array()) :
            new AptosAccount();
    }

    /**
     * Get network statistics
     */
    async getNetworkStats() {
        try {
            const stats = await this.client.view({
                function: `${CONTRACT_ADDRESS}::moderntensor::get_enhanced_network_stats`,
                arguments: [],
                type_arguments: []
            });

            return {
                totalValidators: stats[0],
                totalMiners: stats[1],
                totalSubnets: stats[2],
                totalStake: stats[3],
                activeValidators: stats[4],
                activeMiners: stats[5]
            };
        } catch (error) {
            console.error("Error fetching network stats:", error);
            throw error;
        }
    }

    /**
     * Get fee information
     */
    async getFeeInfo() {
        try {
            const feeInfo = await this.client.view({
                function: `${CONTRACT_ADDRESS}::moderntensor::get_registration_fee_info`,
                arguments: [],
                type_arguments: []
            });

            return {
                minerFee: feeInfo[0],
                validatorFee: feeInfo[1],
                subnetFee: feeInfo[2],
                permitFee: feeInfo[3]
            };
        } catch (error) {
            console.error("Error fetching fee info:", error);
            throw error;
        }
    }

    /**
     * Get treasury statistics
     */
    async getTreasuryStats() {
        try {
            const stats = await this.client.view({
                function: `${CONTRACT_ADDRESS}::moderntensor::get_treasury_stats`,
                arguments: [],
                type_arguments: []
            });

            return {
                totalBurned: stats[0],
                totalTreasuryFees: stats[1],
                totalRegistrations: stats[2],
                totalPermits: stats[3]
            };
        } catch (error) {
            console.error("Error fetching treasury stats:", error);
            throw error;
        }
    }

    /**
     * Create a subnet
     */
    async createSubnet(
        subnetId: number,
        name: string,
        description: string,
        maxValidators: number,
        maxMiners: number,
        minStakeValidator: number,
        minStakeMiner: number,
        permitsRequired: boolean = false
    ) {
        const payload = {
            type: "entry_function_payload",
            function: `${CONTRACT_ADDRESS}::moderntensor::create_subnet`,
            arguments: [
                subnetId,
                name,
                description,
                maxValidators,
                maxMiners,
                minStakeValidator,
                minStakeMiner,
                permitsRequired
            ],
            type_arguments: []
        };

        try {
            const txnRequest = await this.client.generateTransaction(this.account.address(), payload);
            const signedTxn = await this.client.signTransaction(this.account, txnRequest);
            const transactionRes = await this.client.submitTransaction(signedTxn);
            await this.client.waitForTransaction(transactionRes.hash);

            console.log(`✅ Subnet ${subnetId} created successfully`);
            return transactionRes;
        } catch (error) {
            console.error("Error creating subnet:", error);
            throw error;
        }
    }

    /**
     * Register as a miner
     */
    async registerMiner(
        uid: string,
        subnetId: number,
        stake: number,
        walletHash: string,
        apiEndpoint: string
    ) {
        const payload = {
            type: "entry_function_payload",
            function: `${CONTRACT_ADDRESS}::moderntensor::register_miner`,
            arguments: [
                HexString.fromUint8Array(new TextEncoder().encode(uid)).hex(),
                subnetId,
                stake,
                HexString.fromUint8Array(new TextEncoder().encode(walletHash)).hex(),
                HexString.fromUint8Array(new TextEncoder().encode(apiEndpoint)).hex()
            ],
            type_arguments: []
        };

        try {
            const txnRequest = await this.client.generateTransaction(this.account.address(), payload);
            const signedTxn = await this.client.signTransaction(this.account, txnRequest);
            const transactionRes = await this.client.submitTransaction(signedTxn);
            await this.client.waitForTransaction(transactionRes.hash);

            console.log(`✅ Miner ${uid} registered successfully`);
            return transactionRes;
        } catch (error) {
            console.error("Error registering miner:", error);
            throw error;
        }
    }

    /**
     * Register as a validator
     */
    async registerValidator(
        uid: string,
        subnetId: number,
        stake: number,
        bond: number,
        walletHash: string,
        apiEndpoint: string
    ) {
        const payload = {
            type: "entry_function_payload",
            function: `${CONTRACT_ADDRESS}::moderntensor::register_validator`,
            arguments: [
                HexString.fromUint8Array(new TextEncoder().encode(uid)).hex(),
                subnetId,
                stake,
                bond,
                HexString.fromUint8Array(new TextEncoder().encode(walletHash)).hex(),
                HexString.fromUint8Array(new TextEncoder().encode(apiEndpoint)).hex()
            ],
            type_arguments: []
        };

        try {
            const txnRequest = await this.client.generateTransaction(this.account.address(), payload);
            const signedTxn = await this.client.signTransaction(this.account, txnRequest);
            const transactionRes = await this.client.submitTransaction(signedTxn);
            await this.client.waitForTransaction(transactionRes.hash);

            console.log(`✅ Validator ${uid} registered successfully`);
            return transactionRes;
        } catch (error) {
            console.error("Error registering validator:", error);
            throw error;
        }
    }

    /**
     * Purchase validator permit
     */
    async purchaseValidatorPermit(subnetId: number) {
        const payload = {
            type: "entry_function_payload",
            function: `${CONTRACT_ADDRESS}::moderntensor::purchase_validator_permit`,
            arguments: [subnetId],
            type_arguments: []
        };

        try {
            const txnRequest = await this.client.generateTransaction(this.account.address(), payload);
            const signedTxn = await this.client.signTransaction(this.account, txnRequest);
            const transactionRes = await this.client.submitTransaction(signedTxn);
            await this.client.waitForTransaction(transactionRes.hash);

            console.log(`✅ Validator permit purchased for subnet ${subnetId}`);
            return transactionRes;
        } catch (error) {
            console.error("Error purchasing validator permit:", error);
            throw error;
        }
    }

    /**
     * Get account balance
     */
    async getBalance(): Promise<number> {
        try {
            const resources = await this.client.getAccountResources(this.account.address());
            const accountResource = resources.find(r => r.type === "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>");
            return accountResource ? parseInt((accountResource.data as any).coin.value) : 0;
        } catch (error) {
            console.error("Error fetching balance:", error);
            return 0;
        }
    }

    /**
     * Get account address
     */
    getAddress(): string {
        return this.account.address().hex();
    }

    /**
     * Get private key for backup
     */
    getPrivateKey(): string {
        return HexString.fromUint8Array(this.account.signingKey.secretKey).hex();
    }
}

// Example usage
async function main() {
    console.log("🚀 ModernTensor TypeScript Client Demo");
    console.log("=" * 40);

    // Create client
    const client = new ModernTensorClient();

    console.log(`📍 Account Address: ${client.getAddress()}`);
    console.log(`🔑 Private Key: ${client.getPrivateKey()}`);

    try {
        // Get network stats
        console.log("\n📊 Network Statistics:");
        const stats = await client.getNetworkStats();
        console.log(`- Total Validators: ${stats.totalValidators}`);
        console.log(`- Total Miners: ${stats.totalMiners}`);
        console.log(`- Total Subnets: ${stats.totalSubnets}`);
        console.log(`- Total Stake: ${stats.totalStake}`);

        // Get fee info
        console.log("\n💰 Fee Information:");
        const feeInfo = await client.getFeeInfo();
        console.log(`- Miner Fee: ${feeInfo.minerFee} APT`);
        console.log(`- Validator Fee: ${feeInfo.validatorFee} APT`);
        console.log(`- Subnet Fee: ${feeInfo.subnetFee} APT`);
        console.log(`- Permit Fee: ${feeInfo.permitFee} APT`);

        // Get treasury stats
        console.log("\n🏦 Treasury Statistics:");
        const treasuryStats = await client.getTreasuryStats();
        console.log(`- Total Burned: ${treasuryStats.totalBurned}`);
        console.log(`- Total Treasury Fees: ${treasuryStats.totalTreasuryFees}`);
        console.log(`- Total Registrations: ${treasuryStats.totalRegistrations}`);

        // Check balance
        const balance = await client.getBalance();
        console.log(`\n💰 Account Balance: ${balance} APT`);

        if (balance < 100000000) { // 1 APT
            console.log("⚠️ Low balance! Fund your account with testnet APT:");
            console.log(`aptos account fund-with-faucet --account ${client.getAddress()}`);
        }

    } catch (error) {
        console.error("❌ Error:", error);
    }
}

// Run example
if (require.main === module) {
    main().catch(console.error);
}

export { ModernTensorClient }; 