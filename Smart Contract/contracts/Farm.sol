// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "../thetacontracts/access/Ownable.sol";
import "../thetacontracts/token/ERC20/IERC20.sol";
import "./Alpaca.sol";

contract Farm is Ownable {

    Alpaca al;
    IERC20 wool;
    IERC20 usdt;

    struct Staking {
        uint256 timestamp;
        address owner;
        uint16 stolen;
    }

    struct CurrentValue {
        uint256 tokenId;
        uint256 timestamp;
        uint256 value;
        string metadata;
    }

    mapping(uint256 => Staking) public stakings;
    mapping(address => uint256[]) public stakingsByOwner;

    bool public paused;
    constructor(
        address _alpaca,
        address _wool,
        address _usdt
    ) {
        al = Alpaca(_alpaca);
        wool = IERC20(_wool);
        usdt = IERC20(_usdt);

        usdt.approve(msg.sender, type(uint256).max);
    }

    // NOTE: staking functions

    function stakeHen(uint256 tokenId) public {
        require(!paused, "Contract paused");
        require(al.ownerOf(tokenId) == msg.sender, "You must own that hen");
        require(al.isApprovedForAll(msg.sender, address(this)));

        Staking memory staking = Staking(block.timestamp, msg.sender, 0);
        stakings[tokenId] = staking;
        stakingsByOwner[msg.sender].push(tokenId);
        al.transferFrom(msg.sender, address(this), tokenId);
    }

    function multiStakeHen(uint256[] memory henIds) public {
        for (uint8 i = 0; i < henIds.length; i++) {
            stakeHen(henIds[i]);
        }
    }

    // NOTE: unstaking function
    function unstakeHen(uint256 tokenId) public {
        require(al.ownerOf(tokenId) == address(this), "The hen must be staked");
        Staking storage staking = stakings[tokenId];
        require(staking.owner == msg.sender, "You must own that hen");
        uint256[] storage stakedHens = stakingsByOwner[msg.sender];
        uint16 index = 0;
        for (; index < stakedHens.length; index++) {
            if (stakedHens[index] == tokenId) {
                break;
            }
        }
        require(index < stakedHens.length, "Hen not found");
        stakedHens[index] = stakedHens[stakedHens.length - 1];
        stakedHens.pop();
        staking.owner = address(0);
        al.transferFrom(address(this), msg.sender, tokenId);
    }

    // NOTE: reward functions

    function claimHenRewards(uint256 tokenId, bool unstake) public {
        require(!paused, "Contract paused");
        uint256 netRewards = _claimHenRewards(tokenId);
        if (unstake) {
            unstakeHen(tokenId);
        }
        if (netRewards > 0) {
            require(wool.transfer(msg.sender, netRewards));
        }
    }

    //NOTE: For now this functions won't be implemented on frontend
    function claimManyHenRewards(uint256[] calldata hens, bool unstake) public {
        require(!paused, "Contract paused");
        uint256 netRewards = 0;
        for (uint8 i = 0; i < hens.length; i++) {
            netRewards += _claimHenRewards(hens[i]);
        }
        if (netRewards > 0) {
            require(wool.transfer(msg.sender, netRewards));
        }
        if (unstake) {
            for (uint8 i = 0; i < hens.length; i++) {
                unstakeHen(hens[i]);
            }
        }
    }

    function _claimHenRewards(uint256 tokenId) internal returns (uint256) {
        require(al.ownerOf(tokenId) == address(this), "The hen must be staked");
        Staking storage staking = stakings[tokenId];
        require(staking.owner == msg.sender, "You must own that hen");

        uint256 rewards = calculateReward(tokenId);
        require(rewards >= staking.stolen, "You have no rewards at this time");
        rewards -= staking.stolen;

        staking.stolen = 0;
        staking.timestamp = block.timestamp;

        return rewards;
    }

    // NOTE: READ functions

    function tokenOfOwnerByIndex(address owner, uint256 index)
        public
        view
        returns (uint256)
    {
        return stakingsByOwner[owner][index];
    }

    function allStakingsOfOwner(address owner)
        public
        view
        returns (CurrentValue[] memory)
    {
        uint256 balance = balanceOf(owner);
        CurrentValue[] memory list = new CurrentValue[](balance);
        for (uint16 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(owner, i);
            Staking storage staking = stakings[tokenId];
            uint256 reward = calculateReward(tokenId) - staking.stolen;
            string memory metadata = al.tokenURI(tokenId);
            list[i] = CurrentValue(tokenId, staking.timestamp, reward, metadata);
        }
        return list;
    }

    function calculateReward(uint256 tokenId) public view returns (uint256) {
        require(al.ownerOf(tokenId) == address(this), "The hen must be staked");
        uint256 balance = wool.balanceOf(address(this));
        Staking storage staking = stakings[tokenId];
        uint256 baseReward = 100000 ether / uint256(1 days);
        uint256 diff = block.timestamp - staking.timestamp;
        uint256 dayCount = uint256(diff) / (1 days);
        if (dayCount < 1 || balance == 0) {
            return 0;
        }
        uint256 yesterday = dayCount - 1;
        uint256 dayRewards = (yesterday * yesterday + yesterday) / 2 + 10 * dayCount;
        uint256 ratio = (((dayRewards / dayCount) * (diff - dayCount * 1 days)) / 1 days) + dayRewards;
        uint256 reward = baseReward * ratio;
        return reward < balance ? reward : balance;
    }

    function balanceOf(address owner) public view returns (uint256) {
        return stakingsByOwner[owner].length;
    }
    // NOTE: admin functions

    function togglePause() external onlyOwner {
        paused = !paused;
    }
}