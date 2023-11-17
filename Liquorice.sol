// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Liquorice is ReentrancyGuard{

    struct LendingPool {
        uint256 interestRate;
        uint256 capital; //in ETH
        uint256 loanDuration;
        uint256 punishmentFee;
        uint256 collateralRatio;
        address[] whitelist;
        address owner;
    }

    address constant borrowETH = address(0);
    address constant lendUSDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174; // Replace with the actual USDC contract address

    mapping(uint256 => LendingPool) public lendingPools;
    uint256 public nextPoolId;

    function createLendingPool(
        uint256 _interestRate,
        uint256 _capital,
        uint256 _loanDuration,
        uint256 _punishmentFee,
        uint256 _collateralRatio,
        address[] memory _whitelist
    ) external payable {

        require(msg.value >= _capital, "Not enough ETH provided");
        require(_punishmentFee <= 100, "Punishment fee cannot exceed 100.");

        LendingPool memory newPool = LendingPool({
            interestRate: _interestRate,
            capital: _capital,
            loanDuration: _loanDuration,
            punishmentFee: _punishmentFee,
            collateralRatio: _collateralRatio,
            whitelist: _whitelist,
            owner: msg.sender
        });

        lendingPools[nextPoolId] = newPool;
        nextPoolId++;
    }

    function withdrawCapital(uint256 poolId, uint256 withdrawAmount) external {
        LendingPool storage pool = lendingPools[poolId];
        require(msg.sender == pool.owner, "Only the pool owner can withdraw capital.");
        require(withdrawAmount <= pool.capital, "Withdrawl request exceeds pool amount.");
        pool.capital -= withdrawAmount;
        payable(pool.owner).transfer(withdrawAmount);
    }

    


}
