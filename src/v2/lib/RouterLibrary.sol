// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
      pair := keccak256(start, 85)
      mstore(0x40, add(free_ptr, 0xA0)) // store new free memory ptr
    }
  }
}