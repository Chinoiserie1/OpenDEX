// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOpenDexPair} from '../interface/IOpenDexPair.sol';
import '../OpenDexPair.sol';

import {IDENTICAL_ADDRESS, ADDRESS_ZERO} from './OpenDexFactoryConstants.sol';

library RouterLibrary {
  function initHash() internal pure returns (bytes32) {
    // initcode = 0x40cb58066ce06698b5de8929bb09b2415945f6d911cfaf2afa96e9aae3e86c3c
    bytes memory bytecode = type(OpenDexPair).creationCode;
    return keccak256(abi.encodePacked(bytecode));
  }

  function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
    assembly {
      if eq(tokenA, tokenB) {
        mstore(0x00, IDENTICAL_ADDRESS)
        revert(0x00, 0x04)
      }
      token0 := tokenA
      token1 := tokenB
      if gt(tokenA, tokenB) {
        token0 := tokenB
        token1 := tokenA
      }
      if iszero(token0) {
        mstore(0x00, ADDRESS_ZERO)
        revert(0x00, 0x04)
      }
    }
  }

  // create2 = keccak256(0xff ++ address ++ salt ++ keccak256(bytecode))
  function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
    (address token0, address token1) = sortTokens(tokenA, tokenB);
    assembly {
      let free_ptr := mload(0x40) // load free memory ptr
      // no need to store length because we dont use it
      mstore(add(free_ptr, 0x28), token1)
      mstore(add(free_ptr, 0x14), token0)
      let salt := keccak256(add(free_ptr, 0x20), 0x28)
      let ptr := add(free_ptr, 0x60)
      mstore(add(ptr, 0x40), 0x40cb58066ce06698b5de8929bb09b2415945f6d911cfaf2afa96e9aae3e86c3c)
      mstore(add(ptr, 0x20), salt)
      mstore(ptr, factory)
      let start := add(ptr, 0x0b)
      mstore8(start, 0xff)
      pair := shr(0x60, shl(0x60, keccak256(start, 85))) // change first 24 bit to zero
      mstore(0x40, add(free_ptr, 0xC0)) // store new free memory ptr
    }
  }

  function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
    (address token0,) = sortTokens(tokenA, tokenB);
    (uint reserve0, uint reserve1,) = IOpenDexPair(pairFor(factory, tokenA, tokenB)).getReserves();
    (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
  }

  function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
    assembly {
      function safeMul(x, y) -> z {
        z := mul(x, y)
        if lt(z, x) {
          mstore(0x00, OVERFLOW)
          revert(0x00, 0x04)
        }
      }
      if iszero(amountA) {
        // error INSUFFICIENT_AMOUNT
        revert(0, 0)
      }
      if or(iszero(reserveA), iszero(reserveB)) {
        // error INSUFFICIENT_LIQUIDITY
        revert(0, 0)
      }
      amountB := div(safeMul(amountA, reserveB), reserveA)
    }
  }

  function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
    assembly {
      function safeMul(x, y) -> z {
        z := mul(x, y)
        if lt(z, x) {
          mstore(0x00, OVERFLOW)
          revert(0x00, 0x04)
        }
      }
      function safeAdd(x, y) -> z {
        z := add(x, y)
        if lt(z, x) {
          mstore(0x00, OVERFLOW)
          revert(0x00, 0x04)
        }
      }

      if iszero(amountIn) {
        // error INSUFFICIENT_INPUT_AMOUNT
        revert(0, 0)
      }
      if or(iszero(reserveIn), iszero(reserveOut)) {
        // error INSUFFICIENT_LIQUIDITY
        revert(0, 0)
      }
      let amountInWithFee := safeMul(amountIn, 997)
      let numerator := safeMul(amountInWithFee, reserveOut)
      let denominator := safeAdd(safeMul(reserveIn, 1000), amountInWithFee)
      amountOut := div(numerator, denominator)
    }
  }

  function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
    assembly {
      function safeMul(x, y) -> z {
        z := mul(x, y)
        if lt(z, x) {
          mstore(0x00, OVERFLOW)
          revert(0x00, 0x04)
        }
      }
      function safeSub(x, y) -> z {
        z := sub(x, y)
        if gt(z, x) {
          mstore(0x00, UNDERFLOW)
          revert(0x00, 0x04)
        }
      }

      if iszero(amountOut) {
        // error INSUFFICIENT_OUTPUT_AMOUNT
        revert(0, 0)
      }
      if or(iszero(reserveIn), iszero(reserveOut)) {
        // error INSUFFICIENT_LIQUIDITY
        revert(0, 0)
      }
      let numerator := safeMul(safeMul(reserveIn, amountOut), 1000)
      let denominator := safeMul(safeSub(reserveOut, amountOut), 997)
      amountIn := add(div(numerator, denominator), 1)
    }
  }
}