// SPDX-License-Identifier: MIT
pragma solidity ^0.6.10;

import 'OpenZeppelin/openzeppelin-contracts@3.0.0/contracts/token/ERC20/ERC20.sol';

contract LiquidStakeDAO is ERC20 {
    constructor (string memory name, string memory symbol)
        ERC20(name, symbol)
        public
    {
        _mint(msg.sender, 1000 * 1000 * 10 ** uint(decimals()));
    }
}
