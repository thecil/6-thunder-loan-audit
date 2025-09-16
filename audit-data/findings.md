| File                         | nSLOC | Complexity Score | audited |
|------------------------------|-------|------------------|---------|
| src/interfaces/ITSwapPool.sol  | 3     | 3                | checked |
| src/interfaces/IThunderLoan.sol  | 3     | 3                | checked |
| src/interfaces/IPoolFactory.sol  | 3     | 3                | checked |
| src/interfaces/IFlashLoanReceiver.sol | 4    | 3                | checked |
| src/protocol/OracleUpgradeable.sol | 23   | 18               | checked |
| src/protocol/AssetToken.sol      | 65    | 41               | checked |
| src/upgradedProtocol/ThunderLoanUpgraded.sol | 189  | 127              |
| src/protocol/ThunderLoan.sol     | 193   | 129              |


## Findings

## HIGH

### [H-1] - Erroneus `ThunderLoan::updateExchangeRate` in the `deposit` function causes protocol to think it has more fees than it really does, which blocks redemption and incorrectly set the exchange rate.

**Description**: In the ThunderLoan system, the `exchangeRate` is responsible for calculating the exchange rate between assetTokens and underlying tokens.In a way, it's responsible for keepin thrack of how many fees to give to liquidity providers.

However, the `deposit` function, updates this rate without collecting any fees, by doing this, the `redeem` function will think it has more fees than it really does, which blocks redemption and incorrectly set the exchange rate.

```solidity
    function deposit(IERC20 token, uint256 amount) external revertIfZero(amount) revertIfNotAllowedToken(token) {
        AssetToken assetToken = s_tokenToAssetToken[token];
        uint256 exchangeRate = assetToken.getExchangeRate();
        uint256 mintAmount = (amount * assetToken.EXCHANGE_RATE_PRECISION()) / exchangeRate;
        emit Deposit(msg.sender, token, amount);
        assetToken.mint(msg.sender, mintAmount);
@>      uint256 calculatedFee = getCalculatedFee(token, amount);
@>      assetToken.updateExchangeRate(calculatedFee);
        token.safeTransferFrom(msg.sender, address(assetToken), amount);
    }
```

**Impact**: There are several impacts to this bug.

1. The `redeem` function is blocked because the protocol thinks the owed tokens is more than it has, preventing users from redeeming their tokens.

2. Rewards are incorrectly calculated, leading to liquidity providers potentially getting way more or less than deserved.

**Proof of Concept**: 

1. LP deposits.
2. User takes a flashloan.
3. It is now impossible for LP to redeem.

<details>
<summary>Proof of Code</summary>

Place the following into `TunderLoanTest.t.sol` and execute the unit test.

```solidity
    function test_redeemAfterLoan() public setAllowedToken hasDeposits {
        // copy/paste from testFlashLoan()
        uint256 amountToBorrow = AMOUNT * 10;
        uint256 calculatedFee = thunderLoan.getCalculatedFee(
            tokenA,
            amountToBorrow
        );
        vm.startPrank(user);
        tokenA.mint(address(mockFlashLoanReceiver), calculatedFee);
        thunderLoan.flashloan(
            address(mockFlashLoanReceiver),
            tokenA,
            amountToBorrow,
            ""
        );
        vm.stopPrank();

        uint256 amountToRedeem = type(uint256).max;
        vm.startPrank(liquidityProvider);
        thunderLoan.redeem(tokenA, amountToRedeem);
        vm.stopPrank();
    }
```
</details>

**Recommended Mitigation**: Remove the incorrectly updated exchange rate lines from the `deposit` function.

```diff
    function deposit(IERC20 token, uint256 amount) external revertIfZero(amount) revertIfNotAllowedToken(token) {
        AssetToken assetToken = s_tokenToAssetToken[token];
        uint256 exchangeRate = assetToken.getExchangeRate();
        uint256 mintAmount = (amount * assetToken.EXCHANGE_RATE_PRECISION()) / exchangeRate;
        emit Deposit(msg.sender, token, amount);
        assetToken.mint(msg.sender, mintAmount);
-       uint256 calculatedFee = getCalculatedFee(token, amount);
-       assetToken.updateExchangeRate(calculatedFee);
        token.safeTransferFrom(msg.sender, address(assetToken), amount);
    }
```

## MEDIUM

### [M-2] - Using TSwap as price oracle leads to price and oracle manipulation attacks 

**Description**: The TSwap protocol is a constant product formula based AMM (automated market maker). The price of a token is determined by how many reservers are on either side of the pool. Because of this, it is easy for malicious users to manipulate the price of a token by buying or selling a large amount of the token in the same transaction, essentially ignoring protocol fees.

**Impact**: Liquidity providers will drastically reduced fees for providint liquidity.

**Proof of Concept**: 

The following all happens in 1 transaction.

1. User takes a flash loan from `ThunderLoan` from 1000 `tokenA`. They are charged the original fee `fee1`. During the flash loan, they do the following:
    1. User sells 1000 `tokenA`, tanking the price.
    2. Instead of repaying right away, the user takes out another flash loan for another 1000 `tokenA`.
        1. Due the fact that the way `ThunderLoan` calculates price based on the `TSwapPool` this second flash loan is substantially cheaper.

```solidity
    function getPriceInWeth(address token) public view returns (uint256) {
        address swapPoolOfToken = IPoolFactory(s_poolFactory).getPool(token);
        return ITSwapPool(swapPoolOfToken).getPriceOfOnePoolTokenInWeth();
    }
```
    3. The user then repays the first flash loan, and then repays the second flash loan.

Check the unit test `ThunderLoanTest::test_oracleManipulation` as proof of code for this bug. 

**Recommended Mitigation**: Consider using a different price oracle mechanism, like a Chainlink price feed with a Uniswap TWAP fallback oracle.

## LOW

## INFORMATIONAL

## GAS

### [I-1] - 

**Description**:

**Impact**:

**Proof of Concept**: (Proof of Code)

**Recommended Mitigation**: 