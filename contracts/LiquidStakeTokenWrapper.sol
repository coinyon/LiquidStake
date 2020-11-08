pragma solidity ^0.5.0;

import 'OpenZeppelin/openzeppelin-contracts@2.3.0/contracts/math/Math.sol';
import 'OpenZeppelin/openzeppelin-contracts@2.3.0/contracts/math/SafeMath.sol';
import 'OpenZeppelin/openzeppelin-contracts@2.3.0/contracts/token/ERC721/ERC721.sol';
import 'OpenZeppelin/openzeppelin-contracts@2.3.0/contracts/token/ERC20/SafeERC20.sol';


contract LiquidStakeTokenWrapper {

    using SafeMath for uint256;

    ERC721 public wrappedNFT;
    //constant public yinsure = address(0x181Aea6936B407514ebFC0754A37704eB8d98F91); //yinsure
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

    function stakeToken(uint256 tokenId) public {
        uint stakeShares = 100;

        _owned[msg.sender].push(LiquidStakeToken(tokenId, stakeShares, false));
        _totalStaked = _totalStaked.add(1);
        _adjustedTotalShares = _adjustedTotalShares.add(stakeShares);
        _totalShares = _totalShares.add(stakeShares);
        _myShares[msg.sender] = _myShares[msg.sender].add(stakeShares);
        wrappedNFT.transferFrom(msg.sender, address(this), tokenId);
    }

    function withdrawToken(uint256 tokenId) public {
        for (uint i = 0; i < _owned[msg.sender].length; i++) {
            if (_owned[msg.sender][i].stakeId == tokenId && !_owned[msg.sender][i].withdrawn) {
                _totalStaked = _totalStaked.sub(1);
                _totalShares = _totalShares.sub(_owned[msg.sender][i].shares);
                _adjustedTotalShares = _adjustedTotalShares.sub(_owned[msg.sender][i].shares);
                _myShares[msg.sender] = _myShares[msg.sender].sub(_owned[msg.sender][i].shares);
                _owned[msg.sender][i].withdrawn = true;
                wrappedNFT.transferFrom(address(this), msg.sender, tokenId);

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
                wrappedNFT.transferFrom(address(this), msg.sender, _owned[msg.sender][i].stakeId);
            }
        }
    }
}
