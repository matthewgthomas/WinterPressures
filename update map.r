##
## Map the situation reports
##
# set up data folders
source("init.r")

# import and process the most recent situation report
# note: you'll need to update the `sitrep_filename` variable on line 14 of this file
source("process sitrep.r")

# produce map as .html file (all data and javascript will be contained in the single file)
rmarkdown::render("winterpressures.Rmd", output_file="index.html", output_dir="output")
