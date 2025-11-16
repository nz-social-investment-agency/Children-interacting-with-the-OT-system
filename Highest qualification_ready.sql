-- Highest qualification
-- Basic code to take the highest qualification from the nqf spells table
-- This takes qualifications from many different sources (secondary, tertiary, targetted training, etc)
-- We use the end of the year in which a person turns 18. A key reason for this (rather than as of turning 18) is that we don't have 
-- enormous granularity over dates, for example the year of tertiary quals is recorded. My understanding is that the student_qualifications table (secondary quals) 
-- reflects NZQA verifying qualifications, and the data is heavily weighted towards completion dates at the end of the year.

-- To summarise NCEA 2+, use age_18,

:setvar targetdb "IDI_Sandpit"
:setvar projectschema "[DL-MAA2016-23]"
:setvar idicleanversion "IDI_Clean_202406"
:setvar nqftable "[highest_nqflevel_spells_202406]"


-- use a refdate that is the first of the month, otherwise calculations (datediffs) may return incorrect results
:setvar refdate "'2023-01-01'" 
:setvar max_age 30 

DROP TABLE IF EXISTS #enrolled_since_15;
SELECT enrol.[snz_uid], MIN(moe_esi_provider_code) entity_1
INTO #enrolled_since_15
FROM $(idicleanversion).moe_clean.student_enrol enrol
INNER JOIN IDI_Sandpit.$(projectschema).icm_master_table pop
ON enrol.snz_uid = pop.snz_uid
WHERE DATEADD(YEAR, 15,eomonth(pop.snz_birth_date_proxy)) < [moe_esi_end_date]
AND DATEADD(YEAR, 18,eomonth(pop.snz_birth_date_proxy)) > [moe_esi_start_date] 
GROUP BY  enrol.snz_uid

DROP TABLE IF EXISTS #moe_secondary_fix;
SELECT snz_uid
	,MAX(ncea_l1) AS ncea_l1
	,MAX(ncea_l2) AS ncea_l2 
	,MAX(ncea_l3) AS ncea_l3 
INTO #moe_secondary_fix
FROM [IDI_Usercode].$(projectschema).[tmp_moe_secondary_quals]
WHERE ncea_l1 = 1 OR ncea_l2 = 1 OR ncea_l3 = 1
AND qual_attained_date < $(refdate)
GROUP BY snz_uid


------------------------------------------------- Remove existing column (if any) from Master Table

ALTER TABLE [IDI_Sandpit].$(projectschema).[icm_master_table] DROP COLUMN IF EXISTS ncea_1
																	,COLUMN IF EXISTS ncea_2
																	,COLUMN IF EXISTS ncea_3
																	,COLUMN IF EXISTS highest_nqf_level
																	,COLUMN IF EXISTS highest_nqf_level__7_plus
																	,COLUMN IF EXISTS highest_nqf_level__4_to_6
																	,COLUMN IF EXISTS highest_nqf_level__1_to_3
																	,COLUMN IF EXISTS highest_nqf_level__2_to_3
																	,COLUMN IF EXISTS highest_nqf_level__2_plus
--																	,COLUMN IF EXISTS NCEA2plus
																	,COLUMN IF EXISTS ncea2_pop;
ALTER TABLE [IDI_Sandpit].$(projectschema).[icm_master_table] ADD ncea_1 bit
																	,ncea_2 bit
																	,ncea_3 bit
																	,highest_nqf_level tinyint
																	,highest_nqf_level__7_plus bit
																	,highest_nqf_level__4_to_6 bit
																	,highest_nqf_level__1_to_3 bit
																	,highest_nqf_level__2_to_3 bit
																	,highest_nqf_level__2_plus bit
--																	,NCEA2plus bit
																	,ncea2_pop bit;
GO



------------------------------------------------- Add data from the fixed secondary table to our master table

UPDATE
	[IDI_Sandpit].$(projectschema).[icm_master_table]
SET
	ncea_1 = CASE WHEN moe.ncea_l1 = 1 THEN 1 ELSE NULL END
	,ncea_2 = CASE WHEN moe.ncea_l2 = 1 THEN 1 ELSE NULL END
	,ncea_3 = CASE WHEN moe.ncea_l3 = 1 THEN 1 ELSE NULL END
	
FROM 
	#moe_secondary_fix moe
WHERE [IDI_Sandpit].$(projectschema).[icm_master_table].snz_uid = moe.snz_uid

------------------------------------------------- Add and update columns into Master Table

UPDATE
	[IDI_Sandpit].$(projectschema).[icm_master_table]
SET
	highest_nqf_level = moe.max_nqflevel_sofar
	,highest_nqf_level__7_plus = CASE WHEN moe.max_nqflevel_sofar IN (7,8,9,10) THEN 1 ELSE NULL END
	,highest_nqf_level__4_to_6 = CASE WHEN moe.max_nqflevel_sofar IN (4,5,6) THEN 1 ELSE NULL END
	,highest_nqf_level__1_to_3 = CASE WHEN moe.max_nqflevel_sofar IN (1,2,3) OR ((moe.max_nqflevel_sofar IS NULL OR moe.max_nqflevel_sofar = 0) AND COALESCE(ncea_3,ncea_2,ncea_1,0)=1) THEN 1 ELSE NULL END
	,highest_nqf_level__2_to_3 = CASE WHEN moe.max_nqflevel_sofar IN (2,3) OR ((moe.max_nqflevel_sofar IS NULL OR moe.max_nqflevel_sofar < 2) AND COALESCE(ncea_3,ncea_2,0)=1) THEN 1 ELSE NULL END
	,highest_nqf_level__2_plus = CASE WHEN moe.max_nqflevel_sofar >= 2 OR COALESCE(ncea_3,ncea_2,0)=1  THEN 1 ELSE NULL END
	
FROM 
	[IDI_Community].[cm_read_HIGHEST_NQFLEVEL_SPELLS].$(nqftable) moe
WHERE [IDI_Sandpit].$(projectschema).[icm_master_table].snz_uid = moe.snz_uid
AND moe.[nqf_attained_date] < $(refdate)
AND moe.until_date >=$(refdate)

UPDATE
	[IDI_Sandpit].$(projectschema).[icm_master_table]
SET
	ncea2_pop = CASE WHEN moe15.snz_uid IS NOT NULL AND Age = 18 THEN 1 ELSE NULL END -- this is the population that is (1) age 18 and (2) was enrolled since age 15
	
FROM 
	#enrolled_since_15 moe15
WHERE [IDI_Sandpit].$(projectschema).[icm_master_table].snz_uid = moe15.snz_uid



-- Build entity table...

DROP TABLE IF EXISTS IDI_Sandpit.$(projectschema).icm_highest_nqf_level_ent;
SELECT DISTINCT moe.snz_uid, entity AS entity_1
INTO IDI_Sandpit.$(projectschema).icm_highest_nqf_level_ent
FROM [IDI_Community].[cm_read_HIGHEST_NQFLEVEL_SPELLS].$(nqftable) moe
INNER JOIN IDI_Sandpit.$(projectschema).icm_master_table pop
ON moe.snz_uid = pop.snz_uid
WHERE moe.nqf_attained_date < $(refdate)
	AND moe.until_date >=$(refdate)

CREATE CLUSTERED INDEX icm_index ON IDI_Sandpit.$(projectschema).icm_highest_nqf_level_ent (snz_uid)
ALTER TABLE IDI_Sandpit.$(projectschema).icm_highest_nqf_level_ent REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS IDI_Sandpit.$(projectschema).icm_ncea2_pop_ent;
SELECT DISTINCT moe.snz_uid, CAST(entity_1 AS INT) entity_1
INTO IDI_Sandpit.$(projectschema).icm_ncea2_pop_ent
FROM #enrolled_since_15 moe
INNER JOIN IDI_Sandpit.$(projectschema).icm_master_table pop
ON moe.snz_uid = pop.snz_uid
WHERE pop.Age = 18

CREATE CLUSTERED INDEX icm_index ON IDI_Sandpit.$(projectschema).icm_ncea2_pop_ent (snz_uid)
ALTER TABLE IDI_Sandpit.$(projectschema).icm_ncea2_pop_ent REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


