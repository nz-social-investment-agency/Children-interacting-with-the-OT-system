/*** Child interacting with OT

This code identifies whether a person in our dataset aged 27-30:
- nbr_children: has children (and how many)
- nbr_children_placement: has children that have interacted with Oranga Tamariki (same categories as used in the main code and CWM) and how many
- nbr_children_interaction: has children that have experienced a FGC/FWA with Oranga Tamariki (same categories as used in the main code and CWM) and how many
- nbr_children_interaction: has children that have experienced a placement/custody with Oranga Tamariki (same categories as used in the main code and CWM) and how many

The main focus is on (1) determining the number of people of the age group who are parents and (2) determining the proportion that has had some interaction (or placement) with OT.
The additional detail in these variables is mainly intended for verification purposes, and not drawing inferences about the children, and care should be exercised when trying to draw
precise comparisons (for example, 17 year olds have had longer to potentially interact iwth OT than 1 year olds, and ideally this should be controlled for in a deeper analysis).

Note that we use the cyf_clean datasets to determine information about the chilren. This is because not all children may be in the resident population (eg, have moved out of the country or died.)

***/

:setvar targetdb "IDI_Sandpit"
:setvar projectschema "[DL-MAA2016-23]"
:setvar idicleanversion "IDI_Clean_202406"
:setvar refdate "'2023-01-01'" 

DROP TABLE IF EXISTS #parent_child_link;

SELECT * 
INTO #parent_child_link
FROM
		(
		SELECT pop.snz_uid AS parent_id
				,det1.snz_uid AS child_id
		FROM $(targetdb).$(projectschema).icm_master_table pop
		INNER JOIN $(idicleanversion).data.personal_detail det1
		ON det1.snz_parent1_uid = pop.snz_uid
		WHERE Age_Group = '27-30'
		UNION ALL
		SELECT pop.snz_uid AS parent_id
				,det2.snz_uid AS child_id
		FROM $(targetdb).$(projectschema).icm_master_table pop
		INNER JOIN $(idicleanversion).data.personal_detail det2
		ON det2.snz_parent2_uid = pop.snz_uid
		WHERE Age_Group = '27-30'
		) k;

-- We DON'T go to the icm_master_table for this, because this is only people in the resident pop. 
-- If a child has gone overseas or died, we probably still want that info.
-- These are business rules from OT CWM for identifying/classifying interaction types

DROP TABLE IF EXISTS #parent_child_ot_events;
SELECT pop.parent_id
		,pop.child_id
		,COALESCE(yj_pla_life,cp_pla_life, hmc_pla_life,yj_sup_life,yj_fgc_life, cp_fgc_life,yj_fwa_life, cp_fwa_life
					--,cp_cfa_life,cp_roc_life -- these are a subset of notif
					,cp_notif_life) AS ot_interaction_flag
		,COALESCE(yj_sup_life,yj_fgc_life, cp_fgc_life,yj_fwa_life, cp_fwa_life) AS ot_FGC_FWA_life
		,COALESCE(yj_pla_life,cp_pla_life, hmc_pla_life) AS ot_placement_life
INTO #parent_child_ot_events
FROM #parent_child_link pop

LEFT JOIN (SELECT snz_uid
					,CASE WHEN COUNT(CASE WHEN cyf_pld_placement_type_code IN ('RESCJP','RESNON','RESYJ','RMNDHM') THEN 1 ELSE NULL END) >=1
								THEN 1
								ELSE NULL END AS yj_pla_life
					,CASE WHEN COUNT(CASE WHEN cyf_pld_placement_type_code IN ('CFSS', 'CYP', 'IWI', 'PSS', 'WHA', 'FAM','WCP', 'BRD', 'SGHP' -- foster care
								,'RESCP', 'RESIDCR', 'RESMHA'	-- respite care
								,'INDEP', 'YOOC', 'YSFHCD', 'YSFHSA', 'AKCOMMRESISVC', 'KAAHUIWHETUU' -- other care
								) THEN 1 ELSE NULL END) >=1
							THEN 1
							ELSE NULL END AS cp_pla_life
					,CASE WHEN COUNT(CASE WHEN cyf_pld_placement_type_code IN ('REMHM','RETHM') THEN 1 ELSE NULL END) >=1
							THEN 1
							ELSE NULL END AS hmc_pla_life
			FROM $(idicleanversion).cyf_clean.cyf_placements_event pla_ev
			LEFT JOIN $(idicleanversion).cyf_clean.cyf_placements_details pla_dt
			ON pla_dt.snz_composite_event_uid = pla_ev.snz_composite_event_uid
			WHERE $(refdate) > [cyf_ple_event_from_date_wid_date]
			GROUP BY snz_uid) dat1
	ON pop.child_id = dat1.snz_uid

LEFT JOIN (SELECT snz_uid
				,CASE WHEN COUNT(CASE WHEN cyf_fgd_business_area_type_code = 'CNP' THEN 1 ELSE NULL END) >= 1 THEN 1 ELSE NULL END AS cp_fgc_life
				,CASE WHEN COUNT(CASE WHEN cyf_fgd_business_area_type_code = 'YJU' THEN 1 ELSE NULL END) >= 1 THEN 1 ELSE NULL END AS yj_fgc_life
			FROM $(idicleanversion).cyf_clean.cyf_ev_cli_fgc_cys_f fgc_ev
			LEFT JOIN $(idicleanversion).cyf_clean.cyf_dt_cli_fgc_cys_d fgc_dt
			ON fgc_dt.snz_composite_event_uid = fgc_ev.snz_composite_event_uid
			WHERE $(refdate) > cyf_fge_event_from_datetime
			GROUP BY snz_uid) dat2
	ON pop.child_id = dat2.snz_uid

LEFT JOIN (SELECT snz_uid
				,CASE WHEN COUNT(CASE WHEN cyf_fwd_business_area_type_code = 'CNP' THEN 1 ELSE NULL END) >= 1 THEN 1 ELSE NULL END AS cp_fwa_life
				,CASE WHEN COUNT(CASE WHEN cyf_fwd_business_area_type_code = 'YJU' THEN 1 ELSE NULL END) >= 1 THEN 1 ELSE NULL END AS yj_fwa_life
			FROM $(idicleanversion).cyf_clean.cyf_ev_cli_fwas_cys_f fwa_ev
			LEFT JOIN $(idicleanversion).cyf_clean.cyf_dt_cli_fwas_cys_d fwa_dt
			ON fwa_dt.snz_composite_event_uid = fwa_ev.snz_composite_event_uid
			WHERE $(refdate) > [cyf_fwe_event_from_date_wid_date]
			GROUP BY snz_uid) dat3
	ON pop.child_id = dat3.snz_uid
LEFT JOIN (SELECT snz_uid
					,1 AS yj_sup_life
			FROM $(idicleanversion).cyf_clean.cyf_dt_cli_legal_status_cys_d d
			LEFT JOIN $(idicleanversion).cyf_clean.cyf_ev_cli_legal_status_cys_f f
			ON d.snz_composite_event_uid = f.snz_composite_event_uid
			WHERE cyf_lsd_legal_status_code in ('S283K','S307','S3074')
			AND $(refdate) > [cyf_lse_event_from_date_wid_date]
			GROUP BY snz_uid) dat4
	ON pop.child_id = dat4.snz_uid
LEFT JOIN (SELECT snz_uid
			,CASE WHEN COUNT(CASE WHEN cyf_ind_business_area_type_code = 'CNP' AND cyf_ind_final_outcome_type_code IN ('FAR','CFA','FARCFA','INV') THEN 1 ELSE NULL END) >= 1 THEN 1 ELSE NULL END AS cp_cfa_life
			,CASE WHEN COUNT(CASE WHEN cyf_ind_business_area_type_code = 'CNP' THEN 1 ELSE NULL END) >= 1 THEN 1 ELSE NULL END AS cp_notif_life
			,CASE WHEN COUNT(CASE WHEN cyf_ind_business_area_type_code = 'CNP' AND [cyf_ind_cnp_notification_ind] = 'Y' THEN 1 ELSE NULL END) >= 1 THEN 1 ELSE NULL END AS cp_roc_life
			from $(idicleanversion).cyf_clean.cyf_intakes_event int_ev
			left join $(idicleanversion).cyf_clean.cyf_intakes_details int_dt
			on int_ev.snz_composite_event_uid = int_dt.snz_composite_event_uid
			WHERE cyf_ine_event_from_datetime < $(refdate)
			GROUP BY snz_uid) dat5
	ON pop.child_id = dat5.snz_uid

DROP TABLE IF EXISTS #parent_child_ot_interaction;
SELECT parent_id AS snz_uid
		,COUNT(DISTINCT child_id) AS nbr_children
		-- For the following: COUNT(DISTINCT ...) does not count NULLs - so this picks up only the distinct child IDs (if any)
		,COUNT(DISTINCT IIF(ot_placement_life = 1, child_id, NULL)) AS nbr_children_placement -- use to sum, or count
		,COUNT(DISTINCT IIF(ot_FGC_FWA_life = 1, child_id, NULL))  AS nbr_children_FGC_FWA
		,COUNT(DISTINCT IIF(ot_interaction_flag =1, child_id, NULL)) AS nbr_children_interaction -- use to sum or count
INTO #parent_child_ot_interaction
FROM #parent_child_ot_events
GROUP BY parent_id

-- 
ALTER TABLE $(targetdb).$(projectschema).icm_master_table DROP COLUMN IF EXISTS nbr_children
																		,COLUMN IF EXISTS nbr_children_placement
																		,COLUMN IF EXISTS nbr_children_FGC_FWA
																		,COLUMN IF EXISTS nbr_children_interaction;
ALTER TABLE $(targetdb).$(projectschema).icm_master_table ADD nbr_children TINYINT
																,nbr_children_placement TINYINT
																,nbr_children_FGC_FWA TINYINT
																,nbr_children_interaction TINYINT;
GO

UPDATE
	$(targetdb).$(projectschema).icm_master_table
SET
	nbr_children = CASE WHEN ot.nbr_children > 0 THEN ot.nbr_children
						ELSE NULL END
	
	,nbr_children_placement = CASE WHEN ot.nbr_children_placement > 0 THEN ot.nbr_children_placement
						ELSE NULL END

	,nbr_children_FGC_FWA = CASE WHEN ot.nbr_children_FGC_FWA > 0 THEN ot.nbr_children_FGC_FWA
						ELSE NULL END

	,nbr_children_interaction =  CASE WHEN ot.nbr_children_interaction > 0 THEN ot.nbr_children_interaction
						ELSE NULL END

FROM 
	#parent_child_ot_interaction ot
WHERE $(targetdb).$(projectschema).icm_master_table.snz_uid = ot.snz_uid;
