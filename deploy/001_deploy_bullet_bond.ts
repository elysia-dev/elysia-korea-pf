import { DeployFunction } from "hardhat-deploy/types";

const deploy: DeployFunction = async function (hre) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  await deploy("BulletBond", {
    from: deployer,
    args: [],
    log: true,
  });
};

export default deploy;
