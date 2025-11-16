/**************************************************************************************************
Title: Crime - offenders and victims
Author: Simon Anastasiadis

Inputs & Dependencies:
- [IDI_Clean].[pol_clean].[post_count_offenders]
- [IDI_Clean].[pol_clean].[post_count_victimisations]
Outputs:
- [IDI_UserCode].[DL-MAA2016-15].[defn_crime_offender]
- [IDI_UserCode].[DL-MAA2016-15].[defn_crime_victim]

Description:
Offenders and victims of crime.

Intended purpose:
Determining who has been a victim of crime or an offender.
Counting the number of occurrence of offence or victimisation.
 
Notes:
1) Multiple charges can arise from a single occurrence.
   We use the post_count tables for both offender and victim.
   This means that only the most serious offence/charge from each
   occurrence is used.
2) Not every crime/offence has a person as its victim.
   E.g. drink driving.
   The offender for some victimisations is unknown.
   E.g. Burglary while victim was out.
   Hence the number of offenders and victims will not match.
3) Only captures reported crime to police.
4) When deciding between the earliest possible and latest possible occurence dates, note that the
	gap between the two is generally small - over 90% of records will be a range of 0-2 days window,
	and over 98% will be within 0-30 days of each other. There are a small number of totally implausible
	records (>100 years) that seem likely to represent data entry errors (eg, the year 3021 instead of 2021).
5) Because the data only goes back to mid 2014, we have set a threshold to avoid changes from year to year
	purely as a result of looking at a longer period. 7 years has been used, which is nearly the length of the 
	full data set, and is sufficient to cover the entire potentially TSS-eligible age (between turning 18 and 25)
	
SELECT YEAR([pol_pov_latest_poss_occ_date]) YR, COUNT(*) FROM [IDI_Clean_202406].[pol_clean].[post_count_victimisations] GROUP BY YEAR([pol_pov_latest_poss_occ_date])
ORDER BY YR

Parameters & Present values:
  Current refresh = 202410
  Prefix = defn_
  Project schema = [DL-MAA2016-23]

Issues:
 
History (reverse order):
DY: modified for ICM table
2020-05-20 SA v1
**************************************************************************************************/

:setvar TBLTOUPDATE "icm_master_table"
:setvar targetdb "IDI_Sandpit"
:setvar projectschema "[DL-MAA2016-23]"
:setvar idicleanversion "IDI_Clean_202406"
:setvar idimetadataversion "IDI_Metadata_202406"
:setvar TBLPREF "icm_" 
:setvar  refdate "'2022-12-31'"
:setvar lookback_period 7


SELECT YEAR([pol_pov_earliest_occ_start_date]) YR, COUNT(*)  FROM IDI_Clean_202406.[pol_clean].[post_count_victimisations] GROUP BY YEAR([pol_pov_earliest_occ_start_date]) ORDER BY YR

/* Set database for writing views */
USE IDI_UserCode
GO

/* Clear existing view */
IF OBJECT_ID('$(projectschema).[icm_defn_crime_offender]','V') IS NOT NULL
DROP VIEW $(projectschema).[icm_defn_crime_offender];
GO

/* Create view */
CREATE VIEW $(projectschema).[icm_defn_crime_offender] AS
SELECT [snz_uid]
      ,[pol_poo_occurrence_inv_ind]
      ,[pol_poo_offence_inv_ind]
      ,[pol_poo_proceeding_date]
      ,[pol_poo_offence_code]
      ,[pol_poo_proceeding_code]
      ,[snz_person_ind]
      ,[pol_poo_earliest_occ_start_date]
      ,[pol_poo_latest_poss_occ_date]
FROM [$(idicleanversion)].[pol_clean].[post_count_offenders]
WHERE [snz_person_ind] = 1 --offender is a person
AND snz_uid > 0 --meaningful snz_uid code
AND [pol_poo_occurrence_inv_ind] = 1 --occurrence was investigated
AND [pol_poo_proceeding_code] NOT IN ('300', '999') --exclude not proceeded with and unknown status
GO

/* Clear existing view */
IF OBJECT_ID('$(projectschema).[icm_defn_crime_victim]','V') IS NOT NULL
DROP VIEW $(projectschema).[icm_defn_crime_victim];
GO

/* Create view */
CREATE VIEW $(projectschema).[icm_defn_crime_victim] AS
SELECT v.[snz_uid]
      ,[pol_pov_occurrence_inv_ind]
      ,[pol_pov_offence_inv_ind]
      ,[pol_pov_reported_date]
      ,[pol_pov_offence_code]
      ,[pol_pov_rov_code]
      ,v.[snz_person_ind]
      ,[pol_pov_earliest_occ_start_date]
      ,[pol_pov_latest_poss_occ_date]
	  ,DATEDIFF(MONTH, snz_birth_date_proxy, [pol_pov_latest_poss_occ_date])/12 AS Age_at_victimisation
FROM [$(idicleanversion)].[pol_clean].[post_count_victimisations] v
	LEFT JOIN [$(idicleanversion)].[data].[personal_detail] d
ON v.snz_uid = d.snz_uid
WHERE v.[snz_person_ind] = 1 --victim is a person
	AND v.snz_uid > 0 --meaningful snz_uid code
	AND [pol_pov_occurrence_inv_ind] = 1 --occurrence was investigated
	AND v.[pol_pov_latest_poss_occ_date] BETWEEN DATEADD(YEAR,-1*$(lookback_period),$(refdate)) AND $(refdate)
GO




-- Join victims onto personal detail
-- Take only victimisations that were pre-ref date
-- Identify victimisations in the current year
-- Identify victimisations ever
-- Identify victimisations for adults/before 18
DROP TABLE IF EXISTS #victimisations;	
SELECT snz_uid
		,IIF(COUNT(IIF(Age_at_victimisation >=18,1,NULL))>0,1,NULL) AS victim_adult
		,IIF(COUNT(IIF(Age_at_victimisation < 18,1,NULL))>0,1,NULL) AS victim_cyp
		,IIF(COUNT(IIF(YEAR([pol_pov_latest_poss_occ_date])=2022,1,NULL))>0,1,NULL) AS victim_current
INTO #victimisations
FROM [IDI_UserCode].$(projectschema).[icm_defn_crime_victim]
GROUP BY snz_uid


------------------------------------------------- Remove existing columns (if any) from Master Table

ALTER TABLE [$(targetdb)].$(projectschema).[$(TBLTOUPDATE)] DROP COLUMN IF EXISTS victim_adult
																	,COLUMN IF EXISTS victim_cyp
																	,COLUMN IF EXISTS victim_current;
ALTER TABLE [$(targetdb)].$(projectschema).[$(TBLTOUPDATE)] ADD victim_adult bit
																	,victim_cyp bit
																	,victim_current bit;
GO


------------------------------------------------- Add data to our master table

UPDATE
	[$(targetdb)].$(projectschema).[$(TBLTOUPDATE)]
SET
	victim_adult = vic.victim_adult
	,victim_cyp = vic.victim_cyp
	,victim_current  = vic.victim_current
FROM 
	#victimisations vic
WHERE [$(targetdb)].$(projectschema).[$(TBLTOUPDATE)].snz_uid = vic.snz_uid
	
 