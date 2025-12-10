# ============================================================
# Synthetic Climate Data Creation
# ============================================================

library(dplyr)
library(ggplot2)
library(lubridate)
library(zoo)

# ====== Synthetic Long-term Temperature Data ====== 

# To reduce computational time the data is subset to 1920-2025 and to Delhi, India

# ------------------------------
# 1. Define the parameters
# ------------------------------
set.seed(123)

# Time setup (~100 years: 1920–2025)
start_year <- 1920
end_year <- 2025
years <- seq(start_year, end_year, by = 1)
months <- 1:12
n_months <- length(years) * length(months)
time <- 1:n_months

# Spatial extent for Delhi region (1° grid)
lat_seq <- seq(28.5, 29.5, by = 1)
lon_seq <- seq(76.5, 77.5, by = 1)
grid <- expand.grid(lat = lat_seq, lon = lon_seq)

# ------------------------------
# 2. Define temperature components
# ------------------------------
# 1. Long-term warming trend (~1.2°C over 100 years → scaled for 50 years)
warming_rate <- 1.2 / 100  # 1.2°C per century
trend <- warming_rate * (time / 12)  # convert months to years

# 2. Seasonal cycle (sinusoidal, amplitude = 10°C)
seasonal_amp <- 10
seasonal_cycle <- seasonal_amp * sin(2 * pi * (months[(time - 1) %% 12 + 1]) / 12)

# 3. AR(1) noise for temporal autocorrelation
phi <- 0.6
noise <- numeric(n_months)
noise[1] <- rnorm(1, 0, 1.5)
for (i in 2:n_months) {
  noise[i] <- phi * noise[i - 1] + sqrt(1 - phi^2) * rnorm(1, 0, 1.5)
}

# ------------------------------
# 3. Spatial base temperature
# ------------------------------
# Simple heuristic for Delhi:
# ~20–35°C range, minor spatial variation

grid$base_temp <- 30 - 0.3 * (grid$lat - 28) + 
  (-1.5 * exp(-((grid$lat - 28.5)^2 + (grid$lon - 77)^2)/0.5)) +  # slightly cooler center
  rnorm(nrow(grid), 0, 0.5)  # local small-scale noise

# ------------------------------
# 4. Combine time × space
# ------------------------------
# Create temporal structure
dates <- seq.Date(from = as.Date(paste0(start_year, "-01-01")),
                  to = as.Date(paste0(end_year, "-12-01")),
                  by = "month")

time_df <- data.frame(
  date = dates,
  year = as.numeric(format(dates, "%Y")),
  month = as.numeric(format(dates, "%m")),
  trend = trend,
  seasonal = seasonal_cycle,
  noise = noise
)

# Cartesian join: each grid cell × each time step
temp_df <- merge(grid, time_df, all = TRUE)

# Compute final temperature
temp_df$temperature <- temp_df$base_temp + temp_df$trend +
  temp_df$seasonal + temp_df$noise

# ------------------------------
# 5. Save to file
# ------------------------------
temp_df <- temp_df %>% select(lat, lon, year, month, temperature)
write.csv(temp_df, "02_synthetic_climate_data_generation/temperature.csv", row.names = FALSE)

# ====== Synthetic Long-term Precipitation & Humidity Data ======

# ------------------------------
# 1. Define parameters
# ------------------------------
set.seed(456)  # Different seed from temperature for independence

# Time setup (~100 years: 1920–2025)
start_year <- 1920
end_year <- 2025
years <- seq(start_year, end_year, by = 1)
months <- 1:12
n_months <- length(years) * length(months)
time <- 1:n_months

# Spatial extent for Delhi region (0.1° grid)
lat_seq <- seq(28.5, 29.5, by = 1)
lon_seq <- seq(76.5, 77.5, by = 1)
grid <- expand.grid(lat = lat_seq, lon = lon_seq)

# ------------------------------
# 2. Precipitation (mm/month)
# ------------------------------

# Base level and long-term trend
base_precip <- 80
precip_rate <- base_precip * 0.01 / 10  # 1% per decade → per year
trend_precip <- precip_rate * (time / 12)

# Seasonal cycle (monsoon-influenced: peak ~July)
seasonal_amp_precip <- 40
seasonal_cycle_precip <- seasonal_amp_precip * sin(2 * pi * (months[(time - 1) %% 12 + 1]) / 12 + pi/3)

# AR(1) noise
noise_precip <- rnorm(n_months, mean = 0, sd = 20)
phi_p <- 0.5
for (i in 2:n_months) {
  noise_precip[i] <- phi_p * noise_precip[i - 1] + sqrt(1 - phi_p^2) * rnorm(1, 0, 20)
}

# ------------------------------
# 3. Relative Humidity (%)
# ------------------------------

base_humidity <- 75
humidity_decline_rate <- -0.5 / 100  # -0.5% per century → scaled
trend_humidity <- humidity_decline_rate * (time / 12)

seasonal_amp_hum <- 8
seasonal_cycle_hum <- -seasonal_amp_hum * sin(2 * pi * (months[(time - 1) %% 12 + 1]) / 12)

noise_hum <- rnorm(n_months, mean = 0, sd = 2)
phi_h <- 0.4
for (i in 2:n_months) {
  noise_hum[i] <- phi_h * noise_hum[i - 1] + sqrt(1 - phi_h^2) * rnorm(1, 0, 2)
}

# ------------------------------
# 4. Create temporal dataframe
# ------------------------------
dates <- seq.Date(from = as.Date(paste0(start_year, "-01-01")),
                  to = as.Date(paste0(end_year, "-12-01")),
                  by = "month")

time_df <- data.frame(
  date = dates,
  year = as.numeric(format(dates, "%Y")),
  month = as.numeric(format(dates, "%m")),
  trend_precip = trend_precip,
  seasonal_precip = seasonal_cycle_precip,
  noise_precip = noise_precip,
  trend_hum = trend_humidity,
  seasonal_hum = seasonal_cycle_hum,
  noise_hum = noise_hum
)

# ------------------------------
# 5. Combine spatial × temporal
# ------------------------------
temp_precip_df <- merge(grid, time_df, all = TRUE)

# Compute final values
temp_precip_df$precipitation_mm <- pmax(base_precip + 
                                          temp_precip_df$trend_precip +
                                          temp_precip_df$seasonal_precip +
                                          temp_precip_df$noise_precip, 0)

temp_precip_df$humidity_percent <- pmin(pmax(base_humidity + 
                                               temp_precip_df$trend_hum +
                                               temp_precip_df$seasonal_hum +
                                               temp_precip_df$noise_hum, 20), 100)

# ------------------------------
# 6. Save to CSV
# ------------------------------
precipitation <- temp_precip_df %>% select(lat, lon, year, month, precipitation_mm)
humidity <- temp_precip_df %>% select(lat, lon, year, month, humidity_percent)

write.csv(precipitation, "02_synthetic_climate_data_generation/precipitation.csv")
write.csv(humidity, "02_synthetic_climate_data_generation/humidity.csv")

# ====== Synthetic Climate Data with Multiple Heatwaves ====== 

set.seed(1234)

# ------------------------------
# 1. Generate baseline daily temperatures (2010-2019)
# ------------------------------
dates <- seq(as.Date("2010-01-01"), as.Date("2019-12-31"), by = "day")
n <- length(dates)
doy <- yday(dates)
year <- year(dates)

# Seasonal pattern (annual + semiannual)
omega <- 2 * pi / 365.25
seasonal <- 10 * sin(omega * doy - 0.3) + 3 * cos(2 * omega * doy + 1.1)

# Small warming trend over 10 years (~0.4 °C)
trend <- 0.04 * ((1:n) / 365.25)

# Base mean and random noise
baseline <- 15
noise <- rnorm(n, sd = 2)

temp <- baseline + seasonal + trend + noise

df <- data.frame(date = dates, temp = temp)

# ------------------------------
# 2. Insert multiple artificial heatwaves
# ------------------------------
insert_heatwave <- function(df, start_date, duration, peak_anomaly) {
  hw_days <- seq(as.Date(start_date), by = "day", length.out = duration)
  if (max(hw_days) > max(df$date)) return(df)
  # smooth bump anomaly
  anomaly <- seq(0, 1, length.out = duration)
  anomaly <- sin(pi * anomaly) * peak_anomaly
  df$temp[df$date %in% hw_days] <- df$temp[df$date %in% hw_days] + anomaly
  df$is_forced_heatwave[df$date %in% hw_days] <- TRUE
  return(df)
}

df$is_forced_heatwave <- FALSE

# Randomly generate ~2 heatwaves per year in summer (June–August)
years <- unique(year)
for (yr in years) {
  n_hw <- sample(1:3, 1)  # 1–3 heatwaves per year
  for (i in 1:n_hw) {
    start_day <- sample(150:240, 1)  # roughly June–August
    duration <- sample(5:14, 1)
    peak <- runif(1, 5, 12)
    df <- insert_heatwave(df, as.Date(paste0(yr, "-01-01")) + start_day, duration, peak)
  }
}

# ------------------------------
# 3. Detect heatwaves (≥3 consecutive days above 90th percentile)
# ------------------------------
df$doy <- yday(df$date)

# Day-of-year 90th percentile climatology
clim90 <- df %>%
  group_by(doy) %>%
  summarize(thresh90 = quantile(temp, 0.9))

df <- left_join(df, clim90, by = "doy") %>%
  mutate(above90 = temp > thresh90)

# Identify consecutive sequences
rle_above <- rle(df$above90)
group_id <- rep(seq_along(rle_above$lengths), times = rle_above$lengths)
df$group <- group_id

# Flag heatwave groups (≥3 consecutive above90 days)
heatwave_groups <- df %>%
  group_by(group) %>%
  summarize(is_hw = all(above90) & n() >= 3)

df <- left_join(df, heatwave_groups, by = "group")
df$is_heatwave <- ifelse(is.na(df$is_hw), FALSE, df$is_hw)
df$is_heatwave[df$is_forced_heatwave] <- TRUE  # ensure inserted ones are marked
df <- df %>% select(-is_hw)

# ------------------------------
# 4. Process additional variables related to temperature
# ------------------------------

# Water vapour (g/kg)
# Typically increases with temperature
df$q <- 5 + 0.3 * df$temp + rnorm(n, sd = 1)  # simple linear relation
df$q <- pmax(df$q, 0.1)  # no negative values

# Daily precipitation (mm/day)
# Heatwaves suppress normal rainfall
df$P_mean <- rnorm(n, mean = 2, sd = 3)
df$P_mean[df$P_mean < 0] <- 0
df$P_mean[df$is_heatwave] <- df$P_mean[df$is_heatwave] * runif(sum(df$is_heatwave), 0, 0.5)

# Precipitation extremes (mm/day)
# Random extreme events, rare, independent of normal precipitation
df$P_extreme <- rbinom(n, 1, 0.02) * runif(n, 20, 100)  # 2% chance

# CAPE (J/kg)
# Correlates with temperature and humidity
df$CAPE <- pmax(0, rnorm(n, mean = 500 + 10 * (df$temp - 15) + 5 * (df$q - 10), sd = 200))
df$CAPE[df$is_heatwave] <- df$CAPE[df$is_heatwave] * runif(sum(df$is_heatwave), 0.7, 1.2)

# ------------------------------
# 5. Save CSV
# ------------------------------
write.csv(df, "02_synthetic_climate_data_generation/synthetic_heatwaves.csv", row.names = FALSE)



