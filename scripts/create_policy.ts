import { ethers } from "hardhat";
import { FireProduct, FireProduct__factory } from "../typechain-types";

async function main() {
    const [protocolOwner,masterInstanceOwner,fireOwner, customer] = await ethers.getSigners();

    // let FireProduct = await ethers.getContractFactory("FireProduct", {
    //     libraries: {
    //     AmountLib: process.env.AMOUNTLIB_ADDRESS,
    //     ContractLib: process.env.CONTRACTLIB_ADDRESS,
    //     FeeLib: process.env.FEELIB_ADDRESS,
    //     NftIdLib: process.env.NFTIDLIB_ADDRESS,
    //     ObjectTypeLib: process.env.OBJECTTYPELIB_ADDRESS,
    //     ReferralLib: process.env.REFERRALLIB_ADDRESS,
    //     RiskIdLib: process.env.RISKIDLIB_ADDRESS,
    //     SecondsLib: process.env.SECONDSLIB_ADDRESS,
    //     TimestampLib: process.env.TIMESTAMPLIB_ADDRESS,
    //     UFixedLib: process.env.UFIXEDLIB_ADDRESS,
    //     VersionLib: process.env.VERSIONLIB_ADDRESS,
    //     },
    // })
    // const FireProductO = FireProduct.connect(fireOwner)
    // const fireProduct = FireProductO.attach(process.env.FIRE_PRODUCT_ADDRESS!) as FireProduct;
    console.log(process.env.FIRE_PRODUCT_ADDRESS!);
    const fireProduct = FireProduct__factory.connect(process.env.FIRE_PRODUCT_ADDRESS!, fireOwner);

    try {
        console.log(0);
        const tx = await fireProduct.createPolicy(288000205, 1728038948);
        console.log(1);
        const res = await tx.wait();
        console.log(2);
        console.log(`status: ${res?.status}`);
        console.log(res);
    } catch(err) { 
        console.log(27);
        console.log(err);
        console.log(JSON.stringify(err));
        console.log(err.data);
        console.log(err.error);
        console.log(err.info);
    }
}

main();