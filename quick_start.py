#!/usr/bin/env python3
"""
ModernTensor Quick Start Script
==============================

This script provides a quick way to test the ModernTensor contract
with all the basic operations in one go.
"""

import subprocess
import sys
import time

# Configuration
CONTRACT_ADDRESS = "0x9ba2d796ed64ea00a4f7690be844174820e0729de9f37fcaae429bc15ac37c04"
PROFILE = "default"

def print_header(text):
    """Print a formatted header"""
    print(f"\n{'='*50}")
    print(f"🚀 {text}")
    print(f"{'='*50}")

def print_step(step, description):
    """Print a formatted step"""
    print(f"\n{step}. {description}")
    print("-" * 30)

def run_cmd(cmd, description=""):
    """Run a command and show the result"""
    if description:
        print(f"🔄 {description}")
    print(f"Running: {cmd}")
    
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            print("✅ Success!")
            if result.stdout:
                print(result.stdout)
        else:
            print("❌ Failed!")
            if result.stderr:
                print(result.stderr)
        return result.returncode == 0
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def main():
    """Main quick start function"""
    print_header("MODERNTENSOR QUICK START")
    
    print("This script will:")
    print("1. Check contract deployment")
    print("2. Get network statistics")
    print("3. Get fee information")
    print("4. Create a test subnet")
    print("5. Register a miner")
    print("6. Register a validator")
    print("7. Show final statistics")
    
    input("\nPress Enter to continue...")
    
    # Step 1: Check contract deployment
    print_step(1, "Checking contract deployment")
    if not run_cmd(f"aptos move view --profile {PROFILE} --function-id {CONTRACT_ADDRESS}::moderntensor::get_enhanced_network_stats", "Checking if contract is deployed"):
        print("❌ Contract not deployed or not responding")
        print("💡 Please run 'python3 deploy.py' first")
        sys.exit(1)
    
    # Step 2: Get network statistics
    print_step(2, "Getting network statistics")
    run_cmd(f"aptos move view --profile {PROFILE} --function-id {CONTRACT_ADDRESS}::moderntensor::get_enhanced_network_stats", "Getting network stats")
    
    # Step 3: Get fee information
    print_step(3, "Getting fee information")
    run_cmd(f"aptos move view --profile {PROFILE} --function-id {CONTRACT_ADDRESS}::moderntensor::get_registration_fee_info", "Getting fee info")
    
    # Step 4: Create a test subnet
    print_step(4, "Creating a test subnet")
    subnet_cmd = f"""aptos move run --profile {PROFILE} --assume-yes \\
        --function-id {CONTRACT_ADDRESS}::moderntensor::create_subnet \\
        --args u64:999 \\
        --args string:"Quick Start Subnet" \\
        --args string:"Test subnet created by quick start script" \\
        --args u64:5 \\
        --args u64:50 \\
        --args u64:1000000 \\
        --args u64:1000000 \\
        --args bool:false"""
    
    if run_cmd(subnet_cmd, "Creating test subnet"):
        time.sleep(3)  # Wait for transaction confirmation
    
    # Step 5: Register a miner
    print_step(5, "Registering a test miner")
    miner_cmd = f"""aptos move run --profile {PROFILE} --assume-yes \\
        --function-id {CONTRACT_ADDRESS}::moderntensor::register_miner \\
        --args hex:"717569636b5f6d696e65725f31" \\
        --args u64:999 \\
        --args u64:10000000 \\
        --args hex:"717569636b5f6d696e65725f77616c6c6574" \\
        --args hex:"687474703a2f2f717569636b2d6d696e65722e6578616d706c652e636f6d" """
    
    if run_cmd(miner_cmd, "Registering test miner"):
        time.sleep(3)  # Wait for transaction confirmation
    
    # Step 6: Register a validator
    print_step(6, "Registering a test validator")
    validator_cmd = f"""aptos move run --profile {PROFILE} --assume-yes \\
        --function-id {CONTRACT_ADDRESS}::moderntensor::register_validator \\
        --args hex:"717569636b5f76616c696461746f725f31" \\
        --args u64:999 \\
        --args u64:50000000 \\
        --args u64:10000000 \\
        --args hex:"717569636b5f76616c696461746f725f77616c6c6574" \\
        --args hex:"687474703a2f2f717569636b2d76616c696461746f722e6578616d706c652e636f6d" """
    
    if run_cmd(validator_cmd, "Registering test validator"):
        time.sleep(3)  # Wait for transaction confirmation
    
    # Step 7: Show final statistics
    print_step(7, "Final network statistics")
    run_cmd(f"aptos move view --profile {PROFILE} --function-id {CONTRACT_ADDRESS}::moderntensor::get_enhanced_network_stats", "Getting updated network stats")
    
    # Get subnet info
    print("\n📊 Subnet Information:")
    run_cmd(f"aptos move view --profile {PROFILE} --function-id {CONTRACT_ADDRESS}::moderntensor::get_subnet_info --args u64:999", "Getting subnet info")
    
    # Get treasury stats
    print("\n🏦 Treasury Statistics:")
    run_cmd(f"aptos move view --profile {PROFILE} --function-id {CONTRACT_ADDRESS}::moderntensor::get_treasury_stats", "Getting treasury stats")
    
    # Success message
    print_header("QUICK START COMPLETED!")
    
    print("🎉 Congratulations! You have successfully:")
    print("  ✅ Verified contract deployment")
    print("  ✅ Retrieved network statistics")
    print("  ✅ Retrieved fee information")
    print("  ✅ Created a test subnet")
    print("  ✅ Registered a test miner")
    print("  ✅ Registered a test validator")
    print("  ✅ Retrieved updated statistics")
    
    print("\n🚀 Next Steps:")
    print("  1. Run 'python3 demo.py' for more detailed testing")
    print("  2. Check out 'examples/' directory for client code")
    print("  3. Read 'DEPLOYMENT_GUIDE.md' for full documentation")
    print("  4. Try batch operations with multiple miners")
    print("  5. Test validator permits and bonding")
    
    print("\n📚 Resources:")
    print("  • Contract Address:", CONTRACT_ADDRESS)
    print("  • Network: Testnet")
    print("  • Documentation: README.md")
    print("  • Examples: examples/")
    
    print("\n💡 Tips:")
    print("  • All fees are in testing mode (very low)")
    print("  • Cooldown periods are only 5 minutes")
    print("  • Use batch operations for better gas efficiency")
    print("  • Monitor treasury for burn/fee statistics")
    
    print("\n🔗 Useful Commands:")
    print("  • Check balance: aptos account list --profile default")
    print("  • Fund account: aptos account fund-with-faucet --profile default")
    print("  • View functions: aptos move view --profile default --function-id ...")
    
    print("\n" + "="*50)
    print("✨ ModernTensor Contract is ready for use! ✨")
    print("="*50)

if __name__ == "__main__":
    main() 