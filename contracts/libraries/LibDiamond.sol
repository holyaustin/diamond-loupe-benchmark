// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {IDiamondCut} from "../interfaces/IDiamondCut.sol";

library LibDiamond {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("compose.diamond");

    struct FacetAndPosition {
        address facet;
        uint16 position;
    }

    struct DiamondStorage {
        address contractOwner;
        mapping(bytes4 => FacetAndPosition) facetAndPosition;
        bytes4[] selectors;
    }

    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function setContractOwner(address _owner) internal {
        DiamondStorage storage ds = diamondStorage();
        ds.contractOwner = _owner;
    }

    function contractOwner() internal view returns (address owner) {
        owner = diamondStorage().contractOwner;
    }

    function enforceIsContractOwner() internal view {
        if (msg.sender != contractOwner()) {
            revert("LibDiamond: Must be contract owner");
        }
    }
}
