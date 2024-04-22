// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console2} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OpenDexERC20} from "../OpenDexERC20.sol";

error Reantrant();

uint256 constant MINIMUM_LIQUIDITY = 10**3;

uint256 constant BALANCE_OF_SELECTOR = 0x70a0823100000000000000000000000000000000000000000000000000000000;

/**
 * @notice UniswapV2 fork in assembly
 */
contract OpenDexPairV2 {
  address public factory;
  address public token0;
  address public token1;

  uint112 private reserve0;
  uint112 private reserve1;
  uint32 private blockTimestampLast;

  uint256 private reantrant = 1;

  modifier reantrancyGuard {
    if (reantrant == 0) revert Reantrant();
    reantrant = 0;
    _;
    reantrant = 1;
  }

  constructor() {
    assembly {
      sstore(0, caller())
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
        revert(0, 0)
      }
      sstore(token0.slot, _token0)
      sstore(token1.slot, _token1)
    }
  }

  function mint(address _to, uint256 _amount0, uint256 _amount1, address _payer) external returns(uint256 _liquidity) {
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
        revert (0, 0)
      }
    }
  }
}