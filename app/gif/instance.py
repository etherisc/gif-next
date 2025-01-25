from typing import List, Dict

from web3 import Web3
from web3utils.contract import Contract

def get_targets(admin:Contract, reader:Contract):
    num_targets = admin.targets()
    targets = {}
    for i in range(num_targets):
        target_address = admin.getTargetAddress(i)
        target_info = admin.getTargetInfo(target_address)
        targets[target_address] = to_target_info_dict(reader, target_info)
    
    return targets

def get_functions(target_address:str, admin:Contract, reader:Contract):
    num_functions = admin.authorizedFunctions(target_address)
    functions = {}
    for i in range(num_functions):
        (function_info, role_id) = admin.getAuthorizedFunction(target_address, i)
        function_id = function_info[1]
        functions[f'0x{function_id.hex()}'] = to_function_info_dict(reader, function_info, role_id)
    
    return functions

def get_roles(admin:Contract, reader:Contract):
    num_roles = admin.roles()
    roles = {}
    for i in range(num_roles):
        role_id = admin.getRoleId(i)
        role_info = admin.getRoleInfo(role_id)
        roles[role_id] = to_role_info_dict(reader, role_info)
        print(roles[role_id])
    
    return roles

def to_target_info_dict(reader, target_info):
    return {
        'name': reader.toString(target_info[0]),
        'targetType': target_info[1],
        'roleId': target_info[2],
        'createdAt': target_info[3],
        'lastUpdateIn': target_info[4]
    }

def to_function_info_dict(reader, function_info, role_id):
    return {
        'name': reader.toString(function_info[0]),
        'roleId': role_id,
        'selector': function_info[1],
        'createdAt': function_info[2],
        'lastUpdateIn': function_info[3]
    }

def to_role_info_dict(reader, role_info):
    return {
        'name': reader.toString(role_info[6]),
        'adminRoleId': role_info[0],
        'targetType': role_info[1],
        'maxMemberCount': role_info[2],
        'createdAt': role_info[3],
        'pausedAt': role_info[4],
        'lastUpdateIn': role_info[5]
    }