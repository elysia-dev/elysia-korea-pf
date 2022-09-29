import { DeployFunction } from "hardhat-deploy/types";

const deploy: DeployFunction = async function (hre) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  const deployResult = await deploy("CouponBond", {
    from: deployer,
    args: [],
    log: true,
  });
};

deploy.tags = ["test", "main", "CouponBond"];
deploy.dependencies = [];

export default deploy;
