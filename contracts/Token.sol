// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is Ownable(msg.sender), ERC20("Token", "TKN") {
    constructor() {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}
