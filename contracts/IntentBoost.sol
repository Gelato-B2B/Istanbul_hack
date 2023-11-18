// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IChainlinkAggregator {
    function latestAnswer() external view returns (int256);
}

contract intentBoost {

    struct LendingPool {
        uint256 interestRate;
        uint256 capital; //in ETH
        uint256 loanDuration;
        uint256 liquidationThreshold;
        uint256 collateralRatio;
        address[] whitelist;
        address owner;
    }

    struct borrowers {
        uint256 collateral;
        uint256 lockedCollateral;
    }

    struct Order {
        uint256 amountIn;
        uint256 amountOut;
        uint256 validTo;
        address maker;
        bytes uid;
    }

    struct liquidationMarket {
        address lender;
        address borrower;
        uint256 borrowedETH;
        uint256 lockedColalteral;
        uint256 loanDuration;
        uint256 liquidationPrice;
    }

    address constant lockUSDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

    mapping(uint256 => LendingPool) public lendingPools;
    mapping(address => borrowers) public poolBorrowers;
    mapping(bytes32 => bool) public invalidatedOrders;
    mapping(uint256 => liquidationMarket) public liquidationMarkets;

    uint256 public nextPoolId;
    uint256 public nextMarket;

    bytes32 immutable DOMAIN_SEPARATOR;

    bytes32 constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 constant ORDER_TYPEHASH = keccak256(
        "Order(uint256 amountIn,uint256 amountOut,address maker,bytes uid)"
    );

    constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256("intentBoost"), // contract name
                keccak256("1"), // Version
                block.chainid,
                address(this)
            )
        );
    }





//-----------------------------------------------------------------------------------------------------
//------Main functions---------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------

    function createLendingPool(
        uint256 _interestRate,
        uint256 _capital,
        uint256 _loanDuration,
        uint256 _liquidationThreshold,
        uint256 _collateralRatio,
        address[] memory _whitelist
    ) external payable {

        require(msg.value >= _capital, "Not enough ETH provided");
        require(_liquidationThreshold <= 100, "Punishment fee cannot exceed 100.");
        require(_collateralRatio <= 100, "Collateral ratio must be below 100.");
        require(_collateralRatio >= 1, "Collateral ratio must be higher than 1.");

        LendingPool memory newPool = LendingPool({
            interestRate: _interestRate,
            capital: _capital,
            loanDuration: _loanDuration,
            liquidationThreshold: _liquidationThreshold,
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

    //taker is calling the function
    function settlement(Order memory _order, bytes memory _signature, uint256 _poolID) external payable {
        //Checks
        bytes32 orderhash = _hashOrder(_order);
        address recsigner = recoverSigner(orderhash, _signature);
        require(recsigner == _order.maker, "Ivalid signature");
        uint256 collateral = _order.amountOut * lendingPools[_poolID].collateralRatio / 100;
        require(poolBorrowers[_order.maker].collateral - poolBorrowers[_order.maker].lockedCollateral >=
        collateral, "Not enough collateral");

        //Invalidating the quote
        _invalidateOrder(orderhash);

        //Recording borrowing
        recordBorrowing(_order, collateral, _poolID);

        // swap
        payable(msg.sender).transfer(_order.amountOut);
        IERC20 usdcToken = IERC20(lockUSDC);
        require(usdcToken.transferFrom(msg.sender, address(this), _order.amountIn), "Transfer failed.");
    }


    function recordBorrowing(Order memory _order, uint256 _collalteral, uint256 _poolID) internal {
        liquidationMarkets[nextMarket].lender = msg.sender;
        liquidationMarkets[nextMarket].borrower = _order.maker;
        liquidationMarkets[nextMarket].borrowedETH = _order.amountIn;
        liquidationMarkets[nextMarket].lockedColalteral = _collalteral;
        liquidationMarkets[nextMarket].loanDuration = lendingPools[_poolID].loanDuration;
        liquidationMarkets[nextMarket].liquidationPrice = getEthUsdPrice() * lendingPools[_poolID].liquidationThreshold / 100;

        poolBorrowers[_order.maker].lockedCollateral += _collalteral;
        nextMarket++;
    }

    function liquidate(uint256 _marketID) external {
        require(msg.sender == liquidationMarkets[_marketID].lender, "Only lenders can liquidate");
        if (block.timestamp > liquidationMarkets[_marketID].loanDuration) {
            poolBorrowers[liquidationMarkets[_marketID].borrower].lockedCollateral -= liquidationMarkets[_marketID].lockedColalteral;
            IERC20 usdcToken = IERC20(lockUSDC);
            require(usdcToken.transferFrom(address(this), msg.sender, liquidationMarkets[nextMarket].lockedColalteral), "Transfer failed.");
            delete liquidationMarkets[nextMarket];
        }else {
            require(getEthUsdPrice() < liquidationMarkets[nextMarket].liquidationPrice, "Liquidation threshold not breached");
            poolBorrowers[liquidationMarkets[_marketID].borrower].lockedCollateral -= liquidationMarkets[_marketID].lockedColalteral;
            IERC20 usdcToken = IERC20(lockUSDC);
            require(usdcToken.transferFrom(address(this), msg.sender, liquidationMarkets[nextMarket].lockedColalteral), "Transfer failed.");
            delete liquidationMarkets[nextMarket];
        }
    }

    function repay(uint256 marketId) external payable {
        liquidationMarket storage market = liquidationMarkets[marketId];
        require(msg.sender == market.borrower, "Only the borrower can repay the loan");

        uint256 totalDue = market.borrowedETH;

        require(msg.value >= totalDue, "Insufficient amount to cover the loan");

        if (msg.value > totalDue) {
            payable(msg.sender).transfer(msg.value - totalDue);
        }

        borrowers storage borrower = poolBorrowers[market.borrower];
        borrower.lockedCollateral -= market.lockedColalteral;
        delete liquidationMarkets[marketId];

        IERC20 usdcToken = IERC20(lockUSDC);
        require(usdcToken.transferFrom(address(this), msg.sender, market.lockedColalteral), "Collateral return failed");
    }





//----------------------------------------------------------------------------------------------------
//------Supplimentary functions-----------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------

    function _invalidateOrder(bytes32 _hash) internal {
        require(!invalidatedOrders[_hash], "Invalid Order");
        invalidatedOrders[_hash] = true;
    }

   //hashes order data
    function _hashOrder(Order memory _order) public pure returns (bytes32) {
        return keccak256(abi.encode(
            ORDER_TYPEHASH,
            _order.amountIn,
            _order.amountOut,
            _order.maker,
            _order.uid
        ));
    }

    //generates final hash including domain separator to be signed by maker from received order hash
    function getEthSignedMessageHash(bytes32 _orderHash)
        public
        view
        returns (bytes32 hash)
    {
        return keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            _orderHash
        ));
    }

    //view function that can be called by test maker to generate hash that maker has to sign
    function generateEIP712Hash(Order memory _order) public view returns (bytes32) {
        return getEthSignedMessageHash(_hashOrder(_order));
    }

    function recoverSigner(
        bytes32 _hash,
        bytes memory signature
    ) public view returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        bytes32 messageHash = getEthSignedMessageHash(_hash);

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        return ecrecover(messageHash, v, r, s);
    }

    function getEthUsdPrice() internal view returns(uint256) {
        // mainnet
        // address source = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

        // sepoila
        // address source = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

        // goerli
        address source = 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e;

        IChainlinkAggregator ethUsdPriceFeed = IChainlinkAggregator(source);
        int256 ethUsdPrice = ethUsdPriceFeed.latestAnswer();
        return uint256(ethUsdPrice);
    }

    receive() external payable {}

}
