// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract WowMiningPoolAdminStorage{
    address public admin;
    address public implementation;
    /**
     * @dev storage gaps
     */
    uint256[49] __gap;
}


contract WowMiningPoolStorage is WowMiningPoolAdminStorage{

    struct RoundInfo{

        /**
         * @dev This mining round number
         */
        uint round;
        /**
         * @dev The total amount tokens will be mined in this round.
         */
        uint amount;
        /**
         * @dev  The amount of this round has been mined.
         */
        uint debt;
    }

    /**
     * @dev  Operator permission list
     */
    mapping(address=>bool) public operator;

    /**
     * @dev  The recipient address,When a certain amount of mining is reached, a token will be sent to this address
     */
    address public receiver;

    /**
     * @dev The number of current mining round.
     */
    uint public currentRound;

    /**
     * @dev The token contract address for mining.
     */
    address public token;

    /**
     * @dev The mined rounds history list.
     */
    RoundInfo[] public roundInfos;

    /**
     * @dev The total amount of given token to be mined.
     */
    uint256 public totalAmount;

    /**
     * @dev The block number to start mining.
     */
    uint256 public startBlock;

    /**
     * @dev Amount per operation.
     */
    uint256 public perOperateAmount;

}
