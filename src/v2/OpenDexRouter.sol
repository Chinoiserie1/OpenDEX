// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './lib/RouterLibrary.sol';

bytes32 constant GET_PAIR_SELECTOR = 0xe6a4390500000000000000000000000000000000000000000000000000000000;
bytes32 constant CREATE_PAIR_SELECTOR = 0xc9c6539600000000000000000000000000000000000000000000000000000000;
bytes32 constant GET_RESERVES_SELECTOR = 0x0902f1ac00000000000000000000000000000000000000000000000000000000;
bytes32 constant TRANSFER_FROM_SELECTOR = 0x23b872dd00000000000000000000000000000000000000000000000000000000;
bytes32 constant MINT_SELECTOR = 0x6a62784200000000000000000000000000000000000000000000000000000000;
bytes32 constant BURN_SELECTOR = 0x23b872dd00000000000000000000000000000000000000000000000000000000;

contract OpenDexRouter {
  address factory;

  modifier ensure(uint deadline) {
    assembly {
      if lt(deadline, timestamp()) {
        // error EXPIRED
        revert(0, 0)
      }
    }
    _;
  }

  constructor(address _factory) {
    assembly {
      sstore(factory.slot, _factory)
    }
  }

  function _addLiquidity(
    address tokenA,
    address tokenB,
    uint256 amountADesired,
    uint256 amountBDesired,
    uint256 amountAMin,
    uint256 amountBMin
  ) internal virtual returns (uint256 amountA, uint256 amountB) {
    assembly {
      // see src/v2/lib/RouterLibrary.sol
      function quote(amountX, reserveX, reserveY) -> amountY {
        function safeMul(x, y) -> z {
          z := mul(x, y)
          if lt(z, x) {
            mstore(0x00, OVERFLOW)
            revert(0x00, 0x04)
          }
        }
        if iszero(amountX) {
          // error INSUFFICIENT_AMOUNT
          revert(0, 0)
        }
        if or(iszero(reserveX), iszero(reserveY)) {
          // error INSUFFICIENT_LIQUIDITY
          revert(0, 0)
        }
        amountY := div(safeMul(amountX, reserveY), reserveX)
      }

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
      // retrieve reserves
      mstore(0x20, GET_RESERVES_SELECTOR)
      callstatus := call(gas(), mload(0x00), 0, 0x20, 0x04, 0x00, 0x60)
      if iszero(callstatus) {
        revert(0x00, calldatasize())
      }
      let reserveA := mload(0x00)
      let reserveB := mload(0x20)
      // get amountA and amountB
      switch and(iszero(reserveA), iszero(reserveB))
      case 1 {
        amountA := amountADesired
        amountB := amountBDesired
      }
      case 0 {
        let amountBOptimal := quote(amountADesired, reserveA, reserveB)
        switch gt(amountBOptimal, amountBDesired)
        case 0 {
          if lt(amountBOptimal, amountBMin) {
            // error INSUFFICIENT_B_AMOUNT
            revert(0, 0)
          }
          amountA := amountADesired
          amountB := amountBOptimal
        }
        case 1 {
          let amountAOptimal := quote(amountBDesired, reserveB, reserveA)
          if gt(amountAOptimal, amountADesired) {
            invalid()
          }
          if lt(amountAOptimal, amountAMin) {
            // error INSUFFICIENT_A_AMOUNT
            revert(0, 0)
          }
          amountA := amountAOptimal
          amountB := amountBDesired
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
    // can't use modifier to prevent Stack too deep error
    assembly {
      if lt(deadline, timestamp()) {
        // error EXPIRED
        revert(0, 0)
      }
    }

    (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
    address pair = RouterLibrary.pairFor(factory, tokenA, tokenB);

    assembly {
      function transferFrom(token, from, receiver, amount) {
        let slot0x40 := mload(0x40)
        mstore(0x00, TRANSFER_FROM_SELECTOR)
        mstore(0x04, from)
        mstore(0x24, receiver)
        mstore(0x44, amount)
        let callstatus := call(gas(), token, 0, 0x00, 0x64, 0x00, 0x20)
        if iszero(callstatus) {
          revert(0, calldatasize())
        }
        mstore(0x40, slot0x40)
        mstore(0x60, 0)
      }

      transferFrom(tokenA, caller(), pair, amountA)
      transferFrom(tokenB, caller(), pair, amountB)

      mstore(0x00, MINT_SELECTOR)
      mstore(0x04, to)
      let callstatus := call(gas(), pair, 0, 0x00, 0x24, 0x00, 0x20)
       if iszero(callstatus) {
        revert(0, calldatasize())
      }
      liquidity := mload(0x00)
    }
  }

  function removeLiquidity(
    address tokenA,
    address tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
  ) public virtual ensure(deadline) returns (uint amountA, uint amountB) {
    address pair = RouterLibrary.pairFor(factory, tokenA, tokenB);
    assembly {
      let slot0x40 := mload(0x40) // store free memory ptr
      // call transferFrom to send liquidity to pair
      mstore(0x00, TRANSFER_FROM_SELECTOR)
      mstore(0x04, caller())
      mstore(0x24, pair)
      mstore(0x44, liquidity)
      let callstatus := call(gas(), pair, 0, 0x00, 0x64, 0x00, 0x20)
      if iszero(callstatus) {
        revert(0, calldatasize())
      }
      // call burn and get amount0 and amount1
      mstore(0x00, BURN_SELECTOR)
      mstore(0x04, to)
      callstatus := call(gas(), pair, 0, 0x00, 0x24, 0x00, 0x40)
      if iszero(callstatus) {
        revert(0, calldatasize())
      }
      let amount0 := mload(0x00)
      let amount1 := mload(0x20)
      // sort tokens
      if eq(tokenA, tokenB) {
        mstore(0x00, IDENTICAL_ADDRESS)
        revert(0x00, 0x04)
      }
      let token0 := tokenA
      let token1 := tokenB
      amountA := amount0
      amountB := amount1
      if gt(tokenA, tokenB) {
        token0 := tokenB
        token1 := tokenA
        amountA := amount1
        amountB := amount0
      }
      if iszero(token0) {
        mstore(0x00, ADDRESS_ZERO)
        revert(0x00, 0x04)
      }
      // check amoutA and amountB greater than amountAMin and amountBMin
      if lt(amountA, amountAMin) {
        // error INSUFFICIENT_A_AMOUNT
        revert(0, 0)
      }
      if lt(amountB, amountBMin) {
        // error INSUFFICIENT_B_AMOUNT
        revert(0, 0)
      }
      mstore(0x40, slot0x40) // restore free memory ptr
      mstore(0x60, 0) // restore zero slot
    }
  }
}