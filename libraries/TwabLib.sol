// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

enum PoolEventType {
    Deposit,
    Withdraw
}

struct PoolEvent {
    PoolEventType eventType;
    uint256 timestamp;
    uint256 cumulativeBalance;
    uint256 balance;
}

library TwabLib {
    function getLastEventIndexUntil(PoolEvent[] storage events, uint256 timestamp)
        internal
        view
        returns (int256)
    {
        int256 lo = -1;
        int256 hi = int256(events.length) - 1;
        while (lo < hi) {
            int256 mid = (hi + lo + 1) / 2;
            if (events[uint256(mid)].timestamp <= timestamp) {
                lo = mid;
            } else {
                hi = mid - 1;
            }
        }
        return lo;
    }

    function getCummulativeBalanceUntil(PoolEvent[] storage events, uint256 timestamp)
        internal
        view
        returns (uint256)
    {
        int256 index = getLastEventIndexUntil(events, timestamp);
        if (index == -1) {
            return 0;
        }
        return events[uint256(index)].cumulativeBalance
            + events[uint256(index)].balance * (timestamp - events[uint256(index)].timestamp);
    }

    function getCummulativeBalanceBetween(PoolEvent[] storage events, uint256 startTime, uint256 endTime)
        internal
        view
        returns (uint256)
    {
        return getCummulativeBalanceUntil(events, endTime) - getCummulativeBalanceUntil(events, startTime);
    }

    function addPoolEvent(PoolEvent[] storage events, PoolEventType eventType, uint256 timestamp, uint256 balance)
        internal
    {
        if (events.length == 0) {
            events.push(PoolEvent({eventType: eventType, timestamp: timestamp, cumulativeBalance: 0, balance: balance}));
        } else {
            uint256 lastCumulativeBalance = events[events.length - 1].cumulativeBalance;
            uint256 lastBalance = events[events.length - 1].balance;
            uint256 lastTimestamp = events[events.length - 1].timestamp;
            uint256 newCumulativeBalance = lastCumulativeBalance + lastBalance * (timestamp - lastTimestamp);
            events.push(
                PoolEvent({
                    eventType: eventType,
                    timestamp: timestamp,
                    cumulativeBalance: newCumulativeBalance,
                    balance: balance
                })
            );
        }
    }
}
