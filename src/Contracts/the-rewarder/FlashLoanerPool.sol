// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";

/**
 * @title FlashLoanerPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 * @dev A simple pool to get flash loans of DVT
 */
contract FlashLoanerPool is ReentrancyGuard {
    using Address for address;

    DamnValuableToken public immutable liquidityToken;

    error NotEnoughTokensInPool();
    error FlashLoanHasNotBeenPaidBack();
    error BorrowerMustBeAContract();

    constructor(address liquidityTokenAddress) {
        liquidityToken = DamnValuableToken(liquidityTokenAddress);
    }

    function flashLoan(uint256 amount) external nonReentrant {

        //1. Store the token balance of this contract(LoanerPool)
        // 2. if amount > the contract token balance throw err
        //3. if call is not 
        uint256 balanceBefore = liquidityToken.balanceOf(address(this));
        if (amount > balanceBefore) revert NotEnoughTokensInPool();
      
      //@audit 

    //   `isContract` will return false for the following
    //  * types of addresses:
    //  *
    //  *  - an externally-owned account
    //  *  - a contract in construction
    //  *  - an address where a contract will be created
    //  *  - an address where a contract lived, but was destroyed

    // however : This  breaks composability, breaks support for smart wallets
   //  * like Gnosis Safe, and does not provide security since it can be circumvented 
   // by calling from a contract constructor
   
       if (!msg.sender.isContract()) revert BorrowerMustBeAContract();




        liquidityToken.transfer(msg.sender, amount);
//@audit 


// 1. No function existence check: The low-level call doesn't verify
// if the receiveFlashLoan function actually exists in the borrower's contract.
// If it doesn't, the call will still succeed, but no code will be executed.
//
// 2 .There's no guarantee that the function signature matches what's expected.
// If the borrower's contract has a different function signature 
// (e.g., different parameter types), it could lead to unexpected behavior.
// If the call fails for any reason other than running out of gas,
// it will return false rather than reverting. This can make debugging difficult.
//
// 3. A malicious contract could implement the function 
//in an unexpected way, potentially leading to security vulnerabilities.

        msg.sender.functionCall(abi.encodeWithSignature("receiveFlashLoan(uint256)", amount));

        if (liquidityToken.balanceOf(address(this)) < balanceBefore) {
            revert FlashLoanHasNotBeenPaidBack();
        }
    }
}
