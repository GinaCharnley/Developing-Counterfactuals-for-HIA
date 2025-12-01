# ====== Convert Monthly GMTA to Annual Weighted Averages ======

# Load required libraries
library(ncdf4)
library(dplyr)
library(tidyr)
library(lubridate)

# ------------------------------
# 1. Open the NetCDF file
# ------------------------------
nc <- nc_open("gmta/Land_and_Ocean_LatLong1.nc")

# ------------------------------
# 2. Extract coordinate and time variables 
# ------------------------------
lon <- ncvar_get(nc, "longitude")
lat <- ncvar_get(nc, "latitude")
time <- ncvar_get(nc, "time")  # File is in decimal years like 1980.042

# ------------------------------
# 3. Define subset bounds 
# ------------------------------
lon_idx <- which(lon >= 76 & lon <= 78)
lat_idx <- which(lat >= 28 & lat <= 30)
time_idx <- which(time >= 1920 & time <= 2025)

lon_sub <- lon[lon_idx]
lat_sub <- lat[lat_idx]
time_sub <- time[time_idx]

# ------------------------------
# 4. Extract temperature anomaly subset 
# ------------------------------
temp_array <- ncvar_get(nc, "temperature",
                        start = c(min(lon_idx), min(lat_idx), min(time_idx)),
                        count = c(length(lon_idx), length(lat_idx), length(time_idx)))

nc_close(nc)

# ------------------------------
# 5 Convert to data frame
# ------------------------------
df <- expand.grid(
  lon = lon_sub,
  lat = lat_sub,
  time = time_sub
)

df$temperature_anomaly <- as.vector(temp_array)
df_clean <- df %>% drop_na(temperature_anomaly)

# ------------------------------
# 6. Add year and month columns from decimal year
# ------------------------------
df_clean <- df_clean %>%
  mutate(
    year = floor(time),
    month = floor((time - year) * 12) + 1
  )

# ------------------------------
# 6b. Compute annual weighted averages
# ------------------------------
df_clean <- df_clean %>%
  # Add number of days in the month for weighting
  mutate(
    days_in_month = days_in_month(ymd(paste(year, month, 1, sep = "-")))
  )

# Compute weighted annual averages for each lon-lat
annual_df <- df_clean %>%
  group_by(lon, lat, year) %>%
  summarise(
    temperature_anomaly_annual = sum(temperature_anomaly * days_in_month) / sum(days_in_month),
    .groups = "drop"
  )

# ------------------------------
# 7. Save as CSV
# ------------------------------
write.csv(annual_df, "gmta/anomalies.csv", row.names = FALSE)


























