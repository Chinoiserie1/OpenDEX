// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import '../../src/v2/interface/IOpenDexFactory.sol';
import '../../src/v2/interface/IOpenDexPair.sol';

import '../../src/v2/OpenDexFactory.sol';
import '../../src/v2/OpenDexPair.sol';
import {TestERC20} from '../../src/testToken/TestERC20.sol';

import '../../src/lib/Math.sol';

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestOpenDexPair is Test {
  OpenDexFactory public factory;
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
  uint256 internal feeSetterPrivateKey;
  address internal feeSetter;
  uint256 internal feePrivateKey;
  address internal fee;

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
    feeSetterPrivateKey = 0xfee5e11e5;
    feeSetter = vm.addr(feeSetterPrivateKey);
    feePrivateKey = 0xfee;
    fee = vm.addr(feePrivateKey);
    
    vm.prank(owner);
    factory = new OpenDexFactory(feeSetter);

    vm.prank(feeSetter);
    factory.setFeeTo(fee);
    
    vm.startPrank(owner);
    testETH = new TestERC20();
    testDAI = new TestERC20();
    factory.createPair(address(testETH), address(testDAI));
    pair = OpenDexPair(factory.getPair(address(testETH), address(testDAI)));
    (token0, token1) = address(testETH) < address(testDAI) ? (address(testETH), address(testDAI)) : (address(testDAI), address(testETH));
  }

  function testGetToken() public view {
    require(pair.token0() == token0, "fail get correct token0 address");
    require(pair.token1() == token1, "fail get correct token1 address");
  }

  function testMint() public {
    vm.warp(365 days * 6);
    testETH.transfer(address(pair), 1 ether);
    testDAI.transfer(address(pair), 1 ether);
    pair.mint(user1);
  }

  function testBurn() public {
    vm.warp(365 days * 6);
    testETH.transfer(address(pair), 1 ether);
    testDAI.transfer(address(pair), 2 ether);
    uint256 liquidity = pair.mint(user1);

    vm.stopPrank();
    vm.startPrank(user1);
    pair.transfer(address(pair), liquidity);
    pair.burn(user1);
  }

  function test() public {
    console2.logBytes4(bytes4(keccak256(bytes('transfer(address,uint256)'))));
    // console2.logBytes4(IOpenDexFactory.feeTo.selector);
    // pair.getReserves();
    // console2.log(Math.sqrt(50)); // 4338 gas
    // console2.log(Math.sqrtA(250)); // 3515 gas
    // console2.log(Math.min(30, 40));
    // console2.log(Math.minAssembly(30, 40));
  }
}

