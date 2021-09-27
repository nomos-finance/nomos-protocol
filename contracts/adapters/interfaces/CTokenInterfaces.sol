// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;



abstract contract CErc20Interface {
    address public underlying;

    function balanceOf(address owner) external virtual view returns (uint);
    
    function approve(address spender, uint amount) external virtual  returns (bool);

    function liquidateBorrow(address borrower, uint repayAmount, address cTokenCollateral) external virtual returns (uint);

    function redeem(uint redeemTokens) external virtual returns (uint);

}


