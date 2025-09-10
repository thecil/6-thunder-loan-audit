// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// @audit - info - IThunderLoan is not implemented in ThunderLoan contract.
interface IThunderLoan {
    // @audit - info - functions parameters does not match with the repay function parameters of ThunderLoan contract.
    function repay(address token, uint256 amount) external;
}
