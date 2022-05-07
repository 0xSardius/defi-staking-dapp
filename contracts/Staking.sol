// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error Staking__TransferFailed();
error Staking__NeedsMoreThanZero();

contract Staking {

    IERC20 public s_stakingToken;
    IERC20 public s_rewardToken;

    // someones address mapped to how much they staked
    mapping(address => uint256) public s_balances;

    // mapping of how much each address has been paid
    mapping(address => uint256) public s_userRewardPerTokenPaid;

    // mapping of how much rewards each address has to claim
    mapping(address => uint256) public s_rewards;

    uint256 public constant REWARD_RATE = 100;
    uint256 public s_totalSupply;
    uint256 public s_rewardPerTokenStored;
    uint256 public s_lastUpdateTime;

    modifier updateReward(address account) {
        // how much reward per token?
        // last timestamp
        // 12pm - 1pm, user earned X tokens
        s_rewardPerTokenStored = rewardPerToken();
        s_lastUpdateTime = block.timestamp;
        s_rewards[account] = earned(account);
        s_userRewardPerTokenPaid[account] = s_rewardPerTokenStored;
        _;
    }

    modifier moreThanZero(uint256 amount) {
        if(amount == 0) {
            revert Staking__NeedsMoreThanZero();
        }
        _;
    }

    constructor (address stakingToken, address rewardToken) {
        s_stakingToken = IERC20(stakingToken);
        s_rewardToken = IERC20(rewardToken);
    }

    function earned(address account) public view returns(uint256) {
        uint256 currentBalance = s_balances[account];
        // how much they have been paid already
        uint256 amountPaid = s_userRewardPerTokenPaid[account];
        uint256 currentRewardPerToken = rewardPerToken();
        uint256 pastRewards = s_rewards[account];

        uint256 _earned = ((currentBalance * (currentRewardPerToken - amountPaid)) / 1e18) + pastRewards;
        return _earned;
    }

    function rewardPerToken() public view returns(uint256) {
        if (s_totalSupply == 0) {
            return s_rewardPerTokenStored;
        }
        return s_rewardPerTokenStored + (((block.timestamp - s_lastUpdateTime) * REWARD_RATE * 1e18)/ s_totalSupply);
    }

    // stake: Lock tokens into the smart contract
    // Just a specific token
    // Improvement: Chainlink stuff to convert prices between tokens
    function stake(uint256 amount) external updateReward(msg.sender) moreThanZero(amount) {
        // keep track of how much this user has staked

        // keep track of how much token we have total
        // transfer the tokens to this contract
        s_balances[msg.sender] = s_balances[msg.sender] + amount;
        s_totalSupply = s_totalSupply + amount;
        // emit event here
       bool success = s_stakingToken.transferFrom(msg.sender, address(this), amount);
       // Note: Doing a regular revert msg with a string is gas intensive. Using our own saves gas.
       // require(success, "Failed");
       if(!success) {
           revert Staking__TransferFailed();
       }
    }

    // withdraw a token 
    function withdraw(uint256 amount) external updateReward(msg.sender) moreThanZero(amount) {
        s_balances[msg.sender] = s_balances[msg.sender] - amount;
        s_totalSupply = s_totalSupply - amount;
        bool success = s_stakingToken.transfer(msg.sender, amount);
        if (!success) {
            revert Staking__TransferFailed();
        }
    }

    function claimReward() external updateReward(msg.sender) {
        uint256 reward = s_rewards[msg.sender];
        bool success = s_rewardToken.transfer(msg.sender, reward);
        if (!success) {
            revert Staking__TransferFailed();
        }
        // How much reward do they get?
        // Each implementation of staking will be diff with a diff reward mechanism
        // The contract is going to emit X tokens per second
        // and disperse them to all token stakers

    }
}



// withdraw: unlock tokens and pull out of the contract
// claimReward: users get their reward tokens
// What's a good reward mechanism?
// What's some good reward math?