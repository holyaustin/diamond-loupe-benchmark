// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {LibDiamond} from "./libraries/LibDiamond.sol";
import {IDiamondCut} from "./interfaces/IDiamondCut.sol";

contract Diamond {
    constructor(address _diamondCutFacet) payable {
        // store owner as deployer
        LibDiamond.setContractOwner(msg.sender);

        // register diamondCut selector and point to provided facet
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        bytes4 selector = IDiamondCut.diamondCut.selector;

        // add mapping & selector array
        ds.facetAndPosition[selector] = LibDiamond.FacetAndPosition(_diamondCutFacet, uint16(ds.selectors.length));
        ds.selectors.push(selector);
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
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}
