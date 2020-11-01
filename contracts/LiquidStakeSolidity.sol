pragma solidity ^0.6.6;

import 'OpenZeppelin/openzeppelin-contracts@3.0.0/contracts/token/ERC721/ERC721.sol';

import 'interfaces/IHEX.sol';
import 'interfaces/IStakingRewards.sol';

contract LiquidStakeSolidity is ERC721 {
    IHEX hex_contract;
    address immutable rewards;
    address immutable owner;

    constructor(string memory name, string memory symbol, address hex_address, address rewards_address)
        ERC721(name, symbol)
        public
    {
        hex_contract = IHEX(hex_address);
        owner = msg.sender;
        rewards = rewards_address;
    }

    modifier restricted() {
        if (msg.sender == owner) _;
    }

    function stake(uint256 newStakedHearts, uint256 newStakedDays)
        external
    {
        hex_contract.transferFrom(msg.sender, address(this), newStakedHearts);
        hex_contract.stakeStart(newStakedHearts, newStakedDays);
        uint256 stake_length = hex_contract.stakeCount(address(this));
        assert(stake_length > 0);
        (uint40 stakeId, uint72 stakedHearts, uint72 stakeShares, uint16
         lockedDay, uint16 stakedDays, uint16 unlockedDay, bool isAutoStake) =
           hex_contract.stakeLists(address(this), stake_length - 1);
        _safeMint(msg.sender, uint256(stakeId));
    }

    function endStake(uint256 stakeIndex, uint40 stakeIdParam)
        external
    {
        require(ownerOf(uint256(stakeIdParam)) == msg.sender);
        uint256 hexAmountPre = hex_contract.balanceOf(address(this));
        hex_contract.stakeEnd(stakeIndex, stakeIdParam);
        uint256 hexAmountPost = hex_contract.balanceOf(address(this));
        uint256 stakeReturn = hexAmountPost - hexAmountPre;
        uint256 fee = stakeReturn / 2000; // 0.05 %
        hex_contract.transfer(msg.sender, stakeReturn - fee);
        _burn(uint256(stakeIdParam));
    }

    function pushRewards() external
    {
       uint256 amt = hex_contract.balanceOf(address(this));
       hex_contract.transfer(rewards, amt);
       IStakingRewards(rewards).notifyRewardAmount(amt);
    }
}
