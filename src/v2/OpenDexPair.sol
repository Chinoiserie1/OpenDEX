// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console2} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OpenDexERC20} from "../v1/OpenDexERC20.sol";

import './interface/IOpenDexFactory.sol';
import '../lib/Math.sol';

error Reantrant();

uint256 constant MINIMUM_LIQUIDITY = 10**3;

uint256 constant BALANCE_OF_SELECTOR = 0x70a0823100000000000000000000000000000000000000000000000000000000;

uint256 constant FEE_TO_SELECTOR = 0x017e7e5800000000000000000000000000000000000000000000000000000000;

uint112 constant MAX_UINT_112 = 0x0000000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFF;

// first 4 bit keccak256("overflow()")
bytes32 constant OVERFLOW = 0x004264c300000000000000000000000000000000000000000000000000000000;

/**
 * @notice UniswapV2 fork in assembly
 * 
 * reference: https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol
 */
contract OpenDexPair is OpenDexERC20 {
  address public factory;
  address public token0;
  address public token1;

  uint112 private reserve0;
  uint112 private reserve1;
  uint32 private blockTimestampLast;

  uint256 public price0CumulativeLast;
  uint256 public price1CumulativeLast;
  uint256 public kLast;

  uint256 private reantrant = 1;

  modifier reantrancyGuard {
    if (reantrant == 0) revert Reantrant();
    reantrant = 0;
    _;
    reantrant = 1;
  }

  constructor() {
    assembly {
      sstore(factory.slot, caller())
    }
  }

  function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
    assembly {
      mstore(0, sload(reserve0.slot))
      _reserve0 := mload(0x00)
      _reserve1 := shr(112, mload(0x00))
      _blockTimestampLast := shr(224, mload(0x00))
    }
  }

  function initialize(address _token0, address _token1) external {
    assembly {
      if iszero(eq(sload(factory.slot), caller())) {
        revert(0, 0) // revert need to be set with a error
      }
      sstore(token0.slot, _token0)
      sstore(token1.slot, _token1)
    }
  }

  function _update(uint256 _balance0, uint256 _balance1, uint112 _reserve0, uint112 _reserve1) private {
    assembly {
      if or(gt(_balance0, MAX_UINT_112), gt(_balance1, MAX_UINT_112)) {
        mstore(0x00, OVERFLOW)
        revert(0x00, 0x04)
      }
      // use free memory because its cheaper
      mstore(0x00, mod(timestamp(), exp(2, 32))) // blockTimestamp
      mstore(0x20, sub(mload(0x00), sload(blockTimestampLast.slot))) // timeElapsed
      if and(and(gt(mload(0x20), 0), gt(_reserve0, 0)), gt(_reserve1, 0)) {
        sstore(price0CumulativeLast.slot, mul(div(_reserve1, _reserve0), mload(0x20)))
        sstore(price1CumulativeLast.slot, mul(div(_reserve0, _reserve1), mload(0x20)))
      }
      sstore(reserve0.slot, _balance0)
      sstore(reserve1.slot, _balance1)
      sstore(blockTimestampLast.slot, mload(0x00))
      // should emit Sync(reserve0, reserve1);
    }
  }

  function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
    address feeTo;
    uint256 liquidity;
    assembly {
      function sqrt(y) -> z {
        if gt(y, 3) {
          z := y
          let x := add(div(y, 2), 1)
          for {} lt(x, z) {} {
            z := x
            x := div(add(div(y, x), x) , 2)
          }
        }
        if and(gt(y, 0), lt(y, 4)) {
          z := 1
        }
      }
      // get address fee to from factory
      mstore(0x00, FEE_TO_SELECTOR)
      let callstatus := call(gas(), sload(factory.slot), 0, 0x00, 0x04, 0x00, 0x20)
      if iszero(callstatus) {
        revert(0x00, returndatasize())
      }
      feeTo := mload(0x00)
      feeOn := 1
      // check if address eq zero
      if iszero(mload(0x00)) {
        feeOn := 0
      }
      let _kLast := sload(kLast.slot)

      if eq(feeOn, 1) {
        if gt(_kLast, 0) {
          let k := mul(_reserve0, _reserve1)
          if lt(k, _reserve1) {
            mstore(0x00, OVERFLOW)
            revert(0x00, 0x04)
          }
          let rootK := sqrt(k)
          let rootKLast := sqrt(_kLast)
          if gt(rootK, rootKLast) {
            let totalSupply_ := sload(totalSupply.slot)
            let numerator := mul(totalSupply_, sub(rootK, rootKLast))
            // check overflow
            if lt(numerator, totalSupply_) {
              mstore(0x00, OVERFLOW)
              revert(0x00, 0x04)
            }
            let denominator := add(mul(rootK, 5), rootKLast) // can't overflow (normaly ? need test)
            liquidity := div(numerator, denominator)
          }
        }
      }
      if and(iszero(feeOn), gt(_kLast, 0)) {
        sstore(kLast.slot, 0)
      }
    }
    if (liquidity > 0) _mint(feeTo, liquidity);
  }

  function mint(address to) external returns(uint256 liquidity) {
    uint112 reserve0_;
    uint112 reserve1_;
    uint256 balance0_;
    uint256 balance1_;
    uint256 amount0_;
    uint256 amount1_;

    assembly {
      function getBalance(tokenAddress) -> balanceResult {
        mstore(0x00, BALANCE_OF_SELECTOR)
        mstore(0x04, address())
        let callstatus := call(gas(), tokenAddress, 0, 0x00, 0x24, 0x00, 0x20)
        if iszero(callstatus) {
          revert(0x00, returndatasize())
        }
        balanceResult := mload(0x00)
      }

      // retrieve balanceOf token0 & token1
      balance0_ := getBalance(sload(token0.slot))
      balance1_ := getBalance(sload(token1.slot))
      // retrieve reserve0 & reserve1
      mstore(0, sload(reserve0.slot))
      reserve0_ := mload(0x00)
      reserve1_ := shr(112, mload(0x00))
      // compute calcul amount0 & amoun1
      amount0_ := sub(balance0_, reserve0_)
      amount1_ := sub(balance1_, reserve1_)
      // check underflow
      if or(gt(amount0_, balance0_), gt(amount1_, balance1_)) {
        revert (0, 0) // revert need to be set with a error
      }
    }

    bool feeOn = _mintFee(reserve0_, reserve1_);
    uint256 totalSupply_;
    assembly {
      totalSupply_ := sload(totalSupply.slot)
    }

    if (totalSupply_ == 0) _mint(address(0), MINIMUM_LIQUIDITY);

    assembly {
      function sqrt(y) -> z {
        if gt(y, 3) {
          z := y
          let x := add(div(y, 2), 1)
          for {} lt(x, z) {} {
            z := x
            x := div(add(div(y, x), x) , 2)
          }
        }
        if and(gt(y, 0), lt(y, 4)) {
          z := 1
        }
      }
      function min(x, y) -> z {
        z := y
        if lt(x, y) {
          z := x
        }
      }
      if iszero(totalSupply_) {
        liquidity := sqrt(sub(mul(amount0_, amount1_), MINIMUM_LIQUIDITY))
      }
      if gt(totalSupply_, 0) {
        liquidity := min(div(mul(amount0_, totalSupply_), reserve0_), div(mul(amount1_, totalSupply_), reserve1_))
      }
      if iszero(liquidity) {
        revert(0,0) // revert need to be set with a error
      }
    }
    _mint(to, liquidity);

    _update(balance0_, balance1_, reserve0_, reserve1_);

    assembly {
      if eq(feeOn, 1) {
        sstore(kLast.slot, mul(sload(reserve0.slot), sload(reserve1.slot)))
        // should emit Mint(msg.sender, amount0, amount1);
      }
    }
  }

}