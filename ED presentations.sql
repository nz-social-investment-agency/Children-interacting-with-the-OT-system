/*** ED presentations. 

The following code identifies ED presentations. 

Validation: this has been checked against figures published by MOH through their shinyapp (minhealthnz.shinyapps.io/ED_Alcohol_Domicile/)
at an NZ-wide level. While focussing on alcohol-related presentations, this contains counts of events.

A range of different ways to identify events were considered (referring to attendance code, service type, etc). The below best agreed with the shinyapp figures.

-- nnpac is pretty out of date: the below code will print a table to quickly see. As at 202406 refresh, data is available between 2007 and 2022 (FY2007/08 to FY2021/22).
SELECT YEAR(moh_nnp_service_date) YR, COUNT(*)
FROM IDI_Clean_202406.moh_clean.nnpac
GROUP BY YEAR(moh_nnp_service_date)
ORDER BY YR DESC

As a result, we use a different master table (that covers the period 2021-06 to 2022-06).
This was constructed using the master table code.

***/


:setvar window_start "'2021-07-01'"
:setvar window_end "'2022-06-01'"
:setvar idi_archive "[IDI_Clean_202406]"
:setvar targettable "[icm_master_table_202206]"
:setvar projschema "[DL-MAA2024-48]"
:setvar targetdb "IDI_Sandpit"

-- Note: datediff looks at the unit boundary being crossed, so birth *day* within the month is meaningless since we are using months and no month boundary has been crossed.
-- So regardless of the choice of day, you are basically treated as having a birthday on the 1st.
DROP TABLE IF EXISTS #events;
SELECT snz_uid
		,moh_nnp_service_date
		,DATEDIFF(MONTH,DATEFROMPARTS(moh_nnp_birth_year_nbr, moh_nnp_birth_month_nbr,01), moh_nnp_service_date)/12 AS AGE 
		,CONCAT($(window_start),' to ',$(window_end)) AS [reporting_period]
INTO #events
FROM $(idi_archive).moh_clean.nnpac
WHERE moh_nnp_service_date BETWEEN $(window_start) AND $(window_end)
	AND moh_nnp_event_type_code = 'ED';

	
DROP TABLE IF EXISTS #people_by_age;
SELECT snz_uid
		,AGE 
		,COUNT(*) n_events
		,[reporting_period]
INTO #people_by_age
FROM #events 
GROUP BY snz_uid, AGE,[reporting_period];



DROP TABLE IF EXISTS #people;
SELECT snz_uid 
		,SUM(n_events) n_events
		,[reporting_period]
INTO #people
FROM #people_by_age 
GROUP BY snz_uid, [reporting_period]



--add to master--

ALTER TABLE $(targetdb).$(projschema).$(targettable) DROP COLUMN IF EXISTS ed_presentations;
ALTER TABLE $(targetdb).$(projschema).$(targettable) ADD ed_presentations tinyint;
GO

UPDATE
	$(targetdb).$(projschema).$(targettable)
SET
	ed_presentations = ed.n_events
FROM 
	#people ed
	WHERE $(targetdb).$(projschema).$(targettable).snz_uid = ed.snz_uid;


/*** Validation:

Run the code below, and compare with the source in the description at the top.
In all the groups checked the results were very close


WITH first_cut AS (
		SELECT DATEDIFF(MONTH,DATEFROMPARTS(moh_nnp_birth_year_nbr, moh_nnp_birth_month_nbr,01), moh_nnp_service_date)/12 AS AGE
				,CASE WHEN moh_nnp_service_date BETWEEN '2021-07-01' AND '2022-06-30' THEN 'FY2022'
						WHEN moh_nnp_service_date BETWEEN '2020-07-01' AND '2021-06-30' THEN 'FY2021'
							ELSE NULL END AS FY
				,COUNT(DISTINCT snz_uid) n_ppl
				,COUNT(*) n_event
		FROM IDI_Clean_202406.moh_clean.nnpac
		WHERE moh_nnp_service_date BETWEEN '2020-07-01' AND '2022-06-30'
			AND moh_nnp_purchase_unit_code IN ('ED00002'
										,'ED00002A'
										,'ED02001'
										,'ED02001A'
										,'ED03001'
										,'ED03001A'
										,'ED04001'
										,'ED04001A'
										,'ED05001'
										,'ED05001A'
										,'ED06001'
										,'ED06001A'
										,'ED08001'
										,'ED08001')
			AND DATEDIFF(MONTH,DATEFROMPARTS(moh_nnp_birth_year_nbr, moh_nnp_birth_month_nbr,01), moh_nnp_service_date)/12 BETWEEN 10 AND 24
		GROUP BY DATEDIFF(MONTH,DATEFROMPARTS(moh_nnp_birth_year_nbr, moh_nnp_birth_month_nbr,01), moh_nnp_service_date)/12,
				CASE WHEN moh_nnp_service_date BETWEEN '2021-07-01' AND '2022-06-30' THEN 'FY2022'
						WHEN moh_nnp_service_date BETWEEN '2020-07-01' AND '2021-06-30' THEN 'FY2021'
							ELSE NULL END 
							),
tidy as (
	SELECT FY
			,CASE WHEN AGE BETWEEN 10 AND 14 THEN '10 to 14'
				WHEN AGE BETWEEN 15 AND 19 THEN '15 to 19'
				WHEN AGE BETWEEN 20 AND 24 THEN '20 to 24'
				ELSE NULL END AS Age_Band
			,SUM(n_event) AS n_events
	FROM first_cut
	GROUP BY FY
				,CASE WHEN AGE BETWEEN 10 AND 14 THEN '10 to 14'
				WHEN AGE BETWEEN 15 AND 19 THEN '15 to 19'
				WHEN AGE BETWEEN 20 AND 24 THEN '20 to 24'
				ELSE NULL END
	UNION
	
	SELECT FY
			,CASE WHEN AGE BETWEEN 10 AND 24 THEN 'Total: 10 to 24'
				ELSE NULL END AS Age_Band
			,SUM(n_event) AS n_events
	FROM first_cut
	GROUP BY FY
		,CASE WHEN AGE BETWEEN 10 AND 24 THEN 'Total: 10 to 24'
				ELSE NULL END
		)
SELECT Age_Band
		,SUM(IIF(FY = 'FY2021',n_events,0)) AS FY2021
		,SUM(IIF(FY = 'FY2022',n_events,0)) AS FY2022
FROM tidy 
GROUP BY Age_Band
ORDER BY Age_Band;


WITH first_cut AS (
		SELECT DATEDIFF(MONTH,DATEFROMPARTS(moh_nnp_birth_year_nbr, moh_nnp_birth_month_nbr,01), moh_nnp_service_date)/12 AS AGE
				,CASE WHEN moh_nnp_service_date BETWEEN '2021-07-01' AND '2022-06-30' THEN 'FY2022'
						WHEN moh_nnp_service_date BETWEEN '2020-07-01' AND '2021-06-30' THEN 'FY2021'
							ELSE NULL END AS FY
				,COUNT(DISTINCT snz_uid) n_ppl
				,COUNT(*) n_event
		FROM IDI_Clean_202406.moh_clean.nnpac
		WHERE moh_nnp_service_date BETWEEN '2020-07-01' AND '2022-06-30'
			AND moh_nnp_event_type_code = 'ED'
			AND DATEDIFF(MONTH,DATEFROMPARTS(moh_nnp_birth_year_nbr, moh_nnp_birth_month_nbr,01), moh_nnp_service_date)/12 BETWEEN 10 AND 24
		GROUP BY DATEDIFF(MONTH,DATEFROMPARTS(moh_nnp_birth_year_nbr, moh_nnp_birth_month_nbr,01), moh_nnp_service_date)/12,
				CASE WHEN moh_nnp_service_date BETWEEN '2021-07-01' AND '2022-06-30' THEN 'FY2022'
						WHEN moh_nnp_service_date BETWEEN '2020-07-01' AND '2021-06-30' THEN 'FY2021'
							ELSE NULL END 
							),
tidy as (
	SELECT FY
			,CASE WHEN AGE BETWEEN 10 AND 14 THEN '10 to 14'
				WHEN AGE BETWEEN 15 AND 19 THEN '15 to 19'
				WHEN AGE BETWEEN 20 AND 24 THEN '20 to 24'
				ELSE NULL END AS Age_Band
			,SUM(n_event) AS n_events
	FROM first_cut
	GROUP BY FY
				,CASE WHEN AGE BETWEEN 10 AND 14 THEN '10 to 14'
				WHEN AGE BETWEEN 15 AND 19 THEN '15 to 19'
				WHEN AGE BETWEEN 20 AND 24 THEN '20 to 24'
				ELSE NULL END
	UNION
	
	SELECT FY
			,CASE WHEN AGE BETWEEN 10 AND 24 THEN 'Total: 10 to 24'
				ELSE NULL END AS Age_Band
			,SUM(n_event) AS n_events
	FROM first_cut
	GROUP BY FY
		,CASE WHEN AGE BETWEEN 10 AND 24 THEN 'Total: 10 to 24'
				ELSE NULL END
		)
SELECT Age_Band
		,SUM(IIF(FY = 'FY2021',n_events,0)) AS FY2021
		,SUM(IIF(FY = 'FY2022',n_events,0)) AS FY2022
FROM tidy 
GROUP BY Age_Band
ORDER BY Age_Band;

***/
