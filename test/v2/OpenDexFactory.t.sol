// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import '../../src/v2/OpenDexFactory.sol';
// import '../../src/v2/OpenDexPair.sol';
import {TestERC20} from '../../src/testToken/TestERC20.sol';

import '../../src/v2/interface/IOpenDexFactoryError.sol';

contract TestOpenDexFactory is Test {
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

    // vm.prank(feeSetter);
    // factory.setFeeTo(fee);
    
    vm.startPrank(owner);
    testETH = new TestERC20();
    testDAI = new TestERC20();
    // factory.createPair(address(testETH), address(testDAI));
    // pair = OpenDexPair(factory.getPair(address(testETH), address(testDAI)));
    // (token0, token1) = address(testETH) < address(testDAI) ? (address(testETH), address(testDAI)) : (address(testDAI), address(testETH));
  }

  function testCreatePair() public {
    address newPair = factory.createPair(address(testETH), address(testDAI));
    require(newPair != address(0), "fail create pair");
  }

  function testCreatePairShouldFailCreateSamePair() public {
    factory.createPair(address(testETH), address(testDAI));
    vm.expectRevert(PairExist.selector);
    factory.createPair(address(testETH), address(testDAI));
  }

  function testCreatePairShouldFailWithAddressZero() public {
    vm.expectRevert(AddressZero.selector);
    factory.createPair(address(0), address(testDAI));
  }

  function testGetAllPairLength() public {
    uint256 lengthBefore = factory.allPairsLength();
    require(lengthBefore == 0, "fail get length before");
    factory.createPair(address(testETH), address(testDAI));
    uint256 lengthAfter = factory.allPairsLength();
    require(lengthAfter == 1, "fail get length after");
  }
}