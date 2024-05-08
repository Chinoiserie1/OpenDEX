// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './lib/RouterLibrary.sol';

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
    bytes32 initcode = RouterLibrary.initHash();
    // console2.logBytes32(initcode);
    // console2.log(factory);
    console2.log(RouterLibrary.pairFor(factory, tokenA, tokenB));
  }
}