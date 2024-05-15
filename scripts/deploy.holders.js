const { ethers, upgrades } = require("hardhat");

async function main() {
    const Holders = await ethers.getContractFactory("Holders");
    console.log("Deploying Holders...");
    const params = [
        ["Level 1", 1000n, 100n, 1000n, ["Level 2", 10000n, 1000n, 10000n]["Level 3", 100000n, 10000n, 100000n]],
        [["0xddaAd340b0f1Ef65169Ae5E41A8b10776a75482d", 5n], ["0x0fC5025C764cE34df352757e82f7B5c4Df39A836", 10n]],
        1630489200n,
        1630489200n,
    ]
    const holders = await upgrades.deployProxy(Holders, params, { initializer: "initialize", kind: "uups" });
    console.log(holders.target);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });