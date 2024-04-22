// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library Math {
  function min(uint x, uint y) internal pure returns (uint z) {
    z = x < y ? x : y;
  }

  function minAssembly(uint x, uint y) internal pure returns (uint z) {
    assembly {
      z := y
      if lt(x, y) {
        z := x
      }
    }
  }

  function sqrt(uint y) internal pure returns (uint z) {
    unchecked {
      if (y > 3) {
        z = y;
        uint x = y / 2 + 1;
        while (x < z) {
          z = x;
          x = (y / x + x) / 2;
        }
      } else if (y != 0) {
        z = 1;
      }
    }
  }

  function sqrtAssembly(uint y) internal pure returns (uint z) {
    assembly {
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
  }
}