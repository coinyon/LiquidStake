pragma solidity ^0.5.0;

import 'OpenZeppelin/openzeppelin-contracts@2.3.0/contracts/math/Math.sol';
import 'OpenZeppelin/openzeppelin-contracts@2.3.0/contracts/math/SafeMath.sol';
import 'OpenZeppelin/openzeppelin-contracts@2.3.0/contracts/token/ERC721/ERC721.sol';
import 'OpenZeppelin/openzeppelin-contracts@2.3.0/contracts/token/ERC20/SafeERC20.sol';
import './RewardsDistributionRecipient.sol';


contract LiquidStakeTokenWrapper {
    using SafeMath for uint256;

    address constant public yinsure = address(0x181Aea6936B407514ebFC0754A37704eB8d98F91); //yinsure
    struct LiquidStakeToken {
        uint stakeId;
        uint shares;
        bool withdrawn;
    }
    uint256 private _totalStaked;
    uint256 private _totalShares;
    uint256 private _adjustedTotalShares;

    mapping(address => uint256) private _myShares;
    mapping(address => LiquidStakeToken[]) private _owned;

    function totalStaked() public view returns (uint256) {
        return _totalStaked;
    }

    function totalSupply() public view returns (uint256) {
        return _adjustedTotalShares;
    }

    function totalShares() public view returns (uint256) {
        return _totalShares;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _myShares[account];
    }

    function numStaked(address account) public view returns (uint256) {
        uint256 staked = 0;
        for (uint i = 0; i < _owned[account].length; i++) {
            if (!_owned[account][i].withdrawn) {
                staked++;
            }
        }
        return staked;
    }

    function idsStaked(address account) public view returns (uint256[] memory) {
        uint256[] memory staked = new uint256[](numStaked(account));
        uint tempIdx = 0;
        for(uint i = 0; i < _owned[account].length; i++) {
            if(!_owned[account][i].withdrawn) {
                staked[tempIdx] = _owned[account][i].stakeId;
                tempIdx ++;
            }
        }
        return staked;
    }

    function stake(uint256 tokenId) public {
        uint stakeShares = 100;

        _owned[msg.sender].push(LiquidStakeToken(tokenId, stakeShares, false));
        _totalStaked = _totalStaked.add(1);
        _adjustedTotalShares = _adjustedTotalShares.add(stakeShares);
        _totalShares = _totalShares.add(stakeShares);
        _myShares[msg.sender] = _myShares[msg.sender].add(stakeShares);
        ERC721(yinsure).transferFrom(msg.sender, address(this), tokenId);
    }

    function withdraw(uint256 tokenId) public {
        for (uint i = 0; i < _owned[msg.sender].length; i++) {
            if (_owned[msg.sender][i].stakeId == tokenId && !_owned[msg.sender][i].withdrawn) {
                _totalStaked = _totalStaked.sub(1);
                _totalShares = _totalShares.sub(_owned[msg.sender][i].shares);
                _adjustedTotalShares = _adjustedTotalShares.sub(_owned[msg.sender][i].shares);
                _myShares[msg.sender] = _myShares[msg.sender].sub(_owned[msg.sender][i].shares);
                _owned[msg.sender][i].withdrawn = true;
                ERC721(yinsure).transferFrom(address(this), msg.sender, tokenId);

            }
        }
    }

    function withdrawAll() public {
        for (uint i = 0; i < _owned[msg.sender].length; i++) {
            if (!_owned[msg.sender][i].withdrawn) {
                _totalStaked = _totalStaked.sub(1);
                _totalShares = _totalShares.sub(_owned[msg.sender][i].shares);
                _adjustedTotalShares = _adjustedTotalShares.sub(_owned[msg.sender][i].shares);
                _myShares[msg.sender] = _myShares[msg.sender].sub(_owned[msg.sender][i].shares);
                _owned[msg.sender][i].withdrawn = true;
                ERC721(yinsure).transferFrom(address(this), msg.sender, _owned[msg.sender][i].stakeId);
            }
        }
    }
}

contract LiquidStakePool is LiquidStakeTokenWrapper, RewardsDistributionRecipient {
    using SafeERC20 for IERC20;
    IERC20 public safe = IERC20(0x1Aa61c196E76805fcBe394eA00e4fFCEd24FC469);
    uint256 public constant DURATION = 7 days;

    uint256 public initreward = 10000*1e18;
    uint256 public starttime = 1599944400; // 1599944400 => Saturday, September 12, 2020 4:00:00 PM GMT-05:00 DST
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 tokenId);
    event Withdrawn(address indexed user, uint256 tokenId);
    event WithdrawnAll(address indexed user);
    event RewardPaid(address indexed user, uint256 reward);

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

    // stake visibility is public as overriding LiquidStakeTokenWrapper's stake() function
    function stake(uint256 tokenId) public updateReward(msg.sender) checkhalve checkStart{ 
        require(tokenId >= 0, "token id must be >= 0");
        super.stake(tokenId);
        emit Staked(msg.sender, tokenId);
    }

    function stakeMultiple(uint256[] memory tokenIds) public updateReward(msg.sender) checkhalve checkStart{ 
        for (uint i = 0; i < tokenIds.length; i++) {
            require(tokenIds[i] >= 0, "token id must be >= 0");
            super.stake(tokenIds[i]);
            emit Staked(msg.sender, tokenIds[i]);
        }
    }

    function withdraw(uint256 tokenId) public updateReward(msg.sender) checkhalve checkStart{
        require(tokenId >= 0, "token id must be >= 0");
        require(numStaked(msg.sender) > 0, "no ynfts staked");
        super.withdraw(tokenId);
        emit Withdrawn(msg.sender, tokenId);
    }

    function withdrawMultiple(uint256[] memory tokenIds) public updateReward(msg.sender) checkhalve checkStart{
        for (uint i = 0; i < tokenIds.length; i++) {
            require(tokenIds[i] >= 0, "token id must be >= 0");
            super.withdraw(tokenIds[i]);
            emit Withdrawn(msg.sender, tokenIds[i]);
        }
    }

    function withdrawAll() public updateReward(msg.sender) checkhalve checkStart {
        require(numStaked(msg.sender) > 0, "no ynfts staked");
        super.withdrawAll();
        emit WithdrawnAll(msg.sender);
    }

    function exit() external {
        withdrawAll();
        getReward();
    }

    function getReward() public updateReward(msg.sender) checkhalve checkStart {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            safe.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

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
}
