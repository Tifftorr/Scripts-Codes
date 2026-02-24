USE [vgroup-onedata-preview]
GO
/****** Object:  StoredProcedure [ShipMgmt_Crewing].[CrewRecruitmentScorecardInsert]    Script Date: 24/02/2026 18:26:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

---------------------------------------
--Created By: Tiffany Torres
--Purpose: Summarized Table for Recruitment Team's scorecard for 2025
--Modified On:  29/03/2025, 29/05/2025

--  Updated by A Seglin on 20/11/2025 User story : 254942
--  Updated by A Seglin on 27/10/2025 User story : 250531
--  Updated by Manjiri on 11/12/2025 User story : 258003

--  Updated by A Seglin on 22/01/2026 User story : 262868

---------------------------------------

ALTER PROCEDURE [ShipMgmt_Crewing].[CrewRecruitmentScorecardInsert]
(
@DateFromPipeline DATETIME
)

AS 

BEGIN

DECLARE @Date DATE = CAST(@DateFromPipeline AS DATE);

--DECLARE @Date DATE = CAST(GETDATE() AS DATE);

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
SELECT DISTINCT
	@Date AS [Record Inserted On],
	rec.[Crew Pool ID] as [Recruitment Cell ID],
	rec.[Recruitment Cell],
	[Endorsed Candidates] = (SELECT COUNT([Crew ID])
							FROM [ShipMgmt_Crewing].[Approved Endorsed Ratio]
								WHERE [Crew Details Log New Value] = 'Endorsed'
								AND [Recruitment Cell ID] = REC.[Crew Pool ID]),
	[Approved Candidates] = (SELECT COUNT([Crew ID])
							 FROM 
								[ShipMgmt_Crewing].[Approved Endorsed Ratio]
							 WHERE 
								[Crew Details Log New Value] = 'Accepted'
								AND [Recruitment Cell ID] = REC.[Crew Pool ID]),
	[New Hired Officers Compliant with CRW16] = (SELECT COUNT(DISTINCT crw03.[Crew ID]) 
												 FROM 
													[ShipMgmt_Crewing].[Assessment Compliance] crw03
												 WHERE 
													crw03.[Compliance] = 'COMPLIANT'
													AND crw03.[For Exclusion] = 'Include'
													AND crw03.[Recruitment Cell ID] = REC.[Crew Pool ID]),

	[New Hired Officers] = (SELECT COUNT(DISTINCT crw03.[Crew ID]) 
							FROM 
								[ShipMgmt_Crewing].[Assessment Compliance] crw03
							WHERE  crw03.[For Exclusion] = 'Include'
								AND crw03.[Recruitment Cell ID] = REC.[Crew Pool ID]),

	[New Hires Processed Via Recruitment Tracking] = (SELECT COUNT(DISTINCT nh.[Crew ID])
													  FROM 
														 [ShipMgmt_Crewing].[Recruitment Tracking Usage] (nolock) nh
														  LEFT JOIN [ShipMgmt_Crewing].[tCrewRecruitmentTracking] CRT ON crt.[Crew Service Record ID] = nh.[Service Record ID] AND CRT.[Is Recruitment Tracking Deleted] = 0 and CRT.[Recruitment Tracking Status ID] = 11
														  INNER JOIN [ShipMgmt_Crewing].[tCrew] CPD ON CPD.[Crew ID] = NH.[Crew ID]
														  LEFT JOIN [ShipMgmt_Crewing].[tCrewServiceRecords] SD ON sd.[Service Record ID] = nh.[Service Record ID]
													  WHERE crt.[Recruitment Tracking ID] IS NOT NULL
														  AND nh.[Recruitment Cell ID] = REC.[Crew Pool ID]),
	[New Hired Seafarers] = (SELECT COUNT(DISTINCT nh.[Crew ID])
							 FROM 
								[ShipMgmt_Crewing].[Recruitment Tracking Usage] nh
								INNER JOIN [ShipMgmt_Crewing].[tCrew] CPD ON CPD.[Crew ID] = NH.[Crew ID]
								LEFT JOIN [ShipMgmt_Crewing].[tCrewServiceRecords] SD ON sd.[Service Record ID] = nh.[Service Record ID]
							 WHERE nh.[Recruitment Cell ID] = REC.[Crew Pool ID]),
	[Urgent Approved Candidates Before Start Date] = (SELECT COUNT(distinct [RR Request ID])
													  FROM 
														[ShipMgmt_Crewing].[Recruitment Urgent Fulfillment Request]
													  WHERE 
														[Compliance] = 'Compliant'
														AND [Recruitment Cell] = REC.[Recruitment Cell]),
	[Urgent Recruitment Requests] = (SELECT COUNT( distinct [RR Request ID])
									 FROM 
										[ShipMgmt_Crewing].[Recruitment Urgent Fulfillment Request]
									 WHERE
										[Recruitment Cell] = REC.[Recruitment Cell]),
	[Non Urgent Approved Candidates Before Start Date] = (SELECT COUNT(distinct [RR Request ID])
														  FROM
															[ShipMgmt_Crewing].[Recruitment Non-Urgent Fulfillment Request]
														  WHERE 
															[Compliance] = 'Compliant'
															AND [Recruitment Cell] = REC.[Recruitment Cell]),
	[Non Urgent Recruitment Request] = (SELECT COUNT(distinct [RR Request ID])
										FROM 
											[ShipMgmt_Crewing].[Recruitment Non-Urgent Fulfillment Request]
										WHERE
											[Recruitment Cell] = REC.[Recruitment Cell]),
	[New Hired Officers Who Passed Assessment] = (SELECT COUNT(DISTINCT TMP.[Crew ID])
												  FROM 
													[ShipMgmt_Crewing].[Recruitment Quality Passed Assessments] TMP
												  WHERE 
													[Crew Details Log New Value] = 'Assessment Passed'
													AND CAST(TMP.[Crew Details Log Created On] as DATE) BETWEEN DATEADD(day,-30,@Date) AND @Date 
													AND TMP.[Recruitment Cell ID] = REC.[Crew Pool ID]),
	[New Hired Officers Compliant with CRW16 TPA] = NULL,
	[New Hired Officers TPA] = NULL,
	[Approved Seafarers] = NULL,
	[Joined Seafarers] = (SELECT COUNT(DISTINCT [Crew ID])
						  FROM 
							[ShipMgmt_Crewing].[Joined Endorsed Ratio]
 cr
						  WHERE 
							  [Crew Details Log New Value] = 'Joined'
							 -- and exists(select [Crew ID] FROM  [ShipMgmt_Crewing].[Joined Endorsed Ratio] cp WHERE [Crew Details Log New Value] = 'Endorsed' and cp.[crew id]=cr.[crew id])
							  AND [Recruitment Cell ID] = REC.[Crew Pool ID]),
	[New Hired Officers Who Has Taken The Assessment] = (SELECT COUNT(DISTINCT TMP.[Crew ID])
													     FROM 
													[ShipMgmt_Crewing].[Recruitment Quality Passed Assessments] TMP
												  WHERE 
													CAST(TMP.[Crew Details Log Created On] as DATE) BETWEEN DATEADD(day,-30,@Date) AND @Date 
													AND TMP.[Recruitment Cell ID] = REC.[Crew Pool ID]),
	-- New Columns to be added in Table
	[Endorsed Seafarers] = (SELECT COUNT([Crew ID])
						    FROM 
								[ShipMgmt_Crewing].[Joined Endorsed Ratio]
						    WHERE 
								[Crew Details Log New Value] in ('Endorsed')
								AND [Recruitment Cell ID] = REC.[Crew Pool ID]),

	[New Hires Digitized] = (SELECT COUNT(DISTINCT NHD.[Crew ID])
							 FROM 
								[ShipMgmt_Crewing].[New Comers Digitization] NHD
							 WHERE 
								NHD.[Uploads] > 0 -- Where the new hire have a least 1 doc uploaded in the app before being approved for the service
								AND NHD.[Recruitment Cell ID] = REC.[Crew Pool ID]),

	[New Hires For Digitization] = (SELECT COUNT(DISTINCT NHD.[Crew ID])
								    FROM 
										[ShipMgmt_Crewing].[New Comers Digitization] NHD
								    WHERE
										NHD.[Recruitment Cell ID] = REC.[Crew Pool ID])
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
		order by 3

	END

END


DROP TABLE #RecCells
drop table #result_CrewRecruitmentScorecard