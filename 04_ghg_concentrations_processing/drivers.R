# ============================================================
# GHG Concentraion Data Processing
# ============================================================

# In order to attribute health outcomes to fossil fuel and greenhouse gas concentrations, 
# these must be incorporated into your counterfactuals. 
# You cannot simply take the difference in the observed vs the counterfactual (based solely on GMTA)
# to be attributable to greenhouse gases. 
# Here I process a range of driver datasets, to complete what I believe is the best available data 

# Load packages 
library(readr)
library(tidyr)
library(dplyr)
library(purrr)

## CONCENTRATIONS 

# Concentration is the stock of greenhouse gas already in the atmosphere in ppm 
# This will therefore give you information related to climate forcing 
# Modern concentration datasets do not go back to the pre-industrial era 
# Therefore, you need to use a combination and stitch them together 

# First you can take the modern one, here I use perhaps the most well known one
# The Mauna Loa record (https://gml.noaa.gov/ccgg/trends/data.html)
# This provides global monthly estimates: 
# CO₂ from March 1958 in ppm 
# N₂O from January 2001 in ppb
# CH₄ from July 1983 in ppb 
# CO₂ is provided as an average and de-seasonalised 
# Select the de-seasonal option, as you are interested in long-term trends 
# CO₂ in the atmosphere isn’t perfectly constant through the year — 
# it rises and falls mainly due to plants growing and decaying.

Mauna_Loa_CH4 <- read_csv("04_ghg_concentrations_processing/raw/Mauna_Loa_CH4.csv")
Mauna_Loa_CO2 <- read_csv("04_ghg_concentrations_processing/raw/Mauna_Loa_CO2.csv")
Mauna_Loa_N2O <- read_csv("04_ghg_concentrations_processing/raw/Mauna_Loa_N2O.csv")

Mauna_Loa_CO2$year <- gsub(";", "", Mauna_Loa_CO2$`ye;ar`)
Mauna_Loa_CO2 <- Mauna_Loa_CO2 %>% select(year, month, deseasonalized) %>% 
  rename("conc_co2" = deseasonalized)

Mauna_Loa_CH4$year <- gsub(";", "", Mauna_Loa_CH4$`ye;ar`)
Mauna_Loa_CH4 <- Mauna_Loa_CH4 %>% select(year, month, average) %>% 
  rename("conc_ch4" = average)

Mauna_Loa_N2O$year <- gsub(";", "", Mauna_Loa_N2O$`ye;ar`)
Mauna_Loa_N2O <- Mauna_Loa_N2O %>% select(year, month, average) %>% 
  rename("conc_n2o" = average)

all_concen <- full_join(Mauna_Loa_CO2, Mauna_Loa_CH4, Mauna_Loa_N2O)
all_concen$year <- as.numeric(all_concen$year)

# For the pre-modern concentrations you need to rely on ice core data 
# Here I use Law Dome ice cores, which are high‑resolution concentraions back to ~1000 CE from Antarctica
# https://www.ncei.noaa.gov/access/metadata/landing-page/bin/iso?id=noaa-icecore-9959

Law_Dome_ice_cores <- read_excel("04_ghg_concentrations_processing/raw/Law_Dome_ice_cores.xlsx", 
                                 sheet = "SplineFit20yr")

Law_Dome_ice_cores <- Law_Dome_ice_cores %>% 
  select(`Year AD...1`, `CH4 Spline (ppb)`, `CO2 Spline (ppm)`, `N2O Spline (ppb)`) %>% 
  rename("year" = `Year AD...1`, 
         "conc_ch4" = `CH4 Spline (ppb)`, 
         "conc_co2" = `CO2 Spline (ppm)`,
         "conc_n2o" = `N2O Spline (ppb)`)

ld_co2 <- Law_Dome_ice_cores %>% select(year, conc_co2)
ld_co2 <- ld_co2 %>%
  mutate(month = list(1:12)) %>%
  unnest(month)
ld_co2 <- ld_co2 %>% filter(year <= 1958) 
ld_co2 <- ld_co2[1:(nrow(ld_co2) - 10), ]

ld_ch4 <- Law_Dome_ice_cores %>% select(year, conc_ch4)
ld_ch4 <- ld_ch4 %>%
  mutate(month = list(1:12)) %>%
  unnest(month)
ld_ch4 <- ld_ch4 %>% filter(year <= 1983) 
ld_ch4 <- ld_ch4[1:(nrow(ld_ch4) - 6), ]

ld_n2o <- Law_Dome_ice_cores %>% select(year, conc_n2o)
ld_n2o <- ld_n2o %>%
  mutate(month = list(1:12)) %>%
  unnest(month)
ld_n2o <- ld_n2o %>% filter(year <= 2000) 

Law_Dome_ice_cores <- full_join(ld_ch4, ld_co2, ld_n2o)

# Merge and save as one file
concentrations <- rbind(Law_Dome_ice_cores, all_concen)

write.csv(concentrations, "04_ghg_concentrations_processing/concentration_data.csv")







