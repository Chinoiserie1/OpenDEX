// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console2} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OpenDexERC20} from "../v1/OpenDexERC20.sol";

import {INVALID_CALLER} from './lib/OpenDexConstants.sol';
import './lib/OpenDexPairConstants.sol';
import {IOpenDexPairError} from './interface/IOpenDexPairError.sol';
import './interface/IOpenDexFactory.sol';

error Reantrant();

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

  event Mint(address indexed sender, uint amount0, uint amount1);

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
      _reserve0 := shr(0x90, shl(0x90, mload(0x00)))
      _reserve1 := shr(0x90, shl(0x20, mload(0x00)))
      _blockTimestampLast := shr(0xE0, mload(0x00))
    }
  }

  function initialize(address _token0, address _token1) external {
    assembly {
      if iszero(eq(sload(factory.slot), caller())) {
        mstore(0x00, INVALID_CALLER)
        revert(0x00, 0x04)
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
      mstore(0x20, sub(mload(0x00), shr(224, sload(blockTimestampLast.slot)))) // timeElapsed
      if and(and(gt(mload(0x20), 0), gt(_reserve0, 0)), gt(_reserve1, 0)) {
        sstore(price0CumulativeLast.slot, mul(div(_reserve1, _reserve0), mload(0x20)))
        sstore(price1CumulativeLast.slot, mul(div(_reserve0, _reserve1), mload(0x20)))
      }
      // store reserve0, reserv1, blockTimestampLast in the same slot
      mstore(0x20, add(add(shl(112, _balance1), shl(224, mload(0x00))), _balance0))
      sstore(reserve0.slot, mload(0x20))
      // emit Sync(uint112 reserve0, uint112 reserve1)
      mstore(0x00, _balance0)
      mstore(0x20, _balance1)
      log1(0x00, 0x40, SYNC_HASH)
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

  function mint(address to) external reantrancyGuard returns(uint256 liquidity) {
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
      mstore(0x00, sload(reserve0.slot))
      reserve0_ := shr(144, shl(144, mload(0x00)))
      reserve1_ := shr(144, shl(32, mload(0x00)))
      // compute calcul amount0 & amoun1
      amount0_ := sub(balance0_, reserve0_)
      amount1_ := sub(balance1_, reserve1_)
      // check underflow
      if or(gt(amount0_, balance0_), gt(amount1_, balance1_)) {
        mstore(0x00, UNDERFLOW)
        revert (0x00, 0x04)
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
        mstore(0x00, INSUFFICIENT_LIQUIDITY_MINT)
        revert(0x00, 0x04)
      }
    }

    _mint(to, liquidity);

    _update(balance0_, balance1_, reserve0_, reserve1_);

    assembly {
      if eq(feeOn, 1) {
        sstore(kLast.slot, mul(sload(reserve0.slot), sload(reserve1.slot)))
        // emit Mint(to, amount0, amount1);
        mstore(0x00, amount0_)
        mstore(0x20, amount1_)
        log2(0x00, 0x40, MINT_HASH, caller())
      }
    }
  }

  function burn(address to) external reantrancyGuard returns(uint256 amount0, uint256 amount1) {
    uint112 reserve0_;
    uint112 reserve1_;
    uint256 balance0_;
    uint256 balance1_;

    uint256 liquidity;

    address token0_;
    address token1_;

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

      token0_ := sload(token0.slot)
      token1_ := sload(token1.slot)
      // retrieve balanceOf token0 & token1
      balance0_ := getBalance(token0_)
      balance1_ := getBalance(token1_)
      // retrieve reserve0 & reserve1
      mstore(0x00, sload(reserve0.slot))
      reserve0_ := shr(144, shl(144, mload(0x00)))
      reserve1_ := shr(144, shl(32, mload(0x00)))
      // retrieve balanceOf address this
      mstore(0x00, address())
      mstore(0x20, balanceOf.slot)
      let slot := keccak256(0x00, 0x40)
      liquidity := sload(slot)
    }

    bool feeOn = _mintFee(reserve0_, reserve1_);

    assembly {
      // compute amount0
      mstore(0x00, sload(totalSupply.slot))
      mstore(0x20, mul(liquidity, balance0_))
      if lt(mload(0x20), liquidity) {
        mstore(0x00, OVERFLOW)
        revert (0x00, 0x04)
      }
      amount0 := div(mload(0x20), mload(0x00))
      // compute amount1
      mstore(0x20, mul(liquidity, balance1_))
      if lt(mload(0x20), liquidity) {
        mstore(0x00, OVERFLOW)
        revert (0x00, 0x04)
      }
      amount1 := div(mload(0x20), mload(0x00))
      // check if sufficient liquidity
      if or(iszero(amount0), iszero(amount1)) {
        mstore(0x00, INSUFFICIENT_LIQUIDITY_BURN)
        revert(0x00, 0x04) // revert need to be set with an error
      }
    }

    _burn(address(this), liquidity);

    assembly {
      // transfer token fn
      function transfer(token, receiver, amount) {
        let slot0x40 := mload(0x40)
        mstore(0x00, TRANSFER_SELECTOR)
        mstore(0x04, receiver)
        mstore(0x24, amount)
        let callstatus := call(gas(), token, 0, 0x00, 0x44, 0x00, 0x20)
        if iszero(callstatus) {
          revert (0x00, returndatasize())
        }
        // restore free memory ptr
        mstore(0x40, slot0x40)
      }
      function getBalance(tokenAddress) -> balanceResult {
        mstore(0x00, BALANCE_OF_SELECTOR)
        mstore(0x04, address())
        let callstatus := call(gas(), tokenAddress, 0, 0x00, 0x24, 0x00, 0x20)
        if iszero(callstatus) {
          revert(0x00, returndatasize())
        }
        balanceResult := mload(0x00)
      }

      transfer(token0_, to, amount0)
      transfer(token1_, to, amount1)
      balance0_ := getBalance(token0_)
      balance1_ := getBalance(token1_)
    }

    _update(balance0_, balance1_, reserve0_, reserve1_);

    assembly {
      if eq(feeOn, 1) {
        sstore(kLast.slot, mul(sload(reserve0.slot), sload(reserve1.slot)))
        // should emit Burn(msg.sender, amount0, amount1, to);
        mstore(0x00, amount0)
        mstore(0x20, amount1)
        log3(0x00, 0x60, BURN_HASH, caller(), to)
      }
    }
  }

  function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external reantrancyGuard {
    uint112 reserve0_;
    uint112 reserve1_;
    uint256 balance0_;
    uint256 balance1_;
    uint256 amount0In;
    uint256 amount1In;

    assembly {
      function transfer(token, receiver, amount) {
        let slot0x40 := mload(0x40)
        mstore(0x00, TRANSFER_SELECTOR)
        mstore(0x04, receiver)
        mstore(0x24, amount)
        let callstatus := call(gas(), token, 0, 0x00, 0x44, 0x00, 0x20)
        if iszero(callstatus) {
          revert (0x00, returndatasize())
        }
        // restore free memory ptr
        mstore(0x40, slot0x40)
      }
      function getBalance(tokenAddress) -> balanceResult {
        mstore(0x00, BALANCE_OF_SELECTOR)
        mstore(0x04, address())
        let callstatus := call(gas(), tokenAddress, 0, 0x00, 0x24, 0x00, 0x20)
        if iszero(callstatus) {
          revert(0x00, returndatasize())
        }
        balanceResult := mload(0x00)
      }
      function safeSub(x, y) -> z {
        z := sub(x, y)
        if gt(z, x) {
          mstore(0x00, UNDERFLOW)
          revert(0, 0)
        }
      }
      function safeMul(x, y) -> z {
        z := mul(x, y)
        if lt(z, x) {
          mstore(0x00, OVERFLOW)
          revert(0x00, 0x04)
        }
      }

      if and(iszero(amount0Out), iszero(amount1Out)) {
        mstore(0x00, INSUFFICIENT_OUTPUT_AMOUNT)
        revert (0x00, 0x04)
      }
      // retrieve reserve0 & reserve1
      mstore(0x00, sload(reserve0.slot))
      reserve0_ := shr(144, shl(144, mload(0x00)))
      reserve1_ := shr(144, shl(32, mload(0x00)))
      if or(gt(amount0Out, reserve0_), gt(amount1Out, reserve1_)) {
        mstore(0x00, INSUFFICIENT_LIQUIDITY)
        revert(0x00, 0x04)
      }
      let token0Addy := sload(token0.slot)
      let token1Addy := sload(token1.slot)
      if or(eq(token0Addy, to), eq(token1Addy, to)) {
        mstore(0x00, INVALID_TO)
        revert(0x00, 0x04)
      }
      if gt(amount0Out, 0) {
        transfer(token0Addy, to, amount0Out)
      }
      if gt(amount1Out, 0) {
        transfer(token1Addy, to, amount1Out)
      }
      // if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
      balance0_ := getBalance(token0Addy)
      balance1_ := getBalance(token1Addy)

      // amount0In
      // let amount0In := 0
      if gt(balance0_, safeSub(reserve0_, amount0Out)) {
        amount0In := safeSub(balance0_, safeSub(reserve0_, amount0Out))
      }
      // let amount1In := 0
      if gt(balance1_, safeSub(reserve1_, amount1Out)) {
        amount1In := safeSub(balance1_, safeSub(reserve1_, amount1Out))
      }
      if and(iszero(amount0In), iszero(amount1In)) {
        mstore(0x00, INSUFFICIENT_INPUT_AMOUNT)
        revert(0x00, 0x04)
      }

      mstore(0x00, safeSub(safeMul(balance0_, 1000), safeMul(amount0In, 3))) // balance0Adjusted
      mstore(0x20, safeSub(safeMul(balance1_, 1000), safeMul(amount1In, 3))) // balance1Adjusted
      if lt(safeMul(mload(0x00), mload(0x20)), safeMul(safeMul(reserve0_, reserve1_), exp(1000, 2))) {
        mstore(0x00, INVALID_VARIABLE_K)
        revert(0x00, 0x04)
      }
    }
    _update(balance0_, balance1_, reserve0_, reserve1_);

    assembly {
      // should emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
      let slot0x40 := mload(0x40)
      mstore(0x00, amount0In)
      mstore(0x20, amount1In)
      mstore(0x40, amount0Out)
      mstore(0x60, amount1Out)
      log3(0x00, 0x80, SWAP_HASH, caller(), to)
      // restore free memory & zero
      mstore(0x40, slot0x40)
      mstore(0x60, 0)
    }
  }

  // force balances to match reserves
  function skim(address to) external reantrancyGuard {
    assembly {
      function transfer(token, receiver, amount) {
        let slot0x40 := mload(0x40)
        mstore(0x00, TRANSFER_SELECTOR)
        mstore(0x04, receiver)
        mstore(0x24, amount)
        let callstatus := call(gas(), token, 0, 0x00, 0x44, 0x00, 0x20)
        if iszero(callstatus) {
          revert (0x00, returndatasize())
        }
        // restore free memory ptr
        mstore(0x40, slot0x40)
      }
      function getBalance(tokenAddress) -> balanceResult {
        mstore(0x00, BALANCE_OF_SELECTOR)
        mstore(0x04, address())
        let callstatus := call(gas(), tokenAddress, 0, 0x00, 0x24, 0x00, 0x20)
        if iszero(callstatus) {
          revert(0x00, returndatasize())
        }
        balanceResult := mload(0x00)
      }
      function safeSub(x, y) -> z {
        z := sub(x, y)
        if gt(z, x) {
          mstore(0x00, UNDERFLOW)
          revert(0x00, 0x04)
        }
      }
      let token0_ := sload(token0.slot)
      let token1_ := sload(token1.slot)
      mstore(0x00, sload(reserve0.slot))
      transfer(token0_, to, safeSub(getBalance(token0_), shr(144, shl(144, mload(0x00)))))
      transfer(token1_, to, safeSub(getBalance(token1_), shr(144, shl(32, mload(0x00)))))
    }
  }

  function sync() external reantrancyGuard {
    _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
  }
}