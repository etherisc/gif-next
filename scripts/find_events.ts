import { string } from "hardhat/internal/core/params/argumentTypes";
import { EventDefinitionContext, EventParameterListContext, FunctionDescriptorContext, IdentifierContext, InheritanceSpecifierContext, ModifierInvocationContext, ModifierListContext, SolidityParser, SourceUnitContext, StateMutabilityContext, StructDefinitionContext, TypeNameContext } from "../antlr/generated/SolidityParser";
import { SolidityFileListener, parseSolidityContracts } from "./contract_parser_helper";
import { logger } from "./logger";
import * as fs from 'fs';


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
    typeName = "";
    
    public enterEventDefinition = (ctx: EventDefinitionContext) => {
        // console.log(`Entering event definition ${ctx.getToken(SolidityParser.Identifier, 0)?.getText()}`);
        this.isEventDefinition = true;
    }

    public exitEventDefinition = (ctx: EventDefinitionContext) => {
        // console.log(`Exiting event definition ${ctx.getText()}`);
        // console.log(`${ctx.getTokens(SolidityParser.Identifier).join(", ")}`);
        this.isEventDefinition = false;
        // console.log(".");
    }

    public enterEventParameterList = (ctx: EventParameterListContext) =>  {
        // console.log(`Entering event parameter list ${ctx.getText()}`);
        this.isEventParameterList = true;
        this.arguments = new Array<string>();
    }

    public exitEventParameterList = (ctx: EventParameterListContext) => {
        // console.log(`Exiting event parameter list ${ctx.getText()}`);
        this.isEventParameterList = false;
    }

    public exitTypeName = (ctx: TypeNameContext) => {
        if (this.isEventParameterList) {
            // console.log(`type: ${ctx.getText()}`);
            this.typeName = ctx.getText();
        }
    }

    public exitIdentifier = (ctx: IdentifierContext) => {
        if (this.isEventParameterList) {
            // console.log(`param: ${ctx.getText()}`);
            this.arguments.push(`${this.typeName} ${ctx.getText()}`);
        } else if (this.isEventDefinition) {
            // console.log(`event: ${ctx.getText()}`);
            this.events.set(ctx.getText(), this.arguments);
        }
    }

    public exitSourceUnit = (ctx: SourceUnitContext) => {
        this.events.forEach((value, key) => {
            // console.log(`event ${key}(${value.join(", ")})`);
            this.findings += `${this.filename}: ${key}(${value.join(", ")})\n`;
        });
    }
}

main().catch((error) => {
    logger.error(error.stack);
    process.exitCode = 1;
});
