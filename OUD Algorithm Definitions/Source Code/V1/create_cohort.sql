-- CC-1171 Shabbar Ranapurwala
-- cohort creation
--
-- create this cohort table ONCE.  This cohort will be used for all versions of the OUD algorithm.
-- #####  look for schema name UNC_TRACSDATA and replace with appropriate schema name #####
--
create table unc_tracsdata.cc_1171_cohort as
with
--- FOR UNC, we had to create a separate prescribing table that removed duplicates
--- COMMENT OUT
--prescribing as
--(
--	select * from unc_tracsdata.outpat_op_rx
--),
---
opioid_prescribing as
(
	-- OUTPATIENT --
	select distinct
		'outpatient' as enc_source,
		encounter.admit_date,
		encounter.discharge_date,
		encounter.enc_type,
		prescribing.prescribingid,
		prescribing.patid,
		prescribing.encounterid,
		prescribing.rx_start_date,
		prescribing.rx_end_date,
		prescribing.RX_QUANTITY,
		prescribing.RXNORM_CUI,
		cc_1171_meds.name,
		cc_1171_meds.tty,
		cc_1171_meds.source,
		cc_1171_meds.dose,
		cc_1171_meds.unit,
		cc_1171_meds.mme_factor
	from
		UNC_TRACSDATA.cc_1171_meds cc_1171_meds
		join prescribing on cc_1171_meds.rxnorm_cui = prescribing.rxnorm_cui
		join encounter on prescribing.encounterid = encounter.encounterid
	where
		prescribing.RX_START_DATE between to_date('2014-01-01','YYYY-MM-DD') and to_date('2017-12-31','YYYY-MM-DD')
		and encounter.enc_type NOT in ('ED','EI','IP','IS','OS')
		
	UNION
	
	-- INPATIENT --
	select distinct
		'inpatient' as enc_source,
		encounter.admit_date,
		encounter.discharge_date,
		encounter.enc_type,
		prescribing.prescribingid,
		prescribing.patid,
		prescribing.encounterid,
		prescribing.rx_start_date,
		prescribing.rx_end_date,
		prescribing.RX_QUANTITY,
		prescribing.RXNORM_CUI,
		cc_1171_meds.name,
		cc_1171_meds.tty,
		cc_1171_meds.source,
		cc_1171_meds.dose,
		cc_1171_meds.unit,
		cc_1171_meds.mme_factor
	from
		UNC_TRACSDATA.cc_1171_meds cc_1171_meds
		join prescribing on cc_1171_meds.rxnorm_cui = prescribing.rxnorm_cui
		join encounter on prescribing.encounterid = encounter.encounterid
	where
		prescribing.RX_START_DATE between to_date('2014-01-01','YYYY-MM-DD') and to_date('2017-12-31','YYYY-MM-DD')
		and encounter.enc_type in ('ED','EI','IP','IS','OS')
		and prescribing.rx_end_date > coalesce(encounter.discharge_date, encounter.admit_date)
),
-- find first encounter in study timeframe , between to_date('2014-01-01','YYYY-MM-DD') and to_date('2017-12-31','YYYY-MM-DD')
first_encounter as
(
	select
		patid,
		encounterid,
		admit_date,
		(sysdate - birth_date) / 365.25 as age
	from
	(
		select
			encounter.patid,
			encounter.encounterid,
			encounter.admit_date,
			demographic.birth_date,
			row_number() over( partition by encounter.patid order by admit_date) as pat_admit_row
		from
			demographic
			join encounter on demographic.patid = encounter.patid
		where
			encounter.admit_date between to_date('2014-01-01','YYYY-MM-DD') and to_date('2017-12-31','YYYY-MM-DD')
			and (sysdate - demographic.birth_date) / 365.25 >= 18
	) subq_first_enc
	where
		pat_admit_row = 1
),
-- new patients are those with no encounters 182.625 (6 months) days before first encounter in study timeframe
new_patients as
(
	select distinct
		first_encounter.patid
	from
		first_encounter
	
	MINUS
	
	select distinct
		first_encounter.patid
	from
		first_encounter
		join encounter on first_encounter.patid = encounter.patid and encounter.admit_date between first_encounter.admit_date - 182.625 and first_encounter.admit_date - 1
	where
		encounter.ADMIT_DATE between to_date('2013-06-30','YYYY-MM-DD') and to_date('2017-12-31','YYYY-MM-DD')		
),

-- new patients with at least 2 opioid rx in 182.625 days (6 months)
cohort as
(
	select distinct
		rx1.PATID,
		0 as reviewed
	from
		new_patients
		join opioid_prescribing rx1 on new_patients.patid = rx1.patid
		join opioid_prescribing rx2 on new_patients.patid = rx2.PATID 
	where
		rx1.RX_START_DATE between rx2.RX_START_DATE - 182.625 and rx2.RX_START_DATE + 182.625
		and rx1.PRESCRIBINGID <> rx2.PRESCRIBINGID
)

select * from cohort