import { string } from "hardhat/internal/core/params/argumentTypes";
import { EventDefinitionContext, EventParameterContext, EventParameterListContext, FunctionDescriptorContext, IdentifierContext, InheritanceSpecifierContext, ModifierInvocationContext, ModifierListContext, OverrideSpecifierContext, SolidityParser, SourceUnitContext, StateMutabilityContext, StructDefinitionContext, TypeNameContext } from "../antlr/generated/SolidityParser";
import { SolidityFileListener, parseSolidityContracts } from "./contract_parser_helper";
import { logger } from "./logger";
import * as fs from 'fs';
import { straightThroughStringTask } from "simple-git/dist/src/lib/tasks/task";
import { ConsoleErrorListener } from "antlr4ng";
import { transferableAbortSignal } from "util";


async function main() {
    // open new output file
    // fs.writeFileSync("events.txt", "", { flag: "w" });
    parseSolidityContracts("contracts", RestrictedMissingListener);   
}

class RestrictedMissingListener extends SolidityFileListener {

    public events = new Map<string, Array<string>>();
    public arguments = new Array<string>();
    isEventDefinition = false;
    isEventParameterList = false;
    isEventParameter = false;
    isTypeName = false;
    eventName = "";
    paramName = "";
    type = "";
    
    public enterEventDefinition = (ctx: EventDefinitionContext) => {
        this.isEventDefinition = true;
        
        this.eventName = "";
        this.arguments = new Array<string>();
    }

    public exitEventDefinition = (ctx: EventDefinitionContext) => {
        this.isEventDefinition = false;
        this.events.set(this.eventName, this.arguments);
    }

    public enterEventParameterList = (ctx: EventParameterListContext) =>  {
        this.isEventParameterList = true;
    }

    public exitEventParameterList = (ctx: EventParameterListContext) => {
        this.isEventParameterList = false;
    }

    public enterTypeName = (ctx: TypeNameContext) => {
        this.isTypeName = true;
        this.type = "";
    }

    public exitTypeName = (ctx: TypeNameContext) => {
        this.isTypeName = false;
        if (this.isEventDefinition) {
            // console.log(`Type: ${ctx.getText()}`);
            this.type = ctx.getText();
        }
    }

    public enterEventParameter = (ctx: EventParameterContext) => {
        this.isEventParameter = true;
    }

    public exitEventParameter = (ctx: EventParameterContext) => {
        this.isEventParameter = false;
        let indexed = "";
        // console.log(`Parameter: ${ctx.getText()}`);
        if (ctx.getTokens(SolidityParser.IndexedKeyword).length > 0) {
            indexed = "indexed ";
        }
        this.arguments.push(`${this.type} ${indexed}${this.paramName}`);
    }

    public exitIdentifier = (ctx: IdentifierContext) => {
        if (this.isEventDefinition) {
            if (this.isTypeName) {
                // console.log(`Type: ${ctx.getText()}`);
            } else if (this.isEventParameter) {
                this.paramName = ctx.getText();
            } else {
                // console.log(`Event: ${ctx.getText()}`);
                this.eventName = ctx.getText();
            }
        }
    }

    public fileFinished(filename: string): void {
        // if (this.events.size     === 0) {
        //     return;
        // }

        // console.log(`File finished: ${filename}`);
        this.events.forEach((value, key) => {
            this.findings += `${filename}: ${key}(${value.join(", ")})\n`;
            // console.log(this.findings);
        });
        
        // if (this.events.size > 0) {
        //     throw Error("Found event");
        // }
    }
}

main().catch((error) => {
    logger.error(error.stack);
    process.exitCode = 1;
});
