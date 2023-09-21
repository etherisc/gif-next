
import * as fs from 'fs';
import { logger } from '../logger';

type State = {
    contracts: ContractState[];
}

export type ContractState = {
    name: string;
    deploymentTransaction: string | undefined;
    address: string | undefined;
    verified: boolean;
}

export class DeploymentState {

    private state: State;

    constructor() {
        this.state = {
            contracts: []
        };
    }

    public isDeployedAndVerified(contractName: string): boolean {
        const contractState = this.state.contracts.find(c => c.name === contractName);
        if (contractState === undefined) {
            return false;
        }
        return contractState.address !== undefined && contractState.verified && contractState.deploymentTransaction !== undefined;
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
                verified: false
            });
        } else {
            contractState.deploymentTransaction = deploymentTransaction;
        }
        this.saveState();
    }

    public setContractAddress(contractName: string, contractAddress: string): void {
        const contractState = this.state.contracts.find(c => c.name === contractName);
        if (contractState === undefined) {
            throw new Error("Contract state not found");
        } else {
            contractState.address = contractAddress;
        }
        this.saveState();
    }

    public setVerified(contractName: string, verified: boolean): void {
        const contractState = this.state.contracts.find(c => c.name === contractName);
        if (contractState === undefined) {
            throw new Error("Contract state not found");
        } else {
            contractState.verified = verified;
        }
        this.saveState();
    }

    private saveState() {
        // TODO save state as json to file
        // serialize state to json
        logger.info(this.state.contracts.length);
        const json = JSON.stringify(this.state);
        logger.debug(json);
        // write json to file
        fs.writeFileSync("deployment_state.json", json);
    }
}

// TODO: initialize deployment state

export const deploymentState = new DeploymentState();

export const isTrackDeploymentStateEnabled = process.env.TRACK_DEPLOYMENT_STATE === "true";
