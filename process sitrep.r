##
## Load NHS trusts and winter situation reports data
##
## You will need to change the situation report filename on line 13
##
library(tidyverse)
library(readxl)
library(stringr)
library(lubridate)
library(Hmisc)

source("init.r")

# pick the most recent file in the sitrep folder
# source: https://stackoverflow.com/questions/13762224/how-to-sort-files-list-by-date/13762544
sitrep_details = file.info(list.files(path=sitrep.dir, pattern="*.xlsx", full.names=T))

sitrep_filename = sitrep_details %>% 
  rownames_to_column() %>% 
  mutate(mtime = as.POSIXct(mtime)) %>% 
  arrange(desc(mtime)) %>% 
  top_n(1, mtime) %>% 
  select(rowname) %>% 
  as.character()

n.bins = 4  # how do we want to rank the Trusts? Quartiles, quintiles etc.


###########################################################################
## Load data
##
# load situation report
# published on Thursdays at 9.30am until end of Feb 2018
# source: https://www.england.nhs.uk/statistics/statistical-work-areas/winter-daily-sitreps/winter-daily-sitrep-2017-18-data/
# sitrep_path = file.path(sitrep.dir, sitrep_filename)

sitrep_ambulance = read_excel(sitrep_filename, sheet = "Ambulance Arrivals and Delays", skip = 14)
# sitrep_dv      = read_excel(sitrep_filename, sheet = "D&V, Norovirus", skip = 14)  # beds closed due to diarrhea and vomiting
sitrep_beds      = read_excel(sitrep_filename, sheet = "G&A beds", skip = 14)        # general and acute beds
sitrep_closures  = read_excel(sitrep_filename, sheet = "A&E closures", skip = 14)
sitrep_diverts   = read_excel(sitrep_filename, sheet = "A&E diverts", skip = 14)

# load NHS Trusts data
# column names come from the data dictionary published with the data
# GOR code stands for 'Government Office Region Code Linked Geographically'
# source: https://data.gov.uk/dataset/england-nhs-connecting-for-health-organisation-data-service-data-files-of-nhsorganisations/resource/e07f159c-43f1-4abc-8cfa-135fa9f62eec
nhs_trusts = read_csv(file.path(nhs.dir, "etr.csv"),
                      col_names = c("Organisation code", "Name", "National grouping", "High level health geography",
                                    "Address line 1", "Address line 2", "Address line 3", "Address line 4", "Address line 5", "Postcode",
                                    "Open date", "Close date", "Null 1", "Null 2", "Null 3", "Null 4", "Null 5",
                                    "Contact telephone number", "Null 6", "Null 7", "Null 8", "Amended record indicator",
                                    "Null 9", "GOR code", "Null 10", "Null 11", "Null 12"))

# load postcodes from the National Statistics Postcode Lookup
## source: http://geoportal.statistics.gov.uk/datasets/national-statistics-postcode-lookup-latest-centroids
## column descriptions are available Annex B of https://ago-item-storage.s3-external-1.amazonaws.com/1f6c4dfccc9545ccbb853afbe9833558/NSPL_User_Guide_Nov_2017.pdf?X-Amz-Security-Token=FQoDYXdzEBIaDDVhX9xIqSTA9aOsHyK3A81w9RQ%2Bjsec0aVKOnhu1Uq8MUtoT6xzZeFWUvk0urOKkcKik3BeLxwWc%2BCXP8z%2BGgZMXEeP%2BHHi74kGxLXAl59iUw4pPOJjIeMr%2B8Q%2BI0xQheMTC%2BizEaFZ2XfghVh9QEU812TQDvQzmUnlwsqTCsV3s6LyNHtx%2B4HJKXQQ5XEXl3ch%2B3WZS3WFKFcrST9axRAbTpuqNe3JKyaBju4gy%2F9y4cEv9%2F4gxU1tTTBRE3igj8d4f8Gv3lyn6CUS%2F2%2FgHma2fdXvFXok6SIskrdTaRH9C%2BncAb%2BIgdSn7P%2FD2FbdvT2%2FkX%2Bvc%2BBuohV0LBD64p6K0OYdo%2B9cNHEZ48yrL6hWRV8XDm89cxnqLWChJrAsSLV57cACfNpHUpUmfdxfRVVEvB%2Buo8BYSqlNjEzwHhZ3uHM4H5MkcKBStUzvIjiqsRAOIirXaRes6lfER%2BPwN6aHSbTydbhreH2alLw%2F36heqI20pwV%2BybNCu0GyS3pEsBc7uRSSf8Cabz1BzR5Hiz2nCIcF0uReWhbByj1nc5GD47t9iYSzDFekw94MV9W8EJMjpbaNSHYh5fvZ1UT1gqXHLyXGJbcouJbz0QU%3D&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20171222T102253Z&X-Amz-SignedHeaders=host&X-Amz-Expires=300&X-Amz-Credential=ASIAJ2EMZYLUTIJMK5PQ%2F20171222%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Signature=7acfa17a5e027e60bf28c3208c24d88f261adb3ad8a14f20ae18a6d4d2705b2a
##
postcodes = read_csv(file.path(data.dir, "Postcodes", "National_Statistics_Postcode_Lookup_Latest_Centroids.csv"),
                     col_types = cols(
                       X = col_double(),
                       Y = col_double(),
                       objectid = col_integer(),
                       dointr = col_integer(),
                       doterm = col_integer(),
                       usertype = col_integer(),
                       oseast1m = col_integer(),
                       osgrdind = col_integer(),
                       ru11ind = col_character(),
                       lat = col_double(),
                       long = col_double(),
                       imd = col_integer(),
                       .default = col_character()
                       ))


###########################################################################
## clean sitrep data
##
# extract dates for this sitrep
sitrep_dates = read_excel(sitrep_filename, sheet = "G&A beds", skip=12, n_max = 1)  # this row contains the dates
#... the last column contains the most recent date
sitrep_date = sitrep_dates[, ncol(sitrep_dates)]     # get the last column only
names(sitrep_date) = "latest_date"                   # give the column a better name
sitrep_date = as.character(sitrep_date$latest_date)  # convert date to string

# remove first two entries (one is totals, other is blank)
sitrep_ambulance = sitrep_ambulance[3:nrow(sitrep_ambulance),]
sitrep_beds      = sitrep_beds     [3:nrow(sitrep_beds),]
sitrep_closures  = sitrep_closures [3:nrow(sitrep_closures),]
sitrep_diverts   = sitrep_diverts  [3:nrow(sitrep_diverts),]

# drop blank columns ("X__1", "X__2", etc.)
sitrep_ambulance = sitrep_ambulance %>% select(-starts_with("X__"))
sitrep_beds      = sitrep_beds %>% select(-starts_with("X__"))
sitrep_closures  = sitrep_closures %>% select(-starts_with("X__"))
sitrep_diverts   = sitrep_diverts %>% select(-starts_with("X__"))

# column names for closures and diverts are meant to be dates but were read in as integers
# ^ this is ok, don't worry about it - we don't need the column names

##
## Take the most recent days for each of the datasets and combine into a single dataframe
##
# which is the highest-numbered column (the most recent date)?
col_num = gsub(".*__([0-9]+)", "\\1", names(sitrep_ambulance)[length(names(sitrep_ambulance))])
col_regex = paste0("(.*)__", col_num)  # regular expression for selecting the most recent date column

# keep the most recent days for ambulances and beds 
sitrep_ambulance = sitrep_ambulance %>% select(`NHS England Region`:Name, matches(col_regex))
sitrep_beds      = sitrep_beds      %>% select(`NHS England Region`:Name, matches(col_regex))

#... rename columns to drop the __6 suffix
names(sitrep_ambulance) = str_replace(names(sitrep_ambulance), col_regex, "\\1")
names(sitrep_beds)      = str_replace(names(sitrep_beds),      col_regex, "\\1")

# keep the most recent days for closures and diverts...
most_recent_idx = ncol(sitrep_diverts)
sitrep_closures = sitrep_closures %>% select(`NHS England Region`:Name, most_recent_idx)
sitrep_diverts  = sitrep_diverts  %>% select(`NHS England Region`:Name, most_recent_idx)

#... and rename the integer date columns to something more useful
names(sitrep_closures)[ncol(sitrep_closures)] = "Closures"
names(sitrep_diverts)[ncol(sitrep_diverts)]   = "Diverts"

# remove rows which are just table footnotes
sitrep_ambulance = na.omit(sitrep_ambulance)
sitrep_beds      = na.omit(sitrep_beds)
sitrep_closures  = na.omit(sitrep_closures)
sitrep_diverts   = na.omit(sitrep_diverts)

# merge the sit reps into one dataframe
sitrep = sitrep_ambulance %>% 
  left_join(sitrep_beds     %>% select(-`NHS England Region`, -Name), by="Code") %>% 
  left_join(sitrep_closures %>% select(-`NHS England Region`, -Name), by="Code") %>% 
  left_join(sitrep_diverts  %>% select(-`NHS England Region`, -Name), by="Code")

# make sure the columns are numeric - sometimes their data uses "-" for missing values
sitrep$`Delay 30-60 mins` = as.numeric(sitrep$`Delay 30-60 mins`)
sitrep$`Occupancy rate` = as.numeric(sitrep$`Occupancy rate`)
sitrep$Closures = as.numeric(sitrep$Closures)
sitrep$Diverts = as.numeric(sitrep$Diverts)


###########################################################################
## Merge in coords for postcodes
##
# keep only postcodes and coordinates
postcodes = postcodes %>% 
  select(Postcode = pcd, Longitude = long, Latitude = lat)

# the ONS data truncates 7-character postcodes (e.g. CM99 1AB) to remove spaces (--> CM991AB) for some reason; get rid of all spaces in both datasets to allow merging
postcodes$Postcode  = gsub(" ", "", postcodes$Postcode)
nhs_trusts$Postcode = gsub(" ", "", nhs_trusts$Postcode)

# look up NHS Trusts' postcodes
nhs_trusts = nhs_trusts %>% 
  left_join(postcodes, by="Postcode")

sum(is.na(nhs_trusts$Longitude))  # how many postcodes couldn't it find? (3)

# add Trust locations to situation report
sitrep = sitrep %>% 
  left_join(nhs_trusts %>% select(`Organisation code`, Postcode, Longitude, Latitude), 
            by=c("Code" = "Organisation code"))


###########################################################################
## Make winter pressures index from the four indicators
##
# treat closures and diverts as binary
sitrep$Closures = ifelse(sitrep$Closures > 1, 1, 0)
sitrep$Diverts  = ifelse(sitrep$Diverts  > 1, 1, 0)

# generate ratings for the hospitals, based on `n.bins`, which was set at the start of this file
sitrep$Delay_stress    = as.integer(cut2(sitrep$`Delay 30-60 mins`, g=n.bins))
sitrep$Beds_stress     = as.integer(cut2(sitrep$`Occupancy rate`,   g=n.bins))
sitrep$Closures_stress = as.integer(cut2(sitrep$Closures,           g=n.bins))
sitrep$Diverts_stress  = as.integer(cut2(sitrep$Diverts,            g=n.bins))

# if a Trust had ambulances delayed by over an hour, mark them in highest stress category
sitrep$Delay_stress = ifelse(sitrep$`Delay >60 mins` > 0, n.bins, sitrep$Delay_stress)

# calculate overall stress rating for each Trust
# - sum up the separate stress measures
# - convert into quartiles
sitrep$Stress = sitrep$Delay_stress + sitrep$Beds_stress + sitrep$Closures_stress + sitrep$Diverts_stress
sitrep$StressRank = cut2(sitrep$Stress, g=n.bins)
levels(sitrep$StressRank) = 1:n.bins

##
## deal with any missing indicators
##
# check for missing data in any of the four indicators
# - this is probably worth flagging up to the viewer of the map
sitrep$MissingDataYN = F  # don't flag by default
sitrep$MissingDataYN[is.na(sitrep$Delay_stress)]    = T
sitrep$MissingDataYN[is.na(sitrep$Beds_stress)]     = T
sitrep$MissingDataYN[is.na(sitrep$Closures_stress)] = T
sitrep$MissingDataYN[is.na(sitrep$Diverts_stress)]  = T

# if a stress rating is NA, mark it the worst
sitrep$StressRank[is.na(sitrep$StressRank)] = n.bins


################################################################
## Save cleaned situation report
##
# save a date-stamped file for archiving plus a copy for feeding into the map
write_csv(sitrep, file.path(sitrep.dir, paste0("sitrep - ", sitrep_date, ".csv")))
# write_csv(sitrep, file.path(sitrep.dir, "sitrep - clean.csv"))  # don't need this one anymore since map script now loads most recent sitrep .csv file
