/***

This code determines the proportion of people attending ECE by type in a given year of interest
It focusses on whether a person attends kohanga reo, a different type, and unknown type, or didn't attend. It excludes people who did not complete the survey

The population for this variable are the people who are Maori ethnicity and first enrolled in school in the specified year.
We will use this population as the summarised variable, and just use the normal population as the population
This is because we want to use the type of ECE as a dimension (text value) rather than having it as a 1=include / NULL=exclude summarised variable

This variable takes the following values:

-- "Kohanga reo" when the person has a survey response that says they attended Kohanga Reo.
-- "Did not attend" when the person has a survey response that says they did not attend an ECE.
-- "Unknown ECE type" when the person has a survey response that says they do not know the type of ECE attended.
-- "Other ECE type" when the person attended any of the following:
		-- Kindergarten or Education and Care Centre
		-- Playcentre (20633)
		-- Home based service (20634)
		-- The Correspondence School - Te Aho o Te Kura Pounamu (20635)
		-- Playgroup (20636)
		-- Attended, but only outside New Zealand (61050)
-- NULL when the response was "Unable to establish if attended", or the person did not answer that survey question 
	(includes when they does not have a survey result at all).

NB. Note that the summary process takes a population and excludes people not in the population, as well as excluding persons who have a NULL for the variable

It takes the following approach:
(1) Set key variables (year of interest, refresh to use, etc)
(2) Identify people who first enroll in school in the specified year
(3) Identify ENROL(?) survey results for the people who enrolled
(4) Process these to identify our group:
	(a) Those who attended kohanga reo
	(b) Those who attended a different, known, type of ECE
	(c) Those who responded that they do not know the type of ECE attended
	(d) Those who responded that they did not attend an ECE
	(e) Those who did not enroll in the year of interest, and those who did not answer this question, are excluded 
(5) We create a denominator for this outside the IDI (avoids percentages summing to more/less than 100%), which is the sum of the groups (a) through (d)

***/


-- (1) Set key variables
:setvar refresh "202406"
:setvar year_of_interest 2023
:setvar targetdb "[IDI_Sandpit]"
:setvar projectschema "[DL-MAA2016-23]"
:setvar targettable "[icm_master_table]"


-- (2) Identify people who first enroll in school in the specified year
-- This table is a list of snz_uids, 
DROP TABLE IF EXISTS #first_school_enrolment;
WITH temp AS (SELECT snz_uid
		,moe_esi_provider_code
		,YEAR(moe_esi_start_date) first_year_enrolled
		,ROW_NUMBER() OVER (PARTITION BY snz_uid ORDER BY moe_esi_start_date) n 
FROM IDI_Clean_$(refresh).moe_clean.student_enrol)
SELECT * 
INTO #first_school_enrolment
FROM temp
WHERE n = 1;

-- (3) Identify ENROL survey results for the people who enrolled

/***  ECE classification codes
20630	Did not attend
20631	Kohanga Reo
20632	Kindergarten or Education and Care Centre
20633	Playcentre
20634	Home based service
20635	The Correspondence School - Te Aho o Te Kura Pounamu
20636	Playgroup
20637	Unable to establish if attended or not
20638	Attended, but don't know what type of service
61050	Attended, but only outside New Zealand
***/

DROP TABLE IF EXISTS #ECE_type_attended;
SELECT snz_uid
	 , CASE WHEN COUNT(IIF(dur.[moe_sed_ece_classification_code] = 20631,1,NULL)) > 0 THEN 'Kohanga Reo'
			WHEN COUNT(IIF (dur.[moe_sed_ece_classification_code] IN (
																			20632,	--Kindergarten or Education and Care Centre
																			20633,	--Playcentre
																			20634,	--Home based service
																			20635,	--The Correspondence School - Te Aho o Te Kura Pounamu
																			20636,	--Playgroup
																			61050	--Attended, but only outside New Zealand
																			),1,NULL)) > 0 THEN 'Other ECE type' 
			WHEN COUNT(IIF(dur.[moe_sed_ece_classification_code] =  20630,1,NULL)) > 0 THEN 'Did not attend'
			WHEN COUNT(IIF(dur.[moe_sed_ece_classification_code] =  20638,1,NULL)) > 0 THEN 'Unknown ECE type'
			ELSE NULL END AS ECE_type -- Includes NULL response,  unable to establish if attended
INTO #ECE_type_attended
FROM [IDI_Clean_$(refresh)].[moe_clean].[ece_duration] dur
LEFT JOIN [IDI_Metadata_$(refresh)].[moe_school].[ece_classif23_code] cla_co
ON cla_co.[ECEClassificationID] = dur.[moe_sed_ece_classification_code]
GROUP BY dur.snz_uid

-- (4) Process these to identify our group
DROP TABLE IF EXISTS #ece_attendance_data
SELECT fse.snz_uid
		, fse.moe_esi_provider_code
		, fse.first_year_enrolled
		,eta.ECE_type
INTO #ece_attendance_data
FROM #first_school_enrolment fse
LEFT JOIN #ECE_type_attended eta
ON fse.snz_uid = eta.snz_uid

/*** Quick look at the data

SELECT first_year_enrolled, ECE_Type, COUNT(*) FROM #ece_attendance_data GROUP BY first_year_enrolled, ECE_Type ORDER BY first_year_enrolled DESC, ECE_Type 

The number of people enrolled is greater than would be expected by birth cohorts, and there is a decrease in the number enrolled and the number of NULLs during Covid.
I haven't applied a population filter, but this suggests to me that the people not included are probably too old.
Restricting to people aged 6 or less at the end of the year confirms this (the NULLs reduce without drastic change to the other groups).

SELECT first_year_enrolled, ECE_Type, COUNT(*) 
FROM #ece_attendance_data ead
INNER JOIN IDI_Clean_202406.data.personal_detail pd
ON ead.snz_uid = pd.snz_uid
	AND ead.first_year_enrolled <= pd.snz_birth_year_nbr+6
--WHERE snz_ethnicity_grp2_nbr = 1
GROUP BY first_year_enrolled, ECE_Type ORDER BY first_year_enrolled DESC, ECE_Type 

-- Run this bit after running the master table update (to see these side by side)
SELECT Proportion_attending_kohanga_reo, ECE_Type, COUNT(*) 
FROM IDI_Sandpit.[DL-MAA2016-23].icm_master_table 
GROUP BY Proportion_attending_kohanga_reo, ECE_Type ORDER BY Proportion_attending_kohanga_reo DESC, ECE_Type 


***/

-- Join to master table


ALTER TABLE $(targetdb).$(projectschema).$(targettable) DROP COLUMN IF EXISTS ECE_type
															,COLUMN IF EXISTS Proportion_attending_kohanga_reo;


ALTER TABLE $(targetdb).$(projectschema).$(targettable) ADD ECE_type varchar(16) 
															,Proportion_attending_kohanga_reo bit;
GO

UPDATE $(targetdb).$(projectschema).$(targettable)

SET ECE_type = ece.ECE_type
	,Proportion_attending_kohanga_reo = IIF(snz_ethnicity_grp2_nbr = 1 AND ece.first_year_enrolled = $(year_of_interest),1,NULL)
FROM #ece_attendance_data ece
WHERE $(targetdb).$(projectschema).$(targettable).snz_uid = ece.snz_uid

DROP TABLE IF EXISTS  $(targetdb).$(projectschema).[icm_Proportion_attending_kohanga_reo_ent];
SELECT snz_uid
		,CAST(moe_esi_provider_code AS INT) AS entity_1
INTO $(targetdb).$(projectschema).[icm_Proportion_attending_kohanga_reo_ent]
FROM #ece_attendance_data 
WHERE first_year_enrolled = $(year_of_interest);


CREATE CLUSTERED INDEX first_enrolled_index ON $(targetdb).$(projectschema).[icm_Proportion_attending_kohanga_reo_ent] (snz_uid, entity_1);
ALTER TABLE $(targetdb).$(projectschema).[icm_Proportion_attending_kohanga_reo_ent] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);

