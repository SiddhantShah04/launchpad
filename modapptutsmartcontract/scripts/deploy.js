// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log(
    "Deploying the contracts with the account:",
    await deployer.getAddress()
  );
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  const unlockTime = currentTimestampInSeconds + 60;

  const lockedAmount = hre.ethers.utils.parseEther("0.001");

  // const Lock = await hre.ethers.getContractFactory("Token");
  // const token = await Lock.deploy();

  const Lock = await hre.ethers.getContractFactory("ICO");

  const lock = await Lock.deploy(
    // need to have gari token , also give autority ICO contarct to do transaction by using tis address
    "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", //collect funds _wallet(Must cotains token that we need to send)
    "0x0CDF9acd87E940837ff21BB40c9fd55F68bba059", //_token token which get accecpted for buying new token(eth mint address)
    "0x5eb3Bc0a489C5A8288765d2336659EbCA68FCd00", //_saleToken saleToken (Gari)
    1714498200,
    3600,
    50,
    10,
    25
  );

  await lock.deployed();
  console.log("Token address of ICO:", lock.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
