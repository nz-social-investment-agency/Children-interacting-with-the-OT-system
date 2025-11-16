/***  Add population groupings to master table

This scrip takes the master table including OT interaction indicators and classifies people based on interactions during the past year
or their liftime.
This has been separated out in order to simplify potential changes to classification or groupings.

Essentially, this replicates part of the CWM categorisation, excluding the receipt of Unsupported Child payments. For tamariki and rangitahi,
we also currently do not include the lifetime interactions.


 Coding
Numeric coding for involvement groups
0 'No contact'
1 'Non-Care and Custody contact'
2 'Care and custody'


Numeric coding for the detailed involvement groups (used to manage sandpit footprint) ('detailed2' combines the 6th group into the 5th group)
1 'Concerns raised'
2 'Receiving intervention'
3 'Youth Justice Intervention'
4 'Care and Protection Custody'
5 'Youth Justice custody'
6 'Youth Justice and Care and Protection custody'


Numeric coding for TSS
0 - No OT contact
1 - Not TSS, did not experience a placement, experienced other OT interaction
2 - Not TSS, experienced a placement
3 - TSS eligible


***/


:setvar targetdb "IDI_Sandpit"
:setvar projectschema "DL-MAA2024-48"
:setvar targettable "ICM_Master_Table_202406"

------------------------------------------------- Remove existing column (if any) from Master Table

ALTER TABLE [$(targetdb)].[$(projectschema)].[$(targettable)] DROP COLUMN IF EXISTS OT_involvement_detailed_life
								,COLUMN IF EXISTS OT_involvement_life
								,COLUMN IF EXISTS any_OT_life
								,COLUMN IF EXISTS OT_involvement_detailed_current
								,COLUMN IF EXISTS OT_involvement_current
								,COLUMN IF EXISTS any_OT_current
								,COLUMN IF EXISTS intermediate_outcomes_pop
								,COLUMN IF EXISTS life_outcomes_pop
								,COLUMN IF EXISTS OT_involvement_detailed2_current
								,COLUMN IF EXISTS OT_involvement_detailed2_life
								,COLUMN IF EXISTS TSS_status
								,COLUMN IF EXISTS age_00_17_pop
								,COLUMN IF EXISTS age_18_25_pop
								,COLUMN IF EXISTS age_27_30_pop;
ALTER TABLE [$(targetdb)].[$(projectschema)].[$(targettable)] ADD OT_involvement_detailed_life tinyint
								,OT_involvement_life tinyint
								,any_OT_life bit
								,OT_involvement_detailed_current tinyint
								,OT_involvement_current tinyint
								,any_OT_current bit
								,intermediate_outcomes_pop bit
								,life_outcomes_pop bit
								,OT_involvement_detailed2_current tinyint
								,OT_involvement_detailed2_life tinyint
								,TSS_status tinyint
								,age_00_17_pop bit
								,age_18_25_pop bit
								,age_27_30_pop bit
								GO

------------------------------------------------- Add and update columns into Master Table


UPDATE
	[$(targetdb)].[$(projectschema)].[$(targettable)]
SET OT_involvement_detailed_life = CASE 
				WHEN yj_pla_life =1 AND (cp_pla_life =1 OR hmc_pla_life =1) THEN 6
				WHEN yj_pla_life =1 THEN 5
				WHEN cp_pla_life =1 OR hmc_pla_life =1 THEN 4
				WHEN yj_fgc_eq_life =1 THEN 3
				WHEN cp_fgc_eq_life =1 OR cp_cfa_life =1 THEN 2 
				WHEN cp_notif_life =1 THEN 1
				ELSE 0 END
	,OT_involvement_life = CASE 
				WHEN yj_pla_life =1 OR cp_pla_life =1 OR hmc_pla_life =1 THEN 2
				WHEN yj_fgc_eq_life =1 OR cp_fgc_eq_life =1 OR cp_cfa_life =1 OR cp_notif_life =1 THEN 1
				ELSE 0 END
	,any_OT_life = CASE  
						WHEN yj_pla_life =1 
								OR cp_pla_life =1 
								OR hmc_pla_life =1
								OR yj_fgc_eq_life =1 
								OR cp_fgc_eq_life =1 
								OR cp_cfa_life =1 
								OR cp_notif_life =1  THEN 1
						ELSE 0 END

	,OT_involvement_detailed_current = CASE 
				WHEN yj_pla_1Y =1 AND (cp_pla_1Y =1 OR hmc_pla_1Y =1) THEN 6
				WHEN yj_pla_1Y =1 THEN 5
				WHEN cp_pla_1Y =1 OR hmc_pla_1Y =1 THEN 4
				WHEN yj_fgc_eq_1Y =1 THEN 3
				WHEN cp_fgc_eq_1Y =1 OR cp_cfa_1Y =1 THEN 2
				WHEN cp_notif_1Y =1 THEN 1
				ELSE 0 END 
	,OT_involvement_current = CASE 
				WHEN yj_pla_1Y =1 OR cp_pla_1Y =1 OR hmc_pla_1Y =1 THEN 2
				WHEN yj_fgc_eq_1Y =1 OR cp_fgc_eq_1Y =1 OR cp_cfa_1Y =1 OR cp_notif_1Y =1 THEN 1
				ELSE 0 END 
	,any_OT_current = CASE 
						WHEN yj_pla_1Y =1 
								OR cp_pla_1Y =1 
								OR hmc_pla_1Y =1 
								OR yj_fgc_eq_1Y =1  
								OR cp_fgc_eq_1Y =1 
								OR cp_cfa_1Y =1  
								OR cp_notif_1Y =1 THEN 1 
					ELSE 0 END
	,intermediate_outcomes_pop = CASE WHEN AGE<=25 THEN 1 ELSE NULL END
	,life_outcomes_pop = CASE WHEN AGE BETWEEN 27 AND 30 THEN 1 ELSE NULL END
	,OT_involvement_detailed2_current = CASE 
				WHEN yj_pla_1Y =1 THEN 5
				WHEN cp_pla_1Y =1 OR hmc_pla_1Y =1 THEN 4
				WHEN yj_fgc_eq_1Y =1 THEN 3
				WHEN cp_fgc_eq_1Y =1 OR cp_cfa_1Y =1 THEN 2
				WHEN cp_notif_1Y =1 THEN 1
				ELSE 0 END 
	,OT_involvement_detailed2_life = CASE 
				WHEN yj_pla_life =1 THEN 5
				WHEN cp_pla_life =1 OR hmc_pla_life =1 THEN 4
				WHEN yj_fgc_eq_life =1 THEN 3
				WHEN cp_fgc_eq_life =1 OR cp_cfa_life =1 THEN 2 
				WHEN cp_notif_life =1 THEN 1
				ELSE 0 END
	,TSS_status = CASE WHEN TSS = 'TSS' THEN 3
				WHEN yj_pla_life =1 
								OR cp_pla_life =1 
								OR hmc_pla_life =1 THEN 2
				WHEN			yj_fgc_eq_life =1 
								OR cp_fgc_eq_life =1 
								OR cp_cfa_life =1 
								OR cp_notif_life =1  THEN 1
				ELSE 0 END
	,age_00_17_pop = IIF(Age_Group = '0-17',1,NULL)
	,age_18_25_pop = IIF(Age_Group = '18-25',1,NULL)
	,age_27_30_pop = IIF(Age_Group = '27-30',1,NULL)