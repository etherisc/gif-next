
import fs from "fs";
import { SolidityListener } from "../antlr/generated/SolidityListener";
import { CharStream, CommonTokenStream } from "antlr4ng";
import { SolidityLexer } from "../antlr/generated/SolidityLexer";
import { SolidityParser } from "../antlr/generated/SolidityParser";

export function parseSolidityContracts(directory: string, listenerType: typeof SolidityFileListener) {
    fs.readdirSync(directory, { recursive: true, withFileTypes: true}).forEach(file => {
        if (file.name.endsWith(".sol") && file.isFile() ) {
            const f = file.path + "/" + file.name;
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            const listener = new listenerType(f);
            parseContract(f, listener);

            if (listener.findings.length > 0) {
                console.log(`===============`);
                console.log(listener.findings);
            }
        }
    });

    
}

function parseContract(file: string, listener: SolidityFileListener) {
    const content = fs.readFileSync(file, "utf8");

    const inputStream = CharStream.fromString(content);
    const lexer = new SolidityLexer(inputStream);
    const tokenStream = new CommonTokenStream(lexer);
    const parser = new SolidityParser(tokenStream);
    parser.addParseListener(listener);
    parser.sourceUnit();
}

export class SolidityFileListener extends SolidityListener {
    public filename = '';
    public findings = '';

    constructor(filename: string) {
        super();
        this.filename = filename;
    }
}
