#!/usr/bin/env python3
"""
ModernTensor Python Client Example
=================================

This example shows how to interact with the ModernTensor contract
using Python and the Aptos SDK.
"""

import asyncio
import json
import time
from typing import Dict, List, Optional, Tuple
from aptos_sdk.client import RestClient
from aptos_sdk.account import Account
from aptos_sdk.transactions import (
    EntryFunction,
    TransactionArgument,
    TransactionPayload,
    Serializer,
)
from aptos_sdk.type_tag import TypeTag, StructTag

# Configuration
NODE_URL = "https://fullnode.testnet.aptoslabs.com"
CONTRACT_ADDRESS = "0x9ba2d796ed64ea00a4f7690be844174820e0729de9f37fcaae429bc15ac37c04"

class ModernTensorClient:
    """
    Python client for interacting with the ModernTensor smart contract
    """
    
    def __init__(self, private_key: Optional[str] = None):
        """
        Initialize the client
        
        Args:
            private_key: Optional private key in hex format. If None, creates new account
        """
        self.client = RestClient(NODE_URL)
        self.account = Account.load_key(private_key) if private_key else Account.generate()
        self.contract_address = CONTRACT_ADDRESS
    
    def get_address(self) -> str:
        """Get account address"""
        return str(self.account.address())
    
    def get_private_key(self) -> str:
        """Get private key for backup"""
        return self.account.private_key.hex()
    
    async def get_balance(self) -> int:
        """Get account APT balance"""
        try:
            balance = self.client.account_balance(self.account.address())
            return balance
        except Exception as e:
            print(f"Error fetching balance: {e}")
            return 0
    
    async def get_network_stats(self) -> Dict:
        """Get network statistics"""
        try:
            result = self.client.view(
                f"{self.contract_address}::moderntensor::get_enhanced_network_stats",
                [],
                []
            )
            
            return {
                "total_validators": result[0],
                "total_miners": result[1],
                "total_subnets": result[2],
                "total_stake": result[3],
                "active_validators": result[4],
                "active_miners": result[5]
            }
        except Exception as e:
            print(f"Error fetching network stats: {e}")
            raise
    
    async def get_fee_info(self) -> Dict:
        """Get fee information"""
        try:
            result = self.client.view(
                f"{self.contract_address}::moderntensor::get_registration_fee_info",
                [],
                []
            )
            
            return {
                "miner_fee": result[0],
                "validator_fee": result[1],
                "subnet_fee": result[2],
                "permit_fee": result[3]
            }
        except Exception as e:
            print(f"Error fetching fee info: {e}")
            raise
    
    async def get_treasury_stats(self) -> Dict:
        """Get treasury statistics"""
        try:
            result = self.client.view(
                f"{self.contract_address}::moderntensor::get_treasury_stats",
                [],
                []
            )
            
            return {
                "total_burned": result[0],
                "total_treasury_fees": result[1],
                "total_registrations": result[2],
                "total_permits": result[3]
            }
        except Exception as e:
            print(f"Error fetching treasury stats: {e}")
            raise
    
    async def get_subnet_info(self, subnet_id: int) -> Dict:
        """Get subnet information"""
        try:
            result = self.client.view(
                f"{self.contract_address}::moderntensor::get_subnet_info",
                [subnet_id],
                []
            )
            
            return {
                "subnet_id": result[0],
                "name": result[1],
                "description": result[2],
                "max_validators": result[3],
                "max_miners": result[4],
                "current_validators": result[5],
                "current_miners": result[6]
            }
        except Exception as e:
            print(f"Error fetching subnet info: {e}")
            raise
    
    async def create_subnet(
        self,
        subnet_id: int,
        name: str,
        description: str,
        max_validators: int,
        max_miners: int,
        min_stake_validator: int,
        min_stake_miner: int,
        permits_required: bool = False
    ) -> str:
        """Create a new subnet"""
        try:
            payload = EntryFunction.natural(
                f"{self.contract_address}::moderntensor",
                "create_subnet",
                [],
                [
                    TransactionArgument(subnet_id, Serializer.u64),
                    TransactionArgument(name, Serializer.str),
                    TransactionArgument(description, Serializer.str),
                    TransactionArgument(max_validators, Serializer.u64),
                    TransactionArgument(max_miners, Serializer.u64),
                    TransactionArgument(min_stake_validator, Serializer.u64),
                    TransactionArgument(min_stake_miner, Serializer.u64),
                    TransactionArgument(permits_required, Serializer.bool),
                ]
            )
            
            signed_txn = self.client.create_bcs_signed_transaction(
                self.account, TransactionPayload(payload)
            )
            
            tx_hash = self.client.submit_bcs_transaction(signed_txn)
            self.client.wait_for_transaction(tx_hash)
            
            print(f"✅ Subnet {subnet_id} created successfully")
            return tx_hash
            
        except Exception as e:
            print(f"❌ Error creating subnet: {e}")
            raise
    
    async def register_miner(
        self,
        uid: str,
        subnet_id: int,
        stake: int,
        wallet_hash: str,
        api_endpoint: str
    ) -> str:
        """Register as a miner"""
        try:
            payload = EntryFunction.natural(
                f"{self.contract_address}::moderntensor",
                "register_miner",
                [],
                [
                    TransactionArgument(uid.encode(), Serializer.bytes),
                    TransactionArgument(subnet_id, Serializer.u64),
                    TransactionArgument(stake, Serializer.u64),
                    TransactionArgument(wallet_hash.encode(), Serializer.bytes),
                    TransactionArgument(api_endpoint.encode(), Serializer.bytes),
                ]
            )
            
            signed_txn = self.client.create_bcs_signed_transaction(
                self.account, TransactionPayload(payload)
            )
            
            tx_hash = self.client.submit_bcs_transaction(signed_txn)
            self.client.wait_for_transaction(tx_hash)
            
            print(f"✅ Miner {uid} registered successfully")
            return tx_hash
            
        except Exception as e:
            print(f"❌ Error registering miner: {e}")
            raise
    
    async def register_validator(
        self,
        uid: str,
        subnet_id: int,
        stake: int,
        bond: int,
        wallet_hash: str,
        api_endpoint: str
    ) -> str:
        """Register as a validator"""
        try:
            payload = EntryFunction.natural(
                f"{self.contract_address}::moderntensor",
                "register_validator",
                [],
                [
                    TransactionArgument(uid.encode(), Serializer.bytes),
                    TransactionArgument(subnet_id, Serializer.u64),
                    TransactionArgument(stake, Serializer.u64),
                    TransactionArgument(bond, Serializer.u64),
                    TransactionArgument(wallet_hash.encode(), Serializer.bytes),
                    TransactionArgument(api_endpoint.encode(), Serializer.bytes),
                ]
            )
            
            signed_txn = self.client.create_bcs_signed_transaction(
                self.account, TransactionPayload(payload)
            )
            
            tx_hash = self.client.submit_bcs_transaction(signed_txn)
            self.client.wait_for_transaction(tx_hash)
            
            print(f"✅ Validator {uid} registered successfully")
            return tx_hash
            
        except Exception as e:
            print(f"❌ Error registering validator: {e}")
            raise
    
    async def purchase_validator_permit(self, subnet_id: int) -> str:
        """Purchase validator permit"""
        try:
            payload = EntryFunction.natural(
                f"{self.contract_address}::moderntensor",
                "purchase_validator_permit",
                [],
                [TransactionArgument(subnet_id, Serializer.u64)]
            )
            
            signed_txn = self.client.create_bcs_signed_transaction(
                self.account, TransactionPayload(payload)
            )
            
            tx_hash = self.client.submit_bcs_transaction(signed_txn)
            self.client.wait_for_transaction(tx_hash)
            
            print(f"✅ Validator permit purchased for subnet {subnet_id}")
            return tx_hash
            
        except Exception as e:
            print(f"❌ Error purchasing validator permit: {e}")
            raise


async def main():
    """Main demo function"""
    print("🚀 ModernTensor Python Client Demo")
    print("=" * 40)
    
    # Create client
    client = ModernTensorClient()
    
    print(f"📍 Account Address: {client.get_address()}")
    print(f"🔑 Private Key: {client.get_private_key()}")
    
    try:
        # Get network stats
        print("\n📊 Network Statistics:")
        stats = await client.get_network_stats()
        print(f"- Total Validators: {stats['total_validators']}")
        print(f"- Total Miners: {stats['total_miners']}")
        print(f"- Total Subnets: {stats['total_subnets']}")
        print(f"- Total Stake: {stats['total_stake']}")
        
        # Get fee info
        print("\n💰 Fee Information:")
        fee_info = await client.get_fee_info()
        print(f"- Miner Fee: {fee_info['miner_fee']} APT")
        print(f"- Validator Fee: {fee_info['validator_fee']} APT")
        print(f"- Subnet Fee: {fee_info['subnet_fee']} APT")
        print(f"- Permit Fee: {fee_info['permit_fee']} APT")
        
        # Get treasury stats
        print("\n🏦 Treasury Statistics:")
        treasury_stats = await client.get_treasury_stats()
        print(f"- Total Burned: {treasury_stats['total_burned']}")
        print(f"- Total Treasury Fees: {treasury_stats['total_treasury_fees']}")
        print(f"- Total Registrations: {treasury_stats['total_registrations']}")
        
        # Check balance
        balance = await client.get_balance()
        print(f"\n💰 Account Balance: {balance} APT")
        
        if balance < 100000000:  # 1 APT
            print("⚠️ Low balance! Fund your account with testnet APT:")
            print(f"aptos account fund-with-faucet --account {client.get_address()}")
            return
        
        # Example operations (uncomment to test)
        
        # Create subnet
        # await client.create_subnet(
        #     subnet_id=2,
        #     name="Python Test Subnet",
        #     description="Created by Python client",
        #     max_validators=5,
        #     max_miners=50,
        #     min_stake_validator=1000000,
        #     min_stake_miner=1000000
        # )
        
        # Register miner
        # await client.register_miner(
        #     uid="python_miner_1",
        #     subnet_id=1,
        #     stake=10000000,
        #     wallet_hash="python_wallet_hash",
        #     api_endpoint="http://python-miner.example.com"
        # )
        
        # Register validator
        # await client.register_validator(
        #     uid="python_validator_1",
        #     subnet_id=1,
        #     stake=50000000,
        #     bond=10000000,
        #     wallet_hash="python_validator_wallet_hash",
        #     api_endpoint="http://python-validator.example.com"
        # )
        
        print("\n🎉 Demo completed successfully!")
        print("💡 Uncomment the operations above to test transactions")
        
    except Exception as e:
        print(f"❌ Error: {e}")


if __name__ == "__main__":
    asyncio.run(main()) 