-- load final_outpatient_opioid_meds_for_study.csv into:
create table cc_1171_meds  (
	in_rxnorm_cui integer,
	rxnorm_cui integer,
	name varchar(255),
	tty varchar(16),
	source varchar(16),
	dose float,
	unit varchar(16),
	mme_factor float
)

;

--load final_ingredients_for_study.csv into:
create table cc_1171_ingredients (
	in_rxnorm_cui integer,
	in_name varchar(255),
	mme_factor float
)

;

--load final_treatment_meds_for_study.csv into:
create table cc_1171_treatment_meds  (
	in_rxnorm_cui integer,
	rxnorm_cui integer,
	name varchar(255),
	tty varchar(16),
	dose float,
	unit varchar(16)
)

;
