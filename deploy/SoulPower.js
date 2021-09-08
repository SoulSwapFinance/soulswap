 module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  await deploy("SoulPower", {
    from: deployer,
    log: true,
    deterministicDeployment: false
  })
}

module.exports.tags = ["SoulPower"]
module.exports.dependencies = ["SoulSwapFactory", "SoulSwapRouter"]
