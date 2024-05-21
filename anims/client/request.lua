local insert = table.insert

---Load table functions
Load = {}

---Loads dictionary
---@param dict string
local function LoadDict(dict)
    RequestAnimDict(dict)
    local start = GetGameTimer()
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() - start > 5000 then
            return false
        end
        Wait(0)
    end
    return true
end

---Loads model/prop
---@param model string
local function LoadModel(model)
    local hashModel = GetHashKey(model)
    RequestModel(hashModel)
    local start = GetGameTimer()
    while not HasModelLoaded(hashModel) do
        if GetGameTimer() - start > 5000 then
            return false
        end
        Wait(0)
    end
    return true
end

---Loads animset/walk
---@param walk string
local function LoadWalk(walk)
    RequestAnimSet(walk)
    local start = GetGameTimer()
    while not HasAnimSetLoaded(walk) do
        if GetGameTimer() - start > 5000 then
            return false
        end
        Wait(0)
    end
    return true
end

---Loads particle effects
---@param asset string
local function LoadPtfx(asset)
    RequestNamedPtfxAsset(asset)
    local start = GetGameTimer()
    while not HasNamedPtfxAssetLoaded(asset) do
        if GetGameTimer() - start > 5000 then
            return false
        end
        Wait(0)
    end
    return true
end

---Creates a ptfx at location
---@param ped number
---@param prop number
---@param name string
---@param asset string
---@param placement table
---@param rgb table
local function CreatePtfx(ped, prop, name, asset, placement, rgb)
    local ptfxSpawn = ped
    if prop then
        ptfxSpawn = prop
    end
    local newPtfx = StartNetworkedParticleFxLoopedOnEntityBone(name, ptfxSpawn, placement[1] + 0.0, placement[2] + 0.0, placement[3] + 0.0, placement[4] + 0.0, placement[5] + 0.0, placement[6] + 0.0, GetEntityBoneIndexByName(name, "VFX"), placement[7] + 0.0, 0, 0, 0, 1065353216, 1065353216, 1065353216, 0)
    if newPtfx then
        SetParticleFxLoopedColour(newPtfx, rgb[1] + 0.0, rgb[2] + 0.0, rgb[3] + 0.0)
        if ped == PlayerPedId() then
            insert(cfg.ptfxEntities, newPtfx)
        else
            cfg.ptfxEntitiesTwo[GetPlayerServerId(NetworkGetEntityOwner(ped))] = newPtfx
        end
        cfg.ptfxActive = true
    end
    RemoveNamedPtfxAsset(asset)
end

---Removes existing particle effects
local function RemovePtfx()
    if cfg.ptfxEntities then
        for _, v in pairs(cfg.ptfxEntities) do
            StopParticleFxLooped(v, false)
        end
        cfg.ptfxEntities = {}
    end
end

---Creates a prop at location
---@param ped number
---@param prop string
---@param bone number
---@param placement table
local function CreateProp(ped, prop, bone, placement)
    local coords = GetEntityCoords(ped)
    local newProp = CreateObject(GetHashKey(prop), coords.x, coords.y, coords.z + 0.2, true, true, true)
    if newProp then
        AttachEntityToEntity(newProp, ped, GetPedBoneIndex(ped, bone), placement[1] + 0.0, placement[2] + 0.0, placement[3] + 0.0, placement[4] + 0.0, placement[5] + 0.0, placement[6] + 0.0, true, true, false, true, 1, true)
        insert(cfg.propsEntities, newProp)
        cfg.propActive = true
    end
    SetModelAsNoLongerNeeded(prop)
end

---Removes props
---@param type string
local function RemoveProp(type)
    if type == 'global' then
        if not cfg.propActive then
            for _, v in pairs(GetGamePool('CObject')) do
                if IsEntityAttachedToEntity(PlayerPedId(), v) then
                    SetEntityAsMissionEntity(v, true, true)
                    DeleteObject(v)
                end
            end
        else
            Play.Notification('info', 'Prevented real prop deletion...')
        end
    else
        if cfg.propActive then
            for _, v in pairs(cfg.propsEntities) do
                DeleteObject(v)
            end
            cfg.propsEntities = {}
            cfg.propActive = false
        end
    end
end

---Gets the closest ped by raycast
---@return any
local function GetPlayer()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local offset = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.3, 0.0)
    local rayHandle = StartShapeTestCapsule(coords.x, coords.y, coords.z, offset.x, offset.y, offset.z, 3.0, 12, ped, 7)
    local _, hit, _, _, pedResult = GetShapeTestResult(rayHandle)

    if hit and pedResult ~= 0 and IsPedAPlayer(pedResult) then
        if not IsEntityDead(pedResult) then
            return pedResult
        end
    end
    return false
end

---Sends confirmation to player
---@param target number
---@param shared string
local function Confirmation(target, shared)
    Play.Notification('info', '[E] Accept Request\n[L] Deny Request')
    local hasResolved = false
    SetTimeout(10000, function()
        if not hasResolved then
            hasResolved = true
            TriggerServerEvent('anims:resolveAnimation', target, shared, false)
        end
    end)

    Citizen.CreateThread(function()
        while not hasResolved do
            if IsControlJustPressed(0, cfg.acceptKey) then
                if not hasResolved then
                    if cfg.animActive or cfg.sceneActive then
                        Load.Cancel()
                    end
                    TriggerServerEvent('anims:resolveAnimation', target, shared, true)
                    hasResolved = true
                end
            elseif IsControlJustPressed(0, cfg.denyKey) then
                if not hasResolved then
                    TriggerServerEvent('anims:resolveAnimation', target, shared, false)
                    hasResolved = true
                end
            end
            Wait(5)
        end
    end)
end

---Cancels currently playing animations
local function Cancel()
    if cfg.animDisableMovement then
        cfg.animDisableMovement = false
    end
    if cfg.animDisableLoop then
        cfg.animDisableLoop = false
    end

    if cfg.animActive then
        ClearPedTasks(PlayerPedId())
        cfg.animActive = false
    elseif cfg.sceneActive then
        if cfg.sceneForcedEnd then
            ClearPedTasksImmediately(PlayerPedId())
        else
            ClearPedTasks(PlayerPedId())
        end
        cfg.sceneActive = false
    end

    if cfg.propActive then
       RemoveProp()
       cfg.propActive = false
    end
    if cfg.ptfxActive then
        if cfg.ptfxOwner then
            TriggerServerEvent('anims:syncRemoval')
            cfg.ptfxOwner = false
        end
        RemovePtfx()
        cfg.ptfxActive = false
    end
end

---Loads dictionary
---@param dict string
Load.Dict = LoadDict

---Loads model/prop
---@param model string
Load.Model = LoadModel

---Loads animset/walk
---@param walk string
Load.Walk = LoadWalk

---Loads particle effects
---@param asset string
Load.Ptfx = LoadPtfx

---Creates a ptfx at location
---@param ped number
---@param prop number
---@param name string
---@param asset string
---@param placement table
---@param rgb table
Load.PtfxCreation = CreatePtfx

---Removes existing particle effects
Load.PtfxRemoval = RemovePtfx

---Creates a prop at location
---@param ped number
---@param prop string
---@param bone number
---@param placement table
Load.PropCreation = CreateProp

---Removes props
---@param type string
Load.PropRemoval = RemoveProp

---Gets the closest ped by raycast
---@return any
Load.GetPlayer = GetPlayer

---Sends confirmation to player
---@param target number
---@param shared string
Load.Confirmation = Confirmation

---Cancels currently playing animations
Load.Cancel = Cancel

exports('Load', function()
    return Load
end)

Citizen.CreateThread(function()
    TriggerEvent('chat:addSuggestions', {
        {name = '/' .. cfg.commandNameEmote, help = cfg.commandNameSuggestion, params = {{name = 'emote', help = 'Emote name'}}},
        {name = '/' .. cfg.commandName, help = cfg.commandSuggestion, params = {}}
    })
end)
