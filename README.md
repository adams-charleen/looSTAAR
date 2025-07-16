[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

# looSTAAR

An R package for performing leave-one-out analysis for STAAR models. This package provides functions like `looSTAAR` and `plot_looSTAAR` and includes a vignette (`looSTAAR-guide`) for usage instructions.

## Installation
```R
if (!requireNamespace("devtools", quietly = TRUE)) install.packages("devtools")
library(devtools)
devtools::install_github("adams-charleen/looSTAAR")
library(looSTAAR)
vignette("looSTAAR-guide")
```
