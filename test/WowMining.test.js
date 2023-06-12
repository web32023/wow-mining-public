let {expectEvent, expectRevert, time} = require("@openzeppelin/test-helpers");
let {expectRevertCustomError} = require("custom-error-test-helper");
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
        await expectRevert(MiningPoolDelegator.new(10000000, this.CurrentBlock, receiver, this.PoolDelegate.address, {from: admin}), "START BLOCK MISSED.");
        await expectRevert(MiningPoolDelegator.new(10000000, this.StartBlock, "0x0000000000000000000000000000000000000000", this.PoolDelegate.address, {from: admin}), "INVALID ADDRESS");

        this.PoolDelegator = await MiningPoolDelegator.new(10000000, this.StartBlock, receiver, this.PoolDelegate.address, {from: admin});
        this.Pool = await MiningPoolDelegate.at(this.PoolDelegator.address);
        await this.Token.approve(this.Pool.address, 500000000, {from: admin});
        await this.Pool.setToken(this.Token.address, 500000000, {from: admin});

    });

    it('should add or remove operator successfully', async () => {
        let b = await this.Pool.operator(operator01);
        assert.equal(b, false);
        await expectRevert(this.Pool.addOperator(operator01, {from: receiver}), "UNAUTHORIZED");
        await this.Pool.addOperator(operator01, {from: admin});
        assert.equal(await this.Pool.operator(operator01), true)
        await expectRevertCustomError(MiningPoolDelegate, this.Pool.addOperator(operator01, {from: admin}), "AddOperatorFail", [
            operator01,
            true
        ]);

        await expectRevert(this.Pool.removeOperator(operator01, {from: receiver}), "UNAUTHORIZED")
        await this.Pool.removeOperator(operator01, {from: admin});
        assert.equal(await this.Pool.operator(operator01), false);
        await expectRevertCustomError(MiningPoolDelegate, this.Pool.removeOperator(operator01, {from: admin}), "RemoveOperatorFail", [
            operator01,
            false
        ])

    });

    it('should set token successfully', async () => {
        this.TokenNew = await MockToken.new("WOWCOIN", "WOW", 1000000000, {from: admin});
        await expectRevert(this.Pool.setToken("0x0000000000000000000000000000000000000000", 100, {from: admin}), "INVALID ADDRESS");
        let balanceBeforeToken = await this.Token.balanceOf(admin);
        let balanceBeforeTokenNew = await this.TokenNew.balanceOf(admin);
        assert.equal(balanceBeforeToken, "500000000")
        assert.equal(balanceBeforeTokenNew, "1000000000")
        await this.TokenNew.approve(this.Pool.address, 500000000, {from: admin});
        expectEvent(await this.Pool.setToken(this.TokenNew.address, 5000, {from: admin}), "SetToken", {
            token: this.TokenNew.address,
            totalAmount: new BN(5000)
        });

        let balanceAfterToken = await this.Token.balanceOf(admin);
        let balanceAfterTokenNew = await this.TokenNew.balanceOf(admin);
        let balancePoolTokenNew = await this.TokenNew.balanceOf(this.Pool.address);
        assert.equal(balanceAfterToken, "1000000000");
        assert.equal(balanceAfterTokenNew, "999995000")
        assert.equal(balancePoolTokenNew, "5000");

        let receipt = await this.Pool.setToken(this.TokenNew.address, 500000000, {from: admin})
        expectEvent(receipt, "SetToken", {
            token: this.TokenNew.address,
            totalAmount: new BN(500000000)
        })
        let balanceAfterSetTwiceAdmin = await this.TokenNew.balanceOf(admin);
        let balanceAfterSetTwicePool = await this.TokenNew.balanceOf(this.Pool.address);
        assert.equal(balanceAfterSetTwiceAdmin, "500000000");
        assert.equal(balanceAfterSetTwicePool, "500000000");

        receipt = await this.Pool.setToken(this.TokenNew.address, 200000000, {from: admin});
        expectEvent(receipt, "SetToken", {
            token: this.TokenNew.address,
            totalAmount: new BN(200000000)
        })
        let balanceAfterSetThirdAdmin = await this.TokenNew.balanceOf(admin);
        let balanceAfterSetThirdPool = await this.TokenNew.balanceOf(this.Pool.address);
        console.log(balanceAfterSetThirdAdmin + ":" + balanceAfterSetThirdPool);
        assert.equal(balanceAfterSetThirdAdmin, 800000000);
        assert.equal(balanceAfterSetThirdPool, 200000000);

        await expectRevert(this.Pool.setToken(this.TokenNew.address, 0, {from: admin}),"QUANTITY ERROR");

        await time.advanceBlockTo(this.StartBlock.add(new BN(1)));
        await expectRevert(this.Pool.setToken(this.Token.address, 500, {from: admin}), "MINING HAS STARTED")
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
        let receipt = await this.Pool.setPerOperateAmount(5000000, {from: admin});
        expectEvent(receipt,"SetPerOperateAmount",{
            perOperateAmount:new BN(5000000)
        })
        perOperateAmount = await this.Pool.perOperateAmount();
        assert.equal(perOperateAmount, 5000000);
    });

    it('should set start block successfully', async () => {
        let startBlock = await this.Pool.startBlock();
        assert.equal(this.StartBlock.toString(), startBlock);
        await expectRevert(this.Pool.setStartBlock(this.StartBlock.add(new BN(10)), {from: operator01}), "UNAUTHORIZED");
        let receipt =await this.Pool.setStartBlock(this.StartBlock.add(new BN(10)), {from: admin});
        expectEvent(receipt,"SetStartBlock",{
            startBlock:this.StartBlock.add(new BN(10))
        })
        startBlock = await this.Pool.startBlock();
        assert.equal(this.StartBlock.add(new BN(10)).toString(), startBlock)


    });

    it('should withdraw and open next round successfully', async () => {
        await expectRevert(this.Pool.withdraw({from: admin}), "OPERATION NOT ALLOWED");
        await this.Pool.addOperator(operator01, {from: admin});
        await expectRevert(this.Pool.withdraw({from: operator01}), "NOT STARTED YET");
        await time.advanceBlockTo(this.StartBlock.add(new BN(10)));
        let balance = await this.Token.balanceOf(receiver);
        assert.equal(balance, 0);
        let receipt = await this.Pool.withdraw({from: operator01});
        expectEvent(receipt, "Withdraw", {
            receiver: receiver,
            token: this.Token.address,
            amount: new BN(10000000),
            round: new BN(1)
        })
        for (let i = 0; i < 25; i++) {
            if (i == 24) {
                await this.Pool.withdraw({from: operator01});
                balance = await this.Token.balanceOf(receiver);
                assert.equal(balance, 260000000)
            }else if (i==23){
                let receipt =await this.Pool.withdraw({from: operator01});
                expectEvent(receipt,"OpenNextRound",{
                    nextRount:new BN(2),
                    amount:new BN(125000000),
                })
            } else {
                await this.Pool.withdraw({from: operator01});
            }
        }
        let surplus = await this.Pool.obtainSurplus({from: admin});
        assert.equal(surplus.toString(), 240000000);
        let totalDebt = await this.Pool.obtainTotalDebt({from: admin});
        assert.equal(totalDebt.toString(), 260000000);
        let a = await this.Pool.roundInfo(1);
        assert.equal(a.amount,"250000000");
        assert.equal(a.debt,"250000000");
        let b = await this.Pool.pullRoundInfos();
        assert.equal(b.length,"2");
    });

})