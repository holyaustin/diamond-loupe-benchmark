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
        mapping(bytes4 => FacetAndPosition) facetAndPosition;
        bytes4[] selectors;
        address contractOwner;
    }

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);

    function setContractOwner(address _owner) internal {
        diamondStorage().contractOwner = _owner;
    }

    function contractOwner() internal view returns (address) {
        return diamondStorage().contractOwner;
    }

    function enforceIsContractOwner() internal view {
        require(msg.sender == contractOwner(), "LibDiamond: Must be contract owner");
    }
}
