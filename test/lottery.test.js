const { expect } = require("chai");
const { expectRevert } = require('@openzeppelin/test-helpers');
const Lottery = artifacts.require("Lottery");
const LotteryNFT = artifacts.require("LotteryNFT");
const MockBEP20 = artifacts.require("MockBEP20");

contract('Lottery', ([alice, bob, carol, cal, dev, minter]) => {
    beforeEach(async () => {
        this.usdt = await MockBEP20.new('usdt', 'usdt', '1000000000', { from: minter });
        this.skb = await MockBEP20.new('skb', 'skb', '10000000000', { from: minter });
        this.nft = await LotteryNFT.new({ from: minter })
        this.lottery = await Lottery.new(this.nft.address, this.skb.address,this.usdt.address, '10', '10',alice, { from: minter });

        await this.nft.transferOwnership( this.lottery.address, {from: minter});
        await this.usdt.transfer(bob, '2000', { from: minter });
        await this.usdt.transfer(alice, '2000', { from: minter });
        await this.usdt.transfer(carol, '2000', { from: minter });
        await this.usdt.transfer(cal, '2000', { from: minter });
        await this.skb.transfer(this.lottery.address, '2000', { from: minter });

        await this.lottery.setWhiteList([alice, bob, carol, cal], [1,4,10,20])
        await this.lottery.setClaimPrice('100')
    });

    it('test drawing', async () => {
        await this.lottery.multiBuy('5', {from: carol });
        await this.lottery.multiBuy('1', {from: alice });
        await this.lottery.multiBuy('2', {from: bob });
        await this.lottery.multiBuy('2', {from: bob });
        await this.lottery.multiBuy('20', {from: cal });
        await expectRevert(this.lottery.multiBuy('1', {from: alice }), 'exceed tickets amount');
        await expectRevert(this.lottery.multiBuy('1', {from: dev }), 'exceed tickets amount');
        await expectRevert(this.lottery.drawing('1', {from: alice }), 'enter drawing phase first');
        await this.lottery.enterDrawingPhase({from: alice })
        await this.lottery.drawing('2', {from: alice })
        const a = (await this.lottery.winningRandomNumber()).toString();
        const id1 = 21+parseInt(a)
        const id2 = 21+3+parseInt(a)
        const id3 = a == '0' ? 3 :parseInt(a)
        console.log(id1, id2)
        await this.usdt.approve(this.lottery.address, '1000', { from: cal });
        await this.usdt.approve(this.lottery.address, '1000', { from: carol });
        await this.lottery.multiClaim([id1,id2], {from: cal})
        await this.lottery.multiClaim([id3], {from: carol})
        await expectRevert(this.lottery.multiClaim([id1,id2], {from: cal}), 'claimed'); 
        assert.equal((await this.skb.balanceOf(cal)).toString(), '20');
        assert.equal((await this.usdt.balanceOf(cal)).toString(), '1800');
    });

    it('admin', async () => {
        await this.lottery.setAdmin(bob, { from: minter });
        await this.lottery.adminWithdraw('1000', { from: bob });
    });
});
