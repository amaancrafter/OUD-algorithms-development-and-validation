-- CC-1171 Shabbar Ranapurwala
-- OUD Algorithm Version 3
--cohort is in table unc_tracsdata.cc_1171_cohort
-- #####  look for schema name UNC_TRACSDATA and replace with appropriate schema name #####

--#### what to output ####--
-- see steps at end of file


with
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
		(sysdate - birth_date) / 365.25 as age,
		sex
	from
	(
		select
			encounter.patid,
			encounter.encounterid,
			encounter.admit_date,
			demographic.birth_date,
			demographic.sex,
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
-- new patients are those with no encounters 182.625 days before first encounter in study timeframe
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
		join encounter on first_encounter.patid = encounter.patid and encounter.admit_date between first_encounter.admit_date - 182.625 and first_encounter.admit_date -1
	where
		encounter.ADMIT_DATE between to_date('2013-06-30','YYYY-MM-DD') and to_date('2017-12-31','YYYY-MM-DD')		
),
--
-- select from your cohort table created in setup process
cohort as
(
	select distinct
		cc_1171_cohort.*,
		demographic.sex
--		demographic.race,
--		demographic.hispanic
	from
		unc_tracsdata.cc_1171_cohort cc_1171_cohort
		join demographic on cc_1171_cohort.patid = demographic.patid
),
-- inclusion 1
-- patients with opioid abuse dx
-- OUD DX
--		305.50 - 305.53
--		304.00 - 304.03 
--		F11.10 - F11.19 
--		F11.20 - F11.29 
oud_dx_pats as
(
	select distinct
		1 as oud_dx_inc,
		cohort.patid
	from
		cohort
		join diagnosis on cohort.patid = diagnosis.patid
	where
		diagnosis.admit_date between to_date('2014-01-01','YYYY-MM-DD') and to_date('2017-12-31','YYYY-MM-DD')
		and
		(
			(
				diagnosis.dx_type='09'
				and
				diagnosis.dx in
				(
					'305.50',
					'305.51', 
					'305.52',
					'305.53',
					'304.00',
					'304.01',
					'304.02',
					'304.03'
				)
			)
			or
			(
				diagnosis.dx_type='10'
				and
				(
					diagnosis.dx like 'F11.1%'
					or diagnosis.dx like 'F11.2%'
				)
			)
		)
),
-- inclusion 2
-- patients with medication assisted treatment (hcpcs codes)
mat_pats as
(
	select distinct
		1 as mat_inc,
		cohort.patid
	from
		cohort
		join procedures on cohort.patid = procedures.patid
	where
		px in
		(
		'H0007',
		'H0008',
		'H0009',
		'H0010',
		'H0011',
		'H0012',
		'H0013',
		'H0014',
		'H0015',
		'H0016',
		'H0020'
		)
		and procedures.admit_date between to_date('2014-01-01','YYYY-MM-DD') and to_date('2017-12-31','YYYY-MM-DD')
),
-- patients with addiction tratment rx
treatment_rx_pats as
(
	select distinct 
		cohort.patid
	from
		cohort
		join prescribing on cohort.patid = prescribing.patid
		join UNC_TRACSDATA.cc_1171_treatment_meds cc_1171_treatment_meds on prescribing.rxnorm_cui = cc_1171_treatment_meds.rxnorm_cui
	where
		prescribing.RX_START_DATE between to_date('2014-01-01','YYYY-MM-DD') and to_date('2017-12-31','YYYY-MM-DD')

),
-- patients with overdose dx
overdose_dx_pats as
(
	select 
		cohort.patid,
		count(distinct diagnosis.encounterid) as enc_count
	from
		cohort
		join diagnosis on cohort.patid = diagnosis.patid
	where
		diagnosis.admit_date between to_date('2014-01-01','YYYY-MM-DD') and to_date('2017-12-31','YYYY-MM-DD')
		and
		(
			(
				diagnosis.dx_type='09'
				and
				diagnosis.dx in
				(
					'965.00',
					'965.01', 
					'965.02',
					'E850.0',
					'E850.1',
					'E850.2'
				)
			)
			or
			(
				diagnosis.dx_type='10'
				and
				(
					diagnosis.dx like 'T40.0%'
					or diagnosis.dx like 'T40.1%'
					or diagnosis.dx like 'T40.2%'
					or diagnosis.dx like 'T40.3%'
					or diagnosis.dx like 'T40.4%'
				)
			)
		)
		and diagnosis.admit_date between to_date('2014-01-01','YYYY-MM-DD') and to_date('2017-12-31','YYYY-MM-DD')
	group by
		cohort.patid
	having
		count(distinct diagnosis.encounterid) > 1
),
-- inclusion 3
treat_plus_od as
(
	select distinct 1 as treat_plus_od_inc, patid from
	(
		select distinct patid from overdose_dx_pats
		intersect
		select distinct patid from treatment_rx_pats
	) subq
),
hi_mme_rx as
(
	select * from
	(
	select distinct
		cohort.*,
		prescribingid,
		enc_source,
		opioid_prescribing.encounterid,
		opioid_prescribing.name,
		opioid_prescribing.tty,
		opioid_prescribing.dose,
		opioid_prescribing.unit,
		opioid_prescribing.mme_factor,
		opioid_prescribing.rx_start_date,
		opioid_prescribing.rx_end_date,
		opioid_prescribing.rx_quantity,
		(1 + (rx_end_date - rx_start_date)) as rx_days,
		case 
			when (1 + (rx_end_date - rx_start_date)) > 0 
				then rx_quantity / (1 + (rx_end_date - rx_start_date))
			else NULL
		end as med_per_day,
		case 
			when (1 + (rx_end_date - rx_start_date)) > 0 and mme_factor is not NULL and rx_quantity is not NULL and dose is not NULL
				then mme_factor * dose * (rx_quantity / (1 + (rx_end_date - rx_start_date)))
			else NULL
		end as mme_per_day,		
--		opioid_prescribing.rx_quantity / (1 + (opioid_prescribing.rx_end_date - opioid_prescribing.rx_start_date)) as med_per_day,
--		opioid_prescribing.mme_factor * (opioid_prescribing.rx_quantity / (1 + (opioid_prescribing.rx_end_date - opioid_prescribing.rx_start_date))) as mme_per_day
		1 as hi_mme_inc
	from
		cohort
		join opioid_prescribing on cohort.patid = opioid_prescribing.patid
	)
	where 
		mme_per_day >= 50  -- only evaluate 5o+ mme/day

),
-- inclusion 4
hi_mme_pats_90 as
(
	select distinct 1 as hi_mme_90_inc, patid from
	(
		select subq1.*, rx1_days + rx2_days as total_days from
		(
			select
				rx1.patid,
				rx1.prescribingid,
				rx1.rx_days as rx1_days,
				sum(rx2.rx_days) as rx2_days
			from
				hi_mme_rx rx1
				join hi_mme_rx rx2 on rx1.patid = rx2.patid
			where
				rx2.rx_end_date between rx1.rx_start_date and rx1.rx_start_date+180
				and rx1.prescribingid <> rx2.prescribingid
				and rx1.mme_per_day >= 90
				and rx2.mme_per_day >= 90
			group by
				rx1.patid,
				rx1.prescribingid,
				rx1.rx_days
		) subq1
	) subq2
	where 
		total_days >= 180	
),
-- inclusion 5
-- 3+ ED visits with opioid RX in 30 day window
ed_opioid as
(
	select distinct 1 as ed_opioid_inc, patid from
	(
		select
			cohort.*,
			enc1.encounterid eid1,
			enc2.encounterid eid2,
			enc3.encounterid eid3,
			enc1.admit_date ad1,
			enc2.admit_date ad2,
			enc3.admit_date ad3,
			rx1.name rxn1,
			rx2.name rxn2,
			rx3.name rxn3
		from
			cohort
			-- first encounter
			join encounter enc1 on cohort.patid = enc1.patid and enc1.enc_type='ED' and enc1.admit_date between to_date('2014-01-01','YYYY-MM-DD') and to_date('2017-12-31','YYYY-MM-DD')
			join opioid_prescribing rx1 on enc1.encounterid = rx1.encounterid
			-- second encounter
			join encounter enc2 on cohort.patid = enc2.patid and enc2.enc_type='ED' and enc2.admit_date between to_date('2014-01-01','YYYY-MM-DD') and to_date('2017-12-31','YYYY-MM-DD')
				and enc2.admit_date between enc1.admit_date and enc1.admit_date+30
			join opioid_prescribing rx2 on enc2.encounterid = rx2.encounterid
			-- third encounter
			join encounter enc3 on cohort.patid = enc3.patid and enc3.enc_type='ED' and enc3.admit_date between to_date('2014-01-01','YYYY-MM-DD') and to_date('2017-12-31','YYYY-MM-DD')
				and enc3.admit_date between enc1.admit_date and enc1.admit_date+30
			join opioid_prescribing rx3 on enc3.encounterid = rx3.encounterid
			
		where
			enc1.encounterid <> enc2.encounterid
			and enc1.encounterid <> enc3.encounterid
			and enc2.encounterid <> enc3.encounterid
			and enc1.admit_date <> enc2.admit_date
			and enc1.admit_date <> enc3.admit_date
			and enc2.admit_date <> enc3.admit_date		
		) subq
),
cohort_algorithm as
(
	select distinct
		cohort.*,
		oud_dx_inc,				-- use for inclusion
		mat_inc,				-- use for inclusion
		treat_plus_od_inc,		-- use for inclusion
		hi_mme_90_inc,			-- use for inclusion
		ed_opioid_inc,			-- use for inclusion
		case 
			when oud_dx_inc=1 or mat_inc=1 or treat_plus_od_inc=1 or hi_mme_90_inc=1 or ed_opioid_inc=1 then 1 
			else 0 
		end as algorithm_inclusion,
		dbms_random.value() as randnum,
		case 
			when hi_mme_90_inc=1 then 'hi_mme_90_inc' 
			when mat_inc=1 then 'mat_inc'
			when treat_plus_od_inc=1 then 'treat_plus_od_inc'
			when ed_opioid_inc=1 then 'ed_opioid_inc'			
			when oud_dx_inc=1 then 'oud_dx_inc'
			else 'none' 
		end as inc_type
	from
		cohort
		left outer join oud_dx_pats on cohort.patid = oud_dx_pats.patid
		left outer join mat_pats on cohort.patid = mat_pats.patid
		left outer join treat_plus_od on cohort.patid = treat_plus_od.patid
		left outer join hi_mme_pats_90 on cohort.patid = hi_mme_pats_90.patid
		left outer join ed_opioid on cohort.patid = ed_opioid.patid
),
-- from create_cohort.sql , used for summary counts
new_patient_counts as
(
	select count(distinct patid) as num, sex from
	(
	select distinct
		first_encounter.patid, first_encounter.sex
	from
		first_encounter
	
	MINUS
	
	select distinct
		first_encounter.patid, first_encounter.sex
	from
		first_encounter
		join encounter on first_encounter.patid = encounter.patid and encounter.admit_date between first_encounter.admit_date - 182.625 and first_encounter.admit_date -1
	where
		encounter.ADMIT_DATE between to_date('2013-06-30','YYYY-MM-DD') and to_date('2017-12-31','YYYY-MM-DD')		
	) subq
	group by
		sex
),
algorithm_summary as
(
	select
		'cohort patients' as type,
		cohort_algorithm.sex,
		count(patid) as num,
		sum(oud_dx_inc) as oud_dx_inc,
		sum(mat_inc) as mat_inc,		
		sum(treat_plus_od_inc) as treat_plus_od_inc,
		sum(hi_mme_90_inc) as hi_mme_90_inc,
		sum(ed_opioid_inc) as ed_opioid_inc,
		sum(algorithm_inclusion) as algorithm_inclusion,
		sum(1-algorithm_inclusion) as algorithm_not_included
	from
		cohort_algorithm
	group by
		cohort_algorithm.sex
		
	UNION
	
	select
		'new patients' as type,
		new_patient_counts.sex,
		new_patient_counts.num,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL
	from
		new_patient_counts
		
	UNION
	
	select
		'cohort prescriptions' as type,
		NULL,
		count(distinct prescribingid) as num,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL
	from
		cohort
		join opioid_prescribing on cohort.patid = opioid_prescribing.patid
),
included_5 as
(
	select * from
	(
		select
			pat_type,
			patid,
			oud_dx_inc,
			mat_inc,
			treat_plus_od_inc,
			hi_mme_90_inc,
			ed_opioid_inc,
			algorithm_inclusion,
			row_number() over(order by rowcount) as review_row		
		from
		(
			select
				'included' as pat_type,
				cohort_algorithm.*,
				row_number() over(partition by inc_type order by randnum) as rowcount
			from
				cohort_algorithm
			where
				algorithm_inclusion=1
				and reviewed=0
		) subq
	) subq2
	where review_row <= 5
),
not_included_5 as
(
	select
		pat_type,
		patid,
		oud_dx_inc,
		mat_inc,
		treat_plus_od_inc,
		hi_mme_90_inc,
		ed_opioid_inc,
		algorithm_inclusion,
		rowcount as review_row
	from
	(
		select
			'not included' as pat_type,
			cohort_algorithm.*,
			row_number() over(partition by inc_type order by randnum) as rowcount
		from
			cohort_algorithm
		where
			algorithm_inclusion=0
			and reviewed=0			
	) subq
	where rowcount <= 5

),
pats_to_review as
(

	select * from included_5
	UNION 
	select * from not_included_5
)


-- 1) output summary
-- select * from algorithm_summary order by 1,2
-- 2) output 10 sample patients
--	select * from pats_to_review order by pat_type, patid
-- 3) update patient cohort table, set sample patients to reviewed=1
--	update  unc_tracsdata.cc_1171_cohort set reviewed=1 where patid in
--	(
--	--put the 10 sample patids here
--	3956644,
--	7321398,
--	7430607,
--	7489770,
--	8950818,
--	4647459,
--	4772828,
--	5073041,
--	7410543,
--	8838011
--	)

