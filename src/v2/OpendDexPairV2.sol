// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OpenDexERC20} from "../OpenDexERC20.sol";

error Reantrant();

uint256 constant MINIMUM_LIQUIDITY = 10**3;

/**
 * @notice UniswapV2 fork
 */
contract OpenDexPairV2 {
  address public factory;
  address public token0;
  address public token1;

  uint256 private reantrant = 1;

  modifier reantrancyGuard {
    if (reantrant == 0) revert Reantrant();
    reantrant = 0;
    _;
    reantrant = 1;
  }
}