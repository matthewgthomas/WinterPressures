##
## Map the situation reports
## - https://www.england.nhs.uk/statistics/statistical-work-areas/winter-daily-sitreps/winter-daily-sitrep-2017-18-data/
##
# set up data folders
source("init.r")

# import and process the most recent situation report
source("process sitrep.r")

# import and process BRC's independent living services
# note: you should only need to run this once (or after every extract)
# source("process services.r")

# produce map as .html file (all data and javascript will be contained in the single file)
rmarkdown::render("winterpressures.Rmd", output_file="index.html", output_dir="output")
rmarkdown::render("winterpressures-services.Rmd", output_file="index-services.html", output_dir="output")
