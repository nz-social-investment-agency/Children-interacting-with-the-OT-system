/*** 
This code looks at whether a person became a parent, and whether they became a parent for the first time in a specified year.

For the period examined, personal_detail and dia_births produced near identical results. Personal detail appears to have additional records from other sources (more from longer ago)
so this is preferred (and use population definition to exclude temporary migrants, etc)

Datasts used:
	[data].[personal_detail]


***/

:setvar targetdb "IDI_Sandpit"
:setvar projectschema "[DL-MAA2016-23]"
:setvar idicleanversion "IDI_Clean_202406"
:setvar  yr "2022"



-- Build table of births
DROP TABLE IF EXISTS #parents;
SELECT snz_uid
		,IIF(SUM(IIF(child_bday = $(yr),1,0))>0,1,NULL) AS became_parent
		,IIF(MIN(child_bday) = $(yr),1,NULL) AS first_became_parent
		,SUM(IIF(child_bday = $(yr),1,0)) AS nbr_children
INTO #parents
FROM 
	(
	SELECT snz_parent1_uid AS snz_uid
			,snz_birth_year_nbr AS child_bday
	FROM $(idicleanversion).data.personal_detail dat
	WHERE snz_person_ind = 1
		AND snz_spine_ind = 1
		AND snz_parent1_uid IS NOT NULL
	UNION ALL
	SELECT snz_parent2_uid AS snz_uid
			,snz_birth_year_nbr AS child_bday
	FROM $(idicleanversion).data.personal_detail dat
	WHERE snz_person_ind = 1
		AND snz_spine_ind = 1
		AND snz_parent2_uid != snz_parent1_uid
		AND snz_parent2_uid IS NOT NULL
	) birs
GROUP BY snz_uid;
GO




ALTER TABLE $(targetdb).$(projectschema).icm_master_table DROP COLUMN IF EXISTS became_parent
																,COLUMN IF EXISTS first_became_parent
																,COLUMN IF EXISTS nbr_children;
ALTER TABLE $(targetdb).$(projectschema).icm_master_table ADD became_parent bit
															,first_became_parent bit
															,nbr_children TINYINT;
GO

UPDATE
	$(targetdb).$(projectschema).icm_master_table
SET
	became_parent = parent.became_parent
	,first_became_parent = parent.first_became_parent
	,nbr_children = parent.nbr_children
FROM 
	#parents parent
WHERE $(targetdb).$(projectschema).icm_master_table.snz_uid = parent.snz_uid;

