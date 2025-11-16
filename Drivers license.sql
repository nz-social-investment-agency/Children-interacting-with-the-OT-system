/**************************************************************************************************
Title:Driving Licence Holders
Author: Ashleigh Arendt
Peer review: Charlotte Rose
Modified for ICM: DY

Inputs & Dependencies:
- [IDI_Community].[cm_read_NZTA_DRIVER_LICENCES_STATUS].[nzta_driver_licences_status_$idicleanversion$]
	- This uses {idicleanversion}.[nzta_clean].[drivers_licence_register]

Outputs:
- Update to [icm_master_table]

Description:
Number of drivers licence holders of specific licence classes and stages.

Intended purpose:
Drivers licences enable better access to work, education, healthcare, social connectness and more.

Notes:
1) NZ licences only
2) Only photo licences, excludes temporary paper licence holders
3) Following Waka Kotahi data is limited to current licence holders with the following licence classes:
	- Class 1 Motor Cars and Light Motor Vehicles - learner, restricted or full
	- Class 6 MOtorcycles, Moped or ATV - learner, restricted or full
4) Licence holders under 16 are excluded as the legal age increased from 15 to 16 in August 2011.

The below code shows the options for status, class and stage. We will use Restricted or FUll

SELECT DISTINCT nzta_dlr_class_status_text
FROM [IDI_Community].[cm_read_NZTA_DRIVER_LICENCES_STATUS].[nzta_driver_licences_status_202406] 

SELECT DISTINCT nzta_dlr_licence_class_text
FROM [IDI_Community].[cm_read_NZTA_DRIVER_LICENCES_STATUS].[nzta_driver_licences_status_202406] 

SELECT DISTINCT nzta_dlr_licence_stage_text
FROM [IDI_Community].[cm_read_NZTA_DRIVER_LICENCES_STATUS].[nzta_driver_licences_status_202406] 


-- NB. NZTA website shows that drivers licensing is slightly heirarchical.
-- For class 1-5, if you have a heavier vehicle license you can drive lighter vehicles of the same type (rigid or combination), and if you have a 
-- combination vehicle licence you can also drive rigid vehicles. Class 6 (motorbikes) is separate
-- A Class 2 license entitles you to drive anything covered by a Class 1 licence, in addition to Class 2 vehicles
-- A Class 3 license entitles you to drive anything covered by a Class 1 or Class 2 licence, in addition to Class 3 vehicles
-- A Class 4 license entitles you to drive anything covered by a Class 1 or Class 2 licence (but NOT Class 3), in addition to Class 4 vehicles
-- A Class 5 license entitles you to drive anything covered by a Class 1,2,3 or 4 licence, in addition to Class 5 vehicles
-- See validation code at the bottom that shows only a tiny number of people have a higher class (2-5) without a class 1. 


Parameters & Present values:
  Current refresh = 202406
  Prefix = _
  Project schema = [DL-MAA2024-48]
  Earliest start date = '2018-01-01'
 
Issues:

Runtime: ~20 minutes
 
History (reverse order):
2024-12-20 DY - updates for ICM project
2023-03-24 AA - using Code Modules new version of driving licence code. Reformatted to use CTE over nested query.

**************************************************************************************************/

:setvar targetdb "IDI_Sandpit"
:setvar projectschema "[DL-MAA2024-48]"
:setvar idicleanversion "IDI_Clean_202406"
:setvar targettable "ICM_Master_Table_202406"
:setvar CodeModuleTable "[nzta_driver_licences_status_202406]" -- will need to update this with different refreshes

-- always use a refdate that is the first of the following month, otherwise calculations (datediffs) may return incorrect results
:setvar refdate "'2023-01-01'" 
:setvar max_age 30 


DROP TABLE IF EXISTS #current_driving_licence;

WITH licences AS 
	(SELECT * 
			FROM [IDI_Community].[cm_read_NZTA_DRIVER_LICENCES_STATUS].$(CodeModuleTable) 
			WHERE nzta_dlr_class_status_text = 'CURRENT' 
				AND nzta_dlr_licence_stage_text IN ('FULL','RESTRICTED') -- nb. if using class 2-5, there is no restricted.
				AND nzta_dlr_licence_class_text IN ('MOTOR CARS AND LIGHT MOTOR VEHICLES'					-- class 1
	--												,'MEDIUM RIGID VEHICLES'								-- class 2
	--												,'MEDIUM COMBINATION VEHICLES'							-- class 3
	--												,'HEAVY RIGID VEHICLES'									-- class 4
	--												,'HEAVY COMBINATION VEHICLES' 							-- class 5
													,'MOTORCYCLES, MOPED OR ATV'							-- class 6
													)
												)
SELECT licences.snz_uid
		,1 AS any_licence
		,CASE WHEN COUNT(CASE WHEN licences.nzta_dlr_licence_stage_text = 'FULL' THEN 1 ELSE NULL END) >0 THEN 1 ELSE NULL END AS full_licence
		,CASE WHEN COUNT(CASE WHEN licences.nzta_dlr_licence_stage_text = 'FULL' THEN 1 ELSE NULL END) = 0  THEN 1 ELSE NULL END AS restricted_licence_only -- our CTE table only includes full and restricted
INTO #current_driving_licence
FROM licences
WHERE $(refdate) < spell_end 
	AND $(refdate) > spell_start
GROUP BY snz_uid


/* Join to Master Table */

ALTER TABLE $(targetdb).$(projectschema).$(targettable) DROP COLUMN IF EXISTS any_licence, COLUMN IF EXISTS full_licence, COLUMN IF EXISTS restricted_licence_only;
ALTER TABLE $(targetdb).$(projectschema).$(targettable) ADD any_licence bit, full_licence BIT, restricted_licence_only BIT;
GO

UPDATE
	$(targetdb).$(projectschema).$(targettable)
SET
	 any_licence= nzta.any_licence
	,full_licence = nzta.full_licence
	,restricted_licence_only = nzta.restricted_licence_only


FROM 
	#current_driving_licence nzta
	WHERE $(targetdb).$(projectschema).$(targettable).snz_uid = nzta.snz_uid;

ALTER TABLE $(targetdb).$(projectschema).$(targettable) REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);
GO

DROP TABLE IF EXISTS #current_driving_licence;


------------------------------ Misc validation and exploration ------------------------------

/***
-- Very good match at all levels with the published figures
SELECT nzta_dlr_licence_class_text
		,COUNT(CASE WHEN nzta_dlr_licence_stage_text = 'LEARNER' THEN 1 ELSE NULL END) AS learner_licence
		,COUNT(CASE WHEN nzta_dlr_licence_stage_text = 'RESTRICTED' THEN 1 ELSE NULL END) AS restricted_licence
		,COUNT(CASE WHEN nzta_dlr_licence_stage_text = 'FULL' THEN 1 ELSE NULL END) AS full_licence
		,COUNT(*) AS total_licences
FROM [IDI_Community].[cm_read_NZTA_DRIVER_LICENCES_STATUS].[nzta_driver_licences_status_202406] 
WHERE nzta_dlr_class_status_text = 'CURRENT' 
	AND nzta_dlr_licence_class_text IN ('MOTOR CARS AND LIGHT MOTOR VEHICLES','MOTORCYCLES, MOPED OR ATV')
	AND '2023-06-30' <= spell_end 
	AND '2023-06-30' > spell_start
GROUP BY nzta_dlr_licence_class_text

-- Results: (compared with published figures from (FY22/23) ()
-- Copare with figures from nzta.govt.nz/resources/new-zealand-driver-licence-register-dlr-statistics/
-- (Use FY 22/23 - query above uses as at 30 Jun 2023). Produces near exact match

***/