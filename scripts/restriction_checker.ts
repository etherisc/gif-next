import { CharStream, CommonTokenStream } from "antlr4ng";
import fs from "fs";
import { SolidityLexer } from "../antlr/generated/SolidityLexer";
import { SolidityListener } from "../antlr/generated/SolidityListener";
import { FunctionDefinitionContext, ModifierInvocationContext, ModifierListContext, SolidityParser } from "../antlr/generated/SolidityParser";
import { logger } from "./logger";

async function main() {
    // read file ../contracts/staking/StakingService.sol

    fs.readdirSync("contracts", { recursive: true, withFileTypes: true}).forEach(file => {
        if (file.name.endsWith(".sol") && file.isFile()) {
            const f = file.path + "/" + file.name;
            parseContract(f);
        }
    });

    // const content = fs.readFileSync("contracts/staking/StakingService.sol", "utf8");

    // const inputStream = CharStream.fromString(content);
    // const lexer = new SolidityLexer(inputStream);
    // const tokenStream = new CommonTokenStream(lexer);
    // const parser = new SolidityParser(tokenStream);
    // parser.addParseListener(new MyListener());
    // const contractDefinition = parser.sourceUnit();
    // const functionDefinition = parser.functionDefinition();
    
    // console.log(contractDefinition.toString());
}

function parseContract(file: string) {
    console.log(`=============== Parsing contract ${file}`);
    const content = fs.readFileSync(file, "utf8");

    const inputStream = CharStream.fromString(content);
    const lexer = new SolidityLexer(inputStream);
    const tokenStream = new CommonTokenStream(lexer);
    const parser = new SolidityParser(tokenStream);
    parser.addParseListener(new RestrictedMissingListener());
    parser.sourceUnit();
    console.log(`===============\n\n`);

}

// TODO: only contract that are Service, AccessManagedUpgradeable, AccessManaged, ObjectManager, Component, InstanceLinkedComponent, ComponentVerifyingService

class RestrictedMissingListener extends SolidityListener {

    isFunctionDefinition = false;
    isPublic = false;
    isExternal = false;
    isRestricted = false;

    public enterFunctionDefinition = (/*ctx: FunctionDefinitionContext*/) => {
        // console.log(`Entering function definition ${ctx.getText()}`);
        this.isFunctionDefinition = true;
        this.isPublic = false;
        this.isExternal = false;
        this.isRestricted = false;
    }
    public exitFunctionDefinition = (ctx: FunctionDefinitionContext) => {
        // console.log(`Exiting function definition ${ctx.getText()}`);

        if ((this.isPublic || this.isExternal) && ! this.isRestricted)  {
            console.log(`Function ${ctx.getText()} without restricted modifier`);
        }


        this.isFunctionDefinition = false;
    }

    public exitModifierList = (ctx: ModifierListContext) => {
        // console.log(`--0`);
        // console.log(ctx.getText());
        // console.log(ctx.getTokens(SolidityParser.PublicKeyword).length);
        // console.log(ctx.getTokens(SolidityParser.ExternalKeyword).length);
        this.isPublic = ctx.getTokens(SolidityParser.PublicKeyword).length > 0;
        this.isExternal = ctx.getTokens(SolidityParser.ExternalKeyword).length > 0;

        // console.log(`--1`);
    }

    public exitModifierInvocation = (ctx: ModifierInvocationContext) => {
        // console.log(`--2`);
        // console.log(ctx.getText());
        if (ctx.getText() === "restricted()") {
            this.isRestricted = true;
        }
        // console.log(`--3`);
    }

    // public exitFunctionDescriptor = (ctx: FunctionDescriptorContext) => {
    //     console.log(`Function descriptor ${ctx.getText()} `);
    //     console.log(`Function descriptor ${ctx.getChild(0)?.getText()} `);
    //     console.log(`Function descriptor ${ctx.getChild(1)?.getText()} `);
    // }

}

main().catch((error) => {
    logger.error(error.stack);
    process.exitCode = 1;
});