CREATE PROCEDURE [ShipMgmt_Crewing].[CrewComplianceInsert]
(
@DateFromPipeline DATETIME
)

AS 

BEGIN

DECLARE @Date DATETIME = @DateFromPipeline;

BEGIN TRAN
DELETE FROM [dbo].[SF_STAGE_CrewCompliance]
WHERE CAST([Run Day] AS DATE) = CAST(@Date AS DATE)
COMMIT

SELECT * INTO #tmpVes FROM(
		select v.ves_id
		,v.VES_Name
		,cpc.CMP_Name as CrewOffice
		,vd.VMD_ID
		,DENSE_RANK() OVER (PARTITION BY V.VES_ID ORDER BY  vd.vmd_managestart desc, vmd_UpdatedOn ) LV
		from shipsure..vessel v
		inner join shipsure..VESMANAGEMENTDETAILS vd (NOLOCK) on vd.VES_ID=v.VES_ID  
		LEFT JOIN shipsure..VESOFFICESERVICE ot (NOLOCK) ON ot.VMD_ID = VD.VMD_ID AND ot.VOS_Deleted = 0 AND ot.VOT_ID IN ('GLAS00000005') -- technical office
		LEFT JOIN shipsure..VESOFFICESERVICE ro (NOLOCK) ON ro.VMD_ID = VD.VMD_ID AND ro.VOS_Deleted = 0 AND ro.VOT_ID IN ('GLAS00000003') -- responsible office*/
		LEFT JOIN shipsure..VESOFFICESERVICE co (NOLOCK) ON co.VMD_ID = VD.VMD_ID AND co.VOS_Deleted = 0 AND co.VOT_ID IN ('GLAS00000006') -- crew office
		left join shipsure..COMPANY cpt (NOLOCK) on cpt.CMP_ID=ot.CMP_ID
		left join shipsure..COMPANY cpr (NOLOCK) on cpr.CMP_ID=ro.CMP_ID
		left join shipsure..COMPANY cpc (NOLOCK) on cpc.CMP_ID=co.CMP_ID
		left join shipsure..company cmp (NOLOCK) on cmp.cmp_id = VD.VMD_Owner	

		WHERE
		(VMD_ManageEnd IS NULL or cast(VMD_ManageEnd as date)>=cast(GETDATE() as date))
		and (VMD_Deleted is null or VMD_Deleted=0) 
		AND  ( ((cast(VMD_ManageStart as date)<=cast(GETDATE() as date) or (VMD_ManageStart is null 
		AND(cast(VMD_ManESTDateStart as date) is null or cast(VMD_ManESTDateStart as date)<=cast(GETDATE() as date)))) and VSS_ID in ('01','06')) OR ( VSS_ID='06' AND VMD_ManESTDateStart is not null))
		and v.VES_Onboard2>0
		and v.VSS_ID in ('01','06')

		) LH WHERE LV=1

SELECT
R.CRW_PID as [PCN],
R.crw_id as [Crew ID],
R.ves_id as [Vessel ID],
V.VMD_ID as [Vessel Mgmt ID],
nat.NAT_Description as [Crew Nationality],
R.rnk_id as [Rank ID],
[Rank Sequence] = case  
				 when CCA_IsOfficer = 1 then '0' + cast(rnk.RNK_SequenceNumber as varchar(20))
				 when CCA_IsOfficer = 0 then '1' + cast(rnk.RNK_SequenceNumber as varchar(20))  END,
[Crew Status] = CASE WHEN R.crew_status = 'O' THEN 'ONBOARD' ELSE 'RELIEVER' END,
R.SET_StartDate as [Start Date],
R.SET_EndDate as [End Date],
R.CRD_Number [Document Number],
R.DOC_ID [Document ID],
R.CRD_Country [Document Country ID],
R.CRD_ISSUED [Document Issued Date],
R.CRD_Expiry [Document Expiry Date],
R.Doc_desc [Document Description],
M.DOC_Desc [Document General Name],
[Sign On Status] = CASE WHEN R.TMC_ShortCode = 'REC' THEN 'Warning'
						WHEN R.SignOn_Status = 'N' THEN 'Non-Compliant'
						WHEN SignOn_Status='W' THEN 'Warning'		
						ELSE 'Compliant' END,
[Sign Off Status] = CASE WHEN R.TMC_ShortCode='REC' THEN 'Warning'
						 WHEN (R.SignOn_Status!='N' AND (R.SignOff_Note LIKE '%Document%expires%before Sign Off%' OR 
							   R.SignOff_Note LIKE 'Validity Period%expires before Sign Off%' OR  
							   R.SignOff_Note LIKE 'Grace period of%will expire before Sign Off%' OR 
							   R.SignOn_Note LIKE '%Grace period of%from Sign On allowed%')) OR 
							   R.SignOff_Status='W' THEN 'Warning' 
						 WHEN R.SignOff_Status='N' THEN 'Non-Compliant'
                         ELSE 'Compliant' END,
[Note] = CASE WHEN R.signon_note LIKE'%waiver%' AND R.signoff_note!='' THEN  R.signoff_note+ '. By Waiver'
			  WHEN (R.signon_note='' or R.signon_note is null or R.signon_note like'%waiver%' or R.signon_note like '%covered%' or R.SignOn_Note like '%Equivalent%' or R.signon_note like 'Grace period of%from Sign On allowed') and R.signoff_note!='' then R.signoff_note
			  WHEN tmc.TMC_Description like '%Within%' and (R.signon_note like '%Validity Period of%expires before Sign On%' or R.SignOn_Note like '%Document expired%before Sign On%' )and r.TMC_ShortCode like '%12M%' and  (cast(dateadd(MONTH,12,r.SET_StartDate) as date)>cast(getdate() as date) or R.Crew_Status!='O')then 'Grace period of 12 Months from Sign On allowed'
			  WHEN tmc.TMC_Description like '%Within%' and (R.signon_note like '%Validity Period of%expires before Sign On%' or R.SignOn_Note like '%Document expired%before Sign On%' )and r.TMC_ShortCode like '%6M%' and  (cast(dateadd(MONTH,6,r.SET_StartDate) as date)>cast(getdate() as date) or R.Crew_Status!='O')then 'Grace period of 6 Months from Sign On allowed'
			  WHEN tmc.TMC_Description like '%Within%' and (R.signon_note like '%Validity Period of%expires before Sign On%' or R.SignOn_Note like '%Document expired%before Sign On%' )and r.TMC_ShortCode like '%12W%' and  (cast(dateadd(WEEK,12,r.SET_StartDate) as date)>cast(getdate() as date) or R.Crew_Status!='O')then 'Grace period of 12 weeks from Sign On allowed'
			  WHEN tmc.tMC_Description like '%Within%' and (R.signon_note like '%Validity Period of%expires before Sign On%' or R.SignOn_Note like '%Document expired%before Sign On%' ) and  r.TMC_ShortCode like '%8W%' and  (cast(dateadd(WEEK,8,r.SET_StartDate) as date)>cast(getdate() as date) or R.Crew_Status!='O') then 'Grace period of 8 weeks from Sign On allowed'
			  WHEN tmc.TMC_Description like '%Within%' and (R.signon_note like '%Validity Period of%expires before Sign On%' or R.SignOn_Note like '%Document expired%before Sign On%' ) and  r.TMC_ShortCode like 'M%' and  (cast(dateadd(WEEK,4,r.SET_StartDate) as date)>cast(getdate() as date) or R.Crew_Status!='O') then 'Grace period of 4 weeks from Sign On allowed'
			  WHEN tmc.TMC_Description like '%Within%' and (R.signon_note like '%Validity Period of%expires before Sign On%' or R.SignOn_Note like '%Document expired%before Sign On%' )and r.TMC_ShortCode like 'W%' and  (cast(dateadd(WEEK,1,r.SET_StartDate) as date)>cast(getdate() as date) or R.Crew_Status!='O')then 'Grace period of 1 week from Sign On allowed'
			  WHEN tmc.TMC_Description like '%Within%' and (R.signon_note like '%Validity Period of%expires before Sign On%' or R.SignOn_Note like '%Document expired%before Sign On%' )and r.TMC_ShortCode like '%12M%' and  (cast(dateadd(MONTH,12,r.SET_StartDate) as date)<=cast(getdate() as date) )then 'Grace period of 12 Months from Sign On has passed'
			  WHEN tmc.tMC_Description like '%Within%' and (R.signon_note like '%Validity Period of%expires before Sign On%' or R.SignOn_Note like '%Document expired%before Sign On%' )and r.TMC_ShortCode like '%6M%' and  (cast(dateadd(MONTH,6,r.SET_StartDate) as date)<=cast(getdate() as date) )then 'Grace period of 6 Months from Sign On has passed'
			  WHEN tmc.TMC_Description like '%Within%' and (R.signon_note like '%Validity Period of%expires before Sign On%' or R.SignOn_Note like '%Document expired%before Sign On%' ) and r.TMC_ShortCode like '%12W%' and  cast(dateadd(WEEK,12,r.SET_StartDate) as date)<=cast(getdate() as date) then 'Grace period of 12 weeks from Sign On has passed'
			  WHEN tmc.TMC_Description like '%Within%' and (R.signon_note like '%Validity Period of%expires before Sign On%' or R.SignOn_Note like '%Document expired%before Sign On%' ) and  r.TMC_ShortCode like '%8W%' and  cast(dateadd(WEEK,8,r.SET_StartDate) as date)<=cast(getdate() as date) then 'Grace period of 8 weeks from Sign On has passed'
			  WHEN tmc.tMC_Description like '%Within%' and (R.signon_note like '%Validity Period of%expires before Sign On%' or R.SignOn_Note like '%Document expired%before Sign On%' ) and  r.TMC_ShortCode like 'M%' and  cast(dateadd(WEEK,4,r.SET_StartDate) as date)<=cast(getdate() as date) then 'Grace period of 4 weeks from Sign has passed'
			  WHEN tmc.TMC_Description like '%Within%' and (R.signon_note like '%Validity Period of%expires before Sign On%' or R.SignOn_Note like '%Document expired%before Sign On%' ) and  r.TMC_ShortCode like 'W%' and  cast(dateadd(WEEK,1,r.SET_StartDate) as date)<=cast(getdate() as date) then 'Grace period of 1 week from Sign has passed'
			  WHEN r.signon_note=''and R.SignOff_Note='' then 'Compliant' 
			  ELSE r.signon_note END,
[Grace Period] = CASE WHEN tmc.TMC_ShortCode like '%12M%'then '12 Months'
						       WHEN tmc.TMC_ShortCode like '%6M%'then '6 Months'
						       WHEN tmc.TMC_ShortCode like '%12W%' then '12 weeks'
						       WHEN tmc.TMC_ShortCode like '%8W%'  then '8 weeks'
						       WHEN tmc.TMC_ShortCode like 'M%' then '4 weeks'
						       WHEN tmc.TMC_ShortCode like 'W%' then '1 week' END,
R.signon_note [Sign On Note],
signoff_note [Sign Off Note],
tmt.TMT_Name [Template Name],
tmt.TMT_Core [Template is Core],
r.TMC_ShortCode [Document Requirement Short Code],
tmc.TMC_Description [Document Requirement],
tmc.TMC_Description as [Document Requirement 1],
r.TMC_ShortCode as [Document Requirement Short Code 1],
[Last Date of Grace Period] = CASE WHEN tmc.TMC_Description like '%Within%'and  r.TMC_ShortCode like '%M%' then cast(dateadd(WEEK,4,r.SET_StartDate) as date)
								   WHEN tmc.TMC_Description like '%Within%'and  r.TMC_ShortCode like '%12W%' then cast(dateadd(WEEK,12,r.SET_StartDate) as date)
								   WHEN tmc.TMC_Description like '%Within%'and  r.TMC_ShortCode like '%8W%' then cast(dateadd(WEEK,8,r.SET_StartDate) as date) END,
[Document Non Compliant] = CASE WHEN r.TMC_ShortCode='REC' THEN 0
								WHEN ( r.SignOn_Status='C' and  r.Signoff_Status='N' and ( r.SignOff_Note like '%Document%expires%before Sign Off%' or r.SignOff_Note like 'Validity Period%expires before Sign Off%' or r.SignOff_Note like 'Grace period of%will expire before Sign Off%') ) then 0							  
								WHEN tmc.tMC_Description like '%Within%' and (r.signon_note like '%Validity Period of%expires before Sign On%' or r.SignOn_Note like '%Document expired%before Sign On%' )and r.TMC_ShortCode like '%12M%' and  (cast(dateadd(MONTH,12,r.SET_StartDate) as date)>cast(getdate() as date) or r.Crew_Status!='O')then 0
								WHEN tmc.tMC_Description like '%Within%' and (r.signon_note like '%Validity Period of%expires before Sign On%' or r.SignOn_Note like '%Document expired%before Sign On%' )and r.TMC_ShortCode like '%6M%' and  (cast(dateadd(MONTH,6,r.SET_StartDate) as date)>cast(getdate() as date) or r.Crew_Status!='O')then 0
								WHEN tmc.tMC_Description like '%Within%' and (r.signon_note like '%Validity Period of%expires before Sign On%' or r.SignOn_Note like '%Document expired%before Sign On%' )and r.TMC_ShortCode like '%12W%' and  (cast(dateadd(WEEK,12,r.SET_StartDate) as date)>cast(getdate() as date) or r.Crew_Status!='O')then 0
								WHEN tmc.tMC_Description like '%Within%' and (r.signon_note like '%Validity Period of%expires before Sign On%' or r.SignOn_Note like '%Document expired%before Sign On%' ) and  r.TMC_ShortCode like '%8W%' and  (cast(dateadd(WEEK,8,r.SET_StartDate) as date)>cast(getdate() as date) or r.Crew_Status!='O') then 0
								WHEN tmc.tMC_Description like '%Within%' and (r.signon_note like '%Validity Period of%expires before Sign On%' or r.SignOn_Note like '%Document expired%before Sign On%' ) and  r.TMC_ShortCode like 'M%' and  (cast(dateadd(WEEK,4,r.SET_StartDate) as date)>cast(getdate() as date) or r.Crew_Status!='O') then 0
								WHEN tmc.tMC_Description like '%Within%' and (r.signon_note like '%Validity Period of%expires before Sign On%' or r.SignOn_Note like '%Document expired%before Sign On%' )and r.TMC_ShortCode like 'W%' and  (cast(dateadd(WEEK,1,r.SET_StartDate) as date)>cast(getdate() as date) or r.Crew_Status!='O')then 0
								WHEN ((SignOff_Status='N' and SignOn_Status!='W') or SignOn_Status='N') THEN 1
								ELSE 0  END,
[Document Compliance] = CASE WHEN r.TMC_ShortCode='REC' THEN 'Compliant'
							 WHEN ( r.SignOn_Status='C' and  r.Signoff_Status='N' and ( r.SignOff_Note like '%Document%expires%before Sign Off%' or r.SignOff_Note like 'Validity Period%expires before Sign Off%' or r.SignOff_Note like 'Grace period of%will expire before Sign Off%') ) then 'Compliant'
							 WHEN tmc.tMC_Description like '%Within%' and (r.signon_note like '%Validity Period of%expires before Sign On%' or r.SignOn_Note like '%Document expired%before Sign On%' )and r.TMC_ShortCode like '%12M%' and  (cast(dateadd(MONTH,12,r.SET_StartDate) as date)>cast(getdate() as date) or r.Crew_Status!='O')then 'Compliant'
							 WHEN tmc.tMC_Description like '%Within%' and (r.signon_note like '%Validity Period of%expires before Sign On%' or r.SignOn_Note like '%Document expired%before Sign On%' )and r.TMC_ShortCode like '%6M%' and  (cast(dateadd(MONTH,6,r.SET_StartDate) as date)>cast(getdate() as date) or r.Crew_Status!='O')then 'Compliant'
							 WHEN tmc.tMC_Description like '%Within%' and (r.signon_note like '%Validity Period of%expires before Sign On%' or r.SignOn_Note like '%Document expired%before Sign On%' )and r.TMC_ShortCode like '%12W%' and  (cast(dateadd(WEEK,12,r.SET_StartDate) as date)>cast(getdate() as date) or r.Crew_Status!='O')then 'Compliant'
							 WHEN tmc.tMC_Description like '%Within%' and (r.signon_note like '%Validity Period of%expires before Sign On%' or r.SignOn_Note like '%Document expired%before Sign On%' ) and  r.TMC_ShortCode like '%8W%' and  (cast(dateadd(WEEK,8,r.SET_StartDate) as date)>cast(getdate() as date) or r.Crew_Status!='O') then 'Compliant'
							 WHEN tmc.tMC_Description like '%Within%' and (r.signon_note like '%Validity Period of%expires before Sign On%' or r.SignOn_Note like '%Document expired%before Sign On%' ) and  r.TMC_ShortCode like 'M%' and  (cast(dateadd(WEEK,4,r.SET_StartDate) as date)>cast(getdate() as date) or r.Crew_Status!='O') then 'Compliant'
							 WHEN tmc.tMC_Description like '%Within%' and (r.signon_note like '%Validity Period of%expires before Sign On%' or r.SignOn_Note like '%Document expired%before Sign On%' )and r.TMC_ShortCode like 'W%' and  (cast(dateadd(WEEK,1,r.SET_StartDate) as date)>cast(getdate() as date) or r.Crew_Status!='O')then 'Compliant'
							 WHEN ((r.SignOff_Status='N' and r.SignOn_Status!='W') or SignOn_Status='N') then 'Non-Compliant'
							 ELSE 'Compliant'  END,
tmt.TMT_ID [Template ID],
[Company To Exclude] = CASE WHEN CMP12.CMP_ID='VGRP00071032' then 'Uniteam-Exclude' else 'Others' END,
[Template Requirement] = CASE WHEN r.TMC_ShortCode='REC' then 'Recommended' else 'Mandatory' END,
dat.tdi_effectivestartdate [Effective Start Date],
dat.tdi_reportingstartdate [Reporting Start Date],
[Training Type] = CASE WHEN dat.doc_id is not null and (cast(dat.TDI_ReportingStartDate as date)>cast(GETDATE() as date) or dat.tdi_reportingStartDate is null) then 'New Training' 
					   ELSE 'Old Training' END,
[CPI Report] = case WHEN (typ.DocumentRequirement='Statutory' or r.DOC_ID  in ('VSHP00000042','GLAS00000432','VSHP00000125') )and VESEX.ExclusionCategory='Statutory' then 'Excluded'
					WHEN typ.DocumentRequirement='VMS'  and VESEX.ExclusionCategory='VMS' and r.DOC_ID  in ('VSHP00000042','GLAS00000432','VSHP00000125') then 'Excluded'
					WHEN VESEXall.ExclusionCategory='ALL'then 'Excluded' 
					WHEN vesextpi.ExclusionCategory='TPA_TMPI' and  pd.cpl_id='VGR500000053' and DocumentRequirement='VMS'then 'Excluded'
					ELSE 'Included' END,
COALESCE (VESEX.ExclusionStartDate,VESEXall.ExclusionStartDate,vesextpi.ExclusionStartDate) as [Exclusion Start Date],
COALESCE (VESEX.ExclusionEndDate,VESEXall.ExclusionEndDate,vesextpi.ExclusionEndDate) as [Exclusion End Date],
COALESCE (VESEX.ExclusionCategory,VESEXall.ExclusionCategory,vesextpi.ExclusionCategory) as [Exclusion Category],
COALESCE (VESEX.REMARK,VESEXall.REMARK,vesextpi.REMARK) [Remarks],
[Is Flag State]= case when r.DOC_Desc like '%flag%' then 'YES' else 'No' END,
[Requirement Type] = case when r.DOC_ID in ('VSHP00000084','VSHP00000016','VSHP00000083') then 'Statutory' else typ.DocumentRequirement END,
[Is Default Template] = case when DT.TMT_ID IS NOT NULL THEN 'YES' ELSE 'NO' END,
case when typ.CDT_ID in ('VSHP00000002','GLAS00000029','GLAS00000032','') or typ.DOC_CertifOfCompetency=1 then 'COC' 
when typ.CDT_ID in ('VSHP00000007','GLAS00000035') or typ.DocumentRequirement='Statutory'  then 'STCW'
when typ.CDT_ID in ('VSHP00000001') then '05 Personal/ Travel' else 'Other' end as [Document Group Type]

INTO #Part
FROM CrewCompliance..ComplianceRunOutcome (NOLOCK) R
INNER JOIN shipsure.dbo.CRWDocMaster M (NOLOCK) ON M.doc_id=R.doc_id
INNER JOIN Shipsure..CRWTrainingMatrixTemplate tmt (NOLOCK) on R.TMT_ID=tmt.TMT_ID
INNER JOIN Shipsure.dbo.CRWTrainingMatrixCompliance tmc on tmc.TMC_ID=r.TMC_ID
LEFT JOIN shipsure.dbo.CRWTrainingMatrixTemplateDate dat (NOLOCK) on  dat.DOC_ID = r.DOC_ID and dat.tmt_id = tmt.TMT_ID and dat.TDI_Active=1
LEFT JOIN shipsure..CRWRANKS rnk on rnk.rnk_id=r.RNK_ID
LEFT JOIN SHIPSURE..CRWRankCategory CCA on CCA.CCA_ID=rnk.CCA_ID
INNER JOIN #tmpVes v on v.VES_ID=r.VES_ID
INNER JOIN Shipsure..CRWPersonalDetails pd (NOLOCK) on r.crw_id=pd.crw_id
LEFT JOIN Shipsure..NATIONALITY nat (NOLOCK) on nat.NAT_ID=pd.NAT_ID
LEFT JOIN  shipsure..COMPANY CMP12 (NOLOCK) ON CMP12.CMP_ID =  coalesce(pd.CRW_3rdPartyAgent, CRW_employmentEntity)
Left join Aggregates.dbo.vDocumentsType typ on typ.doc_id=r.DOC_ID
LEFT JOIN Aggregates..CRWTrainingComplianceDefaultTemplate DT on DT.TMT_ID=r.TMT_ID and DT.TMT_DEFAULT_ACTIVE=1
LEFT JOIN Aggregates..CRWTrainingComplianceVesselExclusion vesex on VESEX.VES_ID=r.VES_ID  AND (VESEX.ExclusionEndDate>=getdate() or VESEX.ExclusionEndDate is null) and (VESEX.ExclusionCategory=DocumentRequirement or VESEX.ExclusionCategory is null) and VESEX.Exclusion_Active=1
LEFT JOIN Aggregates..CRWTrainingComplianceVesselExclusion vesexall on vesexall.VES_ID=r.VES_ID  AND (vesexall.ExclusionEndDate>=getdate() or vesexall.ExclusionEndDate is null) and (vesexall.ExclusionCategory='ALL') and vesexall.Exclusion_Active=1
LEFT JOIN Aggregates..CRWTrainingComplianceVesselExclusion vesextpi on vesextpi.VES_ID=r.VES_ID  AND (vesextpi.ExclusionEndDate>=getdate() or vesextpi.ExclusionEndDate is null) and (vesextpi.ExclusionCategory='TPA_TMPI') and vesextpi.Exclusion_Active=1
WHERE (dat.TDI_EffectiveStartDate is null or cast(TDI_EffectiveStartDate as date)<=cast(GETDATE() as date))
and RNK.dep_id not in ('SUPERN','SPM_OB')
order by R.crw_id

-----------------------COURSES AFTER 1st JUL----------------------

	UPDATE #Part
	 SET [Sign On Status] = case when [Sign On Status] = 'Non-Compliant' then 'Warning' else [Sign On Status] END,
		 [Sign On Note] = case when [Sign On Status] = 'Non-Compliant' then 'Eff. 01/07/2021 - auto update' else [Sign On Note] end,
		 [Sign Off Status] = case when [Sign Off Status] = 'Non-Compliant' then 'Warning' else [Sign Off Status] end,
		 [Sign Off Note] = case when [Sign Off Status] = 'Non-Compliant' then 'Eff. 01/07/2021 - auto update' else [Sign Off Note] end,
		 [Note] = case when [Note] like '%Waiver%' then  [Note] + '. Eff. 01/07/2021' else '. Eff. 01/07/2021 - auto update' end,
		 [Document Non Compliant] = 0,
		 [Document Compliance] = 'Compliant'
	 WHERE [Template ID] in ('VGRP00000073','GLAS00000124')
	   and (([Document ID] in ( 'VSHP00000119','GLAS00000523'))
		or ([Document ID] IN ('GLAS00000477') and ([Sign Off Note] not like 'Missing%' or [Sign On Note] not like 'Missing')
				and Note not like 'Missing%' ))
	   and ([Sign On Status] = 'Non-Compliant' or [Sign Off Status] ='Non-Compliant' or note like '%Waiver%')
	   and [Start Date] <'2021-07-01'
	   
		--CLEAR OUT PRE (SO) for VMS_OTG TEmplate
		--Risk Management--
	
	UPDATE #Part
   SET [Sign On Status] = case when note like '%waiver%' then [Sign On Status] else 'Warning' end,
       [Sign On Note] = case when note like '%waiver%' then 'By Waiver. (Grace Period allowed)' else 'Grace period of 12 weeks from Sign On allowed - auto update' end,
       [Sign Off Status] = case when note like '%waiver%' then [Sign Off Status] else 'Warning' end,
       [Sign Off Note] = case when note like '%waiver%'then '' when cast(dateadd(WEEK,12,[Start Date]) as date) <cast([End Date] as Date) then 'Grace period of 12 weeks will expire before Sign Off '+convert(nchar(10),dateadd(WEEK,12,[End Date]),103) else '' end,
	   Note= case when note like '%waiver%' then Note else 'Grace period of 12 weeks will expire before Sign Off '+convert(nchar(10),[End Date],103) end,
	   [Last Date of Grace Period] = cast(dateadd(WEEK,12,[Start Date]) as date),
	   [Document Non Compliant] = 0,
	   [Document Compliance] ='Compliant'
 WHERE [Template ID] = 'VGRP00000073'
   and [Document ID] = 'VSHP00000119'
   and cast(dateadd(WEEK,12,[Start Date]) as date)>cast(getdate() as date)
   and ([Sign On Status] = 'Non-Compliant' or [Sign Off Status] = 'Non-Compliant' or note like '%waiver%')

------------------------------------------------------ ANTI-CORRUPTION FOR SEAFARERS and others
   
   UPDATE #Part
	 SET  [Sign On Status] = case when [Sign On Status] = 'Non-Compliant' then 'Warning' else [Sign On Status] end,
		  [Sign On Note] = case when [Sign On Status] = 'Non-Compliant' then 'Eff. 10/01/2022 - auto update' else [Sign On Note] end,
		  [Sign Off Status] = case when [Sign Off Status] = 'Non-Compliant' then 'Warning' else [Sign Off Status] end,
		  [Sign Off Note] = case when [Sign Off Status] = 'Non-Compliant' then 'Eff. 10/01/2022 - auto update' else [Sign Off Note] end,
		  Note = case when Note like '%Waiver%' then  'By Waiver' + '. Eff. 10/01/2022' else '. Eff. 10/01/2022 - auto update' end,
		  [Document Non Compliant] = 0,
		  [Document Compliance] ='Compliant'
	 WHERE  [Template ID] in ('VGRP00000073','GLAS00000124','GLAS00000134','GLAS00000192')
		and [Document ID] in ('GLAS00000222','GLAS00000172','MANI00000053','GLAS00000360')
		and Note not like 'Missing%' 
	    and ([Sign On Status] = 'Non-Compliant' or [Sign Off Status] ='Non-Compliant' or note like '%Waiver%')
	    and [Start Date] <'2022-01-10'
	   

	   ---***Cadets***---
	      UPDATE #Part
	 SET [Sign On Status]  = case when [Sign On Status]  = 'Non-Compliant' then 'Warning' else [Sign On Status] end,
		  [Sign On Note] = case when [Sign On Status] = 'Non-Compliant' then 'Eff. 10/01/2022 - auto update' else [Sign On Note] end,
		  [Sign Off Status] = case when [Sign Off Status] = 'Non-Compliant' then 'Warning' else [Sign Off Status] end,
		  [Sign Off Note] = case when [Sign Off Status] = 'Non-Compliant' then 'Eff. 10/01/2022 - auto update' else [Sign Off Note] end,
		  Note = case when Note like '%Waiver%' then  'By Waiver' + '. Eff. 10/01/2022' else '. Eff. 10/01/2022 - auto update' end,
		  [Document Non Compliant] = 0,
		  [Document Compliance] ='Compliant'
	 WHERE [Template ID] in ('VGRP00000073','GLAS00000124','GLAS00000134')
			and [Document ID] in ('MANI00000053') 
		    and [Rank ID] in ('VSHP00000018') 
		    and ([Sign On Status] = 'Non-Compliant' or [Sign Off Status] ='Non-Compliant' or NOTE like '%Waiver%')
		    and [Start Date] <'2022-01-10'

-----------------Update Dummy columns so documents will be reported as Grace Period
   UPDATE #Part
   SET
	  [Document Requirement 1] = case when [Document Requirement Short Code 1] ='PRE (SO)' then [Document Requirement 1] +' Within 12W' else [Document Requirement 1] end,
	  [Document Requirement Short Code 1] = case when [Document Requirement Short Code 1] ='PRE (SO)' then 'PRE(SO)+12W' else [Document Requirement Short Code 1] end
   WHERE [Template ID]='VGRP00000073'
   and [Document ID] = 'VSHP00000119'

 -----------Medical Fitness Cert-------
	UPDATE #Part
   SET [Sign On Status] = case when dateadd(M,3, [Document Expiry Date])>[End Date] then 'Warning' 
                             when DATEADD(M,3,[Document Expiry Date])>=GETDATE() then 'Warning'
                        else [Sign Off Status] end,
       [Sign Off Note] = case when dateadd(M,3,[Document Expiry Date])> [End Date] then 'Grace period until '+convert(varchar,dateadd(M,3,[Document Expiry Date]),103)+' to renew certificate.' 
                           when DATEADD(M,3,[Document Expiry Date])>=GETDATE() then 'Grace period until '+convert(varchar,dateadd(M,3,[Document Expiry Date]),103)+' to renew certificate.' 
                      else 'Grace period to renew certificate has passed on '+convert(varchar,dateadd(M,3,[Document Expiry Date]),103) end,
	   Note = case when dateadd(M,3,[Document Expiry Date])> [End Date] then 'Grace period until '+convert(varchar,dateadd(M,3,[Document Expiry Date]),103)+' to renew certificate.' 
                           when DATEADD(M,3,[Document Expiry Date])>=GETDATE() then 'Grace period until '+convert(varchar,dateadd(M,3,[Document Expiry Date]),103)+' to renew certificate.' 
                      else 'Grace period to renew certificate has passed on '+convert(varchar,dateadd(M,3,[Document Expiry Date]),103) end,
	   [Document Non Compliant] = case when dateadd(M,3,[Document Expiry Date])>[End Date] then 0 
                             when DATEADD(M,3,[Document Expiry Date])>=GETDATE() then 0
                        else 1 end,
		[Document Compliance] = case when dateadd(M,3,[Document Expiry Date])> [End Date] then 'Compliant'
                             when DATEADD(M,3,[Document Expiry Date])>=GETDATE() then 'Compliant'
                        else 'Non-Compliant' end
 where [Document ID] = 'VSHP00000016'
   and [Template ID] = 'GLAS00000054'
   and ([Sign On Status] <>'Non-Compliant' and [Sign Off Status] = 'Non-Compliant')
 
 ---------------------COURSES excluded before/ seafarers signed on before effective date----
	UPDATE #Part
	 SET [Sign On Status] = case when [Sign On Status] = 'Non-Compliant' then 'Compliant' else [Sign On Status] end,
		  [Sign Off Status] = case when [Sign Off Status] = 'Non-Compliant' then 'Compliant' else [Sign Off Status] end,
		  [Document Non Compliant] = 0,
		  [Document Compliance] = 'Compliant'
	 WHERE [Training Type] ='Old Training' and
	 cast([Start Date] as date) < [Effective Start Date]

---------------------------------------------------------------------------------------------
  UPDATE #Part
   SET [Sign On Status] = case when note like '%waiver%' then [Sign On Status] else 'Warning' end,
       [Sign Off Status] = case when note like '%waiver%' then [Sign Off Status] else 'Warning' end,
       [Sign Off Note] = case when note like '%waiver%'then '' else [Sign Off Note]  end,
	   Note= case when note like '%waiver%' then Note else 'Pre(SO)'+ Note /*convert(nchar(10),dateadd(WEEK,12,StartDate),103) */end,
	   [Document Non Compliant] = 0,
	   [Document Compliance] ='Compliant'
where  ([Template ID] IN(
'GLAS00000124',
'VGRP00000073',
'GLAS00000106',
'GLAS00000197',
'GLAS00000219',
'GLAS00000085',
'GLAS00000222',
'GLAS00000128',
'GLAS00000189',
'GLAS00000190',
'GLAS00000193',
'GLAS00000243',
'GLAS00000244',
'GLAS00000160',
'GLAS00000161',
'VGRP00000071',
'VGRP00000072',
'GLAS00000082',
'GLAS00000195',
'GLAS00000216'
,'GLAS00000131',
'GLAS00000194',
'GLAS00000135',
'GLAS00000136') or [Template Name] like '%ECDIS%')
AND [Requirement Type] in ('VMS','Other')
AND ( Note like '%Validity Period of%months expire%before Sign Off%'
		or Note like 'Document%expire%whilst on board%' or Note like 'Document%expire%before Sign Off%')
AND [Document Compliance] = 'Non-Compliant'

-- for Culture Mngmt and Competency Mgmt adn MTI Media Course
UPDATE #Part
   SET [Sign On Status] = case when note like '%waiver%' then [Sign On Status] else 'Warning' end,
       [Sign On Note] = 'Grace period of 12 weeks from Sign On allowed - auto update',
       [Sign Off Status] = case when cast(dateadd(WEEK,12,'2022-09-15') as date) < cast([End Date] as Date) then 'N' else 'C' end,
       [Sign Off Note] = case when cast(dateadd(WEEK,12,'2022-09-15') as date) < cast([End Date] as Date) then 'Grace period of 12 weeks will expire before Sign Off '+convert(nchar(10),dateadd(WEEK,12,[Start Date]),103) else 'Compliant' end,
	   Note = case when cast(dateadd(WEEK,12,'2022-09-15') as date) < cast([End Date] as Date) then 'Grace period of 12 weeks will expire before Sign Off '+convert(nchar(10),dateadd(WEEK,12,[Start Date]),103) else 'Compliant' end,
	   [Document Non Compliant] = 0 ,
	   [Document Compliance] =  'Compliant' 
 WHERE [Template ID] = 'VGRP00000073'
   and [Document ID] in ('VGRP00000575','VGR400000682','VGR400000748')
   and [Sign On Note] like '%grace period% has passed%'
   and cast([Start Date] as Date) <= '2022-09-15'
   and cast(getdate() as date)<cast(dateadd(WEEK,12,'2022-09-15') as date);

-- for VOC
UPDATE #Part
   SET [Sign On Status] = case when note like '%waiver%' then [Sign On Status] else 'Warning' end,
       [Sign On Note] = 'Grace period of 1 month from Sign On allowed - auto update',
       [Sign Off Status] = case when cast(dateadd(M,1,'2022-09-15') as date) < cast([End Date] as Date) then 'N' else 'C' end,
       [Sign Off Note] = case when cast(dateadd(M,1,'2022-09-15') as date) < cast([End Date] as Date) then 'Grace period of 1 month will expire before Sign Off '+convert(nchar(10),dateadd(WEEK,12,[Start Date]),103) else 'Compliant' end,
	   Note = case when cast(dateadd(M,1,'2022-09-15') as date) < cast([End Date] as Date) then 'Grace period of 1 month will expire before Sign Off '+convert(nchar(10),dateadd(WEEK,12,[Start Date]),103) else 'Compliant' end,
	   [Document Non Compliant] = 0 ,
	   [Document Compliance] =  'Compliant' 
 WHERE [Template ID] ='GLAS00000194'
   and [Document ID] in ('GLAS00000210')
   and [Sign On Note] like '%grace period% has passed%'
   and cast([Start Date] as Date) <= '2022-09-15'
   and [Rank ID] in ('VSHP00000079','VSHP00000077','VSHP00000072','VSHP00000068','VSHP00000002','VSHP00000012','VSHP00000014')
   and cast(getdate() as date)<cast(dateadd(M,1,'2022-09-15') as date);

-- for Port State Control and Toolbox Talks
UPDATE #Part
   SET [Sign On Status] = case when note like '%waiver%' then [Sign On Status] else 'Warning' end,
       [Sign On Note] = 'Grace period of 8 weeks from Sign On allowed - auto update',
       [Sign Off Status] = case when cast(dateadd(WEEK,8,'2022-09-15') as date) < cast([End Date] as Date) then 'N' else 'C' end,
       [Sign Off Note] = case when cast(dateadd(WEEK,8,'2022-09-15') as date) < cast([End Date] as Date) then 'Grace period of 8 weeks will expire before Sign Off '+convert(nchar(10),dateadd(WEEK,12,[Start Date]),103) else 'Compliant' end,
	   Note = case when cast(dateadd(WEEK,8,'2022-09-15') as date) < cast([End Date] as Date) then 'Grace period of 8 weeks will expire before Sign Off '+convert(nchar(10),dateadd(WEEK,12,[Start Date]),103) else 'Compliant' end,
	   [Document Non Compliant] = 0 ,
	   [Document Compliance] =  'Compliant' 
 WHERE [Template ID] ='VGRP00000073'
   and [Document ID] in ('GLAT00000014','VGR400000724')
   and [Sign On Note] like '%grace period% has passed%'
   and cast([Start Date] as Date) <= '2022-09-15'
   and cast(getdate() as date)<cast(dateadd(M,2,'2022-09-15') as date);

-- for Oily Water
UPDATE #Part
   SET [Sign On Status] = case when note like '%waiver%' then [Sign On Status] else 'Warning' end,
       [Sign On Note] = 'Grace period of 1 month from Sign On allowed - auto update',
       [Sign Off Status] = case when cast(dateadd(M,1,'2022-09-15') as date) < cast([End Date] as Date) then 'N' else 'C' end,
       [Sign Off Note] = case when cast(dateadd(M,1,'2022-09-15') as date) < cast([End Date] as Date) then 'Grace period of 1 month will expire before Sign Off '+convert(nchar(10),dateadd(WEEK,12,[Start Date]),103) else 'Compliant' end,
	   Note= case when cast(dateadd(M,1,'2022-09-15') as date) < cast([End Date] as Date) then 'Grace period of 1 month will expire before Sign Off '+convert(nchar(10),dateadd(WEEK,12,[Start Date]),103) else 'Compliant' end,
	   [Document Non Compliant] = 0 ,
	   [Document Compliance] =  'Compliant' 
 WHERE [Template ID] = 'VGRP00000073'
   and [Document ID] in ('GLAT00000048')
   and [Sign On Note] like '%grace period% has passed%'
   and cast([Start Date] as Date) <= '2022-09-15'
   and [Rank ID] in ('VSHP00000002')
   and cast(getdate() as date)<cast(dateadd(M,1,'2022-09-15') as date);
   
    UPDATE #Part
	 SET 
		 Note = Note + '. Document Expires in less than 30 day after planned Sign Off Date'
	 WHERE DATEDIFF(day, [Document Expiry Date], [End Date])<30 and Note='Compliant'

----MEdical Care for Filipino 2nd Off

	  UPDATE #Part
	  SET

	   [Sign On Status] = case when [Sign On Status] = 'Compliant'then 'Compliant' else  'Warning' end,
       [Sign On Note] = case when [Sign On Status] = 'Compliant'then 'Compliant' else  'Missing Recommended document' end,
       [Sign Off Status] = case when [Sign Off Note] = 'Compliant'then 'Compliant' else  'Warning' end,
       [Sign Off Note] =  case when [Sign Off Note] = 'Compliant'then 'Compliant' else  'Missing Recommended document' end,
	   Note = case when Note = 'Compliant'then 'Compliant' else  'Missing Recommended document' end,
	   [Document Non Compliant] = 0 ,
	   [Document Compliance] =  'Compliant' ,
	   [Document Requirement Short Code] = 'REC'

 WHERE  [Document ID] = 'VSHP00000024'
 AND [Rank ID] ='VSHP00000012'
  AND [Crew Nationality] ='Filipino'
  and [Template ID] in ('GLAS00000124','VGRP00000073')

 -------------------------------------------------------------------------------------------------------NRS UPDATE TEMP-----------------------------------------------------------------------------------------------------------------------------------------
	 UPDATE #Part
	 SET [Sign On Status] =  'Compliant' ,
		 [Sign Off Status] = 'Compliant',
		 [CPI Report] ='Incl-NRS',
		 [Document Non Compliant] = 0,
		 [Document Compliance] ='Compliant'
	 WHERE [Remarks] like 'STATUTORY documents are not reported%' and [CPI Report] ='Excluded' and [Requirement Type] ='Statutory'

-------------------FINAL SELECT-------------------------------------------------

BEGIN TRAN
INSERT INTO [dbo].[SF_STAGE_CrewCompliance]

SELECT DISTINCT 

[Run Day] = GETUTCDATE(),
p.[Crew ID],
p.[Vessel ID],
p.[Vessel Mgmt ID],
p.[Rank ID],
p.[Rank Sequence],
p.[Crew Status],
p.[Start Date],
p.[End Date],
p.[Document Number],
p.[Document ID],
p.[Document Country ID],
p.[Document Issued Date],
p.[Document Expiry Date],
p.[Document Description],
p.[Document General Name],
p.[Sign On Status],
p.[Sign Off Status],
p.[Note],
p.[Grace Period],
p.[Sign On Note],
p.[Sign Off Note],
p.[Template Name],
p.[Template is Core],
p.[Document Requirement Short Code],
p.[Document Requirement],
p.[Last Date of Grace Period],
p.[Document Non Compliant],
p.[Document Compliance],
p.[Template ID],
p.[Company To Exclude],
p.[Template Requirement],
p.[Effective Start Date],
p.[Reporting Start Date],
p.[Training Type],
p.[CPI Report],
p.[Exclusion Start Date],
p.[Exclusion End Date],
p.[Exclusion Category],
p.[Remarks],
p.[Is Flag State],
p.[Requirement Type],
p.[Is Default Template],
p.[Document Group Type],
[Sign On 14 Days] = case when datediff(day,[Start Date],getdate()) >14 then 'No' else 'Yes' end,
[Document Missing] = case  when (note like '%Missing Mandatory document with no grace period%' or note like '%Missing Flag Specific document%'  or note like '%No document marked as Primary%' or  note like '%Grace period%from Sign On%')  and [Document Compliance]='Non-Compliant' then 1 else 0 end
,[Document Expired at Sign Off] = case  when (note like '%Document%expires%before Sign Off%' or note like '%Validity Period%expires before Sign Off%' or note like '%Document expires%before Sign Off%')  and [Document Compliance] ='Non-Compliant' then 1 else 0 end
,[Document Expired] = case when (note like '%Validity Period%expires before Sign On%' or note like '%Document%expired%before Sign On%' or note like '%Expiry date missing for document%' or note like '%Document%expired%whilst on board%'or note like 'Grace period to renew certificate has passed on%' ) and [Document Compliance] ='Non-Compliant' 	then 1 else 0 end
,[Grace Period Allowance]= case when [Document Requirement 1] like '%Within%' then 'YES' else 'NO' end
,[Document Status] =case when (note like '%Missing Mandatory document with no grace period%' or note like '%Missing Flag Specific document%'  or note like '%No document marked as Primary' or  note like '%Grace period%from Sign On%')  and [Document Compliance] ='Non-Compliant' then 'Missing'
						  when (note like '%Document%expires%before Sign Off%' or note like '%Validity Period%expires before Sign Off%' or note like '%Document expires%before Sign Off%')  and [Document Compliance] ='Non-Compliant' then  'Expired at SignOff'
						  when (note like '%Validity Period%expires before Sign On%' or note like '%Document%expired%before Sign On%' or note like '%Expiry date missing for document%' or note like '%Document%expired%whilst on board%' or note like 'Grace period to renew certificate has passed on%' ) and [Document Compliance] ='Non-Compliant'  then  'Expired' 
						else 'OK' end 
,[Note Short Code] = case when [Document Requirement Short Code] ='REC' then NULL	
							  when (note like '%Document%expired%before Sign On%' or note like '%Validity Period%expires before Sign On%') then 'Expired before Sign-On' 
							  when (note like '%Document%expired%whilst on board%' or note like 'Grace period to renew certificate has passed on%')  then 'Expired while On Board'
							  when (note like '%Document%expires%before Sign Off%' or note like '%Validity Period%expires before Sign Off%')   then 'Expires before Sign-Off'
							  when (note like '%Expiry date missing for document%')   then 'Missing expiry date' 
							  when (note like  '%Grace period of%from Sign On has passed%'  or note like '%Missing Flag Specific document%' or note like '%Missing Mandatory document with no grace period%'or note like '%No document marked as Primary%' or
									( note like '%waiver%' and note not like '%. Eff.%' and [Sign On Note] not like '%By Waiver. (Grace Period allowed)%') )  then 'Missing mandatory document' end 		
,[Expiry Status] = case when (note like '%Missing Mandatory document with no grace period%' or note like '%Missing Flag Specific document%'  or note like '%No document marked as Primary' or  note like '%Grace period%from Sign On%')  and [Document Compliance] ='Non-Compliant' then 'Missing'
						when (note like '%Document%expires%before Sign Off%' or note like '%Validity Period%expires before Sign Off%' or note like '%Document expires%before Sign Off%' or note like 'Grace period until%to renew certificate.') then  'Expiring'
						when (note like '%Validity Period%expires before Sign On%' or note like '%Document%expired%before Sign On%' or note like '%Expiry date missing for document%' or note like '%Document%expired%whilst on board%' or note like 'Grace period to renew certificate has passed on%' ) and [Document Compliance] ='Non-Compliant'  then  'Expired' 
						else 'OK' end 
,[Days To Expire] = case when (note like '%Missing Mandatory document with no grace period%' or note like '%Missing Flag Specific document%'  or note like '%No document marked as Primary' or  note like '%Grace period%from Sign On%')  and [Document Compliance] ='Non-Compliant' then 'Missing'
						 when (note like '%Document%expires%before Sign Off%' or note like '%Validity Period%expires before Sign Off%' or note like '%Document expires%before Sign Off%' or note like 'Grace period until%to renew certificate.') and DATEDIFF(day,GETDATE(),[Document Expiry Date])<31 then  'Expiring in 30 Days'
						 when (note like '%Document%expires%before Sign Off%' or note like '%Validity Period%expires before Sign Off%' or note like '%Document expires%before Sign Off%' or note like 'Grace period until%to renew certificate.') and DATEDIFF(day,GETDATE(),[Document Expiry Date])>=31 then  'Expiring >30 Days'
						 when (note like '%Validity Period%expires before Sign On%' or note like '%Document%expired%before Sign On%' or note like '%Expiry date missing for document%' or note like '%Document%expired%whilst on board%' or note like 'Grace period to renew certificate has passed on%' ) and [Document Compliance] ='Non-Compliant'  then  'Expired' 
						else 'OK' end 
						
					-----------------CASUAL ELEMENTS-------------------------------- END
					------------------ DISPENSAIONS +CASUALS ------------------

,[Document Missing Without Dispensation] = case  when ((note like '%Missing Mandatory document with no grace period%' or note like '%Missing Flag Specific document%'  or note like '%No document marked as Primary%' or  note like '%Grace period%from Sign On%')  
															and [Document Compliance] ='Non-Compliant') or  ( note like '%waiver%' and note not like '%. Eff.%' and [Sign On Note] not like '%By Waiver. (Grace Period allowed)%') then 1 else 0 end

,[Document Expired at Sign Off Without Dispensation] = case  when (note like '%Document%expires%before Sign Off%' or note like '%Validity Period%expires before Sign Off%' /*or note like '%Document expired%whilst on board%' */or note like '%Document expires%before Sign Off%')  and [Document Compliance] ='Non-Compliant' and note not like  '%waiver%' then 1 else 0 end
,[Document Expired WithoutDispensation] = case when (note like '%Validity Period%expires before Sign On%' or note like '%Document%expired%before Sign On%' or note like '%Expiry date missing for document%' or note like '%Document%expired%whilst on board%'or note like 'Grace period to renew certificate has passed on%' ) and [Document Compliance] ='Non-Compliant' and note not like  '%waiver%' then 1 else 0 end
,[Dispensation Status] = case when [Document Expiry Date] <getdate() and note like '%waiver%' then 'Expired'		
							  when [Document Expiry Date] <(getdate()+30) and [Document Expiry Date] >=getdate()  and note like '%waiver%' then 'DueToExpire'  
							  when ([Document Expiry Date] >=(getdate()+30) or [Document Expiry Date] is null) and note like '%waiver%' then 'Active' end 	
,[Dispensation] = case when note like '%waiver%' then 'YES' else 'NO' end
,[Document Non Compliance Ignoring Dispensation] = Case when ( note like '%waiver%' and note not like '%. Eff.%' and [Sign On Note] not like '%By Waiver. (Grace Period allowed)%') then 1 else [Document Non Compliant] end
,[Document Compliance Ignoring Dispensation] = Case when ( note like '%waiver%' and note not like '%. Eff.%' and [Sign On Note] not like '%By Waiver. (Grace Period allowed)%')  then 'Non-Compliant' else [Document Compliance] end	

						------------------ DISPENSAIONS +CASUALS ------------------ END	
	 
						--------------------------- GRACE PERIOD -----------
	
,[Non Compliant Grace] = case when [Document Requirement 1] like '%Within%' and( note like '%Grace period of%from Sign On has passed%' and note not like '%Eff.%Grace period of%from Sign On has passed%') then 1
							  when  [Document Requirement 1] like '%Within%' and  [Sign Off Status] ='Warning' and note not like '%Eff.%'  or ([Sign On Note] like '%Validity Period%expire%before Sign On%' and [Document Non Compliant] = 0) then 2
							  else [Document Non Compliant] end 
,[Grace Period Exists] = case when [Document Requirement 1] like '%Within%' and (( note like '%Waiver%' and [Document Non Compliant] = 0)or note  like '%Eff.%'or note like '%Compliant%' or note like '%Equivalent%'or note like '%Covered%'or  note like 'Pre(SO) Document expire%whilst on board%'
									or note like 'Pre(SO) Document expires%before Sign%'or note like 'Seafarer rank excluded from compliance' ) then 1 else 0 end 
,[Grace Period Missing] = case when [Document Requirement 1] like '%Within%' and ( (note like '%Grace period of%from Sign On has passed%' and note not like '%Eff.%Grace period of%from Sign On has passed%')or note like'%Missing Mandatory document with no grace period%' or note like '%Document%expired%before Sign On%'/*or note like '%auto update%'*/) then 1 else 0 end
,[Grace Period Within Grace Period]= case when [Document Requirement 1] like '%Within%' and (note like '%Grace period of%from Sign On allowed%' or note like '%Grace period of%will expire before Sign Off%')  then 1 else 0 end
,[Grace Period Expired at Sign Off] = case when [Document Requirement 1] like '%Within%' and (note like '%Validity Period of%expires before Sign Off%'or note like '%Document%expired%whilst on board%' or note like '%Document expires%before Sign Off%')  and ([Document Compliance] ='Non-Compliant' or [Sign Off Status] = 'Warning') then 1 else 0 end
,[Grace Period Document Status] = case when [Document Requirement 1] like '%Within%' and ( note like 'Seafarer rank excluded from compliance' or( note like '%Waiver%' and [Document Non Compliant] = 0)or  note  like '%Eff.%'or note like '%Compliant%' or note like '%Equivalent%' or note like '%Covered%'  or  note like 'Pre(SO) Document expire%whilst on board%' 	or note like 'Pre(SO) Document expires%before Sign%') then 'Exists'
									   when [Document Requirement 1] like '%Within%' and (note like '%Grace period of%from Sign On has passed%' or note like'%Missing Mandatory document with no grace period%' or note like '%Document%expired%before Sign On%') then 'Missing'
									   when [Document Requirement 1] like '%Within%' and (note like '%Grace period of%from Sign On allowed%' or note like '%Grace period of%will expire before Sign Off%') then 'Within Grace Period'
									   when [Document Requirement 1] like '%Within%' and (note like '%Validity Period of%expires before Sign Off%'or note like '%Document%expired%whilst on board%' or note like '%Document expires%before Sign Off%')  and ([Document Compliance] ='Non-Compliant' or [Sign Off Status] = 'Warning') then 'Expired at Sign Off' end 
,[Grace Include Dispensation Compliance] = case  when  [Document Requirement 1] like '%Within%' and (note like '%Grace period of%from Sign On has passed%'  and note not like '%Eff.%Grace period of%from Sign On has passed%' ) then 'Non-Compliant' 
											   when  [Document Requirement 1] like '%Within%' and [Sign Off Status] ='Warning' and note not like '%Eff.%' or ([Sign On Note] like '%Validity Period%expire%before Sign On%' and [Document Non Compliant] = 0) then 'Warning' else [Document Compliance] end

--------------------------- GRACE PERIOD ----------- END
--------------------------- GRACE PERIOD + DISPENSATIONS----------- 
	
,[Grace Dispensation Compliance] = case when  ( note like '%waiver%' and note not like '%. Eff.%' and [Sign On Note] not like '%By Waiver. (Grace Period allowed)%') then 'Non-Compliant' 
										when  [Document Requirement 1] like '%Within%' and note like '%Grace period of%from Sign On has passed%' and note not like '%Eff.%Grace period of%from Sign On has passed%' then 'Non-Compliant' 
										when  ([Document Requirement 1] like '%Within%' and [Sign Off Status] ='Warning' and note not like '%Eff.%') or ([Sign On Note] like '%Validity Period%expire%before Sign On%' and [Document Non Compliant] =0) then 'Warning' else [Document Compliance] end
,[Non Compliant Grace Dispensation] = case when ( note like '%waiver%' and note not like '%. Eff.%' and [Sign On Note] not like '%By Waiver. (Grace Period allowed)%')  then 1 
								 when  [Document Requirement 1] like '%Within%' and note like '%Grace period of%from Sign On has passed%' and note not like '%Eff.%Grace period of%from Sign On has passed%' then 1
								 when  ([Document Requirement 1] like '%Within%' and [Sign Off Status] ='Warning'and note not like '%Eff.%') or ([Sign On Note] like '%Validity Period%expire%before Sign On%' and [Document Non Compliant] =0) then 2 else [Document Non Compliant] end
,[Grace Period Dispensation Document Status] = case when [Document Requirement 1] like '%Within%' and (( (note like '%Compliant%' or note like '%Equivalent%' or note like '%Covered%')and note not like '%waiver%') or ( note not like '%waiver%' and note  like '%Eff.%' and [Sign On Note]  not like '%By Waiver. (Grace Period allowed)%')
														or  note like 'Pre(SO) Document%expired%whilst on board%' 	or note like 'Pre(SO) Document expires%before Sign%' or  note like 'Seafarer rank excluded from compliance' ) then 'Exists'
												 when [Document Requirement 1] like '%Within%' and (( note like '%waiver%' and note not like '%Eff.%' and [Sign On Note] not like '%By Waiver. (Grace Period allowed)%') or note like '%Grace period of%from Sign On has passed%' or note like'%Missing Mandatory document with no grace period%' or note like '%Document%expired%before Sign On%') then 'Missing'
												 when [Document Requirement 1] like '%Within%' and (note like '%Grace period of%from Sign On allowed%' or note like '%Grace period of%will expire before Sign Off%' or   [Sign On Note]  like '%By Waiver. (Grace Period allowed)%') then 'Within Grace Period'
												 when [Document Requirement 1] like '%Within%' and (note like '%Validity Period of%expires before Sign Off%' or note like '%Document%expired%whilst on board%' or note like '%Document expires%before Sign Off%')  and ([Document Compliance] ='Non-Compliant' or [Sign Off Status] = 'Warning') then 'Expired at Sign Off' end
,[Grace Period Dispensation Exists] = case when [Document Requirement 1] like '%Within%' and ( note not like '%Waiver%' and( note  like '%Eff.%' or note like 'Seafarer rank excluded from compliance' or note like '%Compliant%' or note like '%Equivalent%' or note like '%Covered%' or  note like 'Pre(SO) Document expire%whilst on board%'
										or note like 'Pre(SO) Document expires%before Sign%') )then 1 else 0 end
,[Grace Period Dispensation Missing] = case when [Document Requirement 1] like '%Within%' and (( note like '%waiver%' and note not like '%Eff.%' and [Sign On Note] not like '%By Waiver. (Grace Period allowed)%') or ( note like '%Grace period of%from Sign On has passed%' and note not like '%Eff.%Grace period of%from Sign On has passed%') or note like'%Missing Mandatory document with no grace period%' or note like '%Document%expired%before Sign On%') then 1 else 0 end
,[OTG Code Grace] = case when [Document Requirement 1] like '%Within%' and (note like '%Grace period of%from Sign On allowed%' or note like '%Grace period of%will expire before Sign Off%')  then [Grace Period]
						 when note like '%waiver%' and note not like '%Eff.%' then 'DISP'  End 
,[Course Color Category] = Case when [Document Requirement 1] like '%Mandatory%Pre-Joining%' then 'Red' when [Document Requirement 1] like '%Within%' then 'Orange' else 'Other' end
,newID() as [Row ID]
--------------------------- GRACE PERIOD + DISPENSATIONS----------- END
	from #part p
	WHERE  (note not like 'Seafarer rank excluded from compliance' or note is null)
	order by [Rank Sequence]

COMMIT


DROP TABLE #tmpVes
DROP TABLE #part

END



