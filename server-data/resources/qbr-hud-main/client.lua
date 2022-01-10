local QBCore = exports['qbr-core']:GetCoreObject()
local speed = 0.0
local seatbeltOn = false
local cruiseOn = false
local radarActive = false
local nos = 0
local stress = 0
local hunger = 100
local thirst = 100
local cashAmount = 0
local bankAmount = 0
local isLoggedIn = false

-- Events

RegisterNetEvent('QBCore:Client:OnPlayerUnload')
AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    isLoggedIn = false
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    isLoggedIn = true
end)

RegisterNetEvent('hud:client:UpdateNeeds') -- Triggered in qbr-core
AddEventHandler('hud:client:UpdateNeeds', function(newHunger, newThirst)
    hunger = newHunger
    thirst = newThirst
end)

RegisterNetEvent('hud:client:UpdateStress') -- Add this event with adding stress elsewhere
AddEventHandler('hud:client:UpdateStress', function(newStress)
    stress = newStress
end)

RegisterNetEvent('seatbelt:client:ToggleSeatbelt') -- Triggered in smallresources
AddEventHandler('seatbelt:client:ToggleSeatbelt', function()
    seatbeltOn = not seatbeltOn
end)

RegisterNetEvent('seatbelt:client:ToggleCruise') -- Triggered in smallresources
AddEventHandler('seatbelt:client:ToggleCruise', function()
    cruiseOn = not cruiseOn
end)

RegisterNetEvent('hud:client:UpdateNitrous')
AddEventHandler('hud:client:UpdateNitrous', function(hasNitro, nitroLevel, bool)
    nos = nitroLevel
end)

-- Player HUD
Citizen.CreateThread(function()
    while true do
        Wait(500)
        if LocalPlayer.state['isLoggedIn'] then
            local show = true
            local player = PlayerPedId()
            local playerid = PlayerId()
            --local talking = Citizen.InvokeNative(0xEF6F2A35FAAF2ED7, playerid)
            local talking = SetPlayerTalkingOverride(PlayerId())
            if IsPauseMenuActive() then
                show = false
            end
            SendNUIMessage({
                action = 'hudtick',
                show = show,
                health = GetEntityHealth(player) / 3, -- health in red dead is 300 so dividing by 3 makes it 100 here
                armor = Citizen.InvokeNative(0x2CE311A7, player),
                thirst = thirst,
                hunger = hunger,
                stress = stress,
                voice = Citizen.InvokeNative(0x2F82CAB262C8AE26, playerid),
                talking = talking,
            })
        else
            SendNUIMessage({
                action = 'hudtick',
                show = false,
            })
        end
    end
end)

-- Vehicle HUD
Citizen.CreateThread(function()
    while true do
        Wait(500)
        if LocalPlayer.state['isLoggedIn'] then
            local player = PlayerPedId()
            local inVehicle = IsPedInAnyVehicle(player)
            local vehicle = GetVehiclePedIsIn(player)
            if inVehicle then
                radarActive = true
                local pos = GetEntityCoords(player)
                local speed = GetEntitySpeed(vehicle) * 2.23694
                local street1, street2 = GetStreetNameAtCoord(pos.x, pos.y, pos.z, Citizen.ResultAsInteger(), Citizen.ResultAsInteger())
                local fuel = exports['LegacyFuel']:GetFuel(vehicle)
                SendNUIMessage({
                    action = 'car',
                    show = true,
                    isPaused = IsPauseMenuActive(),
                    direction = GetDirectionText(GetEntityHeading(player)),
                    street1 = GetStreetNameFromHashKey(street1),
                    street2 = GetStreetNameFromHashKey(street2),
                    seatbelt = seatbeltOn,
                    cruise = cruiseOn,
                    speed = math.ceil(speed),
                    nos = nos,
                    fuel = fuel,
                })
            else
                SendNUIMessage({
                    action = 'car',
                    show = true,
                    seatbelt = false,
                })
                radarActive = false
            end
        else
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Wait(1)
          if IsPedOnMount(PlayerPedId()) or IsPedOnVehicle(PlayerPedId()) then
            SetMinimapType(1)
          else
              SetMinimapType(3)
          end
     end
  end)
  
function GetDirectionText(heading)
    if ((heading >= 0 and heading < 45) or (heading >= 315 and heading < 360)) then
        return 'North'
    elseif (heading >= 45 and heading < 135) then
        return 'South'
    elseif (heading >=135 and heading < 225) then
        return 'East'
    elseif (heading >= 225 and heading < 315) then
        return 'West'
    end
end

-- Money HUD

RegisterNetEvent('hud:client:ShowAccounts')
AddEventHandler('hud:client:ShowAccounts', function(type, amount)
    if type == 'cash' then
        SendNUIMessage({
            action = 'show',
            type = 'cash',
            cash = amount,
        })
    else
        SendNUIMessage({
            action = 'show',
            type = 'bank',
            bank = amount,
        })
    end
end)

RegisterNetEvent('hud:client:OnMoneyChange')
AddEventHandler('hud:client:OnMoneyChange', function(type, amount, isMinus)
    QBCore.Functions.GetPlayerData(function(PlayerData)
        cashAmount = PlayerData.money['cash']
        bankAmount = PlayerData.money['bank']
    end)
    SendNUIMessage({
        action = 'update',
        cash = cashAmount,
        bank = bankAmount,
        amount = amount,
        minus = isMinus,
        type = type,
    })
end)

-- Stress Gain

Citizen.CreateThread(function() -- Speeding
    while true do
        if QBCore ~= nil --[[ and isLoggedIn ]] then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                speed = GetEntitySpeed(GetVehiclePedIsIn(ped, false)) * 2.237 --mph
                if speed >= Config.MinimumSpeed then
                    TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
                end
            end
        end
        Citizen.Wait(20000)
    end
end)

Citizen.CreateThread(function() -- Shooting
    while true do
        if QBCore ~= nil --[[ and isLoggedIn ]] then
            if IsPedShooting(PlayerPedId()) then
                if math.random() < Config.StressChance then
                    TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
                end
            end
        end
        Citizen.Wait(6)
    end
end)

-- Stress Screen Effects

Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local Wait = GetEffectInterval(stress)
        if stress >= 100 then
            local ShakeIntensity = GetShakeIntensity(stress)
            local FallRepeat = math.random(2, 4)
            local RagdollTimeout = (FallRepeat * 1750)
            ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', ShakeIntensity)
            SetFlash(0, 0, 500, 3000, 500)

            if not IsPedRagdoll(ped) and IsPedOnFoot(ped) and not IsPedSwimming(ped) then
                local player = PlayerPedId()
                SetPedToRagdollWithFall(player, RagdollTimeout, RagdollTimeout, 1, GetEntityForwardVector(player), 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
            end

            Citizen.Wait(500)
            for i = 1, FallRepeat, 1 do
                Citizen.Wait(750)
                DoScreenFadeOut(200)
                Citizen.Wait(1000)
                DoScreenFadeIn(200)
                ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', ShakeIntensity)
                SetFlash(0, 0, 200, 750, 200)
            end
        elseif stress >= Config.MinimumStress then
            local ShakeIntensity = GetShakeIntensity(stress)
            ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', ShakeIntensity)
            SetFlash(0, 0, 500, 2500, 500)
        end
        Citizen.Wait(Wait)
    end
end)

function GetShakeIntensity(stresslevel)
    local retval = 0.05
    for k, v in pairs(Config.Intensity['shake']) do
        if stresslevel >= v.min and stresslevel <= v.max then
            retval = v.intensity
            break
        end
    end
    return retval
end

function GetEffectInterval(stresslevel)
    local retval = 60000
    for k, v in pairs(Config.EffectInterval) do
        if stresslevel >= v.min and stresslevel <= v.max then
            retval = v.timeout
            break
        end
    end
    return retval
end