// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './lib/RouterLibrary.sol';

bytes32 constant GET_PAIR_SELECTOR = 0xe6a4390500000000000000000000000000000000000000000000000000000000;
bytes32 constant CREATE_PAIR_SELECTOR = 0xc9c6539600000000000000000000000000000000000000000000000000000000;

contract OpenDexRouter {
  address factory;

  constructor(address _factory) {
    factory = _factory;
  }

  function _addLiquidity(
    address tokenA,
    address tokenB,
    uint256 amountADesired,
    uint256 amountBDesired,
    uint256 amountAMin,
    uint256 amountBMin
  ) internal virtual returns (uint256 amountA, uint256 amountB) {
    // create the pair if it doesn't exist yet
    assembly {
      // call getPair to check if a pair exist
      let slot0x40 := mload(0x40)
      mstore(0x00, GET_PAIR_SELECTOR)
      mstore(0x04, tokenA)
      mstore(0x24, tokenB)
      let callstatus := call(gas(), sload(factory.slot), 0, 0x00, 0x44, 0x00, 0x20)
      if iszero(callstatus) {
        revert(0x00, calldatasize())
      }
      // if no pair exist create one
      if iszero(mload(0x00)) {
        mstore(0x00, CREATE_PAIR_SELECTOR)
        mstore(0x04, tokenA)
        callstatus := call(gas(), sload(factory.slot), 0, 0x00, 0x44, 0x00, 0x20)
        if iszero(callstatus) {
          revert(0x00, calldatasize())
        }
      }
      // restore free memory ptr
      mstore(0x40, slot0x40)
    }
  }

  function addLiquidity(
    address tokenA,
    address tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
  ) external virtual returns (uint amountA, uint amountB, uint liquidity) {
    (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
    // bytes32 initcode = RouterLibrary.initHash();
    // console2.logBytes32(initcode);
    // console2.log(factory);
    // console2.log(RouterLibrary.pairFor(factory, tokenA, tokenB));
  }
}