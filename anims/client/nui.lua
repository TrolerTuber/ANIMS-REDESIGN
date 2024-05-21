local function animType(data, p)
    if data then
        if data.disableMovement then
            cfg.animDisableMovement = true
        end
        if data.disableLoop then
            cfg.animDisableLoop = true
        end
        if data.dance then
            Play.Animation(data.dance, data.particle, data.prop, p)
        elseif data.scene then
            Play.Scene(data.scene, p)
        elseif data.expression then
            Play.Expression(data.expression, p)
        elseif data.walk then
            Play.Walk(data.walk, p)
        elseif data.shared then
            Play.Shared(data.shared, p)
        end
    end
end

local function enableCancel()
    Citizen.CreateThread(function()
        while cfg.animActive or cfg.sceneActive do
            if IsControlJustPressed(0, cfg.cancelKey) then
                Load.Cancel()
                break
            end
            Citizen.Wait(10)
        end
    end)
end

local function findEmote(emoteName)
    if emoteName then
        local name = emoteName:upper()
        SendNUIMessage({action = 'findEmote', name = name})
    end
end

local function getWalkingStyle(cb)
    local savedWalk = GetResourceKvpString('savedWalk')
    if cb then
        return cb(savedWalk)
    end
    return savedWalk
end

RegisterNUICallback('changeCfg', function(data, cb)
    if data then
        if data.type == 'movement' then
            cfg.animMovement = not data.state
        elseif data.type == 'loop' then
            cfg.animLoop = not data.state
        elseif data.type == 'settings' then
            cfg.animDuration = tonumber(data.duration) or cfg.animDuration
            cfg.cancelKey = tonumber(data.cancel) or cfg.cancelKey
            cfg.defaultEmote = data.emote or cfg.defaultEmote
            cfg.defaultEmoteKey = tonumber(data.key) or cfg.defaultEmoteKey
        end
    end
    cb({})
end)

RegisterNUICallback('cancelAnimation', function(_, cb)
    Load.Cancel()
    cb({})
end)

RegisterNUICallback('removeProps', function(_, cb)
    Load.PropRemoval('global')
    cb({})
end)

RegisterNUICallback('exitPanel', function(_, cb)
    if cfg.panelStatus then
        cfg.panelStatus = false
        SetNuiFocus(false, false)
        SendNUIMessage({action = 'panelStatus', panelStatus = cfg.panelStatus})
    end
    cb({})
end)

RegisterNUICallback('sendNotification', function(data, cb)
    if data then
        Play.Notification(data.type, data.message)
    end
    cb({})
end)

RegisterNUICallback('fetchStorage', function(data, cb)
    if data then
        for _, v in pairs(data) do
            if v == 'loop' then
                cfg.animLoop = true
            elseif v == 'movement' then
                cfg.animMovement = true
            end
        end
        local savedWalk = GetResourceKvpString('savedWalk')
        if savedWalk then
            local p = promise.new()
            Citizen.Wait(cfg.waitBeforeWalk)
            Play.Walk({style = savedWalk}, p)
            local result = Citizen.Await(p)
            if result.passed then
                Play.Notification('info', 'Set old walk style back.')
            end
        end
    end
    cb({})
end)

RegisterNUICallback('beginAnimation', function(data, cb)
    Load.Cancel()
    local p = promise.new()
    animType(data, p)
    p:next(function(result)
        if result.passed then
            if not result.shared then
                enableCancel()
            end
            cb({e = true})
        else
            if result.nearby then cb({e = 'nearby'}) end
            cb({e = false})
        end
    end)
end)

RegisterCommand(cfg.commandName, function()
    cfg.panelStatus = not cfg.panelStatus
    SetNuiFocus(true, true)
    SendNUIMessage({action = 'panelStatus',panelStatus = cfg.panelStatus})
end)

RegisterCommand(cfg.commandNameEmote, function(_, args)
    if args and args[1] then
        return findEmote(args[1])
    end
    Play.Notification('info', 'No emote name set...')
end)

RegisterCommand(cfg.defaultCommand, function()
    if cfg.defaultEmote then
        findEmote(cfg.defaultEmote)
    end
end)



if cfg.keyActive then
    RegisterKeyMapping(cfg.commandName, cfg.keySuggestion, 'keyboard', cfg.keyLetter)
end

AddEventHandler('onResourceStop', function(name)
    if GetCurrentResourceName() == name then
        Load.Cancel()
    end
end)

AddEventHandler('anims:updateCfg', function(_cfg, result)
    if GetCurrentResourceName() == GetInvokingResource() then
        CancelEvent()
        print('Cannot use this event from the same resource!')
        return
    end
    if type(_cfg) ~= "table" then
        print(GetInvokingResource() .. ' tried to update anims cfg but it was not a table')
        CancelEvent()
        return
    end
    local oldCfg = cfg
    for k, v in pairs(_cfg) do
        if cfg[k] and v then
            cfg[k] = v
        end
    end
    print(GetInvokingResource() .. ' updated anims cfg!')
    if result then
        print('Old:' .. json.encode(oldCfg) .. '\nNew: ' .. json.encode(cfg))
    end
end)

exports('PlayEmote', findEmote)
exports('GetWalkingStyle', getWalkingStyle)
