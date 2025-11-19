/*** ECE duration
Author: DY
This code looks at ECE attendance based on the ECE_duration. This is based on surveys of newly enrolled students in school.

There are three main fields of interest to us (set out below) that contain data about the type of ECE attended, the hours per week attended, 
and the length of attendance prior to starting school.

-- From the metadata:
--[moe_sed_ece_classification_code] -	When a new entrant student starts school, the school completes a series of standard questions within MoE's system.
										This ECE classification codes are the types of response MoE got for a specific question, that is, "Did the child 
										attend an Early Childhood Education service in the six months prior to starting school?".

--[moe_sed_ece_duration_code] -			ECE duration code - derived from start time and end time of attendance. This field is the response to the question, "Did 
										the child regularly attend Early Childhood Education?"

--[moe_sed_hours_nbr] -					When a new entrant student starts school, the school completes a series of standard questions within MoE's system. 
										The hour_nbr is the response to the question "How many hours per week did the child attend this (ECE) service?", 
										i.e number of hours attended for the identified ECE service - derived from start time and end time. Whithin the 
										MoE's system, the guidance for responding to this question states "if the child has attendance hours varied, or the 
										parent/caregiver is uncertain, please enter an approximate or average number of hours oer week".

Data from the Early Learning Education system (ELI) contained in ece_student_attendance is an alternative source for ECE attendance data. 
However, kohanga reo do not currently provide data to ELI. While this data is expected to be collected soon, it is unclear if any historic data will be available.

The key questions to be answered by this attendance data are (in the context of oranga tamariki system interaction):
- Are/for how long are tamariki attending ECE for prior to starting school?
- How many hours per week are tamariki attending ECE?
- Are tamariki attending kohanga reo (rather than other types)? - this will probably be refined, and may be used to cut other variables (adding complexity...)

Because survey responses can be missing for any particular question, each of these will likely need a different denominator to calculate the rate:
- Are tamariki attending: any attendance, divided by known responses for any attendance
- Kohanga reo: the number of tamariki who said they attended kohanga reo, divided by the number who identified a type (excludes those who don't attend or don't know the type of provider)
- For how long are tamariki attending: The maximum duration recorded for that tamariki (binned), divided by the number of tamariki who provide a response.
- Hours per week: The number of people in the hours/week bin, divided by the number of tamariki who provided a non-zero hour attendance.


This will tell us:
- What proportion of children (surveyed) attended an ECE out of those who answered the question (excluding 'don't know' responses)
- What proportion of children (surveyed) attended kohanga reo out of those who answered the question (excluding 'don't know' responses)
- Of those who did attend an ECE, what proportion attended for 10 hours or more, or for 20 hours or more?
- Of those who attended an ECE, how many years/months did they attend for?

If possible, we can/will break down the last two by kohanga reo status

NB. This needs to be combined with school enrolment data in order to identify when the person started school (and therefore, the period the ECE attendance
	applied to) since the duration table does not include a date. This is flagged as 'first_enrolled_20XX'.

Known issues:
	-	People can have multiple rows. Confusingly, 'unique number' also isn't unique for an individual or individual and ECE type.
		However, this affects a tiny minority (about 0.1%) of people. We will reconcile these through taking max values.
	-	Survey responses can be partially complete, and there is a small  so the denominator is changing depending on the question we ask
	-	This has variable consistency with results from ELI - likely because of parents estimating duration and averaging over a period. It will not
		be possible to reconcile these perfectly.
	
Update frequency of source tables
-- The table appears to be updated each October refresh, with a most recent extraction date for August


At the end is some code to:
- understand duplicate rows (where there are multiple instances of the same unique number for a person)
- understand the relationship where a person attends multiple types of ECE
- understand the start/end of the series and quality/distribution of the hours attended
The upshot of this is that there is a bit of messiness to the data. There are duplicate rows per person, and it is unclear how much where 

***/

/*** Use command mode! In the menu bar, select Query > SQLCMD Mode ***/
 
:setvar refresh "202406"
:setvar first_enrolled_at_school 2023 -- Generally the year after the year of interest (so, the survey that likely relates to the current year)
:setvar targetdb "[IDI_Sandpit]"
:setvar projectschema "[DL-MAA2024-48]"
:setvar targettable "[icm_master_table_202406]"


DROP TABLE IF EXISTS #ece_surveys;
SELECT dur.snz_uid
		,dur.snz_moe_uid
-- type (kohanga reo)
	  ,CASE WHEN COUNT(CASE WHEN dur.[moe_sed_ece_classification_code] = 20631 THEN 1 ELSE NULL END) > 0 THEN 1
			WHEN COUNT(CASE WHEN dur.[moe_sed_ece_classification_code] IN (
													 			--	20630,	--Did not attend
																--	20631,	--Kohanga Reo
																	20632,	--Kindergarten or Education and Care Centre
																	20633,	--Playcentre
																	20634,	--Home based service
																	20635,	--The Correspondence School - Te Aho o Te Kura Pounamu
																	20636,	--Playgroup
																--	20637,	--Unable to establish if attended or not
																--	20638,	--Attended, but don't know what type of service
																	61050	--Attended, but only outside New Zealand
																	) THEN 1 ELSE NULL END) > 0 THEN 0 
			ELSE NULL END AS attended_ece_kohanga	-- 1 if attended kohanga, 0 if attended ECE of a known type but not kohanga, null otherwise. 
													-- Do not use this indicator for totals, but only to determine proportion between kohanga and non-kohanga
-- attendance (any type)
,CASE WHEN COUNT(CASE WHEN dur.[moe_sed_ece_classification_code] IN (
													 			--	20630,	--Did not attend
																	20631,	--Kohanga Reo
																	20632,	--Kindergarten or Education and Care Centre
																	20633,	--Playcentre
																	20634,	--Home based service
																	20635,	--The Correspondence School - Te Aho o Te Kura Pounamu
																	20636,	--Playgroup
																--	20637,	--Unable to establish if attended or not
																	20638,	--Attended, but don't know what type of service
																	61050	--Attended, but only outside New Zealand
																	) THEN 1 ELSE NULL END) > 0 THEN 1 ELSE NULL END AS attended_ece_type_any
,CASE WHEN COUNT(CASE WHEN dur.[moe_sed_ece_classification_code] IN (
													 				20630,	--Did not attend
																	20631,	--Kohanga Reo
																	20632,	--Kindergarten or Education and Care Centre
																	20633,	--Playcentre
																	20634,	--Home based service
																	20635,	--The Correspondence School - Te Aho o Te Kura Pounamu
																	20636,	--Playgroup
																--	20637,	--Unable to establish if attended or not
																	20638,	--Attended, but don't know what type of service
																	61050	--Attended, but only outside New Zealand
																	) THEN 1 ELSE NULL END) > 0 THEN 1 ELSE NULL END AS attended_ece_type_any_denominator
-- duration
	  ,CASE WHEN COUNT(CASE WHEN dur_co.ECEDuration IN ('Yes, for the last 2 years'
														  ,'Yes, for the last 3 years'
														  ,'Yes, for the last 4 years'
														  ,'Yes, for the last 5 or more years') THEN 1 ELSE NULL END) > 0  THEN 1 ELSE NULL END AS ECE_duration_2_years_plus
	  ,CASE WHEN COUNT(CASE WHEN dur_co.ECEDuration IN ('Yes, for the last year') THEN 1 ELSE NULL END) > 0 THEN 1 ELSE NULL END AS ECE_duration_1_year
	  ,CASE WHEN COUNT(CASE WHEN dur_co.ECEDuration IS NOT NULL THEN 1 ELSE NULL END) > 0 THEN 1 ELSE NULL END AS ECE_duration_denominator
-- hours
	  ,CASE WHEN MAX(dur.[moe_sed_hours_nbr])> 20.0 THEN 1 ELSE NULL END AS ECE_hrs_week_20_plus 
	  ,CASE WHEN MAX(dur.[moe_sed_hours_nbr])<= 20.0 AND MAX(dur.[moe_sed_hours_nbr])> 10.0 THEN 1 ELSE NULL END AS ECE_hrs_week_10_up_to_20
	  ,CASE WHEN MAX(dur.[moe_sed_hours_nbr])<= 10.0 THEN 1 ELSE NULL END AS ECE_hrs_week_00_up_to_10
	  ,CASE WHEN MAX(dur.[moe_sed_hours_nbr]) IS NOT NULL THEN 1 ELSE NULL END AS ECE_hrs_week_denominator

INTO #ece_surveys
FROM [IDI_Clean_$(refresh)].[moe_clean].[ece_duration] dur
LEFT JOIN [IDI_Metadata_$(refresh)].[moe_school].[ece_duration23_code] dur_co
ON dur_co.[ECEDurationID] = dur.[moe_sed_ece_duration_code]
LEFT JOIN [IDI_Metadata_$(refresh)].[moe_school].[ece_classif23_code] cla_co
ON cla_co.[ECEClassificationID] = dur.[moe_sed_ece_classification_code]
GROUP BY dur.snz_uid
		,dur.snz_moe_uid

-- Create flag for when a person first enrolled in school (giving an estimate of when the ECE survey relates to)
DROP TABLE IF EXISTS #first_enrolled;
SELECT * 
INTO #first_enrolled
FROM (SELECT snz_uid
		,moe_esi_provider_code
		,YEAR(moe_esi_start_date) first_year_enrolled
		,ROW_NUMBER() OVER (PARTITION BY snz_uid ORDER BY moe_esi_start_date) n 
FROM IDI_Clean_$(refresh).moe_clean.student_enrol) moe
WHERE moe.n = 1
	AND first_year_enrolled = $(first_enrolled_at_school);

-- the logic will be to join on the survey results where the person first enrolled in school in the year, giving us an estimate of when the 
-- ECE attendance related to.

ALTER TABLE $(targetdb).$(projectschema).$(targettable) DROP COLUMN IF EXISTS first_enrolled_$(first_enrolled_at_school) 
															,COLUMN IF EXISTS ECE__hrs_week_20_plus 
															,COLUMN IF EXISTS ECE__hrs_week_10_up_to_20
															,COLUMN IF EXISTS ECE__hrs_week_00_up_to_10
															,COLUMN IF EXISTS ECE__hrs_week_denominator
															,COLUMN IF EXISTS ECE__attended_ece_type_any
															,COLUMN IF EXISTS ECE__attended_ece_type_any_denominator
															,COLUMN IF EXISTS ECE__attended_ece_kohanga
															,COLUMN IF EXISTS ECE__duration_2_years_plus
															,COLUMN IF EXISTS ECE__duration_1_year
															,COLUMN IF EXISTS ECE__duration_denominator;

ALTER TABLE $(targetdb).$(projectschema).$(targettable) ADD first_enrolled_$(first_enrolled_at_school) bit 
															,ECE__hrs_week_20_plus bit
															,ECE__hrs_week_10_up_to_20 bit
															,ECE__hrs_week_00_up_to_10 bit
															,ECE__hrs_week_denominator bit
															,ECE__attended_ece_type_any bit
															,ECE__attended_ece_type_any_denominator bit
															,ECE__attended_ece_kohanga bit
															,ECE__duration_2_years_plus bit
															,ECE__duration_1_year bit
															,ECE__duration_denominator bit;
GO

UPDATE $(targetdb).$(projectschema).$(targettable)

SET first_enrolled_$(first_enrolled_at_school) = 1

FROM #first_enrolled fe
WHERE $(targetdb).$(projectschema).$(targettable).snz_uid = fe.snz_uid;
GO

UPDATE $(targetdb).$(projectschema).$(targettable)

SET ECE__hrs_week_20_plus = ece.ECE_hrs_week_20_plus
	,ECE__hrs_week_10_up_to_20  = ece.ECE_hrs_week_10_up_to_20
	,ECE__hrs_week_00_up_to_10  = ece.ECE_hrs_week_00_up_to_10
	,ECE__hrs_week_denominator  = ece.ECE_hrs_week_denominator
	,ECE__attended_ece_type_any  = ece.attended_ece_type_any
	,ECE__attended_ece_type_any_denominator  = ece.attended_ece_type_any_denominator
	,ECE__attended_ece_kohanga  = ece.attended_ece_kohanga
	,ECE__duration_2_years_plus  = ece.ECE_duration_2_years_plus
	,ECE__duration_1_year  = ece.ECE_duration_1_year
	,ECE__duration_denominator = ece.ECE_duration_denominator

FROM #ece_surveys ece

WHERE $(targetdb).$(projectschema).$(targettable).snz_uid = ece.snz_uid
	AND first_enrolled_$(first_enrolled_at_school) = 1; -- Limits us to people who first enrolled in the year of interest


DROP TABLE IF EXISTS  $(targetdb).$(projectschema).[icm_ECE_ent];
SELECT snz_uid
		,CAST(moe_esi_provider_code AS INT) AS entity_1
INTO $(targetdb).$(projectschema).[icm_ECE_ent]
FROM #first_enrolled ;


CREATE CLUSTERED INDEX first_enrolled_index ON $(targetdb).$(projectschema).[icm_ECE_ent] (snz_uid, entity_1);
ALTER TABLE $(targetdb).$(projectschema).[icm_ECE_ent] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);

