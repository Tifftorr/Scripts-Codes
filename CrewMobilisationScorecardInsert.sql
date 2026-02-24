CREATE PROCEDURE [ShipMgmt_Crewing].[CrewMobilisationScorecardInsert]
(
@DateFromPipeline DATETIME
)

AS 

BEGIN

DECLARE @Date DATETIME = @DateFromPipeline;


IF OBJECT_ID('tempdb.dbo.#onboardcrew') IS NOT NULL
  DROP TABLE #onboardcrew;

IF OBJECT_ID('tempdb.dbo.#tmpTN') IS NOT NULL
  DROP TABLE #tmpTN;

IF OBJECT_ID('tempdb.dbo.#TN') IS NOT NULL
  DROP TABLE #TN;

IF OBJECT_ID('tempdb.dbo.#TNfinal') IS NOT NULL
  DROP TABLE #TNfinal;

IF OBJECT_ID('tempdb.dbo.#trainingneeds') IS NOT NULL
  DROP TABLE #trainingneeds;

IF OBJECT_ID('tempdb.dbo.#pre_joining_comp') IS NOT NULL
  DROP TABLE #pre_joining_comp;

IF OBJECT_ID('tempdb.dbo.#MCH') IS NOT NULL
  DROP TABLE #MCH;

IF OBJECT_ID('tempdb.dbo.#Mobrel') IS NOT NULL
  DROP TABLE #Mobrel;

IF OBJECT_ID('tempdb.dbo.#MobAcp') IS NOT NULL
  DROP TABLE #MobAcp;

IF OBJECT_ID('tempdb.dbo.#CDB') IS NOT NULL
  DROP TABLE #CDB;

IF OBJECT_ID('tempdb.dbo.#ontimerelief') IS NOT NULL
  DROP TABLE #ontimerelief;

IF OBJECT_ID('tempdb.dbo.#CRWAPPR') IS NOT NULL
  DROP TABLE #CRWAPPR;

IF OBJECT_ID('tempdb.dbo.#tmpdocs') IS NOT NULL
  DROP TABLE #tmpdocs;

IF OBJECT_ID('tempdb.dbo.#tmpdocsfinal') IS NOT NULL
  DROP TABLE #tmpdocsfinal;

IF OBJECT_ID('tempdb.dbo.#OnboardCrew1') IS NOT NULL
  DROP TABLE #OnboardCrew1;

IF OBJECT_ID('tempdb.dbo.#tmpSRVDetail') IS NOT NULL
  DROP TABLE #tmpSRVDetail;

IF OBJECT_ID('tempdb.dbo.#ObMovements') IS NOT NULL
  DROP TABLE #ObMovements;

IF OBJECT_ID('tempdb.dbo.#SignedPolicies') IS NOT NULL
  DROP TABLE #SignedPolicies;

IF OBJECT_ID('tempdb.dbo.#docpolicy') IS NOT NULL
  DROP TABLE #docpolicy;

-------------------------------------
-- Training Needs

--getting all onboard crew from full managed & cargo only
SELECT DISTINCT
AA.[Crew ID],
AA.[Mobilisation Cell],
AA.[Current Status Start Date],
AA.[Current Status End Date]

into #onboardcrew
FROM [ShipMgmt_Crewing].[Crew Current Status] AA
WHERE [Crew Pool Status] = 'Active'
AND [Current Status] = 'ONBOARD'
AND AA.[Management Type] IN ('Full Management', 'Tech Mgmt')
AND aa.Segment = 'CARGO'
AND (aa.[Supply Type] IS NULL OR aa.[Supply Type] <> 'Owner Supplied')

-- getting trainingneeds for onboard crew, removeing Training needs raised within contract and only TN raised > 2021
SELECT
OB.[Crew ID],
OB.[Mobilisation Cell],
OB.[Current Status Start Date],
OB.[Current Status End Date],
CT.[Training Need ID],
CT.[Training Need Raised On],
CT.[Course Description],
CT.[Status]

INTO #tmpTN
FROM #onboardcrew OB
LEFT JOIN ShipMgmt_Crewing.tCrewTrainingNeed CT ON ct.[Crew ID] = ob.[Crew ID]
WHERE ct.[Status] <> 'Cancelled'
AND CT.[Training Need Raised On] >= '2021-01-01' -- TN raised only from 2021 onwards
AND CASE WHEN (CAST(ct.[Training Need Raised On] AS DATE) >= CAST(ob.[Current Status Start Date] AS DATE)) THEN 1 ELSE 0 END = 0 --removing tn raised BETWEEN OB contract

--training needs
SELECT
tmptn.[Crew ID],
CASE WHEN tmptn.[Status] = 'Completed' then count(tmptn.[Training Need ID]) else 0 end as completed_tn,
CASE WHEN tmptn.[Status] <> 'Completed' then count(tmptn.[Training Need ID]) else 0 end as pending_tn

INTO #TN
FROM #tmpTN tmptn
GROUP BY tmptn.[Crew ID], tmptn.[Status]
ORDER BY 1

--into final
SELECT
[Crew ID], sum(completed_tn) as completed_tn, sum(pending_tn) as pending_tn

INTO #TNfinal
FROM #TN
GROUP BY [Crew ID]
ORDER BY 1 ASC
										
SELECT 
OB.*, TN.completed_tn, TN.pending_tn

into #trainingneeds
from #onboardcrew OB
inner join #TNfinal TN on TN.[Crew ID] = OB.[Crew ID]
-------------------------------------
-- documents upload

-- getting all docs uploaded month to date
Select 
AD.*, CDN.[Country Name] as [Document Issued Country], PD.[Nationality]

	into #tmpdocs
	from [ShipMgmt_Crewing].[tCrewDocumentUploads] AD
	LEFT JOIN [Reference_Position].[tCountry] CDN ON CDN.[Country ID] = AD.[Document Issued Country ID]
	INNER JOIN [ShipMgmt_Crewing].[tCrew] pd  (nolock)  on pd.[Crew ID] = AD.[Crew ID]
	LEFT JOIN [ShipMgmt_VesselMgmt].[tVesselMetricsPerDayNew] VV on VV.[Vessel ID] = AD.[Vessel ID] and vv.[Date] = CAST(AD.[Uploaded On] as DATE)
	where month(cast(AD.[Uploaded On] AS date)) = month(getdate())
	AND year(cast(AD.[Uploaded On] AS date)) = year(getdate())
	--CAST(AD.[Uploaded On] AS DATE) BETWEEN DATEADD(day,-30,getdate()) AND GETDATE() -- last 30 days upload
	AND VV.[Mgmt Type] in ('Full Management', 'Tech Mgmt')
	AND (PD.[Crew Contract Type] is null or PD.[Crew Contract Type] <> 'Owner Supplied') -- not owner supplied

--summarizing further to remove documents that are in flag state countries

Select F.*, 
	case 
			when F.[Document Scope] = 'OUT OF SCOPE' then 'OUT OF SCOPE'
			when F.[Document Name] = 'Visa - MCV' then 'OUT OF SCOPE'
			when F.[Document Issued Country] in ('Azerbaijan', 'Bahamas', 'Belgium', 'Belize', 'Cayman Islands', 'Cyprus', 'DANISH INTERNATIONAL REGISTER', 'Gibraltar', 'Hong Kong', 'Isle Of Man.', 'Liberia',
					'LUXEMBOURG (UN)', 'Madeira', 'Malta', 'Marshall Islands', 'Nigeria', 'Norwegian International ShipRegister', 'Panama', 'Singapore', 'St. Vincent') then 'OUT OF SCOPE'
			else 'IN SCOPE'

	end as DocumentScopeFinal

	into #tmpdocsfinal
	from #tmpdocs F
	where F.[Mobilisation Cell ID] not in ('VGRP00000117', 'VGRP00000118', 'VGR300000031', 'VGR400000265')   --removing palican, sea agency, seaway
	and case when (F.[Nationality] = 'Canadian' and F.[Mobilisation Cell ID] = 'VGRP00000130') then 1 else 0 end = 0 --removing all canadian crew under rigel mob cell

-------------------------------------
/*PREJOINING ONBOARD COMPLIANCE*/
Select distinct
[Record Inserted On]
,AA.[Crew ID]
,[Mobilisation Cell ID]
,SUM([Statutory Non Compliant Documents]) as [Statutory Non Compliant Documents]
,SUM([VMS Non Compliant Documents]) as [VMS Non Compliant Documents]

INTO #pre_joining_comp
from [ShipMgmt_Crewing].[tCrewComplianceTrends] AA
LEFT JOIN [ShipMgmt_VesselMgmt].[tShipMgmtRecords] SR on SR.[Vessel Mgmt ID] = AA.[Vessel Mgmt ID]
LEFT JOIN [Reference_Vessel].[tVessel] VV on VV.[Vessel ID] = AA.[Vessel ID]
WHERE [Vessel In Scope CPI] = 'Included'
AND [Default Template] = 'Yes'
AND [Template Requirement] = 'Mandatory'
AND [Crew Status] = 'Onboard'
AND [Course Color Category] = 'Red'
AND [Training Type] = 'Old Training'
AND cast([Record Inserted On] as date) = (select Max(cast([Record Inserted On] as date)) from [ShipMgmt_Crewing].[tCrewComplianceTrends])
AND SR.[Vessel Mgmt Type] in ('Full Management', 'Tech Mgmt')  -- sm only
AND VV.[Vessel Business] = 'Cargo' -- cargo only

GROUP BY 
[Record Inserted On]
,AA.[Crew ID]
,[Mobilisation Cell ID]

-------------------------------------
-- Mobilisation/Digital Checklist Usage

Select SD.[Crew ID], PD.[Mobilisation Cell ID], CH.[Mob Checklist ID], ch.[Mob Checklist Status]

into #MCH
FROM [ShipMgmt_Crewing].[tCrewServiceRecords] SD
LEFT JOIN ( Select * 
			from [ShipMgmt_Crewing].[tCrewMobilisationCheckList] MCH
			where MCH.[Mob Checklist Deleted] = 0
			AND mch.[Mob Checklist Status ID] IN ('GLAS00000002','GLAS00000003')) CH on CH.[Linked Service Record ID] = sd.[Service Record ID]
INNER JOIN [ShipMgmt_Crewing].[tCrew] PD on PD.[Crew ID] = sd.[Crew ID]
LEFT JOIN [ShipMgmt_Crewing].[tCrewPool] MOB (NOLOCK) ON MOB.[Crew Pool ID] = PD.[Mobilisation Cell ID]
LEFT JOIN [ShipMgmt_VesselMgmt].[tShipMgmtRecords] (NOLOCK) VV ON VV.[Vessel Mgmt ID] = SD.[Vessel Mgmt ID]
LEFT JOIN [Reference_BusinessStructure].[tCompany] (NOLOCK) CL ON CL.[Company ID] = VV.[Client ID]
WHERE SD.[Service Cancelled] = 0
AND  SD.[Previous Experience] = 0
AND  (SD.[Service Active Status ID] IS NULL OR SD.[Service Active Status ID] <> (3))
AND  SD.[Status ID] IN ('OB','OV')
AND  CAST(SD.[Start Date] AS DATE) BETWEEN DATEADD(day,-30,getdate()) AND GETDATE() --only joiners in the last 30 days
AND (PD.[Crew Contract Type ID] IS NULL OR PD.[Crew Contract Type ID] <> 'VSHP00000002') --not owner supplied
AND CASE WHEN (PD.[Nationality] = 'Canadian' and PD.[Mobilisation Cell ID] = 'VGRP00000130') THEN 1 ELSE 0 END = 0 --removing all canadian crew under rigel mob cell
AND (SD.[Sign On Reason] IS NULL OR SD.[Sign On Reason] = 'Standard') --only standard sign on reasons
AND PD.[Mobilisation Cell ID] NOT IN ('VGRP00000117', 'VGRP00000118', 'VGR300000031', 'VGR400000265') ----removing palican, sea agency, seaway
AND VV.[Vessel Mgmt Type] IN ('Tech Mgmt', 'Full Management', 'Crew Mgmt') -- only SM & CM vessels
AND CL.[Company Name] NOT IN ('ADNOC Logistics & Services', 'ADNOC Logistics and Services') --exclude ADNOC

-------------------------------------
-- Mobilisation Reliability
SELECT sd.[Crew ID], pd.[Mobilisation Cell ID], 
case when cast(CSA.[Planning History Updated On] as date) <= cast(SD.[Crew Estimated Readiness Date] as date) then 'Compliant' else 'Non Compliant' end as [Compliance]

into #Mobrel
FROM [ShipMgmt_Crewing].[tCrewServiceRecords] SD
INNER JOIN [ShipMgmt_Crewing].[tCrew] PD ON PD.[Crew ID] = SD.[Crew ID]
LEFT JOIN [ShipMgmt_Crewing].[tCrewPool] MOB (NOLOCK) ON MOB.[Crew Pool ID] = PD.[Mobilisation Cell ID]
LEFT JOIN [ShipMgmt_Crewing].[tCrewPlanningHistory] CSA ON CSA.[Service Record ID] = SD.[Service Record ID] AND CSA.[Planning Status New] = 'Ready'
LEFT JOIN  [Reference_Vessel].[tVessel] VT ON VT.[Vessel ID] = SD.[Vessel ID]
WHERE SD.[Service Cancelled] = 0
AND	  SD.[Previous Experience] = 0
AND  (SD.[Service Active Status ID] IS NULL OR SD.[Service Active Status ID] <> (3))
AND   CAST(SD.[Start Date] AS DATE) BETWEEN DATEADD(day,-30,getdate()) AND GETDATE() --only joiners in the last 30 days
AND   SD.[Vessel ID] NOT IN ('GLAX00012386', 'GLAT00000027')
AND   SD.[Status ID] IN ('OB','OV')
AND   VT.[Vessel Business] <> 'Offshore'
AND (PD.[Crew Contract Type ID] IS NULL OR PD.[Crew Contract Type ID] <> 'VSHP00000002') --not owner supplied
AND (SD.[Sign On Reason] IS NULL OR SD.[Sign On Reason] = 'Standard') --only standard sign on reasons

-------------------------------------
--Mobilisation Acceptance

Select cph.[Crew ID], cph.[Planning History Updated On], sd.[Mobilisation Accepted On],
(datediff(dd,cast(sd.[Mobilisation Accepted On] as date), cast(cph.[Planning History Updated On] as date)) + 1) - datediff(ww,cast(sd.[Mobilisation Accepted On] as date), cast(cph.[Planning History Updated On] as date)) * 2 as weekdaysbetween,
DENSE_RANK() OVER ( PARTITION BY cph.[Crew ID] ORDER BY cph.[planning history updated on] desc) RN_ApprovedOn, pd.[Mobilisation Cell ID]

into #MobAcp
from  [ShipMgmt_Crewing].[tCrewPlanningHistory] CPH
left JOIN [ShipMgmt_Crewing].[tCrewServiceRecords] SD on SD.[Service Record ID] = CPH.[Service Record ID]
left JOIN [ShipMgmt_VesselMgmt].[tShipMgmtRecords] (NOLOCK) VV ON VV.[Vessel Mgmt ID] = SD.[Vessel Mgmt ID]
left JOIN [Reference_Vessel].[tVessel] VT ON VT.[Vessel ID] = SD.[Vessel ID]
left JOIN [ShipMgmt_Crewing].[tCrew] PD ON PD.[Crew ID] = CPH.[Crew ID]
WHERE (PD.[Crew Contract Type ID] IS NULL OR PD.[Crew Contract Type ID] <> 'VSHP00000002') 
AND cph.[Planning Status New] = 'Approved'
and month(cast(cph.[Planning History Updated On] as date)) = MONTH(DATEADD(month, -1, GETDATE())) -- approved last month
and year(cph.[Planning History Updated On]) = year(GETDATE())
AND SD.[Status ID] IN ('OB','OV')
AND SD.[Service Cancelled] = 0
AND SD.[Previous Experience] = 0
AND SD.[Vessel ID] NOT IN ('GLAX00012386', 'GLAT00000027')
AND VV.[Vessel Mgmt Type] IN ('Tech Mgmt', 'Full Management', 'Crew Mgmt')
AND VT.[Vessel Business] IN ('Cargo', 'Leisure')

-------------------------------------
-- Debriefing
SELECT CDB2.*, CASE WHEN (DATEDIFF(day,(cast(CDB2.[Target Date Completion] as date)), cast(CDB2.[Seafarer Contacted On] as date))) <= 0 THEN 1 ELSE 0 END AS [Compliance]

into #CDB
FROM (
	SELECT SD.[Crew ID], SD.[Start Date], SD.[End Date],  dateadd(day,15, SD.[End Date]) as [Target Date Completion], CDB.[Debriefing Status ID], CDB.[Seafarer Contacted On],
	PD.[Mobilisation Cell ID], DENSE_RANK() OVER ( PARTITION BY sd.[Crew ID] ORDER BY CDB.[Seafarer Contacted On] asc) RN

	FROM [ShipMgmt_Crewing].[tCrewServiceRecords] SD
	LEFT JOIN (Select * from [ShipMgmt_Crewing].[tCrewDebriefing] 
					where ([Debriefing Status ID] = 3 or [Debriefing Status ID] = 1)) CDB on CDB.[Service Record ID] = SD.[Service Record ID]
	LEFT JOIN [ShipMgmt_VesselMgmt].[tShipMgmtRecords] (NOLOCK) VV ON VV.[Vessel Mgmt ID] = SD.[Vessel Mgmt ID]
	left JOIN [ShipMgmt_Crewing].[tCrew] PD ON PD.[Crew ID] = SD.[CREW ID]
	WHERE SD.[Status ID] in ('OB', 'OV')
	AND SD.[Service Cancelled] = 0
	AND SD.[Previous Experience] = 0
	AND SD.[Active Status] = 0
	AND (SD.[Service Active Status ID] IS NULL OR SD.[Service Active Status ID] <> (3))
	AND (SD.[Sign Off Reason] IS NULL OR SD.[Sign Off Reason] NOT IN ('Promotion', 'Transfer'))
	AND VV.[Vessel Mgmt Type] IN ('Tech Mgmt', 'Full Management', 'Crew Mgmt')
	AND (PD.[Crew Contract Type ID] IS NULL OR PD.[Crew Contract Type ID] <> 'VSHP00000002')
	AND cast(SD.[End Date] as DATE) > cast(SD.[Start Date] as DATE)
	--AND dateadd(day,15, SD.[End Date]) >= DATEADD(DAY,-30,getdate()) AND dateadd(day,15, SD.[End Date]) <= GETDATE()
	) CDB2
WHERE (CDB2.[Debriefing Status ID] IS NULL OR [Debriefing Status ID] <> 1)
--AND RN = 1
AND cast(CDB2.[Target Date Completion] as date) BETWEEN DATEADD(DAY,-30,getdate()) AND GETDATE() --only offsigners where the target on date is in the last 30 days

-------------------------------------
-- timely relief ratings
select
AC.[Crew ID],
AC.[Planning Cell],
DATEDIFF(DAY, AC.[Contract End Date], GETDATE()) as [Days Difference],
CASE WHEN DATEDIFF(DAY, AC.[Contract End Date], GETDATE()) > 30 THEN 'Overdue' ELSE 'Timely Relieved' end as [Timely Relief Org Contract]

into #ontimerelief
from [ShipMgmt_Crewing].[Crew Current Status] AC
where [Current Status] = 'ONBOARD'
AND AC.[Rank Category] in ('Ratings','Offshore Ratings')
AND AC.[Management Type] in ('Full Management', 'Tech Mgmt')
-------------------------------------
-- crew appraisals
-- need to check which column is to be used
Select
ap.[Crew ID Appraisee],
ap.[Appraisal ID],
ap.[Appraisal Created On],
ap.[Appraisal Report Date],
AP.[Appraisal Reviewed On],
PD.[Mobilisation Cell ID],
SD.[End Date],
DATEDIFF(DAY,SD.[End Date] , AP.[Appraisal Reviewed On]) as [Days To Review],
DENSE_RANK() OVER ( PARTITION BY ap.[Crew ID Appraisee] ORDER BY ap.[Appraisal Created On] desc) as RN

INTO #CRWAPPR
from [ShipMgmt_Crewing].[tCrewAppraisal] ap
left join [ShipMgmt_Crewing].[tCrewServiceRecords] SD on SD.[Service Record ID] = ap.[Service Record ID Appraisee]
inner join [ShipMgmt_Crewing].[tCrew] PD ON PD.[Crew ID] = AP.[Crew ID Appraisee]
left join [ShipMgmt_Crewing].[tCrewRanks] rnk on rnk.[Rank ID] = SD.[Rank ID]
LEFT JOIN [ShipMgmt_VesselMgmt].[tShipMgmtRecords] (NOLOCK) VV ON VV.[Vessel Mgmt ID] = SD.[Vessel Mgmt ID]
left JOIN [Reference_Vessel].[tVessel] VT ON VT.[Vessel ID] = SD.[Vessel ID]
WHERE AP.[Appraisal is Deleted] = 0
AND SD.[Active Status] = 0
AND YEAR(SD.[End Date]) >= YEAR(GETDATE()) AND cast(SD.[End Date] as DATE) <= GETDATE()-15 --ytd offsigners excluding the ones who signed off last 15 days 
AND ap.[Appraisal Status] = 'Completed'
AND (PD.[Crew Contract Type ID] IS NULL OR PD.[Crew Contract Type ID] <> 'VSHP00000002')
AND rnk.[Rank Category] in ('Ratings', 'Offshore Ratings')
AND vv.[Vessel Mgmt Type] in ('Tech Mgmt', 'Full Management')
AND VT.[Vessel Business] = 'Cargo'

-------------------------------------
-- DOC Policy

---Crew Currently onboard
SELECT 
sr.[Service Record ID] AS [Current Service Record ID],
CSS.[Crew ID],
CSS.[Mobilisation Cell ID],
[Sign On]= SR.[Start Date] ,
[Planned Sign Off] =SR.[End Date],
[Reason for Sign On]=ISNULL(SR.[Sign On Reason],'Standard')

into #OnboardCrew1
FROM
[ShipMgmt_Crewing].[tCrew] CSS
INNER JOIN [ShipMgmt_Crewing].[tCrewServiceRecords] SR ON SR.[Crew ID]=CSS.[Crew ID]
Left join [ShipMgmt_Crewing].tCrewRanks rnk on rnk.[Rank ID]=SR.[Rank ID Budgeted]
	LEFT JOIN  ShipMgmt_VesselMgmt.tVesselMetricsPerDayNew MR ON MR.[Vessel ID] = SR.[Vessel ID] AND MR.[Date] =(SELECT MAX(DATE) FROM ShipMgmt_VesselMgmt.tVesselMetricsPerDayNew)
WHERE SR.[Status ID] ='OB' --Onboard Service
and SR.[Active Status]=1 --Active Service
and SR.[Service Cancelled]=0 -- Not deleted sercvice
AND mr.[Mgmt Type] in  ('Full Management','Tech Mgmt' )-- Only applies to Full and Tech Mgmt
---Exclusions for vessels, ranks or OFfice
and (case when SR.[Vessel ID] in ('VGR400021519', 'VGR400021518', 'VGR400021295') and sr.[Rank ID Budgeted] in ('VSHP00000349', 'VGR400000680', 'VSHP00000343') then 1 else 0 end = 0)
AND ([Mobilisation Office] is null or [Mobilisation Office]<>'CSL Australia')
AND [Technical Office]<>'CSL Australia'
and (CSS.[Third Party Agent ID] NOT IN ('VGR500006541','VGR500006565','VGR500006562') OR [Third Party Agent ID] IS NULL)-- SLowns down the query a lot
and SR.[Vessel ID] not in ('ODES00001763','GLAT00000027', 'VGRP00018812')
--and CSS.[crew id]='01094513'

-- Listing of onboard services to see if someone had an onboard movement
SELECT 
SD.[Crew ID],
SD.[Service Record ID],
COALESCE(SD.[Rank ID Budgeted],SD.[Rank ID]) AS [Rank ID],
SD.[Start Date],
SD.[End Date],
SD.[Previous Experience],
SD.[Vessel ID],
SD.[Sea Days],
ROW_NUMBER() OVER(PARTITION BY SD.[Crew ID] ORDER BY SD.[Start Date] DESC) AS rn 

into #tmpSRVDetail
FROM [ShipMgmt_Crewing].[tCrewServiceRecords] SD
INNER JOIN #OnboardCrew1 o on o.[Crew ID]=sd.[Crew ID] --> Restrict crew scope. no functionality as such
WHERE	SD.[Service Active Status ID] IN (1,2)   -- Active or Historical
AND		SD.[Service Cancelled] = 0 --Not Deleted
AND		SD.[Status ID] IN ('OB', 'OV') --Onboard
AND		SD.[Vessel ID] IS NOT NULL -- Onboard service must have a vessel ID
AND     SD.[End Date]>=GETDATE()-365-- Only services that ended within last year
AND     SD.[Previous Experience]=0 --Only company services

-- Check onboard movements
SELECT 
SRV.[Start Date] as [Event Date],-- change,
SRV.[Crew ID] as [Crew ID],
SRV.[Service Record ID] as [Current Service Record ID],
SR.[Service Record ID] as [Service Record ID Before OB MOVE],
SR.[Start Date] as [Sign On Before OB MOVE]

into #ObMovements
FROM #tmpSRVDetail SR --prev SERVICE
INNER JOIN #tmpSRVDetail SRV on SR.rn = SRV.rn+1 and SR.[Crew ID]=SRV.[Crew ID] -- actual SERVICE
INNER JOIN  #OnboardCrew1 AJ ON AJ.[Current Service Record ID]=SRV.[Service Record ID] --ACTUAL SERVICE IS ONBOARD SERVICE, Restrictcrew scope
WHERE 
 SR.[Service Record ID]<>SRV.[Service Record ID] -- Services must be different
and cast(SR.[Start Date] as date)<= cast(SRV.[Start Date]  as date) --Previous service must have started before the actual one
and SR.[Previous Experience]=0 -- COmpany experience
and SRV.[Previous Experience]=0--Company Experience
AND SR.[Vessel ID]=SRV.[Vessel ID]-- Services on same vessel
and datediff(day,isnull(SR.[End Date],dateadd(day,SR.[Sea Days],SR.[Start Date])), SRV.[Start Date])<=2 -- previous service sign off and new service sign on must not have break of more than 2 days


--Checking if seafarer has valid signed policies
SELECT  DISTINCT
[Policy Status]='Signed',
SO.[Crew ID]

into #SignedPolicies
FROM #OnboardCrew1 SO
LEFT JOIN #ObMovements OBO ON OBO.[Current Service Record ID]=SO.[Current Service Record ID]
LEFT JOIN [ShipMgmt_Crewing].[tCrewDOCPolicy] DOC ON DOC.[Crew ID]=SO.[Crew ID] AND DOC.[Is Policy Agreed]=1 AND DOC.[Crew Policy Agreed On] is not null
LEFT JOIN [ShipMgmt_Crewing].[tCrewDOCPolicyAttachments] DOCA ON DOCA.[Crew ID]=SO.[Crew ID]
WHERE DOC.[Service Record ID]=SO.[Current Service Record ID] --Policy linked to current service
                       OR DOC.[Service Record ID]=[Service Record ID Before OB MOVE] --Policy linked for previous servious
                       OR DATEDIFF(DAY,[Crew Policy Agreed On],[Sign On])<70 --Policy Signed min 70 days before sign on 
                       OR DATEDIFF(DAY,[Crew Policy Agreed On],[Sign On Before OB MOVE])<70--Policy signed min 70 days before previous sign on
                       OR DOCA.[FK Document ID]=SO.[Current Service Record ID] --Policy linked as attachment to current service
                       OR DOCA.[FK Document ID]=[Service Record ID Before OB MOVE]-- Policy linked as attachment to previous service 

--Final select of all onboard crew. Crew that has no single signed policy is marked as missing policy
SELECT DISTINCT
[Policy Status]=COALESCE([Policy Status],'Missing'),
SO.[Crew ID],
SO.[Mobilisation Cell ID]

into #docpolicy
FROM #OnboardCrew1 SO
LEFT JOIN #SignedPolicies SP ON SP.[Crew ID]=SO.[Crew ID]

-------------------------------------
INSERT INTO [ShipMgmt_Crewing].[tCrewMobilisationScorecard] (

[Date],
[Mobilisation Cell ID],
[Mobilisation Cell],
[Training Needs Completed],
[Total Training Needs],
[Digital Checklist Signed Off],
[Digital Checklist Joiners],
[Documents Uploaded by Seafarer],
[Total Documents Uploaded],
[Ready Status Updated On Time],
[Mobilisation Reliability Joiners],
[Pre Joining Compliance Statutory Compliant Crew],
[Pre Joining Compliance Statutory Onboard Crew],
[Pre Joining Compliance VMS Compliant Crew],
[Pre Joining Compliance VMS Onboard Crew],
[Declaration of Compliance Signed Pre Joining],
[Crew Onboard Pre Joining Declaration of Compliance],
[Crew Approved To Join Accepted By Mobilisation On Time],
[Crew Approved To Join],
[Crew Debriefing Done On Time],
[Crew Debriefing Offsigners],
[Timely Relieved Ratings],
[Ratings Onboard],
[Crew With Appraisal Review Completion On Time],
[Crew Appraisal Offsigners])

----------------------------
-- Begin

SELECT DISTINCT
	GETDATE() AS [Date],
	MOB.[Crew Pool ID] as [Mobilisation Cell ID],
	mob.[Crew Pool] as [Mobilisation Cell],
	[Training Needs Completed] = (SELECT sum(tn.completed_tn)
									FROM #trainingneeds tn
									WHERE tn.[Mobilisation Cell] NOT IN ('TPA_Aboitiz_Jebsen', 'TPA_DGS', 'TPA_Uniteam', 'TPA_Uniteam_NRS_fleet_Mob')
									AND	tn.[Mobilisation Cell] = mob.[Crew Pool]
								  ),

	[Total Training Needs] = (SELECT sum(tn.completed_tn) + sum(tn.pending_tn)
									FROM #trainingneeds tn
									WHERE tn.[Mobilisation Cell] NOT IN ('TPA_Aboitiz_Jebsen', 'TPA_DGS', 'TPA_Uniteam', 'TPA_Uniteam_NRS_fleet_Mob')
									AND	tn.[Mobilisation Cell] = mob.[Crew Pool]
								  ),

	[Digital Checklist Signed Off] = (SELECT count(DISTINCT MCH.[Crew ID]) 
										FROM #MCH MCH
										WHERE MCH.[Mobilisation Cell ID] = Mob.[Crew Pool ID]
										AND MCH.[Mob Checklist ID] is not NULL
										),

	[Digital Checklist Joiners] = (SELECT count(DISTINCT MCH.[Crew ID]) 
										FROM #MCH MCH
										WHERE	MCH.[Mobilisation Cell ID] = Mob.[Crew Pool ID]),

	[Documents Uploaded by Seafarer] = (Select count(distinct AD.[Document ID])
							from #tmpdocsfinal AD
							WHERE AD.[Uploaded By Unit] = 'Seafarer'
							AND AD.DocumentScopeFinal = 'IN SCOPE'
							AND AD.[Mobilisation Cell ID] = Mob.[Crew Pool ID]),

	[Total Documents Uploaded] = (Select count(distinct AD.[Document ID])
							from #tmpdocsfinal AD
							WHERE AD.DocumentScopeFinal = 'IN SCOPE'
							AND AD.[Mobilisation Cell ID] = Mob.[Crew Pool ID]),

	[Ready Status Updated On Time] = (SELECT COUNT(DISTINCT mb.[Crew ID])
										FROM #Mobrel mb
										WHERE mb.[Mobilisation Cell ID] = mob.[Crew Pool ID]
										AND mb.Compliance = 'Compliant'),
										
	[Mobilisation Reliability Joiners] = (SELECT COUNT(DISTINCT mb.[Crew ID])
										FROM #Mobrel mb
										WHERE mb.[Mobilisation Cell ID] = mob.[Crew Pool ID]),

	[Pre Joining Compliance Statutory Compliant Crew] = (Select count(distinct PJ.[Crew ID])
														from #pre_joining_comp PJ
														WHERE CAST(pj.[Statutory Non Compliant Documents] AS INT) = 0
														AND	PJ.[Mobilisation Cell ID] = Mob.[Crew Pool ID]),

	[Pre Joining Compliance Statutory Onboard Crew] = (Select count(distinct PJ.[Crew ID])
														from #pre_joining_comp PJ
														WHERE PJ.[Mobilisation Cell ID] = Mob.[Crew Pool ID]),

	[Pre Joining Compliance VMS Compliant Crew] = (Select count(distinct PJ.[Crew ID])
														from #pre_joining_comp PJ
														WHERE cast(pj.[VMS Non Compliant Documents] AS INT) = 0
														AND PJ.[Mobilisation Cell ID] = Mob.[Crew Pool ID]),

	[Pre Joining Compliance VMS Onboard Crew] = (Select count(distinct PJ.[Crew ID])
														from #pre_joining_comp PJ
														WHERE PJ.[Mobilisation Cell ID] = Mob.[Crew Pool ID]),

	[Declaration of Compliance Signed Pre Joining] = (Select count(distinct doc.[Crew ID])
														from #docpolicy doc
														where doc.[Policy Status] = 'Signed'
														and doc.[Mobilisation Cell ID] = Mob.[Crew Pool ID]),
	[Crew Onboard Pre Joining Declaration of Compliance] = (Select count(distinct doc.[Crew ID])
														from #docpolicy doc
														where doc.[Mobilisation Cell ID] = Mob.[Crew Pool ID]),

	[Crew Approved To Join Accepted By Mobilisation On Time] = (Select count(distinct macp.[Crew ID]) 
																	from #MobAcp macp
																WHERE macp.weekdaysbetween >= -2
																AND macp.RN_ApprovedOn = 1
																AND macp.[Mobilisation Cell ID] = MOB.[Crew Pool ID]),

	[Crew Approved To Join] = (Select count(distinct macp.[Crew ID]) 
								from #MobAcp macp
								WHERE macp.RN_ApprovedOn = 1
								AND macp.[Mobilisation Cell ID] = MOB.[Crew Pool ID]),

	[Crew Debriefing Done On Time] = (SELECT COUNT(DISTINCT CDB.[Crew ID]) 
										FROM #CDB CDB
										WHERE CDB.[Compliance] = 1
										AND CDB.[Mobilisation Cell ID] = MOB.[Crew Pool ID]),

	[Crew Debriefing Offsigners] = (SELECT COUNT(DISTINCT CDB.[Crew ID]) 
										FROM #CDB CDB
										WHERE CDB.[Mobilisation Cell ID] = MOB.[Crew Pool ID]),

	[Timely Relieved Ratings] = (Select count(distinct ov.[Crew ID])
									from #ontimerelief OV
									WHERE ov.[Timely Relief Org Contract] = 'Timely Relieved'
									AND ov.[Planning Cell] = mob.[Crew Pool]),
	[Ratings Onboard] = (Select count(distinct ov.[Crew ID])
									from #ontimerelief OV
									WHERE ov.[Planning Cell] = mob.[Crew Pool]),

	[Crew With Appraisal Review Completion On Time] = (SELECT COUNT(DISTINCT APPR.[Crew ID Appraisee])
														FROM #CRWAPPR APPR
														WHERE Appr.RN = 1
														AND appr.[Days To Review] <= 15
														AND appr.[Mobilisation Cell ID] = mob.[Crew Pool ID]),
	[Crew Appraisal Offsigners] = (SELECT COUNT(DISTINCT APPR.[Crew ID Appraisee])
														FROM #CRWAPPR APPR
														WHERE Appr.RN = 1
														AND appr.[Mobilisation Cell ID] = mob.[Crew Pool ID])

FROM [ShipMgmt_Crewing].[tCrewPool] MOB
WHERE MOB.[Crew Pool Type ID] = 1
AND Mob.[Is Active] = 1
AND mob.[Crew Pool ID] <> 'VGR400000297' --not romania


END