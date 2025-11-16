/**************************************************************************************************
Title: Join Potentially Avoidable Hospitalisations (code module update)
Author: D Young


Inputs & Dependencies: 
[IDI_Clean_202310].[moh_clean].[pub_fund_hosp_discharges_diag] (code module)
[IDI_Clean_202310].[moh_clean].[pub_fund_hosp_discharges_event] (code module)
[IDI_Sandpit].[DL-MAA2023-55].[tmp2_ASH_PAH]


Outputs:
- Update to [master_table]

Description:
This code applies the Code Module definition of ASH/PAH to update the ICM master table.
It also constructs appropriate age bands for PAH to look at PAH before age 5 (same as with RDP) and PAH within the past year of 0-14 year olds.

Note that PAH as a concept does not exist for adults.

PAH = Preventable by population level intervention / health programs / immunisation etc. This is part of the child youth and wellbeing strategy - child poverty related indicators
report - 2019/2020.


Intended purpose:
To identify disparities in rates of potentially avoidable hospitalisations to assess the performance of social interventions that aim to prevent them.
See code module for more fullsome description.

Notes:
-- events from as far back as 1914, earliest we're interested in is 14YO in 2020Q2 - have they ever had a PAH, so earliest date is 01-07-2005
-- latest data available for events is June 2022, so latest we publish is 2022Q2
-- We're using the birth dates from MoH to align with OT's definition, in future it might be better to take the dates from the personal details table as they are pulled from a 
-- number of sources, some of which may be more reliable
-- See external file for PAH codes
-- Public hospital discharge data is from 1988. However the ash/pah series would start from July 1999 as it uses ICD10, so the first full year of data is 2000. 
-- The code map can be updated manually. Right click IDI_Sandpit, select Tasks > Import Flat File. The Wizard will tell you what to do.
-- RDP primarily looked at people turning 5 who had a PAH prior to that age. However, it also produced (but I understand, did not publish) lifetime PAH for up to 
-- Note that the code module does not always apply a cut off based on maximum age (it appears to do so for disease, not for accidents) - we need to apply this.
-- This includes only events where the primary diagnosis is PAH, consistent with official figures. However, this restriction could be relaxed to incldued secondary diagnosis codes

-- Variables:
-- PAH_1Y		Whether a person experienced a PAH within the past year (1 - yes, NULL - no)
-- PAH_life		Whether a person experienced a PAH within their lifetime (1 - yes, NULL - no)
-- PAH_5YO		Whether a person experienced a PAH before, or in the same month as, turning 5 (1 - yes, NULL - no). 
				NB. This is not restricted to age. So a 14 year old would have events from before they turned 5 recorded; and a 3 year old would have any events from their life to date
					(ie, it is not set to NULL when the person is younger/older than 5)
					Be careful when looking at older people as the data series may not go far enough back to reliably include events.

We also include two new Age dimensions:
-- Age5			Whether the person is age 5. Can either use this as an explicit age band (preferred) or an age filter (not preferred - makes it unclear what the population actually is)
-- Age00_14		Whether the person is aged between 0 and 14 (inclusive). This is used because PAH is a concept for 0-14 year olds.

Parameters & Present values:
  Current refresh = IDI_Clean_202406
  Project schema = DL-MAA2016-23


Run time: ~1 mins

**************************************************************************************************/

:setvar targettable "[ICM_Master_Table]"
:setvar projschema "[DL-MAA2016-23]"
:setvar reportdate "'2022-12-31'"


-- Reconcile ASH_PAH table so that we can join to master
DROP TABLE IF EXISTS #pah;
SELECT snz_uid
		,COUNT(DISTINCT moh_dia_event_id_nbr) AS PAH_LIFE
		,COUNT(DISTINCT IIF(age_mnths <= 60 ,moh_dia_event_id_nbr,NULL)) AS PAH_5YO
		,COUNT(DISTINCT IIF(start_date >= DATEADD(YEAR,-1,$(reportdate)),moh_dia_event_id_nbr,NULL)) AS PAH_1Y
INTO #pah
FROM IDI_Sandpit.[DL-MAA2016-23].tmp2_ASH_PAH
WHERE [start_date] < $(reportdate)
	AND moh_dia_diagnosis_type_code = 'A' -- official figures include only primary diagnosis
	AND age_mnths <=180 -- Aged under 15
	AND PAH_Category != ''
GROUP BY snz_uid


-- Update master with age bands. Could potentially group with next step, but would create potential trap where age bands not created for those with no entry in the temp table.

ALTER TABLE [IDI_Sandpit].$(projschema).$(targettable) DROP COLUMN IF EXISTS Age5, COLUMN IF EXISTS Age00_14, COLUMN IF EXISTS PAH_LIFE, COLUMN IF EXISTS PAH_5YO, COLUMN IF EXISTS PAH_1Y;
ALTER TABLE [IDI_Sandpit].$(projschema).$(targettable) ADD Age5 bit, Age00_14 bit,PAH_LIFE bit,PAH_5YO bit,PAH_1Y tinyint;
GO

UPDATE
	[IDI_Sandpit].$(projschema).$(targettable)
SET
	Age5 = IIF(Age = 5,1,NULL)
	,AGE00_14 = IIF(Age BETWEEN 0 AND 14,1,NULL)

-- Update master with PAH data

UPDATE
	[IDI_Sandpit].$(projschema).$(targettable)
SET
	PAH_1Y = IIF(pah.PAH_1Y>0,1,NULL)
	,PAH_life =IIF([IDI_Sandpit].$(projschema).$(targettable).Age <15 AND pah.PAH_life > 0,1,NULL)  -- 1 if any PAH events, otherwise NULL. Summarisation tool will include people with non-null values
	,PAH_5YO = IIF(pah.PAH_5YO > 0, 1,NULL) -- 1 if any PAH events, otherwise NULL. Summarisation tool will include people with non-null values
FROM 
	#pah pah
	WHERE [IDI_Sandpit].$(projschema).$(targettable).snz_uid = pah.snz_uid;



