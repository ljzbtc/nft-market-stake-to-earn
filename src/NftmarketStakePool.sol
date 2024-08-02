// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract NftmarketStakePool {
    uint256 public constant PRECISION_FACTOR = 1e18;

    uint256 public totalFeeInPool;
    uint256 public totalStakeAmount;

    uint256 public accumulatedRewardPerToken;

    address public immutable NFTMARKET;

    constructor(address _nftMarketContract) {
        NFTMARKET = _nftMarketContract;
    }

    struct StakeInfo {
        uint256 stakeAmount;
        uint256 rewardDebt;
    }

    mapping(address => StakeInfo) public userToStakeInfo;

    function stake() public payable {
        require(msg.value > 0, "stake amount should be greater than 0");

        _updatePool();

        if (userToStakeInfo[msg.sender].stakeAmount > 0) {
            uint256 pending = ((userToStakeInfo[msg.sender].stakeAmount *
                accumulatedRewardPerToken) / PRECISION_FACTOR) -
                userToStakeInfo[msg.sender].rewardDebt;
            if (pending > 0) {
                payable(msg.sender).transfer(pending);
            }
        }

        totalStakeAmount += msg.value;
        userToStakeInfo[msg.sender].stakeAmount += msg.value;
        userToStakeInfo[msg.sender].rewardDebt =
            (userToStakeInfo[msg.sender].stakeAmount *
                accumulatedRewardPerToken) /
            PRECISION_FACTOR;
    }

    function unstake() public {
        require(
            userToStakeInfo[msg.sender].stakeAmount > 0,
            "no stake to unstake"
        );

        _updatePool();

        uint256 pending = ((userToStakeInfo[msg.sender].stakeAmount *
            accumulatedRewardPerToken) / PRECISION_FACTOR) -
            userToStakeInfo[msg.sender].rewardDebt;
        if (pending > 0) {
            _safeTransfer(msg.sender, pending);
        }

        uint256 amount = userToStakeInfo[msg.sender].stakeAmount;
        totalStakeAmount -= amount;
        userToStakeInfo[msg.sender].stakeAmount = 0;
        userToStakeInfo[msg.sender].rewardDebt = 0;

        _safeTransfer(msg.sender, amount);
    }
    function claimReward() public {
        StakeInfo storage user = userToStakeInfo[msg.sender];
        require(user.stakeAmount > 0, "No stake found");

        _updatePool();

        uint256 pending = ((user.stakeAmount * accumulatedRewardPerToken) /
            PRECISION_FACTOR) - user.rewardDebt;
        require(pending > 0, "No rewards to claim");

        user.rewardDebt =
            (user.stakeAmount * accumulatedRewardPerToken) /
            PRECISION_FACTOR;

        _safeTransfer(msg.sender, pending);
    }

    function _safeTransfer(address to, uint256 amount) internal {
        (bool success, ) = to.call{value: amount}("");
        require(success, "Transfer failed");
    }

    function _updatePool() internal {
        if (totalStakeAmount == 0) {
            return;
        }
        uint256 reward = totalFeeInPool;
        totalFeeInPool = 0;
        accumulatedRewardPerToken +=
            (reward * PRECISION_FACTOR) /
            totalStakeAmount;
    }

    receive() external payable {
        require(
            msg.sender == NFTMARKET,
            "only NftMarket contract can send fee to this contract"
        );
        totalFeeInPool += msg.value;
    }
}
