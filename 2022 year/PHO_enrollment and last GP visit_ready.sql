/**************************************************************************************************
Title: PHO enrolment
Author: Craig Wright
Modified D Young

Acknowledgements:
Informatics for Social Services and Wellbeing (terourou.org) supported the publishing of these definitions

Inputs & Dependencies:
- [IDI_Clean].[moh_clean].[nes_enrolment]
Outputs:
- [IDI_Sandpit].[DL-MAA2020-37].[defn_pho_enrollment]

Description:
Enrolment with Primary Health Organisation (PHO).

Intended purpose:
Create variable reporting pho enrolment and whether a doctors visit occured in the past year.


Parameters & Present values:
  Current refresh = 202406
  Prefix = vacc_
  Project schema = DL-MAA2016-23
  Snapshot month = '20200101'
 
Notes:
	There is an enrolment status code with two values: ENROL and PRE. I have not been able to find a data dictionary to explan these variables,
	however analysis of the data and desktop research shows that PRE is likely to be pre-enrolment before they can be enrolled.
	
	Desktop research suggests that when first born, primary healthcare providers receive a notification of birth and enrol the newborn with a 'pre-enrolled' or "B enrolment" 
	status for 3 months, after which it expires in NES unless updated to "Enrolled" by completion of the enrolment process.

	Given this, I have included this code.

	There is not data for the new NES enrolment table. The old PHO enrolment table metadata warned that there was a cutoff for GP visits before the snapshot date. Inspection of the
	new data suggests that this is no longer the case.

History (reverse order):
2023-09-20 DY rebuild for ICM work.
2023-03-27 DY compared with SWA Github version - same logic.
2022-04-13 JG Updated project and refresh for Data for Communities
2021-11-25 SA tidy
2021-10-12 CW
**************************************************************************************************/

-- set variables
:setvar targetdb "IDI_Sandpit"
:setvar projectschema "DL-MAA2016-23"
:setvar idicleanversion "IDI_Clean_202406"
:setvar refdate "'2023-01-01'" 

-- derived variables
:setvar snapshotdate 20230101


/* remove */
DROP TABLE IF EXISTS #pho;

/* create */
SELECT snz_uid
	,1 AS pho_enrollment
	,IIF(moh_nes_last_consult_date BETWEEN DATEADD(YEAR,-1,$(refdate)) AND $(refdate),1,NULL) AS gp_visit_last_year
INTO #pho
FROM [IDI_Clean_202406].[moh_clean].[nes_enrolment]
WHERE [moh_nes_snapshot_month_date] = $(snapshotdate) -- latest date in the 202310 refresh
	AND moh_nes_enrolment_status_code in ('ENROL','PRE')
	AND moh_nes_enrolment_date <= $(refdate)


ALTER TABLE [IDI_Sandpit].[DL-MAA2016-23].[icm_master_table] DROP COLUMN IF EXISTS pho_enrollment, COLUMN IF EXISTS gp_visit_last_year;
ALTER TABLE [IDI_Sandpit].[DL-MAA2016-23].[icm_master_table] ADD pho_enrollment bit, gp_visit_last_year bit;
GO

UPDATE
	[IDI_Sandpit].[DL-MAA2016-23].[icm_master_table]
SET
	pho_enrollment = pho.pho_enrollment,
	gp_visit_last_year = pho.gp_visit_last_year
FROM 
	#pho pho
	WHERE [IDI_Sandpit].[DL-MAA2016-23].[icm_master_table].snz_uid = pho.snz_uid

