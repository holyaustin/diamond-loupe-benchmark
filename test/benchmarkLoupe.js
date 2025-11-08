const { ethers } = require("hardhat");
const csvWriter = require("../helpers/csvWriter");

describe("DiamondLoupeFacet Benchmark", function () {
    this.timeout(0);

    const benchmarks = [
        [40, 20],
        [64, 16],
        [64, 32],
        [64, 64],
        [504, 42],
        [1000, 20], // 20 facets × 50 selectors = 1000
        //[10000, 200] // Optional, scale up if needed
    ];

    let Diamond, DiamondCutFacet, DiamondLoupeFacet_Old, DiamondLoupeFacet_New, DummyFacet;

    before(async () => {
        try {
            console.log("🚀 Loading contract factories...");
            Diamond = await ethers.getContractFactory("Diamond");
            DiamondCutFacet = await ethers.getContractFactory("DiamondCutFacet");
            DiamondLoupeFacet_Old = await ethers.getContractFactory("DiamondLoupeFacet_Old");
            DiamondLoupeFacet_New = await ethers.getContractFactory("DiamondLoupeFacet_New");
            DummyFacet = await ethers.getContractFactory("DummyFacet");
            console.log("✅ All contract factories loaded!");
        } catch (err) {
            console.error("💥 Error loading factories:", err);
            throw err;
        }
    });

    for (const [totalSelectors, numFacets] of benchmarks) {
        it(`should benchmark ${totalSelectors} selectors / ${numFacets} facets`, async function () {
            try {
                console.log(`\n🧪 Benchmark: ${totalSelectors} selectors, ${numFacets} facets`);

                const selectorsPerFacet = Math.max(1, Math.floor(totalSelectors / numFacets));
                const extraSelectors = totalSelectors % numFacets;

                const facetAddresses = [];
                const allSelectors = [];

                // ---------------- Deploy DiamondCutFacet ----------------
                let diamondCutFacet, diamondCutFacetAddress;
                try {
                    diamondCutFacet = await DiamondCutFacet.deploy();
                    diamondCutFacetAddress = await diamondCutFacet.getAddress();
                    console.log("✅ DiamondCutFacet deployed:", diamondCutFacetAddress);
                } catch (err) {
                    console.error("💥 Error deploying DiamondCutFacet:", err);
                    throw err;
                }

                // ---------------- Deploy DummyFacets ----------------
                try {
                    for (let i = 0; i < numFacets; i++) {
                        const facet = await DummyFacet.deploy();
                        const facetAddress = await facet.getAddress();
                        facetAddresses.push(facetAddress);

                        const iface = new ethers.Interface(DummyFacet.interface?.fragments || DummyFacet.interface || DummyFacet.abi);
                        const functions = Object.keys(iface.fragments)
                            .filter(key => iface.fragments[key].type === "function")
                            .map(key => iface.getFunction)
                            .filter(fn => fn);

                        const numToTake = i < extraSelectors ? selectorsPerFacet + 1 : selectorsPerFacet;

                        for (let j = 0; j < numToTake && j < functions.length; j++) {
                            allSelectors.push(iface.getFunction(`func${String(j + 1).padStart(2, "0")}`).selector);
                        }

                        console.log(`✅ DummyFacet #${i + 1} deployed: ${facetAddress} | functions: ${functions.length}`);
                    }
                    console.log(`📊 Total selectors collected: ${allSelectors.length}`);
                } catch (err) {
                    console.error("💥 Error deploying DummyFacets:", err);
                    throw err;
                }

                // ---------------- Deploy Diamond ----------------
                let diamond, diamondAddress;
                try {
                    diamond = await Diamond.deploy(diamondCutFacetAddress);
                    diamondAddress = await diamond.getAddress();
                    console.log("✅ Diamond deployed:", diamondAddress);
                } catch (err) {
                    console.error("💥 Error deploying Diamond:", err);
                    throw err;
                }

                // ---------------- Perform diamondCut ----------------
                try {
                    const diamondCut = facetAddresses.map((addr, i) => {
                        const start = i * selectorsPerFacet + Math.min(i, extraSelectors);
                        const end = (i + 1) * selectorsPerFacet + Math.min(i + 1, extraSelectors);
                        return {
                            facetAddress: addr,
                            action: 0, // Add
                            functionSelectors: allSelectors.slice(start, end)
                        };
                    });

                    const diamondCutFacetAttached = DiamondCutFacet.attach(diamondAddress);
                    await diamondCutFacetAttached.diamondCut(diamondCut, ethers.ZeroAddress, "0x");
                    console.log(`✅ diamondCut completed for ${numFacets} facets`);
                } catch (err) {
                    console.error("💥 Error performing diamondCut:", err);
                    throw err;
                }

                // ---------------- Deploy & attach Loupe facets ----------------
                let loupeOld, loupeNew, oldFacet, newFacet;
                try {
                    loupeOld = await DiamondLoupeFacet_Old.deploy();
                    loupeNew = await DiamondLoupeFacet_New.deploy();
                    oldFacet = DiamondLoupeFacet_Old.attach(diamondAddress);
                    newFacet = DiamondLoupeFacet_New.attach(diamondAddress);
                    console.log("✅ Loupe facets deployed and attached");
                } catch (err) {
                    console.error("💥 Error deploying/attaching Loupe facets:", err);
                    throw err;
                }

            } catch (err) {
                console.error("💥 Benchmark failed:", err);
                throw err;
            }
        });
    }

    after(async () => {
        try {
            await csvWriter.save();
            console.log("✅ CSV saved successfully!");
        } catch (err) {
            console.error("💥 Error saving CSV:", err);
            throw err;
        }
    });
});
