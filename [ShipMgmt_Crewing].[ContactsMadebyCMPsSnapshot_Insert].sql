USE [vgroup-onedata-preview]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [ShipMgmt_Crewing].[ContactsMadebyCMPsSnapshot_Insert]
    @SnapshotDate DATETIME
AS

------------------------------------------------------------------------------------------------------------------
-- Created by: Tiffany Torres, 04/06/2025 
-- This sproc is to be run daily. It inserts all active crew and deletes previous day entry unless it was Sunday. 
-- Effectively we keep all Sunday inserts and the last run.
------------------------------------------------------------------------------------------------------------------

SET NOCOUNT ON;

DELETE FROM [ShipMgmt_Crewing].[tCrewContactsMadebyCMPsToOffsignersSnapshot] 
WHERE [To Delete] = 1
	OR CAST([Date] AS DATE) = CAST(@SnapshotDate AS DATE);

INSERT INTO [ShipMgmt_Crewing].[tCrewContactsMadebyCMPsToOffsignersSnapshot]
			([Date],
			[Crew ID],
			[PCN],
			[Service Record ID],
			[Crew Surname],
			[Crew Forename],
			[Crew Movement Status],
			[Nationality],
			[Country Of Nationality],
			[Activity Date],
			[Start Date],
			[End Date],
			[Crew Rank],
			[Load Port],
			[Load Port Country],
			[Vessel ID],
			[Vessel Name],
			[Mobilisation Cell],
			[Planning Cell],
			[CMP Cell],
			[SignOff Reason],
			[Action],
			[Rank],
			[Rank Category],
			[Rank Department],
			[Vessel Mgmt Type],
			[Technical Office],
			[Sector],
			[Client],
			[Contract Type],
			[# of Contacts Made by CMP],
			[Row Number],
			[To Delete])

SELECT
			[Date],
			[Crew ID],
			[PCN],
			[Service Record ID],
			[Crew Surname],
			[Crew Forename],
			[Crew Movement Status],
			[Nationality],
			[Country Of Nationality],
			[Activity Date],
			[Start Date],
			[End Date],
			[Crew Rank],
			[Load Port],
			[Load Port Country],
			[Vessel ID],
			[Vessel Name],
			[Mobilisation Cell],
			[Planning Cell],
			[CMP Cell],
			[SignOff Reason],
			[Action],
			[Rank],
			[Rank Category],
			[Rank Department],
			[Vessel Mgmt Type],
			[Technical Office],
			[Sector],
			[Client],
			[Contract Type],
			[# of Contacts Made by CMP],
			[Row Number],
			[To Delete]

FROM
	[ShipMgmt_Crewing].[# of Contacts Made by CMPs to Offsigners L30D]
WHERE 
    [Row Number] = 1;     -- ONLY 1 ROW PER CREW (IN CASE OF DUPLICATES)
