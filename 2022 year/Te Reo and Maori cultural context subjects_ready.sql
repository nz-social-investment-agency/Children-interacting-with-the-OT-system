/******
Author: Charlotte Rose
Modified: D Young (business logic, entities)
Peer Review:

Refresh: 202406

Dependencies:
[IDI_Clean_202406].[moe_clean].[student_standard]
[IDI_Clean_202406].[moe_clean].[provider_profile]
[IDI_Metadata_202406].[moe_school].[provider_type_code]
[IDI_Metadata_202406].[moe_school].[standard23_concord]
[IDI_Metadata_202406].[moe_school].[std_sub23_code]
[IDI_Metadata_202406].[moe_school].[subject23_code]
[IDI_Metadata_202406].[moe_school].[std_type23_code]

Output:
Additional columns of ICM master table

Description:
Looks at people who took Te Reo Maori or Maori cultural standards at NCEA level.

This joins the student standard table onto provider profile (and its metadata) to identify standards provided by schools.

Notes:
1) We are unable to specifically identifiy if standards count toward NCEA or another qualification, however in an attempt to infer NCEA, providers have been restricted to schools, 
   NZQA levels restricted to 1,2 & 3 and standard types restricted to unit or achevied standards.
2) To reduce the size of the dataset, the standard completion date range has been restricted to period of interest for the ICM work
3) Standards which are Maori cultural or te reo but not coded as such, will not be included (there are very few)
4) We look at people by their age at the end of the school year. This is potentially a little confusing mapping back to age:
	(i) The starting point is that 6 year olds legally have to be enrolled in school, but most people enroll at age 5. This could potentially have some flow on effects about how old people
		are likely to be for a school year.
	(ii) After that, it looks like  most people who have a birthday between May and the end of the year will be enrolled for the 'next' year following their birthday. In contrast, those born
		in Jan-Mar will be the same year (April is evenly split)
		SO for example, someone who is born in (say) June will in most cases be 15 when they start fifth form, turn 16 in June, and end their fifth form year at 16.
		In contrast, people born in January will start the year aged 14, have their birthday, and be 15 for the entire 5th form school year.
		This isn't perfect, there are people who fall either side of this line (although very few from July onwards).
		It could also be that some people are skipping a year/held back a year.
5) There is a concern that non-enrolments could skew heavily towards our groups of interest.
	To compensate for this, we could look at something like a snapshot of 15 and 16 year olds, who would generally be expected to be enrolled in 5th or 6th form
	and the proportion who are not enrolled; and the same for 17 year olds. The idea is that, if this is similar across the different interaction groups, then we can 
	discount it as a source of bias. 
6) The indicator includes both Te Reo as a subject, as well as subjects with the Maori cultural context flagged. This has been described by an SME as identifying "standards relating to a 
	language or culture" and that "It is only those that we can identify by their domain, field or standard name, it won't be a complete list since some standards are not explicitly related
	to a culture but can take on a cultural focus (which we can't code for)"
7) We apply a threshold of 14 credits worth of standards attempted
8) Code for identifying subjects was validated against pubished figures of sitting/achieving NCEA in Te Reo (EducationCounts)
9) Code for identifying enrollment was validated against enrolment. School roll return data has three main dates associated (2022): March, July and September. A post on IDCommons 
	identifies that March and July are from all schools, whereas September is just state and state-integrated schools with secondary aged (Year 9+) students only.This post also
	suggestst that there ought to be a June collection on the same basis as the September one. However, this does not appear to be included in any of the School Roll Returns since 2018.
	There is a reasonably large drop off in older students between the March and July date, which creates two options for a denominator. The publicly published figures are based on the July 
	date (and there is good correspondence between these numbers and the IDI data). Given this, we have just included those who are enrolled in July.



******/

:setvar TBLTOUPDATE "icm_master_table"
:setvar targetdb "IDI_Sandpit"
:setvar projectschema "[DL-MAA2016-23]"
:setvar idicleanversion "IDI_Clean_202406"
:setvar idimetadataversion "IDI_Metadata_202406"
:setvar TBLPREF "icm" 
:setvar yr "2022" 


DROP TABLE IF EXISTS #mao;
SELECT DISTINCT [snz_uid]
      ,[moe_sst_standard_code]
	  ,sc.StandardName
	  ,[moe_sst_nzqa_comp_date]
	  ,c.SubjectName
	  ,fc.FieldDescription
	  ,sc.StandardLevel
	  ,CAST(sc.Credit AS INT) Credit -- This is saved in metadata table as a varchar
	  ,IIF(t.StandardTypeCode = '01', 'Unit standard','Achievement standard') StandardType -- have filtered to only unit and achievement standards
	  ,CASE WHEN c.SubjectName = 'Te Reo Maori' THEN 1 ELSE NULL END AS Te_Reo_Maori
	  ,CASE WHEN c.SubjectName <> 'Te Reo Maori' THEN 1 ELSE NULL END AS Maori_other
     -- ,[moe_sst_exam_result_code]
	  ,CASE WHEN [moe_sst_exam_result_code] <> 'N' THEN 1 ELSE NULL END AS Achieved -- we have filtered out results other than N,A,M,E
	  ,CASE WHEN [moe_sst_exam_result_code] = 'N' THEN 1 ELSE NULL END AS Not_achieved  -- we have filtered out results other than N,A,M,E
	  ,er.ExamResultName
	  ,[moe_sst_study_provider_code] as Entity
INTO #mao
  FROM [$(idicleanversion)].[moe_clean].[student_standard] st
  LEFT JOIN [$(idicleanversion)].[moe_clean].[provider_profile] pp ON pp.moe_pp_provider_code = st.moe_sst_study_provider_code
  LEFT JOIN [$(idimetadataversion)].[moe_school].[provider_type_code] pt ON pt.ProviderTypeID = pp.moe_pp_provider_type_code
  LEFT JOIN [$(idimetadataversion)].[moe_school].[standard23_concord] sc ON sc.StandardTableId = st.moe_sst_standard_code
  LEFT JOIN [$(idimetadataversion)].[moe_school].[std_sub23_code] sub ON sub.StandardTableId = st.moe_sst_standard_code
  LEFT JOIN [$(idimetadataversion)].[moe_school].[subject23_code] c ON c.SubjectCode = sub.SubjectCode
  LEFT JOIN [$(idimetadataversion)].[moe_school].[std_type23_code] t ON t.StandardTypeCode = sc.StandardTypeCode
  LEFT JOIN [$(idimetadataversion)].[moe_school].[field23_code] fc ON fc.FieldCode = sc.FieldCode
  LEFT JOIN [$(idimetadataversion)].[moe_school].[exam_result23_code] er ON er.ExamResultCode = st.moe_sst_exam_result_code
  WHERE sc.StandardLevel <= 3 -- NZQA level at NCEA level
	AND t.StandardTypeCode IN ('01','02') -- Unit or acheviement standard -- linked to IIF in SELECT statement above
    AND sub.CulturalContext = 'MAOR' --Maori cultural context
	AND st.moe_sst_nzqa_comp_date BETWEEN '2005-01-01' AND '2023-01-01' --reducing size of dataset
	AND st.moe_sst_exam_result_code IN ('A','M','E','N') -- exclude absent, not entered, not available
	AND pt.ProviderTypeID IN (10032 --Restricted composite
							 ,10048 -- School cluster
							 ,10026 -- Specialist school
							 ,10031 -- Correspondence school
							 ,10029 -- Secondary (Year 7-15)
							 ,10030 -- Composite (Year 1-15)
							 ,10033 -- Secondary (Year 9-15)
							 )


-- Comparing two methods of thinking about this
-- any 14 credits in one year and standard level

/***

SELECT COUNT(DISTINCT snz_uid) FROM #temp
WHERE achieved_credits >= 14
AND YR = 2022

SELECT COUNT(DISTINCT snz_uid) FROM #temp
WHERE attempted_credits >= 14
AND YR = 2022;

WITH grouped AS (SELECT snz_uid, SUM(achieved_credits) achieved_credits FROM #temp
WHERE YR = 2022
GROUP BY snz_uid)
SELECT COUNT(DISTINCT snz_uid) FROM grouped
WHERE achieved_credits >= 14;


WITH grouped AS (SELECT snz_uid, SUM(attempted_credits) attempted_credits FROM #temp
WHERE YR = 2022
GROUP BY snz_uid)
SELECT COUNT(DISTINCT snz_uid) FROM grouped
WHERE attempted_credits >= 14
  ***/


-- Create a list of everyone in the OT group
-- Identify who was currently enrolled in year 11 to 13.
-- Summarise the NCEA data. For each year, subject and level, determine if someone attempted/achieved 14 credits or more
-- Join on to identify (1) all-time highest achievement and attempt; (2) who is currently sitting NCEA; (3) those who currently achieved something

DROP TABLE IF EXISTS #res;
WITH spinosaurus_aegypticus AS (
			SELECT snz_uid, Age FROM $(targetdb).$(projectschema).$(TBLTOUPDATE)
			),
	current_students AS (
			SELECT conc.snz_uid, MAX(CurrentYearLEvel) AS EnrolmentYear, MAX(IIF(CollectionDate = '2022-07-01',1,NULL)) AS enrolled_in_july
			FROM IDI_Adhoc.clean_read_moe.school_roll_return_2022 srr
			INNER JOIN $(idicleanversion).security.concordance conc
				ON srr.snz_moe_uid = conc.snz_moe_uid
			WHERE srr.CurrentYearLevel IN (11,12,13)
			GROUP BY conc.snz_uid),
	subject_achievement AS (
		SELECT snz_uid 
					,SubjectName
					,StandardLevel
					,YEAR(moe_sst_nzqa_comp_date) YR
					,IIF(SUM(Credit)>=14,StandardLevel,0) AS credits_attempted_14
					,IIF(SUM(IIF(Achieved = 1,Credit,0))>=14,StandardLevel,0) AS credits_achieved_14
		FROM #mao mao
		GROUP BY snz_uid 
					,YEAR(moe_sst_nzqa_comp_date)
					,SubjectName
					,StandardLevel)
	SELECT
		jp3.snz_uid
		,IIF(cs.EnrolmentYear IS NOT NULL,'Enrolled','Not enrolled') AS enrolled_in_11_to_13
		,enrolled_in_july
		,MAX(IIF(sa.YR = 2022, credits_attempted_14,0)) AS credits_attempted_14_2022 -- 0 if did not attempt 14 or more, otherwise it is the level of the highest subject for which 14 or more credits were attempted
		,MAX(IIF(sa.YR = 2022, credits_achieved_14,0)) AS credits_achieved_14_2022 -- 0 if did not achieve 14 or more, otherwise it is the level of the highest subject for which 14 or more credits were attempted
		,MAX(credits_attempted_14) AS credits_attempted_14_ever -- 0 if did not attempt 14 or more, otherwise it is the level of the highest subject for which 14 or more credits were attempted
		,MAX(credits_achieved_14) AS credits_achieved_14_ever -- 0 if did not achieve 14 or more, otherwise it is the level of the highest subject for which 14 or more credits were attempted
		,IIF(jp3.Age BETWEEN 15 AND 16,'15-16','17') AS enrolment_age -- use this to identify where there could be people who are not enrolled
	INTO #res
	FROM spinosaurus_aegypticus jp3
	LEFT JOIN current_students cs
		ON jp3.snz_uid = cs.snz_uid
	LEFT JOIN subject_achievement sa
		ON jp3.snz_uid = sa.snz_uid
	GROUP BY jp3.snz_uid
			,jp3.Age
			,cs.EnrolmentYear
			,cs.enrolled_in_july
 

------------------------------------------------- Remove existing columns (if any) from Master Table

ALTER TABLE [$(targetdb)].$(projectschema).[$(TBLTOUPDATE)] DROP COLUMN IF EXISTS enrolled_in_11_to_13
																	,COLUMN IF EXISTS enrolled_in_11_to_13_july
																	,COLUMN IF EXISTS credits_attempted_14_2022
																	,COLUMN IF EXISTS credits_achieved_14_2022
																	,COLUMN IF EXISTS credits_attempted_14_ever
																	,COLUMN IF EXISTS credits_achieved_14_ever
																	,COLUMN IF EXISTS enrolment_age;
ALTER TABLE [$(targetdb)].$(projectschema).[$(TBLTOUPDATE)] ADD enrolled_in_11_to_13 bit
																	,enrolled_in_11_to_13_july bit
																	,credits_attempted_14_2022 bit
																	,credits_achieved_14_2022 bit
																	,credits_attempted_14_ever bit
																	,credits_achieved_14_ever bit
																	,enrolment_age varchar(5);
GO


------------------------------------------------- Add data to our master table

UPDATE
	[$(targetdb)].$(projectschema).[$(TBLTOUPDATE)]
SET
	enrolled_in_11_to_13 = IIF(res.enrolled_in_11_to_13 = 'Enrolled',1,NULL)
	,enrolled_in_11_to_13_july  = enrolled_in_july
	,credits_attempted_14_2022 = IIF(res.credits_attempted_14_2022 IN (1,2,3),1,NULL)
	,credits_achieved_14_2022  = IIF(res.credits_achieved_14_2022 IN (1,2,3),1,NULL)
	,credits_attempted_14_ever = IIF(res.credits_attempted_14_ever IN (1,2,3),1,NULL)
	,credits_achieved_14_ever  = IIF(res.credits_achieved_14_ever IN (1,2,3),1,NULL)
	,enrolment_age = res.enrolment_age
FROM 
	#res res
WHERE [$(targetdb)].$(projectschema).[$(TBLTOUPDATE)].snz_uid = res.snz_uid
	
  
 -- Create entity tables
 -- This is, unfortunately, rather convoluted because of the possibility of bringing credits across from multiple providers, and identifying which subjects qualify
 -- The idea is that our final table has the highest level for which a person achieved/attempted 14+ credits in a Maori cultural context subject
 -- The overall structure is to
 -- (1) Create a spine ("spinosaurus_aegypticus") that is people in our population
 -- (2) Build a table ("current_students") that is the snz_uid of anybody who was enrolled in year 11-13 in 2022, and the max year level they were enrolled in;
 -- (3) Build a table ("subject_achievement") that identifies a person, year, subject level, and subject name for Maori cultural subjects, with an indicator for 
 --	attempting/achieving 14+ credits (0 indicates that they took some credits from the subject but did not attempt/achieve 14 credits in it; 1 indicates that they did) 
 -- (4) Combine the spine and the  tables to identify people in the population and whether they achieved 
 -- (5) We then build 4 tables that contain the entities for each indicator
		-- catt22 - current year attempting 14+ credits (2022)
		-- cach22 - current year achieved 14+ credits (2022)
		-- att - lifetime attempting 14+ credits
		-- ach - lifetime achieved 14+ credits
 -- (6) We combine these tables (union) into a single one, along with a description of what each row is, into a table we can generate indicator specific entity counts from
 -- (7) Save these snz_uid-entity pairs into specific entity tables

DROP TABLE IF EXISTS #ent;
WITH spinosaurus_aegypticus AS (
			SELECT snz_uid, Age FROM $(targetdb).$(projectschema).$(TBLTOUPDATE)
			),
	current_students AS (
			SELECT conc.snz_uid, MAX(CurrentYearLEvel) AS EnrolmentYear
			FROM IDI_Adhoc.clean_read_moe.school_roll_return_2022 srr
			INNER JOIN $(idicleanversion).security.concordance conc
				ON srr.snz_moe_uid = conc.snz_moe_uid
			WHERE srr.CurrentYearLevel IN (11,12,13)
			GROUP BY conc.snz_uid),
	subject_achievement AS (
		SELECT snz_uid 
					,SubjectName
					,StandardLevel
					,YEAR(moe_sst_nzqa_comp_date) YR
					,IIF(SUM(Credit)>=14,StandardLevel,0) AS credits_attempted_14
					,IIF(SUM(IIF(Achieved = 1,Credit,0))>=14,StandardLevel,0) AS credits_achieved_14
		FROM #mao mao
		GROUP BY snz_uid 
					,YEAR(moe_sst_nzqa_comp_date)
					,SubjectName
					,StandardLevel),
	final_achievement AS (SELECT
		jp3.snz_uid
		,MAX(IIF(sa.YR = 2022, credits_attempted_14,0)) AS credits_attempted_14_2022 -- 0 if did not attempt 14 or more, otherwise it is the level of the highest subject for which 14 or more credits were attempted
		,MAX(IIF(sa.YR = 2022, credits_achieved_14,0)) AS credits_achieved_14_2022 -- 0 if did not achieve 14 or more, otherwise it is the level of the highest subject for which 14 or more credits were attempted
		,MAX(credits_attempted_14) AS credits_attempted_14_ever -- 0 if did not attempt 14 or more, otherwise it is the level of the highest subject for which 14 or more credits were attempted
		,MAX(credits_achieved_14) AS credits_achieved_14_ever -- 0 if did not achieve 14 or more, otherwise it is the level of the highest subject for which 14 or more credits were attempted
	FROM spinosaurus_aegypticus jp3
	LEFT JOIN current_students cs
		ON jp3.snz_uid = cs.snz_uid
	LEFT JOIN subject_achievement sa
		ON jp3.snz_uid = sa.snz_uid
	GROUP BY jp3.snz_uid
			),
	-- current year attempting credits
	-- link to any standards for a subject in the current year where 14+ were attempted, that are of the highest level
	catt22 AS (
		SELECT sa.snz_uid 
				,sa.SubjectName
				,sa.StandardLevel
				,sa.YR
				,m.Entity
			FROM subject_achievement sa
			INNER JOIN final_achievement fa
				ON sa.snz_uid = fa.snz_uid
					AND fa.credits_attempted_14_2022 = sa.StandardLevel
			LEFT JOIN #mao m
				ON sa.snz_uid = m.snz_uid
					AND sa.SubjectName = m.SubjectName
					AND sa.StandardLevel = m.StandardLevel
					AND sa.YR = YEAR(m.moe_sst_nzqa_comp_date)
		WHERE sa.YR = 2022),
	-- current year achieving credits
	-- link to any standards for a subject in the current year where 14+ were achieved, that are of the highest level  and were achieved
	cach22 AS (
		SELECT sa.snz_uid 
					,sa.SubjectName
					,sa.StandardLevel
					,sa.YR
					,m.Entity
			FROM subject_achievement sa
			INNER JOIN final_achievement fa
				ON sa.snz_uid = fa.snz_uid
					AND fa.credits_achieved_14_2022 = sa.StandardLevel
			LEFT JOIN #mao m
				ON sa.snz_uid = m.snz_uid
					AND sa.SubjectName = m.SubjectName
					AND sa.StandardLevel = m.StandardLevel
					AND sa.YR = YEAR(m.moe_sst_nzqa_comp_date)
		WHERE sa.YR = 2022
			AND m.Achieved = 1),
	att AS (
		SELECT sa.snz_uid 
					,sa.SubjectName
					,sa.StandardLevel
					,sa.YR
					,m.Entity
			FROM subject_achievement sa
			INNER JOIN final_achievement fa
				ON sa.snz_uid = fa.snz_uid
					AND fa.credits_attempted_14_ever = sa.StandardLevel
			LEFT JOIN #mao m
				ON sa.snz_uid = m.snz_uid
					AND sa.SubjectName = m.SubjectName
					AND sa.StandardLevel = m.StandardLevel
					AND sa.YR = YEAR(m.moe_sst_nzqa_comp_date)),
	ach AS (
		SELECT sa.snz_uid 
					,sa.SubjectName
					,sa.StandardLevel
					,sa.YR
					,m.Entity
			FROM subject_achievement sa
			INNER JOIN final_achievement fa
				ON sa.snz_uid = fa.snz_uid
					AND fa.credits_achieved_14_ever = sa.StandardLevel
			LEFT JOIN #mao m
				ON sa.snz_uid = m.snz_uid
					AND sa.SubjectName = m.SubjectName
					AND sa.StandardLevel = m.StandardLevel
					AND sa.YR = YEAR(m.moe_sst_nzqa_comp_date)
			WHERE m.Achieved = 1
		),
	all_ents  AS (
		SELECT 'current_achievement' AS grp, cach22.* FROM cach22
		UNION
		SELECT 'current_attempts' AS grp, catt22.* FROM catt22
		UNION
		SELECT 'lifetime_achievement' AS grp, ach.* FROM ach
		UNION
		SELECT 'lifetime_attempts' AS grp, att.* FROM att
		)
	SELECT grp, snz_uid 
					,SubjectName
					,StandardLevel
					,YR
					,CAST(Entity AS INT) AS Entity 
	INTO #ent 
	FROM all_ents



DROP TABLE IF EXISTS [$(targetdb)].$(projectschema).[$(TBLPREF)_enrolled_in_11_to_13_ENT];
WITH highest_enrolment AS (
	SELECT snz_moe_uid
			,MAX(CurrentYearLEvel) AS EnrolmentYear
	FROM IDI_Adhoc.clean_read_moe.school_roll_return_2022 
	GROUP BY snz_moe_uid
		),
current_students AS (
	SELECT conc.snz_uid
	--	,EnrolmentYear
		,ProviderNumber AS entity_1
	FROM IDI_Adhoc.clean_read_moe.school_roll_return_2022 srr
	INNER JOIN $(idicleanversion).security.concordance conc
		ON srr.snz_moe_uid = conc.snz_moe_uid
	WHERE srr.CurrentYearLevel IN (11,12,13)
		AND EXISTS (SELECT 1 FROM highest_enrolment he WHERE he.snz_moe_uid = srr.snz_moe_uid AND he.EnrolmentYear = srr.CurrentYearLEvel) -- Limit to rows where the CurrentYearLevel is their highest for the year
		)
SELECT DISTINCT snz_uid
		,entity_1
INTO [$(targetdb)].$(projectschema).[$(TBLPREF)_enrolled_in_11_to_13_ENT]
FROM current_students cs
WHERE  cs.snz_uid IN (SELECT snz_uid FROM [$(targetdb)].$(projectschema).[$(TBLTOUPDATE)]);

CREATE NONCLUSTERED INDEX imagine_all_the_people ON [$(targetdb)].$(projectschema).[$(TBLPREF)_enrolled_in_11_to_13_ENT] (snz_uid);
ALTER TABLE [$(targetdb)].$(projectschema).[$(TBLPREF)_enrolled_in_11_to_13_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


-- 

DROP TABLE IF EXISTS [$(targetdb)].$(projectschema).[$(TBLPREF)_enrolled_in_11_to_13_july_ENT];
WITH highest_enrolment AS (
	SELECT snz_moe_uid
			,MAX(CurrentYearLEvel) AS EnrolmentYear
	FROM IDI_Adhoc.clean_read_moe.school_roll_return_2022 
	WHERE CollectionDate = DATEFROMPARTS($(yr),7,1)
	GROUP BY snz_moe_uid
		),
current_students AS (
	SELECT conc.snz_uid
	--	,EnrolmentYear
		,ProviderNumber AS entity_1
	FROM IDI_Adhoc.clean_read_moe.school_roll_return_2022 srr
	INNER JOIN $(idicleanversion).security.concordance conc
		ON srr.snz_moe_uid = conc.snz_moe_uid
	WHERE srr.CurrentYearLevel IN (11,12,13)
		AND CollectionDate = DATEFROMPARTS($(yr),7,1)
		AND EXISTS (SELECT 1 FROM highest_enrolment he WHERE he.snz_moe_uid = srr.snz_moe_uid AND he.EnrolmentYear = srr.CurrentYearLEvel) -- Limit to rows where the CurrentYearLevel is their highest for the year
		)
SELECT DISTINCT snz_uid
		,entity_1
INTO [$(targetdb)].$(projectschema).[$(TBLPREF)_enrolled_in_11_to_13_july_ENT]
FROM current_students cs
WHERE  cs.snz_uid IN (SELECT snz_uid FROM [$(targetdb)].$(projectschema).[$(TBLTOUPDATE)]);

CREATE NONCLUSTERED INDEX imagine_all_the_people ON [$(targetdb)].$(projectschema).[$(TBLPREF)_enrolled_in_11_to_13_july_ENT] (snz_uid);
ALTER TABLE [$(targetdb)].$(projectschema).[$(TBLPREF)_enrolled_in_11_to_13_july_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);





-- Student standard based entity counts
-- Current attempts
DROP TABLE IF EXISTS [$(targetdb)].$(projectschema).[$(TBLPREF)_credits_attempted_14_2022_ENT];
SELECT DISTINCT snz_uid
		,Entity AS entity_1
INTO [$(targetdb)].$(projectschema).[$(TBLPREF)_credits_attempted_14_2022_ENT]
FROM #ent
WHERE grp = 'current_attempts';


CREATE NONCLUSTERED INDEX imagine_all_the_people ON [$(targetdb)].$(projectschema).[$(TBLPREF)_credits_attempted_14_2022_ENT] (snz_uid);
ALTER TABLE [$(targetdb)].$(projectschema).[$(TBLPREF)_credits_attempted_14_2022_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


-- Current achievement
DROP TABLE IF EXISTS [$(targetdb)].$(projectschema).[$(TBLPREF)_credits_achieved_14_2022_ENT];
SELECT DISTINCT snz_uid
		,Entity AS entity_1
INTO [$(targetdb)].$(projectschema).[$(TBLPREF)_credits_achieved_14_2022_ENT]
FROM #ent
WHERE grp = 'current_achievement';


CREATE NONCLUSTERED INDEX imagine_all_the_people ON [$(targetdb)].$(projectschema).[$(TBLPREF)_credits_achieved_14_2022_ENT] (snz_uid);
ALTER TABLE [$(targetdb)].$(projectschema).[$(TBLPREF)_credits_achieved_14_2022_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


-- Historic attempts
DROP TABLE IF EXISTS [$(targetdb)].$(projectschema).[$(TBLPREF)_credits_attempted_14_ever_ENT];
SELECT DISTINCT snz_uid
		,Entity AS entity_1
INTO [$(targetdb)].$(projectschema).[$(TBLPREF)_credits_attempted_14_ever_ENT]
FROM #ent
WHERE grp = 'lifetime_attempts';

CREATE NONCLUSTERED INDEX imagine_all_the_people ON [$(targetdb)].$(projectschema).[$(TBLPREF)_credits_attempted_14_ever_ENT] (snz_uid);
ALTER TABLE [$(targetdb)].$(projectschema).[$(TBLPREF)_credits_attempted_14_ever_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


-- Historic achievement
DROP TABLE IF EXISTS [$(targetdb)].$(projectschema).[$(TBLPREF)_credits_achieved_14_ever_ENT];
SELECT DISTINCT snz_uid
		,Entity AS entity_1
INTO [$(targetdb)].$(projectschema).[$(TBLPREF)_credits_achieved_14_ever_ENT]
FROM #ent
WHERE grp = 'lifetime_achievement';


CREATE NONCLUSTERED INDEX imagine_all_the_people ON [$(targetdb)].$(projectschema).[$(TBLPREF)_credits_achieved_14_ever_ENT] (snz_uid);
ALTER TABLE [$(targetdb)].$(projectschema).[$(TBLPREF)_credits_achieved_14_ever_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


