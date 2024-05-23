Climate time series development for MWEPA Zone 1

About this script:
- The script queries and processes monthly gridded climate data (PRISM) from the RCC-ACIS webservice (https://www.rcc-acis.org/docs_webservices.html).
- A monthly, unweighted spatial mean of precipitation and temperature is calculated from all gridded climate values in MWEPA Zone 1 (MWEPA shapefile).
- A 12-month rolling average temperature ("temp_F_12mo") and 3-month ("spi3") and 12-month ("spi12") Standardized Precipitation Index (SPI) drought indices are calculated from monthly values.
