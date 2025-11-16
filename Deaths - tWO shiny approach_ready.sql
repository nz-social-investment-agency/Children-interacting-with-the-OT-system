/***
Title: Deaths (vehicle and self-inflicted)
Author:D Young

Inputs & Dependencies:
	- data.personal_detail
	- cyf_clean.cyf_placements_event
	- cyf_clean.cyf_placements_details
	- cyf_clean.cyf_dt_cli_legal_status_cys_d
	- cyf_clean.cyf_ev_cli_legal_status_cys_f
	- cyf_clean.cyf_ev_cli_fgc_cys_f
	- cyf_clean.cyf_dt_cli_fgc_cys_d
	- cyf_clean.cyf_ev_cli_fwas_cys_f
	- cyf_clean.cyf_dt_cli_fwas_cys_d
	- cyf_clean.cyf_intakes_event
	- cyf_clean.cyf_intakes_details
	- moh_clean.mortality_registrations

Outputs:
No output tables are saved.

The resulting table is intended to be saved and used for counts of the number of people from the cohort who are no LONGER with us.
Care should be had in drawing conclusions - the data has been constructed to produce counts, not rates, and the Grouping reflects lifetime experiences. Because OT deals with a population
with high needs care should also be had in drawing any inferences about the effect of care as the general population may not be the appropriate comparison group.

Description:
The first part of this code sets out a definition of self-inflicted deaths. This applies the code mapping, for self-inflicted deaths and vehicular deaths, set out in the Te
Whatu Ora shiny app. Note that this code mapping also includes codes for Cancer, Ischaemic Heart Disease, Cerebrovascular Disease, Chronic lower respiratory disease,
other forms of heart disease, Influenza and pneumonia, diabetes mellitus, and assault.

The second part engages in some data wranging for birth cohorts and OT interactions. The intention is to group by the highest 

The third part joins the data together. It may be helpful to view this part in order to see how the table is joined, as it is a reasonably complex join.

The fourth part summarises the data.


Notes:
 -- Age_Band is the age at death (+/- 1 month). These have been grouped in order to help ensure adequate group sizes, since self-harm especially is relatively rare at a population level
 -- n_ppl is the count of distinct snz_uids and should be suppressed where it is less than 6 and then suppressed.
 -- n_ent is the count of distinct facility codes (moh_mor_health_facility_code). Data should be suppressed where this is less than 2.
 -- Self-harm has been identified using the moh_mor_icd_d_code. This corresponds to an ICD10 code (between ~2002 and 2020) which records the underlying cause of death. 
	This is defined by the World Health Organization (WHO) as “the disease or injury which initiated the train of morbid events leading directly to death or the 
	circumstances of the accident or violence which produced the fatal injury.”
	Self-harm in this context means an ICD10 code of X60-X84, or Y870. This records intentional self harm (X) or sequelae of such events (Y870). In contrast, the self-harm indicator
	for non-fatal self harm also includes self-injury or self-poisoning of indeterminate intention (ie, not clear whether it is accidental or intentional).

 -- Earlier events are not currently included as the coding system is unclear (does not appear to be ICD). 
	Note that there is also a field that records other active diagnoses, within the diagnosis table as well as quick reference indicators for alcohol, prescribed pharmaceutical, and
	drug use. However, thse have not been used in this case.
 -- Mortality data is out of date (the most recent, as of the 202406 refresh, is 2020. As a result, we only have data up until 2020 which limits our population to 28 year olds.


Parameters & Present values:
  Current refresh = 202406

History (reverse order):
2024-10-14 DY created initial draft


Run time: 
- <1 min





***/

/*** Part 1: setting up ICD codes of interest
NB currently use 6 ICD system codes (06,11,12,13,14,15)
SELECT DISTINCT moh_mort_diag_clinic_sys_code FROM IDI_Clean_202406.moh_clean.mortality_diagnosis ORDER BY moh_mort_diag_clinic_sys_code

This establishes a table with the following structure:
	[icd_classification_description] VARCHAR(5) -	records whether the classification system is ICD9 or ICD10 in plaintext. This is for convenience.
	[icd_verision_code_start] VARCHAR(2) -			the first clinical system code that this rule applies to. Each ICD revision will have its own code.
													Rather than create identifcal rows for each revision, with only the clinical system code changed, we record the first
													and last revision that the rule applies to, and join on where the clinical system code is between the values. (The 
													BETWEEN statement includes the start and end values).
	[icd_verision_code_end] VARCHAR(2) -			The last clinical system code that this rule applies to.  See description of icd_version_code_start
	[icd_code_start] VARCHAR(8) -					The first ICD diagnosis code that the rule applies to. We truncate the code we are joining to the same length as the 
													start/end codes, and join on codes between the start and end values. (For example, V01-V10 would include V109).
													If the start and end code are not equal length, separate rows should be created in order for the join to work.
													For example, V01-V10.3 should be reflected as a row for V01 to V09 and a row for V10.0 to V10.3.
	[icd_code_end]  VARCHAR(8) -					The last ICD diagnosis code that the row applies to.
	icd_code_length TINYINT							The number of characters in the . This is used to set the length of the string we join on. This is calculated once and
													saved rather than be dynamically calculated (expected to be slower) during the join.
	[mortality_type] VARCHAR(48)					Description of the cause of death (the name we are grouping under).


-- NB. This produces very very close counts to the Te Whatu Ora mortality data series for the identified categories. The total
-- counts are also very close.

-- After running the definition, run the code below to get counts by year of registration and modality.
DROP TABLE IF EXISTS #test;
SELECT moh_mor_registration_year_nbr
				,IIF(cla.mortality_type IS NULL, 'Other cause',cla.mortality_type) AS mortality_type
				,COUNT(DISTINCT snz_uid) n
INTO #test
FROM IDI_Clean_202406.moh_clean.mortality_registrations reg
LEFT JOIN IDI_Clean_202406.moh_clean.mortality_diagnosis dia
	ON dia.snz_dia_death_reg_uid = reg.snz_dia_death_reg_uid
		AND dia.moh_mort_diag_clinical_code = reg.moh_mor_icd_d_code
		AND moh_mort_diag_diag_type_code = 'D'
LEFT JOIN #icd_classification cla
	ON dia.moh_mort_diag_clinic_sys_code BETWEEN cla.icd_verision_code_start AND cla.icd_verision_code_end
		AND LEFT(reg.moh_mor_icd_d_code,icd_code_length) BETWEEN cla.icd_code_start AND cla.icd_code_end
GROUP BY  moh_mor_registration_year_nbr,IIF(cla.mortality_type IS NULL, 'Other cause',cla.mortality_type)

***/

DROP TABLE IF EXISTS #icd_classification;
CREATE TABLE #icd_classification (
	[icd_classification_description] VARCHAR(5),
	[icd_verision_code_start] VARCHAR(2),
	[icd_verision_code_end] VARCHAR(2),
	[icd_code_start] VARCHAR(8),
	[icd_code_end]  VARCHAR(8), 
	icd_code_length TINYINT,
	[mortality_type] VARCHAR(48)
		);

INSERT INTO #icd_classification (icd_classification_description,icd_verision_code_start, icd_verision_code_end, icd_code_start, icd_code_end,icd_code_length, mortality_type)
VALUES 
-- self-harm
    ('ICD9','06', '06','950','959',3,'Self-harm'),
	('ICD10','11','15','X60','X84',3,'Self-harm'),
--motor-vehicle
	('ICD9','06', '06','810','825',3,'Vehicle'),
	('ICD10','11','15','V02','V04',3,'Vehicle'),
	('ICD10','11','15','V12','V14',3,'Vehicle'),
	('ICD10','11','15','V20','V79',3,'Vehicle'),
	('ICD10','11','15','V090','V093',4,'Vehicle'),
	('ICD10','11','15','V190','V192',4,'Vehicle'),
	('ICD10','11','15','V194','V196',4,'Vehicle'),
	('ICD10','11','15','V803','V805',4,'Vehicle'),
	('ICD10','11','15','V810','V811',4,'Vehicle'),
	('ICD10','11','15','V8220','V821',4,'Vehicle'),
	('ICD10','11','15','V830','V833',4,'Vehicle'),
	('ICD10','11','15','V840','V843',4,'Vehicle'),
	('ICD10','11','15','V850','V853',4,'Vehicle'),
	('ICD10','11','15','V860','V878',4,'Vehicle'),
	('ICD10','11','15','V880','V888',4,'Vehicle'),
	('ICD10','11','15','V890','V890',4,'Vehicle'),
	('ICD10','11','15','V892','V899',4,'Vehicle'),
-- cancer
	('ICD9','06', '06','140','208',3,'All cancer'),
	('ICD10','11','15','C00','C96',3,'All cancer'),
	('ICD10','11','15','D45','D47',3,'All cancer'), -- This does not appear to have been used by MoH for deaths registered between 2000 and 2002, only from 2003.
-- Ischaemic Heart Disease
	('ICD9','06', '06','410','414',3,'Ischaemic heart disease'),
	('ICD10','11','15','I20','I25',3,'Ischaemic heart disease'),
-- Cerebrovascular disease
	('ICD9','06', '06','430','438',3,'Cerebrovascular disease'),
	('ICD10','11','15','I60','I69',3,'Cerebrovascular disease'),
-- Chronic lower respiratory disease
	('ICD9','06', '06','490','496',3,'Chronic lower respiratory disease'),
	('ICD10','11','15','J40','J47',3,'Chronic lower respiratory disease'),
-- Other forms of heart disease
	('ICD9','06', '06','420','429',3,'Other forms of heart disease'),
	('ICD10','11','15','I30','I52',3,'Other forms of heart disease'),
-- Influenza and pneumonia
	('ICD9','06', '06','480','487',3,'Influenza and pneumonia'),
	('ICD10','11','15','J10','J18',3,'Influenza and pneumonia'),
-- Diabetes mellitus
	('ICD9','06', '06','250','250',3,'Diabetes mellitus'),
	('ICD10','11','15','E10','E14',3,'Diabetes mellitus'),
-- Assault
	('ICD9','06', '06','960','969',3,'Assault'),
	('ICD10','11','15','X85','Y09',3,'Assault');


-- The join of mortality registrations onto diagnosis is a little awkward.
-- What we really want from this is to capture the ICD code version in order to join to our classification framework
-- Joining on the diag code itself (for diag type = D) works. It removes an insignificant number of rows (where for some reason the registrations and diagnosis
-- table differ on the cause, and does not produce duplicates.
-- However, we could also look at just taking the distinct ICD version code. This is unlikely to be mixed for a single registration


DROP TABLE IF EXISTS #pop;
SELECT DISTINCT snz_uid 
INTO #pop
FROM IDI_Clean_202406.dia_clean.births
WHERE dia_bir_birth_year_nbr BETWEEN 1992 AND 1995;

-- Status is the OT status of individuals
DROP TABLE IF EXISTS #status;
WITH 
	placements AS
		(SELECT DISTINCT snz_uid, 'Placement' AS interaction, CASE WHEN cyf_pld_placement_type_code IN ('RESCJP','RESNON','RESYJ','RMNDHM') THEN 5 ELSE 4 END AS [priority]
		FROM IDI_Clean_202406.cyf_clean.cyf_placements_event pla_ev
		LEFT JOIN IDI_Clean_202406.cyf_clean.cyf_placements_details pla_dt
		ON pla_dt.snz_composite_event_uid = pla_ev.snz_composite_event_uid
			WHERE [cyf_ple_event_from_date_wid_date] <= '2022-12-31'
				AND cyf_pld_placement_type_code IN ('RESCJP','RESNON','RESYJ','RMNDHM', 
													'CFSS', 'CYP', 'IWI', 'PSS', 'WHA', 'FAM','WCP', 'BRD', 'SGHP',
													'RESCP', 'RESIDCR', 'RESMHA',	-- respite care
													'INDEP', 'YOOC', 'YSFHCD', 'YSFHSA', 'AKCOMMRESISVC', 'KAAHUIWHETUU')),
	 supervision AS
		(SELECT DISTINCT snz_uid, 'supervision' AS interaction, 3 AS [priority]
			FROM IDI_Clean_202406.cyf_clean.cyf_dt_cli_legal_status_cys_d d
			LEFT JOIN IDI_Clean_202406.cyf_clean.cyf_ev_cli_legal_status_cys_f f
			ON d.snz_composite_event_uid = f.snz_composite_event_uid
				WHERE [cyf_lse_event_from_date_wid_date] <= '2022-12-31'
					AND cyf_lsd_legal_status_code in ('S283K','S307','S3074')),
	 FGC AS
		(SELECT DISTINCT snz_uid, 'FGC' AS interaction, CASE WHEN cyf_fgd_business_area_type_code = 'YJU' THEN 3 WHEN cyf_fgd_business_area_type_code = 'CNP' THEN 2 ELSE NULL END AS [priority]
			FROM IDI_Clean_202406.cyf_clean.cyf_ev_cli_fgc_cys_f fgc_ev
			LEFT JOIN IDI_Clean_202406.cyf_clean.cyf_dt_cli_fgc_cys_d fgc_dt
			ON fgc_dt.snz_composite_event_uid = fgc_ev.snz_composite_event_uid
				WHERE cyf_fge_event_from_datetime <= '2022-12-31'),
	 FWA AS
		(SELECT DISTINCT snz_uid, 'FWA' AS interaction, CASE WHEN cyf_fwd_business_area_type_code = 'YJU' THEN 3 WHEN cyf_fwd_business_area_type_code = 'CNP' THEN 2 ELSE NULL END AS [priority]
			FROM IDI_Clean_202406.cyf_clean.cyf_ev_cli_fwas_cys_f fwa_ev
			LEFT JOIN IDI_Clean_202406.cyf_clean.cyf_dt_cli_fwas_cys_d fwa_dt
			ON fwa_dt.snz_composite_event_uid = fwa_ev.snz_composite_event_uid
				WHERE [cyf_fwe_event_from_date_wid_date] <= '2022-12-31'),

	 cfa AS
		(SELECT DISTINCT snz_uid, 'CFA' AS interaction, 2 AS [priority]
			from IDI_Clean_202406.cyf_clean.cyf_intakes_event int_ev
			left join IDI_Clean_202406.cyf_clean.cyf_intakes_details int_dt
			on int_ev.snz_composite_event_uid = int_dt.snz_composite_event_uid
				WHERE cyf_ine_event_to_datetime <= '2022-12-31'
					AND cyf_ind_business_area_type_code = 'CNP'
					AND cyf_ind_final_outcome_type_code IN ('FAR','CFA','FARCFA','INV')),

	roc AS
		(SELECT DISTINCT snz_uid, 'Concerns raised' AS interaction, 1 AS [priority]
		from IDI_Clean_202406.cyf_clean.cyf_intakes_event int_ev
			left join IDI_Clean_202406.cyf_clean.cyf_intakes_details int_dt
			on int_ev.snz_composite_event_uid = int_dt.snz_composite_event_uid
				WHERE cyf_ine_event_to_datetime <= '2022-12-31'
					AND cyf_ind_business_area_type_code = 'CNP'),
			
	IDS_prec AS (SELECT snz_uid, [priority]
			FROM cfa
			UNION
			SELECT snz_uid, [priority]
			FROM FWA
			UNION
			SELECT snz_uid, [priority]
			FROM FGC
			UNION
			SELECT snz_uid, [priority]
			FROM supervision
			UNION
			SELECT snz_uid, [priority]
			FROM placements
			UNION
			SELECT snz_uid, [priority]
			FROM roc
			)
	,IDS AS (SELECT snz_uid, MAX([priority]) [priority]
			FROM IDS_prec
			GROUP BY snz_uid)
	SELECT ids.snz_uid
			,[priority]
	INTO #status
	FROM IDS 
	WHERE EXISTS (SELECT 1 FROM #pop p WHERE IDS.snz_uid = p.snz_uid);
GO


-- Mort is deaths from our population. 
DROP TABLE IF EXISTS #mort;
SELECT snz_uid
				,moh_mor_registration_year_nbr
				,DATEFROMPARTS(moh_mor_death_year_nbr,moh_mor_death_month_nbr,1) AS dod
				,moh_mor_icd_d_code
				,moh_mor_occupation_text
				,moh_mor_dth_locn
--				,CLINICAL_CODE_DESCRIPTION
				,IIF(cla.mortality_type IS NULL, 'Other cause',cla.mortality_type) AS mortality_type
INTO #mort
FROM IDI_Clean_202406.moh_clean.mortality_registrations reg
LEFT JOIN IDI_Clean_202406.moh_clean.mortality_diagnosis dia
	ON dia.snz_dia_death_reg_uid = reg.snz_dia_death_reg_uid
		AND dia.moh_mort_diag_clinical_code = reg.moh_mor_icd_d_code
		AND moh_mort_diag_diag_type_code = 'D'
--LEFT JOIN [IDI_Metadata].[clean_read_CLASSIFICATIONS_CLIN_DIAG_CODES].[clinical_codes]
--	ON moh_mor_icd_d_code = clinical_code
--		AND moh_mort_diag_clinic_sys_code = CLINICAL_CODE_SYSTEM
LEFT JOIN #icd_classification cla
	ON dia.moh_mort_diag_clinic_sys_code BETWEEN cla.icd_verision_code_start AND cla.icd_verision_code_end
		AND LEFT(reg.moh_mor_icd_d_code,icd_code_length) BETWEEN cla.icd_code_start AND cla.icd_code_end
WHERE EXISTS (SELECT 1 FROM #pop p WHERE p.snz_uid = reg.snz_uid)



-- #pop is everyone born within the period of interest
-- #status is the OT status of everyone in this group
-- #mort is mortality events for this group

SELECT CASE WHEN PRIORITY IN (4,5) THEN 'Custody (either)'
			WHEN PRIORITY = 3 THEN 'YJ intervention'
			WHEN PRIORITY = 2 THEN 'C&P intervention'
			WHEN PRIORITY = 1 THEN 'Concerns raised'
			ELSE 'No OT Contact' END AS Lifetime_status
		,snz_ethnicity_grp2_nbr
--		,snz_sex_gender_code
		,CASE WHEN m.snz_uid IS NULL THEN 'Alive'
				WHEN mortality_type in ('Self-harm','Vehicle') THEN mortality_type
				ELSE 'Other cause' END AS Cause_of_Death
--		,IIF(m.DOD IS NOT NULL, DATEDIFF(MONTH,pd.snz_birth_date_proxy,m.dod)/12, DATEDIFF(MONTH,pd.snz_birth_date_proxy,'2022-12-31')/12) Age
		,COUNT(DISTINCT p.snz_uid) n
FROM #pop p
LEFT JOIN #mort m
	ON p.snz_uid = m.snz_uid
LEFT JOIN #Status s
	ON p.snz_uid = s.snz_uid
LEFT JOIN IDI_Clean_202406.data.personal_detail pd
	ON pd.snz_uid = p.snz_uid
GROUP BY  CASE WHEN PRIORITY IN (4,5) THEN 'Custody (either)'
			WHEN PRIORITY = 3 THEN 'YJ intervention'
			WHEN PRIORITY = 2 THEN 'C&P intervention'
			WHEN PRIORITY = 1 THEN 'Concerns raised'
			ELSE 'No OT Contact' END
		,snz_ethnicity_grp2_nbr
--		,snz_sex_gender_code
		,CASE WHEN m.snz_uid IS NULL THEN 'Alive'
				WHEN mortality_type in ('Self-harm','Vehicle') THEN mortality_type
				ELSE 'Other cause' END
--		,IIF(m.DOD IS NOT NULL, DATEDIFF(MONTH,pd.snz_birth_date_proxy,m.dod)/12, DATEDIFF(MONTH,pd.snz_birth_date_proxy,'2022-12-31')/12)


SELECT CASE WHEN PRIORITY IN (4,5) THEN 'Custody'
			WHEN PRIORITY IN (1,2,3) THEN 'OT contact'
			ELSE 'No OT Contact' END AS Lifetime_status
		,snz_ethnicity_grp2_nbr
		,snz_sex_gender_code
		,CASE WHEN m.snz_uid IS NULL THEN 'Alive'
				WHEN mortality_type in ('Self-harm','Vehicle') THEN mortality_type
				ELSE 'Other cause' END AS Cause_of_Death
--		,IIF(m.DOD IS NOT NULL, DATEDIFF(MONTH,pd.snz_birth_date_proxy,m.dod)/12, DATEDIFF(MONTH,pd.snz_birth_date_proxy,'2022-12-31')/12) Age
		,COUNT(DISTINCT p.snz_uid) n
FROM #pop p
LEFT JOIN #mort m
	ON p.snz_uid = m.snz_uid
LEFT JOIN #Status s
	ON p.snz_uid = s.snz_uid
LEFT JOIN IDI_Clean_202406.data.personal_detail pd
	ON pd.snz_uid = p.snz_uid
GROUP BY CASE WHEN PRIORITY IN (4,5) THEN 'Custody'
			WHEN PRIORITY IN (1,2,3) THEN 'OT contact'
			ELSE 'No OT Contact' END
		,snz_ethnicity_grp2_nbr
		,snz_sex_gender_code
		,CASE WHEN m.snz_uid IS NULL THEN 'Alive'
				WHEN mortality_type in ('Self-harm','Vehicle') THEN mortality_type
				ELSE 'Other cause' END
--		,IIF(m.DOD IS NOT NULL, DATEDIFF(MONTH,pd.snz_birth_date_proxy,m.dod)/12, DATEDIFF(MONTH,pd.snz_birth_date_proxy,'2022-12-31')/12)