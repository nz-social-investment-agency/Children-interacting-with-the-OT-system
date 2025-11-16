
/*** Emergency housing 
This indicator produces a record of snz_uids that have received an emergency housing payment
Code created by: Craig Wright
Modified by: Dan Young

Purpose: 
- identify individuals who have received an emergency housing payment
- identify children of individuals who have received an emergency housing payment who were a child at the time

Key business rules:
- A person who receives a payment from MSD with the msd_tte_pmt_rsn_type_code of 855 is the recipient of an emergency housing payment.
- Where the person has received another payment within 28 days (inclusive) of the first payment, they are presumed to be part of a continuous spell (most payments are 
	thought to cover a 1-3 week period, but there is some uncertainty around the exact timing).
- The spell ends 7 days after the last payment in the spell


Limitations:
The record of dates relates to payment dates. However, emergency housing may have been provided before/after the date.
Records relate to one person within the household who receives the payment (primary applicant).
Linking children to parents in EMH results in about twice as many as expected. Be careful when using this approach - the indicator is of children with a parent 
in EMH, and that the child may not be in EMH. 

-- See trend over time
SELECT YEAR(msd_tte_decision_date) yr, COUNT(*) n
FROM [IDI_Clean_202406].[msd_clean].[msd_third_tier_expenditure] as a 
WHERE msd_tte_pmt_rsn_type_code in ('855') 
GROUP BY YEAR(msd_tte_decision_date)
ORDER BY yr


Structure:
1. Create temp table of emergency housing payments
2. Assign a spell number to each 'continuous' spell (continuous if 28 days or less between payments)
3. Create individual spells, starting with first payment, ending 7 days after last payment
4. Create table of CYP aged 0-17 at the end of the year of interest, and their parents (duplicate entries, one per child-parent paring)
5. Join the parent's spells onto the CYP, for periods where the child is alive (nb. we do not reconcile spells from different parents into single spells - not material for our use)
6. Reconcile down to to a yes/no flag per year

***/

-- Activate cmd mode
:setvar targetdb "IDI_Sandpit"
:setvar projectschema "[DL-MAA2024-48]"
:setvar targettable "ICM_Master_Table_202406"
:setvar idicleanversion "IDI_Clean_202406"
:setvar yr "2022"



-- Code start:
/* 1. Create temp table of emergency housing payments */

DROP TABLE IF EXISTS #eh_master;
-- Identify all EH payments
WITH eh_payments AS (
  SELECT [snz_uid]
      ,[msd_tte_decision_date] [DATE]
	 FROM $(idicleanversion).[msd_clean].[msd_third_tier_expenditure] as a 
	WHERE msd_tte_pmt_rsn_type_code in ('855') 
	GROUP BY snz_uid,[msd_tte_decision_date]),

/* 2. Assign a spell number to each 'continuous' spell (continuous if 28 days or less between payments) */

-- identify the gap between consecutive EH payments
spells as (
	SELECT [snz_uid]
		,[date]
		,row_number() OVER (PARTITION BY snz_uid ORDER BY [date]) as rn
		,DATEDIFF(DAY
				,LAG(date) OVER (PARTITION BY snz_uid ORDER BY [date])
				,[date]) as diff 
	FROM eh_payments as a),

-- Group payments which are within 28 days (inclusive) of the previous payment. Assign a number to each group, representing the number of the spell
grouped_spells AS (
	SELECT snz_uid
		,[date]
		,SUM(IIF(diff is null or diff>28, 1, 0)) over (partition by snz_uid order by date)  as spell
		FROM spells)

/* 3. Create individual spells, starting with first payment, ending 7 days after last payment */
-- Reduce spells to a single entry, calculate duration
SELECT snz_uid
		,spell
		,MIN([date]) [start_date]
		,DATEADD(DAY,7,MAX([date])) [end_date]
		,datediff(DAY,MIN([date]) ,DATEADD(DAY,7,MAX([date]))) duration
INTO #eh_master
FROM grouped_spells
GROUP BY snz_uid ,spell;


/* 4. Create table of CYP aged 0-17 at the end of the year of interest, and their parents (duplicate entries, one per child-parent paring) */

/*** Children 
There is an issue that children are not going to be the one receiving the payment. MSD does record children, but the data doesn't make it 
to the IDI as part of this dataset. The parent-child links available in the MSD child dataset doesn't seem to provide these parent-child links (using only the ones recorded
would represent only about 1/3 of the expected count).

So we will use:
	- Either the child has received the payment; OR
	- One or both the birth parents from personal detail have received it during a period where the child was under 18
NB. Some care in interpreting this is necessary - parents may be separated
NNB. Parent's spells are not currently reconciled. We care about any spell occuring, so do not need to, but these may need to be dealt with in some way if you
are using this for another purpose.
*/


DROP TABLE IF EXISTS #parents_emh_spells;
WITH parent_link AS
	(SELECT snz_uid,snz_parent1_uid AS parent_uid, DATEFROMPARTS(YEAR(snz_birth_date_proxy),MONTH(snz_birth_date_proxy),1) AS [start_date], EOMONTH(DATEADD(year, 18, snz_birth_date_proxy)) AS [end_date]
	FROM $(idicleanversion).[data].[personal_detail]
	WHERE snz_birth_date_proxy BETWEEN DATEFROMPARTS($(yr) - 17, 1,1) AND DATEFROMPARTS($(yr),12,31) -- Aged 0-17 at end of 2022
		AND snz_parent1_uid IS NOT NULL
	UNION
	SELECT snz_uid,snz_parent2_uid AS parent_uid, DATEFROMPARTS(YEAR(snz_birth_date_proxy),MONTH(snz_birth_date_proxy),1) AS [start_date], EOMONTH(DATEADD(year, 18, snz_birth_date_proxy)) AS [end_date]
	FROM $(idicleanversion).[data].[personal_detail]
	WHERE snz_birth_date_proxy BETWEEN DATEFROMPARTS($(yr) - 17, 1,1) AND DATEFROMPARTS($(yr),12,31)
		AND snz_parent2_uid IS NOT NULL)
SELECT par.snz_uid -- the snz_uid of the child
		,par.parent_uid -- the snz_uid of the parent who received the EMH payment (or the amount was paid on behalf of)
		,NULL AS spell
		,CASE WHEN par.[start_date] <= em.[start_date] THEN em.[start_date] ELSE par.[start_date] END AS [start_date] -- for spells that overlap with the child's birth, use the child's birthday as the start
		,CASE WHEN par.[end_date] <= em.[end_date] THEN par.[end_date] ELSE em.[end_date] END AS [end_date] -- for spells where the young person ages out, use the latest possible date the child aged out as the date end date (for the child)
INTO #parents_emh_spells
FROM #eh_master em
INNER JOIN parent_link par
	ON em.snz_uid = par.parent_uid
		AND par.[start_date] <= em.[end_date] -- the child is born before the end of the EMH spell
		AND par.[end_date] >= em.[start_date]; -- the child has not aged out before the start of the EMH spell


/* 5. Join the parent's spells onto the CYP, for periods where the child is alive */
-- Pull it all together into a single table
DROP TABLE IF EXISTS #emh;
WITH pop AS 
		(SELECT snz_uid FROM #eh_master
		UNION 
		SELECT snz_uid FROM #parents_emh_spells),
	ind  AS -- individual's own emh spells
		(SELECT snz_uid
					,MAX(IIF($(yr) >=YEAR(start_date) AND $(yr)<= YEAR(end_date),1,0)) AS emergency_housing_current -- a spell started in or before the year of interest and ended in or after the year of interest
					,MAX(IIF($(yr) >=YEAR(start_date),1,0)) AS emergency_housing_life -- any spell in or before the year of interest means you had some lifetime exposure
				FROM #eh_master
				GROUP BY snz_uid),
	par AS -- a childn's parent's spells
		(SELECT snz_uid
					,MAX(IIF($(yr) >=YEAR(start_date) AND $(yr)<= YEAR(end_date),1,0)) AS emergency_housing_current -- a spell started in or before the year of interest and ended in or after the year of interest
					,MAX(IIF($(yr) >=YEAR(start_date),1,0)) AS emergency_housing_life -- any spell in or before the year of interest means you had some lifetime exposure
				FROM #parents_emh_spells
				GROUP BY snz_uid)
/* 6. Reconcile down to to a yes/no flag per year */
SELECT pop.snz_uid
		,CASE WHEN ind.emergency_housing_current = 1 OR par.emergency_housing_current = 1 THEN 1 ELSE NULL END AS emergency_housing_current
		,CASE WHEN ind.emergency_housing_life = 1 OR par.emergency_housing_life = 1 THEN 1 ELSE NULL END AS emergency_housing_life
		,CASE WHEN ind.emergency_housing_current = 1 THEN 1 ELSE NULL END AS emergency_housing_current_individual
		,CASE WHEN ind.emergency_housing_life = 1 THEN 1 ELSE NULL END AS emergency_housing_life_individual
INTO #emh
FROM pop
LEFT JOIN  ind
	ON ind.snz_uid = pop.snz_uid
LEFT JOIN  par
	ON par.snz_uid = pop.snz_uid;




ALTER TABLE IDI_Sandpit.[DL-MAA2024-48].$(targettable) DROP COLUMN IF EXISTS emergency_housing_life
																,COLUMN IF EXISTS emergency_housing_current
																,COLUMN IF EXISTS emergency_housing_life_individual
																,COLUMN IF EXISTS emergency_housing_current_individual;
ALTER TABLE IDI_Sandpit.[DL-MAA2024-48].$(targettable) ADD emergency_housing_life bit
																,emergency_housing_current bit
																,emergency_housing_life_individual bit
																,emergency_housing_current_individual bit;
GO

UPDATE
	IDI_Sandpit.[DL-MAA2024-48].$(targettable)
SET
	emergency_housing_life = emh.emergency_housing_life
	,emergency_housing_current = emh.emergency_housing_current
	,emergency_housing_life_individual = emh.emergency_housing_life_individual
	,emergency_housing_current_individual = emh.emergency_housing_current_individual

FROM 
	#emh emh
	WHERE IDI_Sandpit.[DL-MAA2024-48].$(targettable).snz_uid = emh.snz_uid;

ALTER TABLE IDI_Sandpit.[DL-MAA2024-48].$(targettable) REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);




DROP TABLE IF EXISTS #emh2;
WITH pop AS 
		(SELECT snz_uid FROM #eh_master
		UNION 
		SELECT snz_uid FROM #parents_emh_spells),
	ind  AS -- individual's own emh spells
		(SELECT snz_uid
					,MAX(IIF(2022 >=YEAR(start_date) AND 2022<= YEAR(end_date),1,0)) AS emergency_housing_current -- a spell started in or before the year of interest and ended in or after the year of interest
					,MAX(IIF(2022 >=YEAR(start_date),1,0)) AS emergency_housing_life -- any spell in or before the year of interest means you had some lifetime exposure
				FROM #eh_master
				GROUP BY snz_uid),
	par AS -- a childn's parent's spells
		(SELECT snz_uid
					,MAX(IIF(2022 >=YEAR(start_date) AND 2022<= YEAR(end_date),1,0)) AS emergency_housing_current -- a spell started in or before the year of interest and ended in or after the year of interest
					,MAX(IIF(2022 >=YEAR(start_date),1,0)) AS emergency_housing_life -- any spell in or before the year of interest means you had some lifetime exposure
				FROM #parents_emh_spells
				GROUP BY snz_uid)
/* 6. Reconcile down to to a yes/no flag per year */
SELECT pop.snz_uid
		,CASE WHEN par.emergency_housing_current = 1 THEN 1 ELSE NULL END AS emergency_housing_current_parent
		,CASE WHEN par.emergency_housing_life = 1 THEN 1 ELSE NULL END AS emergency_housing_life_parent
		,CASE WHEN ind.emergency_housing_current = 1 THEN 1 ELSE NULL END AS emergency_housing_current_individual
		,CASE WHEN ind.emergency_housing_life = 1 THEN 1 ELSE NULL END AS emergency_housing_life_individual
INTO #emh2
FROM pop
LEFT JOIN  ind
	ON ind.snz_uid = pop.snz_uid
LEFT JOIN  par
	ON par.snz_uid = pop.snz_uid;
