# Open DEX

Open Dex is a simple ERC20 decentralized exchange, this repository is for educational purpose and it's not audited.

## Structure

Open Dex is composed of 2 contracts.

- **OpenDexFactory:** This contract consist to create liquidity pool (OpenDexPair), and keep track of it.
- **OpenDexPair:** This contract consist of the logic of the decentralized exchange.

## Usage

### OpenDexFactory

- **createPair()** take 2 parameters, addresses of the pair token (token A & token B).
- **getPair()** take 2 parameters, addresses of the pair token (token A & token B) and return address of the pair contract.

### OpenDexPair

### Adding Liquidity

- **addLiquidity(amountA, amountB)**

  - **Parameters:**
    - `amountA`: The amount of token A to deposit as liquidity.
    - `amountB`: The amount of token B to deposit as liquidity.
  - **Description**: Deposit `amountA` of token A and `amountB` of token B to the liquidity pool to add liquidity. Upon successful deposit, the user receives liquidity tokens corresponding to their share in the pool.
  - **Returns**: The number of liquidity tokens issued to the depositor.

### Removing Liquidity

- **removeLiquidity(liquidityTokens)**
  - **Parameters:**
    - `liquidityTokens`: The amount of liquidity tokens to redeem.
  - **Description**: Redeem your `liquidityTokens` to withdraw a proportional amount of token A and token B from the liquidity pool. The amounts received are calculated based on the current liquidity and the pricing algorithm of the pool.
  - **Returns**: The amounts of token A and token B received from the liquidity pool.

#### Swapping tokens

- **swap(amountToSend, tokenA, tokenB)**
  - **Parameters:**
    - `amount0In`: The amount of token A.
    - `amount1In`: The amount of token B.
  - **Description**: Use this function to swap, The amount of token received is calculated based on the liquidity and current price in the pool for these tokens.
  - **Returns**: The amount of token received from the swap.

## Installation and Setup

```bash
git clone https://github.com/Chinoiserie1/OpenDEX.git
cd OpenDEX
forge install
```

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
