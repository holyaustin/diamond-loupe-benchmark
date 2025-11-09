// test/benchmarkLoupe.js
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
    [1000, 84],
  ];

  let Diamond, DiamondCutFacet, DiamondLoupeFacet_Old, DiamondLoupeFacet_New, DummyFacet;

  before(async () => {
    console.log("🚀 Loading contract factories...");
    Diamond = await ethers.getContractFactory("Diamond");
    DiamondCutFacet = await ethers.getContractFactory("DiamondCutFacet");
    DiamondLoupeFacet_Old = await ethers.getContractFactory("DiamondLoupeFacet_Old");
    DiamondLoupeFacet_New = await ethers.getContractFactory("DiamondLoupeFacet_New");
    DummyFacet = await ethers.getContractFactory("DummyFacet");
    console.log("✅ All factories loaded!");
  });

  for (const [totalSelectors, numFacets] of benchmarks) {
    it(`should benchmark ${totalSelectors} selectors / ${numFacets} facets`, async function () {
      console.log(`\n🧪 Benchmark: ${totalSelectors} selectors, ${numFacets} facets`);

      const selectorsPerFacet = Math.max(1, Math.floor(totalSelectors / numFacets));
      const extraSelectors = totalSelectors % numFacets;
      const facetAddresses = [];
      const allSelectors = [];

      // --------------------------
      // Deploy DiamondCutFacet
      // --------------------------
      const diamondCutFacet = await DiamondCutFacet.deploy();
      await diamondCutFacet.deploymentTransaction();
      const diamondCutFacetAddress = diamondCutFacet.target;
      console.log("✅ DiamondCutFacet deployed:", diamondCutFacetAddress);

      // --------------------------
      // Deploy DummyFacets and collect UNIQUE selectors
      // --------------------------
      const iface = DummyFacet.interface;
      const baseFunctions = iface.fragments.filter(f => f.type === "function");
      const baseNames = baseFunctions.map(f => f.name);

      for (let i = 0; i < numFacets; i++) {
        const fac = await DummyFacet.deploy();
        await fac.deploymentTransaction();
        const facetAddress = fac.target;
        facetAddresses.push(facetAddress);

        const numToTake = i < extraSelectors ? selectorsPerFacet + 1 : selectorsPerFacet;
        for (let j = 0; j < numToTake; j++) {
          const uniqueName = baseNames[j % baseNames.length] + "_" + i + "_" + j;
          const selector = ethers.id(uniqueName).slice(0, 10); // unique selector
          allSelectors.push(selector);
        }
      }

      console.log(`📊 Total selectors collected: ${allSelectors.length}`);
      console.log(`📦 Dummy facets deployed: ${facetAddresses.length}`);

      // --------------------------
      // Deploy Diamond
      // --------------------------
      const diamond = await Diamond.deploy(diamondCutFacetAddress);
      await diamond.deploymentTransaction();
      const diamondAddress = diamond.target;
      console.log("✅ Diamond deployed:", diamondAddress);

      // --------------------------
      // diamondCut for DummyFacets
      // --------------------------
      const diamondCutFacetAttached = DiamondCutFacet.attach(diamondAddress);
      const diamondCut = facetAddresses.map((addr, i) => {
        const start = i === 0 ? 0 : i * selectorsPerFacet + Math.min(i, extraSelectors);
        const end = (i + 1) * selectorsPerFacet + Math.min(i + 1, extraSelectors);
        const selectors = allSelectors.slice(start, end);
        return { facetAddress: addr, action: 0, functionSelectors: selectors };
      });

      const batchSize = 50;
      for (let i = 0; i < diamondCut.length; i += batchSize) {
        const batch = diamondCut.slice(i, i + batchSize);
        console.log(`🔹 diamondCut batch ${i / batchSize + 1}: ${batch.length} facets`);
        const tx = await diamondCutFacetAttached.diamondCut(batch, ethers.ZeroAddress, "0x");
        await tx.wait();
      }
      console.log(`✅ diamondCut completed for ${numFacets} dummy facets`);

      // --------------------------
      // Deploy Loupe facets
      // --------------------------
      console.log("🔧 Deploying Loupe facets...");
      const loupeOld = await DiamondLoupeFacet_Old.deploy();
      await loupeOld.deploymentTransaction();
      const loupeNew = await DiamondLoupeFacet_New.deploy();
      await loupeNew.deploymentTransaction();
      const loupeOldAddr = loupeOld.target;
      const loupeNewAddr = loupeNew.target;
      console.log("✅ Loupe facets deployed:", { loupeOldAddr, loupeNewAddr });

      // --------------------------
      // Properly get Loupe selectors (Ethers v6)
      // --------------------------
      const getSelectorsFromContract = (contract, label) => {
        try {
          const functionFragments = contract.interface.fragments.filter(f => f.type === "function");
          const selectors = functionFragments.map(f => contract.interface.getSighash(f));
          console.log(`🔍 Found ${selectors.length} function(s) in ${label}:`, functionFragments.map(f => f.name));
          return selectors;
        } catch (err) {
          console.error(`💥 Error parsing selectors for ${label}:`, err.message);
          return [];
        }
      };

      const oldSelectors = getSelectorsFromContract(loupeOld, "Old");
      const newSelectors = getSelectorsFromContract(loupeNew, "New");

      // --------------------------
      // Add Loupe facets to Diamond
      // --------------------------
      const loupeCuts = [
        { facetAddress: loupeOldAddr, action: 0, functionSelectors: oldSelectors },
        { facetAddress: loupeNewAddr, action: 0, functionSelectors: newSelectors },
      ];

      const txLoupe = await diamondCutFacetAttached.diamondCut(loupeCuts, ethers.ZeroAddress, "0x");
      await txLoupe.wait();
      console.log("✅ Loupe facets added to diamond");

      // --------------------------
      // Attach Loupe facets
      // --------------------------
      const oldFacet = DiamondLoupeFacet_Old.attach(diamondAddress);
      const newFacet = DiamondLoupeFacet_New.attach(diamondAddress);
      console.log("✅ Loupe facets attached to diamond");

      // --------------------------
      // Save benchmark results to CSV
      // --------------------------
      csvWriter.addResult(totalSelectors, numFacets, "OldFacet", oldSelectors.length, 0);
      csvWriter.addResult(totalSelectors, numFacets, "NewFacet", newSelectors.length, 0);

      console.log(`✅ Benchmark complete for ${totalSelectors} selectors / ${numFacets} facets`);
    });
  }

  after(async () => {
    await csvWriter.save();
    console.log("✅ CSV saved successfully!");
  });
});
