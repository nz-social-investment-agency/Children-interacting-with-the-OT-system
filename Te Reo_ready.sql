/*** Te Reo proficiency

Created by: DY

INput tables:
	$(idicleanversion).cen_clean.census_individual_2023

Output:
	- Joins census results onto a table based on linking the snz_uid.
	- This is currently set to icm_master_table_202410
	
Description:
	This code uses census 2023 to identify Te Reo fluency. It does this based on the official language indicator, which saves having to 
	use regex to identify Maori out of all possible language codes.

	It includes the following codes:
			11 - Māori only
			21 - Māori and English only (not NZ Sign Language)
			22 - Māori and NZ Sign Language only (not English)
			23 - Māori and Other only (not English or NZ Sign Language)
			31 - Māori, English and NZ Sign Language (not Other)
			32 - Māori, English and Other (not NZ Sign Language)
			33 - Māori, NZ Sign Language and Other (not English)
			41 - Māori, English, NZ Sign Language and Other

	The excluded codes are:
			00 - No Language
			12 - English only
			13 - NZ Sign Language only
			24 - English and NZ Sign Language only (not Māori)
			25 - English and Other only (not Māori or NZ Sign Language)
			26 - NZ Sign Language and Other only (not English or Māori)
			34 - English, NZ Sign Language and Other (not Māori)
			51 - Other Languages only (neither English, Māori nor NZ Sign Language)
			97 - Response unidentifiable
			98 - Response outside scope
			99 - Languages not stated


Results from census 2023 were checked against census 2018, for those who answered both censuses.
It appears that there are inconsistencies in responses between censuses. This has not been reconciled, people have been taken at their word.

One hypothestis is that this may be people with recent learning and lower levels of proficiency who become less confident/proficient in their actual/perceived level. Unfortunately 
census is a binary indicator (yes/no) rather than recording level of proficiency, so cannot be used in this way.

Note that census 2023 was (just) outside the year of interest (2022), being held on or before 7 March 2023 (up to 66 days after). It is not expected that results would meaningfully 
change in the two months and 7 days.

Changelog:
	- 2024-11-06 DY created initial version


***/

/* NOTE: this code uses SQL Command Mode. To activate, in the menu bar click Query> SQLCMD Mode. This enables setting variables, but will disable autocompletion of table names. */

:setvar targetdb "IDI_Sandpit"
:setvar projectschema "DL-MAA2024-48"
:setvar idicleanversion "IDI_Clean_202410"
:setvar outputtable "icm_master_table_202410"

DROP TABLE IF EXISTS #te_reo;
SELECT 
	snz_uid
	,IIF(cen_ind_official_language_code IN (11, 21, 22, 23, 31, 32, 33, 41),1,NULL) AS Speaks_Te_Reo 
	,IIF(cen_ind_official_language_code NOT IN (97,98,99) AND cen_ind_official_language_code IS NOT NULL,1,NULL) AS Speaks_Te_Reo_denominator -- limit to valid responses
INTO #te_reo
FROM 
	$(idicleanversion).cen_clean.census_individual_2023




----------------------------------------------- Add and update columns into Master Table

ALTER TABLE [$(targetdb)].[$(projectschema)].[$(outputtable)] DROP COLUMN IF EXISTS Speaks_Te_Reo
																		,COLUMN IF EXISTS Speaks_Te_Reo_denominator;
ALTER TABLE [$(targetdb)].[$(projectschema)].[$(outputtable)] ADD Speaks_Te_Reo BIT
																,Speaks_Te_Reo_denominator BIT;
GO

UPDATE
	[$(targetdb)].[$(projectschema)].[$(outputtable)]
SET
	Speaks_Te_Reo = cen.Speaks_Te_Reo
	,Speaks_Te_Reo_denominator = cen.Speaks_Te_Reo_denominator
FROM 
	#te_reo cen
WHERE [$(targetdb)].[$(projectschema)].[$(outputtable)].snz_uid = cen.snz_uid;

