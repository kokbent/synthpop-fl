# synthpop-fl
Code to generate synthetic population for Florida to be used for an agent-based model.

# Usage
To generate statewide or ONE county specific population:
```
Rscript gen_dataset_for_synth.R config.json
Rscript create_synthpop.R
```

To generate population for one or multiple PUMA(s):
```
Rscript gen_dataset_for_synth.R config_puma.json
Rscript create_synthpop.R
```

# Config
`config.json` is an example on how to setup for statewide/county synthpop generation. The configuration file contains list of paths to retrieve FL dataset required for synthpop generation. Specifically, one can change `target_county` according to which county they want. Default is `Escambia`. If the value is `Florida` or `All`, the script will generate statewide population.

`config_puma.json` is an example on how to setup for one or more PUMA(s) synthpop generation. The configuration file contains list of paths like `config.json`. Specify `target_puma` in square bracket to generate synthpop for those PUMAs. Default is a list of PUMAs that cover the whole of Miami-Dade and Monroe county.
