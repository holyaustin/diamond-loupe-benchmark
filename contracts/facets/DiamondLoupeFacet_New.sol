// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

contract DiamondLoupeFacet_New {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("compose.diamond");

    struct FacetAndPosition {
        address facet;
        uint16 position;
    }

    struct DiamondStorage {
        mapping(bytes4 => FacetAndPosition) facetAndPosition;
        bytes4[] selectors;
    }

    function getStorage() internal pure returns (DiamondStorage storage s) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    struct Facet {
        address facet;
        bytes4[] functionSelectors;
    }

    /// @notice Returns all facets and their selectors.
    /// @return allFacets_ Array of facets
    ///
    /// Gas Optimization:
    /// - Instead of O(n²) facet lookup, we first collect unique facets in a list
    /// - Count selectors per facet first, then allocate exact-size arrays
    /// - Avoids over-allocation and repeated memory writes
    function facets() external view returns (Facet[] memory allFacets_) {
        DiamondStorage storage s = getStorage();
        uint256 selectorCount = s.selectors.length;

        if (selectorCount == 0) {
            return new Facet[](0);
        }

        // STEP 1: Collect unique facets and count their selectors
        address[] memory tempFacetAddresses = new address[](selectorCount);
        uint256[] memory selectorCounts = new uint256[](selectorCount);
        uint256 facetCount = 0;

        address currentFacet;
        bool found;
        bytes4 selector;

        for (uint256 i = 0; i < selectorCount; ) {
            selector = s.selectors[i];
            currentFacet = s.facetAndPosition[selector].facet;

            // Check if facet already exists
            found = false;
            for (uint256 f = 0; f < facetCount; ) {
                if (tempFacetAddresses[f] == currentFacet) {
                    selectorCounts[f]++;
                    found = true;
                    break;
                }
                unchecked { f++; }
            }

            if (!found) {
                tempFacetAddresses[facetCount] = currentFacet;
                selectorCounts[facetCount] = 1;
                facetCount++;
            }

            unchecked { i++; }
        }

        // STEP 2: Allocate final Facet array with exact size
        allFacets_ = new Facet[](facetCount);
        for (uint256 f = 0; f < facetCount; ) {
            allFacets_[f] = Facet({
                facet: tempFacetAddresses[f],
                functionSelectors: new bytes4[](selectorCounts[f])
            });
            unchecked { f++; }
        }

        // STEP 3: Reset counts to use as write pointers
        for (uint256 f = 0; f < facetCount; ) {
            selectorCounts[f] = 0; // reuse as pointer
            unchecked { f++; }
        }

        // STEP 4: Fill selectors into correct facet arrays
        for (uint256 i = 0; i < selectorCount; ) {
            selector = s.selectors[i];
            currentFacet = s.facetAndPosition[selector].facet;

            for (uint256 f = 0; f < facetCount; ) {
                if (tempFacetAddresses[f] == currentFacet) {
                    uint256 ptr = selectorCounts[f];
                    allFacets_[f].functionSelectors[ptr] = selector;
                    selectorCounts[f] = ptr + 1;
                    break;
                }
                unchecked { f++; }
            }

            unchecked { i++; }
        }
    }

    /// @notice Gets all function selectors supported by a facet.
    /// @param _facet The facet address.
    /// @return facetSelectors_ The function selectors.
    ///
    /// Gas Optimization:
    /// - Pre-counts number of selectors for the facet
    /// - Allocates exact-size memory array
    /// - Avoids over-allocation and manual mstore resizing
    function facetFunctionSelectors(address _facet)
        external
        view
        returns (bytes4[] memory facetSelectors_)
    {
        DiamondStorage storage s = getStorage();
        uint256 selectorCount = s.selectors.length;

        if (selectorCount == 0) {
            return new bytes4[](0);
        }

        // First pass: count how many selectors belong to _facet
        uint256 count = 0;
        for (uint256 i = 0; i < selectorCount; ) {
            bytes4 selector = s.selectors[i];
            if (s.facetAndPosition[selector].facet == _facet) {
                count++;
            }
            unchecked { i++; }
        }

        if (count == 0) {
            return new bytes4[](0);
        }

        // Second pass: copy selectors
        facetSelectors_ = new bytes4[](count);
        uint256 writeIndex = 0;
        for (uint256 i = 0; i < selectorCount; ) {
            bytes4 selector = s.selectors[i];
            if (s.facetAndPosition[selector].facet == _facet) {
                facetSelectors_[writeIndex] = selector;
                writeIndex++;
            }
            unchecked { i++; }
        }
    }

    /// @notice Get all facet addresses used by the diamond.
    /// @return facetAddresses_ The list of facet addresses.
    ///
    /// Gas Optimization:
    /// - Pre-count unique facets to avoid over-allocation
    /// - Uses temporary list + O(n²) check (unavoidable without mappings)
    function facetAddresses() external view returns (address[] memory facetAddresses_) {
        DiamondStorage storage s = getStorage();
        uint256 selectorCount = s.selectors.length;

        if (selectorCount == 0) {
            return new address[](0);
        }

        address[] memory temp = new address[](selectorCount);
        uint256 count = 0;
        address facet;

        for (uint256 i = 0; i < selectorCount; ) {
            facet = s.facetAndPosition[s.selectors[i]].facet;
            bool exists = false;

            for (uint256 j = 0; j < count; ) {
                if (temp[j] == facet) {
                    exists = true;
                    break;
                }
                unchecked { j++; }
            }

            if (!exists) {
                temp[count] = facet;
                count++;
            }

            unchecked { i++; }
        }

        facetAddresses_ = new address[](count);
        for (uint256 i = 0; i < count; ) {
            facetAddresses_[i] = temp[i];
            unchecked { i++; }
        }
    }

    /// @notice Gets the facet address that supports the given selector.
    /// @param _functionSelector The function selector.
    /// @return facet The facet address.
    ///
    /// Already optimal — single SLOAD via mapping
    function facetAddress(bytes4 _functionSelector) external view returns (address facet) {
        DiamondStorage storage s = getStorage();
        facet = s.facetAndPosition[_functionSelector].facet;
    }
}