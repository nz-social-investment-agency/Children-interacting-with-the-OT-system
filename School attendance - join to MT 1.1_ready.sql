/*********************************************
Title: School attendance
Author: Dan Young

Note: Activate SQL command mode under Query > SQLCMD Mode

Inputs & Dependencies:
- [IDI_Sandpit].[DL-MAA2016-23].[moe_sch_att_term_hash_202406]
- [IDI_Sandpit].[DL-MAA2016-23].[icm_master_table]

NB. This sandpit table is temporary until the code module code is updated.
Once this occurs, the input should be [IDI_Community].[cm_read_MOE_SCH_ATT_TERM].[moe_sch_att_term_20XXXX]

Outputs:
- Updates to [IDI_Sandpit].[DL-MAA2016-23].[icm_master_table] to add:
	-- attendance__irregular_absence
	-- attendance__regular_absence
	-- attendance__moderate_absence
	-- attendance__chronic_absence
	-- school_year_pop - 1/NULL for the perosn being between age 5 and 18
	-- school_year_pri_int_pop - population filter for the primary school group in order to have a separate reporting structure for MM for primary and secondary (more people in care in primary so can disaggregate futher)
	-- school_year_sec_pop - population filter for the secondary school group in order to have a separate reporting structure for MM for primary and secondary (more people in care in primary so can disaggregate futher)
	-- school_year_band - for those of school age (see school year pop): Pri-Int when year 1-8 or Sec when year 9-13
	-- school_medium - MM or Non-MM learner

- [IDI_Sandpit].[DL-MAA2016-23].[icm_attendance_ENT]

Description:
This code uses the school attendance code module to assign attendance categories based on the first term of the year (currently 2022).

The code module reconciles daily attendance into up to two half days. Each half day gets coded as Present, Justified Absence, Unjustified Absence, 
or Exam leave.

The total number of half days is counted, and the proprtion that are coded as present are counted.
	Regular Attendance - more than 90% of halfdays coded as present
	Irregular Absence - more than 80% but less than 90% of halfdays coded as present
	Moderate Absence - more than 70% but less than 80% of halfdays coded as present
	Chronic Absence - less than 70% of halfdays coded as present
When determining the proportion present, Exam leave is removed from the denominator.


Intended purpose:
To identify school attendance regularity across different cohorts of people, based on interactions with Oranga Tamariki.

Notes:
While there is a reasonable agreement between the code module code and published figures, there will be some differences including methodology. In particular,
the code module seeks to exclude attendance during periods affected by lockdowns. Joining to a population may have differences (eg, not covered by data - 
although most schools are now said to contribute, arrival since, non-enrolment, etc) and these will be reflected by null rows. Suggest only focussing on individuals
who were included within the school data (ie, denominator is solely the four groups) and investigate further questions like non-enrollment/dropping out separately.

Granularity of attendance type, demographics, and OT groupings may result in some small group sizes. In general, it appears that there is a similarity in high level
trend between early high school, intermediate and primary and within late high school (exam years). 


Parameters & Present values:
  Current refresh = 202406
  Prefix = defn_b4sc
  Project schema = [DL-MAA2016-23]
 
Issues:
- Currently there are two issues with the code module:
	-- When joining onto reporting codes (Present, Justified Absence, Unjustified Absence, Exam Leave) the join excludes rows coded exam leave. This affects the 
	   later application of business rules to calculate total daily attendance and 
	-- When reconciling records to one per day per student, the code groups by reporting_code, which has the unintended effect of separately reconciling each of
	   the reporting codes. This means that the business rules for categorisation will not apply as intended, and that there can be more than 2 half days per person.
  These have been fixed. See correspondence in the Code Module channel on IDCommons.
- There are a reasonably sizable number of "NULL" (missing) attendance bands.

History (reverse order):
2024-07-29 DY adapted to ICM


Run time: 
- <1 min
   


**********************************************/

:setvar SCHLTERM 1
:setvar SCHLYR 2022
:setvar TBLPREF "icm" 
:setvar YYYYMM "202406"
:setvar PROJSCH "DL-MAA2016-23"
:setvar TBLTOUPDATE "icm_master_table"
:setvar SOURCETABLE "moe_sch_att_term_hash_" 

-- Identify school year for 2022. Take the record(s) relating to the school the person is paired with in the school attendance table. 
-- Identify the year level and whether it is Maori medium education.
DROP TABLE IF EXISTS #school_year
SELECT sc.snz_uid
		,max(CurrentYearLevel) CurrentYearLevel -- ranges from 1 to 13
		,CASE WHEN COUNT(IIF(MaoriLanguageLearning in ('F','G','H'),1,NULL)) > 0 THEN 'MM learner' ELSE 'Non-MM learner' END AS school_medium  -- identify MM education. Refer AW's ID Commons post (search for "maori medium")
INTO #school_year
FROM IDI_Adhoc.clean_read_moe.school_roll_return_$(SCHLYR) srr
INNER JOIN IDI_Clean_$(YYYYMM).[security].[concordance] sc
ON srr.snz_moe_uid = sc.snz_moe_uid
WHERE EXISTS (SELECT 1 FROM IDI_Sandpit.[$(PROJSCH)].$(SOURCETABLE)$(YYYYMM) att WHERE att.snz_uid = sc.snz_uid AND att.moe_ssa_provider_code = srr.ProviderNumber
)
GROUP BY sc.snz_uid -- need to group as there will likely be multiple records per student (up to 4 collected per year)

ALTER TABLE [IDI_Sandpit].[$(PROJSCH)].[$(TBLTOUPDATE)] DROP COLUMN IF EXISTS attendance__regular_attendance
				,COLUMN IF EXISTS attendance__irregular_absence
				,COLUMN IF EXISTS attendance__moderate_absence
				,COLUMN IF EXISTS attendance__chronic_absence
				,COLUMN IF EXISTS school_year_pop
				,COLUMN IF EXISTS school_year_band
				,COLUMN IF EXISTS school_medium
				,COLUMN IF EXISTS school_year_pri_int_pop
				,COLUMN IF EXISTS school_year_sec_pop;
ALTER TABLE [IDI_Sandpit].[$(PROJSCH)].[$(TBLTOUPDATE)] ADD attendance__regular_attendance bit
				,attendance__irregular_absence bit
				,attendance__moderate_absence bit
				,attendance__chronic_absence bit
				,school_year_pop bit
				,school_year_band varchar(8)
				,school_medium varchar(14)
				,school_year_pri_int_pop bit
				,school_year_sec_pop bit;
GO

UPDATE [IDI_Sandpit].[$(PROJSCH)].[$(TBLTOUPDATE)]
SET 
	attendance__regular_attendance = CASE WHEN moe.attendance = 'Regular Attendance' THEN 1 ELSE NULL END
	,attendance__irregular_absence = CASE WHEN moe.attendance = 'Irregular Absence' THEN 1 ELSE NULL END
	,attendance__moderate_absence = CASE WHEN moe.attendance = 'Moderate Absence' THEN 1 ELSE NULL END
	,attendance__chronic_absence = CASE WHEN moe.attendance = 'Chronic Absence' THEN 1 ELSE NULL END
	,school_year_pop = CASE WHEN AGE BETWEEN 5 AND 18 THEN 1 ELSE NULL END
FROM [IDI_Sandpit].[$(PROJSCH)].[$(SOURCETABLE)$(YYYYMM)] moe
WHERE [IDI_Sandpit].[$(PROJSCH)].[$(TBLTOUPDATE)].snz_uid = moe.snz_uid
	AND moe.[YEAR] = $(SCHLYR)
	AND moe.[Term] = $(SCHLTERM);

UPDATE [IDI_Sandpit].[$(PROJSCH)].[$(TBLTOUPDATE)]
SET 
	school_year_band = CASE WHEN sy.CurrentYearLevel BETWEEN 1 AND 8 THEN 'Pri-Int' WHEN sy.CurrentYearLevel BETWEEN 9 AND 13 THEN 'Sec' ELSE NULL END 
	,school_medium = CASE WHEN snz_ethnicity_grp2_nbr = 1 THEN sy.school_medium ELSE NULL END -- Only take Maori students. Very few non-Maori students
	,school_year_pri_int_pop = CASE WHEN AGE BETWEEN 5 AND 18  AND sy.CurrentYearLevel BETWEEN 1 AND 8 AND snz_ethnicity_grp2_nbr = 1 THEN 1 ELSE NULL END
	,school_year_sec_pop = CASE WHEN AGE BETWEEN 5 AND 18 AND sy.CurrentYearLevel BETWEEN 9 AND 13 AND snz_ethnicity_grp2_nbr = 1 THEN 1 ELSE NULL END
FROM #school_year sy
WHERE [IDI_Sandpit].[$(PROJSCH)].[$(TBLTOUPDATE)].snz_uid = sy.snz_uid;


-- Single entity table - we joined on this entity ID AND the snz_uid, so must match.
DROP TABLE IF EXISTS [IDI_Sandpit].[$(PROJSCH)].[$(TBLPREF)_attendance_ENT];
SELECT snz_uid
		,CAST (moe_ssa_provider_code AS int) AS entity_1
INTO [IDI_Sandpit].[$(PROJSCH)].[$(TBLPREF)_attendance_ENT]
FROM [IDI_Sandpit].[$(PROJSCH)].[$(SOURCETABLE)$(YYYYMM)] moe
WHERE  moe.snz_uid IN (SELECT snz_uid FROM [IDI_Sandpit].[$(PROJSCH)].[$(TBLTOUPDATE)])
	AND moe.[YEAR] = $(SCHLYR)
	AND moe.[Term] = $(SCHLTERM);


CREATE CLUSTERED INDEX imagine_all_the_people ON [IDI_Sandpit].[$(PROJSCH)].[$(TBLPREF)_attendance_ENT] (snz_uid);
ALTER TABLE [IDI_Sandpit].[$(PROJSCH)].[$(TBLPREF)_attendance_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);

