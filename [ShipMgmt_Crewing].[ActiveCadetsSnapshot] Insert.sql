USE [vgroup-onedata-preview]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [ShipMgmt_Crewing].[ActiveCadetsSnapshot]
    @SnapshotDate DATETIME
AS
------------------------------------------------------------------------------------------------------------------
-- Created by: Tiffany Torres, 21/03/2025 
-- This sproc is to be run daily. It inserts all active crew and deletes previous day entry unless it was Sunday. 
-- Effectively we keep all Sunday inserts and the last run.
------------------------------------------------------------------------------------------------------------------

SET NOCOUNT ON;

 -- deleting whatever is not Sunday or has the same insert date as what is abot to be inserted now
DELETE FROM [ShipMgmt_Crewing].[tActiveCadetsSnapshot] 
WHERE [To Delete] = 1 
	OR CAST([Date] AS DATE) = CAST(@SnapshotDate AS DATE);

INSERT INTO [ShipMgmt_Crewing].[tActiveCadetsSnapshot]
           ([Date],
			[Crew ID],
			[Current Service Record ID],
			[Rank ID],
			[Berth ID] ,
			[Planning Service Record ID],
			[Supply Type],
			[Third Party Agent],
			[Pool Status],
			[Mobilisation Cell ID],
			[Recruitment Cell ID],
			[Planning Cell ID] ,
			[CMP Cell ID],
			[Is Ready For Promotion],
			[Current Status],
			[Current Status Start Date],
			[Current Status End Date],
			[Availability],
			[Actual Service Days] ,
			[Current Service Days],
			[Contract Days],
			[Contract Unit],
			[Extension],
			[Extension Unit],
			[Contract End Date],
			[Current Vessel ID],
			[Planned Vessel ID],
			[Plan To Join],
			[Planning Status],
			[Last Contact Date],
			[Last Vessel ID],
			[Last Vessel Sign On Date],
			[Last Vessel Sign Off Date],
			[V.Ships Contracts],
			[Fleet],
			[Vessel Mgmt ID],
			[Vessel ID Final],
			[Assessed Promotion Record ID],
			[Approved Promotion Record ID],
			[Crew Pool Status],
			[Row Number],
			[Recruiter Name],
			[Recruiter Office],
            [To Delete])

SELECT
			[Date],
			[Crew ID],
			[Current Service Record ID],
			[Rank ID],
			[Berth ID] ,
			[Planning Service Record ID],
			[Supply Type],
			[Third Party Agent],
			[Pool Status],
			[Mobilisation Cell ID],
			[Recruitment Cell ID],
			[Planning Cell ID] ,
			[CMP Cell ID],
			[Is Ready For Promotion],
			[Current Status],
			[Current Status Start Date],
			[Current Status End Date],
			[Availability],
			[Actual Service Days] ,
			[Current Service Days],
			[Contract Days],
			[Contract Unit],
			[Extension],
			[Extension Unit],
			[Contract End Date],
			[Current Vessel ID],
			[Planned Vessel ID],
			[Plan To Join],
			[Planning Status],
			[Last Contact Date],
			[Last Vessel ID],
			[Last Vessel Sign On Date],
			[Last Vessel Sign Off Date],
			[V.Ships Contracts],
			[Fleet],
			[Vessel Mgmt ID],
			[Vessel ID Final],
			[Assessed Promotion Record ID],
			[Approved Promotion Record ID],
			[Crew Pool Status],
			[Row Number],
			[Recruiter Name],
			[Recruiter Office],
            [To Delete]

FROM
	[ShipMgmt_Crewing].[Current Active Cadets]
   
WHERE 
    [Crew Pool Status] = 'ACTIVE'  -- ONLY ACTIVE CREW
    AND [Row Number] = 1;     -- ONLY 1 ROW PER CREW (IN CASE OF DUPLICATE STATUS)