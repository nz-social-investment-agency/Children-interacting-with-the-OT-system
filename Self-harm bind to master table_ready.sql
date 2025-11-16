/** *
This script joins the self-harm hospitalisation indicator onto the master table, meaning that the 
refer to the self-hard indicator description.

It also identifies the population domiciled in Canterbury DHB, due to the change in how these have been recorded.
***/



:setvar targetdb IDI_Sandpit
:setvar projectschema DL-MAA2016-23
:setvar input_table icm_self_harm_events
:setvar targettable icm_master_table


-- Note: a number of people have no mid-2022 address, although a large number of these are 0-year olds who would not have been born or would not have had an address captured. 
-- We ignore them as they are outside the age range we consider. Of the others, address completeness is much better

DROP TABLE IF EXISTS #mid_2022_address;
SELECT snz_uid
		,IIF(DHB2015_V1_00_NAME = 'Canterbury',NULL,1) AS outside_canterbury_dhb
INTO #mid_2022_address
FROM IDI_Clean_202406.data.address_notification adnot
LEFT JOIN (SELECT DISTINCT MB2023_V1_00,DHB2015_V1_00_NAME FROM IDI_Metadata_202406.data.mb23_higher_geo_v1) geo
	ON adnot.ant_meshblock_code = geo.MB2023_V1_00
WHERE '2022-07-01' BETWEEN adnot.ant_notification_date AND adnot.ant_replacement_date;

DROP TABLE IF EXISTS #self_harm_hosp;
SELECT snz_uid, COUNT(DISTINCT moh_evt_event_id_nbr) AS self_harm_events
INTO #self_harm_hosp
FROM [$(targetdb)].[$(projectschema)].[$(input_table)]
WHERE YEAR(moh_evt_even_date) = 2022
	AND overseas_purchase_code_flag IS NULL
	AND Canterbury_dhb_dom_flag IS NULL
	AND transferred_out IS NULL
--	AND transferred_in IS NULL
GROUP BY snz_uid

-- Attach to master table
ALTER TABLE [$(targetdb)].[$(projectschema)].[$(targettable)] DROP COLUMN IF EXISTS self_harm_hosp, COLUMN IF EXISTS self_harm_age_band, COLUMN IF EXISTS outside_canterbury_dhb, COLUMN IF EXISTS self_harm_pop;
ALTER TABLE [$(targetdb)].[$(projectschema)].[$(targettable)] ADD self_harm_hosp tinyint, self_harm_age_band varchar(8),outside_canterbury_dhb bit, self_harm_pop bit;
GO

------------------------------------------------- Add and update columns into Master Table

UPDATE [$(targetdb)].[$(projectschema)].[$(targettable)]
SET self_harm_age_band = CASE WHEN Age <10 THEN NULL WHEN Age BETWEEN 10 AND 14 THEN '10-14' WHEN Age BETWEEN 15 AND 17 THEN '15-17' ELSE Age_Group END
		,self_harm_pop = IIF(Age >= 10,1,NULL)


UPDATE [$(targetdb)].[$(projectschema)].[$(targettable)]
SET self_harm_hosp = shh.self_harm_events
FROM #self_harm_hosp shh
WHERE [$(targetdb)].[$(projectschema)].[$(targettable)].snz_uid = shh.snz_uid;
 

UPDATE [$(targetdb)].[$(projectschema)].[$(targettable)]
SET outside_canterbury_dhb = mqa.outside_canterbury_dhb
FROM #mid_2022_address mqa
WHERE [$(targetdb)].[$(projectschema)].[$(targettable)].snz_uid = mqa.snz_uid;
 

ALTER TABLE [$(targetdb)].[$(projectschema)].[$(targettable)] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);
GO


-- Create entity table (question of whether this is mental health data, but it is easy to include and as we are using nationwide counts will not be likely to fail on these

DROP TABLE IF EXISTS [$(targetdb)].[$(projectschema)].[icm_self_harm_hosp_ent];
SELECT DISTINCT snz_uid, CAST(moh_evt_facility_code AS INT) AS entity_1
INTO  [$(targetdb)].[$(projectschema)].[icm_self_harm_hosp_ent]
FROM [$(targetdb)].[$(projectschema)].[$(input_table)]
WHERE YEAR(moh_evt_even_date) = 2022
	AND overseas_purchase_code_flag IS NULL
	AND Canterbury_dhb_dom_flag IS NULL
	AND transferred_out IS NULL
--	AND transferred_in IS NULL

CREATE CLUSTERED INDEX AnotherBoringIndexName ON [$(targetdb)].[$(projectschema)].[icm_self_harm_hosp_ent] (snz_uid, entity_1);
ALTER TABLE [$(targetdb)].[$(projectschema)].[icm_self_harm_hosp_ent] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);
GO


