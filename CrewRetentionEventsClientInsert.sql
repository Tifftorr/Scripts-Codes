CREATE PROCEDURE [ShipMgmt_Crewing].[CrewRetentionEventsClientInsert]

AS 

BEGIN TRAN

  DECLARE @dStartDate datetime  
  SELECT @dStartDate = '01-jan-2017'  
  DECLARE @dEndDate datetime  
  SELECT @dEndDate =  ( SELECT DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 1, 0))-- First Day Last Month
------------------------------------------------------------------
/*SELECT ALL LEAVE EVENTS OCCURED FROM THE SELECTED START DATE */
------------------------------------------------------------------
   SELECT  
	   SD.[Service Record ID] as [Service Record ID Event]
	   , SD.[Vessel ID]
	   , SD.[Crew ID]
	   , SD.[Rank ID] 
	   , SD.[Status ID]   
	   , SD.[Start Date] as [Event Date]   
	   , SD.[End Date] as [Event End] 
	   , SD.[Service Active Status ID]  
	   , PD.[Mobilising Office ID] AS [Crew Mobilisation Office] -- still to be checked with Maria  
	   , COALESCE(SD.[Service Vessel Client ID],  V.ShipOwnerId, VMD.[Client ID], NULL) AS [Client ID]  
	   , SD.[Service Record Updated By ID] AS [Event By]
	   , cmp.[Company Name] as [Client]
   
   INTO  
		#tmpCRWPERIOD  
   FROM 
		[ShipMgmt_Crewing].[tCrewServiceRecords] SD (NOLOCK)  
	    INNER JOIN [ShipMgmt_Crewing].[tCrew] PD (NOLOCK) ON PD.[Crew ID] = SD.[Crew ID]
	    INNER JOIN [ShipMgmt_Crewing].[tCrewRanks] R on r.[Rank ID] = sd.[Rank ID]
	    INNER JOIN [Reference_Vessel].[tVessel] v (NOLOCK) on v.[Vessel ID] = SD.[Vessel ID]
	    INNER JOIN [ShipMgmt_VesselMgmt].[tShipMgmtRecords] VMD ON SD.[Vessel Mgmt ID] = VMD.[Vessel Mgmt ID]
	    INNER JOIN [Reference_BusinessStructure].[tCompany] cmp (nolock) on cmp.[Company ID] = COALESCE(SD.[Service Vessel Client ID],  V.ShipOwnerId, VMD.[Client ID])
   
   WHERE 
		SD.[Service Cancelled] = 0  
		AND  SD.[Status ID] = 'OB'  
		AND  SD.[Previous Experience] = 0  
		AND  (SD.[Service Active Status ID] IS NULL OR [Service Active Status ID] <> 3)  
		AND  (SD.[Start Date] >=  @dStartDate and SD.[Start Date] <= @dEndDate)  
   ORDER BY SD.[Crew ID], SD.[Start Date] asc  
  
   -- CONSOLIDATE FRONTLINE DATA.  
   UPDATE 
		#tmpCRWPERIOD
	SET  
		[Client ID] = 'MIGI00001881'  
        , [Client] = 'Frontline Management AS'  
   WHERE 
		[Client ID] IN ('GLAS00067713', 'SING00000040', 'ITMD00031533', 'GLAS00000258', 'ITMD00031534', 'ITMD00031616', 'GLAS00069495' )

--------------------------------------------  
  
   SELECT 
		[Crew ID]
		, [Service Record ID Event]
		, [Client ID]
		, [Event Date] as [Start]
		, [Event End] as [End Date],  
        DENSE_RANK() OVER    
		(PARTITION BY [Crew ID], [Client ID] ORDER BY  [Event Date] DESC) AS [Rank Client],  
        DENSE_RANK() OVER    
		(PARTITION BY [Crew ID] ORDER BY  [Event Date] DESC) AS [Rank Date],  
        DENSE_RANK() OVER    
		(PARTITION BY [Crew ID] ORDER BY  [Client ID] DESC) AS [Rank Total Client]
   INTO 
		#tmpCRWPERIOD2   
   FROM 
		#tmpCRWPERIOD  
   order by 1,7

----------------------------------------------------------
			/*INSERT INTO DESTINATION TABLE*/
----------------------------------------------------------
	
INSERT INTO [ShipMgmt_Crewing].[tCrewRetentionEventsClient]
   
   SELECT DISTINCT
		BB.[Service Record ID Event] as [Service Record ID Event]
		, AA.[Crew ID]
		, AA.[Client ID] AS [Client Impacted]
		, DATEDIFF(DAY, AA.[End Date], BB.[Start]) AS [Gap Between Client in Days]
		, AA.[End Date]
		, BB.[Client ID] AS [New Client]
		, BB.[Start] AS [New Client Start Date]
		, DD.[DateKey]
       
   FROM 
		#tmpCRWPERIOD2 AA  
		INNER JOIN #tmpCRWPERIOD2 BB ON AA.[Crew ID] = BB.[Crew ID] AND  BB.[Rank Date] = AA.[Rank Date]-1  -- GET THE NEXT RECORD AFTER THE LEFT CLIENT  
		LEFT  JOIN [DataModel].[DimensionDate]  DD ON  DATEDIFF(DAY, DD.[Date], AA.[End Date]) = 0
   WHERE 
		AA.[Rank Client] = 1  
		AND  AA.[Rank Date] <> 1  
		AND  BB.[Service Record ID Event] NOT IN (SELECT [Service Record ID] FROM [ShipMgmt_Crewing].[tCrewRetentionEventsClient])  
		AND  AA.[Crew ID] IN (SELECT [Crew ID] FROM #tmpCRWPERIOD2 WHERE [Rank Total Client] > 1)  -- ONLY PULL DATA ON CREW THAT HAVE 2 CLIENTS IN THE HISTORY PERIOD.  
   ORDER BY 
		1
		, AA.[End Date]
  
  DROP TABLE #tmpCRWPERIOD2
  DROP TABLE #tmpCRWPERIOD  
  
if @@ERROR <> 0     
  rollback tran    
  else  
    
COMMIT TRAN  
    
GO;