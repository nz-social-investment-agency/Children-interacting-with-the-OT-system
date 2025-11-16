/*** Master population query for ICM population ***/

/***
This query:
1. Takes the population of all persons aged 30 and under as at XX date, from data.personal_detail where they are a person on the spine (snz_person_ind and snz_spine_ind are 1)
2. Take basic demographic details from data.personal_detail - sex, ethnicity, age...
3. Applies a population definition to filter to people who are in the country...

4. Groups people into the following groups:
	a. Detailed interaction (mutually exclusive groups)
			For 0-17 year olds
			- Those who experienced Youth Justice and Care and Protection care in the past 12 months
			- Those who experienced Youth Justice custody/care in the past 12 months
			- Those who experienced Care and Protection care in the past 12 months
			- Those who experienced a Youth Justice family group conference [or other other kind of interaction] in the past 12 months
			- Those who experienced an assessment/family group conference (or FWA) in the past 12 months
			- Those who were the subject of a report of concern/notification in the past 12 months
			- Those who experienced care in their lifetime [break down by the type of exit]
			- Those who experienced youth justice intervention in their lifetime 
			- Those who experienced an assessment/family group conference (or FWA) in their lifetime 
			- Those who were the subject of a report of concern/notification in their lifetime 
			For 18-25 year olds and for 27-30 year olds
			- Those who experienced Youth Justice and Care and Protection care in their lifetime 
			- Those who experienced Youth Justice custody/care in their lifetime 
			- Those who experienced Care and Protection care in their lifetime 
			- Those who experienced youth justice intervention in their lifetime 
			- Those who experienced an assessment/family group conference (or FWA) in their lifetime 
			- Those who were the subject of a report of concern/notification in their lifetime 
	b. Transition Support Services eligibility
		Identify 18-25 year olds eligible for transition support
	c. Transition Support Services type
			- Break down by 18-25 year olds eligible for transition support, based on eligibility for each of the three kinds. 
				May need to determine if there is a heirarchy, or combinations...
	d. High level 
			- Experienced care/custody (YJ or C&P) 
			- Experienced other OT
			- No OT interaction

The concepts for each interaction (eg, what is equivalent to YJ FGC) have been taken from the OT Child Wellbeing Model.

***/

:setvar targetdb "IDI_Sandpit"
:setvar projectschema "DL-MAA2024-48"
:setvar idicleanversion "IDI_Clean_202406"
:setvar outputtable "icm_master_table_202406"

-- always use a refdate that is the first of the month, otherwise calculations (datediffs) may return incorrect results
:setvar refdate "'2023-01-01'" 
:setvar max_age 30 

-- Get personal details of everyone
DROP TABLE IF EXISTS #personal_details;
SELECT snz_uid
		,snz_sex_gender_code
		,snz_ethnicity_grp2_nbr
		,snz_birth_date_proxy
		,floor(datediff(month,snz_birth_date_proxy,$(refdate))/12)  AS Age
INTO #personal_details
FROM $(idicleanversion).data.personal_detail
WHERE snz_birth_date_proxy >= dateadd(YEAR,($(max_age)+1)*-1,$(refdate)) -- need to take max_age plus one to pick up people who were born. The ref time is really the moment just prior to the first of the month refdate (as we cannot accurately tell age beyond 1 month granuluarity...)
	AND snz_birth_date_proxy <= $(refdate)
	AND snz_person_ind = 1
	AND snz_spine_ind = 1
CREATE CLUSTERED INDEX my_index_name ON #personal_details (snz_uid);

-- Create population definition: includes people who are resident at some point during the preceding year 
DROP TABLE IF EXISTS #population_definition;
SELECT pop.snz_uid,res_at_refdate 
INTO #population_definition
FROM #personal_details pop
INNER JOIN (SELECT DISTINCT snz_uid
							,CASE 
								WHEN COUNT(CASE 
												WHEN $(refdate) BETWEEN [apc_arp_spell_start_date] AND [apc_arp_spell_end_date] 
													THEN 1 
												ELSE NULL END) >0 
									THEN 1 
								ELSE NULL END AS res_at_refdate
			FROM $(idicleanversion).data.apc_arp_spells 
			WHERE $(refdate)>[apc_arp_spell_start_date] AND [apc_arp_spell_end_date]>= dateadd(YEAR,-1,$(refdate))
			GROUP BY snz_uid
			) res
ON pop.snz_uid = res.snz_uid


CREATE CLUSTERED INDEX my_index_name ON #population_definition (snz_uid);


-- Use population definition to filter population
DROP TABLE IF EXISTS #final_pop;
SELECT det.* 
		,pop.res_at_refdate
-- YJ placements
		,yj_pla_1Y
		,yj_pla_life
-- C&P placements
		,cp_pla_1Y
		,cp_pla_life
-- Home placements
		,hmc_pla_1Y
		,hmc_pla_life
-- YJ FGC and equivalent
		,COALESCE(cp_fgc_life,cp_fwa_life) AS cp_fgc_eq_life
		,COALESCE(cp_fgc_1Y,cp_fwa_1Y) AS cp_fgc_eq_1Y
-- C&P FGC and equivalent
		,COALESCE(yj_fgc_life,yj_sup_life,yj_fwa_life) AS yj_fgc_eq_life
		,COALESCE(yj_fgc_1Y,yj_sup_1Y,yj_fwa_1Y) AS yj_fgc_eq_1Y
-- INV/CFA		
		,cp_cfa_life
		,cp_cfa_1Y
-- Notifications (described as RoC for the OTAP)
		,cp_notif_life
		,cp_notif_1Y
-- Reports of concern (code module)
		,cp_roc_life
		,cp_roc_1Y
INTO #final_pop
FROM #personal_details det
INNER JOIN #population_definition pop
ON det.snz_uid = pop.snz_uid

-- Placements - YJ, C&P, Homeplacements
LEFT JOIN (SELECT snz_uid
					,CASE WHEN COUNT(CASE WHEN dateadd(YEAR,-1,$(refdate)) <= [cyf_ple_event_to_date_wid_date] 
							AND cyf_pld_placement_type_code IN ('RESCJP','RESNON','RESYJ','RMNDHM')
								THEN 1 
								ELSE NULL END )>= 1 THEN 1 
						ELSE NULL END AS yj_pla_1Y
					,CASE WHEN COUNT(CASE WHEN cyf_pld_placement_type_code IN ('RESCJP','RESNON','RESYJ','RMNDHM') THEN 1 ELSE NULL END) >=1
								THEN 1
								ELSE NULL END AS yj_pla_life
		,CASE WHEN COUNT(CASE WHEN dateadd(YEAR,-1,$(refdate)) <= [cyf_ple_event_to_date_wid_date] 
					AND cyf_pld_placement_type_code IN ('CFSS', 'CYP', 'IWI', 'PSS', 'WHA', 'FAM','WCP', 'BRD', 'SGHP' -- foster care
						,'RESCP', 'RESIDCR', 'RESMHA'	-- respite care
						,'INDEP', 'YOOC', 'YSFHCD', 'YSFHSA', 'AKCOMMRESISVC', 'KAAHUIWHETUU' -- other care
						)
						THEN 1 
						ELSE NULL END )>= 1 THEN 1 
				ELSE NULL END AS cp_pla_1Y
		,CASE WHEN COUNT(CASE WHEN cyf_pld_placement_type_code IN ('CFSS', 'CYP', 'IWI', 'PSS', 'WHA', 'FAM','WCP', 'BRD', 'SGHP' -- foster care
						,'RESCP', 'RESIDCR', 'RESMHA'	-- respite care
						,'INDEP', 'YOOC', 'YSFHCD', 'YSFHSA', 'AKCOMMRESISVC', 'KAAHUIWHETUU' -- other care
						) THEN 1 ELSE NULL END) >=1
					THEN 1
			ELSE NULL END AS cp_pla_life
			,CASE WHEN COUNT(CASE WHEN dateadd(YEAR,-1,$(refdate)) <= [cyf_ple_event_to_date_wid_date] 
					AND cyf_pld_placement_type_code IN ('REMHM','RETHM')
						THEN 1 
						ELSE NULL END )>= 1 THEN 1 
				ELSE NULL END AS hmc_pla_1Y
		,CASE WHEN COUNT(CASE WHEN cyf_pld_placement_type_code IN ('REMHM','RETHM') THEN 1 ELSE NULL END) >=1
					THEN 1
			ELSE NULL END AS hmc_pla_life
	FROM $(idicleanversion).cyf_clean.cyf_placements_event pla_ev
	LEFT JOIN $(idicleanversion).cyf_clean.cyf_placements_details pla_dt
	ON pla_dt.snz_composite_event_uid = pla_ev.snz_composite_event_uid
	WHERE $(refdate) > [cyf_ple_event_from_date_wid_date]
	GROUP BY snz_uid) pla
ON pla.snz_uid = pop.snz_uid


-- Youth justice supervision orders (part of YJ FGC)

LEFT JOIN (SELECT snz_uid
					,CASE WHEN COUNT(CASE WHEN [cyf_lse_event_to_date_wid_date] >= dateadd(YEAR, -1,$(refdate))
												THEN 1 
											ELSE NULL END) >=1 
								THEN 1 
							ELSE NULL END AS yj_sup_1Y
					,1 AS yj_sup_life
			FROM $(idicleanversion).cyf_clean.cyf_dt_cli_legal_status_cys_d d
			LEFT JOIN $(idicleanversion).cyf_clean.cyf_ev_cli_legal_status_cys_f f
			ON d.snz_composite_event_uid = f.snz_composite_event_uid
			WHERE cyf_lsd_legal_status_code in ('S283K','S307','S3074')
			AND $(refdate) > [cyf_lse_event_from_date_wid_date]
			GROUP BY snz_uid) lse
ON lse.snz_uid = pop.snz_uid

-- Family group conference

LEFT JOIN (SELECT snz_uid
				,CASE WHEN COUNT(CASE WHEN cyf_fgd_business_area_type_code = 'CNP' THEN 1 ELSE NULL END) >= 1 THEN 1 ELSE NULL END AS cp_fgc_life
				,CASE WHEN COUNT(CASE WHEN cyf_fgd_business_area_type_code = 'CNP' AND [cyf_fge_event_from_datetime] >= dateadd(YEAR, -1,$(refdate)) THEN 1 ELSE NULL END) >= 1 THEN 1 ELSE NULL END AS cp_fgc_1Y
				,CASE WHEN COUNT(CASE WHEN cyf_fgd_business_area_type_code = 'YJU' THEN 1 ELSE NULL END) >= 1 THEN 1 ELSE NULL END AS yj_fgc_life
				,CASE WHEN COUNT(CASE WHEN cyf_fgd_business_area_type_code = 'YJU' AND [cyf_fge_event_from_datetime] >= dateadd(YEAR, -1,$(refdate)) THEN 1 ELSE NULL END) >= 1 THEN 1 ELSE NULL END AS yj_fgc_1Y
			FROM $(idicleanversion).cyf_clean.cyf_ev_cli_fgc_cys_f fgc_ev
			LEFT JOIN $(idicleanversion).cyf_clean.cyf_dt_cli_fgc_cys_d fgc_dt
			ON fgc_dt.snz_composite_event_uid = fgc_ev.snz_composite_event_uid
			WHERE $(refdate) > cyf_fge_event_from_datetime
			GROUP BY snz_uid) fgc
ON fgc.snz_uid = pop.snz_uid
-- Family whanau agreement

LEFT JOIN (SELECT snz_uid
				,CASE WHEN COUNT(CASE WHEN cyf_fwd_business_area_type_code = 'CNP' THEN 1 ELSE NULL END) >= 1 THEN 1 ELSE NULL END AS cp_fwa_life
				,CASE WHEN COUNT(CASE WHEN cyf_fwd_business_area_type_code = 'CNP' AND [cyf_fwe_event_to_date_wid_date] >= dateadd(YEAR, -1,$(refdate)) THEN 1 ELSE NULL END) >= 1 THEN 1 ELSE NULL END AS cp_fwa_1Y
				,CASE WHEN COUNT(CASE WHEN cyf_fwd_business_area_type_code = 'YJU' THEN 1 ELSE NULL END) >= 1 THEN 1 ELSE NULL END AS yj_fwa_life
				,CASE WHEN COUNT(CASE WHEN cyf_fwd_business_area_type_code = 'YJU' AND [cyf_fwe_event_to_date_wid_date] >= dateadd(YEAR, -1,$(refdate)) THEN 1 ELSE NULL END) >= 1 THEN 1 ELSE NULL END AS yj_fwa_1Y
			FROM $(idicleanversion).cyf_clean.cyf_ev_cli_fwas_cys_f fwa_ev
			LEFT JOIN $(idicleanversion).cyf_clean.cyf_dt_cli_fwas_cys_d fwa_dt
			ON fwa_dt.snz_composite_event_uid = fwa_ev.snz_composite_event_uid
			WHERE $(refdate) > [cyf_fwe_event_from_date_wid_date]
			GROUP BY snz_uid) fwa
ON fwa.snz_uid = pop.snz_uid

-- Child Family Assessment
-- RoC/Notification
-- RoC (Hayden's code)

	LEFT JOIN (SELECT snz_uid
			,CASE WHEN COUNT(CASE WHEN cyf_ind_business_area_type_code = 'CNP' AND cyf_ind_final_outcome_type_code IN ('FAR','CFA','FARCFA','INV') THEN 1 ELSE NULL END) >= 1 THEN 1 ELSE NULL END AS cp_cfa_life
			,CASE WHEN COUNT(CASE WHEN cyf_ind_business_area_type_code = 'CNP' 
										AND cyf_ind_final_outcome_type_code IN ('FAR','CFA','FARCFA','INV')
										AND cyf_ine_event_to_datetime >= dateadd(YEAR, -1,$(refdate)) THEN 1 
								ELSE NULL END) >= 1 
						THEN 1 
				ELSE NULL END AS cp_cfa_1Y
			,CASE WHEN COUNT(CASE WHEN cyf_ind_business_area_type_code = 'CNP' THEN 1 ELSE NULL END) >= 1 THEN 1 ELSE NULL END AS cp_notif_life
			,CASE WHEN COUNT(CASE WHEN cyf_ind_business_area_type_code = 'CNP' 
										AND cyf_ine_event_to_datetime >= dateadd(YEAR, -1,$(refdate)) THEN 1 
								ELSE NULL END) >= 1 
						THEN 1 
				ELSE NULL END AS cp_notif_1Y
			,CASE WHEN COUNT(CASE WHEN cyf_ind_business_area_type_code = 'CNP' AND [cyf_ind_cnp_notification_ind] = 'Y' THEN 1 ELSE NULL END) >= 1 THEN 1 ELSE NULL END AS cp_roc_life
			,CASE WHEN COUNT(CASE WHEN cyf_ind_business_area_type_code = 'CNP' 
										 AND [cyf_ind_cnp_notification_ind] = 'Y'
										AND cyf_ine_event_to_datetime >= dateadd(YEAR, -1,$(refdate)) THEN 1 
								ELSE NULL END) >= 1 
						THEN 1 
				ELSE NULL END AS cp_roc_1Y
			from $(idicleanversion).cyf_clean.cyf_intakes_event int_ev
			left join $(idicleanversion).cyf_clean.cyf_intakes_details int_dt
			on int_ev.snz_composite_event_uid = int_dt.snz_composite_event_uid
			WHERE cyf_ine_event_from_datetime < $(refdate)
			GROUP BY snz_uid) cfa
	ON cfa.snz_uid = pop.snz_uid


-- Transition support - taken from CWM

DROP TABLE IF EXISTS #TSSpop;
select p.snz_uid 
	, tss.advice_support_eligible
	/* The current/past labels in tss_eligibility are for a specific point in time, the code below adjusts to the childs current age */
	, case when tss.tw_eligible in ('CURRENT','PAST') and p.Age <=20 then 'Current TW' 
		when tss.tw_eligible in ('CURRENT','PAST') and p.Age > 20 then 'Past TW' 
		else 'non-TW' end as tw_eligible
INTO #TSSpop
from $(idicleanversion).cyf_clean.tss_eligibility tss
left join #final_pop p 
on p.snz_uid = tss.snz_uid
where advice_support_eligible in ('CURRENT','PAST')
	and p.Age >=15 and p.Age <=24

/* add if they have been referred */
DROP TABLE IF EXISTS #TSSpop2;

select t.*  
	, last_dec 
	, last_ref
	, case when last_ref IS NULL and last_dec IS NULL then 'No action'
		when last_ref IS NULL then 'Declined'
		when last_dec IS NULL then 'Referred'
		when last_dec > last_ref then 'Declined'
		when last_ref > last_dec then 'Referred'
		when last_ref = last_dec then 'Declined'
		else 'error'
		end as [action]
INTO #TSSpop2
from #TSSpop t
left join (
			select a.snz_uid, max(a.start_date) as last_ref
			from $(idicleanversion).cyf_clean.tss_action a
			inner join #TSSpop t on t.snz_uid=a.snz_uid
			where a.action_type in ('REFTRAN')
				and a.start_date < $(refdate)
			group by a.snz_uid) ref 
on t.snz_uid=ref.snz_uid
left join (
	select a.snz_uid, max(a.start_date) as last_dec
	from $(idicleanversion).cyf_clean.tss_action a
	inner join #TSSpop t on t.snz_uid=a.snz_uid
	where a.action_type in ('DECTRAN')
		and a.start_date < $(refdate)
	group by a.snz_uid) dec 
on t.snz_uid=dec.snz_uid

/* join to original action plan cohort */


DROP TABLE IF EXISTS [$(targetdb)].[$(projectschema)].[$(outputtable)];

select DISTINCT p.* -- duplicate rows are creeping in from the TSS table... blunt fix to take distinct
		,CASE WHEN Age<=17 THEN '0-17'
				WHEN Age <=25 THEN '18-25'
				WHEN Age >= 27 AND Age <= 30 THEN '27-30'
				ELSE NULL END AS Age_Group
		,CASE WHEN Age=30 THEN 30 ELSE NULL END AS Age_Thirty
		,t.action AS TSS_group 
	,case when t.snz_uid is not null then 'TSS' else 'non-TSS' end as TSS
	/* just get a high level view of the non-TSS ones */
	,case when t.snz_uid is not null then tw_eligible else 'non-TSS' end as TW -- TW seems to be the eligibility to remain with caregiver until 21...
	,case when t.snz_uid is not null then action else 'non-TSS' end as Action -- Action reflects the most-recent-in-time action (referred or declined)
INTO [$(targetdb)].[$(projectschema)].[$(outputtable)]
from #final_pop p
left join #TSSpop2 t 
on p.snz_uid = t.snz_uid
AND p.Age >=15 AND p.Age <=24 -- We need the age restrictions because the table records a point in time. We use past/current eligibility plus age to determine whether a person was eligible *at the time*

/* drop tables we don't need*/
DROP TABLE IF EXISTS #TSSpop;
DROP TABLE IF EXISTS #TSSpop2;


CREATE NONCLUSTERED INDEX omg_im_an_index ON [$(targetdb)].[$(projectschema)].[$(outputtable)] (snz_uid)

