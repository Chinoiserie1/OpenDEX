// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import '../../src/v2/OpenDexPair.sol';
import {TestERC20} from '../../src/testToken/TestERC20.sol';

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestOpenDexPair is Test {
  OpenDexPair public pair;
  TestERC20 public testETH;
  TestERC20 public testDAI;
  address token0;
  address token1;

  uint256 internal ownerPrivateKey;
  address internal owner;
  uint256 internal user1PrivateKey;
  address internal user1;
  uint256 internal user2PrivateKey;
  address internal user2;
  uint256 internal user3PrivateKey;
  address internal user3;
  uint256 internal signerPrivateKey;
  address internal signer;

  function setUp() public {
    ownerPrivateKey = 0xA11CE;
    owner = vm.addr(ownerPrivateKey);
    user1PrivateKey = 0xB0B;
    user1 = vm.addr(user1PrivateKey);
    user2PrivateKey = 0xFE55E;
    user2 = vm.addr(user2PrivateKey);
    user3PrivateKey = 0xD1C;
    user3 = vm.addr(user3PrivateKey);
    signerPrivateKey = 0xF10;
    signer = vm.addr(signerPrivateKey);
    vm.startPrank(owner);

    testETH = new TestERC20();
    testDAI = new TestERC20();
    pair = new OpenDexPair();
    (token0, token1) = address(testETH) < address(testDAI) ? (address(testETH), address(testDAI)) : (address(testDAI), address(testETH));
    pair.initialize(token0, token1);
  }

  function testGetToken() public view {
    require(pair.token0() == token0, "fail get correct token0 address");
    require(pair.token1() == token1, "fail get correct token1 address");
  }

  function test() public {
    pair.getReserves();
  }
}

