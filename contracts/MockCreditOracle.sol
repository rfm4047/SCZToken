// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICreditOracle {
    function getCreditScore(address user) external view returns (uint256);
}

contract MockCreditOracle is ICreditOracle {
    uint256 private score;

    function setScore(uint256 _score) external {
        score = _score;
    }

    function getCreditScore(address /*user*/) external view override returns (uint256) {
        return score;
    }
}
