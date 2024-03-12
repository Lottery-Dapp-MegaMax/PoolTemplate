// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AbstractPool.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract MyPool is AbstractPool {
    constructor(address vaultAddress, IERC20 asset_) 
        AbstractPool(vaultAddress, asset_) 
    {
        // constructor body
    }

    function getWinnerWithRandomNumber(address[] memory players, uint256[] memory shares, uint256 totalPrize, uint256 randomNumber) public override pure returns (Winner[] memory) {
        Winner[] memory winners = new Winner[](players.length);
        uint256 totalShares = 0;
        for (uint256 i = 0; i < players.length; i++) {
            totalShares += shares[i];
        }
        for (uint256 i = 0; i < players.length; i++) {
            winners[i].player = players[i];
            winners[i].prize = (shares[i] * totalPrize) / totalShares;
        }
        return winners;
    }
}  