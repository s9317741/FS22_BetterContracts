---${title}
---@author ${author}
---@version r_version_r
---@date 18/01/2022

--=======================================================================================================
-- BetterContracts SCRIPT
--
-- Purpose:     Enhance ingame contracts menu.
-- Author:      Royal-Modding / Mmtrx
-- Changelog:
--  v1.0.0.0    19.10.2020  initial by Royal-Modding
--  v1.1.0.0    12.04.2021  release candidate RC-2
--  v1.1.0.3    24.04.2021  (Mmtrx) gui enhancements: addtl details, sort buttons
--  v1.1.0.4    07.07.2021  (Mmtrx) add user-defined missionVehicles.xml, allow missions with no vehicles
--  v1.2.0.0    30.11.2021  (Mmtrx) adapt for FS22
--=======================================================================================================

---------------------- mission vehicle enhancement functions --------------------------------------------
---@param missionManager MissionManager
---@param superFunc function
---@return boolean
function BetterContracts.loadMissionVehicles(missionManager, superFunc, ...)
    local self = BetterContracts
    if superFunc(missionManager, ...) then
        if g_modIsLoaded["FS19_ThueringerHoehe_BG_Edition"] then
            debugPrint("[%s] %s map detected, loading mission vehicles created by %s", self.name, "FS19_ThueringerHoehe", "Lahmi")
            missionManager.missionVehicles = {}
            self:loadExtraMissionVehicles(self.directory .. "missionVehicles/FS19_ThueringerHoehe/baseGame.xml")
            self:loadExtraMissionVehicles(self.directory .. "missionVehicles/FS19_ThueringerHoehe/claasPack.xml")          
        else
            self:loadExtraMissionVehicles(self.directory .. "missionVehicles/baseGame.xml")
            -- self:loadExtraMissionVehicles(self.directory .. "missionVehicles/claasPack.xml")
        end
        local userdef = self.directory .. "missionVehicles/userDefined.xml"
        if fileExists(userdef) then 
            self:loadExtraMissionVehicles(userdef)
        end    
        self:validateMissionVehicles()
        return true
    end
    return false
end

function BetterContracts:validateMissionVehicles()
    -- check if vehicle groups for each missiontype/fieldsize are defined
    local type 
    for _,mt in ipairs(g_missionManager.missionTypes) do
        if mt.category == MissionManager.CATEGORY_FIELD or 
           mt.category == MissionManager.CATEGORY_GRASS_FIELD then
            type = mt.name
            for _,f in ipairs({"small","medium","large"}) do
                if g_missionManager.missionVehicles[type][f] == nil or 
                    #g_missionManager.missionVehicles[type][f] == 0 then
                    Logging.devWarning("[%s] No missionVehicles for %s missions on %s fields",
                        self.name, type, f)
                end
            end
        end
    end
end

function BetterContracts:loadExtraMissionVehicles(xmlFilename)
    local xmlFile = loadXMLFile("loadExtraMissionVehicles", xmlFilename)
    local modDirectory = nil
    local requiredMod = getXMLString(xmlFile, "missionVehicles#requiredMod")
    local hasRequiredMod = false
    if requiredMod ~= nil and g_modIsLoaded[requiredMod] then
        modDirectory = g_modNameToDirectory[requiredMod]
        hasRequiredMod = true
    end
    local overwriteStd = Utils.getNoNil(getXMLBool(xmlFile, "missionVehicles#overwrite"), false)
    if overwriteStd then 
       g_missionManager.missionVehicles = {}
    end
    if hasRequiredMod or requiredMod == nil then
        local index = 0
        while true do
            local baseKey = string.format("missionVehicles.mission(%d)", index)
            if hasXMLProperty(xmlFile, baseKey) then
                local missionType = getXMLString(xmlFile, baseKey .. "#type") or ""
                if missionType ~= "" then
                    if g_missionManager.missionVehicles[missionType] == nil then
                        g_missionManager.missionVehicles[missionType] = {}
                        g_missionManager.missionVehicles[missionType].small = {}
                        g_missionManager.missionVehicles[missionType].medium = {}
                        g_missionManager.missionVehicles[missionType].large = {}
                    end
                    self:loadExtraMissionVehicles_groups(xmlFile, baseKey, missionType, modDirectory)
                end
            else
                break
            end
            index = index + 1
        end
    end
    delete(xmlFile)
end

function BetterContracts:loadExtraMissionVehicles_groups(xmlFile, baseKey, missionType, modDirectory)
    local index = 0
    while true do
        local groupKey = string.format("%s.group(%d)", baseKey, index)
        if hasXMLProperty(xmlFile, groupKey) then
            local group = {}
            local fieldSize = getXMLString(xmlFile, groupKey .. "#fieldSize") or "missingFieldSize"
            group.variant = getXMLString(xmlFile, groupKey .. "#variant")
            group.rewardScale = getXMLFloat(xmlFile, groupKey .. "#rewardScale") or 1
            if g_missionManager.missionVehicles[missionType][fieldSize] == nil then 
                g_missionManager.missionVehicles[missionType][fieldSize] = {}
            end 
            group.identifier = #g_missionManager.missionVehicles[missionType][fieldSize] + 1
            group.vehicles = self:loadExtraMissionVehicles_vehicles(xmlFile, groupKey, modDirectory)
            table.insert(g_missionManager.missionVehicles[missionType][fieldSize], group)
        else
            break
        end
        index = index + 1
    end
end

function BetterContracts:loadExtraMissionVehicles_vehicles(xmlFile, groupKey, modDirectory)
    local index = 0
    local vehicles = {}
    local modName, ignore 
    while true do
        local vehicleKey = string.format("%s.vehicle(%d)", groupKey, index)
        if hasXMLProperty(xmlFile, vehicleKey) then
            local vehicle = {}
            local baseDirectory = nil
            local vfile = getXMLString(xmlFile, vehicleKey .. "#filename") or "missingFilename"
            ignore = false
            modName = getXMLString(xmlFile, vehicleKey .. "#requiredMod")
            if getXMLBool(xmlFile, vehicleKey .. "#isMod") then
                baseDirectory = modDirectory
            elseif modName~= nil then 
                if g_modIsLoaded[modName]then
                    baseDirectory = g_modNameToDirectory[modName]
                else
                    Logging.warning("[%s] required Mod %s not found, ignoring mission vehicle %s",
                        self.name, modName, vfile)
                    ignore = true
                end 
            end
            if not ignore then
                vehicle.filename = Utils.getFilename(vfile, baseDirectory)
                vehicle.configurations = self:loadExtraMissionVehicles_configurations(xmlFile, vehicleKey)
                table.insert(vehicles, vehicle)
            end
        else
            break
        end
        index = index + 1
    end
    return vehicles
end

function BetterContracts:loadExtraMissionVehicles_configurations(xmlFile, vehicleKey)
    local index = 0
    local configurations = {}
    while true do
        local configurationKey = string.format("%s.configuration(%d)", vehicleKey, index)
        if hasXMLProperty(xmlFile, configurationKey) then
            local ignore = false
            local name = getXMLString(xmlFile, configurationKey .. "#name") or "missingName"
            local id = getXMLInt(xmlFile, configurationKey .. "#id") or 1
            local modName = getXMLString(xmlFile, configurationKey .. "#requiredMod")
            if not g_configurationManager:getConfigurationDescByName(name) then 
                Logging.warning("[%s] configuration %s not found, ignored",
                        self.name, name)
            elseif modName~= nil and not g_modIsLoaded[modName] then
                Logging.warning("[%s] required Mod %s not found, ignoring '%s' configuration",
                        self.name, modName, name)
            else
                configurations[name] = id
            end
        else
            break
        end
        index = index + 1
    end
    return configurations
end
