
import * as fs from 'fs';
import { logger } from '../logger';
import hre from 'hardhat';

export const DEPLOYMENTS_BASE_DIRECTORY_NAME = "deployments";
const DEPLOYMENT_STATE_FILENAME = "deployment_state";
const DEPLOYMENT_STATE_FILENAME_SUFFIX = ".json";

type State = {
    contracts: ContractState[];
    transactions: TransactionState[];
}

export type ContractState = {
    name: string;
    deploymentTransaction: string | undefined;
    address: string | undefined;
}

export type TransactionState = {
    txId: string;
    hash: string;
}

export class DeploymentState {

    private state: State;

    constructor(preloadedState: State | null) {
        this.state = preloadedState ?? { contracts: [], transactions: []};
    }

    public isDeployedAndVerified(contractName: string): boolean {
        const contractState = this.state.contracts.find(c => c.name === contractName);
        if (contractState === undefined) {
            return false;
        }
        return contractState.address !== undefined && contractState.deploymentTransaction !== undefined;
    }

    public getContractAddress(contractName: string): string | undefined {
        const contractState = this.state.contracts.find(c => c.name === contractName);
        if (contractState === undefined) {
            return undefined;
        }
        return contractState.address;
    }

    public getDeploymentTransaction(contractName: string): string | undefined {
        const contractState = this.state.contracts.find(c => c.name === contractName);
        if (contractState === undefined) {
            return undefined;
        }
        return contractState.deploymentTransaction;
    }

    public isContractDeployed(contractName: string): boolean {
        const contractState = this.state.contracts.find(c => c.name === contractName);
        if (contractState === undefined) {
            return false;
        }
        return contractState.address !== undefined;
    }

    public setDeploymentTransaction(contractName: string, deploymentTransaction: string): void {
        const contractState = this.state.contracts.find(c => c.name === contractName);
        if (contractState === undefined) {
            logger.debug(`Contract state not found for ${contractName}`);
            this.state.contracts.push({
                name: contractName,
                deploymentTransaction: deploymentTransaction,
                address: undefined,
            });
        } else {
            contractState.deploymentTransaction = deploymentTransaction;
        }
        this.persistState();
    }

    public setContractAddress(contractName: string, contractAddress: string): void {
        const contractState = this.state.contracts.find(c => c.name === contractName);
        if (contractState === undefined) {
            throw new Error("Contract state not found");
        } else {
            contractState.address = contractAddress;
        }
        this.persistState();
    }

    public setTransactionId(txId: string, txHash: string): void {
        const transactionState = this.state.transactions.find(t => t.txId === txId);
        if (transactionState !== undefined) {
            throw new Error(`Transaction state already exists for ${txId}`);
        }
        this.state.transactions.push({ txId: txId, hash: txHash });
        this.persistState();
    }

    public hasTransactionId(txId: string): boolean {
        return this.state.transactions.find(t => t.txId === txId) !== undefined;
    }

    public getTransactionHash(txId: string): string {
        const transactionState = this.state.transactions.find(t => t.txId === txId);
        if (transactionState === undefined) {
            throw new Error(`Transaction state not found for ${txId}`);
        }
        return transactionState.hash;
    }

    private persistState() {
        if (isTestChain()) {
            return;
        }
        mkdirDeploymentsBaseDirectory();
        const json = JSON.stringify(this.state);
        fs.writeFileSync(deploymentsBaseDirectory() + deploymentFilename(), json);
    }
}

export function isTestChain(): boolean {
    return hre.network.config.chainId === 31337;
}

export function deploymentsBaseDirectory(): string {
    return DEPLOYMENTS_BASE_DIRECTORY_NAME + "/" + hre.network.config.chainId + "/";
}

export function mkdirDeploymentsBaseDirectory(): void {
    if (!fs.existsSync(deploymentsBaseDirectory())) {
        fs.mkdirSync(deploymentsBaseDirectory(), { recursive: true });
    }
}

function deploymentFilename(): string {
    return DEPLOYMENT_STATE_FILENAME + DEPLOYMENT_STATE_FILENAME_SUFFIX;
}

let deploymentStateFromFile = null;
if (!isTestChain()) {
    deploymentStateFromFile = fs.existsSync(deploymentsBaseDirectory() + deploymentFilename()) ? JSON.parse(fs.readFileSync(deploymentsBaseDirectory() + deploymentFilename()).toString()) : null;
    
}
export const deploymentState = new DeploymentState(deploymentStateFromFile);

export const isResumeableDeployment = process.env.RESUMEABLE_DEPLOYMENT?.toLowerCase() === "true";
