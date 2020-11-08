pragma solidity ^0.5.0;

import 'OpenZeppelin/openzeppelin-contracts@2.3.0/contracts/math/Math.sol';
import 'OpenZeppelin/openzeppelin-contracts@2.3.0/contracts/math/SafeMath.sol';
import 'OpenZeppelin/openzeppelin-contracts@2.3.0/contracts/token/ERC20/ERC20Detailed.sol';
import 'OpenZeppelin/openzeppelin-contracts@2.3.0/contracts/token/ERC20/SafeERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@2.3.0/contracts/utils/ReentrancyGuard.sol';
import './RewardsDistributionRecipient.sol';
import './LiquidStakeTokenWrapper.sol';


// Inheritance
import "./RewardsDistributionRecipient.sol";
import "./Pausable.sol";


contract LiquidStakePool is LiquidStakeTokenWrapper, RewardsDistributionRecipient, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public rewardsToken;
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public rewardsDuration = 7 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    constructor(
        address _owner,
        address _rewardsDistribution,
        address _rewardsToken,
        address _stakingToken
    ) public Owned(_owner) {
        rewardsToken = IERC20(_rewardsToken);
        rewardsDistribution = _rewardsDistribution;
        wrappedNFT = ERC721(_stakingToken);
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(_totalSupply)
            );
    }

    function earned(address account) public view returns (uint256) {
        return _balances[account].mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(rewards[account]);
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate.mul(rewardsDuration);
    }

    /*
    function stake(uint256 amount) external nonReentrant notPaused updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }
    */

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    function notifyRewardAmount(uint256 reward) external onlyRewardsDistribution updateReward(address(0)) {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(rewardsDuration);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(rewardsDuration);
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint balance = rewardsToken.balanceOf(address(this));
        require(rewardRate <= balance.div(rewardsDuration), "Provided reward too high");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(rewardsDuration);
        emit RewardAdded(reward);
    }

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        // If it's SNX we have to query the token symbol to ensure its not a proxy or underlying
        bool isSNX = (keccak256(bytes("SNX")) == keccak256(bytes(ERC20Detailed(tokenAddress).symbol())));
        // Cannot recover the staking token or the rewards token
        require(
            tokenAddress != address(rewardsToken) && !isSNX,
            "Cannot withdraw the rewards tokens"
        );
        IERC20(tokenAddress).safeTransfer(owner, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
        require(block.timestamp > periodFinish,
            "Previous rewards period must be complete before changing the duration for the new period"
        );
        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(rewardsDuration);
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event Recovered(address token, uint256 amount);













    // IERC20 public safe = IERC20(0x1Aa61c196E76805fcBe394eA00e4fFCEd24FC469);
    uint256 public constant DURATION = 7 days;

    uint256 public initreward = 10000*1e18;
    uint256 public starttime = 1599944400; // 1599944400 => Saturday, September 12, 2020 4:00:00 PM GMT-05:00 DST
    //uint256 public periodFinish = 0;
    //uint256 public rewardRate = 0;
    //uint256 public lastUpdateTime;
    //uint256 public rewardPerTokenStored;
    //mapping(address => uint256) public userRewardPerTokenPaid;
    //mapping(address => uint256) public rewards;

    //event RewardAdded(uint256 reward);
    //event Staked(address indexed user, uint256 tokenId);
    //event Withdrawn(address indexed user, uint256 tokenId);
    event WithdrawnAll(address indexed user);
    //event RewardPaid(address indexed user, uint256 reward);

    /*
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }


    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(totalSupply())
            );
    }

    function earned(address account) public view returns (uint256) {
        return
            balanceOf(account)
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(rewards[account]);
    }
    */

    // stake visibility is public as overriding LiquidStakeTokenWrapper's stake() function
    function stake(uint256 tokenId) public updateReward(msg.sender) checkhalve checkStart{ 
        require(tokenId >= 0, "token id must be >= 0");
        stakeToken(tokenId);
        emit Staked(msg.sender, tokenId);
    }

    function stakeMultiple(uint256[] memory tokenIds) public updateReward(msg.sender) checkhalve checkStart{ 
        for (uint i = 0; i < tokenIds.length; i++) {
            require(tokenIds[i] >= 0, "token id must be >= 0");
            super.stakeToken(tokenIds[i]);
            emit Staked(msg.sender, tokenIds[i]);
        }
    }

    function withdraw(uint256 tokenId) public updateReward(msg.sender) checkhalve checkStart{
        require(tokenId >= 0, "token id must be >= 0");
        require(numStaked(msg.sender) > 0, "no ynfts staked");
        super.withdrawToken(tokenId);
        emit Withdrawn(msg.sender, tokenId);
    }

    function withdrawMultiple(uint256[] memory tokenIds) public updateReward(msg.sender) checkhalve checkStart{
        for (uint i = 0; i < tokenIds.length; i++) {
            require(tokenIds[i] >= 0, "token id must be >= 0");
            super.withdrawToken(tokenIds[i]);
            emit Withdrawn(msg.sender, tokenIds[i]);
        }
    }

    function withdrawAll() public updateReward(msg.sender) checkhalve checkStart {
        require(numStaked(msg.sender) > 0, "no ynfts staked");
        super.withdrawAll();
        emit WithdrawnAll(msg.sender);
    }
    /*

    function exit() external {
        withdrawAll();
        getReward();
    }

    function getReward() public updateReward(msg.sender) checkhalve checkStart {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            // TODO safe.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    */
    modifier checkhalve(){
        if (block.timestamp >= periodFinish) {
            initreward = initreward.mul(50).div(100); 
            // TODO safe.mint(address(this),initreward);

            rewardRate = initreward.div(DURATION);
            periodFinish = block.timestamp.add(DURATION);
            emit RewardAdded(initreward);
        }
        _;
    }

    modifier checkStart(){
        require(block.timestamp > starttime,"not start");
        _;
    }

    /*
    function notifyRewardAmount(uint256 reward)
        external
        onlyRewardsDistribution
        updateReward(address(0))
    {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(DURATION);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(DURATION);
        }
        // TODO safe.mint(address(this),reward);
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(DURATION);
        emit RewardAdded(reward);
    }
    */
}
