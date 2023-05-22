-- ===========================================================================
-- Base File
-- ===========================================================================
include("PlotInfo");

-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_CQUI_OnClickSwapTile = OnClickSwapTile;
BASE_CQUI_OnClickPurchasePlot = OnClickPurchasePlot;
BASE_CQUI_ShowCitizens = ShowCitizens;
BASE_CQUI_OnDistrictAddedToMap = OnDistrictAddedToMap;
BASE_CQUI_AggregateLensHexes = AggregateLensHexes;
BASE_CQUI_RealizeTilt = RealizeTilt;
BASE_CQUI_Initialize = Initialize;
BASE_CQUI_OnClickCitizen = OnClickCitizen;
BASE_CQUI_OnLensLayerOn = OnLensLayerOn;
BASE_CQUI_OnLensLayerOff = OnLensLayerOff;

-- ===========================================================================
-- CQUI Members
-- ===========================================================================
local CQUI_WorkIconSize: number = 48;
local CQUI_WorkIconAlpha = .60;
local CQUI_SmartWorkIcon: boolean = true;
local CQUI_SmartWorkIconSize: number = 64;
local CQUI_SmartWorkIconAlpha = .45;
local CQUI_ShowCityManageOverLenses = false;
local CQUI_DragThresholdExceeded = false;
local CITY_CENTER_DISTRICT_INDEX = GameInfo.Districts["DISTRICT_CITY_CENTER"].Index;

-- Citizen Management, Power, Loyalty, and Religion lenses
-- local m_CitizenManagement : number = UILens.CreateLensLayerHash("Hex_Coloring_Appeal_Level");
local m_Power : number = UILens.CreateLensLayerHash("Power_Lens");
local m_Loyalty : number = UILens.CreateLensLayerHash("Cultural_Identity_Lens");
local m_Religion : number = UILens.CreateLensLayerHash("Hex_Coloring_Religion");

function CQUI_OnSettingsUpdate()
    CQUI_WorkIconSize = GameConfiguration.GetValue("CQUI_WorkIconSize");
    CQUI_WorkIconAlpha = GameConfiguration.GetValue("CQUI_WorkIconAlpha") / 100;
    CQUI_SmartWorkIcon = GameConfiguration.GetValue("CQUI_SmartWorkIcon");
    CQUI_SmartWorkIconSize = GameConfiguration.GetValue("CQUI_SmartWorkIconSize");
    CQUI_SmartWorkIconAlpha = GameConfiguration.GetValue("CQUI_SmartWorkIconAlpha") / 100;
    CQUI_ShowCityManageOverLenses = GameConfiguration.GetValue("CQUI_ShowCityManageOverLenses");
end

-- ===========================================================================
-- CQUI update citizens, data and real housing for both cities when swap tiles
-- ===========================================================================
function CQUI_UpdateCitiesCitizensWhenSwapTiles(pCity)
    CityManager.RequestCommand(pCity, CityCommandTypes.SET_FOCUS, nil);
end

-- ===========================================================================
-- CQUI update citizens, data and real housing for close cities within 4 tiles when city founded
-- we use it only to update real housing for a city that loses a 3rd radius tile to a city that is founded within 4 tiles
-- ===========================================================================
function CQUI_UpdateCloseCitiesCitizensWhenCityFounded(playerID, cityID)
    local kCity = CityManager.GetCity(playerID, cityID);
    local m_pCity:table = Players[playerID]:GetCities();
    for i, pCity in m_pCity:Members() do
        if Map.GetPlotDistance( kCity:GetX(), kCity:GetY(), pCity:GetX(), pCity:GetY() ) == 4 then
            CityManager.RequestCommand(pCity, CityCommandTypes.SET_FOCUS, nil);
        end
    end
end

-- ===========================================================================
-- Takes a table with duplicates and returns a new table without duplicates. Credit to vogomatix at stask exchange for the code
-- ===========================================================================
function CQUI_RemoveDuplicates(i:table)
    local hash = {};
    local o = {};
    for _,v in ipairs(i) do
        if (not hash[v]) then
            o[#o+1] = v;
            hash[v] = true;
        end
    end
    return o;
end

-- ===========================================================================
-- Sets the variable tracking if the map was dragged beyond the threshold
-- ===========================================================================
function CQUI_SetDragThresholdExceeded( state:boolean )
    CQUI_DragThresholdExceeded = state;
end

-- ===========================================================================
--  CQUI modified OnClickCitizen function
--  Force the tiles in the city view to update when a citizen icon is clicked
-- ===========================================================================
function OnClickCitizen( plotId:number )
    local pSelectedCity :table = UI.GetHeadSelectedCity();
    if pSelectedCity ~= nil then
        LuaEvents.CQUI_RefreshCitizenManagement(pSelectedCity:GetID());
    end

    if CQUI_DragThresholdExceeded then
        CQUI_DragThresholdExceeded = false;
        return false;
    end

    BASE_CQUI_OnClickCitizen(plotId);
end

-- ===========================================================================
--  CQUI modified OnClickSwapTile function
--  Update citizens, data and real housing for both cities
-- ===========================================================================
function OnClickSwapTile( plotId:number )
    if CQUI_DragThresholdExceeded then
        CQUI_DragThresholdExceeded = false;
        return false;
    end

    local result = BASE_CQUI_OnClickSwapTile(plotId);

    local pSelectedCity :table = UI.GetHeadSelectedCity();
    local kPlot :table = Map.GetPlotByIndex(plotId);
    local pCity = Cities.GetPlotPurchaseCity(kPlot);  -- CQUI a city that was a previous tile owner
    CQUI_UpdateCitiesCitizensWhenSwapTiles(pSelectedCity);  -- CQUI update citizens and data for a city that is a new tile owner
    CQUI_UpdateCitiesCitizensWhenSwapTiles(pCity);  -- CQUI update citizens and data for a city that was a previous tile owner
    
    return result;
end

-- ===========================================================================
--  CQUI modified OnClickPurchasePlot function
--  Don't purchase if currently dragging
--  Update the city data
-- ===========================================================================
function OnClickPurchasePlot( plotId:number )
    -- CQUI: If we're dragging and we exceeded the threshold for how far we could move the mouse while dragging, do not purchase
    if CQUI_DragThresholdExceeded then
        CQUI_DragThresholdExceeded = false;
        return false;
    end

    local result = BASE_CQUI_OnClickPurchasePlot(plotId);
    OnClickCitizen();  -- CQUI : update selected city citizens and data

    return result;
end

-- ===========================================================================
--  CQUI modified ShowCitizens function : Customize the citizen icon and Hide the city center icon
-- ===========================================================================
function ShowCitizens()
    BASE_CQUI_ShowCitizens();

    local pSelectedCity :table = UI.GetHeadSelectedCity();
    if pSelectedCity == nil then
        -- Add error message here
        return;
    end

    local tParameters :table = {};
    tParameters[CityCommandTypes.PARAM_MANAGE_CITIZEN] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_MANAGE_CITIZEN);

    local tResults  :table = CityManager.GetCommandTargets( pSelectedCity, CityCommandTypes.MANAGE, tParameters );
    if tResults == nil then
        -- Add error message here
        return;
    end

    local tPlots :table = tResults[CityCommandResults.PLOTS];
    local tUnits :table = tResults[CityCommandResults.CITIZENS];
    if tPlots ~= nil and (table.count(tPlots) > 0) then
        for i,plotId in pairs(tPlots) do
            local kPlot :table = Map.GetPlotByIndex(plotId);
            local index :number = kPlot:GetIndex();
            local pInstance :table = GetInstanceAt( index );

            if pInstance ~= nil then
                local isCityCenterPlot = kPlot:GetDistrictType() == CITY_CENTER_DISTRICT_INDEX;
                pInstance.CitizenButton:SetHide(isCityCenterPlot);
                pInstance.CitizenButton:SetDisabled(isCityCenterPlot);

                local numUnits:number = tUnits[i];

                --CQUI Citizen buttons tweaks
                if (CQUI_SmartWorkIcon and numUnits >= 1) then
                    pInstance.CitizenButton:SetSizeVal(CQUI_SmartWorkIconSize, CQUI_SmartWorkIconSize);
                    pInstance.CitizenButton:SetAlpha(CQUI_SmartWorkIconAlpha);
                else
                    pInstance.CitizenButton:SetSizeVal(CQUI_WorkIconSize, CQUI_WorkIconSize);
                    pInstance.CitizenButton:SetAlpha(CQUI_WorkIconAlpha);
                end

                if (numUnits >= 1) then
                    pInstance.CitizenButton:SetTextureOffsetVal(0, 256);
                end
            end
        end
    end
end

-- ===========================================================================
--  CQUI modified GetPlotYields function
-- ===========================================================================
--[[
function GetPlotYields(plotId:number, yields:table)

	local plot:table= Map.GetPlotByIndex(plotId);

	-- Do not show plot yields for districts
	local districtType = plot:GetDistrictType();
	if districtType ~= -1 and districtType ~= CITY_CENTER_DISTRICT_INDEX then
		--return;
	end

    local district = nil;
    local city = Cities.GetPlotPurchaseCity( plot );
    if (districtType ~= -1) then
        district = city:GetDistricts():FindID(plot:GetDistrictID());
    end

	for row in GameInfo.Yields() do
		local yieldAmt:number = plot:GetYield(row.Index);

        if (district) then
            if (districtType ~= CITY_CENTER_DISTRICT_INDEX) then
                yieldAmt = district:GetYield(row.Index);
            else
                yieldAmt = yieldAmt + district:GetYield(row.Index);
            end
            --yieldAmt = yieldAmt + plot:GetAdjacencyYield(plot:GetOwner(), city, GameInfo.Districts[districtType], row.Index);
            
            
            local buildings = city:GetBuildings():GetBuildingsAtLocation(plot);
            for i, type in ipairs(buildings) do
                local building	= GameInfo.Buildings[type].Index;
                local buildingYield = city:GetBuildingYield(building, row.Index);
                yieldAmt = yieldAmt + buildingYield;
            end
        end

		if yieldAmt > 0 then
			local clampedYieldAmount:number = yieldAmt > 5 and 5 or yieldAmt;
			local yieldType:string = YIELD_VARIATION_MAP[row.YieldType] .. clampedYieldAmount;
			local plots:table = yields[yieldType];
			if plots == nil then
				plots = { data = {}, variations = {}, yieldType=row.YieldType };
				yields[yieldType] = plots;
			end
			table.insert(plots.data, plotId);

			-- Variations are used to overlay a number from 6 - 12 on top of largest yield icon (5)
			if yieldAmt > 5 then
				if yieldAmt > 11 then
					table.insert(plots.variations, { YIELD_VARIATION_MANY, plotId });
				else
					table.insert(plots.variations, { YIELD_NUMBER_VARIATION .. yieldAmt, plotId });
				end
			end
		end
	end
end
--]]

-- ===========================================================================
--  CQUI modified OnDistrictAddedToMap function
--  Update citizens, data and real housing for close cities within 4 tiles when city founded
--  we use it only to update real housing for a city that loses a 3rd radius tile to a city that is founded within 4 tiles
-- ===========================================================================
function OnDistrictAddedToMap( playerID: number, districtID : number, cityID :number, districtX : number, districtY : number, districtType:number )
    BASE_CQUI_OnDistrictAddedToMap(playerID, districtID, cityID, districtX, districtY, districtType);
    
    if districtType == CITY_CENTER_DISTRICT_INDEX and playerID == Game.GetLocalPlayer() then
        CQUI_UpdateCloseCitiesCitizensWhenCityFounded(playerID, cityID);
    end
end

-- ===========================================================================
--  CQUI modified AggregateLensHexes function
--  Remove duplicate entries and add selected city tiles if needed
-- ===========================================================================
function AggregateLensHexes(keys:table)
    -- Get the result from the base function
    local result = BASE_CQUI_AggregateLensHexes(keys);

    -- Return if we are in district/building placement mode or if no city is selected
    local mode = UI.GetInterfaceMode();
    local pSelectedCity :table = UI.GetHeadSelectedCity();
    if (mode == InterfaceModeTypes.DISTRICT_PLACEMENT or mode == InterfaceModeTypes.BUILDING_PLACEMENT or pSelectedCity == nil) then
        return CQUI_RemoveDuplicates(result);
    end

    -- Get the list of tiles available to purchase
    local purchaseTiles = BASE_CQUI_AggregateLensHexes({"PLOT_PURCHASE"});

--[[
    -- Remove the city plots from purchaseTiles if the Citizen Management lens is active
    if (#purchaseTiles > 0 and UILens.IsLayerOn(m_CitizenManagement)) then
        local kCityPlots :table = Map.GetCityPlots():GetPurchasedPlots(pSelectedCity);
        for _,plotId in pairs(kCityPlots) do
            local index = (#purchaseTiles - #kCityPlots) + 1;
            if (result[index] ~= plotId) then
                break;
            end
            table.remove(result, index);
        end
    end

    -- Add the city plots if there are no tiles available to purchase and the Citizen Management lens is not active
    if (#purchaseTiles == 0 and not UILens.IsLayerOn(m_CitizenManagement)) then
        local kCityPlots :table = Map.GetCityPlots():GetPurchasedPlots(pSelectedCity);
        for _,plotId in pairs(kCityPlots) do
            table.insert(result, plotId);
        end
    end
--]]

    -- Add the city plots if there are no tiles available to purchase
    if (#purchaseTiles == 0) then
        local kCityPlots :table = Map.GetCityPlots():GetPurchasedPlots(pSelectedCity);
        for _,plotId in pairs(kCityPlots) do
            table.insert(result, plotId);
        end
    end

    -- Return the new result
    return CQUI_RemoveDuplicates(result);
end

-- ===========================================================================
--  CQUI modified RealizeTilt function 
--  Don't change the tilt if in building or district placement
-- ===========================================================================
function RealizeTilt()
    if UI.GetInterfaceMode() == InterfaceModeTypes.DISTRICT_PLACEMENT or UI.GetInterfaceMode() == InterfaceModeTypes.BUILDING_PLACEMENT then
        return;
    end
    BASE_CQUI_RealizeTilt();
end

-- ===========================================================================
--  CQUI modified OnLensLayerOn
--  Allow citizen management on other lenses
-- ===========================================================================
function OnLensLayerOn( layerNum:number )
    BASE_CQUI_OnLensLayerOn(layerNum);

    if (CQUI_ShowCityManageOverLenses and (layerNum == m_Power or layerNum == m_Loyalty or layerNum == m_Religion)) then
        ShowCitizens();
        RealizeShadowMask();
        RealizeTilt();
        RefreshCityYieldsPlotList();
    end
end

-- ===========================================================================
--  CQUI modified OnLensLayerOn
--  Allow citizen management on other lenses
-- ===========================================================================
function OnLensLayerOff( layerNum:number )
    BASE_CQUI_OnLensLayerOff(layerNum);

    if (CQUI_ShowCityManageOverLenses and (layerNum == m_Power or layerNum == m_Loyalty or layerNum == m_Religion)) then
        HideCitizens();
        RealizeShadowMask();
        RealizeTilt();
        RefreshCityYieldsPlotList();
    end
end

-- ===========================================================================
function Initialize_PlotInfo_CQUI()
    -- Note: Replacing the existing Initialize function does not work unless it's called at the end of this file
    --       As such, it does not have to be called "Initialize", any name will do.
    Events.DistrictAddedToMap.Remove(BASE_CQUI_OnDistrictAddedToMap);
    Events.DistrictAddedToMap.Add(OnDistrictAddedToMap);
    Events.LensLayerOn.Remove(BASE_CQUI_OnLensLayerOn);
    Events.LensLayerOff.Remove(BASE_CQUI_OnLensLayerOff);
    Events.LensLayerOn.Add(OnLensLayerOn);
    Events.LensLayerOff.Add(OnLensLayerOff);

    LuaEvents.CQUI_SettingsUpdate.Add(CQUI_OnSettingsUpdate);
    LuaEvents.CQUI_SettingsInitialized.Add(CQUI_OnSettingsUpdate);
    LuaEvents.CQUI_SetDragThresholdExceeded.Add(CQUI_SetDragThresholdExceeded);
    LuaEvents.CQUI_RefreshPurchasePlots.Add(RefreshPurchasePlots);
end
Initialize_PlotInfo_CQUI();