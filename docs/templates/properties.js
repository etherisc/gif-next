const { isNodeType } = require('solidity-ast/utils');
const { slug } = require('./helpers');

module.exports.anchor = function anchor({ item, contract }) {
    let res = '';
    if (contract) {
        res += contract.name + '-';
    }
    res += item.name;
    if ('parameters' in item) {
        const signature = item.parameters.parameters.map(v => v.typeName.typeDescriptions.typeString).join(',');
        res += slug('(' + signature + ')');
    }
    if (isNodeType('VariableDeclaration', item)) {
        res += '-' + slug(item.typeName.typeDescriptions.typeString);
    }
    return res;
};

// module.exports.externalLink = function ({ item, contract }) {

//     const anchor = module.exports.anchor({ item, contract });
//     // TODO: exchange this against links to the actual docs
//     const links = {
//         '@etherisc/gif-next': 'https://github.com/etherisc/gif-next/blob/develop',
//         '@openzeppelin': 'https://docs.openzeppelin.com/contracts/3.x/api'
//     };

//     const path = item.__item_context.file.absolutePath;
//     for (const [key, value] of Object.entries(links)) {
//         if (path.startsWith(key)) {
//             if (key === '@openzeppelin') {
//                 const s1 = /contracts\/([^\/]+)\/.*$/;
//                 const s2 = /contracts\/(.*)\/.*$/;
//                 const mod1 = path.match(s1)[1];
//                 const mod2 = path.match(s2)[1];
//                 console.log(path, mod1, mod2)
//                 return value + '/' + (mod1 === 'token' ? mod2 : mod1) + '#' + anchor;
//             } else {
//                 return value + path.slice(key.length);
//             }
//         }
//     }
//     return "";
// };

// module.exports.isInternal = function ({ item, contract }) {
//     return module.exports.externalLink({ item, contract }) === "";
// }

module.exports.inheritance = function ({ item, build }) {
    if (!isNodeType('ContractDefinition', item)) {
        throw new Error('used inherited-items on non-contract');
    }

    return item.linearizedBaseContracts
        .map(id => build.deref('ContractDefinition', id))
        .filter((c, i) => c.name !== 'Context' || i === 0);
};

module.exports['has-functions'] = function ({ item }) {
    // console.log(item.inheritance)
    return item.inheritance.some(c => c.functions.length > 0);
};

module.exports['has-events'] = function ({ item }) {
    return item.inheritance.some(c => c.events.length > 0);
};

module.exports['inherited-functions'] = function ({ item }) {
    const { inheritance } = item;
    const baseFunctions = new Set(
        inheritance.flatMap(c => c.functions.flatMap(f => f.baseFunctions ?? [])),
    );
    return inheritance.map((contract, i) => ({
        contract,
        functions: contract.functions.filter(f =>
            !baseFunctions.has(f.id) && (f.name !== 'constructor' || i === 0),
        ),
    }));
};