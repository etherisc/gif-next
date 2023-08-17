#!/bin/env bash

# Install required solidity compiler version
mkdir -p ~/.solcx/ 
wget -O ~/.solcx/solc-v0.8.2 https://binaries.soliditylang.org/linux-amd64/solc-linux-amd64-v0.8.2+commit.661d1103 
wget -O ~/.solcx/solc-v0.8.17 https://binaries.soliditylang.org/linux-amd64/solc-linux-amd64-v0.8.17+commit.8df45f5f
chmod 755 ~/.solcx/solc* 

# Retrieve brownie dependencies
export VERSION_OPEN_ZEPPELIN=4.7.3
export VERSION_CHAINLINK=1.6.0
wget -O /tmp/v${VERSION_OPEN_ZEPPELIN}.tar.gz https://github.com/OpenZeppelin/openzeppelin-contracts/archive/refs/tags/v${VERSION_OPEN_ZEPPELIN}.tar.gz 
wget -O /tmp/v${VERSION_CHAINLINK}.tar.gz https://github.com/smartcontractkit/chainlink/archive/refs/tags/v${VERSION_CHAINLINK}.tar.gz
mkdir -p ~/.brownie/packages/OpenZeppelin 
cd ~/.brownie/packages/OpenZeppelin 
tar xvfz /tmp/v${VERSION_OPEN_ZEPPELIN}.tar.gz 
mv openzeppelin-contracts-${VERSION_OPEN_ZEPPELIN} openzeppelin-contracts@${VERSION_OPEN_ZEPPELIN} 
mkdir -p ~/.brownie/packages/smartcontractkit 
cd ~/.brownie/packages/smartcontractkit 
tar xvfz /tmp/v${VERSION_CHAINLINK}.tar.gz 
mv chainlink-${VERSION_CHAINLINK} chainlink@${VERSION_CHAINLINK}

# Install ganache
npm install --global ganache

# Install brownie
python3 -m pip install --user pipx
python3 -m pipx ensurepath 
pipx install eth-brownie

