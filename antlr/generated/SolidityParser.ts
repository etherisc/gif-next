// Generated from Solidity.g4 by ANTLR 4.13.1

import * as antlr from "antlr4ng";
import { Token } from "antlr4ng";

import { SolidityListener } from "./SolidityListener.js";
import { SolidityVisitor } from "./SolidityVisitor.js";

// for running tests with parameters, TODO: discuss strategy for typed parameters in CI
// eslint-disable-next-line no-unused-vars
type int = number;


export class SolidityParser extends antlr.Parser {
    public static readonly T__0 = 1;
    public static readonly T__1 = 2;
    public static readonly T__2 = 3;
    public static readonly T__3 = 4;
    public static readonly T__4 = 5;
    public static readonly T__5 = 6;
    public static readonly T__6 = 7;
    public static readonly T__7 = 8;
    public static readonly T__8 = 9;
    public static readonly T__9 = 10;
    public static readonly T__10 = 11;
    public static readonly T__11 = 12;
    public static readonly T__12 = 13;
    public static readonly T__13 = 14;
    public static readonly T__14 = 15;
    public static readonly T__15 = 16;
    public static readonly T__16 = 17;
    public static readonly T__17 = 18;
    public static readonly T__18 = 19;
    public static readonly T__19 = 20;
    public static readonly T__20 = 21;
    public static readonly T__21 = 22;
    public static readonly T__22 = 23;
    public static readonly T__23 = 24;
    public static readonly T__24 = 25;
    public static readonly T__25 = 26;
    public static readonly T__26 = 27;
    public static readonly T__27 = 28;
    public static readonly T__28 = 29;
    public static readonly T__29 = 30;
    public static readonly T__30 = 31;
    public static readonly T__31 = 32;
    public static readonly T__32 = 33;
    public static readonly T__33 = 34;
    public static readonly T__34 = 35;
    public static readonly T__35 = 36;
    public static readonly T__36 = 37;
    public static readonly T__37 = 38;
    public static readonly T__38 = 39;
    public static readonly T__39 = 40;
    public static readonly T__40 = 41;
    public static readonly T__41 = 42;
    public static readonly T__42 = 43;
    public static readonly T__43 = 44;
    public static readonly T__44 = 45;
    public static readonly T__45 = 46;
    public static readonly T__46 = 47;
    public static readonly T__47 = 48;
    public static readonly T__48 = 49;
    public static readonly T__49 = 50;
    public static readonly T__50 = 51;
    public static readonly T__51 = 52;
    public static readonly T__52 = 53;
    public static readonly T__53 = 54;
    public static readonly T__54 = 55;
    public static readonly T__55 = 56;
    public static readonly T__56 = 57;
    public static readonly T__57 = 58;
    public static readonly T__58 = 59;
    public static readonly T__59 = 60;
    public static readonly T__60 = 61;
    public static readonly T__61 = 62;
    public static readonly T__62 = 63;
    public static readonly T__63 = 64;
    public static readonly T__64 = 65;
    public static readonly T__65 = 66;
    public static readonly T__66 = 67;
    public static readonly T__67 = 68;
    public static readonly T__68 = 69;
    public static readonly T__69 = 70;
    public static readonly T__70 = 71;
    public static readonly T__71 = 72;
    public static readonly T__72 = 73;
    public static readonly T__73 = 74;
    public static readonly T__74 = 75;
    public static readonly T__75 = 76;
    public static readonly T__76 = 77;
    public static readonly T__77 = 78;
    public static readonly T__78 = 79;
    public static readonly T__79 = 80;
    public static readonly T__80 = 81;
    public static readonly T__81 = 82;
    public static readonly T__82 = 83;
    public static readonly T__83 = 84;
    public static readonly T__84 = 85;
    public static readonly T__85 = 86;
    public static readonly T__86 = 87;
    public static readonly T__87 = 88;
    public static readonly T__88 = 89;
    public static readonly T__89 = 90;
    public static readonly T__90 = 91;
    public static readonly T__91 = 92;
    public static readonly T__92 = 93;
    public static readonly T__93 = 94;
    public static readonly T__94 = 95;
    public static readonly T__95 = 96;
    public static readonly Int = 97;
    public static readonly Uint = 98;
    public static readonly Byte = 99;
    public static readonly Fixed = 100;
    public static readonly Ufixed = 101;
    public static readonly BooleanLiteral = 102;
    public static readonly DecimalNumber = 103;
    public static readonly HexNumber = 104;
    public static readonly NumberUnit = 105;
    public static readonly HexLiteralFragment = 106;
    public static readonly ReservedKeyword = 107;
    public static readonly AnonymousKeyword = 108;
    public static readonly BreakKeyword = 109;
    public static readonly ConstantKeyword = 110;
    public static readonly ImmutableKeyword = 111;
    public static readonly ContinueKeyword = 112;
    public static readonly LeaveKeyword = 113;
    public static readonly ExternalKeyword = 114;
    public static readonly IndexedKeyword = 115;
    public static readonly InternalKeyword = 116;
    public static readonly PayableKeyword = 117;
    public static readonly PrivateKeyword = 118;
    public static readonly PublicKeyword = 119;
    public static readonly VirtualKeyword = 120;
    public static readonly PureKeyword = 121;
    public static readonly TypeKeyword = 122;
    public static readonly ViewKeyword = 123;
    public static readonly GlobalKeyword = 124;
    public static readonly ConstructorKeyword = 125;
    public static readonly FallbackKeyword = 126;
    public static readonly ReceiveKeyword = 127;
    public static readonly Identifier = 128;
    public static readonly StringLiteralFragment = 129;
    public static readonly VersionLiteral = 130;
    public static readonly WS = 131;
    public static readonly COMMENT = 132;
    public static readonly LINE_COMMENT = 133;
    public static readonly RULE_sourceUnit = 0;
    public static readonly RULE_pragmaDirective = 1;
    public static readonly RULE_pragmaName = 2;
    public static readonly RULE_pragmaValue = 3;
    public static readonly RULE_version = 4;
    public static readonly RULE_versionOperator = 5;
    public static readonly RULE_versionConstraint = 6;
    public static readonly RULE_importDeclaration = 7;
    public static readonly RULE_importDirective = 8;
    public static readonly RULE_importPath = 9;
    public static readonly RULE_contractDefinition = 10;
    public static readonly RULE_inheritanceSpecifier = 11;
    public static readonly RULE_contractPart = 12;
    public static readonly RULE_stateVariableDeclaration = 13;
    public static readonly RULE_fileLevelConstant = 14;
    public static readonly RULE_customErrorDefinition = 15;
    public static readonly RULE_typeDefinition = 16;
    public static readonly RULE_usingForDeclaration = 17;
    public static readonly RULE_usingForObject = 18;
    public static readonly RULE_usingForObjectDirective = 19;
    public static readonly RULE_userDefinableOperators = 20;
    public static readonly RULE_structDefinition = 21;
    public static readonly RULE_modifierDefinition = 22;
    public static readonly RULE_modifierInvocation = 23;
    public static readonly RULE_functionDefinition = 24;
    public static readonly RULE_functionDescriptor = 25;
    public static readonly RULE_returnParameters = 26;
    public static readonly RULE_modifierList = 27;
    public static readonly RULE_eventDefinition = 28;
    public static readonly RULE_enumValue = 29;
    public static readonly RULE_enumDefinition = 30;
    public static readonly RULE_parameterList = 31;
    public static readonly RULE_parameter = 32;
    public static readonly RULE_eventParameterList = 33;
    public static readonly RULE_eventParameter = 34;
    public static readonly RULE_functionTypeParameterList = 35;
    public static readonly RULE_functionTypeParameter = 36;
    public static readonly RULE_variableDeclaration = 37;
    public static readonly RULE_typeName = 38;
    public static readonly RULE_userDefinedTypeName = 39;
    public static readonly RULE_mappingKey = 40;
    public static readonly RULE_mapping = 41;
    public static readonly RULE_mappingKeyName = 42;
    public static readonly RULE_mappingValueName = 43;
    public static readonly RULE_functionTypeName = 44;
    public static readonly RULE_storageLocation = 45;
    public static readonly RULE_stateMutability = 46;
    public static readonly RULE_block = 47;
    public static readonly RULE_statement = 48;
    public static readonly RULE_expressionStatement = 49;
    public static readonly RULE_ifStatement = 50;
    public static readonly RULE_tryStatement = 51;
    public static readonly RULE_catchClause = 52;
    public static readonly RULE_whileStatement = 53;
    public static readonly RULE_simpleStatement = 54;
    public static readonly RULE_uncheckedStatement = 55;
    public static readonly RULE_forStatement = 56;
    public static readonly RULE_inlineAssemblyStatement = 57;
    public static readonly RULE_inlineAssemblyStatementFlag = 58;
    public static readonly RULE_doWhileStatement = 59;
    public static readonly RULE_continueStatement = 60;
    public static readonly RULE_breakStatement = 61;
    public static readonly RULE_returnStatement = 62;
    public static readonly RULE_throwStatement = 63;
    public static readonly RULE_emitStatement = 64;
    public static readonly RULE_revertStatement = 65;
    public static readonly RULE_variableDeclarationStatement = 66;
    public static readonly RULE_variableDeclarationList = 67;
    public static readonly RULE_identifierList = 68;
    public static readonly RULE_elementaryTypeName = 69;
    public static readonly RULE_expression = 70;
    public static readonly RULE_primaryExpression = 71;
    public static readonly RULE_expressionList = 72;
    public static readonly RULE_nameValueList = 73;
    public static readonly RULE_nameValue = 74;
    public static readonly RULE_functionCallArguments = 75;
    public static readonly RULE_functionCall = 76;
    public static readonly RULE_assemblyBlock = 77;
    public static readonly RULE_assemblyItem = 78;
    public static readonly RULE_assemblyExpression = 79;
    public static readonly RULE_assemblyMember = 80;
    public static readonly RULE_assemblyCall = 81;
    public static readonly RULE_assemblyLocalDefinition = 82;
    public static readonly RULE_assemblyAssignment = 83;
    public static readonly RULE_assemblyIdentifierOrList = 84;
    public static readonly RULE_assemblyIdentifierList = 85;
    public static readonly RULE_assemblyStackAssignment = 86;
    public static readonly RULE_labelDefinition = 87;
    public static readonly RULE_assemblySwitch = 88;
    public static readonly RULE_assemblyCase = 89;
    public static readonly RULE_assemblyFunctionDefinition = 90;
    public static readonly RULE_assemblyFunctionReturns = 91;
    public static readonly RULE_assemblyFor = 92;
    public static readonly RULE_assemblyIf = 93;
    public static readonly RULE_assemblyLiteral = 94;
    public static readonly RULE_tupleExpression = 95;
    public static readonly RULE_numberLiteral = 96;
    public static readonly RULE_identifier = 97;
    public static readonly RULE_hexLiteral = 98;
    public static readonly RULE_overrideSpecifier = 99;
    public static readonly RULE_stringLiteral = 100;

    public static readonly literalNames = [
        null, "'pragma'", "';'", "'*'", "'||'", "'^'", "'~'", "'>='", "'>'", 
        "'<'", "'<='", "'='", "'as'", "'import'", "'from'", "'{'", "','", 
        "'}'", "'abstract'", "'contract'", "'interface'", "'library'", "'is'", 
        "'('", "')'", "'error'", "'using'", "'for'", "'|'", "'&'", "'+'", 
        "'-'", "'/'", "'%'", "'=='", "'!='", "'struct'", "'modifier'", "'function'", 
        "'returns'", "'event'", "'enum'", "'['", "']'", "'address'", "'.'", 
        "'mapping'", "'=>'", "'memory'", "'storage'", "'calldata'", "'if'", 
        "'else'", "'try'", "'catch'", "'while'", "'unchecked'", "'assembly'", 
        "'do'", "'return'", "'throw'", "'emit'", "'revert'", "'var'", "'bool'", 
        "'string'", "'byte'", "'++'", "'--'", "'new'", "':'", "'delete'", 
        "'!'", "'**'", "'<<'", "'>>'", "'&&'", "'?'", "'|='", "'^='", "'&='", 
        "'<<='", "'>>='", "'+='", "'-='", "'*='", "'/='", "'%='", "'let'", 
        "':='", "'=:'", "'switch'", "'case'", "'default'", "'->'", "'callback'", 
        "'override'", null, null, null, null, null, null, null, null, null, 
        null, null, "'anonymous'", "'break'", "'constant'", "'immutable'", 
        "'continue'", "'leave'", "'external'", "'indexed'", "'internal'", 
        "'payable'", "'private'", "'public'", "'virtual'", "'pure'", "'type'", 
        "'view'", "'global'", "'constructor'", "'fallback'", "'receive'"
    ];

    public static readonly symbolicNames = [
        null, null, null, null, null, null, null, null, null, null, null, 
        null, null, null, null, null, null, null, null, null, null, null, 
        null, null, null, null, null, null, null, null, null, null, null, 
        null, null, null, null, null, null, null, null, null, null, null, 
        null, null, null, null, null, null, null, null, null, null, null, 
        null, null, null, null, null, null, null, null, null, null, null, 
        null, null, null, null, null, null, null, null, null, null, null, 
        null, null, null, null, null, null, null, null, null, null, null, 
        null, null, null, null, null, null, null, null, null, "Int", "Uint", 
        "Byte", "Fixed", "Ufixed", "BooleanLiteral", "DecimalNumber", "HexNumber", 
        "NumberUnit", "HexLiteralFragment", "ReservedKeyword", "AnonymousKeyword", 
        "BreakKeyword", "ConstantKeyword", "ImmutableKeyword", "ContinueKeyword", 
        "LeaveKeyword", "ExternalKeyword", "IndexedKeyword", "InternalKeyword", 
        "PayableKeyword", "PrivateKeyword", "PublicKeyword", "VirtualKeyword", 
        "PureKeyword", "TypeKeyword", "ViewKeyword", "GlobalKeyword", "ConstructorKeyword", 
        "FallbackKeyword", "ReceiveKeyword", "Identifier", "StringLiteralFragment", 
        "VersionLiteral", "WS", "COMMENT", "LINE_COMMENT"
    ];
    public static readonly ruleNames = [
        "sourceUnit", "pragmaDirective", "pragmaName", "pragmaValue", "version", 
        "versionOperator", "versionConstraint", "importDeclaration", "importDirective", 
        "importPath", "contractDefinition", "inheritanceSpecifier", "contractPart", 
        "stateVariableDeclaration", "fileLevelConstant", "customErrorDefinition", 
        "typeDefinition", "usingForDeclaration", "usingForObject", "usingForObjectDirective", 
        "userDefinableOperators", "structDefinition", "modifierDefinition", 
        "modifierInvocation", "functionDefinition", "functionDescriptor", 
        "returnParameters", "modifierList", "eventDefinition", "enumValue", 
        "enumDefinition", "parameterList", "parameter", "eventParameterList", 
        "eventParameter", "functionTypeParameterList", "functionTypeParameter", 
        "variableDeclaration", "typeName", "userDefinedTypeName", "mappingKey", 
        "mapping", "mappingKeyName", "mappingValueName", "functionTypeName", 
        "storageLocation", "stateMutability", "block", "statement", "expressionStatement", 
        "ifStatement", "tryStatement", "catchClause", "whileStatement", 
        "simpleStatement", "uncheckedStatement", "forStatement", "inlineAssemblyStatement", 
        "inlineAssemblyStatementFlag", "doWhileStatement", "continueStatement", 
        "breakStatement", "returnStatement", "throwStatement", "emitStatement", 
        "revertStatement", "variableDeclarationStatement", "variableDeclarationList", 
        "identifierList", "elementaryTypeName", "expression", "primaryExpression", 
        "expressionList", "nameValueList", "nameValue", "functionCallArguments", 
        "functionCall", "assemblyBlock", "assemblyItem", "assemblyExpression", 
        "assemblyMember", "assemblyCall", "assemblyLocalDefinition", "assemblyAssignment", 
        "assemblyIdentifierOrList", "assemblyIdentifierList", "assemblyStackAssignment", 
        "labelDefinition", "assemblySwitch", "assemblyCase", "assemblyFunctionDefinition", 
        "assemblyFunctionReturns", "assemblyFor", "assemblyIf", "assemblyLiteral", 
        "tupleExpression", "numberLiteral", "identifier", "hexLiteral", 
        "overrideSpecifier", "stringLiteral",
    ];

    public get grammarFileName(): string { return "Solidity.g4"; }
    public get literalNames(): (string | null)[] { return SolidityParser.literalNames; }
    public get symbolicNames(): (string | null)[] { return SolidityParser.symbolicNames; }
    public get ruleNames(): string[] { return SolidityParser.ruleNames; }
    public get serializedATN(): number[] { return SolidityParser._serializedATN; }

    protected createFailedPredicateException(predicate?: string, message?: string): antlr.FailedPredicateException {
        return new antlr.FailedPredicateException(this, predicate, message);
    }

    public constructor(input: antlr.TokenStream) {
        super(input);
        this.interpreter = new antlr.ParserATNSimulator(this, SolidityParser._ATN, SolidityParser.decisionsToDFA, new antlr.PredictionContextCache());
    }
    public sourceUnit(): SourceUnitContext {
        let localContext = new SourceUnitContext(this.context, this.state);
        this.enterRule(localContext, 0, SolidityParser.RULE_sourceUnit);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 215;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            while ((((_la) & ~0x1F) === 0 && ((1 << _la) & 104620034) !== 0) || ((((_la - 36)) & ~0x1F) === 0 && ((1 << (_la - 36)) & 2080392501) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 3896770685) !== 0) || _la === 127 || _la === 128) {
                {
                this.state = 213;
                this.errorHandler.sync(this);
                switch (this.interpreter.adaptivePredict(this.tokenStream, 0, this.context) ) {
                case 1:
                    {
                    this.state = 202;
                    this.pragmaDirective();
                    }
                    break;
                case 2:
                    {
                    this.state = 203;
                    this.importDirective();
                    }
                    break;
                case 3:
                    {
                    this.state = 204;
                    this.contractDefinition();
                    }
                    break;
                case 4:
                    {
                    this.state = 205;
                    this.enumDefinition();
                    }
                    break;
                case 5:
                    {
                    this.state = 206;
                    this.eventDefinition();
                    }
                    break;
                case 6:
                    {
                    this.state = 207;
                    this.structDefinition();
                    }
                    break;
                case 7:
                    {
                    this.state = 208;
                    this.functionDefinition();
                    }
                    break;
                case 8:
                    {
                    this.state = 209;
                    this.fileLevelConstant();
                    }
                    break;
                case 9:
                    {
                    this.state = 210;
                    this.customErrorDefinition();
                    }
                    break;
                case 10:
                    {
                    this.state = 211;
                    this.typeDefinition();
                    }
                    break;
                case 11:
                    {
                    this.state = 212;
                    this.usingForDeclaration();
                    }
                    break;
                }
                }
                this.state = 217;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
            }
            this.state = 218;
            this.match(SolidityParser.EOF);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public pragmaDirective(): PragmaDirectiveContext {
        let localContext = new PragmaDirectiveContext(this.context, this.state);
        this.enterRule(localContext, 2, SolidityParser.RULE_pragmaDirective);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 220;
            this.match(SolidityParser.T__0);
            this.state = 221;
            this.pragmaName();
            this.state = 222;
            this.pragmaValue();
            this.state = 223;
            this.match(SolidityParser.T__1);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public pragmaName(): PragmaNameContext {
        let localContext = new PragmaNameContext(this.context, this.state);
        this.enterRule(localContext, 4, SolidityParser.RULE_pragmaName);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 225;
            this.identifier();
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public pragmaValue(): PragmaValueContext {
        let localContext = new PragmaValueContext(this.context, this.state);
        this.enterRule(localContext, 6, SolidityParser.RULE_pragmaValue);
        try {
            this.state = 230;
            this.errorHandler.sync(this);
            switch (this.interpreter.adaptivePredict(this.tokenStream, 2, this.context) ) {
            case 1:
                this.enterOuterAlt(localContext, 1);
                {
                this.state = 227;
                this.match(SolidityParser.T__2);
                }
                break;
            case 2:
                this.enterOuterAlt(localContext, 2);
                {
                this.state = 228;
                this.version();
                }
                break;
            case 3:
                this.enterOuterAlt(localContext, 3);
                {
                this.state = 229;
                this.expression(0);
                }
                break;
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public version(): VersionContext {
        let localContext = new VersionContext(this.context, this.state);
        this.enterRule(localContext, 8, SolidityParser.RULE_version);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 232;
            this.versionConstraint();
            this.state = 239;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            while ((((_la) & ~0x1F) === 0 && ((1 << _la) & 4080) !== 0) || _la === 103 || _la === 130) {
                {
                {
                this.state = 234;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                if (_la === 4) {
                    {
                    this.state = 233;
                    this.match(SolidityParser.T__3);
                    }
                }

                this.state = 236;
                this.versionConstraint();
                }
                }
                this.state = 241;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public versionOperator(): VersionOperatorContext {
        let localContext = new VersionOperatorContext(this.context, this.state);
        this.enterRule(localContext, 10, SolidityParser.RULE_versionOperator);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 242;
            _la = this.tokenStream.LA(1);
            if(!((((_la) & ~0x1F) === 0 && ((1 << _la) & 4064) !== 0))) {
            this.errorHandler.recoverInline(this);
            }
            else {
                this.errorHandler.reportMatch(this);
                this.consume();
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public versionConstraint(): VersionConstraintContext {
        let localContext = new VersionConstraintContext(this.context, this.state);
        this.enterRule(localContext, 12, SolidityParser.RULE_versionConstraint);
        let _la: number;
        try {
            this.state = 252;
            this.errorHandler.sync(this);
            switch (this.interpreter.adaptivePredict(this.tokenStream, 7, this.context) ) {
            case 1:
                this.enterOuterAlt(localContext, 1);
                {
                this.state = 245;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                if ((((_la) & ~0x1F) === 0 && ((1 << _la) & 4064) !== 0)) {
                    {
                    this.state = 244;
                    this.versionOperator();
                    }
                }

                this.state = 247;
                this.match(SolidityParser.VersionLiteral);
                }
                break;
            case 2:
                this.enterOuterAlt(localContext, 2);
                {
                this.state = 249;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                if ((((_la) & ~0x1F) === 0 && ((1 << _la) & 4064) !== 0)) {
                    {
                    this.state = 248;
                    this.versionOperator();
                    }
                }

                this.state = 251;
                this.match(SolidityParser.DecimalNumber);
                }
                break;
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public importDeclaration(): ImportDeclarationContext {
        let localContext = new ImportDeclarationContext(this.context, this.state);
        this.enterRule(localContext, 14, SolidityParser.RULE_importDeclaration);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 254;
            this.identifier();
            this.state = 257;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 12) {
                {
                this.state = 255;
                this.match(SolidityParser.T__11);
                this.state = 256;
                this.identifier();
                }
            }

            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public importDirective(): ImportDirectiveContext {
        let localContext = new ImportDirectiveContext(this.context, this.state);
        this.enterRule(localContext, 16, SolidityParser.RULE_importDirective);
        let _la: number;
        try {
            this.state = 295;
            this.errorHandler.sync(this);
            switch (this.interpreter.adaptivePredict(this.tokenStream, 13, this.context) ) {
            case 1:
                this.enterOuterAlt(localContext, 1);
                {
                this.state = 259;
                this.match(SolidityParser.T__12);
                this.state = 260;
                this.importPath();
                this.state = 263;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                if (_la === 12) {
                    {
                    this.state = 261;
                    this.match(SolidityParser.T__11);
                    this.state = 262;
                    this.identifier();
                    }
                }

                this.state = 265;
                this.match(SolidityParser.T__1);
                }
                break;
            case 2:
                this.enterOuterAlt(localContext, 2);
                {
                this.state = 267;
                this.match(SolidityParser.T__12);
                this.state = 270;
                this.errorHandler.sync(this);
                switch (this.tokenStream.LA(1)) {
                case SolidityParser.T__2:
                    {
                    this.state = 268;
                    this.match(SolidityParser.T__2);
                    }
                    break;
                case SolidityParser.T__13:
                case SolidityParser.T__24:
                case SolidityParser.T__43:
                case SolidityParser.T__49:
                case SolidityParser.T__61:
                case SolidityParser.T__94:
                case SolidityParser.LeaveKeyword:
                case SolidityParser.PayableKeyword:
                case SolidityParser.GlobalKeyword:
                case SolidityParser.ConstructorKeyword:
                case SolidityParser.ReceiveKeyword:
                case SolidityParser.Identifier:
                    {
                    this.state = 269;
                    this.identifier();
                    }
                    break;
                default:
                    throw new antlr.NoViableAltException(this);
                }
                this.state = 274;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                if (_la === 12) {
                    {
                    this.state = 272;
                    this.match(SolidityParser.T__11);
                    this.state = 273;
                    this.identifier();
                    }
                }

                this.state = 276;
                this.match(SolidityParser.T__13);
                this.state = 277;
                this.importPath();
                this.state = 278;
                this.match(SolidityParser.T__1);
                }
                break;
            case 3:
                this.enterOuterAlt(localContext, 3);
                {
                this.state = 280;
                this.match(SolidityParser.T__12);
                this.state = 281;
                this.match(SolidityParser.T__14);
                this.state = 282;
                this.importDeclaration();
                this.state = 287;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                while (_la === 16) {
                    {
                    {
                    this.state = 283;
                    this.match(SolidityParser.T__15);
                    this.state = 284;
                    this.importDeclaration();
                    }
                    }
                    this.state = 289;
                    this.errorHandler.sync(this);
                    _la = this.tokenStream.LA(1);
                }
                this.state = 290;
                this.match(SolidityParser.T__16);
                this.state = 291;
                this.match(SolidityParser.T__13);
                this.state = 292;
                this.importPath();
                this.state = 293;
                this.match(SolidityParser.T__1);
                }
                break;
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public importPath(): ImportPathContext {
        let localContext = new ImportPathContext(this.context, this.state);
        this.enterRule(localContext, 18, SolidityParser.RULE_importPath);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 297;
            this.match(SolidityParser.StringLiteralFragment);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public contractDefinition(): ContractDefinitionContext {
        let localContext = new ContractDefinitionContext(this.context, this.state);
        this.enterRule(localContext, 20, SolidityParser.RULE_contractDefinition);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 300;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 18) {
                {
                this.state = 299;
                this.match(SolidityParser.T__17);
                }
            }

            this.state = 302;
            _la = this.tokenStream.LA(1);
            if(!((((_la) & ~0x1F) === 0 && ((1 << _la) & 3670016) !== 0))) {
            this.errorHandler.recoverInline(this);
            }
            else {
                this.errorHandler.reportMatch(this);
                this.consume();
            }
            this.state = 303;
            this.identifier();
            this.state = 313;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 22) {
                {
                this.state = 304;
                this.match(SolidityParser.T__21);
                this.state = 305;
                this.inheritanceSpecifier();
                this.state = 310;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                while (_la === 16) {
                    {
                    {
                    this.state = 306;
                    this.match(SolidityParser.T__15);
                    this.state = 307;
                    this.inheritanceSpecifier();
                    }
                    }
                    this.state = 312;
                    this.errorHandler.sync(this);
                    _la = this.tokenStream.LA(1);
                }
                }
            }

            this.state = 315;
            this.match(SolidityParser.T__14);
            this.state = 319;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            while ((((_la) & ~0x1F) === 0 && ((1 << _la) & 100679680) !== 0) || ((((_la - 36)) & ~0x1F) === 0 && ((1 << (_la - 36)) & 2080392503) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 3896770685) !== 0) || _la === 127 || _la === 128) {
                {
                {
                this.state = 316;
                this.contractPart();
                }
                }
                this.state = 321;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
            }
            this.state = 322;
            this.match(SolidityParser.T__16);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public inheritanceSpecifier(): InheritanceSpecifierContext {
        let localContext = new InheritanceSpecifierContext(this.context, this.state);
        this.enterRule(localContext, 22, SolidityParser.RULE_inheritanceSpecifier);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 324;
            this.userDefinedTypeName();
            this.state = 330;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 23) {
                {
                this.state = 325;
                this.match(SolidityParser.T__22);
                this.state = 327;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                if ((((_la) & ~0x1F) === 0 && ((1 << _la) & 3263184960) !== 0) || ((((_la - 38)) & ~0x1F) === 0 && ((1 << (_la - 38)) & 4278194513) !== 0) || ((((_la - 71)) & ~0x1F) === 0 && ((1 << (_la - 71)) & 4244635651) !== 0) || ((((_la - 103)) & ~0x1F) === 0 && ((1 << (_la - 103)) & 124273675) !== 0)) {
                    {
                    this.state = 326;
                    this.expressionList();
                    }
                }

                this.state = 329;
                this.match(SolidityParser.T__23);
                }
            }

            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public contractPart(): ContractPartContext {
        let localContext = new ContractPartContext(this.context, this.state);
        this.enterRule(localContext, 24, SolidityParser.RULE_contractPart);
        try {
            this.state = 341;
            this.errorHandler.sync(this);
            switch (this.interpreter.adaptivePredict(this.tokenStream, 20, this.context) ) {
            case 1:
                this.enterOuterAlt(localContext, 1);
                {
                this.state = 332;
                this.stateVariableDeclaration();
                }
                break;
            case 2:
                this.enterOuterAlt(localContext, 2);
                {
                this.state = 333;
                this.usingForDeclaration();
                }
                break;
            case 3:
                this.enterOuterAlt(localContext, 3);
                {
                this.state = 334;
                this.structDefinition();
                }
                break;
            case 4:
                this.enterOuterAlt(localContext, 4);
                {
                this.state = 335;
                this.modifierDefinition();
                }
                break;
            case 5:
                this.enterOuterAlt(localContext, 5);
                {
                this.state = 336;
                this.functionDefinition();
                }
                break;
            case 6:
                this.enterOuterAlt(localContext, 6);
                {
                this.state = 337;
                this.eventDefinition();
                }
                break;
            case 7:
                this.enterOuterAlt(localContext, 7);
                {
                this.state = 338;
                this.enumDefinition();
                }
                break;
            case 8:
                this.enterOuterAlt(localContext, 8);
                {
                this.state = 339;
                this.customErrorDefinition();
                }
                break;
            case 9:
                this.enterOuterAlt(localContext, 9);
                {
                this.state = 340;
                this.typeDefinition();
                }
                break;
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public stateVariableDeclaration(): StateVariableDeclarationContext {
        let localContext = new StateVariableDeclarationContext(this.context, this.state);
        this.enterRule(localContext, 26, SolidityParser.RULE_stateVariableDeclaration);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 343;
            this.typeName(0);
            this.state = 352;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            while (((((_la - 96)) & ~0x1F) === 0 && ((1 << (_la - 96)) & 13680641) !== 0)) {
                {
                this.state = 350;
                this.errorHandler.sync(this);
                switch (this.tokenStream.LA(1)) {
                case SolidityParser.PublicKeyword:
                    {
                    this.state = 344;
                    this.match(SolidityParser.PublicKeyword);
                    }
                    break;
                case SolidityParser.InternalKeyword:
                    {
                    this.state = 345;
                    this.match(SolidityParser.InternalKeyword);
                    }
                    break;
                case SolidityParser.PrivateKeyword:
                    {
                    this.state = 346;
                    this.match(SolidityParser.PrivateKeyword);
                    }
                    break;
                case SolidityParser.ConstantKeyword:
                    {
                    this.state = 347;
                    this.match(SolidityParser.ConstantKeyword);
                    }
                    break;
                case SolidityParser.ImmutableKeyword:
                    {
                    this.state = 348;
                    this.match(SolidityParser.ImmutableKeyword);
                    }
                    break;
                case SolidityParser.T__95:
                    {
                    this.state = 349;
                    this.overrideSpecifier();
                    }
                    break;
                default:
                    throw new antlr.NoViableAltException(this);
                }
                }
                this.state = 354;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
            }
            this.state = 355;
            this.identifier();
            this.state = 358;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 11) {
                {
                this.state = 356;
                this.match(SolidityParser.T__10);
                this.state = 357;
                this.expression(0);
                }
            }

            this.state = 360;
            this.match(SolidityParser.T__1);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public fileLevelConstant(): FileLevelConstantContext {
        let localContext = new FileLevelConstantContext(this.context, this.state);
        this.enterRule(localContext, 28, SolidityParser.RULE_fileLevelConstant);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 362;
            this.typeName(0);
            this.state = 363;
            this.match(SolidityParser.ConstantKeyword);
            this.state = 364;
            this.identifier();
            this.state = 365;
            this.match(SolidityParser.T__10);
            this.state = 366;
            this.expression(0);
            this.state = 367;
            this.match(SolidityParser.T__1);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public customErrorDefinition(): CustomErrorDefinitionContext {
        let localContext = new CustomErrorDefinitionContext(this.context, this.state);
        this.enterRule(localContext, 30, SolidityParser.RULE_customErrorDefinition);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 369;
            this.match(SolidityParser.T__24);
            this.state = 370;
            this.identifier();
            this.state = 371;
            this.parameterList();
            this.state = 372;
            this.match(SolidityParser.T__1);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public typeDefinition(): TypeDefinitionContext {
        let localContext = new TypeDefinitionContext(this.context, this.state);
        this.enterRule(localContext, 32, SolidityParser.RULE_typeDefinition);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 374;
            this.match(SolidityParser.TypeKeyword);
            this.state = 375;
            this.identifier();
            this.state = 376;
            this.match(SolidityParser.T__21);
            this.state = 377;
            this.elementaryTypeName();
            this.state = 378;
            this.match(SolidityParser.T__1);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public usingForDeclaration(): UsingForDeclarationContext {
        let localContext = new UsingForDeclarationContext(this.context, this.state);
        this.enterRule(localContext, 34, SolidityParser.RULE_usingForDeclaration);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 380;
            this.match(SolidityParser.T__25);
            this.state = 381;
            this.usingForObject();
            this.state = 382;
            this.match(SolidityParser.T__26);
            this.state = 385;
            this.errorHandler.sync(this);
            switch (this.tokenStream.LA(1)) {
            case SolidityParser.T__2:
                {
                this.state = 383;
                this.match(SolidityParser.T__2);
                }
                break;
            case SolidityParser.T__13:
            case SolidityParser.T__24:
            case SolidityParser.T__37:
            case SolidityParser.T__43:
            case SolidityParser.T__45:
            case SolidityParser.T__49:
            case SolidityParser.T__61:
            case SolidityParser.T__62:
            case SolidityParser.T__63:
            case SolidityParser.T__64:
            case SolidityParser.T__65:
            case SolidityParser.T__94:
            case SolidityParser.Int:
            case SolidityParser.Uint:
            case SolidityParser.Byte:
            case SolidityParser.Fixed:
            case SolidityParser.Ufixed:
            case SolidityParser.LeaveKeyword:
            case SolidityParser.PayableKeyword:
            case SolidityParser.GlobalKeyword:
            case SolidityParser.ConstructorKeyword:
            case SolidityParser.ReceiveKeyword:
            case SolidityParser.Identifier:
                {
                this.state = 384;
                this.typeName(0);
                }
                break;
            default:
                throw new antlr.NoViableAltException(this);
            }
            this.state = 388;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 124) {
                {
                this.state = 387;
                this.match(SolidityParser.GlobalKeyword);
                }
            }

            this.state = 390;
            this.match(SolidityParser.T__1);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public usingForObject(): UsingForObjectContext {
        let localContext = new UsingForObjectContext(this.context, this.state);
        this.enterRule(localContext, 36, SolidityParser.RULE_usingForObject);
        let _la: number;
        try {
            this.state = 404;
            this.errorHandler.sync(this);
            switch (this.tokenStream.LA(1)) {
            case SolidityParser.T__13:
            case SolidityParser.T__24:
            case SolidityParser.T__43:
            case SolidityParser.T__49:
            case SolidityParser.T__61:
            case SolidityParser.T__94:
            case SolidityParser.LeaveKeyword:
            case SolidityParser.PayableKeyword:
            case SolidityParser.GlobalKeyword:
            case SolidityParser.ConstructorKeyword:
            case SolidityParser.ReceiveKeyword:
            case SolidityParser.Identifier:
                this.enterOuterAlt(localContext, 1);
                {
                this.state = 392;
                this.userDefinedTypeName();
                }
                break;
            case SolidityParser.T__14:
                this.enterOuterAlt(localContext, 2);
                {
                this.state = 393;
                this.match(SolidityParser.T__14);
                this.state = 394;
                this.usingForObjectDirective();
                this.state = 399;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                while (_la === 16) {
                    {
                    {
                    this.state = 395;
                    this.match(SolidityParser.T__15);
                    this.state = 396;
                    this.usingForObjectDirective();
                    }
                    }
                    this.state = 401;
                    this.errorHandler.sync(this);
                    _la = this.tokenStream.LA(1);
                }
                this.state = 402;
                this.match(SolidityParser.T__16);
                }
                break;
            default:
                throw new antlr.NoViableAltException(this);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public usingForObjectDirective(): UsingForObjectDirectiveContext {
        let localContext = new UsingForObjectDirectiveContext(this.context, this.state);
        this.enterRule(localContext, 38, SolidityParser.RULE_usingForObjectDirective);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 406;
            this.userDefinedTypeName();
            this.state = 409;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 12) {
                {
                this.state = 407;
                this.match(SolidityParser.T__11);
                this.state = 408;
                this.userDefinableOperators();
                }
            }

            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public userDefinableOperators(): UserDefinableOperatorsContext {
        let localContext = new UserDefinableOperatorsContext(this.context, this.state);
        this.enterRule(localContext, 40, SolidityParser.RULE_userDefinableOperators);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 411;
            _la = this.tokenStream.LA(1);
            if(!((((_la) & ~0x1F) === 0 && ((1 << _la) & 4026533864) !== 0) || ((((_la - 32)) & ~0x1F) === 0 && ((1 << (_la - 32)) & 15) !== 0))) {
            this.errorHandler.recoverInline(this);
            }
            else {
                this.errorHandler.reportMatch(this);
                this.consume();
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public structDefinition(): StructDefinitionContext {
        let localContext = new StructDefinitionContext(this.context, this.state);
        this.enterRule(localContext, 42, SolidityParser.RULE_structDefinition);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 413;
            this.match(SolidityParser.T__35);
            this.state = 414;
            this.identifier();
            this.state = 415;
            this.match(SolidityParser.T__14);
            this.state = 426;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 14 || _la === 25 || ((((_la - 38)) & ~0x1F) === 0 && ((1 << (_la - 38)) & 520098113) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 1615069309) !== 0) || _la === 127 || _la === 128) {
                {
                this.state = 416;
                this.variableDeclaration();
                this.state = 417;
                this.match(SolidityParser.T__1);
                this.state = 423;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                while (_la === 14 || _la === 25 || ((((_la - 38)) & ~0x1F) === 0 && ((1 << (_la - 38)) & 520098113) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 1615069309) !== 0) || _la === 127 || _la === 128) {
                    {
                    {
                    this.state = 418;
                    this.variableDeclaration();
                    this.state = 419;
                    this.match(SolidityParser.T__1);
                    }
                    }
                    this.state = 425;
                    this.errorHandler.sync(this);
                    _la = this.tokenStream.LA(1);
                }
                }
            }

            this.state = 428;
            this.match(SolidityParser.T__16);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public modifierDefinition(): ModifierDefinitionContext {
        let localContext = new ModifierDefinitionContext(this.context, this.state);
        this.enterRule(localContext, 44, SolidityParser.RULE_modifierDefinition);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 430;
            this.match(SolidityParser.T__36);
            this.state = 431;
            this.identifier();
            this.state = 433;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 23) {
                {
                this.state = 432;
                this.parameterList();
                }
            }

            this.state = 439;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            while (_la === 96 || _la === 120) {
                {
                this.state = 437;
                this.errorHandler.sync(this);
                switch (this.tokenStream.LA(1)) {
                case SolidityParser.VirtualKeyword:
                    {
                    this.state = 435;
                    this.match(SolidityParser.VirtualKeyword);
                    }
                    break;
                case SolidityParser.T__95:
                    {
                    this.state = 436;
                    this.overrideSpecifier();
                    }
                    break;
                default:
                    throw new antlr.NoViableAltException(this);
                }
                }
                this.state = 441;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
            }
            this.state = 444;
            this.errorHandler.sync(this);
            switch (this.tokenStream.LA(1)) {
            case SolidityParser.T__1:
                {
                this.state = 442;
                this.match(SolidityParser.T__1);
                }
                break;
            case SolidityParser.T__14:
                {
                this.state = 443;
                this.block();
                }
                break;
            default:
                throw new antlr.NoViableAltException(this);
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public modifierInvocation(): ModifierInvocationContext {
        let localContext = new ModifierInvocationContext(this.context, this.state);
        this.enterRule(localContext, 46, SolidityParser.RULE_modifierInvocation);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 446;
            this.identifier();
            this.state = 452;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 23) {
                {
                this.state = 447;
                this.match(SolidityParser.T__22);
                this.state = 449;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                if ((((_la) & ~0x1F) === 0 && ((1 << _la) & 3263184960) !== 0) || ((((_la - 38)) & ~0x1F) === 0 && ((1 << (_la - 38)) & 4278194513) !== 0) || ((((_la - 71)) & ~0x1F) === 0 && ((1 << (_la - 71)) & 4244635651) !== 0) || ((((_la - 103)) & ~0x1F) === 0 && ((1 << (_la - 103)) & 124273675) !== 0)) {
                    {
                    this.state = 448;
                    this.expressionList();
                    }
                }

                this.state = 451;
                this.match(SolidityParser.T__23);
                }
            }

            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public functionDefinition(): FunctionDefinitionContext {
        let localContext = new FunctionDefinitionContext(this.context, this.state);
        this.enterRule(localContext, 48, SolidityParser.RULE_functionDefinition);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 454;
            this.functionDescriptor();
            this.state = 455;
            this.parameterList();
            this.state = 456;
            this.modifierList();
            this.state = 458;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 39) {
                {
                this.state = 457;
                this.returnParameters();
                }
            }

            this.state = 462;
            this.errorHandler.sync(this);
            switch (this.tokenStream.LA(1)) {
            case SolidityParser.T__1:
                {
                this.state = 460;
                this.match(SolidityParser.T__1);
                }
                break;
            case SolidityParser.T__14:
                {
                this.state = 461;
                this.block();
                }
                break;
            default:
                throw new antlr.NoViableAltException(this);
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public functionDescriptor(): FunctionDescriptorContext {
        let localContext = new FunctionDescriptorContext(this.context, this.state);
        this.enterRule(localContext, 50, SolidityParser.RULE_functionDescriptor);
        let _la: number;
        try {
            this.state = 471;
            this.errorHandler.sync(this);
            switch (this.tokenStream.LA(1)) {
            case SolidityParser.T__37:
                this.enterOuterAlt(localContext, 1);
                {
                this.state = 464;
                this.match(SolidityParser.T__37);
                this.state = 466;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                if (_la === 14 || _la === 25 || ((((_la - 44)) & ~0x1F) === 0 && ((1 << (_la - 44)) & 262209) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 1615069185) !== 0) || _la === 127 || _la === 128) {
                    {
                    this.state = 465;
                    this.identifier();
                    }
                }

                }
                break;
            case SolidityParser.ConstructorKeyword:
                this.enterOuterAlt(localContext, 2);
                {
                this.state = 468;
                this.match(SolidityParser.ConstructorKeyword);
                }
                break;
            case SolidityParser.FallbackKeyword:
                this.enterOuterAlt(localContext, 3);
                {
                this.state = 469;
                this.match(SolidityParser.FallbackKeyword);
                }
                break;
            case SolidityParser.ReceiveKeyword:
                this.enterOuterAlt(localContext, 4);
                {
                this.state = 470;
                this.match(SolidityParser.ReceiveKeyword);
                }
                break;
            default:
                throw new antlr.NoViableAltException(this);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public returnParameters(): ReturnParametersContext {
        let localContext = new ReturnParametersContext(this.context, this.state);
        this.enterRule(localContext, 52, SolidityParser.RULE_returnParameters);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 473;
            this.match(SolidityParser.T__38);
            this.state = 474;
            this.parameterList();
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public modifierList(): ModifierListContext {
        let localContext = new ModifierListContext(this.context, this.state);
        this.enterRule(localContext, 54, SolidityParser.RULE_modifierList);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 486;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            while (_la === 14 || _la === 25 || ((((_la - 44)) & ~0x1F) === 0 && ((1 << (_la - 44)) & 262209) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 2011987971) !== 0) || _la === 127 || _la === 128) {
                {
                this.state = 484;
                this.errorHandler.sync(this);
                switch (this.interpreter.adaptivePredict(this.tokenStream, 41, this.context) ) {
                case 1:
                    {
                    this.state = 476;
                    this.match(SolidityParser.ExternalKeyword);
                    }
                    break;
                case 2:
                    {
                    this.state = 477;
                    this.match(SolidityParser.PublicKeyword);
                    }
                    break;
                case 3:
                    {
                    this.state = 478;
                    this.match(SolidityParser.InternalKeyword);
                    }
                    break;
                case 4:
                    {
                    this.state = 479;
                    this.match(SolidityParser.PrivateKeyword);
                    }
                    break;
                case 5:
                    {
                    this.state = 480;
                    this.match(SolidityParser.VirtualKeyword);
                    }
                    break;
                case 6:
                    {
                    this.state = 481;
                    this.stateMutability();
                    }
                    break;
                case 7:
                    {
                    this.state = 482;
                    this.modifierInvocation();
                    }
                    break;
                case 8:
                    {
                    this.state = 483;
                    this.overrideSpecifier();
                    }
                    break;
                }
                }
                this.state = 488;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public eventDefinition(): EventDefinitionContext {
        let localContext = new EventDefinitionContext(this.context, this.state);
        this.enterRule(localContext, 56, SolidityParser.RULE_eventDefinition);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 489;
            this.match(SolidityParser.T__39);
            this.state = 490;
            this.identifier();
            this.state = 491;
            this.eventParameterList();
            this.state = 493;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 108) {
                {
                this.state = 492;
                this.match(SolidityParser.AnonymousKeyword);
                }
            }

            this.state = 495;
            this.match(SolidityParser.T__1);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public enumValue(): EnumValueContext {
        let localContext = new EnumValueContext(this.context, this.state);
        this.enterRule(localContext, 58, SolidityParser.RULE_enumValue);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 497;
            this.identifier();
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public enumDefinition(): EnumDefinitionContext {
        let localContext = new EnumDefinitionContext(this.context, this.state);
        this.enterRule(localContext, 60, SolidityParser.RULE_enumDefinition);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 499;
            this.match(SolidityParser.T__40);
            this.state = 500;
            this.identifier();
            this.state = 501;
            this.match(SolidityParser.T__14);
            this.state = 503;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 14 || _la === 25 || ((((_la - 44)) & ~0x1F) === 0 && ((1 << (_la - 44)) & 262209) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 1615069185) !== 0) || _la === 127 || _la === 128) {
                {
                this.state = 502;
                this.enumValue();
                }
            }

            this.state = 509;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            while (_la === 16) {
                {
                {
                this.state = 505;
                this.match(SolidityParser.T__15);
                this.state = 506;
                this.enumValue();
                }
                }
                this.state = 511;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
            }
            this.state = 512;
            this.match(SolidityParser.T__16);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public parameterList(): ParameterListContext {
        let localContext = new ParameterListContext(this.context, this.state);
        this.enterRule(localContext, 62, SolidityParser.RULE_parameterList);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 514;
            this.match(SolidityParser.T__22);
            this.state = 523;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 14 || _la === 25 || ((((_la - 38)) & ~0x1F) === 0 && ((1 << (_la - 38)) & 520098113) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 1615069309) !== 0) || _la === 127 || _la === 128) {
                {
                this.state = 515;
                this.parameter();
                this.state = 520;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                while (_la === 16) {
                    {
                    {
                    this.state = 516;
                    this.match(SolidityParser.T__15);
                    this.state = 517;
                    this.parameter();
                    }
                    }
                    this.state = 522;
                    this.errorHandler.sync(this);
                    _la = this.tokenStream.LA(1);
                }
                }
            }

            this.state = 525;
            this.match(SolidityParser.T__23);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public parameter(): ParameterContext {
        let localContext = new ParameterContext(this.context, this.state);
        this.enterRule(localContext, 64, SolidityParser.RULE_parameter);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 527;
            this.typeName(0);
            this.state = 529;
            this.errorHandler.sync(this);
            switch (this.interpreter.adaptivePredict(this.tokenStream, 48, this.context) ) {
            case 1:
                {
                this.state = 528;
                this.storageLocation();
                }
                break;
            }
            this.state = 532;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 14 || _la === 25 || ((((_la - 44)) & ~0x1F) === 0 && ((1 << (_la - 44)) & 262209) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 1615069185) !== 0) || _la === 127 || _la === 128) {
                {
                this.state = 531;
                this.identifier();
                }
            }

            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public eventParameterList(): EventParameterListContext {
        let localContext = new EventParameterListContext(this.context, this.state);
        this.enterRule(localContext, 66, SolidityParser.RULE_eventParameterList);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 534;
            this.match(SolidityParser.T__22);
            this.state = 543;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 14 || _la === 25 || ((((_la - 38)) & ~0x1F) === 0 && ((1 << (_la - 38)) & 520098113) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 1615069309) !== 0) || _la === 127 || _la === 128) {
                {
                this.state = 535;
                this.eventParameter();
                this.state = 540;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                while (_la === 16) {
                    {
                    {
                    this.state = 536;
                    this.match(SolidityParser.T__15);
                    this.state = 537;
                    this.eventParameter();
                    }
                    }
                    this.state = 542;
                    this.errorHandler.sync(this);
                    _la = this.tokenStream.LA(1);
                }
                }
            }

            this.state = 545;
            this.match(SolidityParser.T__23);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public eventParameter(): EventParameterContext {
        let localContext = new EventParameterContext(this.context, this.state);
        this.enterRule(localContext, 68, SolidityParser.RULE_eventParameter);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 547;
            this.typeName(0);
            this.state = 549;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 115) {
                {
                this.state = 548;
                this.match(SolidityParser.IndexedKeyword);
                }
            }

            this.state = 552;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 14 || _la === 25 || ((((_la - 44)) & ~0x1F) === 0 && ((1 << (_la - 44)) & 262209) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 1615069185) !== 0) || _la === 127 || _la === 128) {
                {
                this.state = 551;
                this.identifier();
                }
            }

            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public functionTypeParameterList(): FunctionTypeParameterListContext {
        let localContext = new FunctionTypeParameterListContext(this.context, this.state);
        this.enterRule(localContext, 70, SolidityParser.RULE_functionTypeParameterList);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 554;
            this.match(SolidityParser.T__22);
            this.state = 563;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 14 || _la === 25 || ((((_la - 38)) & ~0x1F) === 0 && ((1 << (_la - 38)) & 520098113) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 1615069309) !== 0) || _la === 127 || _la === 128) {
                {
                this.state = 555;
                this.functionTypeParameter();
                this.state = 560;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                while (_la === 16) {
                    {
                    {
                    this.state = 556;
                    this.match(SolidityParser.T__15);
                    this.state = 557;
                    this.functionTypeParameter();
                    }
                    }
                    this.state = 562;
                    this.errorHandler.sync(this);
                    _la = this.tokenStream.LA(1);
                }
                }
            }

            this.state = 565;
            this.match(SolidityParser.T__23);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public functionTypeParameter(): FunctionTypeParameterContext {
        let localContext = new FunctionTypeParameterContext(this.context, this.state);
        this.enterRule(localContext, 72, SolidityParser.RULE_functionTypeParameter);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 567;
            this.typeName(0);
            this.state = 569;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (((((_la - 48)) & ~0x1F) === 0 && ((1 << (_la - 48)) & 7) !== 0)) {
                {
                this.state = 568;
                this.storageLocation();
                }
            }

            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public variableDeclaration(): VariableDeclarationContext {
        let localContext = new VariableDeclarationContext(this.context, this.state);
        this.enterRule(localContext, 74, SolidityParser.RULE_variableDeclaration);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 571;
            this.typeName(0);
            this.state = 573;
            this.errorHandler.sync(this);
            switch (this.interpreter.adaptivePredict(this.tokenStream, 57, this.context) ) {
            case 1:
                {
                this.state = 572;
                this.storageLocation();
                }
                break;
            }
            this.state = 575;
            this.identifier();
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }

    public typeName(): TypeNameContext;
    public typeName(_p: number): TypeNameContext;
    public typeName(_p?: number): TypeNameContext {
        if (_p === undefined) {
            _p = 0;
        }

        let parentContext = this.context;
        let parentState = this.state;
        let localContext = new TypeNameContext(this.context, parentState);
        let previousContext = localContext;
        let _startState = 76;
        this.enterRecursionRule(localContext, 76, SolidityParser.RULE_typeName, _p);
        let _la: number;
        try {
            let alternative: number;
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 584;
            this.errorHandler.sync(this);
            switch (this.interpreter.adaptivePredict(this.tokenStream, 58, this.context) ) {
            case 1:
                {
                this.state = 578;
                this.elementaryTypeName();
                }
                break;
            case 2:
                {
                this.state = 579;
                this.userDefinedTypeName();
                }
                break;
            case 3:
                {
                this.state = 580;
                this.mapping();
                }
                break;
            case 4:
                {
                this.state = 581;
                this.functionTypeName();
                }
                break;
            case 5:
                {
                this.state = 582;
                this.match(SolidityParser.T__43);
                this.state = 583;
                this.match(SolidityParser.PayableKeyword);
                }
                break;
            }
            this.context!.stop = this.tokenStream.LT(-1);
            this.state = 594;
            this.errorHandler.sync(this);
            alternative = this.interpreter.adaptivePredict(this.tokenStream, 60, this.context);
            while (alternative !== 2 && alternative !== antlr.ATN.INVALID_ALT_NUMBER) {
                if (alternative === 1) {
                    if (this.parseListeners != null) {
                        this.triggerExitRuleEvent();
                    }
                    previousContext = localContext;
                    {
                    {
                    localContext = new TypeNameContext(parentContext, parentState);
                    this.pushNewRecursionContext(localContext, _startState, SolidityParser.RULE_typeName);
                    this.state = 586;
                    if (!(this.precpred(this.context, 3))) {
                        throw this.createFailedPredicateException("this.precpred(this.context, 3)");
                    }
                    this.state = 587;
                    this.match(SolidityParser.T__41);
                    this.state = 589;
                    this.errorHandler.sync(this);
                    _la = this.tokenStream.LA(1);
                    if ((((_la) & ~0x1F) === 0 && ((1 << _la) & 3263184960) !== 0) || ((((_la - 38)) & ~0x1F) === 0 && ((1 << (_la - 38)) & 4278194513) !== 0) || ((((_la - 71)) & ~0x1F) === 0 && ((1 << (_la - 71)) & 4244635651) !== 0) || ((((_la - 103)) & ~0x1F) === 0 && ((1 << (_la - 103)) & 124273675) !== 0)) {
                        {
                        this.state = 588;
                        this.expression(0);
                        }
                    }

                    this.state = 591;
                    this.match(SolidityParser.T__42);
                    }
                    }
                }
                this.state = 596;
                this.errorHandler.sync(this);
                alternative = this.interpreter.adaptivePredict(this.tokenStream, 60, this.context);
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.unrollRecursionContexts(parentContext);
        }
        return localContext;
    }
    public userDefinedTypeName(): UserDefinedTypeNameContext {
        let localContext = new UserDefinedTypeNameContext(this.context, this.state);
        this.enterRule(localContext, 78, SolidityParser.RULE_userDefinedTypeName);
        try {
            let alternative: number;
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 597;
            this.identifier();
            this.state = 602;
            this.errorHandler.sync(this);
            alternative = this.interpreter.adaptivePredict(this.tokenStream, 61, this.context);
            while (alternative !== 2 && alternative !== antlr.ATN.INVALID_ALT_NUMBER) {
                if (alternative === 1) {
                    {
                    {
                    this.state = 598;
                    this.match(SolidityParser.T__44);
                    this.state = 599;
                    this.identifier();
                    }
                    }
                }
                this.state = 604;
                this.errorHandler.sync(this);
                alternative = this.interpreter.adaptivePredict(this.tokenStream, 61, this.context);
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public mappingKey(): MappingKeyContext {
        let localContext = new MappingKeyContext(this.context, this.state);
        this.enterRule(localContext, 80, SolidityParser.RULE_mappingKey);
        try {
            this.state = 607;
            this.errorHandler.sync(this);
            switch (this.interpreter.adaptivePredict(this.tokenStream, 62, this.context) ) {
            case 1:
                this.enterOuterAlt(localContext, 1);
                {
                this.state = 605;
                this.elementaryTypeName();
                }
                break;
            case 2:
                this.enterOuterAlt(localContext, 2);
                {
                this.state = 606;
                this.userDefinedTypeName();
                }
                break;
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public mapping(): MappingContext {
        let localContext = new MappingContext(this.context, this.state);
        this.enterRule(localContext, 82, SolidityParser.RULE_mapping);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 609;
            this.match(SolidityParser.T__45);
            this.state = 610;
            this.match(SolidityParser.T__22);
            this.state = 611;
            this.mappingKey();
            this.state = 613;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 14 || _la === 25 || ((((_la - 44)) & ~0x1F) === 0 && ((1 << (_la - 44)) & 262209) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 1615069185) !== 0) || _la === 127 || _la === 128) {
                {
                this.state = 612;
                this.mappingKeyName();
                }
            }

            this.state = 615;
            this.match(SolidityParser.T__46);
            this.state = 616;
            this.typeName(0);
            this.state = 618;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 14 || _la === 25 || ((((_la - 44)) & ~0x1F) === 0 && ((1 << (_la - 44)) & 262209) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 1615069185) !== 0) || _la === 127 || _la === 128) {
                {
                this.state = 617;
                this.mappingValueName();
                }
            }

            this.state = 620;
            this.match(SolidityParser.T__23);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public mappingKeyName(): MappingKeyNameContext {
        let localContext = new MappingKeyNameContext(this.context, this.state);
        this.enterRule(localContext, 84, SolidityParser.RULE_mappingKeyName);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 622;
            this.identifier();
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public mappingValueName(): MappingValueNameContext {
        let localContext = new MappingValueNameContext(this.context, this.state);
        this.enterRule(localContext, 86, SolidityParser.RULE_mappingValueName);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 624;
            this.identifier();
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public functionTypeName(): FunctionTypeNameContext {
        let localContext = new FunctionTypeNameContext(this.context, this.state);
        this.enterRule(localContext, 88, SolidityParser.RULE_functionTypeName);
        try {
            let alternative: number;
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 626;
            this.match(SolidityParser.T__37);
            this.state = 627;
            this.functionTypeParameterList();
            this.state = 633;
            this.errorHandler.sync(this);
            alternative = this.interpreter.adaptivePredict(this.tokenStream, 66, this.context);
            while (alternative !== 2 && alternative !== antlr.ATN.INVALID_ALT_NUMBER) {
                if (alternative === 1) {
                    {
                    this.state = 631;
                    this.errorHandler.sync(this);
                    switch (this.tokenStream.LA(1)) {
                    case SolidityParser.InternalKeyword:
                        {
                        this.state = 628;
                        this.match(SolidityParser.InternalKeyword);
                        }
                        break;
                    case SolidityParser.ExternalKeyword:
                        {
                        this.state = 629;
                        this.match(SolidityParser.ExternalKeyword);
                        }
                        break;
                    case SolidityParser.ConstantKeyword:
                    case SolidityParser.PayableKeyword:
                    case SolidityParser.PureKeyword:
                    case SolidityParser.ViewKeyword:
                        {
                        this.state = 630;
                        this.stateMutability();
                        }
                        break;
                    default:
                        throw new antlr.NoViableAltException(this);
                    }
                    }
                }
                this.state = 635;
                this.errorHandler.sync(this);
                alternative = this.interpreter.adaptivePredict(this.tokenStream, 66, this.context);
            }
            this.state = 638;
            this.errorHandler.sync(this);
            switch (this.interpreter.adaptivePredict(this.tokenStream, 67, this.context) ) {
            case 1:
                {
                this.state = 636;
                this.match(SolidityParser.T__38);
                this.state = 637;
                this.functionTypeParameterList();
                }
                break;
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public storageLocation(): StorageLocationContext {
        let localContext = new StorageLocationContext(this.context, this.state);
        this.enterRule(localContext, 90, SolidityParser.RULE_storageLocation);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 640;
            _la = this.tokenStream.LA(1);
            if(!(((((_la - 48)) & ~0x1F) === 0 && ((1 << (_la - 48)) & 7) !== 0))) {
            this.errorHandler.recoverInline(this);
            }
            else {
                this.errorHandler.reportMatch(this);
                this.consume();
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public stateMutability(): StateMutabilityContext {
        let localContext = new StateMutabilityContext(this.context, this.state);
        this.enterRule(localContext, 92, SolidityParser.RULE_stateMutability);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 642;
            _la = this.tokenStream.LA(1);
            if(!(((((_la - 110)) & ~0x1F) === 0 && ((1 << (_la - 110)) & 10369) !== 0))) {
            this.errorHandler.recoverInline(this);
            }
            else {
                this.errorHandler.reportMatch(this);
                this.consume();
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public block(): BlockContext {
        let localContext = new BlockContext(this.context, this.state);
        this.enterRule(localContext, 94, SolidityParser.RULE_block);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 644;
            this.match(SolidityParser.T__14);
            this.state = 648;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            while ((((_la) & ~0x1F) === 0 && ((1 << _la) & 3397435456) !== 0) || ((((_la - 38)) & ~0x1F) === 0 && ((1 << (_la - 38)) & 4294881617) !== 0) || ((((_la - 71)) & ~0x1F) === 0 && ((1 << (_la - 71)) & 4244635651) !== 0) || ((((_la - 103)) & ~0x1F) === 0 && ((1 << (_la - 103)) & 124274251) !== 0)) {
                {
                {
                this.state = 645;
                this.statement();
                }
                }
                this.state = 650;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
            }
            this.state = 651;
            this.match(SolidityParser.T__16);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public statement(): StatementContext {
        let localContext = new StatementContext(this.context, this.state);
        this.enterRule(localContext, 96, SolidityParser.RULE_statement);
        try {
            this.state = 668;
            this.errorHandler.sync(this);
            switch (this.interpreter.adaptivePredict(this.tokenStream, 69, this.context) ) {
            case 1:
                this.enterOuterAlt(localContext, 1);
                {
                this.state = 653;
                this.ifStatement();
                }
                break;
            case 2:
                this.enterOuterAlt(localContext, 2);
                {
                this.state = 654;
                this.tryStatement();
                }
                break;
            case 3:
                this.enterOuterAlt(localContext, 3);
                {
                this.state = 655;
                this.whileStatement();
                }
                break;
            case 4:
                this.enterOuterAlt(localContext, 4);
                {
                this.state = 656;
                this.forStatement();
                }
                break;
            case 5:
                this.enterOuterAlt(localContext, 5);
                {
                this.state = 657;
                this.block();
                }
                break;
            case 6:
                this.enterOuterAlt(localContext, 6);
                {
                this.state = 658;
                this.inlineAssemblyStatement();
                }
                break;
            case 7:
                this.enterOuterAlt(localContext, 7);
                {
                this.state = 659;
                this.doWhileStatement();
                }
                break;
            case 8:
                this.enterOuterAlt(localContext, 8);
                {
                this.state = 660;
                this.continueStatement();
                }
                break;
            case 9:
                this.enterOuterAlt(localContext, 9);
                {
                this.state = 661;
                this.breakStatement();
                }
                break;
            case 10:
                this.enterOuterAlt(localContext, 10);
                {
                this.state = 662;
                this.returnStatement();
                }
                break;
            case 11:
                this.enterOuterAlt(localContext, 11);
                {
                this.state = 663;
                this.throwStatement();
                }
                break;
            case 12:
                this.enterOuterAlt(localContext, 12);
                {
                this.state = 664;
                this.emitStatement();
                }
                break;
            case 13:
                this.enterOuterAlt(localContext, 13);
                {
                this.state = 665;
                this.simpleStatement();
                }
                break;
            case 14:
                this.enterOuterAlt(localContext, 14);
                {
                this.state = 666;
                this.uncheckedStatement();
                }
                break;
            case 15:
                this.enterOuterAlt(localContext, 15);
                {
                this.state = 667;
                this.revertStatement();
                }
                break;
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public expressionStatement(): ExpressionStatementContext {
        let localContext = new ExpressionStatementContext(this.context, this.state);
        this.enterRule(localContext, 98, SolidityParser.RULE_expressionStatement);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 670;
            this.expression(0);
            this.state = 671;
            this.match(SolidityParser.T__1);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public ifStatement(): IfStatementContext {
        let localContext = new IfStatementContext(this.context, this.state);
        this.enterRule(localContext, 100, SolidityParser.RULE_ifStatement);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 673;
            this.match(SolidityParser.T__50);
            this.state = 674;
            this.match(SolidityParser.T__22);
            this.state = 675;
            this.expression(0);
            this.state = 676;
            this.match(SolidityParser.T__23);
            this.state = 677;
            this.statement();
            this.state = 680;
            this.errorHandler.sync(this);
            switch (this.interpreter.adaptivePredict(this.tokenStream, 70, this.context) ) {
            case 1:
                {
                this.state = 678;
                this.match(SolidityParser.T__51);
                this.state = 679;
                this.statement();
                }
                break;
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public tryStatement(): TryStatementContext {
        let localContext = new TryStatementContext(this.context, this.state);
        this.enterRule(localContext, 102, SolidityParser.RULE_tryStatement);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 682;
            this.match(SolidityParser.T__52);
            this.state = 683;
            this.expression(0);
            this.state = 685;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 39) {
                {
                this.state = 684;
                this.returnParameters();
                }
            }

            this.state = 687;
            this.block();
            this.state = 689;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            do {
                {
                {
                this.state = 688;
                this.catchClause();
                }
                }
                this.state = 691;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
            } while (_la === 54);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public catchClause(): CatchClauseContext {
        let localContext = new CatchClauseContext(this.context, this.state);
        this.enterRule(localContext, 104, SolidityParser.RULE_catchClause);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 693;
            this.match(SolidityParser.T__53);
            this.state = 698;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if ((((_la) & ~0x1F) === 0 && ((1 << _la) & 41959424) !== 0) || ((((_la - 44)) & ~0x1F) === 0 && ((1 << (_la - 44)) & 262209) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 1615069185) !== 0) || _la === 127 || _la === 128) {
                {
                this.state = 695;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                if (_la === 14 || _la === 25 || ((((_la - 44)) & ~0x1F) === 0 && ((1 << (_la - 44)) & 262209) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 1615069185) !== 0) || _la === 127 || _la === 128) {
                    {
                    this.state = 694;
                    this.identifier();
                    }
                }

                this.state = 697;
                this.parameterList();
                }
            }

            this.state = 700;
            this.block();
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public whileStatement(): WhileStatementContext {
        let localContext = new WhileStatementContext(this.context, this.state);
        this.enterRule(localContext, 106, SolidityParser.RULE_whileStatement);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 702;
            this.match(SolidityParser.T__54);
            this.state = 703;
            this.match(SolidityParser.T__22);
            this.state = 704;
            this.expression(0);
            this.state = 705;
            this.match(SolidityParser.T__23);
            this.state = 706;
            this.statement();
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public simpleStatement(): SimpleStatementContext {
        let localContext = new SimpleStatementContext(this.context, this.state);
        this.enterRule(localContext, 108, SolidityParser.RULE_simpleStatement);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 710;
            this.errorHandler.sync(this);
            switch (this.interpreter.adaptivePredict(this.tokenStream, 75, this.context) ) {
            case 1:
                {
                this.state = 708;
                this.variableDeclarationStatement();
                }
                break;
            case 2:
                {
                this.state = 709;
                this.expressionStatement();
                }
                break;
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public uncheckedStatement(): UncheckedStatementContext {
        let localContext = new UncheckedStatementContext(this.context, this.state);
        this.enterRule(localContext, 110, SolidityParser.RULE_uncheckedStatement);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 712;
            this.match(SolidityParser.T__55);
            this.state = 713;
            this.block();
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public forStatement(): ForStatementContext {
        let localContext = new ForStatementContext(this.context, this.state);
        this.enterRule(localContext, 112, SolidityParser.RULE_forStatement);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 715;
            this.match(SolidityParser.T__26);
            this.state = 716;
            this.match(SolidityParser.T__22);
            this.state = 719;
            this.errorHandler.sync(this);
            switch (this.tokenStream.LA(1)) {
            case SolidityParser.T__5:
            case SolidityParser.T__13:
            case SolidityParser.T__22:
            case SolidityParser.T__24:
            case SolidityParser.T__29:
            case SolidityParser.T__30:
            case SolidityParser.T__37:
            case SolidityParser.T__41:
            case SolidityParser.T__43:
            case SolidityParser.T__45:
            case SolidityParser.T__49:
            case SolidityParser.T__61:
            case SolidityParser.T__62:
            case SolidityParser.T__63:
            case SolidityParser.T__64:
            case SolidityParser.T__65:
            case SolidityParser.T__66:
            case SolidityParser.T__67:
            case SolidityParser.T__68:
            case SolidityParser.T__70:
            case SolidityParser.T__71:
            case SolidityParser.T__94:
            case SolidityParser.Int:
            case SolidityParser.Uint:
            case SolidityParser.Byte:
            case SolidityParser.Fixed:
            case SolidityParser.Ufixed:
            case SolidityParser.BooleanLiteral:
            case SolidityParser.DecimalNumber:
            case SolidityParser.HexNumber:
            case SolidityParser.HexLiteralFragment:
            case SolidityParser.LeaveKeyword:
            case SolidityParser.PayableKeyword:
            case SolidityParser.TypeKeyword:
            case SolidityParser.GlobalKeyword:
            case SolidityParser.ConstructorKeyword:
            case SolidityParser.ReceiveKeyword:
            case SolidityParser.Identifier:
            case SolidityParser.StringLiteralFragment:
                {
                this.state = 717;
                this.simpleStatement();
                }
                break;
            case SolidityParser.T__1:
                {
                this.state = 718;
                this.match(SolidityParser.T__1);
                }
                break;
            default:
                throw new antlr.NoViableAltException(this);
            }
            this.state = 723;
            this.errorHandler.sync(this);
            switch (this.tokenStream.LA(1)) {
            case SolidityParser.T__5:
            case SolidityParser.T__13:
            case SolidityParser.T__22:
            case SolidityParser.T__24:
            case SolidityParser.T__29:
            case SolidityParser.T__30:
            case SolidityParser.T__37:
            case SolidityParser.T__41:
            case SolidityParser.T__43:
            case SolidityParser.T__45:
            case SolidityParser.T__49:
            case SolidityParser.T__61:
            case SolidityParser.T__62:
            case SolidityParser.T__63:
            case SolidityParser.T__64:
            case SolidityParser.T__65:
            case SolidityParser.T__66:
            case SolidityParser.T__67:
            case SolidityParser.T__68:
            case SolidityParser.T__70:
            case SolidityParser.T__71:
            case SolidityParser.T__94:
            case SolidityParser.Int:
            case SolidityParser.Uint:
            case SolidityParser.Byte:
            case SolidityParser.Fixed:
            case SolidityParser.Ufixed:
            case SolidityParser.BooleanLiteral:
            case SolidityParser.DecimalNumber:
            case SolidityParser.HexNumber:
            case SolidityParser.HexLiteralFragment:
            case SolidityParser.LeaveKeyword:
            case SolidityParser.PayableKeyword:
            case SolidityParser.TypeKeyword:
            case SolidityParser.GlobalKeyword:
            case SolidityParser.ConstructorKeyword:
            case SolidityParser.ReceiveKeyword:
            case SolidityParser.Identifier:
            case SolidityParser.StringLiteralFragment:
                {
                this.state = 721;
                this.expressionStatement();
                }
                break;
            case SolidityParser.T__1:
                {
                this.state = 722;
                this.match(SolidityParser.T__1);
                }
                break;
            default:
                throw new antlr.NoViableAltException(this);
            }
            this.state = 726;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if ((((_la) & ~0x1F) === 0 && ((1 << _la) & 3263184960) !== 0) || ((((_la - 38)) & ~0x1F) === 0 && ((1 << (_la - 38)) & 4278194513) !== 0) || ((((_la - 71)) & ~0x1F) === 0 && ((1 << (_la - 71)) & 4244635651) !== 0) || ((((_la - 103)) & ~0x1F) === 0 && ((1 << (_la - 103)) & 124273675) !== 0)) {
                {
                this.state = 725;
                this.expression(0);
                }
            }

            this.state = 728;
            this.match(SolidityParser.T__23);
            this.state = 729;
            this.statement();
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public inlineAssemblyStatement(): InlineAssemblyStatementContext {
        let localContext = new InlineAssemblyStatementContext(this.context, this.state);
        this.enterRule(localContext, 114, SolidityParser.RULE_inlineAssemblyStatement);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 731;
            this.match(SolidityParser.T__56);
            this.state = 733;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 129) {
                {
                this.state = 732;
                this.match(SolidityParser.StringLiteralFragment);
                }
            }

            this.state = 739;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 23) {
                {
                this.state = 735;
                this.match(SolidityParser.T__22);
                this.state = 736;
                this.inlineAssemblyStatementFlag();
                this.state = 737;
                this.match(SolidityParser.T__23);
                }
            }

            this.state = 741;
            this.assemblyBlock();
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public inlineAssemblyStatementFlag(): InlineAssemblyStatementFlagContext {
        let localContext = new InlineAssemblyStatementFlagContext(this.context, this.state);
        this.enterRule(localContext, 116, SolidityParser.RULE_inlineAssemblyStatementFlag);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 743;
            this.stringLiteral();
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public doWhileStatement(): DoWhileStatementContext {
        let localContext = new DoWhileStatementContext(this.context, this.state);
        this.enterRule(localContext, 118, SolidityParser.RULE_doWhileStatement);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 745;
            this.match(SolidityParser.T__57);
            this.state = 746;
            this.statement();
            this.state = 747;
            this.match(SolidityParser.T__54);
            this.state = 748;
            this.match(SolidityParser.T__22);
            this.state = 749;
            this.expression(0);
            this.state = 750;
            this.match(SolidityParser.T__23);
            this.state = 751;
            this.match(SolidityParser.T__1);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public continueStatement(): ContinueStatementContext {
        let localContext = new ContinueStatementContext(this.context, this.state);
        this.enterRule(localContext, 120, SolidityParser.RULE_continueStatement);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 753;
            this.match(SolidityParser.ContinueKeyword);
            this.state = 754;
            this.match(SolidityParser.T__1);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public breakStatement(): BreakStatementContext {
        let localContext = new BreakStatementContext(this.context, this.state);
        this.enterRule(localContext, 122, SolidityParser.RULE_breakStatement);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 756;
            this.match(SolidityParser.BreakKeyword);
            this.state = 757;
            this.match(SolidityParser.T__1);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public returnStatement(): ReturnStatementContext {
        let localContext = new ReturnStatementContext(this.context, this.state);
        this.enterRule(localContext, 124, SolidityParser.RULE_returnStatement);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 759;
            this.match(SolidityParser.T__58);
            this.state = 761;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if ((((_la) & ~0x1F) === 0 && ((1 << _la) & 3263184960) !== 0) || ((((_la - 38)) & ~0x1F) === 0 && ((1 << (_la - 38)) & 4278194513) !== 0) || ((((_la - 71)) & ~0x1F) === 0 && ((1 << (_la - 71)) & 4244635651) !== 0) || ((((_la - 103)) & ~0x1F) === 0 && ((1 << (_la - 103)) & 124273675) !== 0)) {
                {
                this.state = 760;
                this.expression(0);
                }
            }

            this.state = 763;
            this.match(SolidityParser.T__1);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public throwStatement(): ThrowStatementContext {
        let localContext = new ThrowStatementContext(this.context, this.state);
        this.enterRule(localContext, 126, SolidityParser.RULE_throwStatement);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 765;
            this.match(SolidityParser.T__59);
            this.state = 766;
            this.match(SolidityParser.T__1);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public emitStatement(): EmitStatementContext {
        let localContext = new EmitStatementContext(this.context, this.state);
        this.enterRule(localContext, 128, SolidityParser.RULE_emitStatement);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 768;
            this.match(SolidityParser.T__60);
            this.state = 769;
            this.functionCall();
            this.state = 770;
            this.match(SolidityParser.T__1);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public revertStatement(): RevertStatementContext {
        let localContext = new RevertStatementContext(this.context, this.state);
        this.enterRule(localContext, 130, SolidityParser.RULE_revertStatement);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 772;
            this.match(SolidityParser.T__61);
            this.state = 773;
            this.functionCall();
            this.state = 774;
            this.match(SolidityParser.T__1);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public variableDeclarationStatement(): VariableDeclarationStatementContext {
        let localContext = new VariableDeclarationStatementContext(this.context, this.state);
        this.enterRule(localContext, 132, SolidityParser.RULE_variableDeclarationStatement);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 783;
            this.errorHandler.sync(this);
            switch (this.interpreter.adaptivePredict(this.tokenStream, 82, this.context) ) {
            case 1:
                {
                this.state = 776;
                this.match(SolidityParser.T__62);
                this.state = 777;
                this.identifierList();
                }
                break;
            case 2:
                {
                this.state = 778;
                this.variableDeclaration();
                }
                break;
            case 3:
                {
                this.state = 779;
                this.match(SolidityParser.T__22);
                this.state = 780;
                this.variableDeclarationList();
                this.state = 781;
                this.match(SolidityParser.T__23);
                }
                break;
            }
            this.state = 787;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 11) {
                {
                this.state = 785;
                this.match(SolidityParser.T__10);
                this.state = 786;
                this.expression(0);
                }
            }

            this.state = 789;
            this.match(SolidityParser.T__1);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public variableDeclarationList(): VariableDeclarationListContext {
        let localContext = new VariableDeclarationListContext(this.context, this.state);
        this.enterRule(localContext, 134, SolidityParser.RULE_variableDeclarationList);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 792;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 14 || _la === 25 || ((((_la - 38)) & ~0x1F) === 0 && ((1 << (_la - 38)) & 520098113) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 1615069309) !== 0) || _la === 127 || _la === 128) {
                {
                this.state = 791;
                this.variableDeclaration();
                }
            }

            this.state = 800;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            while (_la === 16) {
                {
                {
                this.state = 794;
                this.match(SolidityParser.T__15);
                this.state = 796;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                if (_la === 14 || _la === 25 || ((((_la - 38)) & ~0x1F) === 0 && ((1 << (_la - 38)) & 520098113) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 1615069309) !== 0) || _la === 127 || _la === 128) {
                    {
                    this.state = 795;
                    this.variableDeclaration();
                    }
                }

                }
                }
                this.state = 802;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public identifierList(): IdentifierListContext {
        let localContext = new IdentifierListContext(this.context, this.state);
        this.enterRule(localContext, 136, SolidityParser.RULE_identifierList);
        let _la: number;
        try {
            let alternative: number;
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 803;
            this.match(SolidityParser.T__22);
            this.state = 810;
            this.errorHandler.sync(this);
            alternative = this.interpreter.adaptivePredict(this.tokenStream, 88, this.context);
            while (alternative !== 2 && alternative !== antlr.ATN.INVALID_ALT_NUMBER) {
                if (alternative === 1) {
                    {
                    {
                    this.state = 805;
                    this.errorHandler.sync(this);
                    _la = this.tokenStream.LA(1);
                    if (_la === 14 || _la === 25 || ((((_la - 44)) & ~0x1F) === 0 && ((1 << (_la - 44)) & 262209) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 1615069185) !== 0) || _la === 127 || _la === 128) {
                        {
                        this.state = 804;
                        this.identifier();
                        }
                    }

                    this.state = 807;
                    this.match(SolidityParser.T__15);
                    }
                    }
                }
                this.state = 812;
                this.errorHandler.sync(this);
                alternative = this.interpreter.adaptivePredict(this.tokenStream, 88, this.context);
            }
            this.state = 814;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 14 || _la === 25 || ((((_la - 44)) & ~0x1F) === 0 && ((1 << (_la - 44)) & 262209) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 1615069185) !== 0) || _la === 127 || _la === 128) {
                {
                this.state = 813;
                this.identifier();
                }
            }

            this.state = 816;
            this.match(SolidityParser.T__23);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public elementaryTypeName(): ElementaryTypeNameContext {
        let localContext = new ElementaryTypeNameContext(this.context, this.state);
        this.enterRule(localContext, 138, SolidityParser.RULE_elementaryTypeName);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 818;
            _la = this.tokenStream.LA(1);
            if(!(((((_la - 44)) & ~0x1F) === 0 && ((1 << (_la - 44)) & 7864321) !== 0) || ((((_la - 97)) & ~0x1F) === 0 && ((1 << (_la - 97)) & 31) !== 0))) {
            this.errorHandler.recoverInline(this);
            }
            else {
                this.errorHandler.reportMatch(this);
                this.consume();
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }

    public expression(): ExpressionContext;
    public expression(_p: number): ExpressionContext;
    public expression(_p?: number): ExpressionContext {
        if (_p === undefined) {
            _p = 0;
        }

        let parentContext = this.context;
        let parentState = this.state;
        let localContext = new ExpressionContext(this.context, parentState);
        let previousContext = localContext;
        let _startState = 140;
        this.enterRecursionRule(localContext, 140, SolidityParser.RULE_expression, _p);
        let _la: number;
        try {
            let alternative: number;
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 838;
            this.errorHandler.sync(this);
            switch (this.interpreter.adaptivePredict(this.tokenStream, 90, this.context) ) {
            case 1:
                {
                this.state = 821;
                this.match(SolidityParser.T__68);
                this.state = 822;
                this.typeName(0);
                }
                break;
            case 2:
                {
                this.state = 823;
                this.match(SolidityParser.T__22);
                this.state = 824;
                this.expression(0);
                this.state = 825;
                this.match(SolidityParser.T__23);
                }
                break;
            case 3:
                {
                this.state = 827;
                _la = this.tokenStream.LA(1);
                if(!(_la === 67 || _la === 68)) {
                this.errorHandler.recoverInline(this);
                }
                else {
                    this.errorHandler.reportMatch(this);
                    this.consume();
                }
                this.state = 828;
                this.expression(19);
                }
                break;
            case 4:
                {
                this.state = 829;
                _la = this.tokenStream.LA(1);
                if(!(_la === 30 || _la === 31)) {
                this.errorHandler.recoverInline(this);
                }
                else {
                    this.errorHandler.reportMatch(this);
                    this.consume();
                }
                this.state = 830;
                this.expression(18);
                }
                break;
            case 5:
                {
                this.state = 831;
                this.match(SolidityParser.T__70);
                this.state = 832;
                this.expression(17);
                }
                break;
            case 6:
                {
                this.state = 833;
                this.match(SolidityParser.T__71);
                this.state = 834;
                this.expression(16);
                }
                break;
            case 7:
                {
                this.state = 835;
                this.match(SolidityParser.T__5);
                this.state = 836;
                this.expression(15);
                }
                break;
            case 8:
                {
                this.state = 837;
                this.primaryExpression();
                }
                break;
            }
            this.context!.stop = this.tokenStream.LT(-1);
            this.state = 914;
            this.errorHandler.sync(this);
            alternative = this.interpreter.adaptivePredict(this.tokenStream, 94, this.context);
            while (alternative !== 2 && alternative !== antlr.ATN.INVALID_ALT_NUMBER) {
                if (alternative === 1) {
                    if (this.parseListeners != null) {
                        this.triggerExitRuleEvent();
                    }
                    previousContext = localContext;
                    {
                    this.state = 912;
                    this.errorHandler.sync(this);
                    switch (this.interpreter.adaptivePredict(this.tokenStream, 93, this.context) ) {
                    case 1:
                        {
                        localContext = new ExpressionContext(parentContext, parentState);
                        this.pushNewRecursionContext(localContext, _startState, SolidityParser.RULE_expression);
                        this.state = 840;
                        if (!(this.precpred(this.context, 14))) {
                            throw this.createFailedPredicateException("this.precpred(this.context, 14)");
                        }
                        this.state = 841;
                        this.match(SolidityParser.T__72);
                        this.state = 842;
                        this.expression(14);
                        }
                        break;
                    case 2:
                        {
                        localContext = new ExpressionContext(parentContext, parentState);
                        this.pushNewRecursionContext(localContext, _startState, SolidityParser.RULE_expression);
                        this.state = 843;
                        if (!(this.precpred(this.context, 13))) {
                            throw this.createFailedPredicateException("this.precpred(this.context, 13)");
                        }
                        this.state = 844;
                        _la = this.tokenStream.LA(1);
                        if(!(((((_la - 3)) & ~0x1F) === 0 && ((1 << (_la - 3)) & 1610612737) !== 0))) {
                        this.errorHandler.recoverInline(this);
                        }
                        else {
                            this.errorHandler.reportMatch(this);
                            this.consume();
                        }
                        this.state = 845;
                        this.expression(14);
                        }
                        break;
                    case 3:
                        {
                        localContext = new ExpressionContext(parentContext, parentState);
                        this.pushNewRecursionContext(localContext, _startState, SolidityParser.RULE_expression);
                        this.state = 846;
                        if (!(this.precpred(this.context, 12))) {
                            throw this.createFailedPredicateException("this.precpred(this.context, 12)");
                        }
                        this.state = 847;
                        _la = this.tokenStream.LA(1);
                        if(!(_la === 30 || _la === 31)) {
                        this.errorHandler.recoverInline(this);
                        }
                        else {
                            this.errorHandler.reportMatch(this);
                            this.consume();
                        }
                        this.state = 848;
                        this.expression(13);
                        }
                        break;
                    case 4:
                        {
                        localContext = new ExpressionContext(parentContext, parentState);
                        this.pushNewRecursionContext(localContext, _startState, SolidityParser.RULE_expression);
                        this.state = 849;
                        if (!(this.precpred(this.context, 11))) {
                            throw this.createFailedPredicateException("this.precpred(this.context, 11)");
                        }
                        this.state = 850;
                        _la = this.tokenStream.LA(1);
                        if(!(_la === 74 || _la === 75)) {
                        this.errorHandler.recoverInline(this);
                        }
                        else {
                            this.errorHandler.reportMatch(this);
                            this.consume();
                        }
                        this.state = 851;
                        this.expression(12);
                        }
                        break;
                    case 5:
                        {
                        localContext = new ExpressionContext(parentContext, parentState);
                        this.pushNewRecursionContext(localContext, _startState, SolidityParser.RULE_expression);
                        this.state = 852;
                        if (!(this.precpred(this.context, 10))) {
                            throw this.createFailedPredicateException("this.precpred(this.context, 10)");
                        }
                        this.state = 853;
                        this.match(SolidityParser.T__28);
                        this.state = 854;
                        this.expression(11);
                        }
                        break;
                    case 6:
                        {
                        localContext = new ExpressionContext(parentContext, parentState);
                        this.pushNewRecursionContext(localContext, _startState, SolidityParser.RULE_expression);
                        this.state = 855;
                        if (!(this.precpred(this.context, 9))) {
                            throw this.createFailedPredicateException("this.precpred(this.context, 9)");
                        }
                        this.state = 856;
                        this.match(SolidityParser.T__4);
                        this.state = 857;
                        this.expression(10);
                        }
                        break;
                    case 7:
                        {
                        localContext = new ExpressionContext(parentContext, parentState);
                        this.pushNewRecursionContext(localContext, _startState, SolidityParser.RULE_expression);
                        this.state = 858;
                        if (!(this.precpred(this.context, 8))) {
                            throw this.createFailedPredicateException("this.precpred(this.context, 8)");
                        }
                        this.state = 859;
                        this.match(SolidityParser.T__27);
                        this.state = 860;
                        this.expression(9);
                        }
                        break;
                    case 8:
                        {
                        localContext = new ExpressionContext(parentContext, parentState);
                        this.pushNewRecursionContext(localContext, _startState, SolidityParser.RULE_expression);
                        this.state = 861;
                        if (!(this.precpred(this.context, 7))) {
                            throw this.createFailedPredicateException("this.precpred(this.context, 7)");
                        }
                        this.state = 862;
                        _la = this.tokenStream.LA(1);
                        if(!((((_la) & ~0x1F) === 0 && ((1 << _la) & 1920) !== 0))) {
                        this.errorHandler.recoverInline(this);
                        }
                        else {
                            this.errorHandler.reportMatch(this);
                            this.consume();
                        }
                        this.state = 863;
                        this.expression(8);
                        }
                        break;
                    case 9:
                        {
                        localContext = new ExpressionContext(parentContext, parentState);
                        this.pushNewRecursionContext(localContext, _startState, SolidityParser.RULE_expression);
                        this.state = 864;
                        if (!(this.precpred(this.context, 6))) {
                            throw this.createFailedPredicateException("this.precpred(this.context, 6)");
                        }
                        this.state = 865;
                        _la = this.tokenStream.LA(1);
                        if(!(_la === 34 || _la === 35)) {
                        this.errorHandler.recoverInline(this);
                        }
                        else {
                            this.errorHandler.reportMatch(this);
                            this.consume();
                        }
                        this.state = 866;
                        this.expression(7);
                        }
                        break;
                    case 10:
                        {
                        localContext = new ExpressionContext(parentContext, parentState);
                        this.pushNewRecursionContext(localContext, _startState, SolidityParser.RULE_expression);
                        this.state = 867;
                        if (!(this.precpred(this.context, 5))) {
                            throw this.createFailedPredicateException("this.precpred(this.context, 5)");
                        }
                        this.state = 868;
                        this.match(SolidityParser.T__75);
                        this.state = 869;
                        this.expression(6);
                        }
                        break;
                    case 11:
                        {
                        localContext = new ExpressionContext(parentContext, parentState);
                        this.pushNewRecursionContext(localContext, _startState, SolidityParser.RULE_expression);
                        this.state = 870;
                        if (!(this.precpred(this.context, 4))) {
                            throw this.createFailedPredicateException("this.precpred(this.context, 4)");
                        }
                        this.state = 871;
                        this.match(SolidityParser.T__3);
                        this.state = 872;
                        this.expression(5);
                        }
                        break;
                    case 12:
                        {
                        localContext = new ExpressionContext(parentContext, parentState);
                        this.pushNewRecursionContext(localContext, _startState, SolidityParser.RULE_expression);
                        this.state = 873;
                        if (!(this.precpred(this.context, 3))) {
                            throw this.createFailedPredicateException("this.precpred(this.context, 3)");
                        }
                        this.state = 874;
                        this.match(SolidityParser.T__76);
                        this.state = 875;
                        this.expression(0);
                        this.state = 876;
                        this.match(SolidityParser.T__69);
                        this.state = 877;
                        this.expression(3);
                        }
                        break;
                    case 13:
                        {
                        localContext = new ExpressionContext(parentContext, parentState);
                        this.pushNewRecursionContext(localContext, _startState, SolidityParser.RULE_expression);
                        this.state = 879;
                        if (!(this.precpred(this.context, 2))) {
                            throw this.createFailedPredicateException("this.precpred(this.context, 2)");
                        }
                        this.state = 880;
                        _la = this.tokenStream.LA(1);
                        if(!(_la === 11 || ((((_la - 78)) & ~0x1F) === 0 && ((1 << (_la - 78)) & 1023) !== 0))) {
                        this.errorHandler.recoverInline(this);
                        }
                        else {
                            this.errorHandler.reportMatch(this);
                            this.consume();
                        }
                        this.state = 881;
                        this.expression(3);
                        }
                        break;
                    case 14:
                        {
                        localContext = new ExpressionContext(parentContext, parentState);
                        this.pushNewRecursionContext(localContext, _startState, SolidityParser.RULE_expression);
                        this.state = 882;
                        if (!(this.precpred(this.context, 27))) {
                            throw this.createFailedPredicateException("this.precpred(this.context, 27)");
                        }
                        this.state = 883;
                        _la = this.tokenStream.LA(1);
                        if(!(_la === 67 || _la === 68)) {
                        this.errorHandler.recoverInline(this);
                        }
                        else {
                            this.errorHandler.reportMatch(this);
                            this.consume();
                        }
                        }
                        break;
                    case 15:
                        {
                        localContext = new ExpressionContext(parentContext, parentState);
                        this.pushNewRecursionContext(localContext, _startState, SolidityParser.RULE_expression);
                        this.state = 884;
                        if (!(this.precpred(this.context, 25))) {
                            throw this.createFailedPredicateException("this.precpred(this.context, 25)");
                        }
                        this.state = 885;
                        this.match(SolidityParser.T__41);
                        this.state = 886;
                        this.expression(0);
                        this.state = 887;
                        this.match(SolidityParser.T__42);
                        }
                        break;
                    case 16:
                        {
                        localContext = new ExpressionContext(parentContext, parentState);
                        this.pushNewRecursionContext(localContext, _startState, SolidityParser.RULE_expression);
                        this.state = 889;
                        if (!(this.precpred(this.context, 24))) {
                            throw this.createFailedPredicateException("this.precpred(this.context, 24)");
                        }
                        this.state = 890;
                        this.match(SolidityParser.T__41);
                        this.state = 892;
                        this.errorHandler.sync(this);
                        _la = this.tokenStream.LA(1);
                        if ((((_la) & ~0x1F) === 0 && ((1 << _la) & 3263184960) !== 0) || ((((_la - 38)) & ~0x1F) === 0 && ((1 << (_la - 38)) & 4278194513) !== 0) || ((((_la - 71)) & ~0x1F) === 0 && ((1 << (_la - 71)) & 4244635651) !== 0) || ((((_la - 103)) & ~0x1F) === 0 && ((1 << (_la - 103)) & 124273675) !== 0)) {
                            {
                            this.state = 891;
                            this.expression(0);
                            }
                        }

                        this.state = 894;
                        this.match(SolidityParser.T__69);
                        this.state = 896;
                        this.errorHandler.sync(this);
                        _la = this.tokenStream.LA(1);
                        if ((((_la) & ~0x1F) === 0 && ((1 << _la) & 3263184960) !== 0) || ((((_la - 38)) & ~0x1F) === 0 && ((1 << (_la - 38)) & 4278194513) !== 0) || ((((_la - 71)) & ~0x1F) === 0 && ((1 << (_la - 71)) & 4244635651) !== 0) || ((((_la - 103)) & ~0x1F) === 0 && ((1 << (_la - 103)) & 124273675) !== 0)) {
                            {
                            this.state = 895;
                            this.expression(0);
                            }
                        }

                        this.state = 898;
                        this.match(SolidityParser.T__42);
                        }
                        break;
                    case 17:
                        {
                        localContext = new ExpressionContext(parentContext, parentState);
                        this.pushNewRecursionContext(localContext, _startState, SolidityParser.RULE_expression);
                        this.state = 899;
                        if (!(this.precpred(this.context, 23))) {
                            throw this.createFailedPredicateException("this.precpred(this.context, 23)");
                        }
                        this.state = 900;
                        this.match(SolidityParser.T__44);
                        this.state = 901;
                        this.identifier();
                        }
                        break;
                    case 18:
                        {
                        localContext = new ExpressionContext(parentContext, parentState);
                        this.pushNewRecursionContext(localContext, _startState, SolidityParser.RULE_expression);
                        this.state = 902;
                        if (!(this.precpred(this.context, 22))) {
                            throw this.createFailedPredicateException("this.precpred(this.context, 22)");
                        }
                        this.state = 903;
                        this.match(SolidityParser.T__14);
                        this.state = 904;
                        this.nameValueList();
                        this.state = 905;
                        this.match(SolidityParser.T__16);
                        }
                        break;
                    case 19:
                        {
                        localContext = new ExpressionContext(parentContext, parentState);
                        this.pushNewRecursionContext(localContext, _startState, SolidityParser.RULE_expression);
                        this.state = 907;
                        if (!(this.precpred(this.context, 21))) {
                            throw this.createFailedPredicateException("this.precpred(this.context, 21)");
                        }
                        this.state = 908;
                        this.match(SolidityParser.T__22);
                        this.state = 909;
                        this.functionCallArguments();
                        this.state = 910;
                        this.match(SolidityParser.T__23);
                        }
                        break;
                    }
                    }
                }
                this.state = 916;
                this.errorHandler.sync(this);
                alternative = this.interpreter.adaptivePredict(this.tokenStream, 94, this.context);
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.unrollRecursionContexts(parentContext);
        }
        return localContext;
    }
    public primaryExpression(): PrimaryExpressionContext {
        let localContext = new PrimaryExpressionContext(this.context, this.state);
        this.enterRule(localContext, 142, SolidityParser.RULE_primaryExpression);
        try {
            this.state = 926;
            this.errorHandler.sync(this);
            switch (this.interpreter.adaptivePredict(this.tokenStream, 95, this.context) ) {
            case 1:
                this.enterOuterAlt(localContext, 1);
                {
                this.state = 917;
                this.match(SolidityParser.BooleanLiteral);
                }
                break;
            case 2:
                this.enterOuterAlt(localContext, 2);
                {
                this.state = 918;
                this.numberLiteral();
                }
                break;
            case 3:
                this.enterOuterAlt(localContext, 3);
                {
                this.state = 919;
                this.hexLiteral();
                }
                break;
            case 4:
                this.enterOuterAlt(localContext, 4);
                {
                this.state = 920;
                this.stringLiteral();
                }
                break;
            case 5:
                this.enterOuterAlt(localContext, 5);
                {
                this.state = 921;
                this.identifier();
                }
                break;
            case 6:
                this.enterOuterAlt(localContext, 6);
                {
                this.state = 922;
                this.match(SolidityParser.TypeKeyword);
                }
                break;
            case 7:
                this.enterOuterAlt(localContext, 7);
                {
                this.state = 923;
                this.match(SolidityParser.PayableKeyword);
                }
                break;
            case 8:
                this.enterOuterAlt(localContext, 8);
                {
                this.state = 924;
                this.tupleExpression();
                }
                break;
            case 9:
                this.enterOuterAlt(localContext, 9);
                {
                this.state = 925;
                this.typeName(0);
                }
                break;
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public expressionList(): ExpressionListContext {
        let localContext = new ExpressionListContext(this.context, this.state);
        this.enterRule(localContext, 144, SolidityParser.RULE_expressionList);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 928;
            this.expression(0);
            this.state = 933;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            while (_la === 16) {
                {
                {
                this.state = 929;
                this.match(SolidityParser.T__15);
                this.state = 930;
                this.expression(0);
                }
                }
                this.state = 935;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public nameValueList(): NameValueListContext {
        let localContext = new NameValueListContext(this.context, this.state);
        this.enterRule(localContext, 146, SolidityParser.RULE_nameValueList);
        let _la: number;
        try {
            let alternative: number;
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 936;
            this.nameValue();
            this.state = 941;
            this.errorHandler.sync(this);
            alternative = this.interpreter.adaptivePredict(this.tokenStream, 97, this.context);
            while (alternative !== 2 && alternative !== antlr.ATN.INVALID_ALT_NUMBER) {
                if (alternative === 1) {
                    {
                    {
                    this.state = 937;
                    this.match(SolidityParser.T__15);
                    this.state = 938;
                    this.nameValue();
                    }
                    }
                }
                this.state = 943;
                this.errorHandler.sync(this);
                alternative = this.interpreter.adaptivePredict(this.tokenStream, 97, this.context);
            }
            this.state = 945;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 16) {
                {
                this.state = 944;
                this.match(SolidityParser.T__15);
                }
            }

            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public nameValue(): NameValueContext {
        let localContext = new NameValueContext(this.context, this.state);
        this.enterRule(localContext, 148, SolidityParser.RULE_nameValue);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 947;
            this.identifier();
            this.state = 948;
            this.match(SolidityParser.T__69);
            this.state = 949;
            this.expression(0);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public functionCallArguments(): FunctionCallArgumentsContext {
        let localContext = new FunctionCallArgumentsContext(this.context, this.state);
        this.enterRule(localContext, 150, SolidityParser.RULE_functionCallArguments);
        let _la: number;
        try {
            this.state = 959;
            this.errorHandler.sync(this);
            switch (this.tokenStream.LA(1)) {
            case SolidityParser.T__14:
                this.enterOuterAlt(localContext, 1);
                {
                this.state = 951;
                this.match(SolidityParser.T__14);
                this.state = 953;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                if (_la === 14 || _la === 25 || ((((_la - 44)) & ~0x1F) === 0 && ((1 << (_la - 44)) & 262209) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 1615069185) !== 0) || _la === 127 || _la === 128) {
                    {
                    this.state = 952;
                    this.nameValueList();
                    }
                }

                this.state = 955;
                this.match(SolidityParser.T__16);
                }
                break;
            case SolidityParser.T__5:
            case SolidityParser.T__13:
            case SolidityParser.T__22:
            case SolidityParser.T__23:
            case SolidityParser.T__24:
            case SolidityParser.T__29:
            case SolidityParser.T__30:
            case SolidityParser.T__37:
            case SolidityParser.T__41:
            case SolidityParser.T__43:
            case SolidityParser.T__45:
            case SolidityParser.T__49:
            case SolidityParser.T__61:
            case SolidityParser.T__62:
            case SolidityParser.T__63:
            case SolidityParser.T__64:
            case SolidityParser.T__65:
            case SolidityParser.T__66:
            case SolidityParser.T__67:
            case SolidityParser.T__68:
            case SolidityParser.T__70:
            case SolidityParser.T__71:
            case SolidityParser.T__94:
            case SolidityParser.Int:
            case SolidityParser.Uint:
            case SolidityParser.Byte:
            case SolidityParser.Fixed:
            case SolidityParser.Ufixed:
            case SolidityParser.BooleanLiteral:
            case SolidityParser.DecimalNumber:
            case SolidityParser.HexNumber:
            case SolidityParser.HexLiteralFragment:
            case SolidityParser.LeaveKeyword:
            case SolidityParser.PayableKeyword:
            case SolidityParser.TypeKeyword:
            case SolidityParser.GlobalKeyword:
            case SolidityParser.ConstructorKeyword:
            case SolidityParser.ReceiveKeyword:
            case SolidityParser.Identifier:
            case SolidityParser.StringLiteralFragment:
                this.enterOuterAlt(localContext, 2);
                {
                this.state = 957;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                if ((((_la) & ~0x1F) === 0 && ((1 << _la) & 3263184960) !== 0) || ((((_la - 38)) & ~0x1F) === 0 && ((1 << (_la - 38)) & 4278194513) !== 0) || ((((_la - 71)) & ~0x1F) === 0 && ((1 << (_la - 71)) & 4244635651) !== 0) || ((((_la - 103)) & ~0x1F) === 0 && ((1 << (_la - 103)) & 124273675) !== 0)) {
                    {
                    this.state = 956;
                    this.expressionList();
                    }
                }

                }
                break;
            default:
                throw new antlr.NoViableAltException(this);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public functionCall(): FunctionCallContext {
        let localContext = new FunctionCallContext(this.context, this.state);
        this.enterRule(localContext, 152, SolidityParser.RULE_functionCall);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 961;
            this.expression(0);
            this.state = 962;
            this.match(SolidityParser.T__22);
            this.state = 963;
            this.functionCallArguments();
            this.state = 964;
            this.match(SolidityParser.T__23);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public assemblyBlock(): AssemblyBlockContext {
        let localContext = new AssemblyBlockContext(this.context, this.state);
        this.enterRule(localContext, 154, SolidityParser.RULE_assemblyBlock);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 966;
            this.match(SolidityParser.T__14);
            this.state = 970;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            while ((((_la) & ~0x1F) === 0 && ((1 << _la) & 176209920) !== 0) || ((((_la - 38)) & ~0x1F) === 0 && ((1 << (_la - 38)) & 287322177) !== 0) || ((((_la - 88)) & ~0x1F) === 0 && ((1 << (_la - 88)) & 589676681) !== 0) || ((((_la - 124)) & ~0x1F) === 0 && ((1 << (_la - 124)) & 59) !== 0)) {
                {
                {
                this.state = 967;
                this.assemblyItem();
                }
                }
                this.state = 972;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
            }
            this.state = 973;
            this.match(SolidityParser.T__16);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public assemblyItem(): AssemblyItemContext {
        let localContext = new AssemblyItemContext(this.context, this.state);
        this.enterRule(localContext, 156, SolidityParser.RULE_assemblyItem);
        try {
            this.state = 992;
            this.errorHandler.sync(this);
            switch (this.interpreter.adaptivePredict(this.tokenStream, 103, this.context) ) {
            case 1:
                this.enterOuterAlt(localContext, 1);
                {
                this.state = 975;
                this.identifier();
                }
                break;
            case 2:
                this.enterOuterAlt(localContext, 2);
                {
                this.state = 976;
                this.assemblyBlock();
                }
                break;
            case 3:
                this.enterOuterAlt(localContext, 3);
                {
                this.state = 977;
                this.assemblyExpression();
                }
                break;
            case 4:
                this.enterOuterAlt(localContext, 4);
                {
                this.state = 978;
                this.assemblyLocalDefinition();
                }
                break;
            case 5:
                this.enterOuterAlt(localContext, 5);
                {
                this.state = 979;
                this.assemblyAssignment();
                }
                break;
            case 6:
                this.enterOuterAlt(localContext, 6);
                {
                this.state = 980;
                this.assemblyStackAssignment();
                }
                break;
            case 7:
                this.enterOuterAlt(localContext, 7);
                {
                this.state = 981;
                this.labelDefinition();
                }
                break;
            case 8:
                this.enterOuterAlt(localContext, 8);
                {
                this.state = 982;
                this.assemblySwitch();
                }
                break;
            case 9:
                this.enterOuterAlt(localContext, 9);
                {
                this.state = 983;
                this.assemblyFunctionDefinition();
                }
                break;
            case 10:
                this.enterOuterAlt(localContext, 10);
                {
                this.state = 984;
                this.assemblyFor();
                }
                break;
            case 11:
                this.enterOuterAlt(localContext, 11);
                {
                this.state = 985;
                this.assemblyIf();
                }
                break;
            case 12:
                this.enterOuterAlt(localContext, 12);
                {
                this.state = 986;
                this.match(SolidityParser.BreakKeyword);
                }
                break;
            case 13:
                this.enterOuterAlt(localContext, 13);
                {
                this.state = 987;
                this.match(SolidityParser.ContinueKeyword);
                }
                break;
            case 14:
                this.enterOuterAlt(localContext, 14);
                {
                this.state = 988;
                this.match(SolidityParser.LeaveKeyword);
                }
                break;
            case 15:
                this.enterOuterAlt(localContext, 15);
                {
                this.state = 989;
                this.numberLiteral();
                }
                break;
            case 16:
                this.enterOuterAlt(localContext, 16);
                {
                this.state = 990;
                this.stringLiteral();
                }
                break;
            case 17:
                this.enterOuterAlt(localContext, 17);
                {
                this.state = 991;
                this.hexLiteral();
                }
                break;
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public assemblyExpression(): AssemblyExpressionContext {
        let localContext = new AssemblyExpressionContext(this.context, this.state);
        this.enterRule(localContext, 158, SolidityParser.RULE_assemblyExpression);
        try {
            this.state = 997;
            this.errorHandler.sync(this);
            switch (this.interpreter.adaptivePredict(this.tokenStream, 104, this.context) ) {
            case 1:
                this.enterOuterAlt(localContext, 1);
                {
                this.state = 994;
                this.assemblyCall();
                }
                break;
            case 2:
                this.enterOuterAlt(localContext, 2);
                {
                this.state = 995;
                this.assemblyLiteral();
                }
                break;
            case 3:
                this.enterOuterAlt(localContext, 3);
                {
                this.state = 996;
                this.assemblyMember();
                }
                break;
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public assemblyMember(): AssemblyMemberContext {
        let localContext = new AssemblyMemberContext(this.context, this.state);
        this.enterRule(localContext, 160, SolidityParser.RULE_assemblyMember);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 999;
            this.identifier();
            this.state = 1000;
            this.match(SolidityParser.T__44);
            this.state = 1001;
            this.identifier();
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public assemblyCall(): AssemblyCallContext {
        let localContext = new AssemblyCallContext(this.context, this.state);
        this.enterRule(localContext, 162, SolidityParser.RULE_assemblyCall);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 1007;
            this.errorHandler.sync(this);
            switch (this.interpreter.adaptivePredict(this.tokenStream, 105, this.context) ) {
            case 1:
                {
                this.state = 1003;
                this.match(SolidityParser.T__58);
                }
                break;
            case 2:
                {
                this.state = 1004;
                this.match(SolidityParser.T__43);
                }
                break;
            case 3:
                {
                this.state = 1005;
                this.match(SolidityParser.T__65);
                }
                break;
            case 4:
                {
                this.state = 1006;
                this.identifier();
                }
                break;
            }
            this.state = 1021;
            this.errorHandler.sync(this);
            switch (this.interpreter.adaptivePredict(this.tokenStream, 108, this.context) ) {
            case 1:
                {
                this.state = 1009;
                this.match(SolidityParser.T__22);
                this.state = 1011;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                if (_la === 14 || _la === 25 || ((((_la - 44)) & ~0x1F) === 0 && ((1 << (_la - 44)) & 4489281) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 1615072129) !== 0) || ((((_la - 127)) & ~0x1F) === 0 && ((1 << (_la - 127)) & 7) !== 0)) {
                    {
                    this.state = 1010;
                    this.assemblyExpression();
                    }
                }

                this.state = 1017;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                while (_la === 16) {
                    {
                    {
                    this.state = 1013;
                    this.match(SolidityParser.T__15);
                    this.state = 1014;
                    this.assemblyExpression();
                    }
                    }
                    this.state = 1019;
                    this.errorHandler.sync(this);
                    _la = this.tokenStream.LA(1);
                }
                this.state = 1020;
                this.match(SolidityParser.T__23);
                }
                break;
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public assemblyLocalDefinition(): AssemblyLocalDefinitionContext {
        let localContext = new AssemblyLocalDefinitionContext(this.context, this.state);
        this.enterRule(localContext, 164, SolidityParser.RULE_assemblyLocalDefinition);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 1023;
            this.match(SolidityParser.T__87);
            this.state = 1024;
            this.assemblyIdentifierOrList();
            this.state = 1027;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 89) {
                {
                this.state = 1025;
                this.match(SolidityParser.T__88);
                this.state = 1026;
                this.assemblyExpression();
                }
            }

            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public assemblyAssignment(): AssemblyAssignmentContext {
        let localContext = new AssemblyAssignmentContext(this.context, this.state);
        this.enterRule(localContext, 166, SolidityParser.RULE_assemblyAssignment);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 1029;
            this.assemblyIdentifierOrList();
            this.state = 1030;
            this.match(SolidityParser.T__88);
            this.state = 1031;
            this.assemblyExpression();
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public assemblyIdentifierOrList(): AssemblyIdentifierOrListContext {
        let localContext = new AssemblyIdentifierOrListContext(this.context, this.state);
        this.enterRule(localContext, 168, SolidityParser.RULE_assemblyIdentifierOrList);
        try {
            this.state = 1040;
            this.errorHandler.sync(this);
            switch (this.interpreter.adaptivePredict(this.tokenStream, 110, this.context) ) {
            case 1:
                this.enterOuterAlt(localContext, 1);
                {
                this.state = 1033;
                this.identifier();
                }
                break;
            case 2:
                this.enterOuterAlt(localContext, 2);
                {
                this.state = 1034;
                this.assemblyMember();
                }
                break;
            case 3:
                this.enterOuterAlt(localContext, 3);
                {
                this.state = 1035;
                this.assemblyIdentifierList();
                }
                break;
            case 4:
                this.enterOuterAlt(localContext, 4);
                {
                this.state = 1036;
                this.match(SolidityParser.T__22);
                this.state = 1037;
                this.assemblyIdentifierList();
                this.state = 1038;
                this.match(SolidityParser.T__23);
                }
                break;
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public assemblyIdentifierList(): AssemblyIdentifierListContext {
        let localContext = new AssemblyIdentifierListContext(this.context, this.state);
        this.enterRule(localContext, 170, SolidityParser.RULE_assemblyIdentifierList);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 1042;
            this.identifier();
            this.state = 1047;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            while (_la === 16) {
                {
                {
                this.state = 1043;
                this.match(SolidityParser.T__15);
                this.state = 1044;
                this.identifier();
                }
                }
                this.state = 1049;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public assemblyStackAssignment(): AssemblyStackAssignmentContext {
        let localContext = new AssemblyStackAssignmentContext(this.context, this.state);
        this.enterRule(localContext, 172, SolidityParser.RULE_assemblyStackAssignment);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 1050;
            this.assemblyExpression();
            this.state = 1051;
            this.match(SolidityParser.T__89);
            this.state = 1052;
            this.identifier();
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public labelDefinition(): LabelDefinitionContext {
        let localContext = new LabelDefinitionContext(this.context, this.state);
        this.enterRule(localContext, 174, SolidityParser.RULE_labelDefinition);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 1054;
            this.identifier();
            this.state = 1055;
            this.match(SolidityParser.T__69);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public assemblySwitch(): AssemblySwitchContext {
        let localContext = new AssemblySwitchContext(this.context, this.state);
        this.enterRule(localContext, 176, SolidityParser.RULE_assemblySwitch);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 1057;
            this.match(SolidityParser.T__90);
            this.state = 1058;
            this.assemblyExpression();
            this.state = 1062;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            while (_la === 92 || _la === 93) {
                {
                {
                this.state = 1059;
                this.assemblyCase();
                }
                }
                this.state = 1064;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public assemblyCase(): AssemblyCaseContext {
        let localContext = new AssemblyCaseContext(this.context, this.state);
        this.enterRule(localContext, 178, SolidityParser.RULE_assemblyCase);
        try {
            this.state = 1071;
            this.errorHandler.sync(this);
            switch (this.tokenStream.LA(1)) {
            case SolidityParser.T__91:
                this.enterOuterAlt(localContext, 1);
                {
                this.state = 1065;
                this.match(SolidityParser.T__91);
                this.state = 1066;
                this.assemblyLiteral();
                this.state = 1067;
                this.assemblyBlock();
                }
                break;
            case SolidityParser.T__92:
                this.enterOuterAlt(localContext, 2);
                {
                this.state = 1069;
                this.match(SolidityParser.T__92);
                this.state = 1070;
                this.assemblyBlock();
                }
                break;
            default:
                throw new antlr.NoViableAltException(this);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public assemblyFunctionDefinition(): AssemblyFunctionDefinitionContext {
        let localContext = new AssemblyFunctionDefinitionContext(this.context, this.state);
        this.enterRule(localContext, 180, SolidityParser.RULE_assemblyFunctionDefinition);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 1073;
            this.match(SolidityParser.T__37);
            this.state = 1074;
            this.identifier();
            this.state = 1075;
            this.match(SolidityParser.T__22);
            this.state = 1077;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 14 || _la === 25 || ((((_la - 44)) & ~0x1F) === 0 && ((1 << (_la - 44)) & 262209) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 1615069185) !== 0) || _la === 127 || _la === 128) {
                {
                this.state = 1076;
                this.assemblyIdentifierList();
                }
            }

            this.state = 1079;
            this.match(SolidityParser.T__23);
            this.state = 1081;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 94) {
                {
                this.state = 1080;
                this.assemblyFunctionReturns();
                }
            }

            this.state = 1083;
            this.assemblyBlock();
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public assemblyFunctionReturns(): AssemblyFunctionReturnsContext {
        let localContext = new AssemblyFunctionReturnsContext(this.context, this.state);
        this.enterRule(localContext, 182, SolidityParser.RULE_assemblyFunctionReturns);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            {
            this.state = 1085;
            this.match(SolidityParser.T__93);
            this.state = 1086;
            this.assemblyIdentifierList();
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public assemblyFor(): AssemblyForContext {
        let localContext = new AssemblyForContext(this.context, this.state);
        this.enterRule(localContext, 184, SolidityParser.RULE_assemblyFor);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 1088;
            this.match(SolidityParser.T__26);
            this.state = 1091;
            this.errorHandler.sync(this);
            switch (this.tokenStream.LA(1)) {
            case SolidityParser.T__14:
                {
                this.state = 1089;
                this.assemblyBlock();
                }
                break;
            case SolidityParser.T__13:
            case SolidityParser.T__24:
            case SolidityParser.T__43:
            case SolidityParser.T__49:
            case SolidityParser.T__58:
            case SolidityParser.T__61:
            case SolidityParser.T__65:
            case SolidityParser.T__94:
            case SolidityParser.BooleanLiteral:
            case SolidityParser.DecimalNumber:
            case SolidityParser.HexNumber:
            case SolidityParser.HexLiteralFragment:
            case SolidityParser.LeaveKeyword:
            case SolidityParser.PayableKeyword:
            case SolidityParser.GlobalKeyword:
            case SolidityParser.ConstructorKeyword:
            case SolidityParser.ReceiveKeyword:
            case SolidityParser.Identifier:
            case SolidityParser.StringLiteralFragment:
                {
                this.state = 1090;
                this.assemblyExpression();
                }
                break;
            default:
                throw new antlr.NoViableAltException(this);
            }
            this.state = 1093;
            this.assemblyExpression();
            this.state = 1096;
            this.errorHandler.sync(this);
            switch (this.tokenStream.LA(1)) {
            case SolidityParser.T__14:
                {
                this.state = 1094;
                this.assemblyBlock();
                }
                break;
            case SolidityParser.T__13:
            case SolidityParser.T__24:
            case SolidityParser.T__43:
            case SolidityParser.T__49:
            case SolidityParser.T__58:
            case SolidityParser.T__61:
            case SolidityParser.T__65:
            case SolidityParser.T__94:
            case SolidityParser.BooleanLiteral:
            case SolidityParser.DecimalNumber:
            case SolidityParser.HexNumber:
            case SolidityParser.HexLiteralFragment:
            case SolidityParser.LeaveKeyword:
            case SolidityParser.PayableKeyword:
            case SolidityParser.GlobalKeyword:
            case SolidityParser.ConstructorKeyword:
            case SolidityParser.ReceiveKeyword:
            case SolidityParser.Identifier:
            case SolidityParser.StringLiteralFragment:
                {
                this.state = 1095;
                this.assemblyExpression();
                }
                break;
            default:
                throw new antlr.NoViableAltException(this);
            }
            this.state = 1098;
            this.assemblyBlock();
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public assemblyIf(): AssemblyIfContext {
        let localContext = new AssemblyIfContext(this.context, this.state);
        this.enterRule(localContext, 186, SolidityParser.RULE_assemblyIf);
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 1100;
            this.match(SolidityParser.T__50);
            this.state = 1101;
            this.assemblyExpression();
            this.state = 1102;
            this.assemblyBlock();
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public assemblyLiteral(): AssemblyLiteralContext {
        let localContext = new AssemblyLiteralContext(this.context, this.state);
        this.enterRule(localContext, 188, SolidityParser.RULE_assemblyLiteral);
        try {
            this.state = 1109;
            this.errorHandler.sync(this);
            switch (this.tokenStream.LA(1)) {
            case SolidityParser.StringLiteralFragment:
                this.enterOuterAlt(localContext, 1);
                {
                this.state = 1104;
                this.stringLiteral();
                }
                break;
            case SolidityParser.DecimalNumber:
                this.enterOuterAlt(localContext, 2);
                {
                this.state = 1105;
                this.match(SolidityParser.DecimalNumber);
                }
                break;
            case SolidityParser.HexNumber:
                this.enterOuterAlt(localContext, 3);
                {
                this.state = 1106;
                this.match(SolidityParser.HexNumber);
                }
                break;
            case SolidityParser.HexLiteralFragment:
                this.enterOuterAlt(localContext, 4);
                {
                this.state = 1107;
                this.hexLiteral();
                }
                break;
            case SolidityParser.BooleanLiteral:
                this.enterOuterAlt(localContext, 5);
                {
                this.state = 1108;
                this.match(SolidityParser.BooleanLiteral);
                }
                break;
            default:
                throw new antlr.NoViableAltException(this);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public tupleExpression(): TupleExpressionContext {
        let localContext = new TupleExpressionContext(this.context, this.state);
        this.enterRule(localContext, 190, SolidityParser.RULE_tupleExpression);
        let _la: number;
        try {
            this.state = 1137;
            this.errorHandler.sync(this);
            switch (this.tokenStream.LA(1)) {
            case SolidityParser.T__22:
                this.enterOuterAlt(localContext, 1);
                {
                this.state = 1111;
                this.match(SolidityParser.T__22);
                {
                this.state = 1113;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                if ((((_la) & ~0x1F) === 0 && ((1 << _la) & 3263184960) !== 0) || ((((_la - 38)) & ~0x1F) === 0 && ((1 << (_la - 38)) & 4278194513) !== 0) || ((((_la - 71)) & ~0x1F) === 0 && ((1 << (_la - 71)) & 4244635651) !== 0) || ((((_la - 103)) & ~0x1F) === 0 && ((1 << (_la - 103)) & 124273675) !== 0)) {
                    {
                    this.state = 1112;
                    this.expression(0);
                    }
                }

                this.state = 1121;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                while (_la === 16) {
                    {
                    {
                    this.state = 1115;
                    this.match(SolidityParser.T__15);
                    this.state = 1117;
                    this.errorHandler.sync(this);
                    _la = this.tokenStream.LA(1);
                    if ((((_la) & ~0x1F) === 0 && ((1 << _la) & 3263184960) !== 0) || ((((_la - 38)) & ~0x1F) === 0 && ((1 << (_la - 38)) & 4278194513) !== 0) || ((((_la - 71)) & ~0x1F) === 0 && ((1 << (_la - 71)) & 4244635651) !== 0) || ((((_la - 103)) & ~0x1F) === 0 && ((1 << (_la - 103)) & 124273675) !== 0)) {
                        {
                        this.state = 1116;
                        this.expression(0);
                        }
                    }

                    }
                    }
                    this.state = 1123;
                    this.errorHandler.sync(this);
                    _la = this.tokenStream.LA(1);
                }
                }
                this.state = 1124;
                this.match(SolidityParser.T__23);
                }
                break;
            case SolidityParser.T__41:
                this.enterOuterAlt(localContext, 2);
                {
                this.state = 1125;
                this.match(SolidityParser.T__41);
                this.state = 1134;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                if ((((_la) & ~0x1F) === 0 && ((1 << _la) & 3263184960) !== 0) || ((((_la - 38)) & ~0x1F) === 0 && ((1 << (_la - 38)) & 4278194513) !== 0) || ((((_la - 71)) & ~0x1F) === 0 && ((1 << (_la - 71)) & 4244635651) !== 0) || ((((_la - 103)) & ~0x1F) === 0 && ((1 << (_la - 103)) & 124273675) !== 0)) {
                    {
                    this.state = 1126;
                    this.expression(0);
                    this.state = 1131;
                    this.errorHandler.sync(this);
                    _la = this.tokenStream.LA(1);
                    while (_la === 16) {
                        {
                        {
                        this.state = 1127;
                        this.match(SolidityParser.T__15);
                        this.state = 1128;
                        this.expression(0);
                        }
                        }
                        this.state = 1133;
                        this.errorHandler.sync(this);
                        _la = this.tokenStream.LA(1);
                    }
                    }
                }

                this.state = 1136;
                this.match(SolidityParser.T__42);
                }
                break;
            default:
                throw new antlr.NoViableAltException(this);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public numberLiteral(): NumberLiteralContext {
        let localContext = new NumberLiteralContext(this.context, this.state);
        this.enterRule(localContext, 192, SolidityParser.RULE_numberLiteral);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 1139;
            _la = this.tokenStream.LA(1);
            if(!(_la === 103 || _la === 104)) {
            this.errorHandler.recoverInline(this);
            }
            else {
                this.errorHandler.reportMatch(this);
                this.consume();
            }
            this.state = 1141;
            this.errorHandler.sync(this);
            switch (this.interpreter.adaptivePredict(this.tokenStream, 125, this.context) ) {
            case 1:
                {
                this.state = 1140;
                this.match(SolidityParser.NumberUnit);
                }
                break;
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public identifier(): IdentifierContext {
        let localContext = new IdentifierContext(this.context, this.state);
        this.enterRule(localContext, 194, SolidityParser.RULE_identifier);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 1143;
            _la = this.tokenStream.LA(1);
            if(!(_la === 14 || _la === 25 || ((((_la - 44)) & ~0x1F) === 0 && ((1 << (_la - 44)) & 262209) !== 0) || ((((_la - 95)) & ~0x1F) === 0 && ((1 << (_la - 95)) & 1615069185) !== 0) || _la === 127 || _la === 128)) {
            this.errorHandler.recoverInline(this);
            }
            else {
                this.errorHandler.reportMatch(this);
                this.consume();
            }
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public hexLiteral(): HexLiteralContext {
        let localContext = new HexLiteralContext(this.context, this.state);
        this.enterRule(localContext, 196, SolidityParser.RULE_hexLiteral);
        try {
            let alternative: number;
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 1146;
            this.errorHandler.sync(this);
            alternative = 1;
            do {
                switch (alternative) {
                case 1:
                    {
                    {
                    this.state = 1145;
                    this.match(SolidityParser.HexLiteralFragment);
                    }
                    }
                    break;
                default:
                    throw new antlr.NoViableAltException(this);
                }
                this.state = 1148;
                this.errorHandler.sync(this);
                alternative = this.interpreter.adaptivePredict(this.tokenStream, 126, this.context);
            } while (alternative !== 2 && alternative !== antlr.ATN.INVALID_ALT_NUMBER);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public overrideSpecifier(): OverrideSpecifierContext {
        let localContext = new OverrideSpecifierContext(this.context, this.state);
        this.enterRule(localContext, 198, SolidityParser.RULE_overrideSpecifier);
        let _la: number;
        try {
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 1150;
            this.match(SolidityParser.T__95);
            this.state = 1162;
            this.errorHandler.sync(this);
            _la = this.tokenStream.LA(1);
            if (_la === 23) {
                {
                this.state = 1151;
                this.match(SolidityParser.T__22);
                this.state = 1152;
                this.userDefinedTypeName();
                this.state = 1157;
                this.errorHandler.sync(this);
                _la = this.tokenStream.LA(1);
                while (_la === 16) {
                    {
                    {
                    this.state = 1153;
                    this.match(SolidityParser.T__15);
                    this.state = 1154;
                    this.userDefinedTypeName();
                    }
                    }
                    this.state = 1159;
                    this.errorHandler.sync(this);
                    _la = this.tokenStream.LA(1);
                }
                this.state = 1160;
                this.match(SolidityParser.T__23);
                }
            }

            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }
    public stringLiteral(): StringLiteralContext {
        let localContext = new StringLiteralContext(this.context, this.state);
        this.enterRule(localContext, 200, SolidityParser.RULE_stringLiteral);
        try {
            let alternative: number;
            this.enterOuterAlt(localContext, 1);
            {
            this.state = 1165;
            this.errorHandler.sync(this);
            alternative = 1;
            do {
                switch (alternative) {
                case 1:
                    {
                    {
                    this.state = 1164;
                    this.match(SolidityParser.StringLiteralFragment);
                    }
                    }
                    break;
                default:
                    throw new antlr.NoViableAltException(this);
                }
                this.state = 1167;
                this.errorHandler.sync(this);
                alternative = this.interpreter.adaptivePredict(this.tokenStream, 129, this.context);
            } while (alternative !== 2 && alternative !== antlr.ATN.INVALID_ALT_NUMBER);
            }
        }
        catch (re) {
            if (re instanceof antlr.RecognitionException) {
                this.errorHandler.reportError(this, re);
                this.errorHandler.recover(this, re);
            } else {
                throw re;
            }
        }
        finally {
            this.exitRule();
        }
        return localContext;
    }

    public override sempred(localContext: antlr.ParserRuleContext | null, ruleIndex: number, predIndex: number): boolean {
        switch (ruleIndex) {
        case 38:
            return this.typeName_sempred(localContext as TypeNameContext, predIndex);
        case 70:
            return this.expression_sempred(localContext as ExpressionContext, predIndex);
        }
        return true;
    }
    private typeName_sempred(localContext: TypeNameContext | null, predIndex: number): boolean {
        switch (predIndex) {
        case 0:
            return this.precpred(this.context, 3);
        }
        return true;
    }
    private expression_sempred(localContext: ExpressionContext | null, predIndex: number): boolean {
        switch (predIndex) {
        case 1:
            return this.precpred(this.context, 14);
        case 2:
            return this.precpred(this.context, 13);
        case 3:
            return this.precpred(this.context, 12);
        case 4:
            return this.precpred(this.context, 11);
        case 5:
            return this.precpred(this.context, 10);
        case 6:
            return this.precpred(this.context, 9);
        case 7:
            return this.precpred(this.context, 8);
        case 8:
            return this.precpred(this.context, 7);
        case 9:
            return this.precpred(this.context, 6);
        case 10:
            return this.precpred(this.context, 5);
        case 11:
            return this.precpred(this.context, 4);
        case 12:
            return this.precpred(this.context, 3);
        case 13:
            return this.precpred(this.context, 2);
        case 14:
            return this.precpred(this.context, 27);
        case 15:
            return this.precpred(this.context, 25);
        case 16:
            return this.precpred(this.context, 24);
        case 17:
            return this.precpred(this.context, 23);
        case 18:
            return this.precpred(this.context, 22);
        case 19:
            return this.precpred(this.context, 21);
        }
        return true;
    }

    public static readonly _serializedATN: number[] = [
        4,1,133,1170,2,0,7,0,2,1,7,1,2,2,7,2,2,3,7,3,2,4,7,4,2,5,7,5,2,6,
        7,6,2,7,7,7,2,8,7,8,2,9,7,9,2,10,7,10,2,11,7,11,2,12,7,12,2,13,7,
        13,2,14,7,14,2,15,7,15,2,16,7,16,2,17,7,17,2,18,7,18,2,19,7,19,2,
        20,7,20,2,21,7,21,2,22,7,22,2,23,7,23,2,24,7,24,2,25,7,25,2,26,7,
        26,2,27,7,27,2,28,7,28,2,29,7,29,2,30,7,30,2,31,7,31,2,32,7,32,2,
        33,7,33,2,34,7,34,2,35,7,35,2,36,7,36,2,37,7,37,2,38,7,38,2,39,7,
        39,2,40,7,40,2,41,7,41,2,42,7,42,2,43,7,43,2,44,7,44,2,45,7,45,2,
        46,7,46,2,47,7,47,2,48,7,48,2,49,7,49,2,50,7,50,2,51,7,51,2,52,7,
        52,2,53,7,53,2,54,7,54,2,55,7,55,2,56,7,56,2,57,7,57,2,58,7,58,2,
        59,7,59,2,60,7,60,2,61,7,61,2,62,7,62,2,63,7,63,2,64,7,64,2,65,7,
        65,2,66,7,66,2,67,7,67,2,68,7,68,2,69,7,69,2,70,7,70,2,71,7,71,2,
        72,7,72,2,73,7,73,2,74,7,74,2,75,7,75,2,76,7,76,2,77,7,77,2,78,7,
        78,2,79,7,79,2,80,7,80,2,81,7,81,2,82,7,82,2,83,7,83,2,84,7,84,2,
        85,7,85,2,86,7,86,2,87,7,87,2,88,7,88,2,89,7,89,2,90,7,90,2,91,7,
        91,2,92,7,92,2,93,7,93,2,94,7,94,2,95,7,95,2,96,7,96,2,97,7,97,2,
        98,7,98,2,99,7,99,2,100,7,100,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,
        0,1,0,1,0,5,0,214,8,0,10,0,12,0,217,9,0,1,0,1,0,1,1,1,1,1,1,1,1,
        1,1,1,2,1,2,1,3,1,3,1,3,3,3,231,8,3,1,4,1,4,3,4,235,8,4,1,4,5,4,
        238,8,4,10,4,12,4,241,9,4,1,5,1,5,1,6,3,6,246,8,6,1,6,1,6,3,6,250,
        8,6,1,6,3,6,253,8,6,1,7,1,7,1,7,3,7,258,8,7,1,8,1,8,1,8,1,8,3,8,
        264,8,8,1,8,1,8,1,8,1,8,1,8,3,8,271,8,8,1,8,1,8,3,8,275,8,8,1,8,
        1,8,1,8,1,8,1,8,1,8,1,8,1,8,1,8,5,8,286,8,8,10,8,12,8,289,9,8,1,
        8,1,8,1,8,1,8,1,8,3,8,296,8,8,1,9,1,9,1,10,3,10,301,8,10,1,10,1,
        10,1,10,1,10,1,10,1,10,5,10,309,8,10,10,10,12,10,312,9,10,3,10,314,
        8,10,1,10,1,10,5,10,318,8,10,10,10,12,10,321,9,10,1,10,1,10,1,11,
        1,11,1,11,3,11,328,8,11,1,11,3,11,331,8,11,1,12,1,12,1,12,1,12,1,
        12,1,12,1,12,1,12,1,12,3,12,342,8,12,1,13,1,13,1,13,1,13,1,13,1,
        13,1,13,5,13,351,8,13,10,13,12,13,354,9,13,1,13,1,13,1,13,3,13,359,
        8,13,1,13,1,13,1,14,1,14,1,14,1,14,1,14,1,14,1,14,1,15,1,15,1,15,
        1,15,1,15,1,16,1,16,1,16,1,16,1,16,1,16,1,17,1,17,1,17,1,17,1,17,
        3,17,386,8,17,1,17,3,17,389,8,17,1,17,1,17,1,18,1,18,1,18,1,18,1,
        18,5,18,398,8,18,10,18,12,18,401,9,18,1,18,1,18,3,18,405,8,18,1,
        19,1,19,1,19,3,19,410,8,19,1,20,1,20,1,21,1,21,1,21,1,21,1,21,1,
        21,1,21,1,21,5,21,422,8,21,10,21,12,21,425,9,21,3,21,427,8,21,1,
        21,1,21,1,22,1,22,1,22,3,22,434,8,22,1,22,1,22,5,22,438,8,22,10,
        22,12,22,441,9,22,1,22,1,22,3,22,445,8,22,1,23,1,23,1,23,3,23,450,
        8,23,1,23,3,23,453,8,23,1,24,1,24,1,24,1,24,3,24,459,8,24,1,24,1,
        24,3,24,463,8,24,1,25,1,25,3,25,467,8,25,1,25,1,25,1,25,3,25,472,
        8,25,1,26,1,26,1,26,1,27,1,27,1,27,1,27,1,27,1,27,1,27,1,27,5,27,
        485,8,27,10,27,12,27,488,9,27,1,28,1,28,1,28,1,28,3,28,494,8,28,
        1,28,1,28,1,29,1,29,1,30,1,30,1,30,1,30,3,30,504,8,30,1,30,1,30,
        5,30,508,8,30,10,30,12,30,511,9,30,1,30,1,30,1,31,1,31,1,31,1,31,
        5,31,519,8,31,10,31,12,31,522,9,31,3,31,524,8,31,1,31,1,31,1,32,
        1,32,3,32,530,8,32,1,32,3,32,533,8,32,1,33,1,33,1,33,1,33,5,33,539,
        8,33,10,33,12,33,542,9,33,3,33,544,8,33,1,33,1,33,1,34,1,34,3,34,
        550,8,34,1,34,3,34,553,8,34,1,35,1,35,1,35,1,35,5,35,559,8,35,10,
        35,12,35,562,9,35,3,35,564,8,35,1,35,1,35,1,36,1,36,3,36,570,8,36,
        1,37,1,37,3,37,574,8,37,1,37,1,37,1,38,1,38,1,38,1,38,1,38,1,38,
        1,38,3,38,585,8,38,1,38,1,38,1,38,3,38,590,8,38,1,38,5,38,593,8,
        38,10,38,12,38,596,9,38,1,39,1,39,1,39,5,39,601,8,39,10,39,12,39,
        604,9,39,1,40,1,40,3,40,608,8,40,1,41,1,41,1,41,1,41,3,41,614,8,
        41,1,41,1,41,1,41,3,41,619,8,41,1,41,1,41,1,42,1,42,1,43,1,43,1,
        44,1,44,1,44,1,44,1,44,5,44,632,8,44,10,44,12,44,635,9,44,1,44,1,
        44,3,44,639,8,44,1,45,1,45,1,46,1,46,1,47,1,47,5,47,647,8,47,10,
        47,12,47,650,9,47,1,47,1,47,1,48,1,48,1,48,1,48,1,48,1,48,1,48,1,
        48,1,48,1,48,1,48,1,48,1,48,1,48,1,48,3,48,669,8,48,1,49,1,49,1,
        49,1,50,1,50,1,50,1,50,1,50,1,50,1,50,3,50,681,8,50,1,51,1,51,1,
        51,3,51,686,8,51,1,51,1,51,4,51,690,8,51,11,51,12,51,691,1,52,1,
        52,3,52,696,8,52,1,52,3,52,699,8,52,1,52,1,52,1,53,1,53,1,53,1,53,
        1,53,1,53,1,54,1,54,3,54,711,8,54,1,55,1,55,1,55,1,56,1,56,1,56,
        1,56,3,56,720,8,56,1,56,1,56,3,56,724,8,56,1,56,3,56,727,8,56,1,
        56,1,56,1,56,1,57,1,57,3,57,734,8,57,1,57,1,57,1,57,1,57,3,57,740,
        8,57,1,57,1,57,1,58,1,58,1,59,1,59,1,59,1,59,1,59,1,59,1,59,1,59,
        1,60,1,60,1,60,1,61,1,61,1,61,1,62,1,62,3,62,762,8,62,1,62,1,62,
        1,63,1,63,1,63,1,64,1,64,1,64,1,64,1,65,1,65,1,65,1,65,1,66,1,66,
        1,66,1,66,1,66,1,66,1,66,3,66,784,8,66,1,66,1,66,3,66,788,8,66,1,
        66,1,66,1,67,3,67,793,8,67,1,67,1,67,3,67,797,8,67,5,67,799,8,67,
        10,67,12,67,802,9,67,1,68,1,68,3,68,806,8,68,1,68,5,68,809,8,68,
        10,68,12,68,812,9,68,1,68,3,68,815,8,68,1,68,1,68,1,69,1,69,1,70,
        1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,
        1,70,1,70,1,70,1,70,3,70,839,8,70,1,70,1,70,1,70,1,70,1,70,1,70,
        1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,
        1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,
        1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,
        1,70,1,70,1,70,1,70,1,70,1,70,1,70,3,70,893,8,70,1,70,1,70,3,70,
        897,8,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,1,70,
        1,70,1,70,1,70,5,70,913,8,70,10,70,12,70,916,9,70,1,71,1,71,1,71,
        1,71,1,71,1,71,1,71,1,71,1,71,3,71,927,8,71,1,72,1,72,1,72,5,72,
        932,8,72,10,72,12,72,935,9,72,1,73,1,73,1,73,5,73,940,8,73,10,73,
        12,73,943,9,73,1,73,3,73,946,8,73,1,74,1,74,1,74,1,74,1,75,1,75,
        3,75,954,8,75,1,75,1,75,3,75,958,8,75,3,75,960,8,75,1,76,1,76,1,
        76,1,76,1,76,1,77,1,77,5,77,969,8,77,10,77,12,77,972,9,77,1,77,1,
        77,1,78,1,78,1,78,1,78,1,78,1,78,1,78,1,78,1,78,1,78,1,78,1,78,1,
        78,1,78,1,78,1,78,1,78,3,78,993,8,78,1,79,1,79,1,79,3,79,998,8,79,
        1,80,1,80,1,80,1,80,1,81,1,81,1,81,1,81,3,81,1008,8,81,1,81,1,81,
        3,81,1012,8,81,1,81,1,81,5,81,1016,8,81,10,81,12,81,1019,9,81,1,
        81,3,81,1022,8,81,1,82,1,82,1,82,1,82,3,82,1028,8,82,1,83,1,83,1,
        83,1,83,1,84,1,84,1,84,1,84,1,84,1,84,1,84,3,84,1041,8,84,1,85,1,
        85,1,85,5,85,1046,8,85,10,85,12,85,1049,9,85,1,86,1,86,1,86,1,86,
        1,87,1,87,1,87,1,88,1,88,1,88,5,88,1061,8,88,10,88,12,88,1064,9,
        88,1,89,1,89,1,89,1,89,1,89,1,89,3,89,1072,8,89,1,90,1,90,1,90,1,
        90,3,90,1078,8,90,1,90,1,90,3,90,1082,8,90,1,90,1,90,1,91,1,91,1,
        91,1,92,1,92,1,92,3,92,1092,8,92,1,92,1,92,1,92,3,92,1097,8,92,1,
        92,1,92,1,93,1,93,1,93,1,93,1,94,1,94,1,94,1,94,1,94,3,94,1110,8,
        94,1,95,1,95,3,95,1114,8,95,1,95,1,95,3,95,1118,8,95,5,95,1120,8,
        95,10,95,12,95,1123,9,95,1,95,1,95,1,95,1,95,1,95,5,95,1130,8,95,
        10,95,12,95,1133,9,95,3,95,1135,8,95,1,95,3,95,1138,8,95,1,96,1,
        96,3,96,1142,8,96,1,97,1,97,1,98,4,98,1147,8,98,11,98,12,98,1148,
        1,99,1,99,1,99,1,99,1,99,5,99,1156,8,99,10,99,12,99,1159,9,99,1,
        99,1,99,3,99,1163,8,99,1,100,4,100,1166,8,100,11,100,12,100,1167,
        1,100,0,2,76,140,101,0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,
        32,34,36,38,40,42,44,46,48,50,52,54,56,58,60,62,64,66,68,70,72,74,
        76,78,80,82,84,86,88,90,92,94,96,98,100,102,104,106,108,110,112,
        114,116,118,120,122,124,126,128,130,132,134,136,138,140,142,144,
        146,148,150,152,154,156,158,160,162,164,166,168,170,172,174,176,
        178,180,182,184,186,188,190,192,194,196,198,200,0,15,1,0,5,11,1,
        0,19,21,3,0,3,3,5,10,28,35,1,0,48,50,4,0,110,110,117,117,121,121,
        123,123,3,0,44,44,63,66,97,101,1,0,67,68,1,0,30,31,2,0,3,3,32,33,
        1,0,74,75,1,0,7,10,1,0,34,35,2,0,11,11,78,87,1,0,103,104,10,0,14,
        14,25,25,44,44,50,50,62,62,95,95,113,113,117,117,124,125,127,128,
        1299,0,215,1,0,0,0,2,220,1,0,0,0,4,225,1,0,0,0,6,230,1,0,0,0,8,232,
        1,0,0,0,10,242,1,0,0,0,12,252,1,0,0,0,14,254,1,0,0,0,16,295,1,0,
        0,0,18,297,1,0,0,0,20,300,1,0,0,0,22,324,1,0,0,0,24,341,1,0,0,0,
        26,343,1,0,0,0,28,362,1,0,0,0,30,369,1,0,0,0,32,374,1,0,0,0,34,380,
        1,0,0,0,36,404,1,0,0,0,38,406,1,0,0,0,40,411,1,0,0,0,42,413,1,0,
        0,0,44,430,1,0,0,0,46,446,1,0,0,0,48,454,1,0,0,0,50,471,1,0,0,0,
        52,473,1,0,0,0,54,486,1,0,0,0,56,489,1,0,0,0,58,497,1,0,0,0,60,499,
        1,0,0,0,62,514,1,0,0,0,64,527,1,0,0,0,66,534,1,0,0,0,68,547,1,0,
        0,0,70,554,1,0,0,0,72,567,1,0,0,0,74,571,1,0,0,0,76,584,1,0,0,0,
        78,597,1,0,0,0,80,607,1,0,0,0,82,609,1,0,0,0,84,622,1,0,0,0,86,624,
        1,0,0,0,88,626,1,0,0,0,90,640,1,0,0,0,92,642,1,0,0,0,94,644,1,0,
        0,0,96,668,1,0,0,0,98,670,1,0,0,0,100,673,1,0,0,0,102,682,1,0,0,
        0,104,693,1,0,0,0,106,702,1,0,0,0,108,710,1,0,0,0,110,712,1,0,0,
        0,112,715,1,0,0,0,114,731,1,0,0,0,116,743,1,0,0,0,118,745,1,0,0,
        0,120,753,1,0,0,0,122,756,1,0,0,0,124,759,1,0,0,0,126,765,1,0,0,
        0,128,768,1,0,0,0,130,772,1,0,0,0,132,783,1,0,0,0,134,792,1,0,0,
        0,136,803,1,0,0,0,138,818,1,0,0,0,140,838,1,0,0,0,142,926,1,0,0,
        0,144,928,1,0,0,0,146,936,1,0,0,0,148,947,1,0,0,0,150,959,1,0,0,
        0,152,961,1,0,0,0,154,966,1,0,0,0,156,992,1,0,0,0,158,997,1,0,0,
        0,160,999,1,0,0,0,162,1007,1,0,0,0,164,1023,1,0,0,0,166,1029,1,0,
        0,0,168,1040,1,0,0,0,170,1042,1,0,0,0,172,1050,1,0,0,0,174,1054,
        1,0,0,0,176,1057,1,0,0,0,178,1071,1,0,0,0,180,1073,1,0,0,0,182,1085,
        1,0,0,0,184,1088,1,0,0,0,186,1100,1,0,0,0,188,1109,1,0,0,0,190,1137,
        1,0,0,0,192,1139,1,0,0,0,194,1143,1,0,0,0,196,1146,1,0,0,0,198,1150,
        1,0,0,0,200,1165,1,0,0,0,202,214,3,2,1,0,203,214,3,16,8,0,204,214,
        3,20,10,0,205,214,3,60,30,0,206,214,3,56,28,0,207,214,3,42,21,0,
        208,214,3,48,24,0,209,214,3,28,14,0,210,214,3,30,15,0,211,214,3,
        32,16,0,212,214,3,34,17,0,213,202,1,0,0,0,213,203,1,0,0,0,213,204,
        1,0,0,0,213,205,1,0,0,0,213,206,1,0,0,0,213,207,1,0,0,0,213,208,
        1,0,0,0,213,209,1,0,0,0,213,210,1,0,0,0,213,211,1,0,0,0,213,212,
        1,0,0,0,214,217,1,0,0,0,215,213,1,0,0,0,215,216,1,0,0,0,216,218,
        1,0,0,0,217,215,1,0,0,0,218,219,5,0,0,1,219,1,1,0,0,0,220,221,5,
        1,0,0,221,222,3,4,2,0,222,223,3,6,3,0,223,224,5,2,0,0,224,3,1,0,
        0,0,225,226,3,194,97,0,226,5,1,0,0,0,227,231,5,3,0,0,228,231,3,8,
        4,0,229,231,3,140,70,0,230,227,1,0,0,0,230,228,1,0,0,0,230,229,1,
        0,0,0,231,7,1,0,0,0,232,239,3,12,6,0,233,235,5,4,0,0,234,233,1,0,
        0,0,234,235,1,0,0,0,235,236,1,0,0,0,236,238,3,12,6,0,237,234,1,0,
        0,0,238,241,1,0,0,0,239,237,1,0,0,0,239,240,1,0,0,0,240,9,1,0,0,
        0,241,239,1,0,0,0,242,243,7,0,0,0,243,11,1,0,0,0,244,246,3,10,5,
        0,245,244,1,0,0,0,245,246,1,0,0,0,246,247,1,0,0,0,247,253,5,130,
        0,0,248,250,3,10,5,0,249,248,1,0,0,0,249,250,1,0,0,0,250,251,1,0,
        0,0,251,253,5,103,0,0,252,245,1,0,0,0,252,249,1,0,0,0,253,13,1,0,
        0,0,254,257,3,194,97,0,255,256,5,12,0,0,256,258,3,194,97,0,257,255,
        1,0,0,0,257,258,1,0,0,0,258,15,1,0,0,0,259,260,5,13,0,0,260,263,
        3,18,9,0,261,262,5,12,0,0,262,264,3,194,97,0,263,261,1,0,0,0,263,
        264,1,0,0,0,264,265,1,0,0,0,265,266,5,2,0,0,266,296,1,0,0,0,267,
        270,5,13,0,0,268,271,5,3,0,0,269,271,3,194,97,0,270,268,1,0,0,0,
        270,269,1,0,0,0,271,274,1,0,0,0,272,273,5,12,0,0,273,275,3,194,97,
        0,274,272,1,0,0,0,274,275,1,0,0,0,275,276,1,0,0,0,276,277,5,14,0,
        0,277,278,3,18,9,0,278,279,5,2,0,0,279,296,1,0,0,0,280,281,5,13,
        0,0,281,282,5,15,0,0,282,287,3,14,7,0,283,284,5,16,0,0,284,286,3,
        14,7,0,285,283,1,0,0,0,286,289,1,0,0,0,287,285,1,0,0,0,287,288,1,
        0,0,0,288,290,1,0,0,0,289,287,1,0,0,0,290,291,5,17,0,0,291,292,5,
        14,0,0,292,293,3,18,9,0,293,294,5,2,0,0,294,296,1,0,0,0,295,259,
        1,0,0,0,295,267,1,0,0,0,295,280,1,0,0,0,296,17,1,0,0,0,297,298,5,
        129,0,0,298,19,1,0,0,0,299,301,5,18,0,0,300,299,1,0,0,0,300,301,
        1,0,0,0,301,302,1,0,0,0,302,303,7,1,0,0,303,313,3,194,97,0,304,305,
        5,22,0,0,305,310,3,22,11,0,306,307,5,16,0,0,307,309,3,22,11,0,308,
        306,1,0,0,0,309,312,1,0,0,0,310,308,1,0,0,0,310,311,1,0,0,0,311,
        314,1,0,0,0,312,310,1,0,0,0,313,304,1,0,0,0,313,314,1,0,0,0,314,
        315,1,0,0,0,315,319,5,15,0,0,316,318,3,24,12,0,317,316,1,0,0,0,318,
        321,1,0,0,0,319,317,1,0,0,0,319,320,1,0,0,0,320,322,1,0,0,0,321,
        319,1,0,0,0,322,323,5,17,0,0,323,21,1,0,0,0,324,330,3,78,39,0,325,
        327,5,23,0,0,326,328,3,144,72,0,327,326,1,0,0,0,327,328,1,0,0,0,
        328,329,1,0,0,0,329,331,5,24,0,0,330,325,1,0,0,0,330,331,1,0,0,0,
        331,23,1,0,0,0,332,342,3,26,13,0,333,342,3,34,17,0,334,342,3,42,
        21,0,335,342,3,44,22,0,336,342,3,48,24,0,337,342,3,56,28,0,338,342,
        3,60,30,0,339,342,3,30,15,0,340,342,3,32,16,0,341,332,1,0,0,0,341,
        333,1,0,0,0,341,334,1,0,0,0,341,335,1,0,0,0,341,336,1,0,0,0,341,
        337,1,0,0,0,341,338,1,0,0,0,341,339,1,0,0,0,341,340,1,0,0,0,342,
        25,1,0,0,0,343,352,3,76,38,0,344,351,5,119,0,0,345,351,5,116,0,0,
        346,351,5,118,0,0,347,351,5,110,0,0,348,351,5,111,0,0,349,351,3,
        198,99,0,350,344,1,0,0,0,350,345,1,0,0,0,350,346,1,0,0,0,350,347,
        1,0,0,0,350,348,1,0,0,0,350,349,1,0,0,0,351,354,1,0,0,0,352,350,
        1,0,0,0,352,353,1,0,0,0,353,355,1,0,0,0,354,352,1,0,0,0,355,358,
        3,194,97,0,356,357,5,11,0,0,357,359,3,140,70,0,358,356,1,0,0,0,358,
        359,1,0,0,0,359,360,1,0,0,0,360,361,5,2,0,0,361,27,1,0,0,0,362,363,
        3,76,38,0,363,364,5,110,0,0,364,365,3,194,97,0,365,366,5,11,0,0,
        366,367,3,140,70,0,367,368,5,2,0,0,368,29,1,0,0,0,369,370,5,25,0,
        0,370,371,3,194,97,0,371,372,3,62,31,0,372,373,5,2,0,0,373,31,1,
        0,0,0,374,375,5,122,0,0,375,376,3,194,97,0,376,377,5,22,0,0,377,
        378,3,138,69,0,378,379,5,2,0,0,379,33,1,0,0,0,380,381,5,26,0,0,381,
        382,3,36,18,0,382,385,5,27,0,0,383,386,5,3,0,0,384,386,3,76,38,0,
        385,383,1,0,0,0,385,384,1,0,0,0,386,388,1,0,0,0,387,389,5,124,0,
        0,388,387,1,0,0,0,388,389,1,0,0,0,389,390,1,0,0,0,390,391,5,2,0,
        0,391,35,1,0,0,0,392,405,3,78,39,0,393,394,5,15,0,0,394,399,3,38,
        19,0,395,396,5,16,0,0,396,398,3,38,19,0,397,395,1,0,0,0,398,401,
        1,0,0,0,399,397,1,0,0,0,399,400,1,0,0,0,400,402,1,0,0,0,401,399,
        1,0,0,0,402,403,5,17,0,0,403,405,1,0,0,0,404,392,1,0,0,0,404,393,
        1,0,0,0,405,37,1,0,0,0,406,409,3,78,39,0,407,408,5,12,0,0,408,410,
        3,40,20,0,409,407,1,0,0,0,409,410,1,0,0,0,410,39,1,0,0,0,411,412,
        7,2,0,0,412,41,1,0,0,0,413,414,5,36,0,0,414,415,3,194,97,0,415,426,
        5,15,0,0,416,417,3,74,37,0,417,423,5,2,0,0,418,419,3,74,37,0,419,
        420,5,2,0,0,420,422,1,0,0,0,421,418,1,0,0,0,422,425,1,0,0,0,423,
        421,1,0,0,0,423,424,1,0,0,0,424,427,1,0,0,0,425,423,1,0,0,0,426,
        416,1,0,0,0,426,427,1,0,0,0,427,428,1,0,0,0,428,429,5,17,0,0,429,
        43,1,0,0,0,430,431,5,37,0,0,431,433,3,194,97,0,432,434,3,62,31,0,
        433,432,1,0,0,0,433,434,1,0,0,0,434,439,1,0,0,0,435,438,5,120,0,
        0,436,438,3,198,99,0,437,435,1,0,0,0,437,436,1,0,0,0,438,441,1,0,
        0,0,439,437,1,0,0,0,439,440,1,0,0,0,440,444,1,0,0,0,441,439,1,0,
        0,0,442,445,5,2,0,0,443,445,3,94,47,0,444,442,1,0,0,0,444,443,1,
        0,0,0,445,45,1,0,0,0,446,452,3,194,97,0,447,449,5,23,0,0,448,450,
        3,144,72,0,449,448,1,0,0,0,449,450,1,0,0,0,450,451,1,0,0,0,451,453,
        5,24,0,0,452,447,1,0,0,0,452,453,1,0,0,0,453,47,1,0,0,0,454,455,
        3,50,25,0,455,456,3,62,31,0,456,458,3,54,27,0,457,459,3,52,26,0,
        458,457,1,0,0,0,458,459,1,0,0,0,459,462,1,0,0,0,460,463,5,2,0,0,
        461,463,3,94,47,0,462,460,1,0,0,0,462,461,1,0,0,0,463,49,1,0,0,0,
        464,466,5,38,0,0,465,467,3,194,97,0,466,465,1,0,0,0,466,467,1,0,
        0,0,467,472,1,0,0,0,468,472,5,125,0,0,469,472,5,126,0,0,470,472,
        5,127,0,0,471,464,1,0,0,0,471,468,1,0,0,0,471,469,1,0,0,0,471,470,
        1,0,0,0,472,51,1,0,0,0,473,474,5,39,0,0,474,475,3,62,31,0,475,53,
        1,0,0,0,476,485,5,114,0,0,477,485,5,119,0,0,478,485,5,116,0,0,479,
        485,5,118,0,0,480,485,5,120,0,0,481,485,3,92,46,0,482,485,3,46,23,
        0,483,485,3,198,99,0,484,476,1,0,0,0,484,477,1,0,0,0,484,478,1,0,
        0,0,484,479,1,0,0,0,484,480,1,0,0,0,484,481,1,0,0,0,484,482,1,0,
        0,0,484,483,1,0,0,0,485,488,1,0,0,0,486,484,1,0,0,0,486,487,1,0,
        0,0,487,55,1,0,0,0,488,486,1,0,0,0,489,490,5,40,0,0,490,491,3,194,
        97,0,491,493,3,66,33,0,492,494,5,108,0,0,493,492,1,0,0,0,493,494,
        1,0,0,0,494,495,1,0,0,0,495,496,5,2,0,0,496,57,1,0,0,0,497,498,3,
        194,97,0,498,59,1,0,0,0,499,500,5,41,0,0,500,501,3,194,97,0,501,
        503,5,15,0,0,502,504,3,58,29,0,503,502,1,0,0,0,503,504,1,0,0,0,504,
        509,1,0,0,0,505,506,5,16,0,0,506,508,3,58,29,0,507,505,1,0,0,0,508,
        511,1,0,0,0,509,507,1,0,0,0,509,510,1,0,0,0,510,512,1,0,0,0,511,
        509,1,0,0,0,512,513,5,17,0,0,513,61,1,0,0,0,514,523,5,23,0,0,515,
        520,3,64,32,0,516,517,5,16,0,0,517,519,3,64,32,0,518,516,1,0,0,0,
        519,522,1,0,0,0,520,518,1,0,0,0,520,521,1,0,0,0,521,524,1,0,0,0,
        522,520,1,0,0,0,523,515,1,0,0,0,523,524,1,0,0,0,524,525,1,0,0,0,
        525,526,5,24,0,0,526,63,1,0,0,0,527,529,3,76,38,0,528,530,3,90,45,
        0,529,528,1,0,0,0,529,530,1,0,0,0,530,532,1,0,0,0,531,533,3,194,
        97,0,532,531,1,0,0,0,532,533,1,0,0,0,533,65,1,0,0,0,534,543,5,23,
        0,0,535,540,3,68,34,0,536,537,5,16,0,0,537,539,3,68,34,0,538,536,
        1,0,0,0,539,542,1,0,0,0,540,538,1,0,0,0,540,541,1,0,0,0,541,544,
        1,0,0,0,542,540,1,0,0,0,543,535,1,0,0,0,543,544,1,0,0,0,544,545,
        1,0,0,0,545,546,5,24,0,0,546,67,1,0,0,0,547,549,3,76,38,0,548,550,
        5,115,0,0,549,548,1,0,0,0,549,550,1,0,0,0,550,552,1,0,0,0,551,553,
        3,194,97,0,552,551,1,0,0,0,552,553,1,0,0,0,553,69,1,0,0,0,554,563,
        5,23,0,0,555,560,3,72,36,0,556,557,5,16,0,0,557,559,3,72,36,0,558,
        556,1,0,0,0,559,562,1,0,0,0,560,558,1,0,0,0,560,561,1,0,0,0,561,
        564,1,0,0,0,562,560,1,0,0,0,563,555,1,0,0,0,563,564,1,0,0,0,564,
        565,1,0,0,0,565,566,5,24,0,0,566,71,1,0,0,0,567,569,3,76,38,0,568,
        570,3,90,45,0,569,568,1,0,0,0,569,570,1,0,0,0,570,73,1,0,0,0,571,
        573,3,76,38,0,572,574,3,90,45,0,573,572,1,0,0,0,573,574,1,0,0,0,
        574,575,1,0,0,0,575,576,3,194,97,0,576,75,1,0,0,0,577,578,6,38,-1,
        0,578,585,3,138,69,0,579,585,3,78,39,0,580,585,3,82,41,0,581,585,
        3,88,44,0,582,583,5,44,0,0,583,585,5,117,0,0,584,577,1,0,0,0,584,
        579,1,0,0,0,584,580,1,0,0,0,584,581,1,0,0,0,584,582,1,0,0,0,585,
        594,1,0,0,0,586,587,10,3,0,0,587,589,5,42,0,0,588,590,3,140,70,0,
        589,588,1,0,0,0,589,590,1,0,0,0,590,591,1,0,0,0,591,593,5,43,0,0,
        592,586,1,0,0,0,593,596,1,0,0,0,594,592,1,0,0,0,594,595,1,0,0,0,
        595,77,1,0,0,0,596,594,1,0,0,0,597,602,3,194,97,0,598,599,5,45,0,
        0,599,601,3,194,97,0,600,598,1,0,0,0,601,604,1,0,0,0,602,600,1,0,
        0,0,602,603,1,0,0,0,603,79,1,0,0,0,604,602,1,0,0,0,605,608,3,138,
        69,0,606,608,3,78,39,0,607,605,1,0,0,0,607,606,1,0,0,0,608,81,1,
        0,0,0,609,610,5,46,0,0,610,611,5,23,0,0,611,613,3,80,40,0,612,614,
        3,84,42,0,613,612,1,0,0,0,613,614,1,0,0,0,614,615,1,0,0,0,615,616,
        5,47,0,0,616,618,3,76,38,0,617,619,3,86,43,0,618,617,1,0,0,0,618,
        619,1,0,0,0,619,620,1,0,0,0,620,621,5,24,0,0,621,83,1,0,0,0,622,
        623,3,194,97,0,623,85,1,0,0,0,624,625,3,194,97,0,625,87,1,0,0,0,
        626,627,5,38,0,0,627,633,3,70,35,0,628,632,5,116,0,0,629,632,5,114,
        0,0,630,632,3,92,46,0,631,628,1,0,0,0,631,629,1,0,0,0,631,630,1,
        0,0,0,632,635,1,0,0,0,633,631,1,0,0,0,633,634,1,0,0,0,634,638,1,
        0,0,0,635,633,1,0,0,0,636,637,5,39,0,0,637,639,3,70,35,0,638,636,
        1,0,0,0,638,639,1,0,0,0,639,89,1,0,0,0,640,641,7,3,0,0,641,91,1,
        0,0,0,642,643,7,4,0,0,643,93,1,0,0,0,644,648,5,15,0,0,645,647,3,
        96,48,0,646,645,1,0,0,0,647,650,1,0,0,0,648,646,1,0,0,0,648,649,
        1,0,0,0,649,651,1,0,0,0,650,648,1,0,0,0,651,652,5,17,0,0,652,95,
        1,0,0,0,653,669,3,100,50,0,654,669,3,102,51,0,655,669,3,106,53,0,
        656,669,3,112,56,0,657,669,3,94,47,0,658,669,3,114,57,0,659,669,
        3,118,59,0,660,669,3,120,60,0,661,669,3,122,61,0,662,669,3,124,62,
        0,663,669,3,126,63,0,664,669,3,128,64,0,665,669,3,108,54,0,666,669,
        3,110,55,0,667,669,3,130,65,0,668,653,1,0,0,0,668,654,1,0,0,0,668,
        655,1,0,0,0,668,656,1,0,0,0,668,657,1,0,0,0,668,658,1,0,0,0,668,
        659,1,0,0,0,668,660,1,0,0,0,668,661,1,0,0,0,668,662,1,0,0,0,668,
        663,1,0,0,0,668,664,1,0,0,0,668,665,1,0,0,0,668,666,1,0,0,0,668,
        667,1,0,0,0,669,97,1,0,0,0,670,671,3,140,70,0,671,672,5,2,0,0,672,
        99,1,0,0,0,673,674,5,51,0,0,674,675,5,23,0,0,675,676,3,140,70,0,
        676,677,5,24,0,0,677,680,3,96,48,0,678,679,5,52,0,0,679,681,3,96,
        48,0,680,678,1,0,0,0,680,681,1,0,0,0,681,101,1,0,0,0,682,683,5,53,
        0,0,683,685,3,140,70,0,684,686,3,52,26,0,685,684,1,0,0,0,685,686,
        1,0,0,0,686,687,1,0,0,0,687,689,3,94,47,0,688,690,3,104,52,0,689,
        688,1,0,0,0,690,691,1,0,0,0,691,689,1,0,0,0,691,692,1,0,0,0,692,
        103,1,0,0,0,693,698,5,54,0,0,694,696,3,194,97,0,695,694,1,0,0,0,
        695,696,1,0,0,0,696,697,1,0,0,0,697,699,3,62,31,0,698,695,1,0,0,
        0,698,699,1,0,0,0,699,700,1,0,0,0,700,701,3,94,47,0,701,105,1,0,
        0,0,702,703,5,55,0,0,703,704,5,23,0,0,704,705,3,140,70,0,705,706,
        5,24,0,0,706,707,3,96,48,0,707,107,1,0,0,0,708,711,3,132,66,0,709,
        711,3,98,49,0,710,708,1,0,0,0,710,709,1,0,0,0,711,109,1,0,0,0,712,
        713,5,56,0,0,713,714,3,94,47,0,714,111,1,0,0,0,715,716,5,27,0,0,
        716,719,5,23,0,0,717,720,3,108,54,0,718,720,5,2,0,0,719,717,1,0,
        0,0,719,718,1,0,0,0,720,723,1,0,0,0,721,724,3,98,49,0,722,724,5,
        2,0,0,723,721,1,0,0,0,723,722,1,0,0,0,724,726,1,0,0,0,725,727,3,
        140,70,0,726,725,1,0,0,0,726,727,1,0,0,0,727,728,1,0,0,0,728,729,
        5,24,0,0,729,730,3,96,48,0,730,113,1,0,0,0,731,733,5,57,0,0,732,
        734,5,129,0,0,733,732,1,0,0,0,733,734,1,0,0,0,734,739,1,0,0,0,735,
        736,5,23,0,0,736,737,3,116,58,0,737,738,5,24,0,0,738,740,1,0,0,0,
        739,735,1,0,0,0,739,740,1,0,0,0,740,741,1,0,0,0,741,742,3,154,77,
        0,742,115,1,0,0,0,743,744,3,200,100,0,744,117,1,0,0,0,745,746,5,
        58,0,0,746,747,3,96,48,0,747,748,5,55,0,0,748,749,5,23,0,0,749,750,
        3,140,70,0,750,751,5,24,0,0,751,752,5,2,0,0,752,119,1,0,0,0,753,
        754,5,112,0,0,754,755,5,2,0,0,755,121,1,0,0,0,756,757,5,109,0,0,
        757,758,5,2,0,0,758,123,1,0,0,0,759,761,5,59,0,0,760,762,3,140,70,
        0,761,760,1,0,0,0,761,762,1,0,0,0,762,763,1,0,0,0,763,764,5,2,0,
        0,764,125,1,0,0,0,765,766,5,60,0,0,766,767,5,2,0,0,767,127,1,0,0,
        0,768,769,5,61,0,0,769,770,3,152,76,0,770,771,5,2,0,0,771,129,1,
        0,0,0,772,773,5,62,0,0,773,774,3,152,76,0,774,775,5,2,0,0,775,131,
        1,0,0,0,776,777,5,63,0,0,777,784,3,136,68,0,778,784,3,74,37,0,779,
        780,5,23,0,0,780,781,3,134,67,0,781,782,5,24,0,0,782,784,1,0,0,0,
        783,776,1,0,0,0,783,778,1,0,0,0,783,779,1,0,0,0,784,787,1,0,0,0,
        785,786,5,11,0,0,786,788,3,140,70,0,787,785,1,0,0,0,787,788,1,0,
        0,0,788,789,1,0,0,0,789,790,5,2,0,0,790,133,1,0,0,0,791,793,3,74,
        37,0,792,791,1,0,0,0,792,793,1,0,0,0,793,800,1,0,0,0,794,796,5,16,
        0,0,795,797,3,74,37,0,796,795,1,0,0,0,796,797,1,0,0,0,797,799,1,
        0,0,0,798,794,1,0,0,0,799,802,1,0,0,0,800,798,1,0,0,0,800,801,1,
        0,0,0,801,135,1,0,0,0,802,800,1,0,0,0,803,810,5,23,0,0,804,806,3,
        194,97,0,805,804,1,0,0,0,805,806,1,0,0,0,806,807,1,0,0,0,807,809,
        5,16,0,0,808,805,1,0,0,0,809,812,1,0,0,0,810,808,1,0,0,0,810,811,
        1,0,0,0,811,814,1,0,0,0,812,810,1,0,0,0,813,815,3,194,97,0,814,813,
        1,0,0,0,814,815,1,0,0,0,815,816,1,0,0,0,816,817,5,24,0,0,817,137,
        1,0,0,0,818,819,7,5,0,0,819,139,1,0,0,0,820,821,6,70,-1,0,821,822,
        5,69,0,0,822,839,3,76,38,0,823,824,5,23,0,0,824,825,3,140,70,0,825,
        826,5,24,0,0,826,839,1,0,0,0,827,828,7,6,0,0,828,839,3,140,70,19,
        829,830,7,7,0,0,830,839,3,140,70,18,831,832,5,71,0,0,832,839,3,140,
        70,17,833,834,5,72,0,0,834,839,3,140,70,16,835,836,5,6,0,0,836,839,
        3,140,70,15,837,839,3,142,71,0,838,820,1,0,0,0,838,823,1,0,0,0,838,
        827,1,0,0,0,838,829,1,0,0,0,838,831,1,0,0,0,838,833,1,0,0,0,838,
        835,1,0,0,0,838,837,1,0,0,0,839,914,1,0,0,0,840,841,10,14,0,0,841,
        842,5,73,0,0,842,913,3,140,70,14,843,844,10,13,0,0,844,845,7,8,0,
        0,845,913,3,140,70,14,846,847,10,12,0,0,847,848,7,7,0,0,848,913,
        3,140,70,13,849,850,10,11,0,0,850,851,7,9,0,0,851,913,3,140,70,12,
        852,853,10,10,0,0,853,854,5,29,0,0,854,913,3,140,70,11,855,856,10,
        9,0,0,856,857,5,5,0,0,857,913,3,140,70,10,858,859,10,8,0,0,859,860,
        5,28,0,0,860,913,3,140,70,9,861,862,10,7,0,0,862,863,7,10,0,0,863,
        913,3,140,70,8,864,865,10,6,0,0,865,866,7,11,0,0,866,913,3,140,70,
        7,867,868,10,5,0,0,868,869,5,76,0,0,869,913,3,140,70,6,870,871,10,
        4,0,0,871,872,5,4,0,0,872,913,3,140,70,5,873,874,10,3,0,0,874,875,
        5,77,0,0,875,876,3,140,70,0,876,877,5,70,0,0,877,878,3,140,70,3,
        878,913,1,0,0,0,879,880,10,2,0,0,880,881,7,12,0,0,881,913,3,140,
        70,3,882,883,10,27,0,0,883,913,7,6,0,0,884,885,10,25,0,0,885,886,
        5,42,0,0,886,887,3,140,70,0,887,888,5,43,0,0,888,913,1,0,0,0,889,
        890,10,24,0,0,890,892,5,42,0,0,891,893,3,140,70,0,892,891,1,0,0,
        0,892,893,1,0,0,0,893,894,1,0,0,0,894,896,5,70,0,0,895,897,3,140,
        70,0,896,895,1,0,0,0,896,897,1,0,0,0,897,898,1,0,0,0,898,913,5,43,
        0,0,899,900,10,23,0,0,900,901,5,45,0,0,901,913,3,194,97,0,902,903,
        10,22,0,0,903,904,5,15,0,0,904,905,3,146,73,0,905,906,5,17,0,0,906,
        913,1,0,0,0,907,908,10,21,0,0,908,909,5,23,0,0,909,910,3,150,75,
        0,910,911,5,24,0,0,911,913,1,0,0,0,912,840,1,0,0,0,912,843,1,0,0,
        0,912,846,1,0,0,0,912,849,1,0,0,0,912,852,1,0,0,0,912,855,1,0,0,
        0,912,858,1,0,0,0,912,861,1,0,0,0,912,864,1,0,0,0,912,867,1,0,0,
        0,912,870,1,0,0,0,912,873,1,0,0,0,912,879,1,0,0,0,912,882,1,0,0,
        0,912,884,1,0,0,0,912,889,1,0,0,0,912,899,1,0,0,0,912,902,1,0,0,
        0,912,907,1,0,0,0,913,916,1,0,0,0,914,912,1,0,0,0,914,915,1,0,0,
        0,915,141,1,0,0,0,916,914,1,0,0,0,917,927,5,102,0,0,918,927,3,192,
        96,0,919,927,3,196,98,0,920,927,3,200,100,0,921,927,3,194,97,0,922,
        927,5,122,0,0,923,927,5,117,0,0,924,927,3,190,95,0,925,927,3,76,
        38,0,926,917,1,0,0,0,926,918,1,0,0,0,926,919,1,0,0,0,926,920,1,0,
        0,0,926,921,1,0,0,0,926,922,1,0,0,0,926,923,1,0,0,0,926,924,1,0,
        0,0,926,925,1,0,0,0,927,143,1,0,0,0,928,933,3,140,70,0,929,930,5,
        16,0,0,930,932,3,140,70,0,931,929,1,0,0,0,932,935,1,0,0,0,933,931,
        1,0,0,0,933,934,1,0,0,0,934,145,1,0,0,0,935,933,1,0,0,0,936,941,
        3,148,74,0,937,938,5,16,0,0,938,940,3,148,74,0,939,937,1,0,0,0,940,
        943,1,0,0,0,941,939,1,0,0,0,941,942,1,0,0,0,942,945,1,0,0,0,943,
        941,1,0,0,0,944,946,5,16,0,0,945,944,1,0,0,0,945,946,1,0,0,0,946,
        147,1,0,0,0,947,948,3,194,97,0,948,949,5,70,0,0,949,950,3,140,70,
        0,950,149,1,0,0,0,951,953,5,15,0,0,952,954,3,146,73,0,953,952,1,
        0,0,0,953,954,1,0,0,0,954,955,1,0,0,0,955,960,5,17,0,0,956,958,3,
        144,72,0,957,956,1,0,0,0,957,958,1,0,0,0,958,960,1,0,0,0,959,951,
        1,0,0,0,959,957,1,0,0,0,960,151,1,0,0,0,961,962,3,140,70,0,962,963,
        5,23,0,0,963,964,3,150,75,0,964,965,5,24,0,0,965,153,1,0,0,0,966,
        970,5,15,0,0,967,969,3,156,78,0,968,967,1,0,0,0,969,972,1,0,0,0,
        970,968,1,0,0,0,970,971,1,0,0,0,971,973,1,0,0,0,972,970,1,0,0,0,
        973,974,5,17,0,0,974,155,1,0,0,0,975,993,3,194,97,0,976,993,3,154,
        77,0,977,993,3,158,79,0,978,993,3,164,82,0,979,993,3,166,83,0,980,
        993,3,172,86,0,981,993,3,174,87,0,982,993,3,176,88,0,983,993,3,180,
        90,0,984,993,3,184,92,0,985,993,3,186,93,0,986,993,5,109,0,0,987,
        993,5,112,0,0,988,993,5,113,0,0,989,993,3,192,96,0,990,993,3,200,
        100,0,991,993,3,196,98,0,992,975,1,0,0,0,992,976,1,0,0,0,992,977,
        1,0,0,0,992,978,1,0,0,0,992,979,1,0,0,0,992,980,1,0,0,0,992,981,
        1,0,0,0,992,982,1,0,0,0,992,983,1,0,0,0,992,984,1,0,0,0,992,985,
        1,0,0,0,992,986,1,0,0,0,992,987,1,0,0,0,992,988,1,0,0,0,992,989,
        1,0,0,0,992,990,1,0,0,0,992,991,1,0,0,0,993,157,1,0,0,0,994,998,
        3,162,81,0,995,998,3,188,94,0,996,998,3,160,80,0,997,994,1,0,0,0,
        997,995,1,0,0,0,997,996,1,0,0,0,998,159,1,0,0,0,999,1000,3,194,97,
        0,1000,1001,5,45,0,0,1001,1002,3,194,97,0,1002,161,1,0,0,0,1003,
        1008,5,59,0,0,1004,1008,5,44,0,0,1005,1008,5,66,0,0,1006,1008,3,
        194,97,0,1007,1003,1,0,0,0,1007,1004,1,0,0,0,1007,1005,1,0,0,0,1007,
        1006,1,0,0,0,1008,1021,1,0,0,0,1009,1011,5,23,0,0,1010,1012,3,158,
        79,0,1011,1010,1,0,0,0,1011,1012,1,0,0,0,1012,1017,1,0,0,0,1013,
        1014,5,16,0,0,1014,1016,3,158,79,0,1015,1013,1,0,0,0,1016,1019,1,
        0,0,0,1017,1015,1,0,0,0,1017,1018,1,0,0,0,1018,1020,1,0,0,0,1019,
        1017,1,0,0,0,1020,1022,5,24,0,0,1021,1009,1,0,0,0,1021,1022,1,0,
        0,0,1022,163,1,0,0,0,1023,1024,5,88,0,0,1024,1027,3,168,84,0,1025,
        1026,5,89,0,0,1026,1028,3,158,79,0,1027,1025,1,0,0,0,1027,1028,1,
        0,0,0,1028,165,1,0,0,0,1029,1030,3,168,84,0,1030,1031,5,89,0,0,1031,
        1032,3,158,79,0,1032,167,1,0,0,0,1033,1041,3,194,97,0,1034,1041,
        3,160,80,0,1035,1041,3,170,85,0,1036,1037,5,23,0,0,1037,1038,3,170,
        85,0,1038,1039,5,24,0,0,1039,1041,1,0,0,0,1040,1033,1,0,0,0,1040,
        1034,1,0,0,0,1040,1035,1,0,0,0,1040,1036,1,0,0,0,1041,169,1,0,0,
        0,1042,1047,3,194,97,0,1043,1044,5,16,0,0,1044,1046,3,194,97,0,1045,
        1043,1,0,0,0,1046,1049,1,0,0,0,1047,1045,1,0,0,0,1047,1048,1,0,0,
        0,1048,171,1,0,0,0,1049,1047,1,0,0,0,1050,1051,3,158,79,0,1051,1052,
        5,90,0,0,1052,1053,3,194,97,0,1053,173,1,0,0,0,1054,1055,3,194,97,
        0,1055,1056,5,70,0,0,1056,175,1,0,0,0,1057,1058,5,91,0,0,1058,1062,
        3,158,79,0,1059,1061,3,178,89,0,1060,1059,1,0,0,0,1061,1064,1,0,
        0,0,1062,1060,1,0,0,0,1062,1063,1,0,0,0,1063,177,1,0,0,0,1064,1062,
        1,0,0,0,1065,1066,5,92,0,0,1066,1067,3,188,94,0,1067,1068,3,154,
        77,0,1068,1072,1,0,0,0,1069,1070,5,93,0,0,1070,1072,3,154,77,0,1071,
        1065,1,0,0,0,1071,1069,1,0,0,0,1072,179,1,0,0,0,1073,1074,5,38,0,
        0,1074,1075,3,194,97,0,1075,1077,5,23,0,0,1076,1078,3,170,85,0,1077,
        1076,1,0,0,0,1077,1078,1,0,0,0,1078,1079,1,0,0,0,1079,1081,5,24,
        0,0,1080,1082,3,182,91,0,1081,1080,1,0,0,0,1081,1082,1,0,0,0,1082,
        1083,1,0,0,0,1083,1084,3,154,77,0,1084,181,1,0,0,0,1085,1086,5,94,
        0,0,1086,1087,3,170,85,0,1087,183,1,0,0,0,1088,1091,5,27,0,0,1089,
        1092,3,154,77,0,1090,1092,3,158,79,0,1091,1089,1,0,0,0,1091,1090,
        1,0,0,0,1092,1093,1,0,0,0,1093,1096,3,158,79,0,1094,1097,3,154,77,
        0,1095,1097,3,158,79,0,1096,1094,1,0,0,0,1096,1095,1,0,0,0,1097,
        1098,1,0,0,0,1098,1099,3,154,77,0,1099,185,1,0,0,0,1100,1101,5,51,
        0,0,1101,1102,3,158,79,0,1102,1103,3,154,77,0,1103,187,1,0,0,0,1104,
        1110,3,200,100,0,1105,1110,5,103,0,0,1106,1110,5,104,0,0,1107,1110,
        3,196,98,0,1108,1110,5,102,0,0,1109,1104,1,0,0,0,1109,1105,1,0,0,
        0,1109,1106,1,0,0,0,1109,1107,1,0,0,0,1109,1108,1,0,0,0,1110,189,
        1,0,0,0,1111,1113,5,23,0,0,1112,1114,3,140,70,0,1113,1112,1,0,0,
        0,1113,1114,1,0,0,0,1114,1121,1,0,0,0,1115,1117,5,16,0,0,1116,1118,
        3,140,70,0,1117,1116,1,0,0,0,1117,1118,1,0,0,0,1118,1120,1,0,0,0,
        1119,1115,1,0,0,0,1120,1123,1,0,0,0,1121,1119,1,0,0,0,1121,1122,
        1,0,0,0,1122,1124,1,0,0,0,1123,1121,1,0,0,0,1124,1138,5,24,0,0,1125,
        1134,5,42,0,0,1126,1131,3,140,70,0,1127,1128,5,16,0,0,1128,1130,
        3,140,70,0,1129,1127,1,0,0,0,1130,1133,1,0,0,0,1131,1129,1,0,0,0,
        1131,1132,1,0,0,0,1132,1135,1,0,0,0,1133,1131,1,0,0,0,1134,1126,
        1,0,0,0,1134,1135,1,0,0,0,1135,1136,1,0,0,0,1136,1138,5,43,0,0,1137,
        1111,1,0,0,0,1137,1125,1,0,0,0,1138,191,1,0,0,0,1139,1141,7,13,0,
        0,1140,1142,5,105,0,0,1141,1140,1,0,0,0,1141,1142,1,0,0,0,1142,193,
        1,0,0,0,1143,1144,7,14,0,0,1144,195,1,0,0,0,1145,1147,5,106,0,0,
        1146,1145,1,0,0,0,1147,1148,1,0,0,0,1148,1146,1,0,0,0,1148,1149,
        1,0,0,0,1149,197,1,0,0,0,1150,1162,5,96,0,0,1151,1152,5,23,0,0,1152,
        1157,3,78,39,0,1153,1154,5,16,0,0,1154,1156,3,78,39,0,1155,1153,
        1,0,0,0,1156,1159,1,0,0,0,1157,1155,1,0,0,0,1157,1158,1,0,0,0,1158,
        1160,1,0,0,0,1159,1157,1,0,0,0,1160,1161,5,24,0,0,1161,1163,1,0,
        0,0,1162,1151,1,0,0,0,1162,1163,1,0,0,0,1163,199,1,0,0,0,1164,1166,
        5,129,0,0,1165,1164,1,0,0,0,1166,1167,1,0,0,0,1167,1165,1,0,0,0,
        1167,1168,1,0,0,0,1168,201,1,0,0,0,130,213,215,230,234,239,245,249,
        252,257,263,270,274,287,295,300,310,313,319,327,330,341,350,352,
        358,385,388,399,404,409,423,426,433,437,439,444,449,452,458,462,
        466,471,484,486,493,503,509,520,523,529,532,540,543,549,552,560,
        563,569,573,584,589,594,602,607,613,618,631,633,638,648,668,680,
        685,691,695,698,710,719,723,726,733,739,761,783,787,792,796,800,
        805,810,814,838,892,896,912,914,926,933,941,945,953,957,959,970,
        992,997,1007,1011,1017,1021,1027,1040,1047,1062,1071,1077,1081,1091,
        1096,1109,1113,1117,1121,1131,1134,1137,1141,1148,1157,1162,1167
    ];

    private static __ATN: antlr.ATN;
    public static get _ATN(): antlr.ATN {
        if (!SolidityParser.__ATN) {
            SolidityParser.__ATN = new antlr.ATNDeserializer().deserialize(SolidityParser._serializedATN);
        }

        return SolidityParser.__ATN;
    }


    private static readonly vocabulary = new antlr.Vocabulary(SolidityParser.literalNames, SolidityParser.symbolicNames, []);

    public override get vocabulary(): antlr.Vocabulary {
        return SolidityParser.vocabulary;
    }

    private static readonly decisionsToDFA = SolidityParser._ATN.decisionToState.map( (ds: antlr.DecisionState, index: number) => new antlr.DFA(ds, index) );
}

export class SourceUnitContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public EOF(): antlr.TerminalNode {
        return this.getToken(SolidityParser.EOF, 0)!;
    }
    public pragmaDirective(): PragmaDirectiveContext[];
    public pragmaDirective(i: number): PragmaDirectiveContext | null;
    public pragmaDirective(i?: number): PragmaDirectiveContext[] | PragmaDirectiveContext | null {
        if (i === undefined) {
            return this.getRuleContexts(PragmaDirectiveContext);
        }

        return this.getRuleContext(i, PragmaDirectiveContext);
    }
    public importDirective(): ImportDirectiveContext[];
    public importDirective(i: number): ImportDirectiveContext | null;
    public importDirective(i?: number): ImportDirectiveContext[] | ImportDirectiveContext | null {
        if (i === undefined) {
            return this.getRuleContexts(ImportDirectiveContext);
        }

        return this.getRuleContext(i, ImportDirectiveContext);
    }
    public contractDefinition(): ContractDefinitionContext[];
    public contractDefinition(i: number): ContractDefinitionContext | null;
    public contractDefinition(i?: number): ContractDefinitionContext[] | ContractDefinitionContext | null {
        if (i === undefined) {
            return this.getRuleContexts(ContractDefinitionContext);
        }

        return this.getRuleContext(i, ContractDefinitionContext);
    }
    public enumDefinition(): EnumDefinitionContext[];
    public enumDefinition(i: number): EnumDefinitionContext | null;
    public enumDefinition(i?: number): EnumDefinitionContext[] | EnumDefinitionContext | null {
        if (i === undefined) {
            return this.getRuleContexts(EnumDefinitionContext);
        }

        return this.getRuleContext(i, EnumDefinitionContext);
    }
    public eventDefinition(): EventDefinitionContext[];
    public eventDefinition(i: number): EventDefinitionContext | null;
    public eventDefinition(i?: number): EventDefinitionContext[] | EventDefinitionContext | null {
        if (i === undefined) {
            return this.getRuleContexts(EventDefinitionContext);
        }

        return this.getRuleContext(i, EventDefinitionContext);
    }
    public structDefinition(): StructDefinitionContext[];
    public structDefinition(i: number): StructDefinitionContext | null;
    public structDefinition(i?: number): StructDefinitionContext[] | StructDefinitionContext | null {
        if (i === undefined) {
            return this.getRuleContexts(StructDefinitionContext);
        }

        return this.getRuleContext(i, StructDefinitionContext);
    }
    public functionDefinition(): FunctionDefinitionContext[];
    public functionDefinition(i: number): FunctionDefinitionContext | null;
    public functionDefinition(i?: number): FunctionDefinitionContext[] | FunctionDefinitionContext | null {
        if (i === undefined) {
            return this.getRuleContexts(FunctionDefinitionContext);
        }

        return this.getRuleContext(i, FunctionDefinitionContext);
    }
    public fileLevelConstant(): FileLevelConstantContext[];
    public fileLevelConstant(i: number): FileLevelConstantContext | null;
    public fileLevelConstant(i?: number): FileLevelConstantContext[] | FileLevelConstantContext | null {
        if (i === undefined) {
            return this.getRuleContexts(FileLevelConstantContext);
        }

        return this.getRuleContext(i, FileLevelConstantContext);
    }
    public customErrorDefinition(): CustomErrorDefinitionContext[];
    public customErrorDefinition(i: number): CustomErrorDefinitionContext | null;
    public customErrorDefinition(i?: number): CustomErrorDefinitionContext[] | CustomErrorDefinitionContext | null {
        if (i === undefined) {
            return this.getRuleContexts(CustomErrorDefinitionContext);
        }

        return this.getRuleContext(i, CustomErrorDefinitionContext);
    }
    public typeDefinition(): TypeDefinitionContext[];
    public typeDefinition(i: number): TypeDefinitionContext | null;
    public typeDefinition(i?: number): TypeDefinitionContext[] | TypeDefinitionContext | null {
        if (i === undefined) {
            return this.getRuleContexts(TypeDefinitionContext);
        }

        return this.getRuleContext(i, TypeDefinitionContext);
    }
    public usingForDeclaration(): UsingForDeclarationContext[];
    public usingForDeclaration(i: number): UsingForDeclarationContext | null;
    public usingForDeclaration(i?: number): UsingForDeclarationContext[] | UsingForDeclarationContext | null {
        if (i === undefined) {
            return this.getRuleContexts(UsingForDeclarationContext);
        }

        return this.getRuleContext(i, UsingForDeclarationContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_sourceUnit;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterSourceUnit) {
             listener.enterSourceUnit(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitSourceUnit) {
             listener.exitSourceUnit(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitSourceUnit) {
            return visitor.visitSourceUnit(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class PragmaDirectiveContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public pragmaName(): PragmaNameContext {
        return this.getRuleContext(0, PragmaNameContext)!;
    }
    public pragmaValue(): PragmaValueContext {
        return this.getRuleContext(0, PragmaValueContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_pragmaDirective;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterPragmaDirective) {
             listener.enterPragmaDirective(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitPragmaDirective) {
             listener.exitPragmaDirective(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitPragmaDirective) {
            return visitor.visitPragmaDirective(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class PragmaNameContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext {
        return this.getRuleContext(0, IdentifierContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_pragmaName;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterPragmaName) {
             listener.enterPragmaName(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitPragmaName) {
             listener.exitPragmaName(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitPragmaName) {
            return visitor.visitPragmaName(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class PragmaValueContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public version(): VersionContext | null {
        return this.getRuleContext(0, VersionContext);
    }
    public expression(): ExpressionContext | null {
        return this.getRuleContext(0, ExpressionContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_pragmaValue;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterPragmaValue) {
             listener.enterPragmaValue(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitPragmaValue) {
             listener.exitPragmaValue(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitPragmaValue) {
            return visitor.visitPragmaValue(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class VersionContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public versionConstraint(): VersionConstraintContext[];
    public versionConstraint(i: number): VersionConstraintContext | null;
    public versionConstraint(i?: number): VersionConstraintContext[] | VersionConstraintContext | null {
        if (i === undefined) {
            return this.getRuleContexts(VersionConstraintContext);
        }

        return this.getRuleContext(i, VersionConstraintContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_version;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterVersion) {
             listener.enterVersion(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitVersion) {
             listener.exitVersion(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitVersion) {
            return visitor.visitVersion(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class VersionOperatorContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_versionOperator;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterVersionOperator) {
             listener.enterVersionOperator(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitVersionOperator) {
             listener.exitVersionOperator(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitVersionOperator) {
            return visitor.visitVersionOperator(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class VersionConstraintContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public VersionLiteral(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.VersionLiteral, 0);
    }
    public versionOperator(): VersionOperatorContext | null {
        return this.getRuleContext(0, VersionOperatorContext);
    }
    public DecimalNumber(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.DecimalNumber, 0);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_versionConstraint;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterVersionConstraint) {
             listener.enterVersionConstraint(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitVersionConstraint) {
             listener.exitVersionConstraint(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitVersionConstraint) {
            return visitor.visitVersionConstraint(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class ImportDeclarationContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext[];
    public identifier(i: number): IdentifierContext | null;
    public identifier(i?: number): IdentifierContext[] | IdentifierContext | null {
        if (i === undefined) {
            return this.getRuleContexts(IdentifierContext);
        }

        return this.getRuleContext(i, IdentifierContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_importDeclaration;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterImportDeclaration) {
             listener.enterImportDeclaration(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitImportDeclaration) {
             listener.exitImportDeclaration(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitImportDeclaration) {
            return visitor.visitImportDeclaration(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class ImportDirectiveContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public importPath(): ImportPathContext {
        return this.getRuleContext(0, ImportPathContext)!;
    }
    public identifier(): IdentifierContext[];
    public identifier(i: number): IdentifierContext | null;
    public identifier(i?: number): IdentifierContext[] | IdentifierContext | null {
        if (i === undefined) {
            return this.getRuleContexts(IdentifierContext);
        }

        return this.getRuleContext(i, IdentifierContext);
    }
    public importDeclaration(): ImportDeclarationContext[];
    public importDeclaration(i: number): ImportDeclarationContext | null;
    public importDeclaration(i?: number): ImportDeclarationContext[] | ImportDeclarationContext | null {
        if (i === undefined) {
            return this.getRuleContexts(ImportDeclarationContext);
        }

        return this.getRuleContext(i, ImportDeclarationContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_importDirective;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterImportDirective) {
             listener.enterImportDirective(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitImportDirective) {
             listener.exitImportDirective(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitImportDirective) {
            return visitor.visitImportDirective(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class ImportPathContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public StringLiteralFragment(): antlr.TerminalNode {
        return this.getToken(SolidityParser.StringLiteralFragment, 0)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_importPath;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterImportPath) {
             listener.enterImportPath(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitImportPath) {
             listener.exitImportPath(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitImportPath) {
            return visitor.visitImportPath(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class ContractDefinitionContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext {
        return this.getRuleContext(0, IdentifierContext)!;
    }
    public inheritanceSpecifier(): InheritanceSpecifierContext[];
    public inheritanceSpecifier(i: number): InheritanceSpecifierContext | null;
    public inheritanceSpecifier(i?: number): InheritanceSpecifierContext[] | InheritanceSpecifierContext | null {
        if (i === undefined) {
            return this.getRuleContexts(InheritanceSpecifierContext);
        }

        return this.getRuleContext(i, InheritanceSpecifierContext);
    }
    public contractPart(): ContractPartContext[];
    public contractPart(i: number): ContractPartContext | null;
    public contractPart(i?: number): ContractPartContext[] | ContractPartContext | null {
        if (i === undefined) {
            return this.getRuleContexts(ContractPartContext);
        }

        return this.getRuleContext(i, ContractPartContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_contractDefinition;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterContractDefinition) {
             listener.enterContractDefinition(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitContractDefinition) {
             listener.exitContractDefinition(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitContractDefinition) {
            return visitor.visitContractDefinition(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class InheritanceSpecifierContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public userDefinedTypeName(): UserDefinedTypeNameContext {
        return this.getRuleContext(0, UserDefinedTypeNameContext)!;
    }
    public expressionList(): ExpressionListContext | null {
        return this.getRuleContext(0, ExpressionListContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_inheritanceSpecifier;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterInheritanceSpecifier) {
             listener.enterInheritanceSpecifier(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitInheritanceSpecifier) {
             listener.exitInheritanceSpecifier(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitInheritanceSpecifier) {
            return visitor.visitInheritanceSpecifier(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class ContractPartContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public stateVariableDeclaration(): StateVariableDeclarationContext | null {
        return this.getRuleContext(0, StateVariableDeclarationContext);
    }
    public usingForDeclaration(): UsingForDeclarationContext | null {
        return this.getRuleContext(0, UsingForDeclarationContext);
    }
    public structDefinition(): StructDefinitionContext | null {
        return this.getRuleContext(0, StructDefinitionContext);
    }
    public modifierDefinition(): ModifierDefinitionContext | null {
        return this.getRuleContext(0, ModifierDefinitionContext);
    }
    public functionDefinition(): FunctionDefinitionContext | null {
        return this.getRuleContext(0, FunctionDefinitionContext);
    }
    public eventDefinition(): EventDefinitionContext | null {
        return this.getRuleContext(0, EventDefinitionContext);
    }
    public enumDefinition(): EnumDefinitionContext | null {
        return this.getRuleContext(0, EnumDefinitionContext);
    }
    public customErrorDefinition(): CustomErrorDefinitionContext | null {
        return this.getRuleContext(0, CustomErrorDefinitionContext);
    }
    public typeDefinition(): TypeDefinitionContext | null {
        return this.getRuleContext(0, TypeDefinitionContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_contractPart;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterContractPart) {
             listener.enterContractPart(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitContractPart) {
             listener.exitContractPart(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitContractPart) {
            return visitor.visitContractPart(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class StateVariableDeclarationContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public typeName(): TypeNameContext {
        return this.getRuleContext(0, TypeNameContext)!;
    }
    public identifier(): IdentifierContext {
        return this.getRuleContext(0, IdentifierContext)!;
    }
    public PublicKeyword(): antlr.TerminalNode[];
    public PublicKeyword(i: number): antlr.TerminalNode | null;
    public PublicKeyword(i?: number): antlr.TerminalNode | null | antlr.TerminalNode[] {
    	if (i === undefined) {
    		return this.getTokens(SolidityParser.PublicKeyword);
    	} else {
    		return this.getToken(SolidityParser.PublicKeyword, i);
    	}
    }
    public InternalKeyword(): antlr.TerminalNode[];
    public InternalKeyword(i: number): antlr.TerminalNode | null;
    public InternalKeyword(i?: number): antlr.TerminalNode | null | antlr.TerminalNode[] {
    	if (i === undefined) {
    		return this.getTokens(SolidityParser.InternalKeyword);
    	} else {
    		return this.getToken(SolidityParser.InternalKeyword, i);
    	}
    }
    public PrivateKeyword(): antlr.TerminalNode[];
    public PrivateKeyword(i: number): antlr.TerminalNode | null;
    public PrivateKeyword(i?: number): antlr.TerminalNode | null | antlr.TerminalNode[] {
    	if (i === undefined) {
    		return this.getTokens(SolidityParser.PrivateKeyword);
    	} else {
    		return this.getToken(SolidityParser.PrivateKeyword, i);
    	}
    }
    public ConstantKeyword(): antlr.TerminalNode[];
    public ConstantKeyword(i: number): antlr.TerminalNode | null;
    public ConstantKeyword(i?: number): antlr.TerminalNode | null | antlr.TerminalNode[] {
    	if (i === undefined) {
    		return this.getTokens(SolidityParser.ConstantKeyword);
    	} else {
    		return this.getToken(SolidityParser.ConstantKeyword, i);
    	}
    }
    public ImmutableKeyword(): antlr.TerminalNode[];
    public ImmutableKeyword(i: number): antlr.TerminalNode | null;
    public ImmutableKeyword(i?: number): antlr.TerminalNode | null | antlr.TerminalNode[] {
    	if (i === undefined) {
    		return this.getTokens(SolidityParser.ImmutableKeyword);
    	} else {
    		return this.getToken(SolidityParser.ImmutableKeyword, i);
    	}
    }
    public overrideSpecifier(): OverrideSpecifierContext[];
    public overrideSpecifier(i: number): OverrideSpecifierContext | null;
    public overrideSpecifier(i?: number): OverrideSpecifierContext[] | OverrideSpecifierContext | null {
        if (i === undefined) {
            return this.getRuleContexts(OverrideSpecifierContext);
        }

        return this.getRuleContext(i, OverrideSpecifierContext);
    }
    public expression(): ExpressionContext | null {
        return this.getRuleContext(0, ExpressionContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_stateVariableDeclaration;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterStateVariableDeclaration) {
             listener.enterStateVariableDeclaration(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitStateVariableDeclaration) {
             listener.exitStateVariableDeclaration(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitStateVariableDeclaration) {
            return visitor.visitStateVariableDeclaration(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class FileLevelConstantContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public typeName(): TypeNameContext {
        return this.getRuleContext(0, TypeNameContext)!;
    }
    public ConstantKeyword(): antlr.TerminalNode {
        return this.getToken(SolidityParser.ConstantKeyword, 0)!;
    }
    public identifier(): IdentifierContext {
        return this.getRuleContext(0, IdentifierContext)!;
    }
    public expression(): ExpressionContext {
        return this.getRuleContext(0, ExpressionContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_fileLevelConstant;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterFileLevelConstant) {
             listener.enterFileLevelConstant(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitFileLevelConstant) {
             listener.exitFileLevelConstant(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitFileLevelConstant) {
            return visitor.visitFileLevelConstant(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class CustomErrorDefinitionContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext {
        return this.getRuleContext(0, IdentifierContext)!;
    }
    public parameterList(): ParameterListContext {
        return this.getRuleContext(0, ParameterListContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_customErrorDefinition;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterCustomErrorDefinition) {
             listener.enterCustomErrorDefinition(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitCustomErrorDefinition) {
             listener.exitCustomErrorDefinition(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitCustomErrorDefinition) {
            return visitor.visitCustomErrorDefinition(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class TypeDefinitionContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public TypeKeyword(): antlr.TerminalNode {
        return this.getToken(SolidityParser.TypeKeyword, 0)!;
    }
    public identifier(): IdentifierContext {
        return this.getRuleContext(0, IdentifierContext)!;
    }
    public elementaryTypeName(): ElementaryTypeNameContext {
        return this.getRuleContext(0, ElementaryTypeNameContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_typeDefinition;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterTypeDefinition) {
             listener.enterTypeDefinition(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitTypeDefinition) {
             listener.exitTypeDefinition(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitTypeDefinition) {
            return visitor.visitTypeDefinition(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class UsingForDeclarationContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public usingForObject(): UsingForObjectContext {
        return this.getRuleContext(0, UsingForObjectContext)!;
    }
    public typeName(): TypeNameContext | null {
        return this.getRuleContext(0, TypeNameContext);
    }
    public GlobalKeyword(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.GlobalKeyword, 0);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_usingForDeclaration;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterUsingForDeclaration) {
             listener.enterUsingForDeclaration(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitUsingForDeclaration) {
             listener.exitUsingForDeclaration(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitUsingForDeclaration) {
            return visitor.visitUsingForDeclaration(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class UsingForObjectContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public userDefinedTypeName(): UserDefinedTypeNameContext | null {
        return this.getRuleContext(0, UserDefinedTypeNameContext);
    }
    public usingForObjectDirective(): UsingForObjectDirectiveContext[];
    public usingForObjectDirective(i: number): UsingForObjectDirectiveContext | null;
    public usingForObjectDirective(i?: number): UsingForObjectDirectiveContext[] | UsingForObjectDirectiveContext | null {
        if (i === undefined) {
            return this.getRuleContexts(UsingForObjectDirectiveContext);
        }

        return this.getRuleContext(i, UsingForObjectDirectiveContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_usingForObject;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterUsingForObject) {
             listener.enterUsingForObject(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitUsingForObject) {
             listener.exitUsingForObject(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitUsingForObject) {
            return visitor.visitUsingForObject(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class UsingForObjectDirectiveContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public userDefinedTypeName(): UserDefinedTypeNameContext {
        return this.getRuleContext(0, UserDefinedTypeNameContext)!;
    }
    public userDefinableOperators(): UserDefinableOperatorsContext | null {
        return this.getRuleContext(0, UserDefinableOperatorsContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_usingForObjectDirective;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterUsingForObjectDirective) {
             listener.enterUsingForObjectDirective(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitUsingForObjectDirective) {
             listener.exitUsingForObjectDirective(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitUsingForObjectDirective) {
            return visitor.visitUsingForObjectDirective(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class UserDefinableOperatorsContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_userDefinableOperators;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterUserDefinableOperators) {
             listener.enterUserDefinableOperators(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitUserDefinableOperators) {
             listener.exitUserDefinableOperators(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitUserDefinableOperators) {
            return visitor.visitUserDefinableOperators(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class StructDefinitionContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext {
        return this.getRuleContext(0, IdentifierContext)!;
    }
    public variableDeclaration(): VariableDeclarationContext[];
    public variableDeclaration(i: number): VariableDeclarationContext | null;
    public variableDeclaration(i?: number): VariableDeclarationContext[] | VariableDeclarationContext | null {
        if (i === undefined) {
            return this.getRuleContexts(VariableDeclarationContext);
        }

        return this.getRuleContext(i, VariableDeclarationContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_structDefinition;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterStructDefinition) {
             listener.enterStructDefinition(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitStructDefinition) {
             listener.exitStructDefinition(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitStructDefinition) {
            return visitor.visitStructDefinition(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class ModifierDefinitionContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext {
        return this.getRuleContext(0, IdentifierContext)!;
    }
    public block(): BlockContext | null {
        return this.getRuleContext(0, BlockContext);
    }
    public parameterList(): ParameterListContext | null {
        return this.getRuleContext(0, ParameterListContext);
    }
    public VirtualKeyword(): antlr.TerminalNode[];
    public VirtualKeyword(i: number): antlr.TerminalNode | null;
    public VirtualKeyword(i?: number): antlr.TerminalNode | null | antlr.TerminalNode[] {
    	if (i === undefined) {
    		return this.getTokens(SolidityParser.VirtualKeyword);
    	} else {
    		return this.getToken(SolidityParser.VirtualKeyword, i);
    	}
    }
    public overrideSpecifier(): OverrideSpecifierContext[];
    public overrideSpecifier(i: number): OverrideSpecifierContext | null;
    public overrideSpecifier(i?: number): OverrideSpecifierContext[] | OverrideSpecifierContext | null {
        if (i === undefined) {
            return this.getRuleContexts(OverrideSpecifierContext);
        }

        return this.getRuleContext(i, OverrideSpecifierContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_modifierDefinition;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterModifierDefinition) {
             listener.enterModifierDefinition(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitModifierDefinition) {
             listener.exitModifierDefinition(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitModifierDefinition) {
            return visitor.visitModifierDefinition(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class ModifierInvocationContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext {
        return this.getRuleContext(0, IdentifierContext)!;
    }
    public expressionList(): ExpressionListContext | null {
        return this.getRuleContext(0, ExpressionListContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_modifierInvocation;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterModifierInvocation) {
             listener.enterModifierInvocation(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitModifierInvocation) {
             listener.exitModifierInvocation(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitModifierInvocation) {
            return visitor.visitModifierInvocation(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class FunctionDefinitionContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public functionDescriptor(): FunctionDescriptorContext {
        return this.getRuleContext(0, FunctionDescriptorContext)!;
    }
    public parameterList(): ParameterListContext {
        return this.getRuleContext(0, ParameterListContext)!;
    }
    public modifierList(): ModifierListContext {
        return this.getRuleContext(0, ModifierListContext)!;
    }
    public block(): BlockContext | null {
        return this.getRuleContext(0, BlockContext);
    }
    public returnParameters(): ReturnParametersContext | null {
        return this.getRuleContext(0, ReturnParametersContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_functionDefinition;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterFunctionDefinition) {
             listener.enterFunctionDefinition(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitFunctionDefinition) {
             listener.exitFunctionDefinition(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitFunctionDefinition) {
            return visitor.visitFunctionDefinition(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class FunctionDescriptorContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext | null {
        return this.getRuleContext(0, IdentifierContext);
    }
    public ConstructorKeyword(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.ConstructorKeyword, 0);
    }
    public FallbackKeyword(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.FallbackKeyword, 0);
    }
    public ReceiveKeyword(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.ReceiveKeyword, 0);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_functionDescriptor;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterFunctionDescriptor) {
             listener.enterFunctionDescriptor(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitFunctionDescriptor) {
             listener.exitFunctionDescriptor(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitFunctionDescriptor) {
            return visitor.visitFunctionDescriptor(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class ReturnParametersContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public parameterList(): ParameterListContext {
        return this.getRuleContext(0, ParameterListContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_returnParameters;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterReturnParameters) {
             listener.enterReturnParameters(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitReturnParameters) {
             listener.exitReturnParameters(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitReturnParameters) {
            return visitor.visitReturnParameters(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class ModifierListContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public ExternalKeyword(): antlr.TerminalNode[];
    public ExternalKeyword(i: number): antlr.TerminalNode | null;
    public ExternalKeyword(i?: number): antlr.TerminalNode | null | antlr.TerminalNode[] {
    	if (i === undefined) {
    		return this.getTokens(SolidityParser.ExternalKeyword);
    	} else {
    		return this.getToken(SolidityParser.ExternalKeyword, i);
    	}
    }
    public PublicKeyword(): antlr.TerminalNode[];
    public PublicKeyword(i: number): antlr.TerminalNode | null;
    public PublicKeyword(i?: number): antlr.TerminalNode | null | antlr.TerminalNode[] {
    	if (i === undefined) {
    		return this.getTokens(SolidityParser.PublicKeyword);
    	} else {
    		return this.getToken(SolidityParser.PublicKeyword, i);
    	}
    }
    public InternalKeyword(): antlr.TerminalNode[];
    public InternalKeyword(i: number): antlr.TerminalNode | null;
    public InternalKeyword(i?: number): antlr.TerminalNode | null | antlr.TerminalNode[] {
    	if (i === undefined) {
    		return this.getTokens(SolidityParser.InternalKeyword);
    	} else {
    		return this.getToken(SolidityParser.InternalKeyword, i);
    	}
    }
    public PrivateKeyword(): antlr.TerminalNode[];
    public PrivateKeyword(i: number): antlr.TerminalNode | null;
    public PrivateKeyword(i?: number): antlr.TerminalNode | null | antlr.TerminalNode[] {
    	if (i === undefined) {
    		return this.getTokens(SolidityParser.PrivateKeyword);
    	} else {
    		return this.getToken(SolidityParser.PrivateKeyword, i);
    	}
    }
    public VirtualKeyword(): antlr.TerminalNode[];
    public VirtualKeyword(i: number): antlr.TerminalNode | null;
    public VirtualKeyword(i?: number): antlr.TerminalNode | null | antlr.TerminalNode[] {
    	if (i === undefined) {
    		return this.getTokens(SolidityParser.VirtualKeyword);
    	} else {
    		return this.getToken(SolidityParser.VirtualKeyword, i);
    	}
    }
    public stateMutability(): StateMutabilityContext[];
    public stateMutability(i: number): StateMutabilityContext | null;
    public stateMutability(i?: number): StateMutabilityContext[] | StateMutabilityContext | null {
        if (i === undefined) {
            return this.getRuleContexts(StateMutabilityContext);
        }

        return this.getRuleContext(i, StateMutabilityContext);
    }
    public modifierInvocation(): ModifierInvocationContext[];
    public modifierInvocation(i: number): ModifierInvocationContext | null;
    public modifierInvocation(i?: number): ModifierInvocationContext[] | ModifierInvocationContext | null {
        if (i === undefined) {
            return this.getRuleContexts(ModifierInvocationContext);
        }

        return this.getRuleContext(i, ModifierInvocationContext);
    }
    public overrideSpecifier(): OverrideSpecifierContext[];
    public overrideSpecifier(i: number): OverrideSpecifierContext | null;
    public overrideSpecifier(i?: number): OverrideSpecifierContext[] | OverrideSpecifierContext | null {
        if (i === undefined) {
            return this.getRuleContexts(OverrideSpecifierContext);
        }

        return this.getRuleContext(i, OverrideSpecifierContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_modifierList;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterModifierList) {
             listener.enterModifierList(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitModifierList) {
             listener.exitModifierList(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitModifierList) {
            return visitor.visitModifierList(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class EventDefinitionContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext {
        return this.getRuleContext(0, IdentifierContext)!;
    }
    public eventParameterList(): EventParameterListContext {
        return this.getRuleContext(0, EventParameterListContext)!;
    }
    public AnonymousKeyword(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.AnonymousKeyword, 0);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_eventDefinition;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterEventDefinition) {
             listener.enterEventDefinition(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitEventDefinition) {
             listener.exitEventDefinition(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitEventDefinition) {
            return visitor.visitEventDefinition(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class EnumValueContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext {
        return this.getRuleContext(0, IdentifierContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_enumValue;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterEnumValue) {
             listener.enterEnumValue(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitEnumValue) {
             listener.exitEnumValue(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitEnumValue) {
            return visitor.visitEnumValue(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class EnumDefinitionContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext {
        return this.getRuleContext(0, IdentifierContext)!;
    }
    public enumValue(): EnumValueContext[];
    public enumValue(i: number): EnumValueContext | null;
    public enumValue(i?: number): EnumValueContext[] | EnumValueContext | null {
        if (i === undefined) {
            return this.getRuleContexts(EnumValueContext);
        }

        return this.getRuleContext(i, EnumValueContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_enumDefinition;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterEnumDefinition) {
             listener.enterEnumDefinition(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitEnumDefinition) {
             listener.exitEnumDefinition(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitEnumDefinition) {
            return visitor.visitEnumDefinition(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class ParameterListContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public parameter(): ParameterContext[];
    public parameter(i: number): ParameterContext | null;
    public parameter(i?: number): ParameterContext[] | ParameterContext | null {
        if (i === undefined) {
            return this.getRuleContexts(ParameterContext);
        }

        return this.getRuleContext(i, ParameterContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_parameterList;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterParameterList) {
             listener.enterParameterList(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitParameterList) {
             listener.exitParameterList(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitParameterList) {
            return visitor.visitParameterList(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class ParameterContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public typeName(): TypeNameContext {
        return this.getRuleContext(0, TypeNameContext)!;
    }
    public storageLocation(): StorageLocationContext | null {
        return this.getRuleContext(0, StorageLocationContext);
    }
    public identifier(): IdentifierContext | null {
        return this.getRuleContext(0, IdentifierContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_parameter;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterParameter) {
             listener.enterParameter(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitParameter) {
             listener.exitParameter(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitParameter) {
            return visitor.visitParameter(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class EventParameterListContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public eventParameter(): EventParameterContext[];
    public eventParameter(i: number): EventParameterContext | null;
    public eventParameter(i?: number): EventParameterContext[] | EventParameterContext | null {
        if (i === undefined) {
            return this.getRuleContexts(EventParameterContext);
        }

        return this.getRuleContext(i, EventParameterContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_eventParameterList;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterEventParameterList) {
             listener.enterEventParameterList(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitEventParameterList) {
             listener.exitEventParameterList(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitEventParameterList) {
            return visitor.visitEventParameterList(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class EventParameterContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public typeName(): TypeNameContext {
        return this.getRuleContext(0, TypeNameContext)!;
    }
    public IndexedKeyword(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.IndexedKeyword, 0);
    }
    public identifier(): IdentifierContext | null {
        return this.getRuleContext(0, IdentifierContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_eventParameter;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterEventParameter) {
             listener.enterEventParameter(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitEventParameter) {
             listener.exitEventParameter(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitEventParameter) {
            return visitor.visitEventParameter(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class FunctionTypeParameterListContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public functionTypeParameter(): FunctionTypeParameterContext[];
    public functionTypeParameter(i: number): FunctionTypeParameterContext | null;
    public functionTypeParameter(i?: number): FunctionTypeParameterContext[] | FunctionTypeParameterContext | null {
        if (i === undefined) {
            return this.getRuleContexts(FunctionTypeParameterContext);
        }

        return this.getRuleContext(i, FunctionTypeParameterContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_functionTypeParameterList;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterFunctionTypeParameterList) {
             listener.enterFunctionTypeParameterList(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitFunctionTypeParameterList) {
             listener.exitFunctionTypeParameterList(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitFunctionTypeParameterList) {
            return visitor.visitFunctionTypeParameterList(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class FunctionTypeParameterContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public typeName(): TypeNameContext {
        return this.getRuleContext(0, TypeNameContext)!;
    }
    public storageLocation(): StorageLocationContext | null {
        return this.getRuleContext(0, StorageLocationContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_functionTypeParameter;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterFunctionTypeParameter) {
             listener.enterFunctionTypeParameter(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitFunctionTypeParameter) {
             listener.exitFunctionTypeParameter(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitFunctionTypeParameter) {
            return visitor.visitFunctionTypeParameter(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class VariableDeclarationContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public typeName(): TypeNameContext {
        return this.getRuleContext(0, TypeNameContext)!;
    }
    public identifier(): IdentifierContext {
        return this.getRuleContext(0, IdentifierContext)!;
    }
    public storageLocation(): StorageLocationContext | null {
        return this.getRuleContext(0, StorageLocationContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_variableDeclaration;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterVariableDeclaration) {
             listener.enterVariableDeclaration(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitVariableDeclaration) {
             listener.exitVariableDeclaration(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitVariableDeclaration) {
            return visitor.visitVariableDeclaration(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class TypeNameContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public elementaryTypeName(): ElementaryTypeNameContext | null {
        return this.getRuleContext(0, ElementaryTypeNameContext);
    }
    public userDefinedTypeName(): UserDefinedTypeNameContext | null {
        return this.getRuleContext(0, UserDefinedTypeNameContext);
    }
    public mapping(): MappingContext | null {
        return this.getRuleContext(0, MappingContext);
    }
    public functionTypeName(): FunctionTypeNameContext | null {
        return this.getRuleContext(0, FunctionTypeNameContext);
    }
    public PayableKeyword(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.PayableKeyword, 0);
    }
    public typeName(): TypeNameContext | null {
        return this.getRuleContext(0, TypeNameContext);
    }
    public expression(): ExpressionContext | null {
        return this.getRuleContext(0, ExpressionContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_typeName;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterTypeName) {
             listener.enterTypeName(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitTypeName) {
             listener.exitTypeName(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitTypeName) {
            return visitor.visitTypeName(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class UserDefinedTypeNameContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext[];
    public identifier(i: number): IdentifierContext | null;
    public identifier(i?: number): IdentifierContext[] | IdentifierContext | null {
        if (i === undefined) {
            return this.getRuleContexts(IdentifierContext);
        }

        return this.getRuleContext(i, IdentifierContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_userDefinedTypeName;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterUserDefinedTypeName) {
             listener.enterUserDefinedTypeName(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitUserDefinedTypeName) {
             listener.exitUserDefinedTypeName(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitUserDefinedTypeName) {
            return visitor.visitUserDefinedTypeName(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class MappingKeyContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public elementaryTypeName(): ElementaryTypeNameContext | null {
        return this.getRuleContext(0, ElementaryTypeNameContext);
    }
    public userDefinedTypeName(): UserDefinedTypeNameContext | null {
        return this.getRuleContext(0, UserDefinedTypeNameContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_mappingKey;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterMappingKey) {
             listener.enterMappingKey(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitMappingKey) {
             listener.exitMappingKey(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitMappingKey) {
            return visitor.visitMappingKey(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class MappingContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public mappingKey(): MappingKeyContext {
        return this.getRuleContext(0, MappingKeyContext)!;
    }
    public typeName(): TypeNameContext {
        return this.getRuleContext(0, TypeNameContext)!;
    }
    public mappingKeyName(): MappingKeyNameContext | null {
        return this.getRuleContext(0, MappingKeyNameContext);
    }
    public mappingValueName(): MappingValueNameContext | null {
        return this.getRuleContext(0, MappingValueNameContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_mapping;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterMapping) {
             listener.enterMapping(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitMapping) {
             listener.exitMapping(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitMapping) {
            return visitor.visitMapping(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class MappingKeyNameContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext {
        return this.getRuleContext(0, IdentifierContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_mappingKeyName;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterMappingKeyName) {
             listener.enterMappingKeyName(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitMappingKeyName) {
             listener.exitMappingKeyName(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitMappingKeyName) {
            return visitor.visitMappingKeyName(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class MappingValueNameContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext {
        return this.getRuleContext(0, IdentifierContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_mappingValueName;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterMappingValueName) {
             listener.enterMappingValueName(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitMappingValueName) {
             listener.exitMappingValueName(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitMappingValueName) {
            return visitor.visitMappingValueName(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class FunctionTypeNameContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public functionTypeParameterList(): FunctionTypeParameterListContext[];
    public functionTypeParameterList(i: number): FunctionTypeParameterListContext | null;
    public functionTypeParameterList(i?: number): FunctionTypeParameterListContext[] | FunctionTypeParameterListContext | null {
        if (i === undefined) {
            return this.getRuleContexts(FunctionTypeParameterListContext);
        }

        return this.getRuleContext(i, FunctionTypeParameterListContext);
    }
    public InternalKeyword(): antlr.TerminalNode[];
    public InternalKeyword(i: number): antlr.TerminalNode | null;
    public InternalKeyword(i?: number): antlr.TerminalNode | null | antlr.TerminalNode[] {
    	if (i === undefined) {
    		return this.getTokens(SolidityParser.InternalKeyword);
    	} else {
    		return this.getToken(SolidityParser.InternalKeyword, i);
    	}
    }
    public ExternalKeyword(): antlr.TerminalNode[];
    public ExternalKeyword(i: number): antlr.TerminalNode | null;
    public ExternalKeyword(i?: number): antlr.TerminalNode | null | antlr.TerminalNode[] {
    	if (i === undefined) {
    		return this.getTokens(SolidityParser.ExternalKeyword);
    	} else {
    		return this.getToken(SolidityParser.ExternalKeyword, i);
    	}
    }
    public stateMutability(): StateMutabilityContext[];
    public stateMutability(i: number): StateMutabilityContext | null;
    public stateMutability(i?: number): StateMutabilityContext[] | StateMutabilityContext | null {
        if (i === undefined) {
            return this.getRuleContexts(StateMutabilityContext);
        }

        return this.getRuleContext(i, StateMutabilityContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_functionTypeName;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterFunctionTypeName) {
             listener.enterFunctionTypeName(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitFunctionTypeName) {
             listener.exitFunctionTypeName(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitFunctionTypeName) {
            return visitor.visitFunctionTypeName(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class StorageLocationContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_storageLocation;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterStorageLocation) {
             listener.enterStorageLocation(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitStorageLocation) {
             listener.exitStorageLocation(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitStorageLocation) {
            return visitor.visitStorageLocation(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class StateMutabilityContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public PureKeyword(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.PureKeyword, 0);
    }
    public ConstantKeyword(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.ConstantKeyword, 0);
    }
    public ViewKeyword(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.ViewKeyword, 0);
    }
    public PayableKeyword(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.PayableKeyword, 0);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_stateMutability;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterStateMutability) {
             listener.enterStateMutability(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitStateMutability) {
             listener.exitStateMutability(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitStateMutability) {
            return visitor.visitStateMutability(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class BlockContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public statement(): StatementContext[];
    public statement(i: number): StatementContext | null;
    public statement(i?: number): StatementContext[] | StatementContext | null {
        if (i === undefined) {
            return this.getRuleContexts(StatementContext);
        }

        return this.getRuleContext(i, StatementContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_block;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterBlock) {
             listener.enterBlock(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitBlock) {
             listener.exitBlock(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitBlock) {
            return visitor.visitBlock(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class StatementContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public ifStatement(): IfStatementContext | null {
        return this.getRuleContext(0, IfStatementContext);
    }
    public tryStatement(): TryStatementContext | null {
        return this.getRuleContext(0, TryStatementContext);
    }
    public whileStatement(): WhileStatementContext | null {
        return this.getRuleContext(0, WhileStatementContext);
    }
    public forStatement(): ForStatementContext | null {
        return this.getRuleContext(0, ForStatementContext);
    }
    public block(): BlockContext | null {
        return this.getRuleContext(0, BlockContext);
    }
    public inlineAssemblyStatement(): InlineAssemblyStatementContext | null {
        return this.getRuleContext(0, InlineAssemblyStatementContext);
    }
    public doWhileStatement(): DoWhileStatementContext | null {
        return this.getRuleContext(0, DoWhileStatementContext);
    }
    public continueStatement(): ContinueStatementContext | null {
        return this.getRuleContext(0, ContinueStatementContext);
    }
    public breakStatement(): BreakStatementContext | null {
        return this.getRuleContext(0, BreakStatementContext);
    }
    public returnStatement(): ReturnStatementContext | null {
        return this.getRuleContext(0, ReturnStatementContext);
    }
    public throwStatement(): ThrowStatementContext | null {
        return this.getRuleContext(0, ThrowStatementContext);
    }
    public emitStatement(): EmitStatementContext | null {
        return this.getRuleContext(0, EmitStatementContext);
    }
    public simpleStatement(): SimpleStatementContext | null {
        return this.getRuleContext(0, SimpleStatementContext);
    }
    public uncheckedStatement(): UncheckedStatementContext | null {
        return this.getRuleContext(0, UncheckedStatementContext);
    }
    public revertStatement(): RevertStatementContext | null {
        return this.getRuleContext(0, RevertStatementContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_statement;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterStatement) {
             listener.enterStatement(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitStatement) {
             listener.exitStatement(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitStatement) {
            return visitor.visitStatement(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class ExpressionStatementContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public expression(): ExpressionContext {
        return this.getRuleContext(0, ExpressionContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_expressionStatement;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterExpressionStatement) {
             listener.enterExpressionStatement(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitExpressionStatement) {
             listener.exitExpressionStatement(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitExpressionStatement) {
            return visitor.visitExpressionStatement(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class IfStatementContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public expression(): ExpressionContext {
        return this.getRuleContext(0, ExpressionContext)!;
    }
    public statement(): StatementContext[];
    public statement(i: number): StatementContext | null;
    public statement(i?: number): StatementContext[] | StatementContext | null {
        if (i === undefined) {
            return this.getRuleContexts(StatementContext);
        }

        return this.getRuleContext(i, StatementContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_ifStatement;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterIfStatement) {
             listener.enterIfStatement(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitIfStatement) {
             listener.exitIfStatement(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitIfStatement) {
            return visitor.visitIfStatement(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class TryStatementContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public expression(): ExpressionContext {
        return this.getRuleContext(0, ExpressionContext)!;
    }
    public block(): BlockContext {
        return this.getRuleContext(0, BlockContext)!;
    }
    public returnParameters(): ReturnParametersContext | null {
        return this.getRuleContext(0, ReturnParametersContext);
    }
    public catchClause(): CatchClauseContext[];
    public catchClause(i: number): CatchClauseContext | null;
    public catchClause(i?: number): CatchClauseContext[] | CatchClauseContext | null {
        if (i === undefined) {
            return this.getRuleContexts(CatchClauseContext);
        }

        return this.getRuleContext(i, CatchClauseContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_tryStatement;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterTryStatement) {
             listener.enterTryStatement(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitTryStatement) {
             listener.exitTryStatement(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitTryStatement) {
            return visitor.visitTryStatement(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class CatchClauseContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public block(): BlockContext {
        return this.getRuleContext(0, BlockContext)!;
    }
    public parameterList(): ParameterListContext | null {
        return this.getRuleContext(0, ParameterListContext);
    }
    public identifier(): IdentifierContext | null {
        return this.getRuleContext(0, IdentifierContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_catchClause;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterCatchClause) {
             listener.enterCatchClause(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitCatchClause) {
             listener.exitCatchClause(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitCatchClause) {
            return visitor.visitCatchClause(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class WhileStatementContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public expression(): ExpressionContext {
        return this.getRuleContext(0, ExpressionContext)!;
    }
    public statement(): StatementContext {
        return this.getRuleContext(0, StatementContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_whileStatement;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterWhileStatement) {
             listener.enterWhileStatement(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitWhileStatement) {
             listener.exitWhileStatement(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitWhileStatement) {
            return visitor.visitWhileStatement(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class SimpleStatementContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public variableDeclarationStatement(): VariableDeclarationStatementContext | null {
        return this.getRuleContext(0, VariableDeclarationStatementContext);
    }
    public expressionStatement(): ExpressionStatementContext | null {
        return this.getRuleContext(0, ExpressionStatementContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_simpleStatement;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterSimpleStatement) {
             listener.enterSimpleStatement(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitSimpleStatement) {
             listener.exitSimpleStatement(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitSimpleStatement) {
            return visitor.visitSimpleStatement(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class UncheckedStatementContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public block(): BlockContext {
        return this.getRuleContext(0, BlockContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_uncheckedStatement;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterUncheckedStatement) {
             listener.enterUncheckedStatement(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitUncheckedStatement) {
             listener.exitUncheckedStatement(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitUncheckedStatement) {
            return visitor.visitUncheckedStatement(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class ForStatementContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public statement(): StatementContext {
        return this.getRuleContext(0, StatementContext)!;
    }
    public simpleStatement(): SimpleStatementContext | null {
        return this.getRuleContext(0, SimpleStatementContext);
    }
    public expressionStatement(): ExpressionStatementContext | null {
        return this.getRuleContext(0, ExpressionStatementContext);
    }
    public expression(): ExpressionContext | null {
        return this.getRuleContext(0, ExpressionContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_forStatement;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterForStatement) {
             listener.enterForStatement(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitForStatement) {
             listener.exitForStatement(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitForStatement) {
            return visitor.visitForStatement(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class InlineAssemblyStatementContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public assemblyBlock(): AssemblyBlockContext {
        return this.getRuleContext(0, AssemblyBlockContext)!;
    }
    public StringLiteralFragment(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.StringLiteralFragment, 0);
    }
    public inlineAssemblyStatementFlag(): InlineAssemblyStatementFlagContext | null {
        return this.getRuleContext(0, InlineAssemblyStatementFlagContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_inlineAssemblyStatement;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterInlineAssemblyStatement) {
             listener.enterInlineAssemblyStatement(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitInlineAssemblyStatement) {
             listener.exitInlineAssemblyStatement(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitInlineAssemblyStatement) {
            return visitor.visitInlineAssemblyStatement(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class InlineAssemblyStatementFlagContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public stringLiteral(): StringLiteralContext {
        return this.getRuleContext(0, StringLiteralContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_inlineAssemblyStatementFlag;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterInlineAssemblyStatementFlag) {
             listener.enterInlineAssemblyStatementFlag(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitInlineAssemblyStatementFlag) {
             listener.exitInlineAssemblyStatementFlag(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitInlineAssemblyStatementFlag) {
            return visitor.visitInlineAssemblyStatementFlag(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class DoWhileStatementContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public statement(): StatementContext {
        return this.getRuleContext(0, StatementContext)!;
    }
    public expression(): ExpressionContext {
        return this.getRuleContext(0, ExpressionContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_doWhileStatement;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterDoWhileStatement) {
             listener.enterDoWhileStatement(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitDoWhileStatement) {
             listener.exitDoWhileStatement(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitDoWhileStatement) {
            return visitor.visitDoWhileStatement(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class ContinueStatementContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public ContinueKeyword(): antlr.TerminalNode {
        return this.getToken(SolidityParser.ContinueKeyword, 0)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_continueStatement;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterContinueStatement) {
             listener.enterContinueStatement(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitContinueStatement) {
             listener.exitContinueStatement(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitContinueStatement) {
            return visitor.visitContinueStatement(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class BreakStatementContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public BreakKeyword(): antlr.TerminalNode {
        return this.getToken(SolidityParser.BreakKeyword, 0)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_breakStatement;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterBreakStatement) {
             listener.enterBreakStatement(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitBreakStatement) {
             listener.exitBreakStatement(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitBreakStatement) {
            return visitor.visitBreakStatement(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class ReturnStatementContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public expression(): ExpressionContext | null {
        return this.getRuleContext(0, ExpressionContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_returnStatement;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterReturnStatement) {
             listener.enterReturnStatement(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitReturnStatement) {
             listener.exitReturnStatement(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitReturnStatement) {
            return visitor.visitReturnStatement(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class ThrowStatementContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_throwStatement;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterThrowStatement) {
             listener.enterThrowStatement(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitThrowStatement) {
             listener.exitThrowStatement(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitThrowStatement) {
            return visitor.visitThrowStatement(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class EmitStatementContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public functionCall(): FunctionCallContext {
        return this.getRuleContext(0, FunctionCallContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_emitStatement;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterEmitStatement) {
             listener.enterEmitStatement(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitEmitStatement) {
             listener.exitEmitStatement(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitEmitStatement) {
            return visitor.visitEmitStatement(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class RevertStatementContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public functionCall(): FunctionCallContext {
        return this.getRuleContext(0, FunctionCallContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_revertStatement;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterRevertStatement) {
             listener.enterRevertStatement(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitRevertStatement) {
             listener.exitRevertStatement(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitRevertStatement) {
            return visitor.visitRevertStatement(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class VariableDeclarationStatementContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifierList(): IdentifierListContext | null {
        return this.getRuleContext(0, IdentifierListContext);
    }
    public variableDeclaration(): VariableDeclarationContext | null {
        return this.getRuleContext(0, VariableDeclarationContext);
    }
    public variableDeclarationList(): VariableDeclarationListContext | null {
        return this.getRuleContext(0, VariableDeclarationListContext);
    }
    public expression(): ExpressionContext | null {
        return this.getRuleContext(0, ExpressionContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_variableDeclarationStatement;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterVariableDeclarationStatement) {
             listener.enterVariableDeclarationStatement(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitVariableDeclarationStatement) {
             listener.exitVariableDeclarationStatement(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitVariableDeclarationStatement) {
            return visitor.visitVariableDeclarationStatement(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class VariableDeclarationListContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public variableDeclaration(): VariableDeclarationContext[];
    public variableDeclaration(i: number): VariableDeclarationContext | null;
    public variableDeclaration(i?: number): VariableDeclarationContext[] | VariableDeclarationContext | null {
        if (i === undefined) {
            return this.getRuleContexts(VariableDeclarationContext);
        }

        return this.getRuleContext(i, VariableDeclarationContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_variableDeclarationList;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterVariableDeclarationList) {
             listener.enterVariableDeclarationList(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitVariableDeclarationList) {
             listener.exitVariableDeclarationList(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitVariableDeclarationList) {
            return visitor.visitVariableDeclarationList(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class IdentifierListContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext[];
    public identifier(i: number): IdentifierContext | null;
    public identifier(i?: number): IdentifierContext[] | IdentifierContext | null {
        if (i === undefined) {
            return this.getRuleContexts(IdentifierContext);
        }

        return this.getRuleContext(i, IdentifierContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_identifierList;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterIdentifierList) {
             listener.enterIdentifierList(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitIdentifierList) {
             listener.exitIdentifierList(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitIdentifierList) {
            return visitor.visitIdentifierList(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class ElementaryTypeNameContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public Int(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.Int, 0);
    }
    public Uint(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.Uint, 0);
    }
    public Byte(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.Byte, 0);
    }
    public Fixed(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.Fixed, 0);
    }
    public Ufixed(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.Ufixed, 0);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_elementaryTypeName;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterElementaryTypeName) {
             listener.enterElementaryTypeName(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitElementaryTypeName) {
             listener.exitElementaryTypeName(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitElementaryTypeName) {
            return visitor.visitElementaryTypeName(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class ExpressionContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public typeName(): TypeNameContext | null {
        return this.getRuleContext(0, TypeNameContext);
    }
    public expression(): ExpressionContext[];
    public expression(i: number): ExpressionContext | null;
    public expression(i?: number): ExpressionContext[] | ExpressionContext | null {
        if (i === undefined) {
            return this.getRuleContexts(ExpressionContext);
        }

        return this.getRuleContext(i, ExpressionContext);
    }
    public primaryExpression(): PrimaryExpressionContext | null {
        return this.getRuleContext(0, PrimaryExpressionContext);
    }
    public identifier(): IdentifierContext | null {
        return this.getRuleContext(0, IdentifierContext);
    }
    public nameValueList(): NameValueListContext | null {
        return this.getRuleContext(0, NameValueListContext);
    }
    public functionCallArguments(): FunctionCallArgumentsContext | null {
        return this.getRuleContext(0, FunctionCallArgumentsContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_expression;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterExpression) {
             listener.enterExpression(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitExpression) {
             listener.exitExpression(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitExpression) {
            return visitor.visitExpression(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class PrimaryExpressionContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public BooleanLiteral(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.BooleanLiteral, 0);
    }
    public numberLiteral(): NumberLiteralContext | null {
        return this.getRuleContext(0, NumberLiteralContext);
    }
    public hexLiteral(): HexLiteralContext | null {
        return this.getRuleContext(0, HexLiteralContext);
    }
    public stringLiteral(): StringLiteralContext | null {
        return this.getRuleContext(0, StringLiteralContext);
    }
    public identifier(): IdentifierContext | null {
        return this.getRuleContext(0, IdentifierContext);
    }
    public TypeKeyword(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.TypeKeyword, 0);
    }
    public PayableKeyword(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.PayableKeyword, 0);
    }
    public tupleExpression(): TupleExpressionContext | null {
        return this.getRuleContext(0, TupleExpressionContext);
    }
    public typeName(): TypeNameContext | null {
        return this.getRuleContext(0, TypeNameContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_primaryExpression;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterPrimaryExpression) {
             listener.enterPrimaryExpression(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitPrimaryExpression) {
             listener.exitPrimaryExpression(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitPrimaryExpression) {
            return visitor.visitPrimaryExpression(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class ExpressionListContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public expression(): ExpressionContext[];
    public expression(i: number): ExpressionContext | null;
    public expression(i?: number): ExpressionContext[] | ExpressionContext | null {
        if (i === undefined) {
            return this.getRuleContexts(ExpressionContext);
        }

        return this.getRuleContext(i, ExpressionContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_expressionList;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterExpressionList) {
             listener.enterExpressionList(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitExpressionList) {
             listener.exitExpressionList(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitExpressionList) {
            return visitor.visitExpressionList(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class NameValueListContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public nameValue(): NameValueContext[];
    public nameValue(i: number): NameValueContext | null;
    public nameValue(i?: number): NameValueContext[] | NameValueContext | null {
        if (i === undefined) {
            return this.getRuleContexts(NameValueContext);
        }

        return this.getRuleContext(i, NameValueContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_nameValueList;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterNameValueList) {
             listener.enterNameValueList(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitNameValueList) {
             listener.exitNameValueList(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitNameValueList) {
            return visitor.visitNameValueList(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class NameValueContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext {
        return this.getRuleContext(0, IdentifierContext)!;
    }
    public expression(): ExpressionContext {
        return this.getRuleContext(0, ExpressionContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_nameValue;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterNameValue) {
             listener.enterNameValue(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitNameValue) {
             listener.exitNameValue(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitNameValue) {
            return visitor.visitNameValue(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class FunctionCallArgumentsContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public nameValueList(): NameValueListContext | null {
        return this.getRuleContext(0, NameValueListContext);
    }
    public expressionList(): ExpressionListContext | null {
        return this.getRuleContext(0, ExpressionListContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_functionCallArguments;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterFunctionCallArguments) {
             listener.enterFunctionCallArguments(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitFunctionCallArguments) {
             listener.exitFunctionCallArguments(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitFunctionCallArguments) {
            return visitor.visitFunctionCallArguments(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class FunctionCallContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public expression(): ExpressionContext {
        return this.getRuleContext(0, ExpressionContext)!;
    }
    public functionCallArguments(): FunctionCallArgumentsContext {
        return this.getRuleContext(0, FunctionCallArgumentsContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_functionCall;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterFunctionCall) {
             listener.enterFunctionCall(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitFunctionCall) {
             listener.exitFunctionCall(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitFunctionCall) {
            return visitor.visitFunctionCall(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class AssemblyBlockContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public assemblyItem(): AssemblyItemContext[];
    public assemblyItem(i: number): AssemblyItemContext | null;
    public assemblyItem(i?: number): AssemblyItemContext[] | AssemblyItemContext | null {
        if (i === undefined) {
            return this.getRuleContexts(AssemblyItemContext);
        }

        return this.getRuleContext(i, AssemblyItemContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_assemblyBlock;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterAssemblyBlock) {
             listener.enterAssemblyBlock(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitAssemblyBlock) {
             listener.exitAssemblyBlock(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitAssemblyBlock) {
            return visitor.visitAssemblyBlock(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class AssemblyItemContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext | null {
        return this.getRuleContext(0, IdentifierContext);
    }
    public assemblyBlock(): AssemblyBlockContext | null {
        return this.getRuleContext(0, AssemblyBlockContext);
    }
    public assemblyExpression(): AssemblyExpressionContext | null {
        return this.getRuleContext(0, AssemblyExpressionContext);
    }
    public assemblyLocalDefinition(): AssemblyLocalDefinitionContext | null {
        return this.getRuleContext(0, AssemblyLocalDefinitionContext);
    }
    public assemblyAssignment(): AssemblyAssignmentContext | null {
        return this.getRuleContext(0, AssemblyAssignmentContext);
    }
    public assemblyStackAssignment(): AssemblyStackAssignmentContext | null {
        return this.getRuleContext(0, AssemblyStackAssignmentContext);
    }
    public labelDefinition(): LabelDefinitionContext | null {
        return this.getRuleContext(0, LabelDefinitionContext);
    }
    public assemblySwitch(): AssemblySwitchContext | null {
        return this.getRuleContext(0, AssemblySwitchContext);
    }
    public assemblyFunctionDefinition(): AssemblyFunctionDefinitionContext | null {
        return this.getRuleContext(0, AssemblyFunctionDefinitionContext);
    }
    public assemblyFor(): AssemblyForContext | null {
        return this.getRuleContext(0, AssemblyForContext);
    }
    public assemblyIf(): AssemblyIfContext | null {
        return this.getRuleContext(0, AssemblyIfContext);
    }
    public BreakKeyword(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.BreakKeyword, 0);
    }
    public ContinueKeyword(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.ContinueKeyword, 0);
    }
    public LeaveKeyword(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.LeaveKeyword, 0);
    }
    public numberLiteral(): NumberLiteralContext | null {
        return this.getRuleContext(0, NumberLiteralContext);
    }
    public stringLiteral(): StringLiteralContext | null {
        return this.getRuleContext(0, StringLiteralContext);
    }
    public hexLiteral(): HexLiteralContext | null {
        return this.getRuleContext(0, HexLiteralContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_assemblyItem;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterAssemblyItem) {
             listener.enterAssemblyItem(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitAssemblyItem) {
             listener.exitAssemblyItem(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitAssemblyItem) {
            return visitor.visitAssemblyItem(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class AssemblyExpressionContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public assemblyCall(): AssemblyCallContext | null {
        return this.getRuleContext(0, AssemblyCallContext);
    }
    public assemblyLiteral(): AssemblyLiteralContext | null {
        return this.getRuleContext(0, AssemblyLiteralContext);
    }
    public assemblyMember(): AssemblyMemberContext | null {
        return this.getRuleContext(0, AssemblyMemberContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_assemblyExpression;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterAssemblyExpression) {
             listener.enterAssemblyExpression(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitAssemblyExpression) {
             listener.exitAssemblyExpression(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitAssemblyExpression) {
            return visitor.visitAssemblyExpression(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class AssemblyMemberContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext[];
    public identifier(i: number): IdentifierContext | null;
    public identifier(i?: number): IdentifierContext[] | IdentifierContext | null {
        if (i === undefined) {
            return this.getRuleContexts(IdentifierContext);
        }

        return this.getRuleContext(i, IdentifierContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_assemblyMember;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterAssemblyMember) {
             listener.enterAssemblyMember(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitAssemblyMember) {
             listener.exitAssemblyMember(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitAssemblyMember) {
            return visitor.visitAssemblyMember(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class AssemblyCallContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext | null {
        return this.getRuleContext(0, IdentifierContext);
    }
    public assemblyExpression(): AssemblyExpressionContext[];
    public assemblyExpression(i: number): AssemblyExpressionContext | null;
    public assemblyExpression(i?: number): AssemblyExpressionContext[] | AssemblyExpressionContext | null {
        if (i === undefined) {
            return this.getRuleContexts(AssemblyExpressionContext);
        }

        return this.getRuleContext(i, AssemblyExpressionContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_assemblyCall;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterAssemblyCall) {
             listener.enterAssemblyCall(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitAssemblyCall) {
             listener.exitAssemblyCall(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitAssemblyCall) {
            return visitor.visitAssemblyCall(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class AssemblyLocalDefinitionContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public assemblyIdentifierOrList(): AssemblyIdentifierOrListContext {
        return this.getRuleContext(0, AssemblyIdentifierOrListContext)!;
    }
    public assemblyExpression(): AssemblyExpressionContext | null {
        return this.getRuleContext(0, AssemblyExpressionContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_assemblyLocalDefinition;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterAssemblyLocalDefinition) {
             listener.enterAssemblyLocalDefinition(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitAssemblyLocalDefinition) {
             listener.exitAssemblyLocalDefinition(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitAssemblyLocalDefinition) {
            return visitor.visitAssemblyLocalDefinition(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class AssemblyAssignmentContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public assemblyIdentifierOrList(): AssemblyIdentifierOrListContext {
        return this.getRuleContext(0, AssemblyIdentifierOrListContext)!;
    }
    public assemblyExpression(): AssemblyExpressionContext {
        return this.getRuleContext(0, AssemblyExpressionContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_assemblyAssignment;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterAssemblyAssignment) {
             listener.enterAssemblyAssignment(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitAssemblyAssignment) {
             listener.exitAssemblyAssignment(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitAssemblyAssignment) {
            return visitor.visitAssemblyAssignment(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class AssemblyIdentifierOrListContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext | null {
        return this.getRuleContext(0, IdentifierContext);
    }
    public assemblyMember(): AssemblyMemberContext | null {
        return this.getRuleContext(0, AssemblyMemberContext);
    }
    public assemblyIdentifierList(): AssemblyIdentifierListContext | null {
        return this.getRuleContext(0, AssemblyIdentifierListContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_assemblyIdentifierOrList;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterAssemblyIdentifierOrList) {
             listener.enterAssemblyIdentifierOrList(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitAssemblyIdentifierOrList) {
             listener.exitAssemblyIdentifierOrList(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitAssemblyIdentifierOrList) {
            return visitor.visitAssemblyIdentifierOrList(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class AssemblyIdentifierListContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext[];
    public identifier(i: number): IdentifierContext | null;
    public identifier(i?: number): IdentifierContext[] | IdentifierContext | null {
        if (i === undefined) {
            return this.getRuleContexts(IdentifierContext);
        }

        return this.getRuleContext(i, IdentifierContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_assemblyIdentifierList;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterAssemblyIdentifierList) {
             listener.enterAssemblyIdentifierList(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitAssemblyIdentifierList) {
             listener.exitAssemblyIdentifierList(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitAssemblyIdentifierList) {
            return visitor.visitAssemblyIdentifierList(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class AssemblyStackAssignmentContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public assemblyExpression(): AssemblyExpressionContext {
        return this.getRuleContext(0, AssemblyExpressionContext)!;
    }
    public identifier(): IdentifierContext {
        return this.getRuleContext(0, IdentifierContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_assemblyStackAssignment;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterAssemblyStackAssignment) {
             listener.enterAssemblyStackAssignment(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitAssemblyStackAssignment) {
             listener.exitAssemblyStackAssignment(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitAssemblyStackAssignment) {
            return visitor.visitAssemblyStackAssignment(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class LabelDefinitionContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext {
        return this.getRuleContext(0, IdentifierContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_labelDefinition;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterLabelDefinition) {
             listener.enterLabelDefinition(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitLabelDefinition) {
             listener.exitLabelDefinition(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitLabelDefinition) {
            return visitor.visitLabelDefinition(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class AssemblySwitchContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public assemblyExpression(): AssemblyExpressionContext {
        return this.getRuleContext(0, AssemblyExpressionContext)!;
    }
    public assemblyCase(): AssemblyCaseContext[];
    public assemblyCase(i: number): AssemblyCaseContext | null;
    public assemblyCase(i?: number): AssemblyCaseContext[] | AssemblyCaseContext | null {
        if (i === undefined) {
            return this.getRuleContexts(AssemblyCaseContext);
        }

        return this.getRuleContext(i, AssemblyCaseContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_assemblySwitch;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterAssemblySwitch) {
             listener.enterAssemblySwitch(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitAssemblySwitch) {
             listener.exitAssemblySwitch(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitAssemblySwitch) {
            return visitor.visitAssemblySwitch(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class AssemblyCaseContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public assemblyLiteral(): AssemblyLiteralContext | null {
        return this.getRuleContext(0, AssemblyLiteralContext);
    }
    public assemblyBlock(): AssemblyBlockContext {
        return this.getRuleContext(0, AssemblyBlockContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_assemblyCase;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterAssemblyCase) {
             listener.enterAssemblyCase(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitAssemblyCase) {
             listener.exitAssemblyCase(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitAssemblyCase) {
            return visitor.visitAssemblyCase(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class AssemblyFunctionDefinitionContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public identifier(): IdentifierContext {
        return this.getRuleContext(0, IdentifierContext)!;
    }
    public assemblyBlock(): AssemblyBlockContext {
        return this.getRuleContext(0, AssemblyBlockContext)!;
    }
    public assemblyIdentifierList(): AssemblyIdentifierListContext | null {
        return this.getRuleContext(0, AssemblyIdentifierListContext);
    }
    public assemblyFunctionReturns(): AssemblyFunctionReturnsContext | null {
        return this.getRuleContext(0, AssemblyFunctionReturnsContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_assemblyFunctionDefinition;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterAssemblyFunctionDefinition) {
             listener.enterAssemblyFunctionDefinition(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitAssemblyFunctionDefinition) {
             listener.exitAssemblyFunctionDefinition(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitAssemblyFunctionDefinition) {
            return visitor.visitAssemblyFunctionDefinition(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class AssemblyFunctionReturnsContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public assemblyIdentifierList(): AssemblyIdentifierListContext | null {
        return this.getRuleContext(0, AssemblyIdentifierListContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_assemblyFunctionReturns;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterAssemblyFunctionReturns) {
             listener.enterAssemblyFunctionReturns(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitAssemblyFunctionReturns) {
             listener.exitAssemblyFunctionReturns(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitAssemblyFunctionReturns) {
            return visitor.visitAssemblyFunctionReturns(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class AssemblyForContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public assemblyExpression(): AssemblyExpressionContext[];
    public assemblyExpression(i: number): AssemblyExpressionContext | null;
    public assemblyExpression(i?: number): AssemblyExpressionContext[] | AssemblyExpressionContext | null {
        if (i === undefined) {
            return this.getRuleContexts(AssemblyExpressionContext);
        }

        return this.getRuleContext(i, AssemblyExpressionContext);
    }
    public assemblyBlock(): AssemblyBlockContext[];
    public assemblyBlock(i: number): AssemblyBlockContext | null;
    public assemblyBlock(i?: number): AssemblyBlockContext[] | AssemblyBlockContext | null {
        if (i === undefined) {
            return this.getRuleContexts(AssemblyBlockContext);
        }

        return this.getRuleContext(i, AssemblyBlockContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_assemblyFor;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterAssemblyFor) {
             listener.enterAssemblyFor(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitAssemblyFor) {
             listener.exitAssemblyFor(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitAssemblyFor) {
            return visitor.visitAssemblyFor(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class AssemblyIfContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public assemblyExpression(): AssemblyExpressionContext {
        return this.getRuleContext(0, AssemblyExpressionContext)!;
    }
    public assemblyBlock(): AssemblyBlockContext {
        return this.getRuleContext(0, AssemblyBlockContext)!;
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_assemblyIf;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterAssemblyIf) {
             listener.enterAssemblyIf(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitAssemblyIf) {
             listener.exitAssemblyIf(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitAssemblyIf) {
            return visitor.visitAssemblyIf(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class AssemblyLiteralContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public stringLiteral(): StringLiteralContext | null {
        return this.getRuleContext(0, StringLiteralContext);
    }
    public DecimalNumber(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.DecimalNumber, 0);
    }
    public HexNumber(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.HexNumber, 0);
    }
    public hexLiteral(): HexLiteralContext | null {
        return this.getRuleContext(0, HexLiteralContext);
    }
    public BooleanLiteral(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.BooleanLiteral, 0);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_assemblyLiteral;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterAssemblyLiteral) {
             listener.enterAssemblyLiteral(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitAssemblyLiteral) {
             listener.exitAssemblyLiteral(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitAssemblyLiteral) {
            return visitor.visitAssemblyLiteral(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class TupleExpressionContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public expression(): ExpressionContext[];
    public expression(i: number): ExpressionContext | null;
    public expression(i?: number): ExpressionContext[] | ExpressionContext | null {
        if (i === undefined) {
            return this.getRuleContexts(ExpressionContext);
        }

        return this.getRuleContext(i, ExpressionContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_tupleExpression;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterTupleExpression) {
             listener.enterTupleExpression(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitTupleExpression) {
             listener.exitTupleExpression(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitTupleExpression) {
            return visitor.visitTupleExpression(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class NumberLiteralContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public DecimalNumber(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.DecimalNumber, 0);
    }
    public HexNumber(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.HexNumber, 0);
    }
    public NumberUnit(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.NumberUnit, 0);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_numberLiteral;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterNumberLiteral) {
             listener.enterNumberLiteral(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitNumberLiteral) {
             listener.exitNumberLiteral(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitNumberLiteral) {
            return visitor.visitNumberLiteral(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class IdentifierContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public ReceiveKeyword(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.ReceiveKeyword, 0);
    }
    public GlobalKeyword(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.GlobalKeyword, 0);
    }
    public ConstructorKeyword(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.ConstructorKeyword, 0);
    }
    public PayableKeyword(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.PayableKeyword, 0);
    }
    public LeaveKeyword(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.LeaveKeyword, 0);
    }
    public Identifier(): antlr.TerminalNode | null {
        return this.getToken(SolidityParser.Identifier, 0);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_identifier;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterIdentifier) {
             listener.enterIdentifier(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitIdentifier) {
             listener.exitIdentifier(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitIdentifier) {
            return visitor.visitIdentifier(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class HexLiteralContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public HexLiteralFragment(): antlr.TerminalNode[];
    public HexLiteralFragment(i: number): antlr.TerminalNode | null;
    public HexLiteralFragment(i?: number): antlr.TerminalNode | null | antlr.TerminalNode[] {
    	if (i === undefined) {
    		return this.getTokens(SolidityParser.HexLiteralFragment);
    	} else {
    		return this.getToken(SolidityParser.HexLiteralFragment, i);
    	}
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_hexLiteral;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterHexLiteral) {
             listener.enterHexLiteral(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitHexLiteral) {
             listener.exitHexLiteral(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitHexLiteral) {
            return visitor.visitHexLiteral(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class OverrideSpecifierContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public userDefinedTypeName(): UserDefinedTypeNameContext[];
    public userDefinedTypeName(i: number): UserDefinedTypeNameContext | null;
    public userDefinedTypeName(i?: number): UserDefinedTypeNameContext[] | UserDefinedTypeNameContext | null {
        if (i === undefined) {
            return this.getRuleContexts(UserDefinedTypeNameContext);
        }

        return this.getRuleContext(i, UserDefinedTypeNameContext);
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_overrideSpecifier;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterOverrideSpecifier) {
             listener.enterOverrideSpecifier(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitOverrideSpecifier) {
             listener.exitOverrideSpecifier(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitOverrideSpecifier) {
            return visitor.visitOverrideSpecifier(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}


export class StringLiteralContext extends antlr.ParserRuleContext {
    public constructor(parent: antlr.ParserRuleContext | null, invokingState: number) {
        super(parent, invokingState);
    }
    public StringLiteralFragment(): antlr.TerminalNode[];
    public StringLiteralFragment(i: number): antlr.TerminalNode | null;
    public StringLiteralFragment(i?: number): antlr.TerminalNode | null | antlr.TerminalNode[] {
    	if (i === undefined) {
    		return this.getTokens(SolidityParser.StringLiteralFragment);
    	} else {
    		return this.getToken(SolidityParser.StringLiteralFragment, i);
    	}
    }
    public override get ruleIndex(): number {
        return SolidityParser.RULE_stringLiteral;
    }
    public override enterRule(listener: SolidityListener): void {
        if(listener.enterStringLiteral) {
             listener.enterStringLiteral(this);
        }
    }
    public override exitRule(listener: SolidityListener): void {
        if(listener.exitStringLiteral) {
             listener.exitStringLiteral(this);
        }
    }
    public override accept<Result>(visitor: SolidityVisitor<Result>): Result | null {
        if (visitor.visitStringLiteral) {
            return visitor.visitStringLiteral(this);
        } else {
            return visitor.visitChildren(this);
        }
    }
}
