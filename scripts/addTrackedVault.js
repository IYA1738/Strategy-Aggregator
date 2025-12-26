// scripts/addTrackedVault.rpc.js
require("dotenv").config();
const { ethers } = require("ethers");

const COMPTROLLER = "0xD1C3413730FD1980f15237FDb4C17Cc64361083D";
const VAULT = "0xc5aabf6115Cde16fe2b13D690D7490F462C545ed";

const VaultComptrollerAbi = [
    {
        inputs: [{ internalType: "address", name: "_vault", type: "address" }],
        name: "addTrackedVault",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [{ internalType: "address", name: "", type: "address" }],
        name: "isTrackedVault",
        outputs: [{ internalType: "bool", name: "", type: "bool" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [],
        name: "getOwner",
        outputs: [{ internalType: "address", name: "", type: "address" }],
        stateMutability: "view",
        type: "function",
    },
];
async function main() {
    const RPC_URL = process.env.BASE_SEPOLIA_RPC;
    const PRIVATE_KEY = process.env.DEPLOYER_PK;

    if (!RPC_URL) throw new Error("Missing env: BASE_SEPOLIA_RPC_URL");
    if (!PRIVATE_KEY) throw new Error("Missing env: DEPLOYER_PRIVATE_KEY");

    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

    console.log("signer:", wallet.address);

    const comptroller = new ethers.Contract(COMPTROLLER, VaultComptrollerAbi, wallet);

    const owner = await comptroller.getOwner();
    console.log("Owner is", owner);

    const isTracked = await comptroller.isTrackedVault(VAULT);
    console.log("isTrackedVault(before):", isTracked);

    if (isTracked) {
        console.log("Already tracked, skip.");
        return;
    }

    const tx = await comptroller.addTrackedVault(VAULT);
    console.log("tx:", tx.hash);

    const receipt = await tx.wait();
    console.log("confirmed in block:", receipt.blockNumber);

    const isTrackedAfter = await comptroller.isTrackedVault(VAULT);
    console.log("isTrackedVault(after):", isTrackedAfter);
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});
