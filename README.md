# synthpop-fl
Code to generate synthetic population for Florida to be used for an agent-based model. Current version is 3.1.

# Usage
The code depends specifically on a library `abmgravity` that is not available on CRAN. To install that package:
```
devtools::install_github("kokbent/abmgravity")
```

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

## Detailed explanation of config parameter
`target_county` County name of subpopulation of interest or for statewide synthpop, use `Florida` or `All`.
`output_name` Controls the output SQLITE and TGZ file names (see output section). Required for PUMA synthpop, default to `target_county` if parameter unspecified in County/statewide synthpop.
`extracurricular` Toggle for extracurricular activity. 0 = No, 1 = Yes.
`use_statewide_census` Controls if Households and Persons in the synthpop are sampled from the corresponding area (0; more geographically uneven) or from statewide population (1). 
`data_folder` "Prefix" of the paths.
`path_county_shape` Path to ESRI shapefile for counties, source: FGDL.
`path_cenblock_shape` Path to ESRI shapefile for census block group, source: FGDL.
`path_centract_puma` Path to relationship data frame (CSV) between census tract and PUMA (Public User Microdata Area), source: US Census.
`path_ipums_xml` Path to XML file for IPUMS data extract, provided by IPUMS.
`path_ipums_dat` Path to DAT file for IPUMS data extract, provided by IPUMS.
`path_hhdens_raster` Path to US household density raster (TIFF), source: SEDAC CIESIN.
`path_wac_shape` Path to ESRI shapefile for Work Area Characteristic (WAC) data by census block, source: FGDL.
`path_naics_size` Path to data frame (CSV) of US distribution of number of employees per NAICS code, source: BLS.
`path_naics_lookup` Path to data frame (CSV) of relationship between NAICS 2017 and 2012, source: ???.
`path_workplace` Path to data frame (CSV) of lat long of workplaces, their NAICS code and their "essential" status, source: NCD.
`path_nh` Path to data frame (CSV) of nursing homes (including lat long and size), source: FL AHCA.
`path_schools_shape` Path to ESRI shapefile of schools, source: FGDL.
`path_col_uni_size` Path to data frame (CSV) of "college/university" in the school file, containing their purported sizes, source: Google search by hand.
`path_hf` Path to data frame (TSV or CSV) of health facilities (hospital), containing their size and lat long, source: FL AHCA.
`path_brfss` Path to data frame (CSV) of processed BRFSS data, containing sex, age group, county and probability of having one or more COVID-19 underlying condition, source: BRFSS plus some data wrangling.
`path_patterns` Path to data frame (CSV) of processed safegraph data, containing prepandemic (Jan and Feb 2020) average raw number of visits to POI (point of interests) that are part of "extracurricular" activity in the ABM with either high (H) or low (L) transmission risk, source: Safegraph plus some data wrangling.

# Output
The code automatically create a `.tgz` file named as `sim_pop-<county/output name>-<version>`. This `.tgz` file contains a `sqlite` database. You can run the `extract_sqlite-<version>.R` script located inside the `synth/` folder to extract four text files that are used as input to the ABM. The `.tgz` file must be in the same folder as the extract script. Example:
```
Rscript extract_sqlite-3.0.R sim_pop-escambia-3.0.tgz
```
You then get a folder called `sim_pop-escambia` which contains four `.txt` files.

#
