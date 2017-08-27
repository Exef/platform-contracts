export const weiPrice = 300e-18; // http://coincap.io/
export const gasPrice = 21e9 * weiPrice; // https://ethstats.net
export const gasLimit = 6712392; // https://ethstats.net

export const gasCost = gas =>
  `${gas} gas (€${Math.round(100 * gas * gasPrice) / 100}, ${Math.round(
    1000 * gas / gasLimit
  ) / 10}% of limit)`;

export const txGasCost = tx => gasCost(tx.receipt.gasUsed);

export const contractGasCost = contract =>
  gasCost(web3.eth.getTransactionReceipt(contract.transactionHash).gasUsed);

export default obj =>
  Number.isInteger(obj)
    ? gasCost(obj)
    : obj.receipt ? txGasCost(obj) : contractGasCost(obj);
