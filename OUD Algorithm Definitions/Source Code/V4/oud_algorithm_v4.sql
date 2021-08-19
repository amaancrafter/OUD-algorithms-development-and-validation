-- CC-1171 Shabbar Ranapurwala
-- OUD Algorithm Version 4 
--
-- REPLACE our schema name with yours for the tables below:
--cohort is in table unc_tracsdata.cc_1171_cohort
--surgery codes are in table unc_tracsdata.cc_1171_surgery
-- #####  look for schema name UNC_TRACSDATA and replace with appropriate schema name #####

--#### what to output ####--
-- see steps at end of file


with
--- FOR UNC, we had to create a separate prescribing table that removed duplicates
--- COMMENT OUT
--prescribing_dedupe as
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
--		join prescribing_dedupe prescribing on cc_1171_meds.rxnorm_cui = prescribing.rxnorm_cui
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
		join prescribing_dedupe prescribing on cc_1171_meds.rxnorm_cui = prescribing.rxnorm_cui
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
cancer_dx as 
(
    select 
        distinct diagnosis.patid --, diagnosis.ADMIT_DATE, diagnosis.dx
    from 
        cohort
        join diagnosis on cohort.patid = diagnosis.patid
    where
        (
            (DX_TYPE = '10' AND DX BETWEEN 'C00' AND 'D49.99') 
            OR 
            (DX_TYPE = '09' AND DX BETWEEN '140' AND '239.99')
        )
        and diagnosis.admit_date BETWEEN to_date('2014-01-01','YYYY-MM-DD') and to_date('2017-12-31','YYYY-MM-DD')
),
cancer_rx as
(
	select
		distinct prescribing.patid
	from
		cohort
		join prescribing on cohort.patid = prescribing.patid
WHERE 
	prescribing.RXNORM_CUI IN ('337521',	'2046141',	'253337',	'2046138',	'1657068',	'2046149',	'2046145',	'1657074',	'544556',	'2046142',	'1657067',	'2046143',	'1657066',	'2046148',	'2046140',	'1657073',	'437105',	'2046139',	'1657065',	'1161185',	'1175674',	'2046144',	'1101770',	'202982',	'72962',	'1299922',	'1860486',	'1111073',	'1101773',	'1860482',	'1101771',	'1111072',	'1001406',	'1101772',	'1860481',	'1860485',	'1918045',	'1861411',	'1111071',	'1101769',	'1870937',	'1093280',	'1860480',	'1001405',	'1860619',	'1001404',	'1093279',	'1101768',	'1111070',	'329054',	'376888',	'1860479',	'1160617',	'1173805',	'1180259',	'203652',	'51499',	'153329',	'1726325',	'1726321',	'1726335',	'904161',	'1726320',	'1726319',	'1726492',	'1726333',	'1726324',	'904159',	'1726318',	'1161334',	'1172305',	'1597881',	'1597876',	'1657192',	'1991413',	'1657196',	'1597882',	'1657191',	'1991412',	'1657190',	'1657195',	'1597877',	'1657189',	'1597878',	'1597884',	'1547550',	'1547545',	'1657751',	'1657749',	'1547551',	'1657747',	'1657748',	'1657750',	'1657746',	'1547546',	'1657744',	'1657745',	'1547547',	'1547553',	'1424215',	'1424174',	'1424219',	'1745393',	'1745387',	'1424214',	'1745391',	'1745384',	'1424212',	'1424218',	'101306',	'224905',	'1922512',	'806575',	'1922518',	'806574',	'1922510',	'1922517',	'540885',	'1922511',	'1922509',	'806573',	'1922516',	'806572',	'1922507',	'1922515',	'377216',	'1922508',	'1162762',	'1169113',	'203472',	'57308',	'266573',	'748738',	'637550',	'748740',	'748736',	'748739',	'1799417',	'748737',	'1799418',	'747193',	'747195',	'1799424',	'1799416',	'342947',	'452837',	'747194',	'1799414',	'747192',	'1799415',	'1157655',	'1157656',	'1157657',	'1172714',	'1172715',	'1172716',	'1304480',	'1232150',	'1304475',	'1723194',	'1723189',	'1304481',	'1723188',	'1723193',	'1723187',	'1304476',	'1723180',	'1232152',	'1304483',	'1670317',	'10803',	'1670304',	'1670310',	'1670322',	'1670324',	'1670318',	'1670323',	'1670319',	'1670311',	'1670316',	'1670305',	'1670306',	'1670314',	'1670315',	'1670309',	'1670307',	'1670308',	'1670320',	'1670321',	'1425105',	'1425099',	'1425098',	'1425118',	'1425110',	'1425106',	'1425117',	'1425107',	'1425116',	'1425104',	'1425100',	'1425115',	'1425103',	'1425101',	'1425102',	'1425108',	'1425109',	'2099947',	'2099704',	'2099703',	'2099956',	'2099952',	'2099948',	'2099955',	'2099949',	'2099946',	'2099954',	'2099942',	'2099953',	'2099945',	'2099943',	'2099944',	'2099950',	'2099951',	'1312403',	'1312397',	'1371319',	'1312408',	'1312404',	'1312405',	'1312402',	'1312398',	'1312401',	'1312399',	'1312400',	'1312406',	'1312407',	'1535993',	'1535922',	'1657781',	'1657777',	'1535994',	'1657776',	'1657780',	'1657775',	'1535989',	'1657774',	'1535990',	'1535996',	'1298949',	'1298944',	'1298953',	'1298950',	'1657574',	'1298948',	'1298945',	'1657572',	'1298946',	'1298952',	'11473',	'105443',	'1737461',	'1737451',	'1737457',	'1737459',	'1737449',	'1737453',	'904918',	'904922',	'904926',	'1737456',	'1737458',	'1737460',	'1737448',	'1160721',	'1723746',	'1723738',	'1723750',	'1723747',	'1723748',	'1723745',	'1723741',	'1723744',	'1723742',	'1723749',	'2103170',	'2103164',	'2103179',	'2103175',	'2103171',	'2103178',	'2103172',	'2103169',	'2103177',	'2103165',	'2103176',	'2103168',	'2103166',	'2103167',	'2103173',	'2103174',	'203769',	'72965',	'153124',	'565177',	'368318',	'200064',	'316135',	'372571',	'1163195',	'1163196',	'1176624',	'1176625',	'1719773',	'1719768',	'1719767',	'1719777',	'1719774',	'1719775',	'1719772',	'1719769',	'1719771',	'1719770',	'1719776',	'1094837',	'1094833',	'1657013',	'1657007',	'1094838',	'1657006',	'1657012',	'1657005',	'1094834',	'1657004',	'1161327',	'1186646',	'203870',	'282357',	'727954',	'575925',	'727953',	'727762',	'350934',	'727760',	'1156671',	'1174691',	'2058916',	'2058849',	'2058932',	'2058926',	'2058922',	'2058917',	'2058925',	'2058931',	'2058919',	'2058930',	'2058915',	'2058924',	'2058910',	'2058923',	'2058929',	'2058914',	'2058911',	'2058913',	'2058920',	'2058921',	'301739',	'402100',	'402338',	'402339',	'1163065',	'1659922',	'1659191',	'1659192',	'1659927',	'1659923',	'1659924',	'1659921',	'1659917',	'1659920',	'1659918',	'1659919',	'1659925',	'1659926',	'1371046',	'1371041',	'1658087',	'1658091',	'1658085',	'1658090',	'1658086',	'1658089',	'1658084',	'1658082',	'1658088',	'1658083',	'1601452',	'1371049',	'262485',	'84857',	'151124',	'564931',	'367866',	'199224',	'315382',	'370588',	'1157702',	'1157703',	'1170752',	'1170753',	'355460',	'318341',	'1657660',	'1657664',	'544717',	'1657659',	'1657663',	'1657658',	'485253',	'1657657',	'1161239',	'1168274',	'1045457',	'1045453',	'1045452',	'1045460',	'1045458',	'1736562',	'1045456',	'1045454',	'1736560',	'1162502',	'1176093',	'1430268',	'1430438',	'1430441',	'1430453',	'1430457',	'1430449',	'1430447',	'1430452',	'1430456',	'1430448',	'1430451',	'1430446',	'1430455',	'1430442',	'1430450',	'1430454',	'1430445',	'1430443',	'1430444',	'1430271',	'1430272',	'203760',	'70223',	'105648',	'1719783',	'1719784',	'307816',	'1719780',	'1719781',	'1154611',	'1180698',	'1727480',	'1727455',	'1727485',	'1727481',	'1727482',	'1727479',	'1727475',	'1727478',	'1727476',	'1727477',	'1727483',	'1727484',	'2169302',	'2169320',	'2169322',	'2169314',	'2169319',	'2169321',	'2169311',	'2169285',	'2169307',	'2169318',	'2169313',	'2169303',	'2169312',	'2169317',	'2169304',	'2169310',	'2169300',	'2169316',	'2169296',	'2169309',	'2169315',	'2169299',	'2169297',	'2169298',	'2169305',	'2169306',	'1792781',	'1792776',	'1792785',	'2119696',	'1792782',	'1792783',	'1792780',	'2119695',	'1792777',	'1792779',	'1792778',	'1792784',	'2049112',	'2049106',	'2049117',	'2049121',	'2049113',	'2049120',	'2049114',	'2049119',	'2049111',	'2049107',	'2049118',	'2049110',	'2049108',	'2049109',	'2049115',	'2049116',	'2049128',	'2049122',	'2049133',	'2049129',	'2049130',	'2049127',	'2049123',	'2049126',	'2049124',	'2049125',	'2049131',	'2049132',	'1921223',	'1988786',	'1988785',	'1921217',	'1988768',	'1921228',	'1988772',	'1988767',	'1988771',	'1921224',	'1921225',	'1921222',	'1925494',	'1988770',	'1988769',	'1925493',	'1921218',	'1921221',	'1921219',	'1921220',	'1921226',	'1921227',	'1790162',	'1363268',	'1790167',	'1790175',	'1790171',	'1790163',	'1790170',	'1790174',	'1790164',	'1790169',	'1790173',	'1790161',	'1363269',	'1790168',	'1790172',	'1790160',	'1363270',	'1363271',	'1790165',	'1790166',	'1363274',	'1363408',	'1364581',	'1363410',	'1364580',	'1363409',	'1363312',	'1363267',	'1363284',	'1363279',	'1363275',	'1363283',	'1363276',	'1363281',	'1363273',	'1363280',	'1363272',	'1363277',	'1363278',	'220961',	'194000',	'213293',	'213292',	'573202',	'573203',	'368280',	'200328',	'200327',	'315557',	'315558',	'371250',	'1158877',	'1158878',	'1186410',	'1186411',	'1535463',	'1535457',	'2121061',	'1535468',	'1535464',	'1535465',	'2121060',	'1535462',	'2121059',	'1535458',	'1535461',	'2121058',	'1535459',	'1535460',	'1535466',	'1535467',	'1425223',	'1424911',	'1425222',	'1425228',	'1425230',	'1425224',	'1425229',	'1425225',	'1424918',	'1424916',	'1424912',	'1424917',	'1424915',	'1424913',	'1424914',	'1425226',	'1425227',	'2180331',	'2180325',	'2180336',	'2180332',	'2180333',	'2180330',	'2180326',	'2180329',	'2180327',	'2180328',	'2180334',	'2180335',	'1919508',	'1919503',	'1919512',	'1919516',	'1919509',	'1919510',	'1919515',	'1919507',	'1919504',	'1919506',	'1919505',	'1919511',	'1307304',	'1307298',	'1307309',	'1307305',	'1307306',	'1307303',	'1307299',	'1307302',	'1307300',	'1307301',	'1307307',	'1307308',	'2123132',	'2123125',	'2123141',	'2123137',	'2123145',	'2123133',	'2123140',	'2123144',	'2123134',	'2123131',	'2123139',	'2123143',	'2123127',	'2123138',	'2123142',	'2123130',	'2123128',	'2123129',	'2123135',	'2123136',	'151722',	'4126',	'1803018',	'1803015',	'1803016',	'308096',	'1721592',	'1721593',	'1151587',	'1803017',	'1243005',	'1242999',	'1243010',	'1243014',	'1243006',	'1243013',	'1243007',	'1243012',	'1243004',	'1243000',	'1243011',	'1243003',	'1243001',	'1243002',	'1243008',	'1243009',	'845509',	'141704',	'998191',	'1310144',	'1310147',	'1310138',	'1119402',	'845518',	'845512',	'1119401',	'845510',	'845517',	'998190',	'1869515',	'1869520',	'845511',	'1869516',	'1308430',	'845515',	'845507',	'1119400',	'1308428',	'998189',	'1308432',	'1119399',	'845505',	'845514',	'998188',	'1869512',	'1869518',	'845506',	'1869513',	'1163786',	'1163787',	'1308426',	'1172066',	'1172067',	'1310137',	'1792372',	'1604352',	'2054157',	'1604384',	'1604395',	'1604350',	'1792393',	'1796665',	'2054159',	'2054158',	'1604351',	'2054156',	'1604383',	'1604394',	'1796664',	'1792392',	'1604349',	'1603296',	'1792377',	'1796538',	'1792373',	'1796537',	'1792374',	'1604345',	'1604348',	'1604341',	'1604347',	'1604344',	'1604342',	'1604343',	'1792375',	'1792376',	'352619',	'42375',	'203217',	'825333',	'825334',	'825335',	'825325',	'583426',	'583431',	'583436',	'825324',	'752894',	'752899',	'752889',	'752884',	'583424',	'583429',	'583434',	'727599',	'1163443',	'1173874',	'1597588',	'1597582',	'1597593',	'1942485',	'1942489',	'1597589',	'1942483',	'1942488',	'1597590',	'1942484',	'1942482',	'1942487',	'1597587',	'1597583',	'1942480',	'1942486',	'1597586',	'1942481',	'1597584',	'1597585',	'1597591',	'1597592',	'1862585',	'1862579',	'1862578',	'1921589',	'1862590',	'1862595',	'1862586',	'1862594',	'1921588',	'1862587',	'1921587',	'1862593',	'1862584',	'1862580',	'1862592',	'1921586',	'1862583',	'1862581',	'1862582',	'1862588',	'1862589',	'905054',	'38782',	'338529',	'905060',	'905064',	'905057',	'905059',	'1863373',	'1863378',	'1863382',	'1863374',	'905053',	'199821',	'905062',	'1863370',	'1863376',	'1863380',	'1863371',	'1159353',	'1179671')
	and prescribing.rx_order_date BETWEEN to_date('2014-01-01','YYYY-MM-DD') and to_date('2017-12-31','YYYY-MM-DD')
),
cancer_exclude as
(
	select patid from cancer_dx
	UNION
	select patid from cancer_rx

),
surgery as
(
    select
        procedures.patid,
        procedures.encounterid,
        procedures.px_date,
        procedures.px
    from
        cohort
        join procedures on cohort.patid = procedures.patid
        join UNC_TRACSDATA.cc_1171_surgery cc_1171_surgery on procedures.px = cc_1171_surgery.px
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
		and cohort.patid NOT in (select patid from cancer_exclude)
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
		and cohort.patid NOT in (select patid from cancer_exclude)
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
		and cohort.patid NOT in (select patid from cancer_exclude)

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
		and cohort.patid NOT in (select patid from cancer_exclude)		
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
	where
		cohort.patid NOT in (select patid from cancer_exclude)		
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
non_surgery_ed_encounter as
(
		select distinct
			encounter.*
			--surgery.px_date
		from
			cohort
			-- first encounter
			join encounter  on cohort.patid = encounter.patid
			left outer join surgery on encounter.patid = surgery.patid and encounter.admit_date between  surgery.px_date and surgery.px_date + 14
		where
			encounter.enc_type='ED' 
			and encounter.admit_date between to_date('2014-01-01','YYYY-MM-DD') and to_date('2017-12-31','YYYY-MM-DD')
			and surgery.px_date is null
),
-- inclusion 5
-- 3+ ED visits with opioid RX in 30 day window
-- minus ED visits where surgery was performed up to two weeks before visit
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
			join non_surgery_ed_encounter enc1 on cohort.patid = enc1.patid and enc1.enc_type='ED' and enc1.admit_date between to_date('2014-01-01','YYYY-MM-DD') and to_date('2017-12-31','YYYY-MM-DD')
			join opioid_prescribing rx1 on enc1.encounterid = rx1.encounterid
			-- second encounter
			join non_surgery_ed_encounter enc2 on cohort.patid = enc2.patid and enc2.enc_type='ED' and enc2.admit_date between to_date('2014-01-01','YYYY-MM-DD') and to_date('2017-12-31','YYYY-MM-DD')
				and enc2.admit_date between enc1.admit_date and enc1.admit_date+30
			join opioid_prescribing rx2 on enc2.encounterid = rx2.encounterid
			-- third encounter
			join non_surgery_ed_encounter enc3 on cohort.patid = enc3.patid and enc3.enc_type='ED' and enc3.admit_date between to_date('2014-01-01','YYYY-MM-DD') and to_date('2017-12-31','YYYY-MM-DD')
				and enc3.admit_date between enc1.admit_date and enc1.admit_date+30
			join opioid_prescribing rx3 on enc3.encounterid = rx3.encounterid
			
		where
			enc1.encounterid <> enc2.encounterid
			and enc1.encounterid <> enc3.encounterid
			and enc2.encounterid <> enc3.encounterid
			and enc1.admit_date <> enc2.admit_date
			and enc1.admit_date <> enc3.admit_date
			and enc2.admit_date <> enc3.admit_date		
			and cohort.patid NOT in (select patid from cancer_exclude)
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

--	)

