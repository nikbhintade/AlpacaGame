// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "../thetacontracts/access/Ownable.sol";
import "../thetacontracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../thetacontracts/token/ERC20/IERC20.sol";

contract Alpaca is ERC721Enumerable, Ownable {
  uint256 public constant MAX_TOKENS = 9999;
  uint256 public constant FREE_TOKENS = 3000;
  uint16 public purchased = 0;

  bool public mainSaleStarted;
  mapping(address=>uint8) public freeMintsUsed;
  string baseURI;

  IERC20 wool;

  constructor(address _wool) ERC721("Alpaca", 'AL') {
    wool = IERC20(_wool);

    require(wool.approve(msg.sender, type(uint256).max));
  }

  // internal
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  // Reads
  function woolPrice(uint16 amount) public view returns (uint256) {
    require(purchased + amount >= FREE_TOKENS);
    uint16 secondGen = purchased + amount - uint16(FREE_TOKENS);
    return (secondGen / 500 + 1) * 40 ether;
  }

  function walletOfOwner(address _owner)
    public
    view
    returns (string[] memory)
  {
    uint256 ownerTokenCount = balanceOf(_owner);
    string[] memory tokenIds = new string[](ownerTokenCount);
    for (uint256 i; i < ownerTokenCount; i++) {
      uint256 ids = tokenOfOwnerByIndex(_owner, i);
      tokenIds[i] = tokenURI(ids);
    }
    return tokenIds;
  }

  // Public
  function freeMint(uint8 amount) public payable {
    require(mainSaleStarted, "Main Sale hasn't started yet");
    address minter = _msgSender();
    require(freeMintsUsed[minter] + amount <= 5, "You can't free mint any more");
    require(tx.origin == minter, "Contracts not allowed");
    require(purchased + amount <= FREE_TOKENS, "Sold out");

    for (uint8 i = 0; i < amount; i++) {
      freeMintsUsed[minter]++;
      purchased++;
      _mint(minter, purchased);
    }
  }

  function buyWithwool(uint16 amount) public {
    address minter = _msgSender();
    require(mainSaleStarted, "Main Sale hasn't started yet");
    require(tx.origin == minter, "Contracts not allowed");
    require(amount > 0 && amount <= 20, "Max 20 mints per tx");
    require(purchased >= FREE_TOKENS, "wool sale not active");
    require(purchased + amount <= MAX_TOKENS, "Sold out");

    uint256 price = amount * woolPrice(amount);
    require(price <= wool.allowance(minter, address(this)) && price <= wool.balanceOf(minter), "You need to send enough wool");
    
    uint256 initialPurchased = purchased;
    purchased += amount;
    require(wool.transferFrom(minter, address(this), price));

    for (uint16 i = 1; i <= amount; i++) {
      _mint(minter, initialPurchased + i);
    }
  }

  // Admin
  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
  }

  function toggleMainSale() public onlyOwner {
    mainSaleStarted = !mainSaleStarted;
  }
}