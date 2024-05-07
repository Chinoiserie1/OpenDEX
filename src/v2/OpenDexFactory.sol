// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {INVALID_CALLER} from './lib/OpenDexConstants.sol';
import './lib/OpenDexFactoryConstants.sol';
import {IOpenDexFactory} from "./interface/IOpenDexFactory.sol";
import {IOpenDexPair} from './interface/IOpenDexPair.sol';
import {OpenDexPair} from './OpenDexPair.sol';

error IdenticalAddress();
error AddressZero();
error PairExist();
error InvalidCaller();

/**
 * @notice OpenDexFactory from UniswapV2 to convert in assembly
 * 
 * referance: https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Factory.sol
 */
contract OpenDexFactory is IOpenDexFactory {
  address public feeTo;
  address public feeToSetter;

  mapping(address => mapping(address => address)) public getPair;
  address[] public allPairs;

  constructor(address _feeToSetter) {
    assembly {
      sstore(feeToSetter.slot, _feeToSetter)
    }
  }

  function allPairsLength() external view returns (uint256) {
    uint256 length;
    assembly {
      length := sload(allPairs.slot)
    }
    return length;
  }

  function createPair(address tokenA, address tokenB) external returns (address pair) {
    bytes memory bytecode = type(OpenDexPair).creationCode;
    assembly {
      if eq(tokenA, tokenB) {
        mstore(0x00, IDENTICAL_ADDRESS)
        revert(0x00, 0x04)
      }
      let token0 := tokenA
      let token1 := tokenB
      if gt(tokenA, tokenB) {
        token0 := tokenB
        token1 := tokenA
      }
      if iszero(token0) {
        mstore(0x00, ADDRESS_ZERO)
        revert(0x00, 0x04)
      }
      // retrieve getPair
      mstore(0x00, token0)
      mstore(0x20, getPair.slot)
      mstore(0x20, keccak256(0x00, 0x40))
      mstore(0x00, token1)
      mstore(0x00, sload(keccak256(0x00, 0x40)))
      if gt(mload(0x00), 0) {
        mstore(0x00, PAIR_EXIST)
        revert(0x00, 0x04)
      }
      let free_ptr := mload(0x40) // load free memory ptr
      // no need to store length because we dont use it
      mstore(add(free_ptr, 0x28), token1)
      mstore(add(free_ptr, 0x14), token0)
      mstore(0x40, add(free_ptr, 0x60)) // store new free memory ptr
      let salt := keccak256(add(free_ptr, 0x20), 0x28)
      // create new pair
      pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
      // call initialize
      let slot0x40 := mload(0x40)
      mstore(0x00, INITIALIZE_SELECTOR)
      mstore(0x04, token0)
      mstore(0x24, token1)
      let callstatus := call(gas(), pair, 0, 0x00, 0x44, 0x00, 0x20)
      if iszero(callstatus) {
        revert(0x00, calldatasize())
      }
      mstore(0x40, slot0x40) // restore free memory ptr
      // populate mapping getPair
      mstore(0x00, token0)
      mstore(0x20, getPair.slot)
      mstore(0x20, keccak256(0x00, 0x40))
      mstore(0x00, token1)
      sstore(keccak256(0x00, 0x40), pair)
      mstore(0x00, token1)
      mstore(0x20, getPair.slot)
      mstore(0x20, keccak256(0x00, 0x40))
      mstore(0x00, token0)
      sstore(keccak256(0x00, 0x40), pair)
      // populate array allPair
      let length := sload(allPairs.slot)
      mstore(0x00, allPairs.slot)
      let array_ptr := keccak256(0x00, 0x20)
      sstore(add(array_ptr, length), pair)
      sstore(allPairs.slot, add(length, 1))
      // emit PairCreated
      mstore(0x00, pair)
      mstore(0x20, length)
      log3(0x00, 0x40, PAIR_CREATED_HASH, token0, token1)
    }
  }

  function setFeeTo(address _feeTo) external {
    assembly {
      if iszero(eq(caller(), sload(feeToSetter.slot))) {
        mstore(0x00, INVALID_CALLER)
        revert(0x00, 0x04)
      }
      sstore(feeTo.slot, _feeTo)
    }
  }

  function setFeeToSetter(address _feeToSetter) external {
    assembly {
      if iszero(eq(caller(), sload(feeToSetter.slot))) {
        mstore(0x00, INVALID_CALLER)
        revert(0x00, 0x04)
      }
      sstore(feeToSetter.slot, _feeToSetter)
    }
  }
}