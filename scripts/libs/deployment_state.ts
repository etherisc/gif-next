
import * as fs from 'fs';
import { logger } from '../logger';
import hre from 'hardhat';

const DEPLOYMENT_STATE_FILENAME = "deployment_state";
const DEPLOYMENT_STATE_FILENAME_SUFFIX = ".json";

type State = {
    contracts: ContractState[];
}

export type ContractState = {
    name: string;
    type: string;
    deploymentTransaction: string | undefined;
    address: string | undefined;
    libraries?: any | undefined;
    verified: boolean;
}

export class DeploymentState {

    private state: State;

    constructor(preloadedState: State | null) {
        this.state = preloadedState ?? { contracts: [] };
    }

    // Contract deployment states:
    // Not deployed -> name and deployment transaction not exists, it can be perfectlly valid)
    // Deploying -> name and deployment transaction exists -> tx sent
    // Deployed -> name, deployment transaction, address exists > tx mined
    // Verified -> name, deployment transaction, address exists, verified set to true
    public isDeploying(contractName: string): boolean {
        const contractState = this.state.contracts.find(c => c.name === contractName);
        if (contractState === undefined) {
            return false;
        }
        return contractState.deploymentTransaction !== undefined && contractState.address === undefined;
    }
    
    public isDeployed(contractName: string): boolean {
        const contractState = this.state.contracts.find(c => c.name === contractName);
        if (contractState === undefined) {
            return false;
        }
        return contractState.deploymentTransaction !== undefined && contractState.address !== undefined;
    }

    public isDeployedAndVerified(contractName: string): boolean {
        const contractState = this.state.contracts.find(c => c.name === contractName);
        if (contractState === undefined) {
            return false;
        }
        return contractState.deploymentTransaction !== undefined && contractState.address !== undefined && contractState.verified;
    }

    public requireDeployed(contractName: string) {
        if(!this.isDeployed(contractName)) {
            throw new Error(`DeploymentState: ${contractName} is not deployed`);
        }
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

    public getLibraries(contractName: string): any | undefined {
        const contractState = this.state.contracts.find(c => c.name === contractName);
        if (contractState === undefined) {
            return undefined;
        }
        return contractState.libraries;
    }
/* TODO consider taking libraries from artifacts
    public getLibrariesFromArtifacts(contractName: string): any | undefined {

    }
*/

    public setDeploymentTransaction(contractName: string, contractType: string, deploymentTransaction: string, libraries?: any | undefined, initializable?: boolean | undefined): void 
    {
        const contractState = this.state.contracts.find(c => c.name === contractName);
        if (contractState === undefined) {
            this.state.contracts.push({
                name: contractName,
                type: contractType,
                deploymentTransaction: deploymentTransaction,
                address: undefined,
                libraries: libraries,
                verified: false
            });
            logger.debug(`DeploymentState: ${contractName} state is created`);
        } else {
            logger.debug(`DeploymentState: ${contractName} state already exists`);
            if(contractState.type != contractType) {
                throw new Error(`DeploymentState: ${contractName} type mismatch, expected ${contractState.type}, got ${contractType}`);
            }
            contractState.deploymentTransaction = deploymentTransaction;
            contractState.libraries = libraries;
            // set rest params to initial values? -> new transaction means new address and new verification
            logger.debug(`DeploymentState: ${contractName} state is updated`);
        }
        this.persistState();
    }

    public setContractAddress(contractName: string, contractAddress: string): void {
        const contractState = this.state.contracts.find(c => c.name === contractName);
        // TODO check deploymentTransaction is set
        if (contractState === undefined) {
            throw new Error(`DeploymentState: ${contractName} state not found`);
        } else {
            contractState.address = contractAddress;
            logger.debug(`DeploymentState: ${contractName} address updated`);
        }
        this.persistState();
    }

    public setVerified(contractName: string, verified: boolean): void {
        const contractState = this.state.contracts.find(c => c.name === contractName);
        // TODO check deploymentTransaction is set
        if (contractState === undefined) {
            throw new Error(`DeploymentState: ${contractName} state not found`);
        } else {
            contractState.verified = verified;
            logger.debug(`DeploymentState: ${contractName} verifiacation updated`);
        }
        this.persistState();
    }

    private persistState() {
        const json = JSON.stringify(this.state);
        fs.writeFileSync(deploymentFilename(), json);
    }
}

function deploymentFilename(): string {
    return DEPLOYMENT_STATE_FILENAME + "_" + hre.network.config.chainId + DEPLOYMENT_STATE_FILENAME_SUFFIX;
}

const deploymentStateFromFile = fs.existsSync(deploymentFilename()) ? JSON.parse(fs.readFileSync(deploymentFilename()).toString()) : null;
export const deploymentState = new DeploymentState(deploymentStateFromFile);

export const isResumeableDeployment = process.env.RESUMEABLE_DEPLOYMENT === "true";
