const hre = require("hardhat");
const { ethers } = hre;

async function main() {
    const provider = new ethers.JsonRpcProvider(process.env.BASE_SEPOLIA_RPC);
    const deployer = new ethers.Wallet(process.env.DEPLOYER_PK, provider);

    const feeData = await ethers.provider.getFeeData();
    const overrides = {
        maxFeePerGas: (feeData.maxFeePerGas ?? feeData.gasPrice) * 1n,
    };
    const ZERO = "0x0000000000000000000000000000000000000000";

    const oracleAggregatorFactory = await ethers.getContractFactory("OraclesAggregator");
    const oracleAggregator = await oracleAggregatorFactory.deploy(deployer.address, ZERO, ZERO, {
        ...overrides,
    });
    await oracleAggregator.waitForDeployment();
    const oracleAggregatorAddress = await oracleAggregator.getAddress();
    console.log("OracleAggregator deployed to:", oracleAggregatorAddress);

    const expiredTime = 300; // 5 minutes
    const chainLinkPriceFeedFactory = await ethers.getContractFactory("ChainLinkPriceFeed");
    const chainLinkPriceFeed = await chainLinkPriceFeedFactory.deploy(
        oracleAggregatorAddress,
        expiredTime,
        {
            ...overrides,
        },
    );
    await chainLinkPriceFeed.waitForDeployment();
    const chainLinkPriceFeedAddress = await chainLinkPriceFeed.getAddress();
    console.log("ChainLinkPriceFeed deployed to:", chainLinkPriceFeedAddress);

    const PYTH = "0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a";
    const pythPriceFeedFactory = await ethers.getContractFactory("PythPriceFeed");
    const pythPriceFeed = await pythPriceFeedFactory.deploy(oracleAggregatorAddress, PYTH, {
        ...overrides,
    });
    await pythPriceFeed.waitForDeployment();
    const pythPriceFeedAddress = await pythPriceFeed.getAddress();
    console.log("PythPriceFeed deployed to:", pythPriceFeedAddress);

    const oracleAggregatorContract = await ethers.getContractAt(
        "OraclesAggregator",
        oracleAggregatorAddress,
    );
    await oracleAggregatorContract.setChainLinkPriceFeed(chainLinkPriceFeedAddress);
    await oracleAggregatorContract.setPythPriceFeed(pythPriceFeedAddress);

    const nowChainLink = await oracleAggregatorContract.getChainLinkPriceFeed();
    const nowPyth = await oracleAggregatorContract.getPythPriceFeed();
    console.log("nowChainLink:", nowChainLink);
    console.log("nowPyth:", nowPyth);

    // 0-arg
    const feeManagerFactory = await ethers.getContractFactory("FeeManager");
    const feeManager = await feeManagerFactory.deploy({ ...overrides });
    await feeManager.waitForDeployment();
    const feeManagerAddress = await feeManager.getAddress();
    console.log("FeeManager deployed to:", feeManagerAddress);

    // 0-arg
    const valueCalculatorFactory = await ethers.getContractFactory("ValueCalculator");
    const valueCalculator = await valueCalculatorFactory.deploy(oracleAggregatorAddress, {
        ...overrides,
    });
    await valueCalculator.waitForDeployment();
    const valueCalculatorAddress = await valueCalculator.getAddress();
    console.log("ValueCalculator deployed to:", valueCalculatorAddress);

    const WETH = "0x4200000000000000000000000000000000000006";

    const comptrollerFactory = await ethers.getContractFactory("VaultComptroller");
    const comptroller = await comptrollerFactory.deploy(
        WETH,
        feeManagerAddress,
        valueCalculatorAddress,
        { ...overrides },
    );
    await comptroller.waitForDeployment();
    const comptrollerAddress = await comptroller.getAddress();
    console.log("VaultComptroller deployed to:", comptrollerAddress);

    const VaultConfigLibFactory = await ethers.getContractFactory("VaultConfigLib");
    const vaultConfigLib = await VaultConfigLibFactory.deploy({ ...overrides });
    await vaultConfigLib.waitForDeployment();
    const vaultConfigLibAddress = await vaultConfigLib.getAddress();
    console.log("VaultConfigLib deployed to:", vaultConfigLibAddress);

    // 0-arg
    const factoryFactory = await ethers.getContractFactory("VaultFactory", {
        libraries: {
            VaultConfigLib: await vaultConfigLib.getAddress(),
        },
    });
    const factory = await factoryFactory.deploy({ ...overrides });
    await factory.waitForDeployment();
    const factoryAddress = await factory.getAddress();
    console.log("VaultFactory deployed to:", factoryAddress);

    const USDC = "0x036CbD53842c5426634e7929541eC2318f3dCF7e";
    const delay = 0;

    const tx = await factory.createVault(
        comptrollerAddress,
        USDC,
        factoryAddress,
        delay,
        "Vault",
        "VAULT",
        { ...overrides },
    );
    const receipt = await tx.wait();

    const parsed = receipt.logs
        .map((l) => {
            try {
                return factory.interface.parseLog(l);
            } catch {
                return null;
            }
        })
        .find((e) => e && e.name === "VaultCreated");

    if (!parsed) throw new Error("Vault not created");
    console.log("Vault deployed to:", parsed.args.vault);
}

main().catch((e) => {
    console.error(e);
    process.exitCode = 1;
});
