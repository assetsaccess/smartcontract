/ SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Migrations
 * @dev This contract keeps track of migrated contracts and their versions
 * It can be used to manage deployments and upgrades in a Foundry project
 */
contract Migrations is Ownable {
    // Struct to store information about each deployed contract
    struct DeployedContract {
        address contractAddress;
        uint256 version;
        bool isLatest;
    }

    // Mapping to store deployed contracts by their name
    mapping(string => DeployedContract[]) public deployedContracts;

    // Event emitted when a new contract is deployed
    event ContractDeployed(string contractName, address contractAddress, uint256 version);

    // Event emitted when a contract is marked as the latest version
    event LatestVersionUpdated(string contractName, address contractAddress, uint256 version);

    /**
     * @dev Deploys a new contract or updates an existing one
     * @param contractName Name of the contract being deployed
     * @param contractAddress Address of the deployed contract
     * @param version Version number of the deployed contract
     */
    function setDeployedContract(string memory contractName, address contractAddress, uint256 version) public onlyOwner {
        require(contractAddress != address(0), "Invalid contract address");
        require(bytes(contractName).length > 0, "Contract name cannot be empty");

        DeployedContract[] storage contracts = deployedContracts[contractName];

        // Check if this version already exists
        for (uint i = 0; i < contracts.length; i++) {
            if (contracts[i].version == version) {
                revert("Version already exists");
            }
        }

        // Add the new contract
        contracts.push(DeployedContract({
            contractAddress: contractAddress,
            version: version,
            isLatest: true
        }));

        // Mark previous versions as not latest
        if (contracts.length > 1) {
            for (uint i = 0; i < contracts.length - 1; i++) {
                contracts[i].isLatest = false;
            }
        }

        emit ContractDeployed(contractName, contractAddress, version);
        emit LatestVersionUpdated(contractName, contractAddress, version);
    }

    /**
     * @dev Retrieves the address of the latest version of a contract
     * @param contractName Name of the contract
     * @return address The address of the latest version of the contract
     */
    function getLatestContract(string memory contractName) public view returns (address) {
        DeployedContract[] storage contracts = deployedContracts[contractName];
        require(contracts.length > 0, "No contracts deployed with this name");

        for (uint i = 0; i < contracts.length; i++) {
            if (contracts[i].isLatest) {
                return contracts[i].contractAddress;
            }
        }

        revert("No latest version found");
    }

    /**
     * @dev Retrieves all versions of a deployed contract
     * @param contractName Name of the contract
     * @return DeployedContract[] An array of all deployed versions of the contract
     */
    function getAllVersions(string memory contractName) public view returns (DeployedContract[] memory) {
        return deployedContracts[contractName];
    }

    /**
     * @dev Updates the latest version of a contract
     * @param contractName Name of the contract
     * @param version Version number to set as latest
     */
    function updateLatestVersion(string memory contractName, uint256 version) public onlyOwner {
        DeployedContract[] storage contracts = deployedContracts[contractName];
        require(contracts.length > 0, "No contracts deployed with this name");

        bool versionFound = false;
        for (uint i = 0; i < contracts.length; i++) {
            if (contracts[i].version == version) {
                contracts[i].isLatest = true;
                versionFound = true;
                emit LatestVersionUpdated(contractName, contracts[i].contractAddress, version);
            } else {
                contracts[i].isLatest = false;
            }
        }

        require(versionFound, "Version not found");
    }
}