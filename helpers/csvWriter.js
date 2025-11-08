const createCsvWriter = require('csv-writer').createObjectCsvWriter;

const csvWriter = createCsvWriter({
    path: 'loupe_benchmark_results.csv',
    header: [
        {id: 'selectors', title: 'Selectors'},
        {id: 'facets', title: 'Facets'},
        {id: 'func', title: 'Function'},
        {id: 'oldGas', title: 'Old_Gas'},
        {id: 'newGas', title: 'New_Gas'},
        {id: 'gasSaved', title: 'Gas_Saved'},
        {id: 'pctSaved', title: 'Pct_Saved'}
    ]
});

let results = [];

module.exports = {
    addResult: (selectors, facets, func, oldGas, newGas) => {
        const gasSaved = oldGas - newGas;
        const pctSaved = oldGas > 0 ? ((gasSaved / oldGas) * 100).toFixed(2) : 0;
        results.push({
            selectors,
            facets,
            func,
            oldGas,
            newGas,
            gasSaved,
            pctSaved
        });
    },
    save: async () => {
        await csvWriter.writeRecords(results);
        console.log("\n✅ CSV saved: loupe_benchmark_results.csv");
    }
};