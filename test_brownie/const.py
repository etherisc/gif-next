from brownie.network import accounts

ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

# GIF general
VERSION = (3, 0, 0)

# GIF object types
PROTOCOL = 10
REGISTRY = 20
TOKEN = 30
SERVICE = 40
INSTANCE = 50
STAKE = 60
COMPONENT = 100
TREASURY = 101
PRODUCT = 110
COMPENSATION = 120
ORACLE = 130
POOL = 140
RISK = 200
POLICY = 210
BUNDLE = 220
CLAIM = 211
PAYOUT = 212

# GIF object states
APPLIED = 10
DECLINED = 30
UNDERWRITTEN = 40
ACTIVE = 100

# GIF services
COMPONENT_OWNER_SERVICE_NAME = 'ComponentOwnerService'
DISTRIBUTION_SERVICE_NAME = 'DistributionService'
ORACLE_SERVICE_NAME = 'OracleService'
POOL_SERVICE_NAME = 'PoolService'
PRODUCT_SERVICE_NAME = 'ProductService'

# GIF roles
DISTRIBUTION_OWNER_ROLE = 'DistributionOwnerRole'
POOL_OWNER_ROLE = 'PoolOwnerRole'
PRODUCT_OWNER_ROLE = 'ProductOwnerRole'

# GIF ecosystem actors
REGISTRY_OWNER = 'registryOwner'
INSTANCE_OWNER = 'instanceOwner'
DISTRIBUTION_OWNER = 'distributionOwner'
POOL_OWNER = 'poolOwner'
PRODUCT_OWNER = 'productOwner'
INVESTOR = 'investor'
CUSTOMER = 'customer'
CUSTOMER_2 = 'customer2'
OUTSIDER = 'outsider'

ACTORS = [REGISTRY_OWNER, INSTANCE_OWNER, DISTRIBUTION_OWNER, POOL_OWNER, PRODUCT_OWNER, INVESTOR, CUSTOMER, CUSTOMER_2, OUTSIDER]

ACCOUNTS = {
    REGISTRY_OWNER: 0,
    INSTANCE_OWNER: 1,
    DISTRIBUTION_OWNER: 2,
    POOL_OWNER: 3,
    PRODUCT_OWNER: 4,
    INVESTOR: 5,
    CUSTOMER: 6,
    CUSTOMER_2: 7,
    OUTSIDER: 8,
}

# GIF types
ADDRESS = 'address'
NFT_ID = 'uint96'
