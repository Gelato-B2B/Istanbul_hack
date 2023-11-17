// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

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

    struct borrowers {
        uint256 collateral;
        uint256 lockedCollateral;
    }

    address constant lockUSDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

    mapping(uint256 => LendingPool) public lendingPools;
    mapping(address => borrowers) public poolBorrowers;

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
        require(_collateralRatio <= 100, "Collateral ratio must be below 100.");
        require(_collateralRatio >= 1, "Collateral ratio must be higher than 1.");

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

    function depositCollateral(uint256 amount) public {
        require(amount > 0, "Amount must be greater than 0");
        IERC20 usdcToken = IERC20(lockUSDC);
        require(usdcToken.transferFrom(msg.sender, address(this), amount), "Transfer failed.");
        poolBorrowers[msg.sender].collateral += amount;
    }

    function withdrawCollateral(uint256 amount) public {
        require(amount > 0, "amount needs to be higher than zero");
        require(poolBorrowers[msg.sender].collateral - poolBorrowers[msg.sender].lockedCollateral > amount, "Not enough available collateral");
        poolBorrowers[msg.sender].collateral -= amount;
        IERC20 usdcToken = IERC20(lockUSDC);
        require(usdcToken.transferFrom(address(this), msg.sender, amount), "Transfer failed.");
    }


}
