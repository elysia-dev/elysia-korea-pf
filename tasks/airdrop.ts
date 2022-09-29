import { task } from "hardhat/config";
import readlineSync from "readline-sync";

const data = {
  amount: [3, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
  receivers: [
    "0x6B0FE536f1BA967f2071fB957D608ae68be416cD",
    "0xae5faAE5D1444Bf6cEa281Aae939cBa31Fb99999",
    "0xecE90df345C00635E63F88e6d23517e24e33a076",
    "0x616aDD518660042EA200b952bd8F5b4756cf8D09",
    "0x996AD211c06063177F951BA753E6D02965ed4405",
    "0x4B4125947edDB3d3fbb7ad3A3f690a7b9410c552",
    "0x4f88A117292Fe39e19d577E1a32a126D35da1101",
    "0x84d462c7cB95Ef9125212F1459d49EBA553d3e2f",
    "0xaa6A95Fe2d1b6b3bf62c5e1844634a53ab081b4d",
    "0x6de6B6bD685967055C108e3e4880F0Ce35Bfb310",
    "0x665b3954fE15FE38431788aFfce7ee693Ce37708",
    "0x4C5d6e26c3a9E8Ae423e827f9c87b36c3F60b7F0",
    "0x75AcA833C09C3E571F5a4B3F4e20ef8A7aBd5118",
    "0x21D2988D685f7E5359a03bE60ccf88D99C253456",
    "0xf1Ab46a3553d02aA4d3Cd9df5dF32A557917A812",
    "0x8117A1888Cd0cbF5C294F3fF179C5d243ee573a5",
    "0xc5a9Cb2A359F10A628Dc4e6f1cDe5742e559dc55",
    "0x866b38AcB2807a81D0c873334e39698b0228390F",
    "0x4Bd3e4f30B3DcD1Beb6313a7687cbe286e5f3175",
  ],
};

const transfer = task("airdrop", "Airdrop event prize").setAction(
  async function (taskArgs, hre) {
    const id = 0;
    const [signer] = await hre.ethers.getSigners();
    const deployment = await hre.deployments.get("BulletBond");
    const bulletBond = await hre.ethers.getContractAt(
      deployment.abi,
      deployment.address
    );

    console.log("signer", signer.address);
    const zipped = data.receivers.map((x, i) => ({
      receiver: x,
      amount: data.amount[i],
    }));
    console.log("zipped", zipped);

    for await (const x of zipped) {
      console.log(`Send ${x.amount} NFT to ${x.receiver}`);
      const answer: string = readlineSync.question("Proceed? [y/n]\n");
      if (answer.toLowerCase() === "y") {
        const tx = await bulletBond.safeTransferFrom(
          signer.address,
          x.receiver,
          id,
          x.amount,
          hre.ethers.utils.formatBytes32String("")
        );
        const receipt = await tx.wait();
        console.log(receipt);
      } else {
        console.log("Bye!");
      }
    }
  }
);

export default transfer;
