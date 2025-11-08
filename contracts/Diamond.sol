// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {LibDiamond} from "./libraries/LibDiamond.sol";

contract Diamond {
    constructor(address _diamondCutFacet) payable {
        // Set deployer as owner
        LibDiamond.setContractOwner(msg.sender);
        (bool success, ) = _diamondCutFacet.call("");
        require(success, "Diamond: Facet init failed");
        // DiamondCutFacet will be attached later via diamondCut
    }


    fallback() external payable {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        address facet = ds.facetAndPosition[msg.sig].facet;
        require(facet != address(0), "Diamond: Function does not exist");

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    receive() external payable {}
}
