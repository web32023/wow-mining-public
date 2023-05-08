pragma solidity 0.6.12;

contract WowMiningPoolAdminStorage{
    address public admin;
    address public implementation;
}

contract WowMiningPoolStorage is WowMiningPoolAdminStorage{

    struct RoundInfo{
//        This mining round number.
        uint round;
//        The total amount tokens will be mined in this round.
        uint amount;
//        The amount of this round has been mined.
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
