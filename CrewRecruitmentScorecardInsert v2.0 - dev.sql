---------------------------------------
--Created By: Tiffany Torres
--Purpose: Summarized Table for Recruitment Team's scorecard for 2025
--Modified On:  29/03/2025, 29/05/2025
---------------------------------------

ALTER PROCEDURE [ShipMgmt_Crewing].[CrewRecruitmentScorecardInsert]
(
@DateFromPipeline DATETIME
)

AS 

BEGIN

DECLARE @Date DATE = CAST(@DateFromPipeline AS DATE);

--DECLARE @Date DATE = CAST(GETDATE() AS DATE);

IF OBJECT_ID('tempdb.dbo.#RecCells') IS NOT NULL
  DROP TABLE #RecCells;

IF OBJECT_ID('tempdb.dbo.#Recruitments') IS NOT NULL
  DROP TABLE #Recruitments;

IF OBJECT_ID('tempdb.dbo.#tmpcrw') IS NOT NULL
  DROP TABLE #tmpcrw;

IF OBJECT_ID('tempdb.dbo.#newhires') IS NOT NULL
  DROP TABLE #newhires;

IF OBJECT_ID('tempdb.dbo.#interview') IS NOT NULL
  DROP TABLE #interview;

IF OBJECT_ID('tempdb.dbo.#RankBeforeRejoining') IS NOT NULL
  DROP TABLE #RankBeforeRejoining;
  
IF OBJECT_ID('tempdb.dbo.#assessmentcomp') IS NOT NULL
  DROP TABLE #assessmentcomp;

IF OBJECT_ID('tempdb.dbo.#Candidates') IS NOT NULL
  DROP TABLE #Candidates;

IF OBJECT_ID('tempdb.dbo.#logs') IS NOT NULL
  DROP TABLE #logs;

IF OBJECT_ID('tempdb.dbo.#nulogs2') IS NOT NULL
  DROP TABLE #nulogs2;
 
IF OBJECT_ID('tempdb.dbo.#UrgentFulfillment') IS NOT NULL
  DROP TABLE #UrgentFulfillment;

IF OBJECT_ID('tempdb.dbo.#NonUrgentFulfillment') IS NOT NULL
  DROP TABLE #NonUrgentFulfillment;

IF OBJECT_ID('tempdb.dbo.#NewHiresDigi') IS NOT NULL
  DROP TABLE #NewHiresDigi;

IF OBJECT_ID('tempdb.dbo.#NewHiresDocs') IS NOT NULL
  DROP TABLE #NewHiresDocs;

IF OBJECT_ID('tempdb.dbo.#Recruitments2') IS NOT NULL
  DROP TABLE #Recruitments2;

IF OBJECT_ID('tempdb.dbo.#tmpcrw2') IS NOT NULL
  DROP TABLE #tmpcrw2;

IF OBJECT_ID('tempdb.dbo.#endorseddateforcrewwhojoined') IS NOT NULL
  DROP TABLE #endorseddateforcrewwhojoined;

IF OBJECT_ID('tempdb.dbo.#joinedendorsedratio') IS NOT NULL
  DROP TABLE #joinedendorsedratio;

IF OBJECT_ID('tempdb.dbo.#Candidates2') IS NOT NULL
  DROP TABLE #Candidates2;

IF OBJECT_ID('tempdb.dbo.#logs2') IS NOT NULL
  DROP TABLE #logs2;

IF OBJECT_ID('tempdb.dbo.#ApprovedCan') IS NOT NULL
  DROP TABLE #ApprovedCan;

 IF OBJECT_ID('tempdb.dbo.#EndorsedCan') IS NOT NULL
  DROP TABLE #EndorsedCan;

 IF OBJECT_ID('tempdb.dbo.#ApprovedEndorsedRatio') IS NOT NULL
  DROP TABLE #ApprovedEndorsedRatio;

 IF OBJECT_ID('tempdb.dbo.#TCS') IS NOT NULL
  DROP TABLE #TCS;
-----------------------------------------------------
-- Main Table For Recruitment Cells
SELECT 
	RecCells.*
INTO
	#RecCells
FROM (

	SELECT

		rec.[Crew Pool ID],
		rec.[Crew Pool] as [Recruitment Cell]

	FROM  
		[ShipMgmt_Crewing].[tCrewPool] REC
	WHERE 
		REC.[Crew Pool Type ID] = 6
		AND REC.[Is Active] = 1

	UNION

	Select 
		'UNKNOWN' as [Crew Pool ID],
		'UNKNOWN' as [Recruitment Cell] 

) RecCells
-----------------------------------------------------
--Modified By: Tiffany torres
--Modified On: 29/03/2025
--Purpose: Recruitment Cells that are null is assigned to UNKNOWN value
-----------------------------------------------------
---------------------------------------
--Modified By: Tiffany Torres
--Purpose: Only exclude offshore basis the recruitment cells
--Modified On:  28/05/2025
---------------------------------------

-- Recruitment Quality - Assessment Passed/Failed

--into recruitment request and candidates
SELECT
	 rr.[Crew ID]
	,CRW.[Vessel ID]
	,VMD.[Vessel]
	,VVD.[Vessel Mgmt Type] as [Mgmt Type]
	,VMD.[Vessel Type]
	,VMD.[Vessel Business] as [Segment],
	DENSE_RANK() OVER (
	PARTITION BY rr.[Crew ID]
	ORDER BY RR.[Request Candidate Created On] asc) LV

INTO 
	#Recruitments
FROM 
	[ShipMgmt_Crewing].[tCrewRecruitmentRequestCandidate]  RR
	INNER JOIN [ShipMgmt_Crewing].[tCrewRecruitmentRequest] CRW ON CRW.[Request ID] = RR.[Request ID] -- to connect the candidates to the requisition request raised
	LEFT JOIN [ShipMgmt_VesselMgmt].[tShipMgmtRecords] VVD ON VVD.[Vessel ID] = CRW.[Vessel ID] and VVD.[Mgmt End] IS NULL -- to get vessel mgmt type
	LEFT JOIN [Reference_Vessel].[tVessel] VMD (NOLOCK) ON VMD.[Vessel ID] = CRW.[Vessel ID] -- to get vessel name and type

WHERE 
	RR.[Crew ID] IS NOT NULL
	AND crw.[Request Status] <> 'Cancelled' -- only active requests

-- into recruitment tracking
SELECT  
	 CRT.[Crew ID]
	,SR.[Rank ID Budgeted]
	,CRT.[Recruitment Tracking ID]
	,ISNULL(CRT.[Recruitment Tracking Recruitment Cell ID], 'UNKNOWN') as [Recruitment Cell ID]
	,CRT.[Recruitment Tracking Status]
	,SRR.[Status] AS CURRENT_STATUS
	,CRT.[Recruitment Tracking Start Date]
	,COALESCE(VMD.[Vessel Name], RRD.VESSEL) as VESSEL
	,COALESCE(VMD.[Vessel Mgmt Type],RRD.[Mgmt Type]) as [Management Type]
	,COALESCE(VV.[Vessel Type] , RRD.[VESSEL TYPE]) AS [Vessel Type]
	,COALESCE(VV.[Vessel Business], RRD.Segment) AS [Segment]
	,CD.[Crew Details Log ID]
	,CD.[Crew Details Log Old Value]
	,CD.[Crew Details Log New Value]
	,CD.[Crew Details Log Created On]
	,SR.[Start Date] as [Joining Date]
	,toff.[Office Name] as [Technical Office]

INTO 
	#tmpcrw
FROM  
	[ShipMgmt_Crewing].[tCrewRecruitmentTracking] CRT (NOLOCK)
	LEFT JOIN [ShipMgmt_Crewing].[tCrewServiceRecords] SR (NOLOCK) on SR.[Service Record ID] = CRT.[Crew Service Record ID] AND SR.[Service Cancelled] = 0 -- to get actual joning date
	LEFT JOIN [ShipMgmt_VesselMgmt].[tShipMgmtRecords] VMD (NOLOCK) ON VMD.[Vessel Mgmt ID] = SR.[Vessel Mgmt ID] -- to get vessel mgmt type
	LEFT JOIN [ShipMgmt_VesselMgmt].[tShipMgmtRecordsOffices] toff on toff.[vessel Mgmt ID] = SR.[Vessel Mgmt ID] and toff.[Office Type] = 'Technical Office' and toff.[Valid To] is null
	LEFT JOIN [Reference_Vessel].[tVessel]  VV (NOLOCK) ON VV.[Vessel ID] = SR.[Vessel ID] -- to get vessel name and type
	INNER JOIN [ShipMgmt_Crewing].[tCrewServiceRecords] SRR (NOLOCK) on SRR.[Crew ID] = CRT.[Crew ID] AND SRR.[Service Cancelled]=0 AND SRR.[Active Status] = 1 AND SRR.[Service Active Status ID] NOT IN (0,3) -- to get current status of crew
	LEFT JOIN [ShipMgmt_Crewing].[tCrewDetailsChangeLogRecruitmentTracking] CD (NOLOCK) ON CD.[FK Matched ID] = CRT.[Recruitment Tracking ID]
	LEFT JOIN #Recruitments RRD ON RRD.[Crew ID] = CRT.[Crew ID] AND RRD.LV=1

WHERE 
	CAST(CD.[Crew Details Log Created On] as DATE) BETWEEN DATEADD(day,-120,@Date) AND @Date -- Log date is in last 120 days

-----------------------------------------------------
--Modified By: Tiffany Torres
--Modified On: 26/03/2025
--Purpose: Rejoiners on the same rank has been excluded, Cargo vessels that are mapped to Offshore offices has been excluded, Recruitment Cells that are blank are assigned to UNKNOWN
-----------------------------------------------------
-----------------------------------------------------
--Modified By: Tiffany Torres
--Modified On: 02/06/2025
--Purpose: Rejoiners who joined on lower Ranks where excluded, Crew on externally managed vessels where excluded
-----------------------------------------------------
-- Assessment Compliance

-- Getting New Hired Crew
SELECT
	NH.[Crew ID],
	RNK.[Rank],
	NH.[Rank ID],
	ISNULL(PD.[Recruitment Cell ID], 'UNKNOWN') as [Recruitment Cell ID],
	[Rank Sequence] = CASE WHEN RNK.[Rank Category] IN ('Senior Officers',  'Offshore Officers', 'Officers') THEN '0' + cast(RNK.[Rank Sequence] AS VARCHAR(20))
					  ELSE '1' + cast(RNK.[Rank Sequence] AS VARCHAR(20)) END,
	RNK.[Rank Category],
	NH.[Service Record ID],
	VV.[Mgmt Type],
	VV.[Vessel Business],
	NH.[Rejoined],
	nh.[Event Date],
	vv.[Technical Office],
	vv.[Is Externally Managed]

INTO 
	#newhires
FROM 
	[ShipMgmt_Crewing].[tNewHiresAndPromotions] NH
	LEFT JOIN [ShipMgmt_Crewing].[tCrewRanks] RNK ON RNK.[Rank ID] = NH.[Rank ID]
	LEFT JOIN [ShipMgmt_VesselMgmt].[tVesselMetricsPerDayNew] VV ON VV.[Vessel ID] = NH.[Vessel ID] AND VV.[Date] = CAST(NH.[Event Date] AS DATE)
	LEFT JOIN [ShipMgmt_Crewing].[tCrew] PD ON PD.[Crew ID] = NH.[Crew ID]
WHERE 
	NH.[Event] = 'New Hire'
	AND CAST(NH.[Event Date] AS DATE) BETWEEN DATEADD(day,-30,@Date) AND @Date -- new hires in the last 30 days
	AND (PD.[Recruitment Cell ID] IS NULL OR PD.[Recruitment Cell ID] <> 'VGR400000298') -- Is not Brazil Recruitment cell // exclusion

-- Getting interviews (#CRW03)
SELECT
	IND.[Interview ID],
	IND.[Crew ID],
	RNK.[Rank],
	IND.[Interview for Rank ID],
	[Rank Sequence for Interview] = CASE WHEN RNK.[Rank Category] IN ('Senior Officers',  'Offshore Officers', 'Officers') THEN '0' + CAST(RNK.[Rank Sequence] AS VARCHAR(20))
					  ELSE '1' + CAST(RNK.[Rank Sequence] AS VARCHAR(20)) END,
	CAST(IND.[Interview Created On] AS DATE) [Interview Created On]

INTO 
	#interview
FROM
	[ShipMgmt_Crewing].[tCrewInterviewDetails] IND
	LEFT JOIN [ShipMgmt_Crewing].[tCrewRanks] RNK ON RNK.[Rank ID] = IND.[Interview for Rank ID]
WHERE 
	IND.[Interview Outcome] = 'Successful'
	--AND (IND.[Interview Type] IS NULL OR IND.[Interview Type] = 'New Hire')

--Getting Rank Before Joining
SELECT
	nh.[Crew ID],
	sd.[Service Record ID],
	[Start Date],
	sd.[Rank ID],
	[Rank Sequence] = CASE WHEN RNK2.[Rank Category] IN ('Senior Officers',  'Offshore Officers', 'Officers') THEN '0' + CAST(RNK2.[Rank Sequence] AS VARCHAR(20))
					  ELSE '1' + CAST(RNK2.[Rank Sequence] AS VARCHAR(20)) END,
	sd.[Rank],
	DENSE_RANK() OVER ( PARTITION BY nh.[Crew ID] ORDER BY sd.[Start date] desc) RN
INTO
	#RankBeforeRejoining
FROM 
	[ShipMgmt_Crewing].[tCrewServiceRecords] sd
	INNER JOIN #newhires nh on nh.[Crew ID] = sd.[Crew ID] and nh.[Rejoined] = 1
	LEFT JOIN [ShipMgmt_Crewing].[tCrewRanks] RNK2 on rnk2.[Rank ID] = sd.[Rank ID] -- to get rank sequence
WHERE 
	sd.[Start Date] < nh.[Event Date]
	AND sd.[Status ID] = 'OB' --onboard services only
	AND sd.[Service Cancelled] = 0 -- not cancelled
	AND sd.[Service Active Status ID] = 2 --only historical ob records
	AND sd.[Previous Experience] = 0 --not previous experience

--combine
SELECT
	NHO.*,
	INH.[Rank] AS [Rank for Interview],
	INH.[Interview for Rank ID],
	INH.[Rank Sequence for Interview],
	rbj.[Rank ID] as [Rank Before Rejoining],
	rbj.[Rank] as [Rank Before Rejoining Description],
	rbj.[Rank Sequence] as [Rank Sequence Before Joining],
	[Compliance] = CASE 
				   WHEN INH.[Rank Sequence for Interview] <= NHO.[Rank Sequence] THEN 'COMPLIANT'
				   WHEN NHO.[Rank] = RNK.[Equivalent Rank] THEN 'COMPLIANT'
				   ELSE 'NON-COMPLIANT' END,
	CASE 
		WHEN rbj.[Rank ID] = nho.[Rank ID] THEN 'Exclude' 
		WHEN rbj.[Rank Sequence] <= NHO.[Rank Sequence] THEN 'Exclude'
		WHEN rnk3.[Equivalent Rank ID] = nho.[Rank ID] THEN 'Exclude' 
		ELSE 'Include' END AS [For Exclusion]
INTO 
	#assessmentcomp		   
FROM 
	#newhires NHO
	OUTER APPLY (SELECT TOP (1) [IN].*
				 FROM 
					#interview [IN] 
				 WHERE 
					[IN].[Crew ID] = NHO.[Crew ID]
				 ORDER BY 
					[IN].[Interview Created On] DESC) INH
	LEFT JOIN [ShipMgmt_Crewing].[tCrewRanks] RNK ON RNK.[Rank ID] = INH.[Interview for Rank ID]
	LEFT JOIN #RankBeforeRejoining rbj on rbj.[Crew ID] = nho.[Crew ID] and rbj.RN = 1 --only get service prior to rejoining to know which rank they were before
	LEFT JOIN [ShipMgmt_Crewing].[tCrewRanks] rnk3 ON RNK3.[Rank ID] = rbj.[Rank ID]
ORDER BY 
	NHO.[Crew ID] ASC

-----------------------------------------------------
--Modified By: Tiffany Torres
--Modified On: 29/03/2025
--Purpose: Changed logic to identify which RT Logs are for a specific RR
-----------------------------------------------------
-----------------------------------------------------
--Modified By: Tiffany Torres
--Modified On: 29/05/2025
--Purpose: Added RRs where no candidates have been delivered, Removed Leisure Vessels RRs
-----------------------------------------------------
-- urgent fulfillment request

/*SELECT *
INTO 
	#UrgentRR

FROM (
	SELECT
		 RR.[Crew ID]
		,CRW.[Request ID]
		,CRW.[Request Created On]
		,CRW.[Join Date]
		,CRW.[Vessel ID]
		,VMD.[Vessel]
		,VVD.[Vessel Mgmt Type] AS [Mgmt Type]
		,VMD.[Vessel Type]
		,VMD.[Vessel Business] AS [Segment],
		DENSE_RANK() OVER (
		PARTITION BY CRW.[Request ID]
		ORDER BY RR.[Request Candidate Created On] asc) LV

	FROM 
		[ShipMgmt_Crewing].[tCrewRecruitmentRequestCandidate]  RR
		INNER JOIN [ShipMgmt_Crewing].[tCrewRecruitmentRequest] CRW ON CRW.[Request ID] = RR.[Request ID]
		LEFT JOIN [ShipMgmt_VesselMgmt].[tShipMgmtRecords] VVD ON VVD.[Vessel ID] = CRW.[Vessel ID] AND VVD.[Mgmt End] IS NULL
		LEFT JOIN [Reference_Vessel].[tVessel] VMD (NOLOCK) ON VMD.[Vessel ID] = CRW.[Vessel ID]
	WHERE 
		RR.[Crew ID] IS NOT NULL
		AND CRW.[Request Status] <> 'Cancelled'
		AND cast(CRW.[Join Date] as date) BETWEEN DATEADD(DAY,-45,@date) AND CAST(@date AS DATE)) RR -- only the requests with joining date in the last 45 days
WHERE 
	RR.LV = 1

-- into recruitment tracking
SELECT LOGS.*
into #UrgentFulfillment
FROM (
	SELECT  
		 CRT.[Crew ID]
		,URR.[Request ID]
		,ISNULL(CRT.[Recruitment Tracking Recruitment Cell ID], 'UNKNOWN') as [Recruitment Cell ID]
		,CRT.[Recruitment Tracking Status]
		,SRR.[Status] AS CURRENT_STATUS
		,CRT.[Recruitment Tracking Start Date]
		,COALESCE(VMD.[Vessel Name], URR.VESSEL) as VESSEL
		,COALESCE(VMD.[Vessel Mgmt Type],URR.[Mgmt Type]) as [Management Type]
		,COALESCE(VV.[Vessel Type] , URR.[VESSEL TYPE]) AS [Vessel Type]
		,COALESCE(VV.[Vessel Business], URR.Segment) AS [Segment]
		,CD.[Crew Details Log ID]
		,CD.[Crew Details Log Old Value]
		,CD.[Crew Details Log New Value]
		,CD.[Crew Details Log Created On]
		,URR.[Request Created On]
		,URR.[Join Date]
		,DATEDIFF(WK, CAST(URR.[Request Created On] as date), CAST(URR.[Join Date] as date)) as [# of Weeks]

	FROM  
		[ShipMgmt_Crewing].[tCrewRecruitmentTracking] CRT (NOLOCK)
		LEFT JOIN [ShipMgmt_Crewing].[tCrewServiceRecords] SR (NOLOCK) ON SR.[Service Record ID] = CRT.[Crew Service Record ID] AND SR.[Service Cancelled] = 0
		LEFT JOIN [ShipMgmt_VesselMgmt].[tShipMgmtRecords] VMD (NOLOCK) ON VMD.[Vessel Mgmt ID] = SR.[Vessel Mgmt ID]
		LEFt JOIN [Reference_Vessel].[tVessel]  VV (NOLOCK) ON VV.[Vessel ID] = SR.[Vessel ID]
		INNER JOIN [ShipMgmt_Crewing].[tCrewServiceRecords] SRR (NOLOCK) ON SRR.[Crew ID] = CRT.[Crew ID] AND SRR.[Service Cancelled]=0 AND SRR.[Active Status] = 1 AND SRR.[Service Active Status ID] NOT IN (0,3)
		LEFT JOIN [ShipMgmt_Crewing].[tCrewDetailsChangeLogRecruitmentTracking] CD (NOLOCK) ON CD.[FK Matched ID] = CRT.[Recruitment Tracking ID]
		LEFT JOIN #UrgentRR urr ON URR.[Crew ID] = CRT.[Crew ID]
	WHERE  
		CD.[Crew Details Log New Value] = 'Accepted')  LOGS
WHERE 
	LOGS.[Crew Details Log Created On] >= LOGS.[Request Created On] -- log date must be > Date the request was Raised
	AND [# of Weeks] < 3 -- Critical Requests are when the # of Weeks Between it was raised and Joining Date is < 3*/

SELECT
	 ISNULL(LAG(rr.[Date Received]) OVER(PARTITION BY cc.[Crew ID] ORDER BY rr.[Date Received] DESC), cast(GETDATE() as date)) AS [Next RR Endorsed To],
	rr.[Request ID] as [RR Request ID], 
	rr.[Date Received], 
	rr.[Join Date],
	rr.[Vessel ID],
	vv.[Vessel Business],
	rr.[Request Status],
	rr.[Recruitment Cell],
	cc.*
INTO
	#Candidates
FROM 
	[ShipMgmt_Crewing].[tCrewRecruitmentRequest] rr
	left join [ShipMgmt_Crewing].[tCrewRecruitmentRequestCandidate] cc  on cc.[Request ID] = rr.[Request ID]
	LEFT JOIN [Reference_Vessel].[tVessel] VV ON VV.[Vessel ID] = rr.[Vessel ID]
WHERE 
	rr.[Request Status] <> 'Cancelled'
	and vv.[Vessel Business] <> 'Passenger/Ferry'

-- Getting all Logs for each crew processed in Recruitment Trackin

SELECT
	rtl.*, rt.[Recruitment Tracking Recruitment Cell ID]
INTO 
	#logs
FROM 
	[ShipMgmt_Crewing].[tCrewDetailsChangeLogRecruitmentTracking] rtl
	left join [ShipMgmt_Crewing].[tCrewRecruitmentTracking] rt on rt.[recruitment tracking id] = rtl.[fk matched id]
where 
	rt.[Is Recruitment Tracking Deleted] = 0
	and rtl.[Crew Details Log New Value] = 'Accepted'

-- Combine, Connection using dates between the next endorsement date
SELECT *
INTO 
	#UrgentFulfillment
FROM (

	SELECT
		cc.[Date Received] as [RR Raised On],
		cc.[Next RR Endorsed To],
		--cc.[Request Candidate Created On],
		cc.[Vessel Business],
		cc.[Request Status],
		cc.[Join Date],
		DATEDIFF(WK, CAST(cc.[Date Received] as date), CAST(cc.[Join Date] as date)) as [# of Weeks],
		cc.[Vessel ID],
		cc.[RR Request ID],
		cc.[Crew ID],
		ISNULL(CC.[Recruitment Cell], 'UNKNOWN') as [Recruitment Cell],
		--ISNULL(ll.[Recruitment Tracking Recruitment Cell ID], 'UNKNOWN') as [Recruitment Cell ID],
		ll.[Crew Details Log Created On],
		ll.[Crew Details Log Old Value],
		ll.[Crew Details Log New Value],
		CASE WHEN cast(ll.[Crew Details Log Created On] as date) <= cast(cc.[Join Date] as date) THEN 'Compliant' ELSE 'Non-Compliant' END AS [Compliance],
		DENSE_RANK() OVER ( PARTITION BY  cc.[RR Request ID] ORDER BY ll.[Crew Details Log Created On] ASC) RN

	FROM 
		#candidates cc
		left join #logs ll on ll.[crew id] = cc.[Crew ID] and ll.[Crew Details Log Created On] BETWEEN cc.[Date Received] AND cc.[Next RR Endorsed To] --connect by crew ID and only get logs where the log dates are in between the RR Endorsement dates

	WHERE
		--(ll.[Crew Details Log New Value] is null or ll.[Crew Details Log New Value] = 'Accepted')
		 DATEDIFF(dd, CAST(cc.[Date Received] as date), CAST(cc.[Join Date] as date)) < 21 --only when difference between dates is less than 21 days	
		AND cast(cc.[Join Date] as date) BETWEEN DATEADD(DAY,-45,@date) AND CAST(@date AS DATE) --only RRs where joining date is in last 45 days
	--ORDER BY 
		--cc.[Request Created On], cc.[Crew ID], ll.[Crew Details Log Created On] ASC 
	) fin

WHERE fin.RN = 1

-----------------------------------------------------
--Modified By: Tiffany Torres
--Modified On: 29/03/2025
--Purpose: NULL Recruitment Cells are assigned to UNKNOWN value
-----------------------------------------------------
-----------------------------------------------------
--Modified By: Tiffany Torres
--Modified On: 29/05/2025
--Purpose: Added RRs where no candidates have been delivered, Removed Leisure Vessels RRs
-----------------------------------------------------
-- non-urgent fulfillment request

SELECT
	rtl.*, rt.[Recruitment Tracking Recruitment Cell ID]
INTO 
	#nulogs2
FROM 
	[ShipMgmt_Crewing].[tCrewDetailsChangeLogRecruitmentTracking] rtl
	left join [ShipMgmt_Crewing].[tCrewRecruitmentTracking] rt on rt.[recruitment tracking id] = rtl.[fk matched id]
where 
	rt.[Is Recruitment Tracking Deleted] = 0
	and rtl.[Crew Details Log New Value] = 'Endorsed Planned'

SELECT *, DATEDIFF(dd, fin2.[Crew Details Log Created On], fin2.[Join Date]) as [Days between endorsed planned and join date of RR],
CASE WHEN DATEDIFF(dd, fin2.[Crew Details Log Created On], fin2.[Join Date]) >= 10 THEN 'Compliant' ELSE 'Non-Compliant' END as [Compliance]

INTO 
	#NonUrgentFulfillment
FROM (

	SELECT
		cc.[Date Received] as [RR Raised On],
		cc.[Next RR Endorsed To],
		--cc.[Request Candidate Created On],
		cc.[Vessel Business],
		cc.[Request Status],
		cc.[Join Date],
		DATEDIFF(WK, CAST(cc.[Date Received] as date), CAST(cc.[Join Date] as date)) as [# of Weeks],
		cc.[Vessel ID],
		cc.[RR Request ID],
		cc.[Crew ID],
		ISNULL(CC.[Recruitment Cell], 'UNKNOWN') as [Recruitment Cell],
		ll.[Crew Details Log Created On],
		ll.[Crew Details Log Old Value],
		ll.[Crew Details Log New Value],
		DENSE_RANK() OVER ( PARTITION BY cc.[RR Request ID] ORDER BY ll.[Crew Details Log Created On] ASC) RN

	FROM 
		#candidates cc
		left join #nulogs2 ll on ll.[crew id] = cc.[Crew ID] and ll.[Crew Details Log Created On] BETWEEN cc.[Date Received] AND cc.[Next RR Endorsed To] --connect by crew ID and only get logs where the log dates are in between the RR Endorsement dates

	WHERE
		--(ll.[Crew Details Log New Value] is null or ll.[Crew Details Log New Value] = 'Endorsed Planned')
		DATEDIFF(dd, CAST(cc.[Date Received] as date), CAST(cc.[Join Date] as date)) >= 21 --only when difference between dates is more than 21 days
		AND cast(cc.[Join Date] as date) BETWEEN DATEADD(DAY,-90,@date) AND CAST(@date AS DATE) --only RRs where joining date is in last 45 days
	--ORDER BY 
		--cc.[Request Created On], cc.[Crew ID], ll.[Crew Details Log Created On] ASC 
	) fin2

WHERE fin2.RN = 1

-----------------------------------------------------
--Created by: Tiffany Torres
--Created On: 31/03/2025
--Purpose: Approved / Endorsed Ratio
-----------------------------------------------------
SELECT
	 ISNULL(LAG(rr.[Date Received]) OVER(PARTITION BY cc.[Crew ID] ORDER BY rr.[Date Received] DESC), cast(GETDATE() as date)) AS [Next RR Endorsed To],
	rr.[Request ID] as [RR Request ID], 
	rr.[Date Received], 
	rr.[Join Date],
	rr.[Vessel ID],
	rr.[Request Updated On],
	cc.*
INTO
	#Candidates2
FROM 
	[ShipMgmt_Crewing].[tCrewRecruitmentRequestCandidate] cc
	left join [ShipMgmt_Crewing].[tCrewRecruitmentRequest] rr on rr.[Request ID] = cc.[Request ID]
WHERE 
	rr.[Request Status] = 'Completed'
	and cast(rr.[Request Updated On] as date) BETWEEN DATEADD(DAY,-30,@date) AND CAST(@date AS DATE) --only RRs that are closed out in the last 30 days

-- Getting all Logs for each crew processed in Recruitment Tracking
SELECT
	rtl.*, rt.[Recruitment Tracking Recruitment Cell ID]
INTO 
	#logs2
FROM 
	[ShipMgmt_Crewing].[tCrewDetailsChangeLogRecruitmentTracking] rtl
	left join [ShipMgmt_Crewing].[tCrewRecruitmentTracking] rt on rt.[recruitment tracking id] = rtl.[fk matched id]
where 
	rt.[Is Recruitment Tracking Deleted] = 0

-- Combine, Connection using dates between the next endorsement date
SELECT *
INTO 
	#ApprovedCan
FROM (

	SELECT
		cc.[RR Request ID],
		cc.[Request Updated On] as [RR Closed On],
		cc.[Date Received] as [RR Raised On],
		cc.[Request Updated On],
		cc.[Next RR Endorsed To],
		cc.[Join Date],
		cc.[Vessel ID],
		cc.[Request ID],
		cc.[Crew ID],
		ISNULL(ll.[Recruitment Tracking Recruitment Cell ID], 'UNKNOWN') as [Recruitment Cell ID],
		ll.[Crew Details Log Created On],
		ll.[Crew Details Log Old Value],
		ll.[Crew Details Log New Value],
		DENSE_RANK() OVER ( PARTITION BY  cc.[request id] ORDER BY ll.[Crew Details Log Created On] ASC) RN

	FROM 
		#candidates2 cc
		left join #logs2 ll on ll.[crew id] = cc.[Crew ID] and ll.[Crew Details Log Created On] BETWEEN cc.[Date Received] AND cc.[Next RR Endorsed To] --connect by crew ID and only get logs where the log dates are in between the RR Endorsement dates

	WHERE
		ll.[Crew Details Log New Value] = 'Accepted' --Accepted and Endorsed

	) fin2

--where fin2.[RN] = 1


SELECT *
INTO 
	#EndorsedCan
FROM (

	SELECT
		cc.[RR Request ID],
		cc.[Request Updated On] as [RR Closed On],
		cc.[Date Received] as [RR Raised On],
		cc.[Request Updated On],
		cc.[Next RR Endorsed To],
		cc.[Join Date],
		cc.[Vessel ID],
		cc.[Request ID],
		cc.[Crew ID],
		ISNULL(ll.[Recruitment Tracking Recruitment Cell ID], 'UNKNOWN') as [Recruitment Cell ID],
		ll.[Crew Details Log Created On],
		ll.[Crew Details Log Old Value],
		ll.[Crew Details Log New Value],
		DENSE_RANK() OVER ( PARTITION BY  cc.[request id] ORDER BY ll.[Crew Details Log Created On] ASC) RN

	FROM 
		#candidates2 cc
		left join #logs2 ll on ll.[crew id] = cc.[Crew ID] and ll.[Crew Details Log Created On] BETWEEN cc.[Date Received] AND cc.[Next RR Endorsed To] --connect by crew ID and only get logs where the log dates are in between the RR Endorsement dates

	WHERE
		ll.[Crew Details Log New Value] = 'Endorsed' --Accepted and Endorsed
	--ORDER BY 
		--cc.[Request Created On], cc.[Crew ID], ll.[Crew Details Log Created On] ASC 
	) fin3

--where fin3.[RN] = 1

Select *
into #approvedendorsedratio
from (

	Select * 
	from #ApprovedCan

	UNION

	Select * 
	from #EndorsedCan ) appendfin

-----------------------------------------------------
--Created by: Tiffany Torres
--Created On: 31/03/2025
--Purpose: Joined / Endorsed Ratio
-----------------------------------------------------
SELECT
	 rr.[Crew ID]
	,CRW.[Vessel ID]
	,VMD.[Vessel]
	,VVD.[Vessel Mgmt Type] as [Mgmt Type]
	,VMD.[Vessel Type]
	,VMD.[Vessel Business] as [Segment],
	DENSE_RANK() OVER (
	PARTITION BY rr.[Crew ID]
	ORDER BY RR.[Request Candidate Created On] asc) LV

INTO 
	#Recruitments2
FROM 
	[ShipMgmt_Crewing].[tCrewRecruitmentRequestCandidate]  RR
	INNER JOIN [ShipMgmt_Crewing].[tCrewRecruitmentRequest] CRW ON CRW.[Request ID] = RR.[Request ID] -- to connect the candidates to the requisition request raised
	LEFT JOIN [ShipMgmt_VesselMgmt].[tShipMgmtRecords] VVD ON VVD.[Vessel ID] = CRW.[Vessel ID] and VVD.[Mgmt End] IS NULL -- to get vessel mgmt type
	LEFT JOIN [Reference_Vessel].[tVessel] VMD (NOLOCK) ON VMD.[Vessel ID] = CRW.[Vessel ID] -- to get vessel name and type

WHERE 
	RR.[Crew ID] IS NOT NULL
	AND crw.[Request Status] <> 'Cancelled' -- only active requests

-- into recruitment tracking
SELECT  
	 CRT.[Crew ID]
	,CRT.[Recruitment Tracking ID]
	,ISNULL(CRT.[Recruitment Tracking Recruitment Cell ID], 'UNKNOWN') as [Recruitment Cell ID]
	,CRT.[Recruitment Tracking Status]
	,SRR.[Status] AS CURRENT_STATUS
	,CRT.[Recruitment Tracking Start Date]
	,COALESCE(VMD.[Vessel Name], RRD.VESSEL) as VESSEL
	,COALESCE(VMD.[Vessel Mgmt Type],RRD.[Mgmt Type]) as [Management Type]
	,COALESCE(VV.[Vessel Type] , RRD.[VESSEL TYPE]) AS [Vessel Type]
	,COALESCE(VV.[Vessel Business], RRD.Segment) AS [Segment]
	,CD.[Crew Details Log ID]
	,CD.[Crew Details Log Old Value]
	,CD.[Crew Details Log New Value]
	,CD.[Crew Details Log Created On]
	,SR.[Start Date] as [Joining Date]

INTO 
	#tmpcrw2
FROM  
	[ShipMgmt_Crewing].[tCrewRecruitmentTracking] CRT (NOLOCK)
	LEFT JOIN [ShipMgmt_Crewing].[tCrewServiceRecords] SR (NOLOCK) on SR.[Service Record ID] = CRT.[Crew Service Record ID] AND SR.[Service Cancelled] = 0 -- to get actual joning date
	LEFT JOIN [ShipMgmt_VesselMgmt].[tShipMgmtRecords] VMD (NOLOCK) ON VMD.[Vessel Mgmt ID] = SR.[Vessel Mgmt ID] -- to get vessel mgmt type
	LEFt JOIN [Reference_Vessel].[tVessel]  VV (NOLOCK) ON VV.[Vessel ID] = SR.[Vessel ID] -- to get vessel name and type
	INNER JOIN [ShipMgmt_Crewing].[tCrewServiceRecords] SRR (NOLOCK) on SRR.[Crew ID] = CRT.[Crew ID] AND SRR.[Service Cancelled]=0 AND SRR.[Active Status] = 1 AND SRR.[Service Active Status ID] NOT IN (0,3) -- to get current status of crew
	LEFT JOIN [ShipMgmt_Crewing].[tCrewDetailsChangeLogRecruitmentTracking] CD (NOLOCK) ON CD.[FK Matched ID] = CRT.[Recruitment Tracking ID]
	LEFT JOIN #Recruitments2 RRD ON RRD.[Crew ID] = CRT.[Crew ID] AND RRD.LV=1
WHERE
	YEAR(CAST(CD.[Crew Details Log Created On] as DATE)) = YEAR(@date) -- year to date activities
	AND crt.[Is Recruitment Tracking Deleted] = 0 --RT should not be deleted

--Endorsement Date of those crew above that had already joined
Select 
	crt.*,cd.[Crew Details Log New Value], cd.[Crew Details Log Created On] 
into 
	#endorseddateforcrewwhojoined
from 
	[ShipMgmt_Crewing].[tCrewRecruitmentTracking] crt
	LEFT JOIN [ShipMgmt_Crewing].[tCrewDetailsChangeLogRecruitmentTracking] CD (NOLOCK) ON CD.[FK Matched ID] = CRT.[Recruitment Tracking ID]
where 
	crt.[Is Recruitment Tracking Deleted] = 0 --RT should not be deleted
	and cd.[Crew Details Log New Value] = 'Endorsed'

--Final Select factoring the crew who joined in 2025 but endorsed on 2024 are excluded
Select distinct
	tmp.*, 
	CASE WHEN tmp.[Recruitment Tracking Status] = 'Joined' THEN endo.[Crew Details Log Created On] ELSE NULL END AS [Latest Endorsement Date for Crew who Joined]
into 
	#joinedendorsedratio
from 
	#tmpcrw2 tmp
	outer apply (select top (1) [Crew Details Log Created On]
				from #endorseddateforcrewwhojoined
				where [Crew ID] = tmp.[Crew ID]
				and [Recruitment Tracking ID] = tmp.[Recruitment Tracking ID]
				order by [Crew Details Log Created On] desc) endo
where 
	(endo.[Crew Details Log Created On] is null or case when tmp.[Recruitment Tracking Status] = 'Joined' and YEAR(endo.[Crew Details Log Created On]) <> YEAR(cast(GETDATE() as date)) then 0 else 1 end = 1) --removing all joiners where endorsed date is not in 2025
	and tmp.[Crew Details Log New Value] in ('Endorsed', 'Joined')

-----------------------------------------------------
--Modified By: Tiffany Torres
--Modified On: 29/03/2025
--Purpose: Recruitment Cells that are NULL assigned to UNKNOWN removed Ex V (those who have sailed in the past)
-----------------------------------------------------
-- New Comers Digitization

SELECT
	 TC.[Crew ID]
	,TC.[Recruitment Tracking Start Date]
	,ISNULL(TC.[Recruitment Cell ID], 'UNKNOWN') as [Recruitment Cell ID]
	,RTCD.[Crew Details Log Created On] AS [Approved On]

INTO
	#NewHiresDigi
FROM
	#tmpcrw TC
	LEFT JOIN [ShipMgmt_Crewing].[tCrewDetailsChangeLogRecruitmentTracking] RTCD ON RTCD.[FK Matched ID] = TC.[Recruitment Tracking ID] AND RTCD.[Crew Details Log New Value] = 'Accepted' -- To see the date they were approved
WHERE	
	TC.[Crew Details Log New Value] = 'Joined'
	AND CAST(TC.[Crew Details Log Created On] as DATE) BETWEEN DATEADD(day,-30,@Date) AND @Date

-- into services count

    SELECT
        [Crew ID],
        COUNT([Service Record ID]) AS [Vships Service Count]
	INTO #TCS
    FROM [ShipMgmt_Crewing].[tCrewServiceRecords]
    WHERE ([Service Active Status ID] IS NULL OR [Service Active Status ID] in (1,2)) 
        AND [Active Status] = 0 --SERVICES COMPLETED
        AND [Service Cancelled] = 0 
        AND [Previous Experience] = 0 --SERVICES IN COMPANY
        AND [Status ID] IN ('OB', 'OV')
        AND [Vessel ID] IS NOT NULL
    GROUP BY [Crew ID]

-- Into checking the # of docs they uploaded prioir approve status

SELECT
	NHD.[Crew ID],
	ISNULL(NHD.[Recruitment Cell ID], 'UNKNOWN') as [Recruitment Cell ID],
	COUNT(DISTINCT DOC.[FK Matched ID]) AS [Uploads],
	SUM(TCS.[Vships Service Count]) as [Vships Service Count]
INTO
	#NewHiresDocs
FROM 
	#NewHiresDigi NHD
	LEFT JOIN [ShipMgmt_Crewing].[tCrewCloudEntityScanned] DOC ON DOC.[Crew ID] = NHD.[Crew ID] AND (CAST(DOC.[Created On] as DATE) >= NHD.[Recruitment Tracking Start Date] AND CAST(DOC.[Created On] as DATE) <= [Approved On]) AND [Created By] = 'SEAFARER-API-USER'
	LEFT JOIN #TCS TCS ON TCS.[Crew ID] = NHD.[Crew ID]
GROUP BY
	NHD.[Crew ID],
	ISNULL(NHD.[Recruitment Cell ID], 'UNKNOWN')

-----------------------------------------------------
SELECT DISTINCT
	@Date AS [Record Inserted On],
	rec.[Crew Pool ID] as [Recruitment Cell ID],
	rec.[Recruitment Cell],
	[Endorsed Candidates] = (SELECT COUNT([Crew ID])
							FROM #approvedendorsedratio
								WHERE [Crew Details Log New Value] = 'Endorsed'
								AND [Recruitment Cell ID] = REC.[Crew Pool ID]),
	[Approved Candidates] = (SELECT COUNT([Crew ID])
							 FROM 
								#approvedendorsedratio
							 WHERE 
								[Crew Details Log New Value] = 'Accepted'
								AND [Recruitment Cell ID] = REC.[Crew Pool ID]),
	[New Hired Officers Compliant with CRW16] = (SELECT COUNT(DISTINCT crw03.[Crew ID]) 
												 FROM 
													#assessmentcomp crw03
												 WHERE 
													crw03.[Compliance] = 'COMPLIANT'
													AND crw03.[Rank Category] IN ('Senior Officers',  'Offshore Officers', 'Officers')
													AND crw03.[Mgmt Type] IN ('Full Management', 'Tech Mgmt')
													AND crw03.[Vessel Business] = 'Cargo'
													AND crw03.[For Exclusion] = 'Include'
													and (crw03.[Is Externally Managed] is null or crw03.[Is Externally Managed] = 0)
													AND (crw03.[Technical Office] is null or CASE WHEN crw03.[Technical Office] in ('Offshore Aberdeen', 'Offshore Singapore') THEN 1 else 0 END = 0) -- if technical office is offshore then exclude
													AND crw03.[Recruitment Cell ID] = REC.[Crew Pool ID]),

	[New Hired Officers] = (SELECT COUNT(DISTINCT crw03.[Crew ID]) 
							FROM 
								#assessmentcomp crw03
							WHERE 
								crw03.[Rank Category] IN ('Senior Officers',  'Offshore Officers', 'Officers')
								AND crw03.[Mgmt Type] IN ('Full Management', 'Tech Mgmt')
								AND crw03.[Vessel Business] = 'Cargo'
								AND crw03.[For Exclusion] = 'Include'
								and (crw03.[Is Externally Managed] is null or crw03.[Is Externally Managed] = 0)
								AND (crw03.[Technical Office] is null or CASE WHEN crw03.[Technical Office] in ('Offshore Aberdeen', 'Offshore Singapore') THEN 1 else 0 END = 0)
								AND crw03.[Recruitment Cell ID] = REC.[Crew Pool ID]),

	[New Hires Processed Via Recruitment Tracking] = (SELECT COUNT(DISTINCT nh.[Crew ID])
													  FROM 
														  #newhires (nolock) nh
														  LEFT JOIN [ShipMgmt_Crewing].[tCrewRecruitmentTracking] CRT ON crt.[Crew Service Record ID] = nh.[Service Record ID] AND CRT.[Is Recruitment Tracking Deleted] = 0 and CRT.[Recruitment Tracking Status ID] = 11
														  INNER JOIN [ShipMgmt_Crewing].[tCrew] CPD ON CPD.[Crew ID] = NH.[Crew ID]
														  LEFT JOIN [ShipMgmt_Crewing].[tCrewServiceRecords] SD ON sd.[Service Record ID] = nh.[Service Record ID]
													  WHERE
														  NH.[Mgmt Type]  IN ('Full Management', 'Tech Mgmt','Crew Mgmt')
														  AND Nh.[Vessel Business] IN ('Cargo', 'Offshore')
														  AND (nh.[Rejoined] IS NULL OR nh.[Rejoined] = 0)
														  AND crt.[Recruitment Tracking ID] IS NOT NULL
														  AND sd.[Service Cancelled] = 0
														  AND (cpd.[Crew Contract Type] IS NULL OR cpd.[Crew Contract Type] <> 'VSHP00000003') -- not TPA
														  AND (cpd.[Crew Contract Type] IS NULL OR cpd.[Crew Contract Type] <> 'VSHP00000002') -- or owner supplied
														  AND nh.[Recruitment Cell ID] = REC.[Crew Pool ID]),
	[New Hired Seafarers] = (SELECT COUNT(DISTINCT nh.[Crew ID])
							 FROM 
								#newhires nh
								INNER JOIN [ShipMgmt_Crewing].[tCrew] CPD ON CPD.[Crew ID] = NH.[Crew ID]
								LEFT JOIN [ShipMgmt_Crewing].[tCrewServiceRecords] SD ON sd.[Service Record ID] = nh.[Service Record ID]
							 WHERE
								NH.[Mgmt Type]  IN ('Full Management', 'Tech Mgmt','Crew Mgmt')
								AND Nh.[Vessel Business] IN ('Cargo', 'Offshore')
								AND (nh.[Rejoined] IS NULL OR nh.[Rejoined] = 0)
								AND sd.[Service Cancelled] = 0
								AND (cpd.[Crew Contract Type] IS NULL OR cpd.[Crew Contract Type] <> 'VSHP00000003') -- not TPA
								AND (cpd.[Crew Contract Type] IS NULL OR cpd.[Crew Contract Type] <> 'VSHP00000002') -- or owner supplied
								AND nh.[Recruitment Cell ID] = REC.[Crew Pool ID]),
	[Urgent Approved Candidates Before Start Date] = (SELECT COUNT(distinct [RR Request ID])
													  FROM 
														#UrgentFulfillment
													  WHERE 
														[Compliance] = 'Compliant'
														AND [Recruitment Cell] = REC.[Recruitment Cell]),
	[Urgent Recruitment Requests] = (SELECT COUNT( distinct [RR Request ID])
									 FROM 
										#UrgentFulfillment
									 WHERE
										[Recruitment Cell] = REC.[Recruitment Cell]),
	[Non Urgent Approved Candidates Before Start Date] = (SELECT COUNT(distinct [RR Request ID])
														  FROM
															#nonurgentfulfillment
														  WHERE 
															[Compliance] = 'Compliant'
															AND [Recruitment Cell] = REC.[Recruitment Cell]),
	[Non Urgent Recruitment Request] = (SELECT COUNT(distinct [RR Request ID])
										FROM 
											#nonurgentfulfillment
										WHERE
											[Recruitment Cell] = REC.[Recruitment Cell]),
	[New Hired Officers Who Passed Assessment] = (SELECT COUNT(DISTINCT TMP.[Crew ID])
												  FROM 
													#tmpcrw TMP
													LEFT JOIN [ShipMgmt_Crewing].[tCrew] PD ON PD.[Crew ID] = TMP.[Crew ID]
													LEFT JOIN [ShipMgmt_Crewing].[tCrewRanks] RR ON RR.[Rank ID] = COALESCE(TMP.[Rank ID Budgeted], PD.[Rank ID])
												  WHERE 
													[Crew Details Log New Value] = 'Assessment Passed'
													AND RR.[Rank Category] in ('Officers', 'Senior Officers') -- Only Officers
													AND (TMP.[Recruitment Cell ID] = 'UNKNOWN' or TMP.[Recruitment Cell ID] NOT IN ('VGR400000276', 'VGR400000300', 'VGR400000266', 'VGR400000315', 'VGR500000096', 'VGR400000291')) --not offshore recruitment cells
													AND (TMP.[Technical Office] is null or CASE WHEN TMP.[Technical Office] in ('V.Ships Offshore (Asia) Pte. Ltd', 'V.Ships Offshore Limited (Aberdeen)') THEN 1 else 0 END = 0) -- if technical office is offshore then exclude
													AND CAST(TMP.[Crew Details Log Created On] as DATE) BETWEEN DATEADD(day,-30,@Date) AND @Date 
													AND TMP.[Recruitment Cell ID] = REC.[Crew Pool ID]),
	[New Hired Officers Compliant with CRW16 TPA] = NULL,
	[New Hired Officers TPA] = NULL,
	[Approved Seafarers] = NULL,
	[Joined Seafarers] = (SELECT COUNT([Crew ID])
						  FROM 
							#joinedendorsedratio
						  WHERE 
							  [Crew Details Log New Value] = 'Joined'
							  AND [Recruitment Cell ID] = REC.[Crew Pool ID]),
	[New Hired Officers Who Has Taken The Assessment] = (SELECT COUNT(DISTINCT TMP.[Crew ID])
													     FROM 
															#tmpcrw TMP
															LEFT JOIN [ShipMgmt_Crewing].[tCrew] PD ON PD.[Crew ID] = TMP.[Crew ID]
															LEFT JOIN [ShipMgmt_Crewing].[tCrewRanks] RR ON RR.[Rank ID] = COALESCE(TMP.[Rank ID Budgeted], PD.[Rank ID])
													     WHERE 
															[Crew Details Log New Value] in ('Assessment Passed', 'Assessment Failed')
															AND RR.[Rank Category] in ('Officers', 'Senior Officers') -- Only Officers
															AND (TMP.[Recruitment Cell ID] = 'UNKNOWN' or TMP.[Recruitment Cell ID] NOT IN ('VGR400000276', 'VGR400000300', 'VGR400000266', 'VGR400000315', 'VGR500000096', 'VGR400000291')) --not offshore recruitment cells
															AND (TMP.[Technical Office] is null or CASE WHEN TMP.[Technical Office] in ('V.Ships Offshore (Asia) Pte. Ltd', 'V.Ships Offshore Limited (Aberdeen)') THEN 1 else 0 END = 0) -- if technical office is offshore then exclude
															AND CAST(TMP.[Crew Details Log Created On] as DATE) BETWEEN DATEADD(day,-30,@Date) AND @Date
															AND TMP.[Recruitment Cell ID] = REC.[Crew Pool ID]),
	-- New Columns to be added in Table
	[Endorsed Seafarers] = (SELECT COUNT([Crew ID])
						    FROM 
								#joinedendorsedratio
						    WHERE 
								[Crew Details Log New Value] in ('Endorsed')
								AND [Recruitment Cell ID] = REC.[Crew Pool ID]),

	[New Hires Digitized] = (SELECT COUNT(DISTINCT NHD.[Crew ID])
							 FROM 
								#NewHiresDocs NHD
							 WHERE 
								NHD.[Uploads] > 0 -- Where the new hire have a least 1 doc uploaded in the app before being approved for the service
								AND CASE WHEN NHD.[Vships Service Count] > 0 THEN 1 ELSE 0 END = 0
								AND NHD.[Recruitment Cell ID] = REC.[Crew Pool ID]),

	[New Hires For Digitization] = (SELECT COUNT(DISTINCT NHD.[Crew ID])
								    FROM 
										#NewHiresDocs NHD
								    WHERE
										NHD.[Recruitment Cell ID] = REC.[Crew Pool ID]
										AND CASE WHEN NHD.[Vships Service Count] > 0 THEN 1 ELSE 0 END = 0)
INTO
	#result_CrewRecruitmentScorecard

FROM 
	#RecCells REC

	--select * from #result_CrewRecruitmentScorecard

	--drop table #result_CrewRecruitmentScorecard

DECLARE @toinsert INT = (SELECT COUNT(*) FROM #result_CrewRecruitmentScorecard)

-----------------------------------------------------------------------------
----------- Insert into dest table if there's something to insert -----------
-----------------------------------------------------------------------------

	IF @toinsert > 0 

	BEGIN

		DELETE FROM [ShipMgmt_Crewing].[tCrewRecruitmentScorecard] WHERE [Record Inserted On] = CAST (@Date AS DATE)

		INSERT INTO [ShipMgmt_Crewing].[tCrewRecruitmentScorecard] (
			[Record Inserted On],
			[Recruitment Cell ID],
			[Recruitment Cell],
			[Endorsed Candidates],
			[Approved Candidates],
			[New Hired Officers Compliant with CRW16],
			[New Hired Officers],
			[New Hires Processed Via Recruitment Tracking],
			[New Hired Seafarers],
			[Urgent Approved Candidates Before Start Date],
			[Urgent Recruitment Requests],
			[Non Urgent Approved Candidates Before Start Date],
			[Non Urgent Recruitment Request],
			[New Hired Officers Who Passed Assessment],
			[New Hired Officers Compliant with CRW16 TPA],
			[New Hired Officers TPA],
			[Approved Seafarers],
			[Joined Seafarers],
			[New Hired Officers Who Has Taken The Assessment],
			[Endorsed Seafarers],
			[New Hires Digitized],
			[New Hires For Digitization])

		SELECT
			[Record Inserted On],
			[Recruitment Cell ID],
			[Recruitment Cell],
			[Endorsed Candidates],
			[Approved Candidates],
			[New Hired Officers Compliant with CRW16],
			[New Hired Officers],
			[New Hires Processed Via Recruitment Tracking],
			[New Hired Seafarers],
			[Urgent Approved Candidates Before Start Date],
			[Urgent Recruitment Requests],
			[Non Urgent Approved Candidates Before Start Date],
			[Non Urgent Recruitment Request],
			[New Hired Officers Who Passed Assessment],
			[New Hired Officers Compliant with CRW16 TPA],
			[New Hired Officers TPA],
			[Approved Seafarers],
			[Joined Seafarers],
			[New Hired Officers Who Has Taken The Assessment],
			[Endorsed Seafarers],
			[New Hires Digitized],
			[New Hires For Digitization]

		FROM #result_CrewRecruitmentScorecard

	END

	DROP TABLE #Recruitments;
	DROP TABLE #tmpcrw;
	DROP TABLE #newhires;
	DROP TABLE #interview;
	DROP TABLE #RankBeforeRejoining;
	DROP TABLE #assessmentcomp;
	DROP TABLE #UrgentFulfillment;
	DROP TABLE #NonUrgentFulfillment;
	DROP TABLE #NewHiresDigi;
	DROP TABLE #NewHiresDocs;
	DROP TABLE #Recruitments2;
	DROP TABLE #tmpcrw2;
	DROP TABLE #endorseddateforcrewwhojoined;
	DROP TABLE #Candidates;
	DROP TABLE #logs;
	DROP TABLE #nulogs2;
	DROP TABLE #Candidates2;
	DROP TABLE #logs2;
	DROP TABLE #joinedendorsedratio;
	DROP TABLE #RecCells;
	DROP TABLE #ApprovedCan;
	DROP TABLE #approvedendorsedratio;
	DROP TABLE #EndorsedCan;
	DROP TABLE #TCS;
	DROP TABLE #result_CrewRecruitmentScorecard;

END