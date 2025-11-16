/*** Self harm hospitalisations

Code prepared by: D Young
Date: 27-09-2024


Note: this code uses SQL Command Mode. To activate, select "Query" from the task bar, and then "SQLCMD Mode" (near the bottom of the list). This enables using variables to select IDI archive and output location.

Inputs:
	[IDI_Metadata].[clean_read_CLASSIFICATIONS_CLIN_DIAG_CODES].[clinical_codes]
	[IDI_Clean_202406].[moh_clean].[pub_fund_hosp_discharges_event]
	[IDI_Clean_202406].[moh_clean].[pub_fund_hosp_discharges_diag]

Outputs:
This is the records from the event table for events that were identified as a self-harm hospitalisation, and flags to identify where the purchaser code is overseas eligible or overseas chargeable; 
records where the patient district of domicile is Canterbury; records which record a transfer to that facility; and records where the patient is subsequently transferred elsewhere.

Purpose:
Identify young people in distress and coping with that distress in an unhealthy way, and who need help.
Apply the 

Notes:
This code produces an indicator for hospitalisations associated with self-harm. 

Self harm events are identified as public hospital events where:
- there is a S or T diagnosis code (injury or poisoning) within the first 30 diagnosis codes
- there is a code indicating intention to inflict self-injury (X60-X84 or Y870) or self-injury wtih undetermined intention (Y10-Y34, Y872) in the first 10 E (external cause) codes

Note that this relies on ICD coding being used, and users may wish to check that the provided codes are appropriate for their edition of ICD. It appears that changes to the editions occured around
the following times:
	- 2001 (moving to ICD-10-AM second edition)
	- 2004 (moving to ICD-10-AM third edition)
	- 2008 (moving to ICD-10-AM sixth edition)
	- 2014 (moving to ICD-10-AM eighth edition)
	- 2019 (moving to ICD-10-AM eleventh edition)

In a relatively small number of cases, a record may indicate that a patient has been transferred to another facility. This has the potential effect of increasing the count of events where patients are transferred, 
as the second facility will record another event id.

These additional records have been identified using the [moh_evt_facility_xfer_to_code] field which records the id of the facility the healthcare user was transferred to. The theory is that where this field is
empty, we can identify what should be the final treatment facility. Using the final treatment facility is consistent with how I understand MoH records events for their reporting (using the end date). However,
it should be possible to instead identify the first by identify where there was not a transfer from a previous facility using the [moh_evt_facility_xfer_from_code].

For the current purpose, we are interested in whether or not a person has experienced the event, rather than the number of events, which makes transfers less important. This could be investigated further
if reporting rates.

Overseas domiciled persons are excluded from MoH-published figures. The moh_evt_purchaser_code is used to identify and remove rows where the purchaser code is overseas chargeable or overseas eligible.
However, this only removes a minority of rows. Using a population definition for the resident population (as we have in the master table) (eg, APC ARP spells) could be used to exclude additional records.

Select and run the following to see the purchaser codes. Note that there are some private insurance codes listed in the purchaser codes, and it is not clear how an overseas domiciled person with insurance 
would be treated in this field. However, the numbers are not expected to be material.

SELECT * FROM IDI_Metadata_202406.moh_nmds.purchaser23_code

Private hospitalisations have a much smaller count of events, and the most recent data is older than public hospitalisation. At this time, they are not combined with public events given that (i) the difference
is not likely to be material; and (ii) it is expected that in most use cases the priority will be to have the most recent data possible. 

The results of this indicator were compared to self-harm figures published by MoH. In particular, breakdowns by age band for the 2022 year, and total counts for 2020,2021 and 2022.
A loose population definition, requiring someone to appear (for any length of time) in the apc apr spells table, for that year, was used. This produced a close match for most age bands.

Results were also briefly compared to a breakdown for 2020-22 by DHB of the healthcare user's domicile. The match was also thought to be fairly close for most DHBs, with some instances of larger variation. These have
not been resolved and care should be had when looking at sub-national populations. It may be attributable to a mismatch in how address has been determined, or that more sophisticated allocation rules for transfers 
are required, or that this reflects where the DHB and treatment facility differ (have not yet found a mapping of facilities to DBH).

Note also that Canterbury DHB has changed how data is recorded since December 2020. While some records are available in the IDI data, Canterbury has been excluded from MoH published figures and it is clear 
that there has been a break in the time series. A flag has been included for records where the patients domicile is in Canterbury DHB area. Depending on what users want to use this for, they may wish to 
exclude/include these records.
				
***/

:setvar idi_version IDI_Clean_202406
:setvar proj_schema DL-MAA2016-23
:setvar output_table icm_self_harm_events


DROP TABLE IF EXISTS #self_harm_intent_codes;
SELECT [CLINICAL_CODE_SYSTEM]
      ,[CLINICAL_SYSTEM_DESCRIPTION]
      ,[CLINICAL_CODE_TYPE]
      ,[CLINICAL_CODE_TYPE_DESCRIPTION]
      ,[CLINICAL_CODE]
      ,[CLINICAL_CODE_DESCRIPTION]
      ,[BLOCK]
      ,[BLOCK_SHORT_DESCRIPTION]
      ,[BLOCK_LONG_DESCRIPTION]
INTO #self_harm_intent_codes
FROM [IDI_Metadata].[clean_read_CLASSIFICATIONS_CLIN_DIAG_CODES].[clinical_codes]
WHERE CLINICAL_CODE_SYSTEM = 15
  AND [CLINICAL_CODE_TYPE] = 'E'
  AND (LEFT([CLINICAL_CODE],2) IN ('X6','X7','Y1','Y2')
		OR LEFT([CLINICAL_CODE],3) IN ('X80','X81','X82','X83','X84','Y30','Y31','Y32','Y33','Y34')
		OR LEFT([CLINICAL_CODE],4) IN ('Y870','Y872'))

-- Build a table of event ids
DROP TABLE IF EXISTS [IDI_Sandpit].[$(proj_schema)].[$(output_table)];

WITH reconciled_pub_events AS (
		SELECT moh_dia_event_id_nbr
				,ROW_NUMBER() OVER (PARTITION BY moh_dia_event_id_nbr ORDER BY CAST(moh_dia_diag_sequence_code AS INT)) AS first_30 -- we will use this to identify whether there is an S or T (injury or poisining) code in the first 30 diagnosis codes
				,ROW_NUMBER() OVER (PARTITION BY moh_dia_event_id_nbr, moh_dia_diagnosis_type_code ORDER BY CAST(moh_dia_diag_sequence_code AS INT)) AS first_10_e -- we will use this to identify the first 10 codes per letter
				,moh_dia_clinical_sys_code
				,moh_dia_submitted_system_code
				,moh_dia_diagnosis_type_code
				,moh_dia_clinical_code
		FROM [$(idi_version)].[moh_clean].[pub_fund_hosp_discharges_diag]
		WHERE [MOH_DIA_CLINICAL_SYS_CODE]=[MOH_DIA_SUBMITTED_SYSTEM_CODE]),
	
	pub_self_harm_event_ids AS (
		SELECT moh_evt_event_id_nbr 
		FROM [$(idi_version)].[moh_clean].[pub_fund_hosp_discharges_event]
		-- Where there is an S or T (injury or poisoning) clincial code in the first 30 clincial codes
		WHERE EXISTS (SELECT 1 
						FROM reconciled_pub_events
						WHERE moh_dia_event_id_nbr =  moh_evt_event_id_nbr 
							AND first_30 <= 30 
							AND (moh_dia_clinical_code LIKE 'S%' 
								OR  moh_dia_clinical_code LIKE 'T%'))
		-- Where there is a clinical code that denotes intentional self-harm or self-inflicted injury of indeterminate intention in the first 10 E-type codes
			AND EXISTS (SELECT 1 
						FROM reconciled_pub_events 
						WHERE moh_dia_event_id_nbr =  moh_evt_event_id_nbr 
							AND first_10_e <= 10 
							AND moh_dia_diagnosis_type_code = 'E'
							AND EXISTS (SELECT 1 
										FROM #self_harm_intent_codes 
										WHERE moh_dia_clinical_code = [CLINICAL_CODE] 
											AND moh_dia_clinical_sys_code = [CLINICAL_CODE_SYSTEM]))
					),
	
	pub_summary AS (
		SELECT *
		FROM [$(idi_version)].[moh_clean].[pub_fund_hosp_discharges_event] evt
		WHERE EXISTS (SELECT 1 
						FROM pub_self_harm_event_ids ids 
						WHERE evt.moh_evt_event_id_nbr = ids.moh_evt_event_id_nbr)
					)

SELECT *
		,IIF(moh_evt_purchaser_code IN ('19','20'),1, NULL) AS overseas_purchase_code_flag
		,IIF(moh_evt_dhb_dom_code = 121,1,NULL) AS Canterbury_dhb_dom_flag
		,IIF(moh_evt_facility_xfer_to_code IS NULL,NULL,1) AS transferred_out
		,IIF(moh_evt_facility_xfer_from_code IS NULL,NULL,1) AS transferred_in
INTO [IDI_Sandpit].[$(proj_schema)].[$(output_table)]
FROM pub_summary;
GO

/*** Quick summary for validation purposes 
-- The following code produces a summary of the data for 2020-2022
-- We will apply a filter to the transferred out column to select only 'not transferred'. This means that the last facility is the facility we count against
-- This is consistent with the approach of using end date for the dates

WITH 
	prec AS (SELECT TOP 3 snz_uid FROM IDI_Clean_202310.data.personal_detail), -- just used to get counts 
	years AS (SELECT 2019+row_number() OVER (PARTITION BY 1 ORDER BY snz_uid) YR FROM prec),
	pop AS (SELECT DISTINCT YR ,snz_uid 
			FROM (SELECT * FROM [$(idi_version)].data.apc_arp_spells WHERE apc_arp_spell_end_date >= '2020-01-01' AND apc_arp_spell_start_date <= '2022-12-31' ) apc -- pre-filter to rows within our period of interest
			LEFT JOIN years
				ON DATEFROMPARTS(years.YR,1,1) <= apc.apc_arp_spell_end_date 
					AND DATEFROMPARTS(years.YR,12,31) >= apc.apc_arp_spell_start_date),
	-- remove people not in population definition, and events where the purchaser code is overseas eligible/chargeable
	nz_res_only AS (SELECT dat.* FROM [IDI_Sandpit].[$(proj_schema)].[$(output_table)] dat
				INNER JOIN pop
				ON dat.snz_uid = pop.snz_uid
					AND pop.YR = YEAR(dat.moh_evt_even_date)
				WHERE overseas_purchase_code_flag IS NULL
			),
	pre_dat AS (
		SELECT pub.*
				,overseas_purchase_code_flag
				,Canterbury_dhb_dom_flag
				,transferred_out
				,transferred_in
		FROM nz_res_only
		LEFT JOIN [$(idi_version)].[moh_clean].[pub_fund_hosp_discharges_event] pub
			ON pub.moh_evt_event_id_nbr = nz_res_only.moh_evt_event_id_nbr
			),
	dat AS (
		SELECT 
			transferred_out -- look at transferred out and transferred in, to compare them
			,transferred_in -- look at transferred out and transferred in, to compare them
			,meta.DHB
			,DATEDIFF(MONTH,DATEFROMPARTS(moh_evt_birth_year_nbr,moh_evt_birth_month_nbr,1),moh_evt_even_date)/12 AS Age
			,moh_evt_sex_snz_code
			,moh_evt_ethnic_grp2_snz_ind
	--		,moh_evt_ethnic_grp3_snz_ind
			,YEAR(moh_evt_even_date) AS YR
			,count(DISTINCT hosp.moh_evt_event_id_nbr) n
		FROM pre_dat hosp
		LEFT JOIN IDI_Metadata_202406.moh_nmds.dhb23_code meta
		ON meta.DHB_CODE = hosp.moh_evt_dhb_dom_code
		GROUP BY 
			transferred_out -- look at transferred out and transferred in, to compare them
			,transferred_in,meta.DHB
			,DATEDIFF(MONTH,DATEFROMPARTS(moh_evt_birth_year_nbr,moh_evt_birth_month_nbr,1),moh_evt_even_date)/12
			,moh_evt_sex_snz_code
			,moh_evt_ethnic_grp2_snz_ind
	--		,moh_evt_ethnic_grp3_snz_ind
			,YEAR(moh_evt_even_date)
			)
SELECT *
		,IIF(Age >=85,'85+',CONCAT(Age/5*5,'-',(Age/5+1)*5-1)) AS age_band
FROM dat

***/