##
## Process BRC's independent living services in England to display on the winter pressures map
##
library(tidyverse)
library(readxl)
library(stringr)

source("init.r")

# load independent living services to show on map
services = read_excel(file.path(data.dir, services.dir, "Service Database_Export_08 01 2018_ENGLAND_S%40H_TS.xlsx"))

# keep only areas in England
services = services %>% 
  filter(`Area Name` %in% c("NORTH", "CENTRAL", "SOUTH EAST", "SOUTH & THE CHANNEL ISLANDS", "LONDON", "Northern (Manvers)", "Harlow", "Crawley", "Telford", "Carlisle", "Isle of Wight")) %>% 
  filter(`Is This Scheme Inactive?` == "NO") %>% 
  select(Type = `Type of Service`, Name = `Official Scheme Name`, Category = `Categorisation (Primary Scheme Classification)`, Staff = `Number of staff currently attached to this service`, Vols = `Number of volunteers currently attached to this service`, `Hospital 1`, `Hospital 2`, `Hospital 3`, `Hospital 4`, Postcode = `Location Scheme Postcode`, Location = `Location of Scheme`, Location_hospital = `Location if Scheme in a Hospital`)

##
## clean postcodes
##
# regular expression to match postcodes (allowing lowercase and unlimited spaces)
# source: https://stackoverflow.com/a/7259020
# see also: page 6 of https://www.gov.uk/government/uploads/system/uploads/attachment_data/file/488478/Bulk_Data_Transfer_-_additional_validation_valid_from_12_November_2015.pdf
postcode_regex = "(([gG][iI][rR] {0,}0[aA]{2})|((([a-pr-uwyzA-PR-UWYZ][a-hk-yA-HK-Y]?[0-9][0-9]?)|(([a-pr-uwyzA-PR-UWYZ][0-9][a-hjkstuwA-HJKSTUW])|([a-pr-uwyzA-PR-UWYZ][a-hk-yA-HK-Y][0-9][abehmnprv-yABEHMNPRV-Y]))) {0,}[0-9][abd-hjlnp-uw-zABD-HJLNP-UW-Z]{2}))"

# str_extract("WP0 8XX", postcode_regex)  # test whether regex matches fake but well-formed postcodes (it does)

# find anything that looks like a postcode and convert them into separate entries
services = services %>% 
  mutate(Postcode = str_extract_all(Postcode, postcode_regex)) %>%  # convert entries containing multiple postcodes into lists
  mutate(Postcode = na_if(Postcode, "character(0)")) %>%            # set empty lists to NAs (otherwise unnest() doesn't work properly)
  unnest() %>%                                                      # convert entries with multiple postcodes into separate rows
  mutate(Postcode = toupper(Postcode))                              # postcodes should be uppercase

# some data cleaning
services = services %>% 
  mutate(`Hospital 1` = na_if(`Hospital 1`, "*NOT APPLICABLE*"),
         `Hospital 2` = na_if(`Hospital 2`, "*NOT APPLICABLE*"),
         `Hospital 3` = na_if(`Hospital 3`, "*NOT APPLICABLE*"),
         `Hospital 4` = na_if(`Hospital 4`, "*NOT APPLICABLE*"))

# combine `Hospital X` columns into a single list
# just make a comma-separated string since we're only going to display this data in the map popups
services = services %>% 
  # combine the four hospitals columns into a comma-separated list
  unite(Hospitals, `Hospital 1`, `Hospital 2`, `Hospital 3`, `Hospital 4`, sep=", ", remove=F) %>% 
  # replace NAs with spaces
  mutate(Hospitals = str_replace_all(Hospitals, "NA", " ")) %>% 
  # remove empty list items
  mutate(Hospitals = str_replace_all(Hospitals, "^\\s,\\s|,\\s{2}", ""))  # source: https://stackoverflow.com/a/39358929
  

#################################################################################
## get coordinates for postcodes
##
postcodes = read_csv(file.path(data.dir, "Postcodes", "National_Statistics_Postcode_Lookup - BRC.csv"),
                     col_types = cols(
                       Postcode = col_character(),
                       Longitude = col_double(),
                       Latitude = col_double(),
                       Country = col_character(),
                       `Output Area` = col_character(),
                       LSOA = col_character(),
                       `Local Authority Code` = col_character(),
                       `Rural or Urban?` = col_character(),
                       `Rural Urban classification` = col_character(),
                       IMD = col_integer(),
                       `Rurality index` = col_double()
                     ))

# the ONS data truncates 7-character postcodes to remove spaces (e.g. CM99 1AB --> CM991AB); get rid of all spaces in both datasets to allow merging
postcodes$Postcode2 = gsub(" ", "", postcodes$Postcode)
services$Postcode2  = gsub(" ", "", services$Postcode)

# merge
services = services %>% 
  left_join(postcodes, by="Postcode2")

services$Postcode2 = NULL  # don't need the truncated column anymore

##
## save processed services 
##
write_csv(services, file.path(data.dir, services.dir, "IL services England.csv"))
