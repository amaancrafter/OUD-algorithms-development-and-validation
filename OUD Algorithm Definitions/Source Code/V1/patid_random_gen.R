# cohort patid file should contain a header row with "patid" (lowercase) in the first and only column.  this column should be populated with patid from your cohort
# change cohort_patid_dir and cohort_patid_filename below
cohort_patid_dir <- "H:/CDRN/CC_1171_Shabbar_Ranapurwala/R/"
cohort_patid_filename <- "cohort_patids.csv"
cohort_outfile <- "cohort_patid_randnum.csv"

cohort <- read.csv(paste(cohort_patid_dir,cohort_patid_filename,sep=""),header=TRUE)

num_pats <- length(cohort$patid)

randnums <- runif(num_pats)

cohort$randnum <- randnums

write.csv(cohort, na='', row.names=FALSE, file=paste(cohort_patid_dir, cohort_outfile, sep="") )
