// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {RewardToken} from "./RewardToken.sol";

contract StakingEngine is ReentrancyGuard, Ownable {
    IERC20 public immutable stakingToken;
    RewardToken public immutable rewardToken;

    uint256 public rewardRate = 100;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public balances;

    uint256 private _totalSupply;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        rewards[account] = earned(account);
        userRewardPerTokenPaid[account] = rewardPerTokenStored;
        _;
    }

    constructor(address _stakingToken, address _rewardToken) Ownable(msg.sender) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = RewardToken(_rewardToken);
        lastUpdateTime = block.timestamp;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp;
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored
            + (((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / _totalSupply);
    }

    function earned(address account) public view returns (uint256) {
        return ((balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18)
            + rewards[account];
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");

        _totalSupply += amount;
        balances[msg.sender] += amount;
        emit Staked(msg.sender, amount);

        bool success = stakingToken.transferFrom(msg.sender, address(this), amount);
        require(success, "Stake transfer failed");
    }

    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        _withdraw(amount);
    }

    function claimReward() public nonReentrant updateReward(msg.sender) {
        _claimReward();
    }

    function exit() external nonReentrant updateReward(msg.sender) {
        _withdraw(balances[msg.sender]);
        _claimReward();
    }

    function _withdraw(uint256 amount) internal {
        require(amount > 0, "Cannot withdraw 0");
        require(balances[msg.sender] >= amount, "Insufficient staked balance");

        _totalSupply -= amount;
        balances[msg.sender] -= amount;
        emit Withdrawn(msg.sender, amount);

        bool success = stakingToken.transfer(msg.sender, amount);
        require(success, "Withdraw transfer failed");
    }

    function _claimReward() internal {
        uint256 reward = rewards[msg.sender];
        if (reward == 0) {
            return;
        }

        rewards[msg.sender] = 0;
        emit RewardClaimed(msg.sender, reward);

        rewardToken.mint(msg.sender, reward);
    }
}
