import { ValidateUpdateRequiresKindError } from "@openzeppelin/upgrades-core";
import { logger } from "./logger";
import { exec } from "child_process";
import fs from "fs";

async function main() {
    exec('forge inspect MockStorageLayout storageLayout',
        (error, stdout, stderr) => {
            if (error !== null) {
                logger.error(`exec error: ${error}`);
                throw Error("Error during execution");
            }

            // logger.info(`stdout: ${stdout}`);
            fs.writeFileSync('storage_layout.json', stdout);

            prettyPrintStorageLayout(stdout);
        });
}

function prettyPrintStorageLayout(storageLayoutRawJson: string) {
    // parse string json object
    const storageLayout = JSON.parse(storageLayoutRawJson);
    const fields = getFields(storageLayout);
    const types = getTypes(storageLayout);
    
    fields.forEach((field) => {
        logger.info(`${field.name} - ${field.type}`);
    });

    types.forEach((type) => {
        logger.info(`${type.id} - ${type.name} - ${type.size}`);
    });
}

function getFields(storageLayout: any) {
    const fields = [];
    for (let x of storageLayout.storage) {
        // logger.debug(x);
        fields.push({
            name: x.label,
            type: x.type,
        });
    }
    return fields;
}

function getTypes(storageLayout: any) {
    const types = [];
    for (let type in storageLayout.types) {
        // logger.debug(type);
        let value = storageLayout.types[type];
        const t = {
            id: type,
            name: value.label,
            size: value.numberOfBytes,
            hasMembers: false,
            members: {},
        };
        if (value.members) {
            // logger.debug(value.members);
            t.hasMembers = true;
            t.members = {
                name: value.members.label,
                offset: value.members.offset,
                slot: value.members.slot,
                type: value.members
            };
        }
        types.push(t);
    }
    return types;
}


if (require.main === module) {
    main().catch((error) => {
        logger.error(error.stack);
        process.exitCode = 1;
    });
}