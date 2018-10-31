pragma solidity 0.4.25;

import "./Standards/IMigrationTarget.sol";


/// @notice mixin that enables contract to receive migration
/// @dev when derived from
contract MigrationTarget is
    IMigrationTarget
{
    ////////////////////////
    // Modifiers
    ////////////////////////

    // intended to be applied on migration receiving function
    modifier onlyMigrationSource() {
        require(msg.sender == currentMigrationSource(), "NF_INV_SOURCE");
        _;
    }
}
