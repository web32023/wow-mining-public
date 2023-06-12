// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../libraries/IERC20.sol";
import "../libraries/SafeERC20.sol";
import "./WowMiningPoolStorage.sol";

contract WowMiningPoolDelegate is WowMiningPoolStorage {
    using SafeERC20 for IERC20;

    //    ===================================Events=================================
    /**
     * @dev When result is true mean successfully added or removed,otherwise, the operation will fail
     */
    event AddOperator(
        address indexed operator,
        bool result
    );

    event RemoveOperator(
        address indexed operator,
        bool result
    );

    event SetReceiver(
        address indexed receiver
    );

    event Withdraw(
        address indexed receiver,
        address token,
        uint256 amount,
        uint256 round
    );

    event OpenNextRound(
        uint256 indexed nextRount,
        uint256 amount
    );

    event SetToken(
        uint256 blocknumber,
        address token,
        uint256 totalAmount
    );

    event SetStartBlock(
        uint256 startBlock
    );

    event SetPerOperateAmount(
        uint256 perOperateAmount
    );

    error AddOperatorFail(
        address operator,
        bool currentState
    );

    error RemoveOperatorFail(
        address operator,
        bool currentState
    );

    /**
     * @dev Only admin filter.
     */
    modifier onlyAdmin(){
        require(admin == msg.sender, "UNAUTHORIZED");
        _;
    }

    /**
     * @dev Only operator filter.
     */
    modifier onlyOperator(){
        require(operator[msg.sender] == true, "OPERATION NOT ALLOWED");
        _;
    }

    string constant INITIALIZED = "ALREADY INITIALIZED";


    /**
     * @dev The initialize function.
     */
    function initialize(uint256 _perOperateAmount, uint256 _startBlock, address _receiver) external onlyAdmin {
        require(startBlock == 0, INITIALIZED);
        require(_startBlock > block.number, "START BLOCK MISSED.");
        startBlock = _startBlock;
        emit SetStartBlock(
            startBlock
        );

        require(_receiver != address(0), "INVALID ADDRESS");
        require(receiver == address(0), INITIALIZED);
        receiver = _receiver;
        emit SetReceiver(
            _receiver
        );

        require(perOperateAmount == 0, INITIALIZED);
        perOperateAmount = _perOperateAmount;
        emit SetPerOperateAmount(
            perOperateAmount
        );
    }

    /**
     * @dev Add operator function
     */
    function addOperator(address _operator) external onlyAdmin {
        if (!operator[_operator]) {
            operator[_operator] = true;
            emit AddOperator(
                _operator,
                true
            );
        } else {
            revert AddOperatorFail(_operator, operator[_operator]);
        }
    }

    /**
     * @dev Remove operator function.
     */
    function removeOperator(address _operator) external onlyAdmin {
        if (operator[_operator]) {
            operator[_operator] = false;
            emit RemoveOperator(
                _operator,
                true
            );
        } else {
            revert RemoveOperatorFail(_operator, operator[_operator]);
        }

    }

    /**
     * @dev Switching token addresses.
     */
    function setToken(address _token, uint256 _totalAmount) external onlyAdmin {
        require(block.number < startBlock, "MINING HAS STARTED");
        require(_totalAmount>0,"QUANTITY ERROR");
        require(_token != address(0), "INVALID ADDRESS");
        if (token != _token && token != address(0)) {
            //        Retrieve tokens that were not mining before
            uint256 oldTokenBalance = IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransfer(msg.sender, oldTokenBalance);
        }
        token = _token;
        totalAmount = _totalAmount;
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance < totalAmount) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), totalAmount - balance);
        } else if (balance > totalAmount) {
            IERC20(token).safeTransfer(msg.sender, balance - totalAmount);
        }
        emit SetToken(
            block.number,
            token,
            totalAmount
        );
    }

    /**
     * @dev Switching receiving address
     */
    function setReceiver(address _receiver) external onlyAdmin {
        receiver = _receiver;
        emit SetReceiver(
            _receiver
        );
    }

    /**
     * @dev Modify Operation Amount
     */
    function setPerOperateAmount(uint256 _perOperateAmount) external onlyAdmin {
        perOperateAmount = _perOperateAmount;
        emit SetPerOperateAmount(
            perOperateAmount
        );
    }

    /**
     * @dev Modify start block height.
     */
    function setStartBlock(uint _startBlock) external onlyAdmin {
        require(block.number < startBlock, "MINING HAS STARTED");
        startBlock = _startBlock;
        emit SetStartBlock(
            startBlock
        );
    }

    /**
     * @dev Operating procedures regularly withdraw tokens to designated recipient accounts
     */
    function withdraw() external onlyOperator {
        require(token != address(0), "TOKEN NEEDS TO BE INITIALIZED");
        require(totalAmount > 0, "INSUFFICIENT TOKEN");
        require(startBlock <= block.number, "NOT STARTED YET");
        if(currentRound==0){
            _openNextRound();
        }
        RoundInfo storage currentRoundInfo = roundInfos[currentRound - 1];
        uint256 remainingQuantity = currentRoundInfo.amount - currentRoundInfo.debt;
        uint256 amount;
        if (remainingQuantity < perOperateAmount) {
            amount = remainingQuantity;
            currentRoundInfo.debt = currentRoundInfo.amount;
        } else {
            amount = perOperateAmount;
            currentRoundInfo.debt = currentRoundInfo.debt + perOperateAmount;
        }
        uint balance = IERC20(token).balanceOf(address(this));
        require(balance >= amount, "INSUFFICIENT QUANTITY");
        IERC20(token).safeTransfer(receiver, amount);
        emit Withdraw(
            receiver,
            token,
            amount,
            currentRound
        );
        if (currentRoundInfo.debt == currentRoundInfo.amount) {
            _openNextRound();
        }
    }



    /**
     * @dev Obtain remaining total amount
     */
    function obtainSurplus() external view returns (uint256){
        return totalAmount - obtainTotalDebt();
    }

    /**
     * @dev Obtain data on the number of mining rounds
     */
    function pullRoundInfos() external view returns (RoundInfo[] memory){
        return roundInfos;
    }

    /**
     * @dev  Obtain a round of data
     */
    function roundInfo(uint256 round) external view returns (RoundInfo memory){
        return roundInfos[round - 1];
    }

    /**
     * @dev Obtain the claimed amount
     */
    function obtainTotalDebt() public view returns (uint256){
        uint debt;
        for (uint i = 0; i < roundInfos.length; i++) {
            debt = debt + roundInfos[i].debt;
        }
        return debt;
    }

    /**
      * @dev  start the next round of mining internal.
      */
    function _openNextRound() internal {
        if (currentRound != 0) {
            RoundInfo memory currentRound = roundInfos[currentRound - 1];
            require(currentRound.debt == currentRound.amount, "CURRENT ROUND NOT END");
        }
        currentRound = currentRound + 1;
        uint halveMultiple = 1 << currentRound;
        uint currentRoundAmount = totalAmount / halveMultiple;
        roundInfos.push(RoundInfo(currentRound, currentRoundAmount, 0));
        emit OpenNextRound(
            currentRound,
            currentRoundAmount
        );
    }
}
