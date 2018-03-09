##
## Create boundaries for Community Connector services
##
library(tidyverse)
library(readxl)
library(stringr)
library(rgdal)

source("init.r")

# load community connector sites
services_cc = read_excel(file.path(data.dir, services.dir, "CC_Service-location-database_for-web.xlsx"))

##
## England, Scotland, Wales
##
# use Open Door Logistics data for all boundaries except NI and Isle of Man
# source: http://www.opendoorlogistics.com/data/
pc_districts = readOGR(dsn = file.path(data.dir, "Postcodes", "Boundaries"), layer = "Districts")

# # keep only community connector postcode districts
pc_districts = pc_districts[pc_districts$name %in% services_cc$Postcode, ]

names(pc_districts@data) = "Name"  # make column name consistent with all the separate files loaded below

# list_districts = file.path(data.dir, "Postcodes", "Boundaries", "districts", 
#                               paste0(services_cc$Postcode, ".kml"))

##
## Northern Ireland
## - use MapIt Voronoi Postcode Boundaries for NI: http://postcodes.mapit.longair.net/
##
# get list of .kml files in NI where we have CC services
list_districts_ni = file.path(data.dir, "Postcodes", "Boundaries", "districts", 
                              paste0(grep("^BT.*", services_cc$Postcode, value = T), ".kml"))

# load the NI .kmz files
for (file in list_districts_ni) {
  # get current postcode district
  postcode = str_replace(file, ".*/([A-Z]+[0-9]+)\\.kml", "\\1")
  ni_tmp = readOGR(file)
  
  ni_tmp@data$Name = postcode     # set `Name` column to be postcode
  ni_tmp@data$Description = NULL  # remove `Description`
  
  # ni_tmp_data = ni_tmp@data  # DEBUG
  
  pc_districts = raster::union(pc_districts, ni_tmp)  # merge into main set of districts
  # paste0("Opening ", postcode)
}

##
## Isle of Man
##
# use the Isle of Man administrative boundary: http://global.mapit.mysociety.org/area/363367.html
pc_districts_iom = readOGR(file.path(data.dir, "Postcodes", "Boundaries", "IoM.kml"))

pc_districts_iom@data$Description = NULL  # we don't need this column
pc_districts_iom@data$Name = "IM1"  # just use any old IoM postcode district - we don't have deprivation indices etc. for these anyway

# combine into a single spatial polygons dataframe
pc_districts = raster::union(pc_districts, pc_districts_iom)

##
## clean up data
##
# some of the postcode districts are spread across several `Name.x` columns, with a bunch of NAs;
# compress them all into a single column
pc_districts@data = data.frame(Name = na.omit(unlist(pc_districts@data)))

row.names(pc_districts@data) = 1:nrow(pc_districts@data)  # the above line of code turns the row names into weird column names; convert them back to numbers

##
## save postcode districts polygons
##
saveRDS(pc_districts, file.path(data.dir, services.dir, "CC boundaries.rds"))
