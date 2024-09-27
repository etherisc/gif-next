import { formatEther } from "ethers";
import { logger } from "../logger";

const totalGasUsed = new Map<string, bigint>();
const balancesBefore = new Map<string, bigint>();
const balancesAfter = new Map<string, bigint>();

export function addGasSpent(address: string, gasSpent: bigint): void {
    let currentGasUsed = totalGasUsed.get(address);
    if (currentGasUsed === undefined) {
        currentGasUsed = BigInt(0);
    }
    totalGasUsed.set(address, currentGasUsed + gasSpent);
}

export function getGasSpent(address: string): bigint {
    return totalGasUsed.get(address) || BigInt(0);
}

export function resetGasSpent(): void {
    totalGasUsed.clear();
}

export function printGasSpent(): void {
    logger.info("Gas spent by address:");
    totalGasUsed.forEach((value, key) => {
        logger.info(`${key}: ${value} gas`);
    });
}

export function setBalanceBefore(address: string, balance: bigint): void {
    balancesBefore.set(address, balance);
}

export function setBalanceAfter(address: string, balance: bigint): void {
    balancesAfter.set(address, balance);
}

export function getBalanceBefore(address: string): bigint {
    return balancesBefore.get(address) || BigInt(0);
}

export function getBalanceAfter(address: string): bigint {
    return balancesAfter.get(address) || BigInt(0);
}

export function resetBalances(): void {
    balancesBefore.clear();
    balancesAfter.clear();
}

export function printBalances(): void {
    logger.info("Balances:");
    balancesBefore.forEach((value, key) => {
        logger.info(`${key}: ${formatEther(value)} -> ${formatEther(getBalanceAfter(key))} = ${formatEther(value - getBalanceAfter(key))}`);
    });
}
