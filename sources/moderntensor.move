module moderntensor_contract::moderntensor {
    use std::signer;
    use std::vector;
    use std::string::{Self, String};
    // use std::option::{Self, Option}; // Removed since we're not using Option anymore
    use aptos_framework::timestamp;
    use aptos_framework::event;
    use aptos_framework::account;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_std::table::{Self, Table};
    use aptos_framework::fungible_asset::{Self, Metadata};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::object::{Self, Object};

    // ==================== ERROR CODES ====================
    const E_NOT_ADMIN: u64 = 1;
    const E_ALREADY_REGISTERED: u64 = 2;
    const E_NOT_REGISTERED: u64 = 3;
    const E_INVALID_PARAMS: u64 = 4;
    const E_INSUFFICIENT_STAKE: u64 = 5;
    const E_INVALID_SUBNET: u64 = 6;
    const E_BATCH_SIZE_EXCEEDED: u64 = 7;
    const E_INVALID_STATUS: u64 = 8;
    const E_STAKE_LOCKED: u64 = 9;
    const E_SLASHING_NOT_ALLOWED: u64 = 10;
    const E_VALIDATOR_LIMIT_EXCEEDED: u64 = 11;
    const E_MINER_LIMIT_EXCEEDED: u64 = 12;
    const E_PERFORMANCE_OUT_OF_RANGE: u64 = 13;
    const E_TRUST_SCORE_OUT_OF_RANGE: u64 = 14;
    const E_WEIGHT_OUT_OF_RANGE: u64 = 15;
    
    // Economic constraint errors
    const E_INSUFFICIENT_REGISTRATION_FEE: u64 = 16;
    const E_INSUFFICIENT_VALIDATOR_BOND: u64 = 17;
    const E_REGISTRATION_COOLDOWN_ACTIVE: u64 = 18;
    const E_VALIDATOR_PERMIT_REQUIRED: u64 = 19;
    const E_IMMUNITY_PERIOD_ACTIVE: u64 = 20;
    const E_INSUFFICIENT_FUNDS: u64 = 21;
    const E_WEIGHT_SETTING_COOLDOWN: u64 = 22;
    const E_RECYCLING_NOT_AVAILABLE: u64 = 23;
    const E_VALIDATOR_BOND_LOCKED: u64 = 24;
    const E_SUBNET_CREATION_FEE_REQUIRED: u64 = 25;

    // ==================== CONSTANTS ====================
    const ADMIN_ADDRESS: address = @moderntensor_contract;
    
    // Status constants
    const STATUS_INACTIVE: u64 = 0;
    const STATUS_ACTIVE: u64 = 1;
    const STATUS_JAILED: u64 = 2;
    const STATUS_SLASHED: u64 = 3;
    
    // Limits and constraints
    const MIN_STAKE: u64 = 1000000; // 0.01 APT (1e8 scaled)
    const MAX_STAKE: u64 = 100000000000000; // 1M APT
    const MAX_VALIDATORS_PER_SUBNET: u64 = 50;
    const MAX_MINERS_PER_SUBNET: u64 = 1000;
    const MAX_BATCH_SIZE: u64 = 100; // Maximum batch update size
    const PERFORMANCE_SCALE: u64 = 100000000; // 1e8 for precision
    const MIN_TRUST_SCORE: u64 = 0;
    const MAX_TRUST_SCORE: u64 = 100000000; // 1.0 scaled by 1e8
    const MIN_WEIGHT: u64 = 1000000; // 0.01 scaled by 1e8
    const MAX_WEIGHT: u64 = 500000000; // 5.0 scaled by 1e8
    const STAKE_LOCK_PERIOD: u64 = 86400000000; // 24 hours in microseconds
    const SLASH_RATE: u64 = 10000000; // 10% slashing rate
    
    // Registration and Economic Constraints (Testing - Low Fees)
    const MINER_REGISTRATION_FEE: u64 = 1000000; // 0.01 APT (testing)
    const VALIDATOR_REGISTRATION_FEE: u64 = 5000000; // 0.05 APT (testing)
    const VALIDATOR_BOND_AMOUNT: u64 = 50000000; // 0.5 APT (testing)
    const SUBNET_CREATION_FEE: u64 = 10000000; // 0.1 APT (testing)
    const BURN_PERCENTAGE: u64 = 50000000; // 50% of fees burned (0.5 * 1e8)
    const TREASURY_ADDRESS: address = @0x1111111111111111111111111111111111111111111111111111111111111111;
    
    // Time constraints (Reduced for testing)
    const REGISTRATION_COOLDOWN: u64 = 300000000; // 5 minutes in microseconds (testing)
    const VALIDATOR_PERMIT_COOLDOWN: u64 = 3600000000; // 1 hour (testing)
    const IMMUNITY_PERIOD: u64 = 600000000; // 10 minutes for new registrations (testing)
    const RECYCLE_PERIOD: u64 = 86400000000; // 1 day (testing)
    const WEIGHT_SETTING_COOLDOWN: u64 = 300000000; // 5 minutes (testing)
    
    // Economic parameters (Testing - Lower amounts)
    const MIN_VALIDATOR_BOND: u64 = 10000000; // 0.1 APT (testing)
    const MAX_VALIDATOR_BOND: u64 = 1000000000; // 10 APT (testing)
    const VALIDATOR_PERMIT_PRICE: u64 = 2000000; // 0.02 APT (testing)
    const RECYCLING_REWARD: u64 = 5000000; // 0.05 APT reward for recycling (testing)
    
    // APT Fungible Asset metadata object address
    const APT_METADATA_ADDRESS: address = @0xa;

    // ==================== STRUCTS ====================
    
    // Treasury for managing economic operations
    struct Treasury has key {
        total_burned: u64,
        total_fees_collected: u64,
        registration_fees_collected: u64,
        validator_bonds_locked: u64,
        subnet_creation_fees: u64,
        recycling_rewards_paid: u64,
        last_burn_time: u64,
        burn_events: event::EventHandle<BurnEvent>,
    }
    
    // Validator Permit system
    struct ValidatorPermit has key, copy, drop, store {
        validator_address: address,
        permit_price_paid: u64,
        issued_at: u64,
        expires_at: u64,
        is_active: bool,
        subnet_uid: u64,
    }
    
    // Registration cooldown tracking
    struct RegistrationCooldown has key, copy, drop, store {
        address: address,
        last_registration_time: u64,
        registration_type: String, // "miner" or "validator"
        cooldown_until: u64,
    }
    
    // Recycling mechanism for inactive nodes
    struct RecyclingInfo has key, copy, drop, store {
        node_address: address,
        node_type: String, // "miner" or "validator"
        last_active_time: u64,
        recyclable_after: u64,
        recycling_reward: u64,
        is_recyclable: bool,
    }

    // Enhanced Subnet Information
    struct SubnetInfo has key, copy, drop, store {
        subnet_uid: u64,
        name: String,
        description: String,
        max_validators: u64,
        max_miners: u64,
        min_stake_validator: u64,
        min_stake_miner: u64,
        validator_count: u64,
        miner_count: u64,
        total_stake: u64,
        is_active: bool,
        created_at: u64,
        last_update: u64,
        creation_fee_paid: u64,
        validator_permits_required: bool,
        immunity_period: u64,
    }

    // Enhanced Global Registry with Smart Tables for better scalability
    struct GlobalRegistry has key {
        // Smart tables for O(1) access
        validators: SmartTable<address, ValidatorInfo>,
        miners: SmartTable<address, MinerInfo>,
        subnets: SmartTable<u64, SubnetInfo>,
        
        // Indexing for efficient queries
        validators_by_subnet: SmartTable<u64, vector<address>>,
        miners_by_subnet: SmartTable<u64, vector<address>>,
        active_validators: vector<address>,
        active_miners: vector<address>,
        
        // Global statistics
        total_validators: u64,
        total_miners: u64,
        total_subnets: u64,
        total_stake: u64,
        network_hash: vector<u8>,
        last_update: u64,
        
        // Governance parameters
        min_validator_stake: u64,
        min_miner_stake: u64,
        max_validators_global: u64,
        max_miners_global: u64,
        
        // Event handles
        validator_events: event::EventHandle<ValidatorEvent>,
        miner_events: event::EventHandle<MinerEvent>,
        batch_events: event::EventHandle<BatchUpdateEvent>,
        subnet_events: event::EventHandle<SubnetEvent>,
        slash_events: event::EventHandle<SlashEvent>,
    }

    // Enhanced Validator Information with additional constraints
    struct ValidatorInfo has key, copy, drop, store {
        uid: vector<u8>,
        subnet_uid: u64,
        stake: u64,
        trust_score: u64, // 0 to 1e8 (0.0 to 1.0)
        last_performance: u64, // 0 to 1e8
        accumulated_rewards: u64,
        slashed_amount: u64,
        last_update_time: u64,
        performance_history_hash: vector<u8>,
        wallet_addr_hash: vector<u8>,
        status: u64,
        registration_time: u64,
        last_active_time: u64,
        api_endpoint: vector<u8>,
        weight: u64, // 0.01 to 5.0 scaled by 1e8
        validator_address: address,
        stake_locked_until: u64,
        consecutive_failures: u64,
        delegation_enabled: bool,
        delegated_stake: u64,
        
        // Economic constraints (Bittensor-like)
        registration_fee_paid: u64,
        validator_bond: u64,
        bond_locked_until: u64,
        has_permit: bool,
        permit_expires_at: u64,
        immunity_until: u64,
        last_weight_set_time: u64,
        recycling_eligible_at: u64,
        total_fees_paid: u64,
    }

    // Enhanced Miner Information
    struct MinerInfo has key, copy, drop, store {
        uid: vector<u8>,
        subnet_uid: u64,
        stake: u64,
        trust_score: u64,
        last_performance: u64,
        accumulated_rewards: u64,
        slashed_amount: u64,
        last_update_time: u64,
        performance_history_hash: vector<u8>,
        wallet_addr_hash: vector<u8>,
        status: u64,
        registration_time: u64,
        last_active_time: u64,
        api_endpoint: vector<u8>,
        weight: u64,
        miner_address: address,
        stake_locked_until: u64,
        consecutive_failures: u64,
        tasks_completed: u64,
        tasks_failed: u64,
        
        // Economic constraints (Bittensor-like)
        registration_fee_paid: u64,
        immunity_until: u64,
        recycling_eligible_at: u64,
        total_fees_paid: u64,
        registration_cooldown_until: u64,
    }

    // Batch Update Structures (Reference only - not used in entry functions)
    // These structs are kept for client implementations that might construct them locally
    struct BatchMinerUpdate has copy, drop, store {
        miner_addr: address,
        trust_score: u64,
        performance: u64,
        rewards: u64,
        weight: u64,
        status: u64, // 0 = no change, 1 = active, 2 = inactive, etc.
    }

    struct BatchValidatorUpdate has copy, drop, store {
        validator_addr: address,
        trust_score: u64,
        performance: u64,
        rewards: u64,
        weight: u64,
        status: u64, // 0 = no change, 1 = active, 2 = inactive, etc.
    }

    // ==================== EVENTS ====================
    
    struct ValidatorEvent has drop, store {
        event_type: String, // "registered", "updated", "status_changed", "slashed"
        validator_address: address,
        uid: vector<u8>,
        subnet_uid: u64,
        old_status: u64, // 0 = no previous status
        new_status: u64, // 0 = no new status
        stake: u64,
        trust_score: u64,
        timestamp: u64,
    }

    struct MinerEvent has drop, store {
        event_type: String,
        miner_address: address,
        uid: vector<u8>,
        subnet_uid: u64,
        old_status: u64, // 0 = no previous status
        new_status: u64, // 0 = no new status
        stake: u64,
        trust_score: u64,
        timestamp: u64,
    }

    struct BatchUpdateEvent has drop, store {
        update_type: String, // "miners" or "validators"
        updated_count: u64,
        total_rewards_distributed: u64,
        average_performance: u64,
        timestamp: u64,
    }

    struct SubnetEvent has drop, store {
        event_type: String, // "created", "updated", "activated", "deactivated"
        subnet_uid: u64,
        name: String,
        validator_count: u64,
        miner_count: u64,
        total_stake: u64,
        timestamp: u64,
    }

    struct SlashEvent has drop, store {
        node_type: String, // "validator" or "miner"
        node_address: address,
        subnet_uid: u64,
        slashed_amount: u64,
        reason: String,
        timestamp: u64,
    }
    
    struct BurnEvent has drop, store {
        amount_burned: u64,
        burn_reason: String, // "registration_fee", "validator_bond", "subnet_creation"
        original_amount: u64,
        treasury_amount: u64,
        timestamp: u64,
    }
    
    struct RegistrationFeeEvent has drop, store {
        node_type: String, // "validator" or "miner"
        node_address: address,
        subnet_uid: u64,
        fee_amount: u64,
        burned_amount: u64,
        treasury_amount: u64,
        timestamp: u64,
    }
    
    struct ValidatorPermitEvent has drop, store {
        validator_address: address,
        subnet_uid: u64,
        permit_fee: u64,
        issued_at: u64,
        expires_at: u64,
        timestamp: u64,
    }
    
    struct RecyclingEvent has drop, store {
        node_type: String,
        recycled_address: address,
        recycler_address: address,
        subnet_uid: u64,
        reward_amount: u64,
        timestamp: u64,
    }

    // ==================== HELPER FUNCTIONS ====================
    
    /// Get APT fungible asset metadata
    fun get_apt_metadata(): Object<Metadata> {
        object::address_to_object<Metadata>(APT_METADATA_ADDRESS)
    }
    
    /// Validate performance score range
    fun validate_performance(performance: u64) {
        assert!(performance <= PERFORMANCE_SCALE, E_PERFORMANCE_OUT_OF_RANGE);
    }
    
    /// Validate trust score range
    fun validate_trust_score(trust_score: u64) {
        assert!(trust_score <= MAX_TRUST_SCORE, E_TRUST_SCORE_OUT_OF_RANGE);
    }
    
    /// Validate weight range
    fun validate_weight(weight: u64) {
        assert!(weight >= MIN_WEIGHT && weight <= MAX_WEIGHT, E_WEIGHT_OUT_OF_RANGE);
    }
    
    /// Validate status
    fun validate_status(status: u64) {
        assert!(status <= STATUS_SLASHED, E_INVALID_STATUS);
    }
    
    /// Check if stake is locked
    fun is_stake_locked(locked_until: u64): bool {
        timestamp::now_microseconds() < locked_until
    }
    
    /// Validate subnet limits
    fun validate_subnet_limits(subnet_info: &SubnetInfo, is_validator: bool) {
        if (is_validator) {
            assert!(subnet_info.validator_count < subnet_info.max_validators, E_VALIDATOR_LIMIT_EXCEEDED);
        } else {
            assert!(subnet_info.miner_count < subnet_info.max_miners, E_MINER_LIMIT_EXCEEDED);
        }
    }
    
    /// Process fee payment with burn mechanism
    fun process_fee_with_burn(
        payer: &signer,
        fee_amount: u64,
        burn_reason: String,
        treasury: &mut Treasury
    ): (u64, u64) {
        // Transfer fee from payer to contract
        let apt_metadata = get_apt_metadata();
        primary_fungible_store::transfer(payer, apt_metadata, ADMIN_ADDRESS, fee_amount);
        
        // Calculate burn and treasury amounts
        let burn_amount = (fee_amount * BURN_PERCENTAGE) / 100000000;
        let treasury_amount = fee_amount - burn_amount;
        
        // Update treasury stats
        treasury.total_fees_collected = treasury.total_fees_collected + fee_amount;
        treasury.total_burned = treasury.total_burned + burn_amount;
        treasury.last_burn_time = timestamp::now_microseconds();
        
        // Emit burn event
        event::emit_event(&mut treasury.burn_events, BurnEvent {
            amount_burned: burn_amount,
            burn_reason,
            original_amount: fee_amount,
            treasury_amount,
            timestamp: timestamp::now_microseconds(),
        });
        
        (burn_amount, treasury_amount)
    }
    
    /// Check registration cooldown
    fun check_registration_cooldown(address: address, _node_type: String): bool acquires RegistrationCooldown {
        let current_time = timestamp::now_microseconds();
        if (exists<RegistrationCooldown>(address)) {
            let cooldown = borrow_global<RegistrationCooldown>(address);
            current_time >= cooldown.cooldown_until
        } else {
            true
        }
    }
    
    /// Set registration cooldown
    fun set_registration_cooldown(
        address: address,
        node_type: String,
        cooldown_duration: u64
    ) acquires RegistrationCooldown {
        let current_time = timestamp::now_microseconds();
        let cooldown = RegistrationCooldown {
            address,
            last_registration_time: current_time,
            registration_type: node_type,
            cooldown_until: current_time + cooldown_duration,
        };
        
        if (exists<RegistrationCooldown>(address)) {
            let existing_cooldown = borrow_global_mut<RegistrationCooldown>(address);
            *existing_cooldown = cooldown;
        };
        
        // Note: In production, registration cooldown would be stored in a global registry
        // For simplicity, we'll store it in the admin account for now
    }
    
    /// Check if validator has valid permit
    fun has_valid_permit(validator_addr: address, subnet_uid: u64): bool acquires ValidatorPermit {
        if (!exists<ValidatorPermit>(validator_addr)) {
            return false
        };
        
        let permit = borrow_global<ValidatorPermit>(validator_addr);
        let current_time = timestamp::now_microseconds();
        
        permit.is_active && 
        permit.subnet_uid == subnet_uid &&
        current_time < permit.expires_at
    }
    
    /// Check if node is in immunity period
    fun is_in_immunity_period(immunity_until: u64): bool {
        timestamp::now_microseconds() < immunity_until
    }
    
    /// Check if node is recyclable
    fun is_recyclable(last_active_time: u64): bool {
        let current_time = timestamp::now_microseconds();
        current_time > (last_active_time + RECYCLE_PERIOD)
    }
    
    /// Validate validator bond amount
    fun validate_validator_bond(bond_amount: u64) {
        assert!(bond_amount >= MIN_VALIDATOR_BOND && bond_amount <= MAX_VALIDATOR_BOND, E_INSUFFICIENT_VALIDATOR_BOND);
    }

    // ==================== INITIALIZATION ====================
    
    /// Initialize the ModernTensor contract with enhanced features
    public entry fun initialize(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == ADMIN_ADDRESS, E_NOT_ADMIN);
        assert!(!exists<GlobalRegistry>(admin_addr), E_ALREADY_REGISTERED);
        
        // Initialize Treasury
        move_to(admin, Treasury {
            total_burned: 0,
            total_fees_collected: 0,
            registration_fees_collected: 0,
            validator_bonds_locked: 0,
            subnet_creation_fees: 0,
            recycling_rewards_paid: 0,
            last_burn_time: timestamp::now_microseconds(),
            burn_events: account::new_event_handle<BurnEvent>(admin),
        });
        
        // Initialize Global Registry
        move_to(admin, GlobalRegistry {
            validators: smart_table::new<address, ValidatorInfo>(),
            miners: smart_table::new<address, MinerInfo>(),
            subnets: smart_table::new<u64, SubnetInfo>(),
            validators_by_subnet: smart_table::new<u64, vector<address>>(),
            miners_by_subnet: smart_table::new<u64, vector<address>>(),
            active_validators: vector::empty<address>(),
            active_miners: vector::empty<address>(),
            total_validators: 0,
            total_miners: 0,
            total_subnets: 0,
            total_stake: 0,
            network_hash: vector::empty<u8>(),
            last_update: timestamp::now_microseconds(),
            min_validator_stake: MIN_STAKE,
            min_miner_stake: MIN_STAKE,
            max_validators_global: 1000,
            max_miners_global: 10000,
            validator_events: account::new_event_handle<ValidatorEvent>(admin),
            miner_events: account::new_event_handle<MinerEvent>(admin),
            batch_events: account::new_event_handle<BatchUpdateEvent>(admin),
            subnet_events: account::new_event_handle<SubnetEvent>(admin),
            slash_events: account::new_event_handle<SlashEvent>(admin),
        });
    }

    /// Create a new subnet with enhanced parameters (requires fee payment)
    public entry fun create_subnet(
        creator: &signer,
        subnet_uid: u64,
        name: String,
        description: String,
        max_validators: u64,
        max_miners: u64,
        min_stake_validator: u64,
        min_stake_miner: u64,
        validator_permits_required: bool,
    ) acquires GlobalRegistry, Treasury {
        let creator_addr = signer::address_of(creator);
        
        // Only admin can create subnets, or users who pay the fee
        let is_admin = creator_addr == ADMIN_ADDRESS;
        if (!is_admin) {
            // Non-admin must pay subnet creation fee
            let treasury = borrow_global_mut<Treasury>(ADMIN_ADDRESS);
            let (burn_amount, treasury_amount) = process_fee_with_burn(
                creator,
                SUBNET_CREATION_FEE,
                string::utf8(b"subnet_creation"),
                treasury
            );
            treasury.subnet_creation_fees = treasury.subnet_creation_fees + SUBNET_CREATION_FEE;
        };
        
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(!smart_table::contains(&registry.subnets, subnet_uid), E_ALREADY_REGISTERED);
        
        let current_time = timestamp::now_microseconds();
        let subnet_info = SubnetInfo {
            subnet_uid,
            name: name,
            description,
            max_validators,
            max_miners,
            min_stake_validator,
            min_stake_miner,
            validator_count: 0,
            miner_count: 0,
            total_stake: 0,
            is_active: true,
            created_at: current_time,
            last_update: current_time,
            creation_fee_paid: if (is_admin) 0 else SUBNET_CREATION_FEE,
            validator_permits_required,
            immunity_period: IMMUNITY_PERIOD,
        };
        
        smart_table::add(&mut registry.subnets, subnet_uid, subnet_info);
        smart_table::add(&mut registry.validators_by_subnet, subnet_uid, vector::empty<address>());
        smart_table::add(&mut registry.miners_by_subnet, subnet_uid, vector::empty<address>());
        
        registry.total_subnets = registry.total_subnets + 1;
        registry.last_update = current_time;
        
        // Emit subnet creation event
        event::emit_event(&mut registry.subnet_events, SubnetEvent {
            event_type: string::utf8(b"created"),
            subnet_uid,
            name: name,
            validator_count: 0,
            miner_count: 0,
            total_stake: 0,
            timestamp: current_time,
        });
    }

    // ==================== REGISTRATION FUNCTIONS ====================
    
    /// Enhanced validator registration with comprehensive validation and fee requirements
    public entry fun register_validator(
        account: &signer,
        uid: vector<u8>,
        subnet_uid: u64,
        stake_amount: u64,
        validator_bond: u64,
        wallet_addr_hash: vector<u8>,
        api_endpoint: vector<u8>,
    ) acquires GlobalRegistry, Treasury, RegistrationCooldown, ValidatorPermit {
        let account_addr = signer::address_of(account);
        
        // Enhanced validation
        assert!(vector::length(&uid) > 0 && vector::length(&uid) <= 64, E_INVALID_PARAMS);
        assert!(vector::length(&api_endpoint) > 0, E_INVALID_PARAMS);
        assert!(stake_amount >= MIN_STAKE && stake_amount <= MAX_STAKE, E_INSUFFICIENT_STAKE);
        validate_validator_bond(validator_bond);
        
        // Check registration cooldown
        assert!(check_registration_cooldown(account_addr, string::utf8(b"validator")), E_REGISTRATION_COOLDOWN_ACTIVE);
        
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        
        // Check subnet exists and validate limits (save values to avoid borrow conflicts)
        assert!(smart_table::contains(&registry.subnets, subnet_uid), E_INVALID_SUBNET);
        let (subnet_is_active, subnet_min_stake, subnet_permits_required, subnet_validator_count, subnet_max_validators) = {
            let subnet_info = smart_table::borrow(&registry.subnets, subnet_uid);
            (subnet_info.is_active, subnet_info.min_stake_validator, subnet_info.validator_permits_required, 
             subnet_info.validator_count, subnet_info.max_validators)
        };
        
        assert!(subnet_is_active, E_INVALID_SUBNET);
        assert!(stake_amount >= subnet_min_stake, E_INSUFFICIENT_STAKE);
        assert!(subnet_validator_count < subnet_max_validators, E_VALIDATOR_LIMIT_EXCEEDED);
        
        // Check validator permit requirement
        if (subnet_permits_required) {
            // For admin, bypass permit requirement
            if (account_addr != ADMIN_ADDRESS) {
                assert!(has_valid_permit(account_addr, subnet_uid), E_VALIDATOR_PERMIT_REQUIRED);
            };
        };
        
        // Check registration logic: allow subnet transfer if already registered
        let is_already_registered = smart_table::contains(&registry.validators, account_addr);
        let old_subnet_uid_opt = if (is_already_registered) {
            // If already registered, allow changing subnet (transfer between subnets)
            let existing_validator = smart_table::borrow(&registry.validators, account_addr);
            let old_subnet_uid = existing_validator.subnet_uid;
            let old_stake = existing_validator.stake;
            
            // Check not already in the same subnet
            assert!(old_subnet_uid != subnet_uid, E_ALREADY_REGISTERED);
            
            // Remove from old subnet
            let old_subnet_validators = smart_table::borrow_mut(&mut registry.validators_by_subnet, old_subnet_uid);
            let (found, index) = vector::index_of(old_subnet_validators, &account_addr);
            if (found) {
                vector::remove(old_subnet_validators, index);
            };
            
            // Update old subnet count (store values first to avoid borrow conflicts)
            old_subnet_uid
        } else {
            // New registration
            assert!(registry.total_validators < registry.max_validators_global, E_VALIDATOR_LIMIT_EXCEEDED);
            0 // placeholder
        };
        
        // Update old subnet after releasing other borrows
        if (is_already_registered) {
            let existing_validator = smart_table::borrow(&registry.validators, account_addr);
            let old_stake = existing_validator.stake;
            let old_subnet_info = smart_table::borrow_mut(&mut registry.subnets, old_subnet_uid_opt);
            old_subnet_info.validator_count = old_subnet_info.validator_count - 1;
            old_subnet_info.total_stake = old_subnet_info.total_stake - old_stake;
        };
        
        // Process registration fee and validator bond
        let treasury = borrow_global_mut<Treasury>(ADMIN_ADDRESS);
        let (burn_amount, treasury_amount) = process_fee_with_burn(
            account,
            VALIDATOR_REGISTRATION_FEE,
            string::utf8(b"validator_registration"),
            treasury
        );
        treasury.registration_fees_collected = treasury.registration_fees_collected + VALIDATOR_REGISTRATION_FEE;
        
        // Lock validator bond
        let apt_metadata = get_apt_metadata();
        primary_fungible_store::transfer(account, apt_metadata, ADMIN_ADDRESS, validator_bond);
        treasury.validator_bonds_locked = treasury.validator_bonds_locked + validator_bond;
        
        let current_time = timestamp::now_microseconds();
        let validator_info = ValidatorInfo {
            uid: uid,
            subnet_uid,
            stake: stake_amount,
            trust_score: MAX_TRUST_SCORE / 2, // Start with 0.5
            last_performance: 0,
            accumulated_rewards: 0,
            slashed_amount: 0,
            last_update_time: current_time,
            performance_history_hash: vector::empty<u8>(),
            wallet_addr_hash,
            status: STATUS_ACTIVE,
            registration_time: current_time,
            last_active_time: current_time,
            api_endpoint,
            weight: PERFORMANCE_SCALE, // Start with 1.0
            validator_address: account_addr,
            stake_locked_until: current_time + STAKE_LOCK_PERIOD,
            consecutive_failures: 0,
            delegation_enabled: false,
            delegated_stake: 0,
            
            // Economic constraints (Bittensor-like)
            registration_fee_paid: VALIDATOR_REGISTRATION_FEE,
            validator_bond,
            bond_locked_until: current_time + STAKE_LOCK_PERIOD,
            has_permit: subnet_permits_required,
            permit_expires_at: if (subnet_permits_required) current_time + VALIDATOR_PERMIT_COOLDOWN else 0,
            immunity_until: current_time + IMMUNITY_PERIOD,
            last_weight_set_time: current_time,
            recycling_eligible_at: current_time + RECYCLE_PERIOD,
            total_fees_paid: VALIDATOR_REGISTRATION_FEE,
        };
        
        // Update registry - use upsert to handle both new and existing validators
        if (is_already_registered) {
            // Remove existing entry first
            smart_table::remove(&mut registry.validators, account_addr);
        };
        smart_table::add(&mut registry.validators, account_addr, validator_info);
        
        // Update subnet
        let subnet_info = smart_table::borrow_mut(&mut registry.subnets, subnet_uid);
        subnet_info.validator_count = subnet_info.validator_count + 1;
        subnet_info.total_stake = subnet_info.total_stake + stake_amount;
        subnet_info.last_update = current_time;
        
        // Update indices
        let subnet_validators = smart_table::borrow_mut(&mut registry.validators_by_subnet, subnet_uid);
        vector::push_back(subnet_validators, account_addr);
        
        // Only add to active_validators if not already there
        let (found_active, _) = vector::index_of(&registry.active_validators, &account_addr);
        if (!found_active) {
            vector::push_back(&mut registry.active_validators, account_addr);
        };
        
        // Update global stats
        if (!is_already_registered) {
            registry.total_validators = registry.total_validators + 1;
        };
        registry.total_stake = registry.total_stake + stake_amount;
        registry.last_update = current_time;
        
        // Set registration cooldown
        set_registration_cooldown(account_addr, string::utf8(b"validator"), REGISTRATION_COOLDOWN);
        
        // Emit registration fee event
        event::emit_event(&mut registry.validator_events, ValidatorEvent {
            event_type: string::utf8(b"registered"),
            validator_address: account_addr,
            uid: uid,
            subnet_uid,
            old_status: 0, // No previous status
            new_status: STATUS_ACTIVE,
            stake: stake_amount,
            trust_score: MAX_TRUST_SCORE / 2,
            timestamp: current_time,
        });
        
        // Emit registration fee event
        let fee_event = RegistrationFeeEvent {
            node_type: string::utf8(b"validator"),
            node_address: account_addr,
            subnet_uid,
            fee_amount: VALIDATOR_REGISTRATION_FEE,
            burned_amount: burn_amount,
            treasury_amount: treasury_amount,
            timestamp: current_time,
        };
        // Note: You might want to add a separate event handle for fee events
    }

    /// Enhanced miner registration with fee requirements
    public entry fun register_miner(
        account: &signer,
        uid: vector<u8>,
        subnet_uid: u64,
        stake_amount: u64,
        wallet_addr_hash: vector<u8>,
        api_endpoint: vector<u8>,
    ) acquires GlobalRegistry, Treasury, RegistrationCooldown {
        let account_addr = signer::address_of(account);
        
        // Enhanced validation
        assert!(vector::length(&uid) > 0 && vector::length(&uid) <= 64, E_INVALID_PARAMS);
        assert!(vector::length(&api_endpoint) > 0, E_INVALID_PARAMS);
        assert!(stake_amount >= MIN_STAKE && stake_amount <= MAX_STAKE, E_INSUFFICIENT_STAKE);
        
        // Check registration cooldown
        assert!(check_registration_cooldown(account_addr, string::utf8(b"miner")), E_REGISTRATION_COOLDOWN_ACTIVE);
        
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        
        // Check subnet exists and validate limits (save values to avoid borrow conflicts)
        assert!(smart_table::contains(&registry.subnets, subnet_uid), E_INVALID_SUBNET);
        let (subnet_is_active, subnet_min_stake, subnet_miner_count, subnet_max_miners) = {
            let subnet_info = smart_table::borrow(&registry.subnets, subnet_uid);
            (subnet_info.is_active, subnet_info.min_stake_miner, subnet_info.miner_count, subnet_info.max_miners)
        };
        
        assert!(subnet_is_active, E_INVALID_SUBNET);
        assert!(stake_amount >= subnet_min_stake, E_INSUFFICIENT_STAKE);
        assert!(subnet_miner_count < subnet_max_miners, E_MINER_LIMIT_EXCEEDED);
        
        // Check registration logic: allow subnet transfer if already registered
        let is_already_registered = smart_table::contains(&registry.miners, account_addr);
        let old_subnet_uid_opt = if (is_already_registered) {
            // If already registered, allow changing subnet (transfer between subnets)
            let existing_miner = smart_table::borrow(&registry.miners, account_addr);
            let old_subnet_uid = existing_miner.subnet_uid;
            let old_stake = existing_miner.stake;
            
            // Check not already in the same subnet
            assert!(old_subnet_uid != subnet_uid, E_ALREADY_REGISTERED);
            
            // Remove from old subnet
            let old_subnet_miners = smart_table::borrow_mut(&mut registry.miners_by_subnet, old_subnet_uid);
            let (found, index) = vector::index_of(old_subnet_miners, &account_addr);
            if (found) {
                vector::remove(old_subnet_miners, index);
            };
            
            // Store old subnet uid for later update
            old_subnet_uid
        } else {
            // New registration
            assert!(registry.total_miners < registry.max_miners_global, E_MINER_LIMIT_EXCEEDED);
            0 // placeholder
        };
        
        // Update old subnet after releasing other borrows
        if (is_already_registered) {
            let existing_miner = smart_table::borrow(&registry.miners, account_addr);
            let old_stake = existing_miner.stake;
            let old_subnet_info = smart_table::borrow_mut(&mut registry.subnets, old_subnet_uid_opt);
            old_subnet_info.miner_count = old_subnet_info.miner_count - 1;
            old_subnet_info.total_stake = old_subnet_info.total_stake - old_stake;
        };
        
        // Process miner registration fee
        let treasury = borrow_global_mut<Treasury>(ADMIN_ADDRESS);
        let (burn_amount, treasury_amount) = process_fee_with_burn(
            account,
            MINER_REGISTRATION_FEE,
            string::utf8(b"miner_registration"),
            treasury
        );
        treasury.registration_fees_collected = treasury.registration_fees_collected + MINER_REGISTRATION_FEE;
        
        let current_time = timestamp::now_microseconds();
        let miner_info = MinerInfo {
            uid: uid,
            subnet_uid,
            stake: stake_amount,
            trust_score: MAX_TRUST_SCORE / 2, // Start with 0.5
            last_performance: 0,
            accumulated_rewards: 0,
            slashed_amount: 0,
            last_update_time: current_time,
            performance_history_hash: vector::empty<u8>(),
            wallet_addr_hash,
            status: STATUS_ACTIVE,
            registration_time: current_time,
            last_active_time: current_time,
            api_endpoint,
            weight: PERFORMANCE_SCALE, // Start with 1.0
            miner_address: account_addr,
            stake_locked_until: current_time + STAKE_LOCK_PERIOD,
            consecutive_failures: 0,
            tasks_completed: 0,
            tasks_failed: 0,
            
            // Economic constraints (Bittensor-like)
            registration_fee_paid: MINER_REGISTRATION_FEE,
            immunity_until: current_time + IMMUNITY_PERIOD,
            recycling_eligible_at: current_time + RECYCLE_PERIOD,
            total_fees_paid: MINER_REGISTRATION_FEE,
            registration_cooldown_until: current_time + REGISTRATION_COOLDOWN,
        };
        
        // Update registry - use upsert to handle both new and existing miners
        if (is_already_registered) {
            // Remove existing entry first
            smart_table::remove(&mut registry.miners, account_addr);
        };
        smart_table::add(&mut registry.miners, account_addr, miner_info);
        
        // Update subnet
        let subnet_info = smart_table::borrow_mut(&mut registry.subnets, subnet_uid);
        subnet_info.miner_count = subnet_info.miner_count + 1;
        subnet_info.total_stake = subnet_info.total_stake + stake_amount;
        subnet_info.last_update = current_time;
        
        // Update indices
        let subnet_miners = smart_table::borrow_mut(&mut registry.miners_by_subnet, subnet_uid);
        vector::push_back(subnet_miners, account_addr);
        
        // Only add to active_miners if not already there
        let (found_active, _) = vector::index_of(&registry.active_miners, &account_addr);
        if (!found_active) {
            vector::push_back(&mut registry.active_miners, account_addr);
        };
        
        // Update global stats
        if (!is_already_registered) {
            registry.total_miners = registry.total_miners + 1;
        };
        registry.total_stake = registry.total_stake + stake_amount;
        registry.last_update = current_time;
        
        // Set registration cooldown
        set_registration_cooldown(account_addr, string::utf8(b"miner"), REGISTRATION_COOLDOWN);
        
        // Emit registration event
        event::emit_event(&mut registry.miner_events, MinerEvent {
            event_type: string::utf8(b"registered"),
            miner_address: account_addr,
            uid: uid,
            subnet_uid,
            old_status: 0, // No previous status
            new_status: STATUS_ACTIVE,
            stake: stake_amount,
            trust_score: MAX_TRUST_SCORE / 2,
            timestamp: current_time,
        });
        
        // Emit registration fee event
        let fee_event = RegistrationFeeEvent {
            node_type: string::utf8(b"miner"),
            node_address: account_addr,
            subnet_uid,
            fee_amount: MINER_REGISTRATION_FEE,
            burned_amount: burn_amount,
            treasury_amount: treasury_amount,
            timestamp: current_time,
        };
        // Note: You might want to add a separate event handle for fee events
    }

    // ==================== ECONOMIC CONSTRAINT FUNCTIONS ====================
    
    /// Purchase validator permit (required for some subnets)
    public entry fun purchase_validator_permit(
        account: &signer,
        subnet_uid: u64,
    ) acquires GlobalRegistry, Treasury, ValidatorPermit {
        let account_addr = signer::address_of(account);
        
        // Check subnet exists
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.subnets, subnet_uid), E_INVALID_SUBNET);
        let subnet_info = smart_table::borrow(&registry.subnets, subnet_uid);
        assert!(subnet_info.is_active, E_INVALID_SUBNET);
        
        // Check validator is registered
        assert!(smart_table::contains(&registry.validators, account_addr), E_NOT_REGISTERED);
        
        // Process permit fee
        let treasury = borrow_global_mut<Treasury>(ADMIN_ADDRESS);
        let (burn_amount, treasury_amount) = process_fee_with_burn(
            account,
            VALIDATOR_PERMIT_PRICE,
            string::utf8(b"validator_permit"),
            treasury
        );
        
        // Create or update permit
        let current_time = timestamp::now_microseconds();
        let permit = ValidatorPermit {
            validator_address: account_addr,
            permit_price_paid: VALIDATOR_PERMIT_PRICE,
            issued_at: current_time,
            expires_at: current_time + VALIDATOR_PERMIT_COOLDOWN,
            is_active: true,
            subnet_uid,
        };
        
        if (exists<ValidatorPermit>(account_addr)) {
            let existing_permit = borrow_global_mut<ValidatorPermit>(account_addr);
            *existing_permit = permit;
        } else {
            // Create new permit
            move_to(account, permit);
        };
        
        // Emit permit event
        let permit_event = ValidatorPermitEvent {
            validator_address: account_addr,
            subnet_uid,
            permit_fee: VALIDATOR_PERMIT_PRICE,
            issued_at: current_time,
            expires_at: current_time + VALIDATOR_PERMIT_COOLDOWN,
            timestamp: current_time,
        };
        // Note: You might want to add a separate event handle for permit events
    }
    
    /// Admin grant validator permit (free)
    public entry fun grant_validator_permit(
        admin: &signer,
        validator_addr: address,
        subnet_uid: u64,
    ) acquires GlobalRegistry, ValidatorPermit {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == ADMIN_ADDRESS, E_NOT_ADMIN);
        
        // Check subnet exists
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.subnets, subnet_uid), E_INVALID_SUBNET);
        let subnet_info = smart_table::borrow(&registry.subnets, subnet_uid);
        assert!(subnet_info.is_active, E_INVALID_SUBNET);
        
        // Create permit
        let current_time = timestamp::now_microseconds();
        let permit = ValidatorPermit {
            validator_address: validator_addr,
            permit_price_paid: 0, // Free grant
            issued_at: current_time,
            expires_at: current_time + VALIDATOR_PERMIT_COOLDOWN,
            is_active: true,
            subnet_uid,
        };
        
        if (exists<ValidatorPermit>(validator_addr)) {
            let existing_permit = borrow_global_mut<ValidatorPermit>(validator_addr);
            *existing_permit = permit;
        } else {
            // Create new permit at validator's account
            // Note: In production, this would need the validator's signature
            // For now, we'll store it in admin account with a mapping
            move_to(admin, permit);
        };
        
        // Emit permit event
        let permit_event = ValidatorPermitEvent {
            validator_address: validator_addr,
            subnet_uid,
            permit_fee: 0,
            issued_at: current_time,
            expires_at: current_time + VALIDATOR_PERMIT_COOLDOWN,
            timestamp: current_time,
        };
        // Note: You might want to add a separate event handle for permit events
    }
    
    /// Reset registration cooldown (admin only)
    public entry fun reset_registration_cooldown(
        admin: &signer,
        target_addr: address,
    ) acquires RegistrationCooldown {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == ADMIN_ADDRESS, E_NOT_ADMIN);
        
        if (exists<RegistrationCooldown>(target_addr)) {
            let cooldown = borrow_global_mut<RegistrationCooldown>(target_addr);
            cooldown.cooldown_until = 0; // Reset cooldown
        };
    }
    
    /// Recycle inactive node to claim rewards
    public entry fun recycle_node(
        recycler: &signer,
        node_address: address,
        node_type: String, // "validator" or "miner"
    ) acquires GlobalRegistry, Treasury {
        let recycler_addr = signer::address_of(recycler);
        let current_time = timestamp::now_microseconds();
        
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        
        // Validate node type and check if recyclable
        if (node_type == string::utf8(b"validator")) {
            assert!(smart_table::contains(&registry.validators, node_address), E_NOT_REGISTERED);
            let validator_info = smart_table::borrow(&registry.validators, node_address);
            assert!(is_recyclable(validator_info.last_active_time), E_RECYCLING_NOT_AVAILABLE);
            assert!(!is_in_immunity_period(validator_info.immunity_until), E_IMMUNITY_PERIOD_ACTIVE);
        } else if (node_type == string::utf8(b"miner")) {
            assert!(smart_table::contains(&registry.miners, node_address), E_NOT_REGISTERED);
            let miner_info = smart_table::borrow(&registry.miners, node_address);
            assert!(is_recyclable(miner_info.last_active_time), E_RECYCLING_NOT_AVAILABLE);
            assert!(!is_in_immunity_period(miner_info.immunity_until), E_IMMUNITY_PERIOD_ACTIVE);
        } else {
            assert!(false, E_INVALID_PARAMS);
        };
        
        // Note: In production, recycling reward would be transferred from treasury
        // For testing, we'll just update the treasury stats
        
        // Update treasury
        let treasury = borrow_global_mut<Treasury>(ADMIN_ADDRESS);
        treasury.recycling_rewards_paid = treasury.recycling_rewards_paid + RECYCLING_REWARD;
        
        // Remove node from registry
        if (node_type == string::utf8(b"validator")) {
            smart_table::remove(&mut registry.validators, node_address);
            registry.total_validators = registry.total_validators - 1;
        } else {
            smart_table::remove(&mut registry.miners, node_address);
            registry.total_miners = registry.total_miners - 1;
        };
        
        // Emit recycling event
        let recycling_event = RecyclingEvent {
            node_type,
            recycled_address: node_address,
            recycler_address: recycler_addr,
            subnet_uid: 0, // Would need to track this
            reward_amount: RECYCLING_REWARD,
            timestamp: current_time,
        };
        // Note: You might want to add a separate event handle for recycling events
    }
    
    /// Set validator weights (with cooldown constraint)
    public entry fun set_validator_weights(
        validator: &signer,
        subnet_uid: u64,
        miner_uids: vector<vector<u8>>,
        weights: vector<u64>,
    ) acquires GlobalRegistry {
        let validator_addr = signer::address_of(validator);
        let current_time = timestamp::now_microseconds();
        
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        
        // Check validator exists
        assert!(smart_table::contains(&registry.validators, validator_addr), E_NOT_REGISTERED);
        let validator_info = smart_table::borrow_mut(&mut registry.validators, validator_addr);
        
        // Check subnet match
        assert!(validator_info.subnet_uid == subnet_uid, E_INVALID_SUBNET);
        
        // Check weight setting cooldown
        assert!(current_time >= validator_info.last_weight_set_time + WEIGHT_SETTING_COOLDOWN, E_WEIGHT_SETTING_COOLDOWN);
        
        // Check not in immunity period
        assert!(!is_in_immunity_period(validator_info.immunity_until), E_IMMUNITY_PERIOD_ACTIVE);
        
        // Validate weights
        let i = 0;
        let len = vector::length(&weights);
        while (i < len) {
            let weight = *vector::borrow(&weights, i);
            validate_weight(weight);
            i = i + 1;
        };
        
        // Update last weight set time
        validator_info.last_weight_set_time = current_time;
        validator_info.last_active_time = current_time;
        
        // Note: In a real implementation, you would store the weights mapping
        // For now, we just validate and update the timestamp
    }
    
    /// Withdraw validator bond (with lock period)
    public entry fun withdraw_validator_bond(
        validator: &signer,
        amount: u64,
    ) acquires GlobalRegistry, Treasury {
        let validator_addr = signer::address_of(validator);
        let current_time = timestamp::now_microseconds();
        
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.validators, validator_addr), E_NOT_REGISTERED);
        let validator_info = smart_table::borrow(&registry.validators, validator_addr);
        
        // Check bond lock period
        assert!(current_time >= validator_info.bond_locked_until, E_VALIDATOR_BOND_LOCKED);
        
        // Check sufficient bond
        assert!(validator_info.validator_bond >= amount, E_INSUFFICIENT_FUNDS);
        
        // Note: In production, validator bond would be transferred back from treasury
        // For testing, we'll just update the treasury stats
        
        // Update treasury
        let treasury = borrow_global_mut<Treasury>(ADMIN_ADDRESS);
        treasury.validator_bonds_locked = treasury.validator_bonds_locked - amount;
        
        // Update validator bond
        let validator_info_mut = smart_table::borrow_mut(&mut borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS).validators, validator_addr);
        validator_info_mut.validator_bond = validator_info_mut.validator_bond - amount;
    }

    // ==================== BATCH UPDATE FUNCTIONS ====================
    
    /// Batch update multiple miners - optimized for 256+ miners
    /// Uses separate vectors for each field to avoid complex struct parameters
    public entry fun batch_update_miners(
        admin: &signer,
        miner_addrs: vector<address>,
        trust_scores: vector<u64>,
        performances: vector<u64>,
        rewards: vector<u64>,
        weights: vector<u64>,
        statuses: vector<u64>, // 0 = no change, 1 = active, 2 = inactive, etc.
    ) acquires GlobalRegistry {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == ADMIN_ADDRESS, E_NOT_ADMIN);
        
        // Validate all vectors have the same length
        let update_count = vector::length(&miner_addrs);
        assert!(update_count > 0 && update_count <= MAX_BATCH_SIZE, E_BATCH_SIZE_EXCEEDED);
        assert!(vector::length(&trust_scores) == update_count, E_INVALID_PARAMS);
        assert!(vector::length(&performances) == update_count, E_INVALID_PARAMS);
        assert!(vector::length(&rewards) == update_count, E_INVALID_PARAMS);
        assert!(vector::length(&weights) == update_count, E_INVALID_PARAMS);
        assert!(vector::length(&statuses) == update_count, E_INVALID_PARAMS);
        
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        let current_time = timestamp::now_microseconds();
        
        let total_rewards = 0u64;
        let total_performance = 0u64;
        let i = 0;
        
        while (i < update_count) {
            let miner_addr = *vector::borrow(&miner_addrs, i);
            let trust_score = *vector::borrow(&trust_scores, i);
            let performance = *vector::borrow(&performances, i);
            let reward = *vector::borrow(&rewards, i);
            let weight = *vector::borrow(&weights, i);
            let status = *vector::borrow(&statuses, i);
            
            assert!(smart_table::contains(&registry.miners, miner_addr), E_NOT_REGISTERED);
            
            let miner_info = smart_table::borrow_mut(&mut registry.miners, miner_addr);
            
            // Validate inputs
            validate_trust_score(trust_score);
            validate_performance(performance);
            validate_weight(weight);
            
            // Update fields
            miner_info.trust_score = trust_score;
            miner_info.last_performance = performance;
            miner_info.accumulated_rewards = miner_info.accumulated_rewards + reward;
            miner_info.weight = weight;
            miner_info.last_update_time = current_time;
            miner_info.last_active_time = current_time;
            
            // Update status if provided (0 means no change)
            if (status != 0) {
                validate_status(status);
                miner_info.status = status;
            };
            
            // Accumulate for event
            total_rewards = total_rewards + reward;
            total_performance = total_performance + performance;
            
            i = i + 1;
        };
        
        registry.last_update = current_time;
        
        // Emit batch event
        event::emit_event(&mut registry.batch_events, BatchUpdateEvent {
            update_type: string::utf8(b"miners"),
            updated_count: update_count,
            total_rewards_distributed: total_rewards,
            average_performance: if (update_count > 0) total_performance / update_count else 0,
            timestamp: current_time,
        });
    }
    
    /// Batch update multiple validators
    /// Uses separate vectors for each field to avoid complex struct parameters
    public entry fun batch_update_validators(
        admin: &signer,
        validator_addrs: vector<address>,
        trust_scores: vector<u64>,
        performances: vector<u64>,
        rewards: vector<u64>,
        weights: vector<u64>,
        statuses: vector<u64>, // 0 = no change, 1 = active, 2 = inactive, etc.
    ) acquires GlobalRegistry {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == ADMIN_ADDRESS, E_NOT_ADMIN);
        
        // Validate all vectors have the same length
        let update_count = vector::length(&validator_addrs);
        assert!(update_count > 0 && update_count <= MAX_BATCH_SIZE, E_BATCH_SIZE_EXCEEDED);
        assert!(vector::length(&trust_scores) == update_count, E_INVALID_PARAMS);
        assert!(vector::length(&performances) == update_count, E_INVALID_PARAMS);
        assert!(vector::length(&rewards) == update_count, E_INVALID_PARAMS);
        assert!(vector::length(&weights) == update_count, E_INVALID_PARAMS);
        assert!(vector::length(&statuses) == update_count, E_INVALID_PARAMS);
        
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        let current_time = timestamp::now_microseconds();
        
        let total_rewards = 0u64;
        let total_performance = 0u64;
        let i = 0;
        
        while (i < update_count) {
            let validator_addr = *vector::borrow(&validator_addrs, i);
            let trust_score = *vector::borrow(&trust_scores, i);
            let performance = *vector::borrow(&performances, i);
            let reward = *vector::borrow(&rewards, i);
            let weight = *vector::borrow(&weights, i);
            let status = *vector::borrow(&statuses, i);
            
            assert!(smart_table::contains(&registry.validators, validator_addr), E_NOT_REGISTERED);
            
            let validator_info = smart_table::borrow_mut(&mut registry.validators, validator_addr);
            
            // Validate inputs
            validate_trust_score(trust_score);
            validate_performance(performance);
            validate_weight(weight);
            
            // Update fields
            validator_info.trust_score = trust_score;
            validator_info.last_performance = performance;
            validator_info.accumulated_rewards = validator_info.accumulated_rewards + reward;
            validator_info.weight = weight;
            validator_info.last_update_time = current_time;
            validator_info.last_active_time = current_time;
            
            // Update status if provided (0 means no change)
            if (status != 0) {
                validate_status(status);
                validator_info.status = status;
            };
            
            // Accumulate for event
            total_rewards = total_rewards + reward;
            total_performance = total_performance + performance;
            
            i = i + 1;
        };
        
        registry.last_update = current_time;
        
        // Emit batch event
        event::emit_event(&mut registry.batch_events, BatchUpdateEvent {
            update_type: string::utf8(b"validators"),
            updated_count: update_count,
            total_rewards_distributed: total_rewards,
            average_performance: if (update_count > 0) total_performance / update_count else 0,
            timestamp: current_time,
        });
    }

    // ==================== SLASHING FUNCTIONS ====================
    
    /// Slash a misbehaving validator
    public entry fun slash_validator(
        admin: &signer,
        validator_addr: address,
        slash_percentage: u64, // Percentage * 1e6 (e.g., 10% = 10000000)
        reason: String,
    ) acquires GlobalRegistry {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == ADMIN_ADDRESS, E_NOT_ADMIN);
        assert!(slash_percentage <= 100000000, E_INVALID_PARAMS); // Max 100%
        
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.validators, validator_addr), E_NOT_REGISTERED);
        
        let validator_info = smart_table::borrow_mut(&mut registry.validators, validator_addr);
        assert!(validator_info.status != STATUS_SLASHED, E_SLASHING_NOT_ALLOWED);
        
        // Calculate slash amount
        let slash_amount = (validator_info.stake * slash_percentage) / 100000000;
        
        // Update validator
        validator_info.slashed_amount = validator_info.slashed_amount + slash_amount;
        validator_info.stake = validator_info.stake - slash_amount;
        validator_info.status = STATUS_SLASHED;
        validator_info.consecutive_failures = validator_info.consecutive_failures + 1;
        validator_info.last_update_time = timestamp::now_microseconds();
        
        // Update global stake
        registry.total_stake = registry.total_stake - slash_amount;
        registry.last_update = timestamp::now_microseconds();
        
        // Emit slash event
        event::emit_event(&mut registry.slash_events, SlashEvent {
            node_type: string::utf8(b"validator"),
            node_address: validator_addr,
            subnet_uid: validator_info.subnet_uid,
            slashed_amount: slash_amount,
            reason,
            timestamp: timestamp::now_microseconds(),
        });
    }
    
    /// Slash a misbehaving miner
    public entry fun slash_miner(
        admin: &signer,
        miner_addr: address,
        slash_percentage: u64,
        reason: String,
    ) acquires GlobalRegistry {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == ADMIN_ADDRESS, E_NOT_ADMIN);
        assert!(slash_percentage <= 100000000, E_INVALID_PARAMS);
        
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.miners, miner_addr), E_NOT_REGISTERED);
        
        let miner_info = smart_table::borrow_mut(&mut registry.miners, miner_addr);
        assert!(miner_info.status != STATUS_SLASHED, E_SLASHING_NOT_ALLOWED);
        
        // Calculate slash amount
        let slash_amount = (miner_info.stake * slash_percentage) / 100000000;
        
        // Update miner
        miner_info.slashed_amount = miner_info.slashed_amount + slash_amount;
        miner_info.stake = miner_info.stake - slash_amount;
        miner_info.status = STATUS_SLASHED;
        miner_info.consecutive_failures = miner_info.consecutive_failures + 1;
        miner_info.tasks_failed = miner_info.tasks_failed + 1;
        miner_info.last_update_time = timestamp::now_microseconds();
        
        // Update global stake
        registry.total_stake = registry.total_stake - slash_amount;
        registry.last_update = timestamp::now_microseconds();
        
        // Emit slash event
        event::emit_event(&mut registry.slash_events, SlashEvent {
            node_type: string::utf8(b"miner"),
            node_address: miner_addr,
            subnet_uid: miner_info.subnet_uid,
            slashed_amount: slash_amount,
            reason,
            timestamp: timestamp::now_microseconds(),
        });
    }

    // ==================== VIEW FUNCTIONS ====================
    
    /// Get paginated validators for large scale queries
    #[view]
    public fun get_validators_paginated(start: u64, limit: u64): vector<ValidatorInfo> acquires GlobalRegistry {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        let result = vector::empty<ValidatorInfo>();
        let count = 0u64;
        let processed = 0u64;
        
        // Iterate through smart table (note: order not guaranteed)
        // In practice, you might want to maintain ordered lists for pagination
        let active_validators = &registry.active_validators;
        let total = vector::length(active_validators);
        
        let i = start;
        while (i < total && count < limit) {
            let addr = *vector::borrow(active_validators, i);
            if (smart_table::contains(&registry.validators, addr)) {
                let validator_info = *smart_table::borrow(&registry.validators, addr);
                vector::push_back(&mut result, validator_info);
                count = count + 1;
            };
            i = i + 1;
        };
        
        result
    }
    
    /// Get paginated miners
    #[view]
    public fun get_miners_paginated(start: u64, limit: u64): vector<MinerInfo> acquires GlobalRegistry {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        let result = vector::empty<MinerInfo>();
        let count = 0u64;
        
        let active_miners = &registry.active_miners;
        let total = vector::length(active_miners);
        
        let i = start;
        while (i < total && count < limit) {
            let addr = *vector::borrow(active_miners, i);
            if (smart_table::contains(&registry.miners, addr)) {
                let miner_info = *smart_table::borrow(&registry.miners, addr);
                vector::push_back(&mut result, miner_info);
                count = count + 1;
            };
            i = i + 1;
        };
        
        result
    }
    
    /// Get subnet information
    #[view]
    public fun get_subnet_info(subnet_uid: u64): SubnetInfo acquires GlobalRegistry {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.subnets, subnet_uid), E_INVALID_SUBNET);
        *smart_table::borrow(&registry.subnets, subnet_uid)
    }
    
    /// Get all subnet UIDs
    #[view]
    public fun get_all_subnet_uids(): vector<u64> acquires GlobalRegistry {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        // Note: SmartTable doesn't provide direct key iteration
        // You might want to maintain a separate vector of subnet UIDs
        vector::empty<u64>() // Simplified for now
    }
    
    /// Get enhanced network statistics
    #[view]
    public fun get_enhanced_network_stats(): (u64, u64, u64, u64, u64, u64) acquires GlobalRegistry {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        (
            registry.total_validators,
            registry.total_miners,
            registry.total_subnets,
            registry.total_stake,
            vector::length(&registry.active_validators),
            vector::length(&registry.active_miners)
        )
    }
    
    /// Check if validator exists
    #[view]
    public fun validator_exists(addr: address): bool acquires GlobalRegistry {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        smart_table::contains(&registry.validators, addr)
    }
    
    /// Check if miner exists
    #[view]
    public fun miner_exists(addr: address): bool acquires GlobalRegistry {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        smart_table::contains(&registry.miners, addr)
    }
    
    /// Get validator info
    #[view]
    public fun get_validator_info(validator_addr: address): ValidatorInfo acquires GlobalRegistry {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.validators, validator_addr), E_NOT_REGISTERED);
        *smart_table::borrow(&registry.validators, validator_addr)
    }
    
    /// Get miner info
    #[view]
    public fun get_miner_info(miner_addr: address): MinerInfo acquires GlobalRegistry {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.miners, miner_addr), E_NOT_REGISTERED);
        *smart_table::borrow(&registry.miners, miner_addr)
    }
    
    /// Get validators by subnet (paginated)
    #[view]
    public fun get_validators_by_subnet_paginated(
        subnet_uid: u64,
        start: u64,
        limit: u64
    ): vector<ValidatorInfo> acquires GlobalRegistry {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.validators_by_subnet, subnet_uid), E_INVALID_SUBNET);
        
        let subnet_validators = smart_table::borrow(&registry.validators_by_subnet, subnet_uid);
        let result = vector::empty<ValidatorInfo>();
        let total = vector::length(subnet_validators);
        let count = 0u64;
        
        let i = start;
        while (i < total && count < limit) {
            let addr = *vector::borrow(subnet_validators, i);
            if (smart_table::contains(&registry.validators, addr)) {
                let validator_info = *smart_table::borrow(&registry.validators, addr);
                vector::push_back(&mut result, validator_info);
                count = count + 1;
            };
            i = i + 1;
        };
        
        result
    }
    
    /// Get miners by subnet (paginated)
    #[view]
    public fun get_miners_by_subnet_paginated(
        subnet_uid: u64,
        start: u64,
        limit: u64
    ): vector<MinerInfo> acquires GlobalRegistry {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.miners_by_subnet, subnet_uid), E_INVALID_SUBNET);
        
        let subnet_miners = smart_table::borrow(&registry.miners_by_subnet, subnet_uid);
        let result = vector::empty<MinerInfo>();
        let total = vector::length(subnet_miners);
        let count = 0u64;
        
        let i = start;
        while (i < total && count < limit) {
            let addr = *vector::borrow(subnet_miners, i);
            if (smart_table::contains(&registry.miners, addr)) {
                let miner_info = *smart_table::borrow(&registry.miners, addr);
                vector::push_back(&mut result, miner_info);
                count = count + 1;
            };
            i = i + 1;
        };
        
        result
    }
    
    // ==================== DEREGISTRATION FUNCTIONS ====================
    
    /// Deregister validator (with penalty if early)
    public entry fun deregister_validator(
        validator: &signer,
        subnet_uid: u64,
    ) acquires GlobalRegistry, Treasury {
        let validator_addr = signer::address_of(validator);
        let current_time = timestamp::now_microseconds();
        
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.validators, validator_addr), E_NOT_REGISTERED);
        
        // Get validator info and save needed values before removal
        let validator_info = smart_table::borrow(&registry.validators, validator_addr);
        assert!(validator_info.subnet_uid == subnet_uid, E_INVALID_SUBNET);
        
        // Check if stake is locked
        assert!(!is_stake_locked(validator_info.stake_locked_until), E_STAKE_LOCKED);
        
        // Check if in immunity period (cannot deregister during immunity)
        assert!(!is_in_immunity_period(validator_info.immunity_until), E_IMMUNITY_PERIOD_ACTIVE);
        
        // Save values before removal
        let validator_stake = validator_info.stake;
        let validator_bond = validator_info.validator_bond;
        let validator_status = validator_info.status;
        let validator_uid = validator_info.uid;
        let validator_trust_score = validator_info.trust_score;
        
        // Update subnet info
        let subnet_info = smart_table::borrow_mut(&mut registry.subnets, subnet_uid);
        subnet_info.validator_count = subnet_info.validator_count - 1;
        subnet_info.total_stake = subnet_info.total_stake - validator_stake;
        subnet_info.last_update = current_time;
        
        // Update global stats
        registry.total_validators = registry.total_validators - 1;
        registry.total_stake = registry.total_stake - validator_stake;
        registry.last_update = current_time;
        
        // Remove from indices
        let subnet_validators = smart_table::borrow_mut(&mut registry.validators_by_subnet, subnet_uid);
        let (found, index) = vector::index_of(subnet_validators, &validator_addr);
        if (found) {
            vector::remove(subnet_validators, index);
        };
        
        let (found_active, active_index) = vector::index_of(&registry.active_validators, &validator_addr);
        if (found_active) {
            vector::remove(&mut registry.active_validators, active_index);
        };
        
        // Remove validator
        smart_table::remove(&mut registry.validators, validator_addr);
        
        // Return validator bond (if not slashed)
        let treasury = borrow_global_mut<Treasury>(ADMIN_ADDRESS);
        if (validator_status != STATUS_SLASHED) {
            // Note: In production, bond would be returned from contract's treasury
            treasury.validator_bonds_locked = treasury.validator_bonds_locked - validator_bond;
        };
        
        // Emit event
        event::emit_event(&mut registry.validator_events, ValidatorEvent {
            event_type: string::utf8(b"deregistered"),
            validator_address: validator_addr,
            uid: validator_uid,
            subnet_uid,
            old_status: validator_status,
            new_status: STATUS_INACTIVE,
            stake: validator_stake,
            trust_score: validator_trust_score,
            timestamp: current_time,
        });
    }
    
    /// Deregister miner
    public entry fun deregister_miner(
        miner: &signer,
        subnet_uid: u64,
    ) acquires GlobalRegistry {
        let miner_addr = signer::address_of(miner);
        let current_time = timestamp::now_microseconds();
        
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.miners, miner_addr), E_NOT_REGISTERED);
        
        // Get miner info and save needed values before removal
        let miner_info = smart_table::borrow(&registry.miners, miner_addr);
        assert!(miner_info.subnet_uid == subnet_uid, E_INVALID_SUBNET);
        
        // Check if stake is locked
        assert!(!is_stake_locked(miner_info.stake_locked_until), E_STAKE_LOCKED);
        
        // Check if in immunity period
        assert!(!is_in_immunity_period(miner_info.immunity_until), E_IMMUNITY_PERIOD_ACTIVE);
        
        // Save values before removal
        let miner_stake = miner_info.stake;
        let miner_status = miner_info.status;
        let miner_uid = miner_info.uid;
        let miner_trust_score = miner_info.trust_score;
        
        // Update subnet info
        let subnet_info = smart_table::borrow_mut(&mut registry.subnets, subnet_uid);
        subnet_info.miner_count = subnet_info.miner_count - 1;
        subnet_info.total_stake = subnet_info.total_stake - miner_stake;
        subnet_info.last_update = current_time;
        
        // Update global stats
        registry.total_miners = registry.total_miners - 1;
        registry.total_stake = registry.total_stake - miner_stake;
        registry.last_update = current_time;
        
        // Remove from indices
        let subnet_miners = smart_table::borrow_mut(&mut registry.miners_by_subnet, subnet_uid);
        let (found, index) = vector::index_of(subnet_miners, &miner_addr);
        if (found) {
            vector::remove(subnet_miners, index);
        };
        
        let (found_active, active_index) = vector::index_of(&registry.active_miners, &miner_addr);
        if (found_active) {
            vector::remove(&mut registry.active_miners, active_index);
        };
        
        // Remove miner
        smart_table::remove(&mut registry.miners, miner_addr);
        
        // Emit event
        event::emit_event(&mut registry.miner_events, MinerEvent {
            event_type: string::utf8(b"deregistered"),
            miner_address: miner_addr,
            uid: miner_uid,
            subnet_uid,
            old_status: miner_status,
            new_status: STATUS_INACTIVE,
            stake: miner_stake,
            trust_score: miner_trust_score,
            timestamp: current_time,
        });
    }
    
    // ==================== STAKE MANAGEMENT FUNCTIONS ====================
    
    /// Add stake to validator
    public entry fun add_validator_stake(
        validator: &signer,
        additional_stake: u64,
    ) acquires GlobalRegistry {
        let validator_addr = signer::address_of(validator);
        let current_time = timestamp::now_microseconds();
        
        assert!(additional_stake >= MIN_STAKE, E_INSUFFICIENT_STAKE);
        
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.validators, validator_addr), E_NOT_REGISTERED);
        
        let validator_info = smart_table::borrow_mut(&mut registry.validators, validator_addr);
        assert!(validator_info.status == STATUS_ACTIVE, E_INVALID_STATUS);
        
        // Check total stake doesn't exceed max
        assert!(validator_info.stake + additional_stake <= MAX_STAKE, E_INSUFFICIENT_STAKE);
        
        // Transfer stake
        let apt_metadata = get_apt_metadata();
        primary_fungible_store::transfer(validator, apt_metadata, ADMIN_ADDRESS, additional_stake);
        
        // Update validator info
        validator_info.stake = validator_info.stake + additional_stake;
        validator_info.last_update_time = current_time;
        validator_info.last_active_time = current_time;
        
        // Update subnet info
        let subnet_info = smart_table::borrow_mut(&mut registry.subnets, validator_info.subnet_uid);
        subnet_info.total_stake = subnet_info.total_stake + additional_stake;
        subnet_info.last_update = current_time;
        
        // Update global stats
        registry.total_stake = registry.total_stake + additional_stake;
        registry.last_update = current_time;
        
        // Emit event
        event::emit_event(&mut registry.validator_events, ValidatorEvent {
            event_type: string::utf8(b"stake_added"),
            validator_address: validator_addr,
            uid: validator_info.uid,
            subnet_uid: validator_info.subnet_uid,
            old_status: validator_info.status,
            new_status: validator_info.status,
            stake: validator_info.stake,
            trust_score: validator_info.trust_score,
            timestamp: current_time,
        });
    }
    
    /// Add stake to miner
    public entry fun add_miner_stake(
        miner: &signer,
        additional_stake: u64,
    ) acquires GlobalRegistry {
        let miner_addr = signer::address_of(miner);
        let current_time = timestamp::now_microseconds();
        
        assert!(additional_stake >= MIN_STAKE, E_INSUFFICIENT_STAKE);
        
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.miners, miner_addr), E_NOT_REGISTERED);
        
        let miner_info = smart_table::borrow_mut(&mut registry.miners, miner_addr);
        assert!(miner_info.status == STATUS_ACTIVE, E_INVALID_STATUS);
        
        // Check total stake doesn't exceed max
        assert!(miner_info.stake + additional_stake <= MAX_STAKE, E_INSUFFICIENT_STAKE);
        
        // Transfer stake
        let apt_metadata = get_apt_metadata();
        primary_fungible_store::transfer(miner, apt_metadata, ADMIN_ADDRESS, additional_stake);
        
        // Update miner info
        miner_info.stake = miner_info.stake + additional_stake;
        miner_info.last_update_time = current_time;
        miner_info.last_active_time = current_time;
        
        // Update subnet info
        let subnet_info = smart_table::borrow_mut(&mut registry.subnets, miner_info.subnet_uid);
        subnet_info.total_stake = subnet_info.total_stake + additional_stake;
        subnet_info.last_update = current_time;
        
        // Update global stats
        registry.total_stake = registry.total_stake + additional_stake;
        registry.last_update = current_time;
        
        // Emit event
        event::emit_event(&mut registry.miner_events, MinerEvent {
            event_type: string::utf8(b"stake_added"),
            miner_address: miner_addr,
            uid: miner_info.uid,
            subnet_uid: miner_info.subnet_uid,
            old_status: miner_info.status,
            new_status: miner_info.status,
            stake: miner_info.stake,
            trust_score: miner_info.trust_score,
            timestamp: current_time,
        });
    }
    
    /// Withdraw stake from validator (with lock period)
    public entry fun withdraw_validator_stake(
        validator: &signer,
        withdraw_amount: u64,
    ) acquires GlobalRegistry {
        let validator_addr = signer::address_of(validator);
        let current_time = timestamp::now_microseconds();
        
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.validators, validator_addr), E_NOT_REGISTERED);
        
        let validator_info = smart_table::borrow_mut(&mut registry.validators, validator_addr);
        
        // Check if stake is locked
        assert!(!is_stake_locked(validator_info.stake_locked_until), E_STAKE_LOCKED);
        
        // Check minimum stake requirement
        assert!(validator_info.stake - withdraw_amount >= MIN_STAKE, E_INSUFFICIENT_STAKE);
        
        // Note: In production, stake would be transferred back from contract's treasury
        // For now, we just update the records
        
        // Update validator info
        validator_info.stake = validator_info.stake - withdraw_amount;
        validator_info.last_update_time = current_time;
        validator_info.stake_locked_until = current_time + STAKE_LOCK_PERIOD; // Reset lock period
        
        // Update subnet info
        let subnet_info = smart_table::borrow_mut(&mut registry.subnets, validator_info.subnet_uid);
        subnet_info.total_stake = subnet_info.total_stake - withdraw_amount;
        subnet_info.last_update = current_time;
        
        // Update global stats
        registry.total_stake = registry.total_stake - withdraw_amount;
        registry.last_update = current_time;
        
        // Emit event
        event::emit_event(&mut registry.validator_events, ValidatorEvent {
            event_type: string::utf8(b"stake_withdrawn"),
            validator_address: validator_addr,
            uid: validator_info.uid,
            subnet_uid: validator_info.subnet_uid,
            old_status: validator_info.status,
            new_status: validator_info.status,
            stake: validator_info.stake,
            trust_score: validator_info.trust_score,
            timestamp: current_time,
        });
    }
    
    /// Withdraw stake from miner (with lock period)
    public entry fun withdraw_miner_stake(
        miner: &signer,
        withdraw_amount: u64,
    ) acquires GlobalRegistry {
        let miner_addr = signer::address_of(miner);
        let current_time = timestamp::now_microseconds();
        
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.miners, miner_addr), E_NOT_REGISTERED);
        
        let miner_info = smart_table::borrow_mut(&mut registry.miners, miner_addr);
        
        // Check if stake is locked
        assert!(!is_stake_locked(miner_info.stake_locked_until), E_STAKE_LOCKED);
        
        // Check minimum stake requirement
        assert!(miner_info.stake - withdraw_amount >= MIN_STAKE, E_INSUFFICIENT_STAKE);
        
        // Note: In production, stake would be transferred back from contract's treasury
        // For now, we just update the records
        
        // Update miner info
        miner_info.stake = miner_info.stake - withdraw_amount;
        miner_info.last_update_time = current_time;
        miner_info.stake_locked_until = current_time + STAKE_LOCK_PERIOD; // Reset lock period
        
        // Update subnet info
        let subnet_info = smart_table::borrow_mut(&mut registry.subnets, miner_info.subnet_uid);
        subnet_info.total_stake = subnet_info.total_stake - withdraw_amount;
        subnet_info.last_update = current_time;
        
        // Update global stats
        registry.total_stake = registry.total_stake - withdraw_amount;
        registry.last_update = current_time;
        
        // Emit event
        event::emit_event(&mut registry.miner_events, MinerEvent {
            event_type: string::utf8(b"stake_withdrawn"),
            miner_address: miner_addr,
            uid: miner_info.uid,
            subnet_uid: miner_info.subnet_uid,
            old_status: miner_info.status,
            new_status: miner_info.status,
            stake: miner_info.stake,
            trust_score: miner_info.trust_score,
            timestamp: current_time,
        });
    }
    
    // ==================== GOVERNANCE FUNCTIONS ====================
    
    /// Update global parameters (admin only)
    public entry fun update_global_params(
        admin: &signer,
        min_validator_stake: u64,
        min_miner_stake: u64,
        max_validators_global: u64,
        max_miners_global: u64,
    ) acquires GlobalRegistry {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == ADMIN_ADDRESS, E_NOT_ADMIN);
        
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        
        // Validate parameters
        assert!(min_validator_stake >= MIN_STAKE, E_INVALID_PARAMS);
        assert!(min_miner_stake >= MIN_STAKE, E_INVALID_PARAMS);
        assert!(max_validators_global > 0, E_INVALID_PARAMS);
        assert!(max_miners_global > 0, E_INVALID_PARAMS);
        
        // Update parameters
        registry.min_validator_stake = min_validator_stake;
        registry.min_miner_stake = min_miner_stake;
        registry.max_validators_global = max_validators_global;
        registry.max_miners_global = max_miners_global;
        registry.last_update = timestamp::now_microseconds();
    }
    
    /// Update subnet parameters (admin only)
    public entry fun update_subnet_params(
        admin: &signer,
        subnet_uid: u64,
        max_validators: u64,
        max_miners: u64,
        min_stake_validator: u64,
        min_stake_miner: u64,
        validator_permits_required: bool,
    ) acquires GlobalRegistry {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == ADMIN_ADDRESS, E_NOT_ADMIN);
        
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.subnets, subnet_uid), E_INVALID_SUBNET);
        
        let subnet_info = smart_table::borrow_mut(&mut registry.subnets, subnet_uid);
        
        // Validate parameters
        assert!(max_validators > 0, E_INVALID_PARAMS);
        assert!(max_miners > 0, E_INVALID_PARAMS);
        assert!(min_stake_validator >= MIN_STAKE, E_INVALID_PARAMS);
        assert!(min_stake_miner >= MIN_STAKE, E_INVALID_PARAMS);
        
        // Update parameters
        subnet_info.max_validators = max_validators;
        subnet_info.max_miners = max_miners;
        subnet_info.min_stake_validator = min_stake_validator;
        subnet_info.min_stake_miner = min_stake_miner;
        subnet_info.validator_permits_required = validator_permits_required;
        subnet_info.last_update = timestamp::now_microseconds();
        
        // Emit event
        event::emit_event(&mut registry.subnet_events, SubnetEvent {
            event_type: string::utf8(b"updated"),
            subnet_uid,
            name: subnet_info.name,
            validator_count: subnet_info.validator_count,
            miner_count: subnet_info.miner_count,
            total_stake: subnet_info.total_stake,
            timestamp: timestamp::now_microseconds(),
        });
    }
    
    /// Disable permit requirement for a subnet (admin only)
    public entry fun disable_subnet_permit_requirement(
        admin: &signer,
        subnet_uid: u64,
    ) acquires GlobalRegistry {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == ADMIN_ADDRESS, E_NOT_ADMIN);
        
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.subnets, subnet_uid), E_INVALID_SUBNET);
        
        let subnet_info = smart_table::borrow_mut(&mut registry.subnets, subnet_uid);
        subnet_info.validator_permits_required = false;
        subnet_info.last_update = timestamp::now_microseconds();
        
        // Emit event
        event::emit_event(&mut registry.subnet_events, SubnetEvent {
            event_type: string::utf8(b"permit_disabled"),
            subnet_uid,
            name: subnet_info.name,
            validator_count: subnet_info.validator_count,
            miner_count: subnet_info.miner_count,
            total_stake: subnet_info.total_stake,
            timestamp: timestamp::now_microseconds(),
        });
    }
    
    /// Activate or deactivate subnet (admin only)
    public entry fun set_subnet_status(
        admin: &signer,
        subnet_uid: u64,
        is_active: bool,
    ) acquires GlobalRegistry {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == ADMIN_ADDRESS, E_NOT_ADMIN);
        
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.subnets, subnet_uid), E_INVALID_SUBNET);
        
        let subnet_info = smart_table::borrow_mut(&mut registry.subnets, subnet_uid);
        subnet_info.is_active = is_active;
        subnet_info.last_update = timestamp::now_microseconds();
        
        // Emit event
        event::emit_event(&mut registry.subnet_events, SubnetEvent {
            event_type: if (is_active) string::utf8(b"activated") else string::utf8(b"deactivated"),
            subnet_uid,
            name: subnet_info.name,
            validator_count: subnet_info.validator_count,
            miner_count: subnet_info.miner_count,
            total_stake: subnet_info.total_stake,
            timestamp: timestamp::now_microseconds(),
        });
    }
    
    // ==================== EMERGENCY FUNCTIONS ====================
    
    /// Emergency pause (admin only)
    public entry fun emergency_pause(
        admin: &signer,
    ) acquires GlobalRegistry {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == ADMIN_ADDRESS, E_NOT_ADMIN);
        
        // Implementation would add a global pause state
        // For now, we just update the last_update timestamp
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        registry.last_update = timestamp::now_microseconds();
    }
    
    /// Emergency unpause (admin only)
    public entry fun emergency_unpause(
        admin: &signer,
    ) acquires GlobalRegistry {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == ADMIN_ADDRESS, E_NOT_ADMIN);
        
        // Implementation would remove the global pause state
        // For now, we just update the last_update timestamp
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        registry.last_update = timestamp::now_microseconds();
    }
    
    // ==================== REWARD DISTRIBUTION FUNCTIONS ====================
    
    /// Distribute rewards to validators and miners (admin only)
    public entry fun distribute_rewards(
        admin: &signer,
        subnet_uid: u64,
        total_reward_amount: u64,
        validator_reward_percentage: u64, // Percentage * 1e8
    ) acquires GlobalRegistry {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == ADMIN_ADDRESS, E_NOT_ADMIN);
        assert!(validator_reward_percentage <= 100000000, E_INVALID_PARAMS); // Max 100%
        
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.subnets, subnet_uid), E_INVALID_SUBNET);
        
        let subnet_info = smart_table::borrow(&registry.subnets, subnet_uid);
        assert!(subnet_info.is_active, E_INVALID_SUBNET);
        
        // Calculate reward splits
        let validator_rewards = (total_reward_amount * validator_reward_percentage) / 100000000;
        let miner_rewards = total_reward_amount - validator_rewards;
        
        // Distribute to validators
        if (validator_rewards > 0 && subnet_info.validator_count > 0) {
            let reward_per_validator = validator_rewards / subnet_info.validator_count;
            let subnet_validators = smart_table::borrow(&registry.validators_by_subnet, subnet_uid);
            let i = 0;
            let len = vector::length(subnet_validators);
            
            while (i < len) {
                let validator_addr = *vector::borrow(subnet_validators, i);
                if (smart_table::contains(&registry.validators, validator_addr)) {
                    let validator_info = smart_table::borrow_mut(&mut registry.validators, validator_addr);
                    validator_info.accumulated_rewards = validator_info.accumulated_rewards + reward_per_validator;
                };
                i = i + 1;
            };
        };
        
        // Distribute to miners
        if (miner_rewards > 0 && subnet_info.miner_count > 0) {
            let reward_per_miner = miner_rewards / subnet_info.miner_count;
            let subnet_miners = smart_table::borrow(&registry.miners_by_subnet, subnet_uid);
            let i = 0;
            let len = vector::length(subnet_miners);
            
            while (i < len) {
                let miner_addr = *vector::borrow(subnet_miners, i);
                if (smart_table::contains(&registry.miners, miner_addr)) {
                    let miner_info = smart_table::borrow_mut(&mut registry.miners, miner_addr);
                    miner_info.accumulated_rewards = miner_info.accumulated_rewards + reward_per_miner;
                };
                i = i + 1;
            };
        };
        
        registry.last_update = timestamp::now_microseconds();
    }
    
    /// Claim accumulated rewards
    public entry fun claim_rewards(
        account: &signer,
        node_type: String, // "validator" or "miner"
    ) acquires GlobalRegistry {
        let account_addr = signer::address_of(account);
        let current_time = timestamp::now_microseconds();
        
        let registry = borrow_global_mut<GlobalRegistry>(ADMIN_ADDRESS);
        let reward_amount = 0u64;
        
        if (node_type == string::utf8(b"validator")) {
            assert!(smart_table::contains(&registry.validators, account_addr), E_NOT_REGISTERED);
            let validator_info = smart_table::borrow_mut(&mut registry.validators, account_addr);
            reward_amount = validator_info.accumulated_rewards;
            validator_info.accumulated_rewards = 0;
            validator_info.last_update_time = current_time;
        } else if (node_type == string::utf8(b"miner")) {
            assert!(smart_table::contains(&registry.miners, account_addr), E_NOT_REGISTERED);
            let miner_info = smart_table::borrow_mut(&mut registry.miners, account_addr);
            reward_amount = miner_info.accumulated_rewards;
            miner_info.accumulated_rewards = 0;
            miner_info.last_update_time = current_time;
        };
        
        // Note: In production, rewards would be transferred from contract's reward pool
        // For now, we just update the records and reset accumulated rewards
    }
    
    // ==================== ECONOMIC CONSTRAINT VIEW FUNCTIONS ====================
    
    /// Get treasury statistics
    #[view]
    public fun get_treasury_stats(): (u64, u64, u64, u64, u64, u64) acquires Treasury {
        let treasury = borrow_global<Treasury>(ADMIN_ADDRESS);
        (
            treasury.total_burned,
            treasury.total_fees_collected,
            treasury.registration_fees_collected,
            treasury.validator_bonds_locked,
            treasury.subnet_creation_fees,
            treasury.recycling_rewards_paid
        )
    }
    
    /// Check if validator has valid permit
    #[view]
    public fun check_validator_permit(validator_addr: address, subnet_uid: u64): bool acquires ValidatorPermit {
        has_valid_permit(validator_addr, subnet_uid)
    }
    
    /// Get validator permit info
    #[view]
    public fun get_validator_permit(validator_addr: address): ValidatorPermit acquires ValidatorPermit {
        assert!(exists<ValidatorPermit>(validator_addr), E_NOT_REGISTERED);
        *borrow_global<ValidatorPermit>(validator_addr)
    }
    
    /// Check registration cooldown
    #[view]
    public fun check_registration_cooldown_status(addr: address): (bool, u64) acquires RegistrationCooldown {
        let current_time = timestamp::now_microseconds();
        if (exists<RegistrationCooldown>(addr)) {
            let cooldown = borrow_global<RegistrationCooldown>(addr);
            (current_time >= cooldown.cooldown_until, cooldown.cooldown_until)
        } else {
            (true, 0)
        }
    }
    
    /// Check if node is recyclable
    #[view]
    public fun check_recyclable_status(node_addr: address, node_type: String): (bool, u64) acquires GlobalRegistry {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        let current_time = timestamp::now_microseconds();
        
        if (node_type == string::utf8(b"validator")) {
            if (smart_table::contains(&registry.validators, node_addr)) {
                let validator_info = smart_table::borrow(&registry.validators, node_addr);
                let recyclable = is_recyclable(validator_info.last_active_time) && 
                                !is_in_immunity_period(validator_info.immunity_until);
                (recyclable, validator_info.recycling_eligible_at)
            } else {
                (false, 0)
            }
        } else if (node_type == string::utf8(b"miner")) {
            if (smart_table::contains(&registry.miners, node_addr)) {
                let miner_info = smart_table::borrow(&registry.miners, node_addr);
                let recyclable = is_recyclable(miner_info.last_active_time) && 
                                !is_in_immunity_period(miner_info.immunity_until);
                (recyclable, miner_info.recycling_eligible_at)
            } else {
                (false, 0)
            }
        } else {
            (false, 0)
        }
    }
    
    /// Get economic summary for a subnet
    #[view]
    public fun get_subnet_economic_summary(subnet_uid: u64): (u64, u64, u64, u64, bool) acquires GlobalRegistry {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.subnets, subnet_uid), E_INVALID_SUBNET);
        
        let subnet_info = smart_table::borrow(&registry.subnets, subnet_uid);
        let total_registration_fees = 
            (subnet_info.validator_count * VALIDATOR_REGISTRATION_FEE) +
            (subnet_info.miner_count * MINER_REGISTRATION_FEE);
        
        (
            subnet_info.creation_fee_paid,
            total_registration_fees,
            subnet_info.total_stake,
            subnet_info.validator_count + subnet_info.miner_count,
            subnet_info.validator_permits_required
        )
    }
    
    /// Get all active validator permits
    #[view]
    public fun get_active_validator_permits(): vector<address> acquires GlobalRegistry, ValidatorPermit {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        let result = vector::empty<address>();
        let current_time = timestamp::now_microseconds();
        
        // Note: This is a simplified version. In practice, you'd want to maintain
        // a separate registry of all permits for efficient querying
        let active_validators = &registry.active_validators;
        let i = 0;
        let len = vector::length(active_validators);
        
        while (i < len) {
            let addr = *vector::borrow(active_validators, i);
            if (exists<ValidatorPermit>(addr)) {
                let permit = borrow_global<ValidatorPermit>(addr);
                if (permit.is_active && current_time < permit.expires_at) {
                    vector::push_back(&mut result, addr);
                };
            };
            i = i + 1;
        };
        
        result
    }
    
    /// Get registration fee requirements
    #[view]
    public fun get_registration_fee_info(): (u64, u64, u64, u64, u64) {
        (
            MINER_REGISTRATION_FEE,
            VALIDATOR_REGISTRATION_FEE,
            MIN_VALIDATOR_BOND,
            VALIDATOR_PERMIT_PRICE,
            SUBNET_CREATION_FEE
        )
    }
    
    /// Get immunity and cooldown periods
    #[view]
    public fun get_time_constraints(): (u64, u64, u64, u64, u64) {
        (
            REGISTRATION_COOLDOWN,
            IMMUNITY_PERIOD,
            RECYCLE_PERIOD,
            WEIGHT_SETTING_COOLDOWN,
            VALIDATOR_PERMIT_COOLDOWN
        )
    }
    
    /// Get detailed subnet statistics
    #[view]
    public fun get_subnet_detailed_stats(subnet_uid: u64): (u64, u64, u64, u64, u64, u64, bool, bool) acquires GlobalRegistry {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        assert!(smart_table::contains(&registry.subnets, subnet_uid), E_INVALID_SUBNET);
        
        let subnet_info = smart_table::borrow(&registry.subnets, subnet_uid);
        (
            subnet_info.validator_count,
            subnet_info.miner_count,
            subnet_info.max_validators,
            subnet_info.max_miners,
            subnet_info.total_stake,
            subnet_info.creation_fee_paid,
            subnet_info.is_active,
            subnet_info.validator_permits_required
        )
    }
    
    /// Get node performance summary
    #[view]
    public fun get_node_performance_summary(node_addr: address, node_type: String): (u64, u64, u64, u64, u64, u64) acquires GlobalRegistry {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        
        if (node_type == string::utf8(b"validator")) {
            assert!(smart_table::contains(&registry.validators, node_addr), E_NOT_REGISTERED);
            let validator_info = smart_table::borrow(&registry.validators, node_addr);
            (
                validator_info.trust_score,
                validator_info.last_performance,
                validator_info.accumulated_rewards,
                validator_info.slashed_amount,
                validator_info.consecutive_failures,
                validator_info.weight
            )
        } else if (node_type == string::utf8(b"miner")) {
            assert!(smart_table::contains(&registry.miners, node_addr), E_NOT_REGISTERED);
            let miner_info = smart_table::borrow(&registry.miners, node_addr);
            (
                miner_info.trust_score,
                miner_info.last_performance,
                miner_info.accumulated_rewards,
                miner_info.slashed_amount,
                miner_info.consecutive_failures,
                miner_info.weight
            )
        } else {
            (0, 0, 0, 0, 0, 0)
        }
    }
    
    /// Get stake information for a node
    #[view]
    public fun get_node_stake_info(node_addr: address, node_type: String): (u64, u64, u64, bool) acquires GlobalRegistry {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        
        if (node_type == string::utf8(b"validator")) {
            assert!(smart_table::contains(&registry.validators, node_addr), E_NOT_REGISTERED);
            let validator_info = smart_table::borrow(&registry.validators, node_addr);
            (
                validator_info.stake,
                validator_info.validator_bond,
                validator_info.stake_locked_until,
                is_stake_locked(validator_info.stake_locked_until)
            )
        } else if (node_type == string::utf8(b"miner")) {
            assert!(smart_table::contains(&registry.miners, node_addr), E_NOT_REGISTERED);
            let miner_info = smart_table::borrow(&registry.miners, node_addr);
            (
                miner_info.stake,
                0, // miners don't have bonds
                miner_info.stake_locked_until,
                is_stake_locked(miner_info.stake_locked_until)
            )
        } else {
            (0, 0, 0, false)
        }
    }
    
    /// Get economic parameters
    #[view]
    public fun get_economic_parameters(): (u64, u64, u64, u64, u64, u64, u64, u64, u64, u64) {
        (
            MINER_REGISTRATION_FEE,
            VALIDATOR_REGISTRATION_FEE,
            VALIDATOR_BOND_AMOUNT,
            SUBNET_CREATION_FEE,
            MIN_VALIDATOR_BOND,
            MAX_VALIDATOR_BOND,
            VALIDATOR_PERMIT_PRICE,
            RECYCLING_REWARD,
            BURN_PERCENTAGE,
            STAKE_LOCK_PERIOD
        )
    }
    
    /// Check if address is registered as any node type
    #[view]
    public fun is_registered(addr: address): (bool, String) acquires GlobalRegistry {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        
        if (smart_table::contains(&registry.validators, addr)) {
            (true, string::utf8(b"validator"))
        } else if (smart_table::contains(&registry.miners, addr)) {
            (true, string::utf8(b"miner"))
        } else {
            (false, string::utf8(b"none"))
        }
    }
    
    /// Get node registration time and active status
    #[view]
    public fun get_node_time_info(node_addr: address, node_type: String): (u64, u64, u64, bool) acquires GlobalRegistry {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        
        if (node_type == string::utf8(b"validator")) {
            assert!(smart_table::contains(&registry.validators, node_addr), E_NOT_REGISTERED);
            let validator_info = smart_table::borrow(&registry.validators, node_addr);
            (
                validator_info.registration_time,
                validator_info.last_active_time,
                validator_info.immunity_until,
                is_in_immunity_period(validator_info.immunity_until)
            )
        } else if (node_type == string::utf8(b"miner")) {
            assert!(smart_table::contains(&registry.miners, node_addr), E_NOT_REGISTERED);
            let miner_info = smart_table::borrow(&registry.miners, node_addr);
            (
                miner_info.registration_time,
                miner_info.last_active_time,
                miner_info.immunity_until,
                is_in_immunity_period(miner_info.immunity_until)
            )
        } else {
            (0, 0, 0, false)
        }
    }
    
    /// Get network health metrics
    #[view]
    public fun get_network_health_metrics(): (u64, u64, u64, u64, u64, u64) acquires GlobalRegistry, Treasury {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        let treasury = borrow_global<Treasury>(ADMIN_ADDRESS);
        
        // Calculate uptime percentage (simplified - in reality would need more complex calculation)
        let total_nodes = registry.total_validators + registry.total_miners;
        let active_nodes = vector::length(&registry.active_validators) + vector::length(&registry.active_miners);
        let uptime_percentage = if (total_nodes > 0) (active_nodes * 100) / total_nodes else 0;
        
        (
            registry.total_stake,
            treasury.total_fees_collected,
            treasury.total_burned,
            uptime_percentage,
            registry.total_subnets,
            registry.last_update
        )
    }
    
    /// Check if validator can transfer to a subnet
    #[view]
    public fun can_validator_transfer_subnet(validator_addr: address, target_subnet_uid: u64): (bool, String) acquires GlobalRegistry, ValidatorPermit {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        
        // Check if validator exists
        if (!smart_table::contains(&registry.validators, validator_addr)) {
            return (false, string::utf8(b"validator_not_registered"))
        };
        
        let validator_info = smart_table::borrow(&registry.validators, validator_addr);
        
        // Check if already in target subnet
        if (validator_info.subnet_uid == target_subnet_uid) {
            return (false, string::utf8(b"already_in_subnet"))
        };
        
        // Check if target subnet exists
        if (!smart_table::contains(&registry.subnets, target_subnet_uid)) {
            return (false, string::utf8(b"subnet_not_found"))
        };
        
        let subnet_info = smart_table::borrow(&registry.subnets, target_subnet_uid);
        
        // Check if subnet is active
        if (!subnet_info.is_active) {
            return (false, string::utf8(b"subnet_inactive"))
        };
        
        // Check subnet limits
        if (subnet_info.validator_count >= subnet_info.max_validators) {
            return (false, string::utf8(b"subnet_full"))
        };
        
        // Check stake requirements
        if (validator_info.stake < subnet_info.min_stake_validator) {
            return (false, string::utf8(b"insufficient_stake"))
        };
        
        // Check permit requirements
        if (subnet_info.validator_permits_required && validator_addr != ADMIN_ADDRESS) {
            if (!has_valid_permit(validator_addr, target_subnet_uid)) {
                return (false, string::utf8(b"permit_required"))
            };
        };
        
        // Check cooldown
        if (is_stake_locked(validator_info.stake_locked_until)) {
            return (false, string::utf8(b"stake_locked"))
        };
        
        // Check immunity period
        if (is_in_immunity_period(validator_info.immunity_until)) {
            return (false, string::utf8(b"immunity_period"))
        };
        
        (true, string::utf8(b"can_transfer"))
    }
    
    /// Check if miner can transfer to a subnet
    #[view]
    public fun can_miner_transfer_subnet(miner_addr: address, target_subnet_uid: u64): (bool, String) acquires GlobalRegistry {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        
        // Check if miner exists
        if (!smart_table::contains(&registry.miners, miner_addr)) {
            return (false, string::utf8(b"miner_not_registered"))
        };
        
        let miner_info = smart_table::borrow(&registry.miners, miner_addr);
        
        // Check if already in target subnet
        if (miner_info.subnet_uid == target_subnet_uid) {
            return (false, string::utf8(b"already_in_subnet"))
        };
        
        // Check if target subnet exists
        if (!smart_table::contains(&registry.subnets, target_subnet_uid)) {
            return (false, string::utf8(b"subnet_not_found"))
        };
        
        let subnet_info = smart_table::borrow(&registry.subnets, target_subnet_uid);
        
        // Check if subnet is active
        if (!subnet_info.is_active) {
            return (false, string::utf8(b"subnet_inactive"))
        };
        
        // Check subnet limits
        if (subnet_info.miner_count >= subnet_info.max_miners) {
            return (false, string::utf8(b"subnet_full"))
        };
        
        // Check stake requirements
        if (miner_info.stake < subnet_info.min_stake_miner) {
            return (false, string::utf8(b"insufficient_stake"))
        };
        
        // Check cooldown
        if (is_stake_locked(miner_info.stake_locked_until)) {
            return (false, string::utf8(b"stake_locked"))
        };
        
        // Check immunity period
        if (is_in_immunity_period(miner_info.immunity_until)) {
            return (false, string::utf8(b"immunity_period"))
        };
        
        (true, string::utf8(b"can_transfer"))
    }
    
    /// Get all subnets a validator can transfer to
    #[view]
    public fun get_available_subnets_for_validator(validator_addr: address): vector<u64> acquires GlobalRegistry {
        let registry = borrow_global<GlobalRegistry>(ADMIN_ADDRESS);
        let result = vector::empty<u64>();
        
        // Check if validator exists
        if (!smart_table::contains(&registry.validators, validator_addr)) {
            return result
        };
        
        // Note: SmartTable doesn't provide iteration, so we would need to maintain
        // a separate list of subnet UIDs. For simplicity, we return empty vector.
        // In practice, you would iterate through all known subnet UIDs.
        
        result
    }
} 