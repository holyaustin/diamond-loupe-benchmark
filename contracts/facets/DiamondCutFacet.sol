// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract DiamondCutFacet is IDiamondCut {
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {
        LibDiamond.enforceIsContractOwner();

        for (uint256 i = 0; i < _diamondCut.length; ) {
            _applyFacetCut(_diamondCut[i]);
            unchecked { i++; }
        }

        if (_init != address(0)) {
            (bool success, ) = _init.call(_calldata);
            require(success, "DiamondCutFacet: _init call failed");
        }
    }

    function _applyFacetCut(FacetCut calldata _facetCut) internal {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        address facet = _facetCut.facetAddress;
        bytes4[] memory selectors = _facetCut.functionSelectors;
        uint256 numSelectors = selectors.length;

        if (_facetCut.action == FacetCutAction.Add) {
            require(facet != address(0), "DiamondCutFacet: Add with zero address");
            for (uint256 i = 0; i < numSelectors; ) {
                bytes4 sel = selectors[i];
                require(ds.facetAndPosition[sel].facet == address(0), "DiamondCutFacet: Function exists");
                ds.facetAndPosition[sel] = LibDiamond.FacetAndPosition(facet, uint16(ds.selectors.length));
                ds.selectors.push(sel);
                unchecked { i++; }
            }
        } else if (_facetCut.action == FacetCutAction.Replace) {
            require(facet != address(0), "DiamondCutFacet: Replace with zero address");
            for (uint256 i = 0; i < numSelectors; ) {
                bytes4 sel = selectors[i];
                require(ds.facetAndPosition[sel].facet != address(0), "DiamondCutFacet: Replace nonexistent function");
                ds.facetAndPosition[sel].facet = facet;
                unchecked { i++; }
            }
        } else if (_facetCut.action == FacetCutAction.Remove) {
            require(facet == address(0), "DiamondCutFacet: Remove with non-zero address");
            for (uint256 i = 0; i < numSelectors; ) {
                bytes4 sel = selectors[i];
                uint256 idx = ds.facetAndPosition[sel].position;
                uint256 lastIdx = ds.selectors.length - 1;
                bytes4 lastSel = ds.selectors[lastIdx];
                ds.selectors[idx] = lastSel;
                ds.facetAndPosition[lastSel].position = uint16(idx);
                delete ds.facetAndPosition[sel];
                ds.selectors.pop();
                unchecked { i++; }
            }
        }
    }
}
