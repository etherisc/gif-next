import { CharStream, CommonTokenStream } from "antlr4ng";
import fs from "fs";
import { SolidityLexer } from "../antlr/generated/SolidityLexer";
import { SolidityListener } from "../antlr/generated/SolidityListener";
import { FunctionDescriptorContext, InheritanceSpecifierContext, ModifierInvocationContext, ModifierListContext, SolidityParser, StateMutabilityContext } from "../antlr/generated/SolidityParser";
import { logger } from "./logger";

async function main() {
    fs.readdirSync("contracts", { recursive: true, withFileTypes: true}).forEach(file => {
        if (file.name.endsWith(".sol") && file.isFile() ) {
            const f = file.path + "/" + file.name;
            parseContract(f);
        }
    });
}

function parseContract(file: string) {
    const content = fs.readFileSync(file, "utf8");

    const listener = new RestrictedMissingListener();
    const inputStream = CharStream.fromString(content);
    const lexer = new SolidityLexer(inputStream);
    const tokenStream = new CommonTokenStream(lexer);
    const parser = new SolidityParser(tokenStream);
    parser.addParseListener(listener);
    parser.sourceUnit();

    if (listener.findings.length > 0) {
        console.log(`=============== Contract ${file}`);
        console.log(listener.findings);
        console.log(`===============\n\n`);
    }

}

const RELEVANT_BASE_CONTRACTS = [
    'Service',
    // 'AccessManagedUpgradeable',
    // 'AccessManaged',
    // 'ObjectManager',
    'Component',
    'InstanceLinkedComponent',
    'ComponentVerifyingService'
];

class RestrictedMissingListener extends SolidityListener {

    public findings = '';
    isRelevant = false;
    isPublic = false;
    isExternal = false;
    isVirtual = false;
    functionDescriptor = '';
    modifierList = '';

    // Service, AccessManagedUpgradeable, AccessManaged, ObjectManager, Component, InstanceLinkedComponent, ComponentVerifyingService

    public enterContractDefinition = (/*ctx: FunctionDefinitionContext*/) => {
        this.isRelevant = false;
    }

    public exitInheritanceSpecifier = (ctx: InheritanceSpecifierContext) => {
        // console.log(ctx.getText().trim());
        if (RELEVANT_BASE_CONTRACTS.includes(ctx.getText().trim())) {
            this.isRelevant = true;
        }
    }

    public enterFunctionDefinition = (/*ctx: FunctionDefinitionContext*/) => {
        // console.log(`Entering function definition ${ctx.getText()}`);
        this.isPublic = false;
        this.isExternal = false;
        this.isVirtual = false;
        this.functionDescriptor = '';
        this.modifierList = '';
    }
    public exitFunctionDefinition = (/*ctx: FunctionDefinitionContext*/) => {
        // console.log(`Exiting function definition ${ctx.getText()}`);

        if (
            this.isRelevant 
            && (this.isPublic || this.isExternal) 
            && ! this.isVirtual)  {
            // console.log(`Function ${this.functionDescriptor} ${this.modifierList} without restricted modifier`);
            this.findings += `Function '${this.functionDescriptor}' |${this.modifierList}| missing virtual modifier\n`;
        }
    }

    public exitFunctionDescriptor = (ctx: FunctionDescriptorContext) => {
        // console.log(`Function descriptor ${ctx.getText()} `);
        // console.log(`Function descriptor ${ctx.getChild(0)?.getText()} `);
        // console.log(`Function descriptor ${ctx.getChild(1)?.getText()} `);
        this.functionDescriptor = ctx.getText();
    }

    public exitModifierList = (ctx: ModifierListContext) => {
        // console.log(`--0`);
        // console.log(ctx.getText());
        // console.log(ctx.getTokens(SolidityParser.PublicKeyword).length);
        // console.log(ctx.getTokens(SolidityParser.ExternalKeyword).length);
        if (ctx.getTokens(SolidityParser.PublicKeyword).length > 0) {
            this.isPublic = true;
        }
        if (ctx.getTokens(SolidityParser.ExternalKeyword).length > 0) {
            this.isExternal = true;
        }
        if (ctx.getTokens(SolidityParser.VirtualKeyword).length > 0) {
            this.isVirtual = true;
        }
        this.modifierList = ctx.getText();
        // console.log(`--1`);
    }

}

main().catch((error) => {
    logger.error(error.stack);
    process.exitCode = 1;
});