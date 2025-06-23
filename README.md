# Stacklet

A decentralized liquidity pool manager built on the Stacks blockchain using Clarity smart contracts.

## Overview

Stacklet is a smart contract that enables users to create and manage token liquidity pools, add/remove liquidity, and perform token swaps with automated market maker (AMM) functionality.

## Features

- **Pool Creation**: Create new liquidity pools for token pairs
- **Liquidity Management**: Add and remove liquidity from pools
- **Token Swapping**: Swap tokens using constant product formula
- **Fee Structure**: Built-in 0.3% trading fee
- **Access Control**: Owner-only pool creation with public trading

## Contract Functions

### Administrative Functions
- `create-pool`: Create a new liquidity pool (owner only)
- `get-contract-owner`: View current contract owner

### Pool Management
- `add-liquidity`: Add liquidity to an existing pool
- `remove-liquidity`: Remove liquidity from a pool
- `get-pool`: View pool information
- `get-user-liquidity`: Check user's liquidity position

### Trading Functions
- `swap-x-for-y`: Swap token X for token Y
- `swap-y-for-x`: Swap token Y for token X
- `calculate-swap`: Calculate swap output amount

## Usage

1. Deploy the contract to Stacks blockchain
2. Create liquidity pools using `create-pool`
3. Users can add liquidity with `add-liquidity`
4. Users can trade tokens using swap functions
5. Liquidity providers can withdraw using `remove-liquidity`

## Error Codes

- `ERR_NOT_AUTHORIZED (u1)`: Caller not authorized
- `ERR_INSUFFICIENT_BALANCE (u2)`: Insufficient balance
- `ERR_POOL_ALREADY_EXISTS (u3)`: Pool already exists
- `ERR_POOL_DOES_NOT_EXIST (u4)`: Pool does not exist
- `ERR_ZERO_AMOUNTS (u5)`: Zero amounts not allowed

## License

MIT License

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Disclaimer

This contract is for educational purposes. Audit thoroughly before mainnet deployment.