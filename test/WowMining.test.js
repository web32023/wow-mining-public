let {expectEvent, expectRevert, time} = require("@openzeppelin/test-helpers");
let MiningPoolDelegate = artifacts.require('WowMiningPoolDelegate');
let MiningPoolDelegator = artifacts.require("WowMiningPoolDelegator");
let MockToken = artifacts.require("MockToken");
const {advanceBlockTo} = require('@openzeppelin/test-helpers/src/time.js');
const BN = require("bn.js");
/**
 *  Wow mining contract tests.
 */
contract('Wow Mining', ([admin, receiver, operator01, receiver02]) => {

    /**
     * Deployment initialization contracts.
     */
    beforeEach(async () => {
        //mocker token decimals ignore
        this.Token = await MockToken.new("WOWCOIN", "WOW", 1000000000, {from: admin});
        this.TokenStandby = await MockToken.new("WOWCOIN", "WOW", 1000000000, {from: admin});
        this.PoolDelegate = await MiningPoolDelegate.new({from: admin});
        this.CurrentBlock = await time.latestBlock();
        this.StartBlock = await new BN(this.CurrentBlock).add(new BN(60));
        console.log("before Each block number:" + this.StartBlock.toString());
        await expectRevert(MiningPoolDelegator.new(500000000, 10000000, this.CurrentBlock, this.Token.address, receiver, this.PoolDelegate.address, {from: admin}), "START BLOCK MISSED.");
        await expectRevert(MiningPoolDelegator.new(500000000, 10000000, this.StartBlock, '0x0000000000000000000000000000000000000000', receiver, this.PoolDelegate.address, {from: admin}), "INVALID ADDRESS");
        await expectRevert(MiningPoolDelegator.new(500000000, 10000000, this.StartBlock, this.Token.address, "0x0000000000000000000000000000000000000000", this.PoolDelegate.address, {from: admin}), "INVALID ADDRESS")
        this.PoolDelegator = await MiningPoolDelegator.new(500000000, 10000000, this.StartBlock, this.Token.address, receiver, this.PoolDelegate.address, {from: admin});
        this.Pool = await MiningPoolDelegate.at(this.PoolDelegator.address);
        this.Token.transfer(this.Pool.address, 500000000, {from: admin});
    });

    it('should good add or remove operator successfully', async () => {
        let b = await this.Pool.operator(operator01);
        assert.equal(b, false);
        await expectRevert(this.Pool.addOperator(operator01, {from: receiver}), "UNAUTHORIZED");
        await this.Pool.addOperator(operator01, {from: admin});
        assert.equal(await this.Pool.operator(operator01), true)

        await expectRevert(this.Pool.removeOperator(operator01, {from: receiver}), "UNAUTHORIZED")
        await this.Pool.removeOperator(operator01, {from: admin});
        assert.equal(await this.Pool.operator(operator01), false);
    });

    it('should set token successfully', async () => {
        assert.equal(await this.Pool.token(), this.Token.address);
        await this.Pool.setToken(this.TokenStandby.address);
        assert.notEqual(this.Pool.token(), this.Token.address);
        await time.advanceBlockTo(this.StartBlock.add(new BN(1)));
        await expectRevert(this.Pool.setToken(this.Token.address, {from: admin}), "MINING HAS STARTED")
    });

    it('should switch receiver successfully', async () => {
        await expectRevert(this.Pool.setReceiver(receiver, {from: operator01}), "UNAUTHORIZED")
        await expectEvent(await this.Pool.setReceiver(receiver, {from: admin}), "SetReceiver", {receiver});
        let newVar = await this.Pool.receiver();
        console.log(newVar);
        assert.equal(newVar, receiver);
    });

    it('should set per operate amount successfully', async () => {
        await expectRevert(this.Pool.setPerOperateAmount(5000000, {from: operator01}), "UNAUTHORIZED");
        let perOperateAmount = await this.Pool.perOperateAmount();
        assert.equal(perOperateAmount, 10000000);
        await this.Pool.setPerOperateAmount(5000000, {from: admin});
        perOperateAmount = await this.Pool.perOperateAmount();
        assert.equal(perOperateAmount, 5000000);
    });

    it('should set start block successfully', async () => {
        let startBlock = await this.Pool.startBlock();
        assert.equal(this.StartBlock.toString(), startBlock);
        await expectRevert(this.Pool.setStartBlock(this.StartBlock.add(new BN(10)), {from: operator01}), "UNAUTHORIZED");
        await this.Pool.setStartBlock(this.StartBlock.add(new BN(10)), {from: admin});
        startBlock = await this.Pool.startBlock();
        assert.equal(this.StartBlock.add(new BN(10)).toString(), startBlock)
    });

    it('should withdraw successfully', async () => {
        await this.Pool.setToken("0x0000000000000000000000000000000000000000", {from: admin})
        await expectRevert(this.Pool.withdraw({from: admin}), "OPERATION NOT ALLOWED");
        await this.Pool.addOperator(operator01, {from: admin});
        await expectRevert(this.Pool.withdraw({from: operator01}), "TOKEN NEEDS TO BE INITIALIZED");
        await this.Pool.setToken(this.Token.address, {from: admin});
        await expectRevert(this.Pool.withdraw({from: operator01}), "NOT STARTED YET");
        await time.advanceBlockTo(this.StartBlock.add(new BN(10)));
        let balance = await this.Token.balanceOf(receiver);
        assert.equal(balance, 0);
        let receipt = await this.Pool.withdraw({from: operator01});
        expectEvent(receipt,"Withdraw",{
            receiver:receiver,
            token:this.Token.address,
            amount:new BN(10000000),
            round: new BN(1)
        })
        for (let i = 0; i < 25; i++) {
            if (i == 24) {
                await this.Pool.withdraw({from: operator01});
                balance = await this.Token.balanceOf(receiver);
                assert.equal(balance,260000000)
            } else {
                await this.Pool.withdraw({from: operator01});
            }
        }
        let surplus = await this.Pool.obtainSurplus({from: admin});
        assert.equal(surplus.toString(),240000000);
        let totalDebt = await this.Pool.obtainTotalDebt({from: admin});
        assert.equal(totalDebt.toString(),260000000);
    });


})