// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../libraries/ERC20.sol";

contract MockToken is ERC20 {
    constructor (string memory name, string memory symbol,uint256 supply) ERC20(name, symbol) {
        _mint(msg.sender, supply);
    }

    function mint(address to, uint256 amount) public{
        _mint(to, amount);
    }



}
