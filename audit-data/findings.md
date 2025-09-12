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

## LOW

## INFORMATIONAL

## GAS

### [I-1] - 

**Description**:

**Impact**:

**Proof of Concept**: (Proof of Code)

**Recommended Mitigation**: 