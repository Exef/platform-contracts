import ether from './helpers/ether';
import advanceToBlock from './helpers/advanceToBlock';
import EVMThrow from './helpers/EVMThrow';

const Crowdsale = artifacts.require('Crowdsale');
const LockedAccount = artifacts.require('LockedAccount');
const EtherToken = artifacts.require('EtherToken');

const BigNumber = web3.BigNumber;

const should = require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();

contract(Crowdsale, ([_, investor, wallet, purchaser]) => {
  it('should be able to read ICO parameters', async () => {
    const instance = await Crowdsale.deployed();
    assert.equal(await instance.startDate.call(), 1501681287);
    assert.equal(await instance.ownedToken.call(), EtherToken.address);
    assert.equal(await instance.lockedAccount.call(), LockedAccount.address);
  });
});