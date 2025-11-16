
/*** Disability 

This code combines different sources that indicate someone is experiencing disability.
This includes:
	(1) SIA Functional Disability indicator (this is a lower threshold than other sources)
	(2) Whaikaha clients (Socrates - Whaikaha's CMS)
	(3) Recipients of education funding (Student Intervention (ORS or High Health Need fund receipt))
	(4) Children that Child Disability Allowance is paid on behalf of
	(5) Recipients of Disability allowance
	(6) Recipients of Invalids Benefit/ Supported Living Payment (excluding SLP Carers)
	   	
Notes from the MSD Income Support Payements Code module and WINZ website:
	Special Disability Allowance is to cover the costs of travel for people on pension/main benefit to visit their partner in hospital (expected stay
	of 13 weeks) or who is getting the Residential Care Subsidy - so not relevant for our purposes.
	Modification Grant - provided to persons with disabilities lasting more than six months that helps with the costs of special equipment for work 
	or changes to a workplace. [Cannot find in benefits]
	Invalid's Benefit and Supported Living Payment - Main benefits for persons with long term illness or disability or person caring for such a person.
	(We do not include SLP Carers (these are identified).)
				

-- Final tables used:

•	[IDI_Clean].[cen_clean].[census_individual_2018]
•	[IDI_Clean].[security].[concordance]
•	[IDI_Clean].[gss_clean].[gss_person]
•	[IDI_Clean].[moh_clean].[interrai] -- commented out - not available for this project
•	[IDI_Adhoc].[clean_read_HLFS].[hlfs_disability]
•	[IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_support_needs_2022]
•	[IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_needs_assessment_2022]
•	[IDI_Adhoc].[clean_read_moh_socrates].[moh_client]	
•	$(idicleanversion).moe_clean.student_intervention
•	[IDI_Adhoc].[clean_read_MSD].[msd_scdaco_202309]
•	[IDI_Clean_YYYYMM].[msd_clean].[msd_spell]
•	[IDI_Clean_YYYYMM].[msd_clean].[msd_partner]
•	[IDI_Clean_YYYYMM].[msd_clean].[msd_first_tier_expenditure]
•	[IDI_Clean_YYYYMM].[msd_clean].[msd_second_tier_expenditure]
•	[IDI_Clean_YYYYMM].[msd_clean].[msd_third_tier_expenditure]



Our population table:

SELECT TOP 100 * FROM IDI_Sandpit.[$(projectschema)].[icm_master_table]

***/


-- (1) Craigs Functional Disability indicator

/***************************************************************************************************************************
Title: Functional disability
Author: Craig Wright
Reviewer: Simon Anastasiadis

Description:
Multi-source indicator of functional disability

NOTE: This definition has been further modified for the D4C project to:
- Remove 'missing' responses from the data (set these to null)
- Across each of the six measures, and "any disability" indicator, produce spells from each observation (eg, survey, census) until the day before next next observation
- Save each measure as a view in order to be compatible with reporting through the DAT
- This code takes about 10m to run

Intended purpose:
Measuring disability is a complex and still evolving issue. There is no perfect way to classify people into categories and no full agreement amongst the disabled community on the language to be used. 
However, it is important for the disabled community, researchers, and policy makers to have some standard way to describe varying levels of participation as citizens, clients, or consumers of services.


## Key concepts

Disability is a social construct that arises through the combination of two things:
1.	The limitations some people have in completing some activities.
2.	The barriers that exist in a person’s environment (or society in general) that limit participation.

Information about the barriers or accommodations people experience is currently not available in administrative data. 
However, there are some sources data that include functional limitations that some people have. 
Hence, one approach is to use functional limitations to identify groups who are more likely to be disabled.


## Practical notes

The indicator is based on the Washington Group Short Set (WGSS) questions on functioning. The WGSS is a series of six questions about difficulties people might encounter doing everyday things:
•	Walking
•	Seeing
•	Hearing
•	Remembering
•	Washing
•	Communication

However, not everyone has answered these questions, and some people might have acquired impairments after the questions were asked. 
We have supplemented these questions with data from some Ministry of Health collections: SOCRATES, which captures functional assessments for disability clients; 
and InterRAI, which captures similar information for older people. 

In collaboration with experts in the disabled community, the Ministry of Health and Office for Disability Issues, we have aligned each of these data sources, resulting in a three-level indicator for each of the six functional activities: 
•	0 = No limitation: This group does not report any limitations in undertaking everyday tasks. They are unlikely to be disabled.
•	1 = Low functional limitation: This group reports some difficulty with everyday tasks. They are somewhat likely to be disabled.
•	2 = High functional limitation: This group reports a lot of difficulty with everyday tasks or cannot do them at all. They are very likely to be disabled.

Following guidance from the Washington Group (2020), we have also produced one overall indicator for disability status. 
This takes the value of ‘disabled’ if the person had high functional limitation in at least one activity, and ‘not disabled’ otherwise. 
(This overall indicator is consistent with how many agencies, such as Stats NZ, are already using the WGSS to report on outcomes for disabled people.)


## How to use this indicator

•	Involve disabled people in your research, including when designing your approach and interpreting your results.
•	Use it to compare outcomes, not to estimate the size of groups. This indicator is not suitable for counting the disabled population. 
The official measure of the disabled population in New Zealand is derived from the Disability Survey undertaken by Stats NZ. 
Use of this definition should be constrained to comparisons between groups, rather than discussing the size of those groups.
•	Adjust for age in your analysis. There is a very strong relationship between age and functional impairment. 
To account for this, we recommend adjusting for age when comparing between functional groups (at minimum, reporting separately those below and above the age of 65).


## Limitations of this indicator

•	The indicator is not as accurate and comprehensive as the measure of disability in the Disability Survey. It is not a replacement for the official measure from the Disability Survey.
•	The Washington Group Short Set (WGSS) is not a fully comprehensive measure of functional limitations.
•	For children under 12, the WGSS is less sensitive at moderate levels of functional limitation. The WGSS is also not collected for children under the age of five.
•	The indicator may capture people who are disabled only temporarily. These people may have very different experiences to people who have permanent or ongoing impairments.


## Other notes

•	The indicator might be expanded in the future to use WGSS responses from the NZCVS and specific modules of the HES. However, the coverage of both sources is limited.
•	We investigated using Hospital diagnoses and ACC records. But the steering group advised against their inclusion.


## References

The Social Wellbeing Agency has published an accompanying guide. You can find it our our website: swa.govt.nz 


## Parameters & Present values:
  Current refresh = 202406
  Prefix = defn_
  Project schema = DL-MAA2023-55


## Dependencies
The code relies on eight input tables:
•	[IDI_Clean].[cen_clean].[census_individual_2018]
•	[IDI_Clean].[security].[concordance]
•	[IDI_Clean].[gss_clean].[gss_person]
•	[IDI_Clean].[moh_clean].[interrai] -- commented out - not available for this project
•	[IDI_Adhoc].[clean_read_HLFS].[hlfs_disability]
•	[IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_support_needs_2022]
•	[IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_needs_assessment_2022]

Linking between the two is done on snz_moh_uid.  No rows are lost via this linking.


## Outputs
Table: [IDI_Sandpit].[DL-MAA2023-20].[defn_functional_disability_spells2]


## Variable Descriptions

---------------------------------------------------------------------------------------------------------------------------
Column                         Description
name                       
------------------------------ --------------------------------------------------------------------------------------------
snz_uid                        The unique STATSNZ person identifier for the person

any_functional_disability	   The highest score recorded across any of the 6 WGSS measures (or equivalent mapping from other data)

startdate				       The date the person was first recorded in the data, or a change was recorded for any_functional_disability. Survey/census date for Stats NZ sources, assessment date for MoH sources.

finishdate					   The day before the person recorded a different result for any_functional_disability



## Version and change history

2024-03-25 AA modified for new project and to join to master table
2023-01-31 DY modified to produce spell based outputs of any_functional_disability consistent with D4C requirements
2022-12-09 MR Created "any_functional_disability" column
2022-09-19 SA ensure consistency with definition documentation
2022-09-19 SA check against definition description by Andrew (from consultation with DDEWG)
2021-12-02 SA review and tidy
2021-11-20 CW v1

## Code

***************************************************************************************************************************/



:setvar targetdb "IDI_Sandpit"
:setvar projectschema "DL-MAA2024-48"
:setvar idicleanversion "IDI_Clean_202406"
:setvar targettable "ICM_Master_Table_202406"

-- Set some numbered table names
-- Not sure of how to create dynamic table names (internet suggests not possible outside of stored procedures?)
:setvar idimetadata "IDI_Metadata_202406"
:setvar ise_mainbenefit "msd_ise_main_benefit_202406"
:setvar ise_supplementary "msd_ise_supplementary_202406"

-- always use a refdate that is the first of the month, otherwise calculations (datediffs) may return incorrect results
:setvar refdate "'2023-01-01'" 

/* create table for all records */
DROP TABLE IF EXISTS #tmp_functional_disability_list
GO

CREATE TABLE #tmp_functional_disability_list (
	snz_uid INT,
	record_source VARCHAR(9),
	event_date DATE,
	dv_hearing INT,
	dv_seeing INT,
	dv_walking INT,
	dv_remembering INT,
	dv_washing INT,
	dv_communication INT,
);
GO

/***************************************************************************************************************
append records from each source into the table
***************************************************************************************************************/

/*********************************
1. Stats NZ surveys - Census 2018

The question in the census is:

22. This question is about difficulties you may have doing certain activities because of a health problem.

	Do you have difficulty with any of the following:

	- seeing, even if wearing glasses?   ([cen_ind_dffcl_seeing_code])
		
		Answers:
			- no difficulty          (1)
			- some difficulty        (2)
			- a lot of difficulty    (3)
			- cannot do at all       (4)

		Other answers in the dataset
			- Response unidentifiable    (7)
			- Not Stated				 (9)

	The same answers apply to these questions:
	- hearing, even if using a hearing aid?  ([cen_ind_dffcl_hearing_code])
	- walking or climbing steps?    ([cen_ind_dffcl_walking_code])
	- remembering or concentrating?   ([cen_ind_dffcl_remembering_code])
	- washing all over or dressing?   ([cen_ind_dffcl_washing_code])
	- communicating using your usual language, for example understanding or being understood by others?   ([cen_ind_dffcl_comt_code])
*********************************/

INSERT INTO #tmp_functional_disability_list
	(snz_uid, record_source, event_date, dv_hearing, dv_seeing, dv_walking, dv_remembering, dv_washing, dv_communication)
SELECT [snz_uid]
	,'CEN2018' AS record_source
	,'2018-03-05' AS event_date
	--,[cen_ind_dsblty_ind_code] as dv_disability
	,CASE
		WHEN [cen_ind_dffcl_hearing_code] = 1 THEN 0
		WHEN [cen_ind_dffcl_hearing_code] = 2 THEN 1
		WHEN [cen_ind_dffcl_hearing_code] IN (3,4) THEN 2
		ELSE null END AS dv_hearing
	,CASE 
		WHEN [cen_ind_dffcl_seeing_code] = 1 THEN 0
		WHEN [cen_ind_dffcl_seeing_code] = 2 THEN 1
		WHEN [cen_ind_dffcl_seeing_code] IN (3,4) THEN 2
		ELSE null END AS dv_seeing
	,CASE 
		WHEN [cen_ind_dffcl_walking_code] = 1 THEN 0
		WHEN [cen_ind_dffcl_walking_code] = 2 THEN 1
		WHEN [cen_ind_dffcl_walking_code] IN (3,4) THEN 2
		ELSE null END AS dv_walking
	,CASE
		WHEN [cen_ind_dffcl_remembering_code] = 1 THEN 0
		WHEN [cen_ind_dffcl_remembering_code] = 2 THEN 1
		WHEN [cen_ind_dffcl_remembering_code] IN (3,4) THEN 2
		ELSE null END AS dv_remembering
	,CASE 
		WHEN [cen_ind_dffcl_washing_code] = 1 THEN 0
		WHEN [cen_ind_dffcl_washing_code] = 2 THEN 1
		WHEN [cen_ind_dffcl_washing_code] IN (3,4) THEN 2
		ELSE null END AS dv_washing
	,CASE
		WHEN [cen_ind_dffcl_comt_code] = 1 THEN 0
		WHEN [cen_ind_dffcl_comt_code] = 2 THEN 1
		WHEN [cen_ind_dffcl_comt_code] IN (3,4) THEN 2
		ELSE null END AS dv_communication
FROM $(idicleanversion).[cen_clean].[census_individual_2018]
/* WGSS not collected for children under 5 years of age for exclude */
WHERE cen_ind_age_code NOT IN ('000', '001', '002', '003', '004')
GO

/*********************************
2. Stats NZ surveys - HLFS
*********************************/

INSERT INTO #tmp_functional_disability_list
	(snz_uid, record_source, event_date, dv_hearing, dv_seeing, dv_walking, dv_remembering, dv_washing, dv_communication)
SELECT b.snz_uid
	,'HLFS' AS record_source
	,[quarter_date]
	,CASE 
		WHEN [diff_hearing_code]='11' then 0
		WHEN [diff_hearing_code]='12' THEN 1
		WHEN [diff_hearing_code] IN ('13','14') THEN 2
		ELSE null END AS dv_hearing
	,CASE 
		WHEN [diff_seeing_code]='11' then 0
		WHEN [diff_seeing_code]='12' THEN 1
		WHEN [diff_seeing_code] IN ('13','14') THEN 2
		ELSE null END AS dv_seeing
	,CASE 
		WHEN [diff_walking_code]='11' then 0
		WHEN [diff_walking_code]='12' THEN 1
		WHEN [diff_walking_code] IN ('13','14') THEN 2
		ELSE null END AS dv_walking
	,CASE 
		WHEN [diff_memory_code]='11' then 0
		WHEN [diff_memory_code]='12' THEN 1
		WHEN [diff_memory_code] IN ('13','14') THEN 2
		ELSE null END AS dv_remembering
	,CASE 
		WHEN [diff_dressing_code]='11' then 0
		WHEN [diff_dressing_code]='12' THEN 1
		WHEN [diff_dressing_code] IN ('13','14') THEN 2
		ELSE null END AS dv_washing
	,CASE 
		WHEN [diff_communicating_code]='11' then 0
		WHEN [diff_communicating_code]='12' THEN 1
		WHEN [diff_communicating_code] IN ('13','14') THEN 2
		ELSE null END AS dv_communication
FROM [IDI_Adhoc].[clean_read_HLFS].[hlfs_disability] as a
INNER JOIN $(idicleanversion).[security].[concordance] as b
ON a.snz_hlfs_uid = b.snz_hlfs_uid
GO

/*********************************
3. Stats NZ surveys - GSS 2021, 2016 or 2018
*********************************/

INSERT INTO #tmp_functional_disability_list
	(snz_uid, record_source, event_date, dv_hearing, dv_seeing, dv_walking, dv_remembering, dv_washing, dv_communication)
SELECT [snz_uid]
	,'GSS' AS record_source
	,[gss_pq_fpqinterviewdate] AS event_date
	,CASE 
		WHEN [gss_pq_dis_qdisabilityhear] ='11' THEN 0
		WHEN [gss_pq_dis_qdisabilityhear] ='12' THEN 1
		WHEN [gss_pq_dis_qdisabilityhear] IN ('13','14') THEN 2
		ELSE null END AS dv_hearing
	,CASE 
		WHEN [gss_pq_dis_qdisabilitysee] ='11' THEN 0
		WHEN [gss_pq_dis_qdisabilitysee] ='12' THEN 1
		WHEN [gss_pq_dis_qdisabilitysee] IN ('13','14') THEN 2
		ELSE null END AS dv_seeing
	,CASE
		WHEN [gss_pq_dis_qdisabilitywalk] ='11' THEN 0
		WHEN [gss_pq_dis_qdisabilitywalk] ='12' THEN 1
		WHEN [gss_pq_dis_qdisabilitywalk] IN ('13','14') THEN 2
		ELSE null END AS dv_walking
	,CASE 
		WHEN [gss_pq_dis_qdisabilityremember] ='11' THEN 0
		WHEN [gss_pq_dis_qdisabilityremember] ='12' THEN 1
		WHEN [gss_pq_dis_qdisabilityremember] IN ('13','14') THEN 2
		ELSE null END AS dv_remembering
	,CASE
		WHEN [gss_pq_dis_qdisabilitywash] ='11' THEN 0
		WHEN [gss_pq_dis_qdisabilitywash] ='12' THEN 1
		WHEN [gss_pq_dis_qdisabilitywash] IN ('13','14') THEN 2
		ELSE null END AS dv_washing
	,CASE
		WHEN [gss_pq_dis_disabilitycommunicate] ='11' THEN 0
		WHEN [gss_pq_dis_disabilitycommunicate] ='12' THEN 1
		WHEN [gss_pq_dis_disabilitycommunicate] IN ('13','14') THEN 2
		ELSE null END AS dv_communication
FROM $(idicleanversion).[gss_clean].[gss_person_2021]
GO


INSERT INTO #tmp_functional_disability_list
	(snz_uid, record_source, event_date, dv_hearing, dv_seeing, dv_walking, dv_remembering, dv_washing, dv_communication)
SELECT [snz_uid]
	,'GSS' AS record_source
	,[gss_pq_fhqinterview_date] AS event_date
	,CASE 
		WHEN [gss_pq_dis_qdisabilityhear_code] ='11' THEN 0
		WHEN [gss_pq_dis_qdisabilityhear_code] ='12' THEN 1
		WHEN [gss_pq_dis_qdisabilityhear_code] IN ('13','14') THEN 2
		ELSE null END AS dv_hearing
	,CASE 
		WHEN [gss_pq_dis_qdisabilitysee_code] ='11' THEN 0
		WHEN [gss_pq_dis_qdisabilitysee_code] ='12' THEN 1
		WHEN [gss_pq_dis_qdisabilitysee_code] IN ('13','14') THEN 2
		ELSE null END AS dv_seeing
	,CASE
		WHEN [gss_pq_dis_qdisabilitywalk_code] ='11' THEN 0
		WHEN [gss_pq_dis_qdisabilitywalk_code] ='12' THEN 1
		WHEN [gss_pq_dis_qdisabilitywalk_code] IN ('13','14') THEN 2
		ELSE null END AS dv_walking
	,CASE 
		WHEN [gss_pq_dis_qdisabiltyremmbr_code] ='11' THEN 0
		WHEN [gss_pq_dis_qdisabiltyremmbr_code] ='12' THEN 1
		WHEN [gss_pq_dis_qdisabiltyremmbr_code] IN ('13','14') THEN 2
		ELSE null END AS dv_remembering
	,CASE
		WHEN [gss_pq_dis_qdisabilitywash_code] ='11' THEN 0
		WHEN [gss_pq_dis_qdisabilitywash_code] ='12' THEN 1
		WHEN [gss_pq_dis_qdisabilitywash_code] IN ('13','14') THEN 2
		ELSE null END AS dv_washing
	,CASE
		WHEN [gss_pq_dis_qdisabiltycomuni_code] ='11' THEN 0
		WHEN [gss_pq_dis_qdisabiltycomuni_code] ='12' THEN 1
		WHEN [gss_pq_dis_qdisabiltycomuni_code] IN ('13','14') THEN 2
		ELSE null END AS dv_communication
FROM $(idicleanversion).[gss_clean].[gss_person_2018]
GO

INSERT INTO #tmp_functional_disability_list
	(snz_uid, record_source, event_date, dv_hearing, dv_seeing, dv_walking, dv_remembering, dv_washing, dv_communication)
SELECT [snz_uid]
	,'GSS' AS record_source
	,[gss_pq_fhqinterview_date] AS event_date
	,CASE 
		WHEN [gss_pq_dis_qdisabilityhear_code] ='11' THEN 0
		WHEN [gss_pq_dis_qdisabilityhear_code] ='12' THEN 1
		WHEN [gss_pq_dis_qdisabilityhear_code] IN ('13','14') THEN 2
		ELSE null END AS dv_hearing
	,CASE 
		WHEN [gss_pq_dis_qdisabilitysee_code] ='11' THEN 0
		WHEN [gss_pq_dis_qdisabilitysee_code] ='12' THEN 1
		WHEN [gss_pq_dis_qdisabilitysee_code] IN ('13','14') THEN 2
		ELSE null END AS dv_seeing
	,CASE
		WHEN [gss_pq_dis_qdisabilitywalk_code] ='11' THEN 0
		WHEN [gss_pq_dis_qdisabilitywalk_code] ='12' THEN 1
		WHEN [gss_pq_dis_qdisabilitywalk_code] IN ('13','14') THEN 2
		ELSE null END AS dv_walking
	,CASE 
		WHEN [gss_pq_dis_qdisabiltyremmbr_code] ='11' THEN 0
		WHEN [gss_pq_dis_qdisabiltyremmbr_code] ='12' THEN 1
		WHEN [gss_pq_dis_qdisabiltyremmbr_code] IN ('13','14') THEN 2
		ELSE null END AS dv_remembering
	,CASE
		WHEN [gss_pq_dis_qdisabilitywash_code] ='11' THEN 0
		WHEN [gss_pq_dis_qdisabilitywash_code] ='12' THEN 1
		WHEN [gss_pq_dis_qdisabilitywash_code] IN ('13','14') THEN 2
		ELSE null END AS dv_washing
	,CASE
		WHEN [gss_pq_dis_qdisbltycomuncte_code] ='11' THEN 0
		WHEN [gss_pq_dis_qdisbltycomuncte_code] ='12' THEN 1
		WHEN [gss_pq_dis_qdisbltycomuncte_code] IN ('13','14') THEN 2
		ELSE null END AS dv_communication
FROM $(idicleanversion).[gss_clean].[gss_person_2016]
GO

/*********************************
4. MoH - SOCRATES

The SOCRATES data is for MoH funded disability services.
These will tend to be at the more severe end of the scale.
So we expect to see that there will be fewer people in this
data and that their measures will tend to be more severe. 

Code list:
	Hearing
	--1003	Hearing impaired
	--1004	Deaf or nearly deaf
	Seeing
	--1001	Vision impaired
	--1002	Blind or nearly blind
	Walking
	--1111	Wheelchair user (inside / outside of home)
	--1101	Moving around inside home
	--1102	Moving around outside home
	--1103	Moving around in the community
	Remembering
	--1299	Other difficulties with memory / cognition / behaviour (specify)
	--1203	Learning ability, i.e. acquiring skills of reading, writing, language, calculating, copying, etc.
	--1202	Intellectual ability, i.e. thinking, understanding
	--1208	Attention, e.g. concentration
	--1201	Memory
	Washing
	--1403	Dressing and / or undressing
	--1405	Toileting, using toilet facilities
	--1402	Bathing, showering, washing self
	--1404	Grooming and caring for body parts, e.g. feet, teeth, hair, nails, etc
	Communication
	--1803	Non verbal
	--1801	Ability to express core needs
	--1006	Mute or nearly mute
	--1005	Speech impaired
*********************************/

INSERT INTO #tmp_functional_disability_list
	(snz_uid, record_source, event_date, dv_hearing, dv_seeing, dv_walking, dv_remembering, dv_washing, dv_communication)

SELECT [snz_uid]
	,'SOCRATES' AS record_source
	,CAST(SUBSTRING([DateAssessmentCompleted],1,7) AS DATE) AS event_date
	--hearing
	,IIF(code IN (1003, 1004), 2, null) AS dv_hearing
	--seeing
	,IIF(code IN (1001, 1002), 2, null) AS dv_seeing
	--walk
	,IIF(code IN (1111, 1101, 1102, 1103), 2, null) AS dv_walking
	--memory/learning
	,IIF(code IN (1201,1202,1203,1208,1299), 2, null) AS dv_remembering
	--wash
	,IIF(code IN (1402,1403,1404,1405), 2, null) AS dv_washing
	--communicating
	,IIF(code IN (1005,1006,1801,1803), 2, null) AS dv_communication
	--,s.Code
	--,s.Description
FROM [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_support_needs_2022] AS s
INNER JOIN $(idicleanversion).[security].[concordance] as c
ON s.snz_moh_uid = c.snz_moh_uid
INNER JOIN [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_needs_assessment_2022] AS n
ON s.[snz_moh_uid] = n.[snz_moh_uid]
AND s.[NeedsAssessmentID] = n.[NeedsAssessmentID]
AND s.[snz_moh_soc_client_uid] = n.[snz_moh_soc_client_uid]
GO

/*********************************
5. MoH - IRAI

Excludes the CA assessment type due to absence of impairment/disability type questions

-- removed - interrai not available for this project
*********************************/

--INSERT INTO #tmp_functional_disability_list
--	(snz_uid, record_source, event_date, dv_hearing, dv_seeing, dv_walking, dv_remembering, dv_washing, dv_communication)

--SELECT [snz_uid]
--	,'IRAI' AS record_source
--	--,[snz_moh_uid]
--	--,[moh_irai_assessment_type_text]
--	--,[moh_irai_assess_version_text]
--	,[moh_irai_assessment_date] AS event_date
--	--hearing
--	,CASE
--		WHEN [moh_irai_hearing_code] BETWEEN 2 AND 4 THEN 2
--		WHEN [moh_irai_hearing_code] = 1 THEN 1
--		WHEN [moh_irai_hearing_code] = 0 THEN 0
--		ELSE null END AS dv_hearing
--	--vision
--	,CASE
--		WHEN [moh_irai_vision_light_code] BETWEEN 2 AND 4 THEN 2
--		WHEN [moh_irai_vision_light_code] = 1 THEN 1
--		WHEN [moh_irai_vision_light_code] = 0 THEN 0
--		ELSE null END AS dv_seeing
--	--walking
--	,CASE
--		WHEN [moh_irai_adl_walking_code] BETWEEN 2 AND 6
--			OR moh_irai_stairs_perform_code BETWEEN 2 AND 6
--			OR moh_irai_stairs_capacity_code BETWEEN 2 AND 6 THEN 2
--		WHEN [moh_irai_adl_walking_code] = 1
--			OR moh_irai_stairs_perform_code = 1
--			OR moh_irai_stairs_capacity_code = 1 THEN 1
--		WHEN [moh_irai_adl_walking_code] = 0
--			OR moh_irai_stairs_perform_code = 0
--			OR moh_irai_stairs_capacity_code = 0 THEN 0
--		ELSE null END AS dv_walking
--	--memory/learning
--	,CASE
--		WHEN [moh_irai_short_term_mem_ind] = 1
--			OR [moh_irai_procedural_mem_ind] = 1
--			OR [moh_irai_situational_mem_ind] = 1
--			OR [moh_irai_long_term_mem_ind] = 1
--			OR [moh_irai_res_hist_intellect_ind] = 1
--			OR [moh_irai_easily_distracted_code] = 2 THEN 2
--		WHEN [moh_irai_easily_distracted_code] = 1 THEN 1
--		WHEN [moh_irai_short_term_mem_ind] = 0
--			OR [moh_irai_procedural_mem_ind] = 0
--			OR [moh_irai_situational_mem_ind] = 0
--			OR [moh_irai_long_term_mem_ind] = 0
--			OR [moh_irai_res_hist_intellect_ind] = 0 
--			OR [moh_irai_easily_distracted_code] = 0 THEN 0
--		ELSE null END AS dv_remembering
--	--washing
--	,CASE
--		WHEN moh_irai_adl_bathing_code BETWEEN 2 AND 6 THEN 2
--		WHEN moh_irai_adl_bathing_code = 1 THEN 1
--		WHEN moh_irai_adl_bathing_code = 0 THEN 0
--		ELSE null END AS dv_washing
--	--communication
--	,CASE
--		WHEN moh_irai_scale_comm_code BETWEEN 3 AND 8 THEN 2
--		WHEN moh_irai_scale_comm_code BETWEEN 1 AND 2 THEN 1
--		WHEN moh_irai_scale_comm_code = 0 THEN 0
--		ELSE null END AS dv_comt
--FROM $(idicleanversion).[moh_clean].[interrai]
--WHERE [moh_irai_assessment_type_text] !='CA'

--GO

/***************************************************************************************************************
Create final table
***************************************************************************************************************/

CREATE NONCLUSTERED INDEX my_index_name ON #tmp_functional_disability_list (snz_uid);
GO

DROP TABLE IF EXISTS #defn_functional_disability
GO


WITH

/* Where multiple records per person for the same date & source, keep the highest */
single_person_source_date_record AS (
	SELECT snz_uid
		,record_source
		,event_date
		,MAX(dv_hearing) AS dv_hearing
		,MAX(dv_seeing) AS dv_seeing
		,MAX(dv_walking) AS dv_walking
		,MAX(dv_remembering) AS dv_remembering
		,MAX(dv_washing) AS dv_washing
		,MAX(dv_communication) AS dv_communication
	FROM #tmp_functional_disability_list
	GROUP BY snz_uid, record_source, event_date
),


most_recent_date AS (
	SELECT *
		,ROW_NUMBER() OVER (PARTITION BY snz_uid ORDER BY event_date DESC, record_source) AS ranking
	FROM single_person_source_date_record
)

SELECT snz_uid
	,record_source
	,event_date
	,dv_hearing
	,dv_seeing
	,dv_walking
	,dv_remembering
	,dv_washing
	,dv_communication
	,IIF(dv_hearing = 2
		OR dv_seeing = 2
		OR dv_walking = 2
		OR dv_remembering = 2
		OR dv_washing = 2
		OR dv_communication = 2, 1, 0) AS overall_dv_indication
	,CASE WHEN dv_hearing = 2
		OR dv_seeing = 2
		OR dv_walking = 2
		OR dv_remembering = 2
		OR dv_washing = 2
		OR dv_communication = 2 THEN 2
		WHEN dv_hearing = 1
		OR dv_seeing = 1
		OR dv_walking = 1
		OR dv_remembering = 1
		OR dv_washing = 1
		OR dv_communication = 1 THEN 1
		WHEN dv_hearing = 0
		OR dv_seeing = 0
		OR dv_walking = 0
		OR dv_remembering = 0
		OR dv_washing = 0
		OR dv_communication = 0 THEN 0
		ELSE null END AS any_functional_disability
INTO #defn_functional_disability
FROM most_recent_date
-- FROM single_person_source_date_record
-- WHERE ranking = 1
GO

DELETE FROM #defn_functional_disability
WHERE any_functional_disability is null

CREATE NONCLUSTERED INDEX my_index_name ON #defn_functional_disability (snz_uid);
GO


/* remove raw list table */
DROP TABLE IF EXISTS #tmp_functional_disability_list
GO

/* remove spells table if exists*/
DROP TABLE IF EXISTS #defn_functional_disability_spells2
GO

/* We break up spells by source */
CREATE TABLE #defn_functional_disability_spells2 (
	snz_uid INT
	,record_source VARCHAR(8)
	,func_disability_type VARCHAR(13)
	,func_disability_ind INT
	,startdate DATE
	,finishdate DATE
);
GO


/* Take the data, restructure so that there is a 'measure' column that records functional disability 'type' (eg, difficulty seeing, hearing, any,) */
WITH long_table AS (
	-- dv_hearing
	SELECT 
	snz_uid
		,record_source
		,event_date
		,'hearing' AS func_disability_type
		,dv_hearing AS func_disability_ind
	FROM #defn_functional_disability
	WHERE dv_hearing IS NOT NULL

	UNION

	-- dv_seeing
	SELECT 
	snz_uid
		,record_source
		,event_date
		,'seeing' AS func_disability_type
		,dv_seeing AS func_disability_ind
	FROM #defn_functional_disability
	WHERE dv_seeing IS NOT NULL

	-- dv_walking
	UNION
	SELECT 
	snz_uid
		,record_source
		,event_date
		,'walking' AS func_disability_type
		,dv_walking AS func_disability_ind
	FROM #defn_functional_disability
	WHERE dv_walking IS NOT NULL

	UNION

	-- dv_remembering
	SELECT 
	snz_uid
		,record_source
		,event_date
		,'remembering' AS func_disability_type
		,dv_remembering AS func_disability_ind
	FROM #defn_functional_disability
	WHERE dv_remembering IS NOT NULL

	UNION

	-- dv_washing
	SELECT 
	snz_uid
		,record_source
		,event_date
		,'washing' AS func_disability_type
		,dv_washing AS func_disability_ind
	FROM #defn_functional_disability
	WHERE dv_washing IS NOT NULL

	UNION

	-- dv_communication
	SELECT 
	snz_uid
		,record_source
		,event_date
		,'communication' AS func_disability_type
		,dv_communication AS func_disability_ind
	FROM #defn_functional_disability
	WHERE dv_communication IS NOT NULL

	UNION

	-- any_functional_disability
	SELECT 
	snz_uid
		,record_source
		,event_date
		,'any' AS func_disability_type
		,any_functional_disability AS func_disability_ind
	FROM #defn_functional_disability
	WHERE any_functional_disability IS NOT NULL
	),

/* Create spells for each indicator that last until it is next recorded for the person. 
We do not condense consecutive recordings of the same value from the same source.
This means that the start date should correspond to the date of the assessment or survey (or proxy for that date) */

temp as (SELECT snz_uid
		,record_source
		,func_disability_type
		,func_disability_ind
		,event_date as startdate
		,LAG(event_date,1,'9999-12-31') over (partition by snz_uid, func_disability_type order by event_date desc) as finishdate
	FROM long_table) 
INSERT INTO #defn_functional_disability_spells2
SELECT snz_uid
	,record_source
	,func_disability_type
	,func_disability_ind
	,startdate
	,case when finishdate = '9999-12-31' then finishdate
		else dateadd(day,-1,finishdate) end as finishdate
FROM temp
GO

CREATE NONCLUSTERED INDEX my_index_name ON #defn_functional_disability_spells2 (snz_uid);
GO
ALTER TABLE #defn_functional_disability_spells2 REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
GO


DROP TABLE IF EXISTS #ot_pop_disability
SELECT ot.snz_uid
		,MAX(CASE WHEN func_disability_type = 'any' THEN func_disability_ind ELSE null END) AS func_dis_any
		,MAX(CASE WHEN func_disability_type = 'seeing' THEN func_disability_ind ELSE null END) AS func_dis_see
		,MAX(CASE WHEN func_disability_type = 'hearing' THEN func_disability_ind ELSE null END) AS func_dis_hear
		,MAX(CASE WHEN func_disability_type = 'walking' THEN func_disability_ind ELSE null END) AS func_dis_walk
		,MAX(CASE WHEN func_disability_type = 'washing' THEN func_disability_ind ELSE null END) AS func_dis_wash
		,MAX(CASE WHEN func_disability_type = 'remembering' THEN func_disability_ind ELSE null END) AS func_dis_remb
		,MAX(CASE WHEN func_disability_type = 'communication' THEN func_disability_ind ELSE null END) AS func_dis_comm
INTO #ot_pop_disability
FROM #defn_functional_disability_spells2 dis
INNER JOIN $(targetdb).[$(projectschema)].$(targettable) ot
ON ot.snz_uid= dis.snz_uid
AND dis.startdate <$(refdate)
AND dis.finishdate >= $(refdate)
GROUP BY ot.snz_uid

CREATE CLUSTERED INDEX my_index_name ON #ot_pop_disability ([snz_uid]);

------------------------------------------------- Add and update columns into Master Table

ALTER TABLE $(targetdb).[$(projectschema)].$(targettable) DROP COLUMN IF EXISTS func_dis_any;

ALTER TABLE $(targetdb).[$(projectschema)].$(targettable) ADD func_dis_any tinyint; 
GO

UPDATE
	$(targetdb).[$(projectschema)].$(targettable)
SET
	func_dis_any = CASE WHEN dis.func_dis_any > 0 THEN 1 ELSE NULL END
FROM 
	#ot_pop_disability dis
WHERE $(targetdb).[$(projectschema)].$(targettable).snz_uid = dis.snz_uid;

-- Compress table
-- ALTER TABLE IDI_Sandpit.$(projectschema).$(targettable) REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)

-- AW has advised that school High Health Need and ORS are indication of disability within the student_intervention table,
-- and that any inclusion should be used, independent of date.
-- For reproducibility across refresh reasons, include only where the data is recorded prior to the date of interest.

DROP TABLE IF EXISTS #moe_interventions;
SELECT snz_uid
		,CASE WHEN COUNT(CASE WHEN InterventionID = 25 THEN 1 ELSE NULL END) > 0 THEN 1 ELSE NULL END AS ORS_students
		,CASE WHEN COUNT(CASE WHEN InterventionID = 27 THEN 1 ELSE NULL END) > 0 THEN 1 ELSE NULL END AS high_health_students
INTO #moe_interventions
FROM $(idicleanversion).moe_clean.student_interventions inv
LEFT JOIN $(idimetadata).[moe_school].[intervention_type23_code] met
ON met.InterventionID  = inv.moe_inv_intrvtn_code
WHERE met.InterventionID in (25,27)
AND moe_inv_start_date <$(refdate)
GROUP BY snz_uid;


-- Socrates is a high threshold so everyone in Socrates will have a disability, but not everyone with a disability will be in Socrates

DROP TABLE IF EXISTS #socrates;
SELECT DISTINCT conc.snz_uid 
INTO #socrates
FROM IDI_Adhoc.clean_read_moh_socrates.moh_client soc
LEFT JOIN $(idicleanversion).[security].concordance conc
ON soc.snz_moh_uid = conc.snz_moh_uid
INNER JOIN $(targetdb).[$(projectschema)].$(targettable) pop
ON conc.snz_uid = pop.snz_uid;



-- Child Disability Allowance
-- See below for analysis of how to best link agency ids from the adhoc table to snz_uids
DROP TABLE IF EXISTS #cda;
SELECT DISTINCT snz_uid, scdaco.beg_date, scdaco.end_date
INTO #cda
FROM IDI_Adhoc.clean_read_MSD.msd_scdaco_202309 scdaco
LEFT JOIN $(idicleanversion).[security].concordance ids
ON scdaco.child_snz_msd_uid = ids.snz_msd_uid
WHERE scdaco.beg_date < $(refdate) AND scdaco.end_date >= dateadd(YEAR,-1,$(refdate));

/*
-- Security.concordance provides a better linkage of snz_uids than msd_customer:
DROP TABLE IF EXISTS #temp;

WITH tm1 AS (SELECT DISTINCT snz_uid, 1 AS conc_flag
		FROM IDI_Adhoc.clean_read_MSD.msd_scdaco_202309 scdaco
		LEFT JOIN (SELECT DISTINCT snz_uid, snz_msd_uid FROM $(idicleanversion).[security].concordance) ids
		ON scdaco.child_snz_msd_uid = ids.snz_msd_uid),
	tm2 AS (SELECT DISTINCT snz_uid, 1 AS msd_flag 
			FROM IDI_Adhoc.clean_read_MSD.msd_scdaco_202309 scdaco
			LEFT JOIN (SELECT DISTINCT snz_uid, snz_msd_uid FROM $(idicleanversion).msd_clean.msd_customer) ids
			ON scdaco.child_snz_msd_uid = ids.snz_msd_uid)
SELECT a.snz_uid
		,tm1.conc_flag
		,tm2.msd_flag
INTO #temp
FROM (SELECT snz_uid FROM tm1 UNION SELECT snz_uid FROM tm2) a
LEFT JOIN tm1
ON a.snz_uid = tm1.snz_uid
LEFT JOIN tm2
ON a.snz_uid = tm2.snz_uid;

SELECT COUNT(CASE WHEN conc_flag = 1 AND msd_flag = 1 THEN 1 ELSE NULL END) AS in_both
		,COUNT(CASE WHEN conc_flag = 1 AND msd_flag IS NULL THEN 1 ELSE NULL END) AS in_conc_only
		,COUNT(CASE WHEN msd_flag = 1 AND conc_flag IS NULL THEN 1 ELSE NULL END) AS in_msd_only
FROM #temp;
DROP TABLE IF EXISTS #temp;
*/

-- Get additional MSD benefits from the Code Module
DROP TABLE IF EXISTS #msd_main_benefits;
SELECT [snz_uid]
		,CASE WHEN COUNT(CASE WHEN [benefit_lvl1] in ('Invalids Benefit','Invalids Benefit weekly') THEN 1 ELSE NULL END) > 0 THEN 1 ELSE NULL END AS Invalids_benefit
		,CASE WHEN COUNT(CASE WHEN [benefit_lvl1] in ('Supported Living Payment','Supported Living Payment Health Condition & Disability','Supported Living Payment Overseas') THEN 1 ELSE NULL END) > 0 THEN 1 ELSE NULL END AS supported_living_payment
INTO #msd_main_benefits
FROM [IDI_Community].[cm_read_MSD_ISE_MAIN_BENEFIT].$(ise_mainbenefit)
WHERE [benefit_lvl1] IN ('Invalids Benefit'
							,'Invalids Benefit weekly'
							,'Supported Living Payment'
							,'Supported Living Payment Health Condition & Disability'
							,'Supported Living Payment Overseas')
  AND payment_start < $(refdate)
  AND payment_end >= dateadd(YEAR,-1,$(refdate))
GROUP BY snz_uid;

DROP TABLE IF EXISTS #msd_supp_benefits;
SELECT DISTINCT [snz_uid]
	,CASE WHEN COUNT(CASE WHEN [benefit_lvl1] in ('Disability Allowance') THEN 1 ELSE NULL END) > 0 THEN 1 ELSE NULL END AS disability_allowance
INTO #msd_supp_benefits
FROM [IDI_Community].[cm_read_MSD_ISE_SUPPLEMENTARY].$(ise_supplementary)
WHERE [benefit_lvl1] IN ('Disability Allowance')
  AND payment_start < $(refdate)
  AND payment_end >= dateadd(YEAR,-1,$(refdate))
GROUP BY snz_uid;



----------------------------------------------- Add and update columns into Master Table

ALTER TABLE $(targetdb).[$(projectschema)].$(targettable) DROP COLUMN IF EXISTS in_socrates
																		,COLUMN IF EXISTS high_health_students
																		,COLUMN IF EXISTS ORS_students
																		,COLUMN IF EXISTS child_disability_allowance
																		,COLUMN IF EXISTS Invalids_benefit
																		,COLUMN IF EXISTS supported_living_payment
																		,COLUMN IF EXISTS disability_allowance
																		,COLUMN IF EXISTS dis_any;
ALTER TABLE $(targetdb).[$(projectschema)].$(targettable) ADD in_socrates TINYINT
																,high_health_students TINYINT
																,ORS_students TINYINT
																,child_disability_allowance TINYINT
																,Invalids_benefit TINYINT
																,supported_living_payment TINYINT
																,disability_allowance tinyint
																,dis_any TINYINT;
GO
-- CDA
UPDATE
	$(targetdb).[$(projectschema)].$(targettable)
SET
	child_disability_allowance = 1
FROM 
	#cda dis
WHERE $(targetdb).[$(projectschema)].$(targettable).snz_uid = dis.snz_uid;

-- MSD Main benefits
UPDATE
	$(targetdb).[$(projectschema)].$(targettable)
SET
	Invalids_benefit = msd_mb.Invalids_benefit
	,supported_living_payment = msd_mb.supported_living_payment
FROM 
	#msd_main_benefits msd_mb
WHERE $(targetdb).[$(projectschema)].$(targettable).snz_uid = msd_mb.snz_uid;

-- MSD supplementary benefits
UPDATE
	$(targetdb).[$(projectschema)].$(targettable)
SET
	disability_allowance = msd_sb.disability_allowance
FROM 
	#msd_supp_benefits msd_sb
WHERE $(targetdb).[$(projectschema)].$(targettable).snz_uid = msd_sb.snz_uid;

-- MOE interventions
UPDATE
	$(targetdb).[$(projectschema)].$(targettable)
SET
	ORS_students = moe.ORS_students
	,high_health_students = moe.high_health_students
FROM 
	#moe_interventions moe
WHERE $(targetdb).[$(projectschema)].$(targettable).snz_uid = moe.snz_uid;

-- Socrates
UPDATE
	$(targetdb).[$(projectschema)].$(targettable)
SET
	in_socrates = 1
FROM 
	#Socrates soc
WHERE $(targetdb).[$(projectschema)].$(targettable).snz_uid = soc.snz_uid;


UPDATE
	$(targetdb).[$(projectschema)].$(targettable)
SET
	dis_any = COALESCE(func_dis_any,in_socrates,high_health_students,ORS_students,child_disability_allowance,Invalids_benefit,supported_living_payment,disability_allowance,0);



-- Compress table
ALTER TABLE $(targetdb).[$(projectschema)].$(targettable) REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
