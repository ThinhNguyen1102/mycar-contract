import { ethers, hardhatArguments } from "hardhat";
import * as Config from "./config";

async function main() {
  await Config.initConfig();
  const network = hardhatArguments.network ? hardhatArguments.network : "dev";
  const [deployer] = await ethers.getSigners();
  console.log("deploy from address: ", deployer.address);

  const MyCar = await ethers.getContractFactory("MyCar");
  const myCar = await MyCar.deploy();
  console.log("MyCar address: ", myCar.target);
  Config.setConfig(network + ".MyCar", myCar.target as string);

  await Config.updateConfig();
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
