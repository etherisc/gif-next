export const NUMBER_OF_CONFIRMATIONS = parseInt(process.env.NUMBER_OF_CONFIRMATIONS || "5");
export const POOL_IS_VERIFYING = process.env.POOL_IS_VERIFYING != undefined ? process.env.POOL_IS_VERIFYING.toLowerCase()  === "true" : true;
export const POOL_COLLATERALIZATION_LEVEL = parseFloat(process.env.POOL_COLLATERALIZATION_LEVEL || "1");
export const DISTRIBUTION_IS_VERIFYING = process.env.DISTRIBUTION_IS_VERIFYING != undefined ? process.env.DISTRIBUTION_IS_VERIFYING.toLowerCase()  === "true" : true;
export const GAS_PRICE = process.env.GAS_PRICE !== undefined ? parseInt(process.env.GAS_PRICE) : undefined;
export const WRITE_ADDRESSES_TO_FILE = process.env.WRITE_ADDRESSES_TO_FILE != undefined ? process.env.WRITE_ADDRESSES_TO_FILE.toLowerCase()  === "true" : false;
export const SKIP_INSTANCE_CREATION = process.env.SKIP_INSTANCE_CREATION != undefined ? process.env.SKIP_INSTANCE_CREATION.toLowerCase()  === "true" : false;
