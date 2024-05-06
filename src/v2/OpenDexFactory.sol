// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console2} from "forge-std/Test.sol";

import {IOpenDexFactory} from "./interface/IOpenDexFactory.sol";
import {IOpenDexPair} from './interface/IOpenDexPair.sol';
import {OpenDexPair} from './OpenDexPair.sol';

error IdenticalAddress();
error AddressZero();
error PairExist();

bytes32 constant IDENTICAL_ADDRESS = 0x065af08d00000000000000000000000000000000000000000000000000000000;
bytes32 constant ADDRESS_ZERO = 0x9fabe1c100000000000000000000000000000000000000000000000000000000;
bytes32 constant PAIR_EXIST = 0x148ea71200000000000000000000000000000000000000000000000000000000;

bytes32 constant INITIALIZE_SELECTOR = 0x485cc95500000000000000000000000000000000000000000000000000000000;

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
    feeToSetter = _feeToSetter;
  }

  function allPairsLength() external view returns (uint256) {
    uint256 length;
    assembly {
      length := sload(allPairs.slot)
    }
    return length;
  }

  function createPair(address tokenA, address tokenB) external returns (address pair) {
    require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
    (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
    require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient
    bytes memory bytecode = type(OpenDexPair).creationCode;
    bytes32 salt = keccak256(abi.encodePacked(token0, token1));
    assembly {
      pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
    }
    IOpenDexPair(pair).initialize(token0, token1);
    getPair[token0][token1] = pair;
    getPair[token1][token0] = pair; // populate mapping in the reverse direction
    allPairs.push(pair);
    emit PairCreated(token0, token1, pair, allPairs.length);
  }

  function createPairA(address tokenA, address tokenB) external returns (address pair) {
    bytes memory bytecode = type(OpenDexPair).creationCode;
    bytes32 log;
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
    }
    console2.logBytes32(log);
  }

  function setFeeTo(address _feeTo) external {
    require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
    feeTo = _feeTo;
  }

  function setFeeToSetter(address _feeToSetter) external {
    require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
    feeToSetter = _feeToSetter;
  }
}