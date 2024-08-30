import { ValidateUpdateRequiresKindError } from "@openzeppelin/upgrades-core";
import { logger } from "./logger";
import { exec } from "child_process";
import fs from "fs";
import { ITokenRegistryHelper__factory } from "../typechain-types";

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

    // types to CSV
    let csv = 'id,name,size,member_name,offset,slot,type\n';
    types.forEach((type) => {
        csv += `${type.id},${type.name},${type.size}`;
        if (type.hasMembers) {
            csv += `,,,\n`;
            for (let member of type.members) {
                csv += `,,,${member.name},${member.offset},${member.slot},${member.type}\n`;
            }
        } else {
            csv += `,,,\n`;
        }
    });

    fs.writeFileSync('storage_layout.csv', csv);
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
            members: [] as any[],
        };
        if (value.members) {
            for (let member in value.members) {
                // logger.debug(member);
                let memberValue = value.members[member];
                t.hasMembers = true;
                t.members.push({
                    name: memberValue.label,
                    offset: memberValue.offset,
                    slot: memberValue.slot,
                    type: memberValue.type,
                });
            }
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