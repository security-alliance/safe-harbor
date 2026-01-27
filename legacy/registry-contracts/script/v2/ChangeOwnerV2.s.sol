// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {AgreementV2} from "../../src/v2/AgreementV2.sol";

contract ChangeOwnerV2 is Script {
    /// @notice Entry via env vars: requires DEPLOYER_PRIVATE_KEY, AGREEMENT_ADDRESS, NEW_OWNER
    function run() public {
        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address agreementAddress = vm.envAddress("AGREEMENT_ADDRESS");
        address newOwner = vm.envAddress("NEW_OWNER");
        _transferOwnership(pk, agreementAddress, newOwner);
    }

    /// @notice Entry via CLI signature: forge script ... --sig 'run(address,address)' <agreement> <newOwner>
    /// @dev Still reads DEPLOYER_PRIVATE_KEY from env for broadcasting
    function run(address agreementAddress, address newOwner) public {
        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        _transferOwnership(pk, agreementAddress, newOwner);
    }

    function _transferOwnership(uint256 pk, address agreementAddress, address newOwner) internal {
        require(agreementAddress != address(0), "agreement address is zero");
        require(newOwner != address(0), "new owner is zero");

        AgreementV2 agreement = AgreementV2(agreementAddress);
        require(address(agreement).code.length > 0, "No contract at agreement address");

        address sender = vm.addr(pk);
        address currentOwner = agreement.owner();
        require(currentOwner == sender, "sender is not current owner");
        require(newOwner != currentOwner, "new owner equals current owner");

        console.log("Transferring ownership of agreement:");
        console.logAddress(agreementAddress);
        console.log("From:");
        console.logAddress(currentOwner);
        console.log("To:");
        console.logAddress(newOwner);

        vm.startBroadcast(pk);
        agreement.transferOwnership(newOwner);
        vm.stopBroadcast();

        console.log("Ownership transferred successfully");
    }
}
