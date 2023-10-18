const { network, ethers } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deployer } = await getNamedAccounts();
  const { deploy, log } = deployments;
  const chainId = network.config.chainId;

  const SOulBoundAddress = await deployments.get("SoulBoundToken");

  const args = [SOulBoundAddress.address];

  const Voting = await deploy("voting", {
    from: deployer,
    // in this contract, we can choose our initial price since it is a mock
    args: args,
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  });

};

module.exports.tags = ["voting"];
