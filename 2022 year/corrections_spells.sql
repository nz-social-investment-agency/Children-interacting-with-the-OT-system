/**************************************************************************************************
Title: Spell managed by Corrections
Author: Simon Anastasiadis
Reviewer: Marianna Pekar, Joel Bancolita

Acknowledgements:
Informatics for Social Services and Wellbeing (terourou.org) supported the publishing of these definitions

Disclaimer:
The definitions provided in this library were determined by the Social Wellbeing Agency to be suitable in the 
context of a specific project. Whether or not these definitions are suitable for other projects depends on the 
context of those projects. Researchers using definitions from this library will need to determine for themselves 
to what extent the definitions provided here are suitable for reuse in their projects. While the Agency provides 
this library as a resource to support IDI research, it provides no guarantee that these definitions are fit for reuse.

Citation:
Social Wellbeing Agency. Definitions library. Source code. https://github.com/nz-social-wellbeing-agency/definitions_library

Description:
A spell for a person in New Zealand with any management by Corrections.

Intended purpose:
Original indicator
1. Creating indicators of when/whether a person has been managed by corrections.
2. Identifying spells when a person is under Corrections management.
3. Counting the number of days a person spends under Corrections management.

Modification
i. Identifying when persons experience prison or home detention as an adult aged 18-27.
ii. Identifying when persons are currently in prison or on home detention

Inputs & Dependencies:
- [IDI_Clean].[cor_clean].[ov_major_mgmt_periods]
Outputs:
- [IDI_UserCode].[DL-MAA2023-46].[defn_corrections_any]
 
Notes on original indicator:
1) Corrections management includes prison sentences (PRISON), remanded in custody (REMAND),
   supervision (ESO, INT_SUPER, SUPER), home detention (HD_REL, HD_SENT), conditions
   (PAROLE, ROC, PDC, PERIODIC), and community sentences (COM_DET, CW, COM_PROG, COM_SERV, OTH_COM)
2) Corrections management excludes not managed (ALIVE), deceased, deported or over 90 (AGED_OUT)
   not applicate (NA), or errors (ERROR).
3) This data set includes only major management periods, of which Prison is one type.
   Where a person has multiple management/sentence types this dataset only records the
   most severe. See introduction of Corrections documentation (2016).
4) A small but meaningful number of snz_uid codes (between 1% and 5%) have some form of duplicate
   records. These people can be identified by having more than one [cor_mmp_max_period_nbr] value.
   To avoid double counting, we keep only the records that are part of the longest sequence.
   This requires the inner join.
   An alternative approach would be to keep the sequence with the longest duration.
   The assumption behind keeping the more complex sequences is that the increased detail makes them
   more likely to be true. Contrast for example: 5 year prison sentence, vs. 2 years in prison,
   1 year home detention, 6 months supervision. In this case the first sequence, while longer,
   may not have been updated as the person's conditions changed with the updates appearing on
   the second sequence.
5) A tiny number of snz_uid codes have duplicate records of equal length that can not be
   resolved using [cor_mmp_max_period_nbr]. Best estimates for the size of this group is <0.1%
   of the population. We have left these duplicate records in place.
6) One day is subtracted from the end date to ensure periods are non-overlapping.
7) From March 2022 refresh, the input table to this definition changed.
	[ov_major_mgmt_periods] is now [ov_major_mgmt_periods_historic]
	And we use its replacement: [ra_ofndr_major_mgmt_period_a]

Additional notes on modification
i)	We seek to exclude YJ related offending that results in a transfer. The exclusion of spells that started before the
	18th birthday is intended to address this. In theory, the way corrections processes their data (looking at the type of corrections
	management (eg, imprisonment, bail, home D) means this should exclude these continuous spells. Comparing to moj data for sentences 
	of Home D or prison, for offending after the person turned 18 (or 17 for pre-1 July 2019 offending) is intended to confirm this.
	It produced near identical results (very small differences in group proportions, or where larger proportions were found, very low counts).



Parameters & Present values:
  Current refresh = 202410
  Prefix = defn_
  Project schema = [DL-MAA2023-46]
 
Issues:
 
History (reverse order):
2024-08-07 SA update for change to ra_ofndr_major_mgmt_period_a
2021-06-04 FL update the input table to the latest reference
2020-07-22 JB QA
2020-07-16 MP QA
2020-02-28 SA v1
**************************************************************************************************/


:setvar TBLTOUPDATE "icm_master_table"
:setvar targetdb "IDI_Sandpit"
:setvar projectschema "[DL-MAA2016-23]"
:setvar idicleanversion "IDI_Clean_202406"


-- Existing indicator

/* Set database for writing views */
USE IDI_UserCode
GO

/* Clear existing view */
DROP VIEW IF EXISTS $(projectschema).[icm_defn_corrections_any];
GO

/* Create view */
CREATE VIEW $(projectschema).[icm_defn_corrections_any] AS
SELECT a.snz_uid
		,a.cor_rommp_prev_directive_type
		,a.[cor_rommp_directive_type]
		,a.cor_rommp_next_directive_type
		,a.cor_rommp_lead_offence_code
		,a.cor_rommp_imposed_days_nbr
		,a.[cor_rommp_period_start_date] AS [start_date]
		,DATEADD(DAY, -1, a.[cor_rommp_period_end_date]) AS [end_date]
FROM [$(idicleanversion)].[cor_clean].[ra_ofndr_major_mgmt_period_a] AS a
INNER JOIN (
	SELECT snz_uid, MAX([cor_rommp_max_period_nbr]) AS [cor_rommp_max_period_nbr]
	FROM [$(idicleanversion)].[cor_clean].[ra_ofndr_major_mgmt_period_a]
	GROUP BY snz_uid
) AS b
ON a.snz_uid = b.snz_uid
AND a.[cor_rommp_max_period_nbr] = b.[cor_rommp_max_period_nbr]
WHERE [cor_rommp_directive_type] NOT IN ('AGED_OUT', 'ALIVE', 'ERROR', 'NA')
AND [cor_rommp_period_start_date] IS NOT NULL
AND [cor_rommp_period_end_date] IS NOT NULL
AND [cor_rommp_period_start_date] <= [cor_rommp_period_end_date];
GO


-- Modification/application
	
DROP TABLE IF EXISTS #lifetime_incarceration;
WITH birth_dates AS (
	SELECT snz_uid
		,snz_birth_date_proxy
		,DATEADD(YEAR,27,snz_birth_date_proxy) AS turns_27
		,DATEADD(MONTH, 217,snz_birth_date_proxy) AS turns_18 -- The month after the person turns 18
	FROM $(targetdb).$(projectschema).$(TBLTOUPDATE)
	WHERE Age_Group IN ('18-25','27-30'))
SELECT DISTINCT c.snz_uid
INTO #lifetime_incarceration
FROM [IDI_UserCode].$(projectschema).[icm_defn_corrections_any] c
LEFT JOIN birth_dates d
	ON c.snz_uid = d.snz_uid
WHERE 
	[cor_rommp_directive_type] IN ('HOME DETENTION','IMPRISONMENT', 'REMAND')
	AND [start_date] > IIF([start_date]> '2019-06-30', turns_18, DATEADD(YEAR,-1,turns_18))
	AND [start_date] <turns_27
	AND [start_date]  <= '2022-12-31'


DROP TABLE IF EXISTS #current_incarceration;
SELECT DISTINCT c.snz_uid
INTO #current_incarceration
FROM [IDI_UserCode].$(projectschema).[icm_defn_corrections_any] c
LEFT JOIN [$(idicleanversion)].[data].[personal_detail] d
	ON c.snz_uid = d.snz_uid
WHERE 
	2022 BETWEEN YEAR([start_date]) AND YEAR([end_date])
	AND [start_date] >DATEADD(MONTH, 217, d.snz_birth_date_proxy) -- Add 18 years and 1 month to birthdate
	AND [cor_rommp_directive_type] IN ('HOME DETENTION','IMPRISONMENT')




------------------------------------------------- Remove existing columns (if any) from Master Table

ALTER TABLE [$(targetdb)].$(projectschema).[$(TBLTOUPDATE)] DROP COLUMN IF EXISTS currently_in_prison_home_d
																,COLUMN IF EXISTS adult_ever_in_prison_home_d;
ALTER TABLE [$(targetdb)].$(projectschema).[$(TBLTOUPDATE)] ADD currently_in_prison_home_d bit
																,adult_ever_in_prison_home_d bit;
GO


------------------------------------------------- Add data to our master table

UPDATE
	[$(targetdb)].$(projectschema).[$(TBLTOUPDATE)]
SET
	currently_in_prison_home_d = IIF(pri.snz_uid IS NOT NULL,1,NULL)

FROM 
	#current_incarceration pri
WHERE [$(targetdb)].$(projectschema).[$(TBLTOUPDATE)].snz_uid = pri.snz_uid


UPDATE
	[$(targetdb)].$(projectschema).[$(TBLTOUPDATE)]
SET
	adult_ever_in_prison_home_d = IIF(pri.snz_uid IS NOT NULL,1,NULL)

FROM 
	#lifetime_incarceration pri
WHERE [$(targetdb)].$(projectschema).[$(TBLTOUPDATE)].snz_uid = pri.snz_uid

