/* Employment (monthly)

This code identifies, for each month of a target year, who is in employment, based on tax data. In particular, those who receive
PAYE taxed income, withholding payments () or paid parent leave are included.

Each month is encoded as "emp_mnthX" where X is between 1 and 12 inclusive.

Entities are saved in separate tables following the naming approach: icm_emp_mthX_ent where X is the corresponding month (between
1 and 12 inclusive).

This is because the current tool can be told to look for an entity table, and it will search for one with the same name as the column.
So you can change these names, but please ensure that the entity table is the same as the column name, 
prefixed by icm_ and suffixed by _ent. For example, if you called the column for January:
  
  column name						entity table
  emp1						--->	icm_emp1_ent
  employed_january_2022		--->	icm_employed_january_2022_ent

There will be future opportunities to change the name:
- When the data is summarised (there is the option to relabel it)
- After the data is output (there is a concordance that creates a 'tidy name' alternative)

Datasets used:
- ir_clean.ird_ems

NB. There is now an employment code module, but I believe this excludes self-employed.


*/



:setvar targetdb "IDI_Sandpit"
:setvar projectschema "[DL-MAA2024-48]"
:setvar targettable "[icm_master_table_202406]"
:setvar idicleanversion "IDI_Clean_202406"
:setvar window_start "'2022-01-01'"
:setvar window_end "'2022-12-31'"

DROP TABLE IF EXISTS #ir_temp;
SELECT icm.snz_uid
		,CASE WHEN COUNT(CASE WHEN MONTH(ir.ir_ems_return_period_date) = 1 THEN 1 ELSE NULL END) > 0 THEN 1 ELSE NULL END AS emp_mth1
		,CASE WHEN COUNT(CASE WHEN MONTH(ir.ir_ems_return_period_date) = 2 THEN 1 ELSE NULL END) > 0 THEN 1 ELSE NULL END AS emp_mth2
		,CASE WHEN COUNT(CASE WHEN MONTH(ir.ir_ems_return_period_date) = 3 THEN 1 ELSE NULL END) > 0 THEN 1 ELSE NULL END AS emp_mth3
		,CASE WHEN COUNT(CASE WHEN MONTH(ir.ir_ems_return_period_date) = 1 THEN 4 ELSE NULL END) > 0 THEN 1 ELSE NULL END AS emp_mth4
		,CASE WHEN COUNT(CASE WHEN MONTH(ir.ir_ems_return_period_date) = 5 THEN 1 ELSE NULL END) > 0 THEN 1 ELSE NULL END AS emp_mth5
		,CASE WHEN COUNT(CASE WHEN MONTH(ir.ir_ems_return_period_date) = 6 THEN 1 ELSE NULL END) > 0 THEN 1 ELSE NULL END AS emp_mth6
		,CASE WHEN COUNT(CASE WHEN MONTH(ir.ir_ems_return_period_date) = 7 THEN 1 ELSE NULL END) > 0 THEN 1 ELSE NULL END AS emp_mth7
		,CASE WHEN COUNT(CASE WHEN MONTH(ir.ir_ems_return_period_date) = 8 THEN 1 ELSE NULL END) > 0 THEN 1 ELSE NULL END AS emp_mth8
		,CASE WHEN COUNT(CASE WHEN MONTH(ir.ir_ems_return_period_date) = 9 THEN 1 ELSE NULL END) > 0 THEN 1 ELSE NULL END AS emp_mth9
		,CASE WHEN COUNT(CASE WHEN MONTH(ir.ir_ems_return_period_date) = 10 THEN 1 ELSE NULL END) > 0 THEN 1 ELSE NULL END AS emp_mth10
		,CASE WHEN COUNT(CASE WHEN MONTH(ir.ir_ems_return_period_date) = 11 THEN 1 ELSE NULL END) > 0 THEN 1 ELSE NULL END AS emp_mth11
		,CASE WHEN COUNT(CASE WHEN MONTH(ir.ir_ems_return_period_date) = 12 THEN 1 ELSE NULL END) > 0 THEN 1 ELSE NULL END AS emp_mth12
INTO #ir_temp
FROM $(targetdb).$(projectschema).$(targettable) icm
INNER JOIN (SELECT *
				FROM $(idicleanversion).ir_clean.ird_ems
				WHERE ir_ems_return_period_date BETWEEN $(window_start) AND $(window_end)
				AND ir_ems_income_source_code IN ('PPL','W&S','WHP')
				AND ir_ems_gross_earnings_amt > 0) ir
ON ir.snz_uid = icm.snz_uid
GROUP BY icm.snz_uid;

CREATE CLUSTERED INDEX the_red_index_goes_faster ON #ir_temp (snz_uid);



ALTER TABLE $(targetdb).$(projectschema).$(targettable) DROP COLUMN IF EXISTS emp_mth1
																,COLUMN IF EXISTS emp_mth2
																,COLUMN IF EXISTS emp_mth3
																,COLUMN IF EXISTS emp_mth4
																,COLUMN IF EXISTS emp_mth5
																,COLUMN IF EXISTS emp_mth6
																,COLUMN IF EXISTS emp_mth7
																,COLUMN IF EXISTS emp_mth8
																,COLUMN IF EXISTS emp_mth9
																,COLUMN IF EXISTS emp_mth10
																,COLUMN IF EXISTS emp_mth11
																,COLUMN IF EXISTS emp_mth12;
ALTER TABLE $(targetdb).$(projectschema).$(targettable) ADD emp_mth1 bit
																,emp_mth2 bit
																,emp_mth3 bit
																,emp_mth4 bit
																,emp_mth5 bit
																,emp_mth6 bit
																,emp_mth7 bit
																,emp_mth8 bit
																,emp_mth9 bit
																,emp_mth10 bit
																,emp_mth11 bit
																,emp_mth12 bit;
GO

UPDATE $(targetdb).$(projectschema).$(targettable)

SET 
	emp_mth1 = ir.emp_mth1
	,emp_mth2  = ir.emp_mth2
	,emp_mth3  = ir.emp_mth3
	,emp_mth4  = ir.emp_mth4
	,emp_mth5  = ir.emp_mth5
	,emp_mth6  = ir.emp_mth6
	,emp_mth7  = ir.emp_mth7
	,emp_mth8  = ir.emp_mth8
	,emp_mth9  = ir.emp_mth9
	,emp_mth10  = ir.emp_mth10
	,emp_mth11  = ir.emp_mth11
	,emp_mth12  = ir.emp_mth12
FROM #ir_temp ir
WHERE $(targetdb).$(projectschema).$(targettable).snz_uid = ir.snz_uid;

DROP TABLE IF EXISTS #ir_temp;


DROP TABLE IF EXISTS #ir_temp_ents;
SELECT ir.snz_uid
				,MONTH(ir_ems_return_period_date) mnth
				,abs(cast(HashBytes('MD5', ir.[ir_ems_enterprise_nbr]) as int)) AS [entity_1] -- need to turn into number not a string
				,abs(cast(HashBytes('MD5', ir.[ir_ems_pbn_nbr]) as int)) AS [entity_2] 
INTO #ir_temp_ents
FROM $(idicleanversion).ir_clean.ird_ems ir
INNER JOIN $(targetdb).$(projectschema).$(targettable) icm
ON ir.snz_uid = icm.snz_uid
WHERE ir_ems_return_period_date BETWEEN $(window_start) AND $(window_end)
	AND ir_ems_income_source_code IN ('PPL','W&S','WHP')
	AND ir_ems_gross_earnings_amt > 0

CREATE CLUSTERED INDEX red_index_with_racing_stripes ON #ir_temp_ents (mnth,snz_uid,entity_1, entity_2);



DROP TABLE IF EXISTS $(targetdb).$(projectschema).icm_emp_mth1_ent;
SELECT DISTINCT snz_uid
				,[entity_1]
				,[entity_2]
INTO $(targetdb).$(projectschema).icm_emp_mth1_ent
FROM #ir_temp_ents
WHERE mnth = 1

ALTER TABLE $(targetdb).$(projectschema).icm_emp_mth1_ent REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
CREATE CLUSTERED INDEX the_red_index_goes_faster ON $(targetdb).$(projectschema).icm_emp_mth1_ent (snz_uid);



DROP TABLE IF EXISTS $(targetdb).$(projectschema).icm_emp_mth2_ent;
SELECT DISTINCT snz_uid
				,[entity_1]
				,[entity_2]
INTO $(targetdb).$(projectschema).icm_emp_mth2_ent
FROM #ir_temp_ents
WHERE mnth = 2

ALTER TABLE $(targetdb).$(projectschema).icm_emp_mth2_ent REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
CREATE CLUSTERED INDEX the_red_index_goes_faster ON $(targetdb).$(projectschema).icm_emp_mth2_ent (snz_uid);



DROP TABLE IF EXISTS $(targetdb).$(projectschema).icm_emp_mth3_ent;
SELECT DISTINCT snz_uid
				,[entity_1]
				,[entity_2]
INTO $(targetdb).$(projectschema).icm_emp_mth3_ent
FROM #ir_temp_ents
WHERE mnth = 3

ALTER TABLE $(targetdb).$(projectschema).icm_emp_mth3_ent REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
CREATE CLUSTERED INDEX the_red_index_goes_faster ON $(targetdb).$(projectschema).icm_emp_mth3_ent (snz_uid);



DROP TABLE IF EXISTS $(targetdb).$(projectschema).icm_emp_mth4_ent;
SELECT DISTINCT snz_uid
				,[entity_1]
				,[entity_2]
INTO $(targetdb).$(projectschema).icm_emp_mth4_ent
FROM #ir_temp_ents
WHERE mnth = 4

ALTER TABLE $(targetdb).$(projectschema).icm_emp_mth4_ent REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
CREATE CLUSTERED INDEX the_red_index_goes_faster ON $(targetdb).$(projectschema).icm_emp_mth4_ent (snz_uid);



DROP TABLE IF EXISTS $(targetdb).$(projectschema).icm_emp_mth5_ent;
SELECT DISTINCT snz_uid
				,[entity_1]
				,[entity_2]
INTO $(targetdb).$(projectschema).icm_emp_mth5_ent
FROM #ir_temp_ents
WHERE mnth = 5

ALTER TABLE $(targetdb).$(projectschema).icm_emp_mth5_ent REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
CREATE CLUSTERED INDEX the_red_index_goes_faster ON $(targetdb).$(projectschema).icm_emp_mth5_ent (snz_uid);



DROP TABLE IF EXISTS $(targetdb).$(projectschema).icm_emp_mth6_ent;
SELECT DISTINCT snz_uid
				,[entity_1]
				,[entity_2]
INTO $(targetdb).$(projectschema).icm_emp_mth6_ent
FROM #ir_temp_ents
WHERE mnth = 6

ALTER TABLE $(targetdb).$(projectschema).icm_emp_mth6_ent REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
CREATE CLUSTERED INDEX the_red_index_goes_faster ON $(targetdb).$(projectschema).icm_emp_mth6_ent (snz_uid);


DROP TABLE IF EXISTS $(targetdb).$(projectschema).icm_emp_mth7_ent
SELECT DISTINCT snz_uid
				,[entity_1]
				,[entity_2]
INTO $(targetdb).$(projectschema).icm_emp_mth7_ent
FROM #ir_temp_ents
WHERE mnth = 7

ALTER TABLE $(targetdb).$(projectschema).icm_emp_mth7_ent REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
CREATE CLUSTERED INDEX the_red_index_goes_faster ON $(targetdb).$(projectschema).icm_emp_mth7_ent (snz_uid);



DROP TABLE IF EXISTS $(targetdb).$(projectschema).icm_emp_mth8_ent;
SELECT DISTINCT snz_uid
				,[entity_1]
				,[entity_2]
INTO $(targetdb).$(projectschema).icm_emp_mth8_ent
FROM #ir_temp_ents
WHERE mnth = 8

ALTER TABLE $(targetdb).$(projectschema).icm_emp_mth8_ent REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
CREATE CLUSTERED INDEX the_red_index_goes_faster ON $(targetdb).$(projectschema).icm_emp_mth8_ent (snz_uid);



DROP TABLE IF EXISTS $(targetdb).$(projectschema).icm_emp_mth9_ent;
SELECT DISTINCT snz_uid
				,[entity_1]
				,[entity_2]
INTO $(targetdb).$(projectschema).icm_emp_mth9_ent
FROM #ir_temp_ents
WHERE mnth = 9

ALTER TABLE $(targetdb).$(projectschema).icm_emp_mth9_ent REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
CREATE CLUSTERED INDEX the_red_index_goes_faster ON $(targetdb).$(projectschema).icm_emp_mth9_ent (snz_uid);



DROP TABLE IF EXISTS $(targetdb).$(projectschema).icm_emp_mth10_ent;
SELECT DISTINCT snz_uid
				,[entity_1]
				,[entity_2]
INTO $(targetdb).$(projectschema).icm_emp_mth10_ent
FROM #ir_temp_ents
WHERE mnth = 10

ALTER TABLE $(targetdb).$(projectschema).icm_emp_mth10_ent REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
CREATE CLUSTERED INDEX the_red_index_goes_faster ON $(targetdb).$(projectschema).icm_emp_mth10_ent (snz_uid);



DROP TABLE IF EXISTS $(targetdb).$(projectschema).icm_emp_mth11_ent;
SELECT DISTINCT snz_uid
				,[entity_1]
				,[entity_2]
INTO $(targetdb).$(projectschema).icm_emp_mth11_ent
FROM #ir_temp_ents
WHERE mnth = 11

ALTER TABLE $(targetdb).$(projectschema).icm_emp_mth11_ent REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
CREATE CLUSTERED INDEX the_red_index_goes_faster ON $(targetdb).$(projectschema).icm_emp_mth11_ent (snz_uid);


DROP TABLE IF EXISTS $(targetdb).$(projectschema).icm_emp_mth12_ent;
SELECT DISTINCT snz_uid
				,[entity_1]
				,[entity_2]
INTO $(targetdb).$(projectschema).icm_emp_mth12_ent
FROM #ir_temp_ents
WHERE mnth = 12

ALTER TABLE $(targetdb).$(projectschema).icm_emp_mth12_ent REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
CREATE CLUSTERED INDEX the_red_index_goes_faster ON $(targetdb).$(projectschema).icm_emp_mth12_ent (snz_uid);


