CREATE PROCEDURE [ShipMgmt_Crewing].[CrewPlannedtoJoinInsert]
(
@DateFromPipeline DATETIME
)

AS 

BEGIN

DECLARE @Date DATE = CAST(@DateFromPipeline AS DATE);

-------------------------------------
SELECT
	@Date as [Date],
	PL.[Crew ID],
	PL.[Service Record ID],
	PL.[Planning Status],
	PL.[Rank ID],
	PL.[Start Date],
	PL.[End Date],
	PL.[Rank],
	PL.[Rank Sequence],
	PL.[Rank Category],
	PL.[Rank Department],
	PL.[Is the service done outside of V.Ships],
	PL.[Planned Vessel ID],
	PL.[Planned Vessel],
	PL.[Planned Vessel Mgmt ID],
	PL.[Planned Vessel Fleet],
	PL.[Planned Vessel Client],
	PL.[Planned Vessel Mgmt Type],
	PL.[Planned Vessel Segment],
	PL.[Planned Vessel Type],
	PL.[Planned Vessel General Type Group],
	PL.[Planned Vessel Technical Office],
	PL.[Sea Days],
	PL.[Order of future services],
	SD.[Lineup ID Joiner],
	LNP.[Line Up Description],
	LNP.[Line Up Created On]

INTO
	#resultPlannedtoJoin

FROM 
	[ShipMgmt_Crewing].[Next Planned Vessel] PL
	LEFT JOIN [ShipMgmt_Crewing].[tCrewServiceRecords] SD ON SD.[Service Record ID] = PL.[Service Record ID]
	LEFT JOIN [ShipMgmt_Crewing].[tCrewLineUps] LNP ON LNP.[Line Up ID] = SD.[Lineup ID Joiner]
WHERE 
	PL.[Start Date] >= @Date AND PL.[Start Date] <= dateadd(DAY, 60, @Date) -- Only Crew who are planned to Join in the next 60 days

DECLARE @toinsert INT = (SELECT COUNT(*) FROM #resultPlannedtoJoin)

-----------------------------------------------------------------------------
----------- Insert into dest table if there's something to insert -----------
-----------------------------------------------------------------------------

IF @toinsert > 0 

BEGIN

	DELETE FROM [ShipMgmt_Crewing].[tCrewPlannedtoJoinSnapshot] WHERE [Date] = CAST (@Date AS DATE)

INSERT INTO [ShipMgmt_Crewing].[tCrewPlannedtoJoinSnapshot] (
	[Date],
	[Crew ID],
	[Service Record ID],
	[Planning Status],
	[Rank ID],
	[Start Date],
	[End Date],
	[Rank],
	[Rank Sequence],
	[Rank Category],
	[Rank Department],
	[Is the service done outside of V.Ships],
	[Planned Vessel ID],
	[Planned Vessel],
	[Planned Vessel Mgmt ID],
	[Planned Vessel Fleet],
	[Planned Vessel Client],
	[Planned Vessel Mgmt Type],
	[Planned Vessel Segment],
	[Planned Vessel Type],
	[Planned Vessel General Type Group],
	[Planned Vessel Technical Office],
	[Sea Days],
	[Order of future services],
	[Lineup ID Joiner],
	[Line Up Description],
	[Line Up Created On]
)

SELECT
	[Date],
	[Crew ID],
	[Service Record ID],
	[Planning Status],
	[Rank ID],
	[Start Date],
	[End Date],
	[Rank],
	[Rank Sequence],
	[Rank Category],
	[Rank Department],
	[Is the service done outside of V.Ships],
	[Planned Vessel ID],
	[Planned Vessel],
	[Planned Vessel Mgmt ID],
	[Planned Vessel Fleet],
	[Planned Vessel Client],
	[Planned Vessel Mgmt Type],
	[Planned Vessel Segment],
	[Planned Vessel Type],
	[Planned Vessel General Type Group],
	[Planned Vessel Technical Office],
	[Sea Days],
	[Order of future services],
	[Lineup ID Joiner],
	[Line Up Description],
	[Line Up Created On]

FROM #resultPlannedtoJoin

END
DROP TABLE #resultPlannedtoJoin;

END