// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {PoolEvent, PoolEventType, TwabLib} from "../libraries/TwabLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

abstract contract AbstractPool is Ownable, ERC4626 {
    using EnumerableSet for EnumerableSet.AddressSet;
    using TwabLib for PoolEvent[];

    uint256 public runningTime;
    uint256 public startedTime;
    uint256 public endingTime;
    uint256 public createdTime;
    uint256 public numDrawBefore;
    bool private lastDraw = true;
    mapping(address owner => PoolEvent[]) public poolEvents;
    EnumerableSet.AddressSet private depositors;

    struct Winner {
        address player;
        uint256 prize;
    }

    constructor(address poolManager, IERC20 asset_) Ownable(poolManager) ERC4626(asset_) ERC20("LotteryPool", "LP") {
        runningTime = 0;
        numDrawBefore = 0;
        createdTime = block.timestamp;
    }

    function startLottery(uint256 _runningTime) public onlyOwner {
        if (runningTime > 0) {
            require(block.timestamp >= endingTime, "Lottery is running");
            require(lastDraw == true, "Last draw is not finished");
            _runningTime = runningTime; // keep the same running time
        }
        startedTime = block.timestamp;
        runningTime = _runningTime;
        endingTime = startedTime + runningTime;
        lastDraw = false;
    }

    function getLastDraw() public view returns (bool) {
        return lastDraw;
    }

    function setLastDraw() public onlyOwner {
        require(lastDraw == false, "Last draw is not finished");
        lastDraw = true;
        ++ numDrawBefore;
    }

    function getWinnerWithRandomNumber(address[] memory players, uint256[] memory shares, uint256 totalPrize, uint256 randomNumber) public virtual pure returns (Winner[] memory) {
    }

    function getWinner(uint256 totalPrize, uint256 randomNumber) public view onlyOwner returns (Winner[] memory) {
        require(block.timestamp >= endingTime, "Lottery is not finished");
        address[] memory players = getDepositors();
        uint256[] memory shares = new uint256[](players.length);
        for (uint256 i = 0; i < players.length; i++) {
            shares[i] = getCurrentCumulativeBalance(players[i]);
        }
        Winner[] memory winners = getWinnerWithRandomNumber(players, shares, totalPrize, randomNumber); 
        require(winners.length == players.length, "Invalid winner");
        for (uint256 i = 0; i < winners.length; i++) {
            require(winners[i].player == players[i], "Invalid winner");
        }
        return winners;
    }

    function totalDeposit() public view returns (uint256) {
        uint256 total = IERC20(asset()).balanceOf(address(this));
        return total;
    }

    function deposit(uint256 assets, address receiver) public override onlyOwner returns (uint256 shares) {
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }
        shares = previewDeposit(assets);
        _mint(receiver, shares);
        poolEvents[receiver].addPoolEvent(PoolEventType.Deposit, block.timestamp, balanceOf(receiver));
        depositors.add(receiver);
    }

    function withdraw(uint256 assets, address, address owner) public override returns (uint256 shares) {                
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }
        shares = previewWithdraw(assets);
        _burn(owner, shares);
        poolEvents[owner].addPoolEvent(PoolEventType.Withdraw, block.timestamp, balanceOf(owner));
        approveTransferAsset(assets);
    }

    function getCumulativeBalanceBetween(address owner, uint256 startTime, uint256 endTime) public view returns (uint256) {
        return poolEvents[owner].getCummulativeBalanceBetween(startTime, endTime);
    }

    function getCurrentCumulativeBalance(address owner) public view returns (uint256) {
        return poolEvents[owner].getCummulativeBalanceBetween(startedTime, endingTime);
    }

    function getTotalCumulativeBalance() public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < depositors.length(); ++ i) {
            address owner = depositors.at(i);
            total += getCurrentCumulativeBalance(owner);
        }
        return total;
    }

    function getDepositors(uint256 startTime, uint256 endTime) public view returns (address[] memory) {
        uint256 Count = 0;
        for (uint256 i = 0; i < depositors.length(); ++ i) {
            address owner = depositors.at(i);
            if (getCumulativeBalanceBetween(owner, startTime, endTime) > 0) {
                Count ++;                
            }
        }
        address[] memory listDepositors = new address[](Count);
        Count = 0;

        for (uint256 i = 0; i < depositors.length(); ++ i) {
            address owner = depositors.at(i);
            if (getCumulativeBalanceBetween(owner, startTime, endTime) > 0) {
                listDepositors[Count ++] = owner;                
            }
        }
        return listDepositors;
    }

    function getDepositors() public view returns (address[] memory) {
        return getDepositors(startedTime, endingTime);
    }

    function approveTransferAsset(uint256 amount) public {
        IERC20 asset = IERC20(asset());
        asset.approve(owner(), amount);
    }

    function mint(address receiver, uint256 amount) public onlyOwner {
        uint256 shares = convertToShares(amount); 
        _mint(receiver, shares);
    }
}