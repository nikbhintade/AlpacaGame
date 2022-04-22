// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "../thetacontracts/token/ERC20/ERC20.sol";

contract WOOL is ERC20 {
  constructor() ERC20("WOOL", "WOOL") {
    _mint(msg.sender, 10000000 ether);
  }
}