// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IOpenDexPairError {
  error Overflow();
  error Underflow();
  error InvalidCaller();
  error InsufficientLiquidity();
  error InsufficientLiquidityMint();
  error InsufficientLiquidityBurn();
  error InsufficientInputAmount();
  error InsufficientOutputAmount();
  error InvalidTo();
  error InvalidVariableK();
}