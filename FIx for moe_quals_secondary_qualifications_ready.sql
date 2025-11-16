/***************************************************************************************************************************

This code is a fix for the secondary qualifications table from the code module. 
The initial code module missed recent NCEA qualifications due to using an old concordance
that did not include entries for newer NCEA quals
This implements the fix.

***************************************************************************************************************************/


-- SQLCMD mode

:setvar targetdb "IDI_UserCode"
:setvar targetschema "DL-MAA..."
:setvar projprefix "tmp"
:setvar idicleanversion "IDI_Clean_202406"
:setvar metadatalookup "[IDI_Metadata_202406].[moe_school].[qualification23_concord]"
GO


/* Assign the target database to which all the components need to be created in. */
USE $(targetdb)
GO

/* Delete the database object if it already exists */
IF OBJECT_ID('[$(targetschema)].[$(projprefix)_moe_secondary_quals]','V') IS NOT NULL
DROP VIEW [$(targetschema)].[$(projprefix)_moe_secondary_quals];
GO

/* Create the database object */
CREATE VIEW [$(targetschema)].[$(projprefix)_moe_secondary_quals] AS

/* <! */

	select 
		a.snz_uid
		,cast('SCH_QUAL' as varchar(50)) as data_source
		,a.moe_sql_qual_code as qualification_id
		,b.QualificationCode as qualification_code
		,b.QualificationName as qualification_name
		,a.moe_sql_exam_result_code as endorsement_code
		,a.moe_sql_award_provider_code as awarding_school
		,a.moe_sql_electivt_strand_nbr as elective_strand
		,a.moe_sql_optional_strand_nbr as optional_strand
		,datefromparts(a.moe_sql_attained_year_nbr, 12, 31) as qual_attained_date
		,datefromparts(9999, 12, 31) as qual_expiry_date
		/* MoE advises that the quality of "NZQFlevel" variable is not great for early years */
		,b.nqflevel as nzqflevel
		/* These case statements assume that if a student got  NCEA Level 3, and there is no record for Level 2 or Level 1 then
				we count them having Level 2 and Level 1 as well, this logic is valid from 2014 only.*/
		,case	when (b.QualificationCode in ('0928','928','0973','973','1039')) and a.moe_sql_attained_year_nbr >=2014 and a.moe_sql_exam_result_code in ('E','M' ,'ZZ') then 1
				when (b.QualificationCode in ('0928','928')) and a.moe_sql_attained_year_nbr <2014 and a.moe_sql_exam_result_code in ('E','M' ,'ZZ') then 1
				else 0 end as ncea_l1 
		,case	when (b.QualificationCode in('0973','973','1039')) and a.moe_sql_attained_year_nbr >=2014 and a.moe_sql_exam_result_code in ('E','M' ,'ZZ') then 1
				when (b.QualificationCode in('0973','973')) and a.moe_sql_attained_year_nbr <2014 and a.moe_sql_exam_result_code in ('E','M' ,'ZZ') then 1
				else 0 end as ncea_l2  
		,case	when (b.QualificationCode='1039' ) and a.moe_sql_exam_result_code in ('E','M' ,'ZZ') then 1 else 0 end as ncea_l3 
	from [$(idicleanversion)].[moe_clean].student_qualification a
	left join $(metadatalookup) b 
		on (a.moe_sql_qual_code=b.qualificationTableId)
	where 
		b.NQFlevel is not null 
		and b.NQFlevel > 0
		and a.moe_sql_attained_year_nbr >= 2003
		and b.NQFlevel <= 11;
GO

/* !> */





