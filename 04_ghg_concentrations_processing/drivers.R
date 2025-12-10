# ============================================================
# Drivers and emissions data processing
# ============================================================

# In order to attribute health outcomes to fossil fuel and greenhouse gas emissions, 
# these must be incorporated into your counterfactuals. 
# You cannot simply take the difference in the observed vs the counterfactual (based solely on GMTA)
# to be attributable to emissions. 
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

Mauna_Loa_CH4 <- read_csv("Mauna_Loa_CH4.csv")
Mauna_Loa_CO2 <- read_csv("Mauna_Loa_CO2.csv")
Mauna_Loa_N2O <- read_csv("Mauna_Loa_N2O.csv")

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

Law_Dome_ice_cores <- read_excel("Law_Dome_ice_cores.xlsx", 
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

write.csv(Law_Dome_ice_cores, "cores.csv")
write.csv(all_concen, "noaa.csv")

## EMISSIONS & LAND-USE 

# Emissions relates to the flow of greenhouse gas released over a period in GtCO₂/year 
# This will give you information regarding anthropogenic activity 
# It also means you can attribute to a specific emitter 

# For land use it is not possible to use directly a land use dataset 
# These give you extent or change but not the greenhouse gas emissions released due to this change 
# To go from land use extent/change to emission you would need to model the carbon stock change
# This matter for your β₃ term in the counterfactual, 
# which is meant to capture the climate response to land-use driven forcing

# Here, I have selected and processed the following datasets: 
# CEDS (Community Emissions Data System): https://zenodo.org/records/4741285
# It has global historical gridded emissions since 1750 in kt
# I have only downloaded the global sets but it also has data by country 
# It offers emissions for the following pollutants: 

# SO₂
# Sulfur dioxide
# From burning coal/oil, smelting; causes acid rain, cooling via aerosols.
# NOₓ
# Nitrogen oxides (NO + NO₂)
# From combustion (vehicles, power plants); contributes to smog, ozone formation, acid rain.
# BC
# Black carbon
# Soot from incomplete combustion; absorbs sunlight, warms atmosphere, darkens snow/ice.
# OC
# Organic carbon
# Carbon-containing aerosols from combustion/biogenic sources; some cooling effect.
# NH₃
# Ammonia
# From agriculture (fertilizers, livestock); forms fine particulate matter with acids.
# NMVOC
# Non‑methane volatile organic compounds
# Organic gases (e.g., isoprene, benzene) that exclude methane; contribute to ozone formation.
# CO
# Carbon monoxide
# From incomplete combustion; toxic gas, also affects methane lifetime.
# CO₂
# Carbon dioxide
# Main long‑lived greenhouse gas from fossil fuels and land‑use change.
# CH₄
# Methane
# Potent greenhouse gas from agriculture, fossil fuels, waste; also ozone precursor.
# N₂O
# Nitrous oxide
# Greenhouse gas from agriculture, industry; also depletes stratospheric ozone.

# Here I am only going to process NOx, NMVOC, CO2, CH4, N2O
# Either because they are a greenhouse gas or relates to ozone depletion 

ceds_files <- list.files()
ceds_data <- read_csv(ceds_files)

ceds_totals <- ceds_data %>%
  group_by(em) %>%
  summarise(
    across(starts_with("X"), sum, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  # reshape to long format
  pivot_longer(
    cols = starts_with("X"),
    names_to = "year",
    values_to = "value"
  ) %>%
  mutate(
    year = as.numeric(sub("X", "", year))  
  )

ceds_totals <- ceds_totals %>% spread(em, value)

# Global Carbon Budget: https://globalcarbonbudget.org/carbonbudget2023/ 
# Includes fossil fuel + land‑use emissions since 1750
# Not catagorised into separate emitters, but does include overall emissions in GtC/yr

Global_Carbon_Budget_2023v1_1 <- read_excel("Global_Carbon_Budget_2023v1.1.xlsx", 
                                            sheet = "Historical Budget")
all_emitter <- Global_Carbon_Budget_2023v1_1 %>% 
  select(Year, `fossil emissions excluding carbonation`, `land-use change emissions`) %>%
  rename("year" = Year,
         "all_ff_emissions" = `fossil emissions excluding carbonation`,
         "all_lu_emission" = `land-use change emissions`)

all_emitter <- left_join(all_emitter, ceds_totals)

write_csv(all_emitter, "emissions_data.csv")














