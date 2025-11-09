// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract DiamondCutFacet is IDiamondCut {
    /// @notice diamondCut applies changes to diamond facets
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {
        LibDiamond.enforceIsContractOwner();

        // process each facet cut
        for (uint256 i = 0; i < _diamondCut.length; ) {
            _processFacetCut(_diamondCut[i]);
            unchecked { i++; }
        }

        // call init if provided
        if (_init != address(0)) {
            (bool success, ) = _init.call(_calldata);
            require(success, "DiamondCutFacet: _init call failed");
        }

        emit LibDiamond.DiamondCut(_diamondCut, _init, _calldata);
    }

    function _processFacetCut(FacetCut calldata _facetCut) internal {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        address facet = _facetCut.facetAddress;
        bytes4[] memory functionSelectors = _facetCut.functionSelectors;
        uint256 numSelectors = functionSelectors.length;

        if (_facetCut.action == FacetCutAction.Add) {
            require(facet != address(0), "DiamondCutFacet: Add with zero address");
            for (uint256 i = 0; i < numSelectors; ) {
                bytes4 sel = functionSelectors[i];
                address old = ds.facetAndPosition[sel].facet;
                require(old == address(0), "DiamondCutFacet: Can't add function that already exists");
                ds.facetAndPosition[sel] = LibDiamond.FacetAndPosition(facet, uint16(ds.selectors.length));
                ds.selectors.push(sel);
                unchecked { i++; }
            }
        } else if (_facetCut.action == FacetCutAction.Replace) {
            require(facet != address(0), "DiamondCutFacet: Replace with zero address");
            for (uint256 i = 0; i < numSelectors; ) {
                bytes4 sel = functionSelectors[i];
                address old = ds.facetAndPosition[sel].facet;
                require(old != address(0), "DiamondCutFacet: Can't replace nonexistent function");
                ds.facetAndPosition[sel].facet = facet;
                unchecked { i++; }
            }
        } else if (_facetCut.action == FacetCutAction.Remove) {
            require(facet == address(0), "DiamondCutFacet: Remove with non-zero address");
            for (uint256 i = 0; i < numSelectors; ) {
                bytes4 sel = functionSelectors[i];
                uint256 index = ds.facetAndPosition[sel].position;
                uint256 lastIndex = ds.selectors.length - 1;
                bytes4 lastSelector = ds.selectors[lastIndex];
                ds.selectors[index] = lastSelector;
                ds.facetAndPosition[lastSelector].position = uint16(index);
                delete ds.facetAndPosition[sel];
                ds.selectors.pop();
                unchecked { i++; }
            }
        }
    }
}
