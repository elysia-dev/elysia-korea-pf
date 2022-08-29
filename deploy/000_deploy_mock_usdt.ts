import { DeployFunction } from "hardhat-deploy/types";

const deploy: DeployFunction = async function (hre) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  await deploy("Usdt", {
    contract: "MockERC20",
    from: deployer,
    args: [],
    log: true,
  });
};

deploy.tags = ["test"];
deploy.dependencies = [];

export default deploy;
