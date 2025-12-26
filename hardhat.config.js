require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: {
        version: "0.8.30",
        settings: {
            viaIR: true,

            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },
    networks: {
        baseSepolia: {
            url: process.env.BASE_SEPOLIA_RPC,
            accounts: [process.env.DEPLOYER_PK],
            chainId: 84532,
        },
    },
};
