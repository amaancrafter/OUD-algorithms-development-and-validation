-- if you have dbms_random installed, you don't need to do this
--
-- if you don't have a random number generator installed with your DBMS, you can create random number outside of the database and use the _ALTERNATE.sql script
-- STEPS:
-- select patid from your cohort table and save as csv file with one column (patid) and column heading "patid" in lowercase
-- run the R script patid_random_gen.R.  make changes so the script will read in your file created above
-- load the output of the R script into the table below:

create table cc_1171_cohort_randnum (
	patid integer,
	randnum float
)

-- Now, you can run the oud_V1 ALTERNATE sql

