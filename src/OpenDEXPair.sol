// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OpenDexERC20} from "./OpenDexERC20.sol";

uint256 constant MINIMUM_LIQUIDITY = 10**3;

error Reantrant();
error InvalidAmount();

/**
 * @notice Simple Decentralized Exchange by chixx.eth
 */
contract OpenDexPair is OpenDexERC20 {
  address public factory;
  address public token0;
  address public token1;

  uint256 private reserve0;
  uint256 private reserve1;
  uint256 private kVariable;

  uint256 private reantrant = 1;

  constructor(address _factory, address _token0, address _token1) {
    factory = _factory;
    token0 = _token0;
    token1 = _token1;
  }

    modifier reantrancyGuard {
    if (reantrant == 0) revert Reantrant();
    reantrant = 0;
    _;
    reantrant = 1;
  }

  function addLiquidity(uint256 amount0, uint256 amount1) external reantrancyGuard returns(uint256 liquidity) {
    uint256 _totalSupply = totalSupply;
    uint256 balance0 = IERC20(token0).balanceOf(address(this));
    uint256 balance1 = IERC20(token1).balanceOf(address(this));
    if (_totalSupply == 0) {
      liquidity = amount0 + amount1 - MINIMUM_LIQUIDITY;
      _mint(address(0), MINIMUM_LIQUIDITY);
    } else {
      uint256 liquidityX = amount0 * _totalSupply / balance0;
      uint256 liquidityY = amount1 * _totalSupply / balance1;
      liquidity = (liquidityX + liquidityY) / 2;
    }

    IERC20(token0).transferFrom(msg.sender, address(this), amount0);
    IERC20(token1).transferFrom(msg.sender, address(this), amount1);

    _mint(msg.sender, liquidity);

    _syncReserve(balance0 + amount0, balance1 + amount1);

    kVariable = reserve0 * reserve1;
  }

  function removeLiquidity(uint256 lpTokenAmount) external reantrancyGuard returns(uint256 token0Out, uint256 token1Out) {
    uint256 _totalSupply = totalSupply;
    uint256 balance0 = IERC20(token0).balanceOf(address(this));
    uint256 balance1 = IERC20(token1).balanceOf(address(this));
    token0Out = lpTokenAmount * balance0 / _totalSupply;
    token1Out = lpTokenAmount * balance1 / _totalSupply;
    _burn(address(this), lpTokenAmount);
    IERC20(token0).transfer(msg.sender, token0Out);
    IERC20(token1).transfer(msg.sender, token1Out);

    _syncReserve(balance0 - token0Out, balance1 - token1Out);

    kVariable = reserve0 * reserve1;
  }

  function _syncReserve(uint256 balance0, uint256 balance1) internal {
    reserve0 = balance0;
    reserve1 = balance1;
  }
}
