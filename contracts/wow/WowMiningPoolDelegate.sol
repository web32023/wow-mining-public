pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./WowMiningPoolStorage.sol";

contract WowMiningPoolDelegate is WowMiningPoolStorage {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    //    ===================================Events=================================
    /**
     * @dev When result is true mean add an operator,otherwise remove an operator
     */
    event ModifyOperator(address indexed operator, bool result);
    event SetReceiver(address receiver);
    event Withdraw(address receiver, address token, uint256 amount, uint256 round);
    event OpenNextRound(uint256 nextRount, uint256 amount);

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
    function initialize(uint256 _totalAmount, uint256 _perOperateAmount, uint256 _startBlock, address _token, address _receiver) external onlyAdmin {
        require(totalAmount == 0, INITIALIZED);
        totalAmount = _totalAmount;
        require(startBlock == 0, INITIALIZED);
        require(_startBlock > block.number, "START BLOCK MISSED.");
        startBlock = _startBlock;
        require(token == address(0), INITIALIZED);
        require(_token != address(0), "INVALID ADDRESS");
        token = _token;
        require(_receiver != address(0), "INVALID ADDRESS");
        require(receiver == address(0), INITIALIZED);
        receiver = _receiver;
        emit SetReceiver(_receiver);
        require(perOperateAmount == 0, INITIALIZED);
        perOperateAmount = _perOperateAmount;
        openNextRound();
    }

    /**
     * @dev Add operator function
     */
    function addOperator(address _operator) external onlyAdmin {
        if (!operator[_operator]) {
            operator[_operator] = true;
            emit ModifyOperator(_operator, true);
        }
    }

    /**
     * @dev Remove operator function.
     */
    function removeOperator(address _operator) external onlyAdmin {
        if (operator[_operator]) {
            operator[_operator] = false;
            emit ModifyOperator(_operator, false);
        }
    }

    /**
     * @dev Switching token addresses.
     */
    function setToken(address _token) external onlyAdmin {
        require(block.number < startBlock, "MINING HAS STARTED");
        token = _token;
    }

    /**
     * @dev Switching receiving address
     */
    function setReceiver(address _receiver) external onlyAdmin {
        receiver = _receiver;
        emit SetReceiver(_receiver);
    }

    /**
     * @dev Modify Operation Amount
     */
    function setPerOperateAmount(uint256 _perOperateAmount) external onlyAdmin {
        perOperateAmount = _perOperateAmount;
    }

    /**
     * @dev Modify start block height.
     */
    function setStartBlock(uint _startBlock) external onlyAdmin {
        startBlock = _startBlock;
    }

    /**
     * @dev
     */
    function withdraw() external onlyOperator {
        require(token != address(0), "TOKEN NEEDS TO BE INITIALIZED");
        require(startBlock <= block.number, "NOT STARTED YET");
        require(currentRound > 0, "OPEN ROUND FIRST");
        RoundInfo storage currentRoundInfo = roundInfos[currentRound.sub(1)];
        require(currentRoundInfo.debt < currentRoundInfo.amount, "PLEASE OPEN NEXT ROUND");
        uint256 remainingQuantity = currentRoundInfo.amount.sub(currentRoundInfo.debt);
        uint256 amount;
        if (remainingQuantity < perOperateAmount) {
            amount = remainingQuantity;
            currentRoundInfo.debt = currentRoundInfo.amount;
        } else {
            amount = perOperateAmount;
            currentRoundInfo.debt = currentRoundInfo.debt.add(perOperateAmount);
        }
        uint balance = IERC20(token).balanceOf(address(this));
        require(balance >= amount, "INSUFFICIENT QUANTITY");
        IERC20(token).transfer(receiver, amount);
        emit Withdraw(receiver, token, amount, currentRound);
        if(currentRoundInfo.debt==currentRoundInfo.amount){
            openNextRound();
        }
    }

    /**
     * @dev Manually start the next round of mining
     */
    function openNextRound() internal {
        if (currentRound != 0) {
            RoundInfo memory currentRound = roundInfos[currentRound.sub(1)];
            require(currentRound.debt == currentRound.amount, "CURRENT ROUND NOT END");
        }
        currentRound = currentRound.add(1);
        uint halveMultiple = 1 << currentRound;
        uint currentRoundAmount = totalAmount.div(halveMultiple);
        roundInfos.push(RoundInfo(currentRound, currentRoundAmount, 0));
        emit OpenNextRound(currentRound, currentRoundAmount);
    }

    /**
     * @dev Obtain remaining total amount
     */
    function obtainSurplus() public view returns (uint256){
        return totalAmount.sub(obtainTotalDebt());
    }

    /**
     * @dev Obtain the claimed amount
     */
    function obtainTotalDebt() public view returns (uint256){
        uint debt;
        for (uint i = 0; i < roundInfos.length; i++) {
            debt = debt.add(roundInfos[i].debt);
        }
        return debt;
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
        return roundInfos[round.sub(1)];
    }
}
