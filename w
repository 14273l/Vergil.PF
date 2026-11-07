-- GENERATED: Vergil ReBorn phantom forces
-- Built from the local backend sources and vergil_reborn_ui.luau.
local function StartAim(...)
-- Actor-aware PF combat backend. All owned hooks and inputs are released on unload.
local options = ...
if type(options) ~= "table" then options = {} end
assert(type(getactorthreads) == "function" and type(run_on_actor_thread) == "function", "Actor dispatch is unavailable")
local threads, G = getactorthreads(), getgenv()
if G.__OC_PFSA_UI then G.__OC_PFSA_UI.unload() end
local actorSource = [==[
local function bootstrap(name)
    local folder = game:GetService("ReplicatedFirst"):FindFirstChild(name)
    if not folder or folder:GetAttribute("UnloadRequested") then return end
    local globals, sharedRuntime = getrenv()._G, getrenv().shared
    local context = globals.__OC_PFSA_GameContext or {}
    local function module(name)
        if sharedRuntime and type(sharedRuntime.require) == "function" then
            local ok, value = pcall(sharedRuntime.require, name)
            if ok and type(value) == "table" then return value end
        end
    end
    local firearm = context.firearmClass or module("FirearmObject")
    local fireRound = context.fireRound or (firearm and firearm.fireRound)
    if not fireRound then
        for i, fn in ipairs(getgc(false)) do
            if type(fn) == "function" then
                local ok, info = pcall(debug.getinfo or getinfo, fn)
                if ok and info.name == "fireRound" and tostring(info.source):find("FirearmObject", 1, true) then fireRound = fn; break end
            end
            if i % 2000 == 0 then task.wait() end
        end
    end
    if not fireRound then return end
    context.fireRound, context.firearmClass = fireRound, firearm
    context.upvalues = context.upvalues or (debug.getupvalues or getupvalues)(fireRound)
    globals.__OC_PFSA_GameContext = context
    local bullets, network, settings
    for _, value in pairs(context.upvalues) do
        if type(value) == "table" then
            if type(value.newBullet) == "function" then bullets = value end
            if type(value.send) == "function" and type(value.getTime) == "function" then network = value end
            if typeof(value.bulletAcceleration) == "Vector3" then settings = value end
        end
    end
    if not bullets or not network or not settings then folder:SetAttribute("Error", "Firing interfaces unavailable"); return end
    -- Resolve potentially-yielding modules before installing anything.
    local characterInterface = module("CharacterInterface")
    local roundSystem = module("RoundSystemClientInterface")
    local crosshairs, notifications, audio = module("HudCrosshairsInterface"), module("HudNotificationInterface"), module("AudioSystem")
    if not folder.Parent or folder:GetAttribute("UnloadRequested") then return end
    if context.aimState and type(context.aimState.uninstall) == "function" then context.aimState.uninstall() end
    local Players, Workspace, RunService = game:GetService("Players"), game:GetService("Workspace"), game:GetService("RunService")
    local state = {active = true, entries = context.entries or {}, connections = {}, pending = {}, localShots = 0, redirected = 0, synced = 0}
    state.extraHooks, state.reloadCache = {}, setmetatable({}, {__mode = "k"})
    context.aimState = state
    local function needsEntries() return folder:GetAttribute("RequestedEnabled") == true or folder:GetAttribute("RageEnabled") == true or folder:GetAttribute("ESPEnabled") == true end
    local feedback = folder:FindFirstChild("Feedback")
    local function soundEnabled(kind)
        return folder:GetAttribute(kind .. "SoundEnabled") == true and (folder:GetAttribute(kind .. "SoundId") or "") ~= ""
    end
    local function replace(owner, key, create)
        if not owner or type(owner[key]) ~= "function" then return end
        local original, rawOriginal = owner[key], rawget(owner, key)
        local hook = create(original)
        owner[key] = hook
        state.extraHooks[#state.extraHooks + 1] = {owner = owner, key = key, rawOriginal = rawOriginal, hook = hook}
    end
    local function reloadAnimations(weapon, original)
        if type(original) ~= "table" then return original end
        local cached = state.reloadCache[weapon]
        if not cached or cached.original ~= original then cached = {original = original, copy = table.clone(original), names = {}}; state.reloadCache[weapon] = cached end
        local current = type(weapon.getCurrentReloadFile) == "function" and weapon:getCurrentReloadFile()
        for name, file in pairs(original) do
            if type(file) == "table" and (tostring(name):lower():find("reload", 1, true) or current and current.reloadName == name) and cached.names[name] ~= file then
                local copy = table.clone(file)
                copy.timescale, copy.resettime = 0.001, 0
                cached.copy[name], cached.names[name] = copy, file
            elseif not cached.names[name] then cached.copy[name] = file
            end
        end
        for name in pairs(cached.copy) do if original[name] == nil then cached.copy[name], cached.names[name] = nil, nil end end
        return cached.copy
    end
    local function refreshEntries()
        local found, seen = {}, {}
        local function add(e)
            if type(e) == "table" and not seen[e] and typeof(e._player) == "Instance" and e._player.Parent == Players then
                seen[e] = true; found[#found + 1] = e
            end
        end
        for _, e in ipairs(state.entries) do add(e) end
        for i, value in ipairs(getgc(true)) do
            if not state.active or not folder.Parent or folder:GetAttribute("UnloadRequested") then return end
            if type(value) == "table" then add(rawget(value, "_replicationObject")); if rawget(value, "_thirdPersonObject") then add(value) end end
            if i % 2500 == 0 then task.wait() end
        end
        state.entries, context.entries = found, found
        folder:SetAttribute("TrackedEntries", #found)
    end
    if #state.entries == 0 and needsEntries() then refreshEntries() end
    if not folder.Parent or folder:GetAttribute("UnloadRequested") then state.active = false; return end
    local refreshQueued = false
    local function scheduleRefresh()
        if refreshQueued or not state.active or not needsEntries() then return end
        refreshQueued = true
        task.delay(0.75, function() refreshQueued = false; if state.active and folder.Parent then refreshEntries() end end)
    end
    state.connections[#state.connections + 1] = Players.PlayerAdded:Connect(scheduleRefresh)
    for _, attribute in ipairs({"RequestedEnabled", "RageEnabled", "ESPEnabled"}) do state.connections[#state.connections + 1] = folder:GetAttributeChangedSignal(attribute):Connect(scheduleRefresh) end
    local characters = Workspace:FindFirstChild("Players")
    if characters then state.connections[#state.connections + 1] = characters.DescendantAdded:Connect(function(o) if o:IsA("Model") then scheduleRefresh() end end) end
    state.connections[#state.connections + 1] = Workspace.ChildAdded:Connect(function(o)
        if o.Name == "Players" then
            characters = o
            state.connections[#state.connections + 1] = o.DescendantAdded:Connect(function(child) if child:IsA("Model") then scheduleRefresh() end end)
            scheduleRefresh()
        end
    end)
    state.connections[#state.connections + 1] = Workspace.ChildRemoved:Connect(function(o) if o == characters then characters = nil end end)
    local viewmodel, espEntries = folder:FindFirstChild("Viewmodel"), folder:FindFirstChild("ESPEntries")
    local espRecords = {}
    local function publishESP()
        local seen, failure = {}, nil
        for _, e in ipairs(state.entries) do
            local ok, err = pcall(function()
                local player, third = e._player, e._thirdPersonObject
                local model = third and third._characterModel
                if player == Players.LocalPlayer or player.Parent ~= Players or not model or not model:IsDescendantOf(Workspace) then return end
                local health, maximum = e:getHealth()
                if type(health) ~= "number" then return end
                local record = espRecords[player]
                if not record then
                    record = Instance.new("Folder"); record.Name = tostring(player.UserId)
                    for _, n in ipairs({"Player", "Character", "RootPart"}) do local v = Instance.new("ObjectValue"); v.Name, v.Parent = n, record end
                    record.Player.Value = player; record.Parent = espEntries; espRecords[player] = record
                end
                seen[player] = true
                record.Character.Value, record.RootPart.Value = model, third._torso or third._rootPart
                record:SetAttribute("Alive", e._alive == true and health > 0)
                record:SetAttribute("Health", health)
                record:SetAttribute("MaxHealth", type(maximum) == "number" and maximum > 0 and maximum or 100)
                record:SetAttribute("IsEnemy", e._isEnemy == true)
                record:SetAttribute("Weapon", third._weaponName or "")
                record:SetAttribute("UpdatedAt", os.clock())
            end)
            if not ok then failure = tostring(err):sub(1, 180) end
        end
        for player, record in pairs(espRecords) do if not seen[player] then record:Destroy(); espRecords[player] = nil end end
        folder:SetAttribute("ESPError", failure)
    end
    local function activeWeapon()
        local character = characterInterface and characterInterface.getCharacterObject()
        local controller = character and character._weaponController
        return controller and controller:getActiveWeapon(), character
    end
    local function publishViewmodel()
        if not characterInterface then return end
        local weapon, character = activeWeapon()
        local camera, model = Workspace.CurrentCamera, weapon and weapon._weaponModel
        local function set(n, v) if typeof(v) ~= "Instance" then v = nil end; if viewmodel[n].Value ~= v then viewmodel[n].Value = v end end
        set("LeftArm", character and character._leftArmModel); set("RightArm", character and character._rightArmModel)
        set("Gun", typeof(model) == "Instance" and camera and model:IsDescendantOf(camera) and model or nil)
        set("Muzzle", weapon and weapon._barrelPart)
        folder:SetAttribute("Ammo", weapon and weapon._magCount or -1)
        folder:SetAttribute("ReserveAmmo", weapon and weapon._spareCount or 0)
        folder:SetAttribute("WeaponName", weapon and (weapon.weaponName or weapon._weaponName) or "")
    end
    local walls = RaycastParams.new()
    walls.FilterType, walls.IgnoreWater = Enum.RaycastFilterType.Exclude, true
    local function ignore(includeCharacters)
        local list = {}
        if Workspace.CurrentCamera then list[#list + 1] = Workspace.CurrentCamera end
        local ignored = Workspace:FindFirstChild("Ignore"); if ignored then list[#list + 1] = ignored end
        local localCharacter = Players.LocalPlayer.Character; if localCharacter then list[#list + 1] = localCharacter end
        if includeCharacters and characters then list[#list + 1] = characters end
        return list
    end
    local function clearRay(from, to)
        return (to - from).Magnitude < 0.001 or Workspace:Raycast(from, to - from, walls) == nil
    end
    local function findOrigin(origin, target)
        walls.FilterDescendantsInstances = ignore(true)
        if clearRay(origin, target) then return origin end
        if not folder:GetAttribute("OriginEnabled") then return end
        local camera = Workspace.CurrentCamera
        if not camera then return end
        local radius = math.clamp(folder:GetAttribute("OriginRadius") or 2, 0, 15)
        local right, up = camera.CFrame.RightVector, camera.CFrame.UpVector
        for _, fraction in ipairs({0.25, 0.5, 1}) do
            for _, direction in ipairs({right, -right, up, -up, (right + up).Unit, (-right + up).Unit, (right - up).Unit, (-right - up).Unit}) do
                local candidate = origin + direction * radius * fraction
                -- Search small offsets first; never cross geometry or exceed 15 studs.
                if clearRay(origin, candidate) and clearRay(candidate, target) then return candidate end
            end
        end
    end
    state.findOrigin = findOrigin
    local function selectTarget(origin, rage, entries)
        local camera = Workspace.CurrentCamera
        if not camera then return end
        local center = camera.ViewportSize * 0.5
        local best, bestDistance = rage and math.huge or (folder:GetAttribute("FOV") or 150), math.huge
        local position, velocity, name, selectedOrigin, selectedEntry
        local function evaluate(entry)
                local health = entry:getHealth()
                if not entry._alive or entry._player == Players.LocalPlayer or entry._player.Parent ~= Players or health <= 0 then return end
                if (rage or folder:GetAttribute("TeamCheck") ~= false) and not entry._isEnemy then return end
                local third = entry._thirdPersonObject
                local hash = third and third._characterModelHash
                local partName = folder:GetAttribute("TargetPart") or "Head"
                if partName == "Random" then partName = math.random(1, 2) == 1 and "Head" or "Torso" end
                local part = hash and (hash[partName] or hash.Head)
                if not part or not part:IsDescendantOf(Workspace) then return end
                local distance = (part.Position - origin).Magnitude
                local maximum = rage and folder:GetAttribute("RageDistance") or folder:GetAttribute("MaxDistance")
                if distance > (maximum or 2000) then return end
                local score
                if rage then score = folder:GetAttribute("RagePriority") == "Lowest health" and health or distance
                else
                    local screen, visible = camera:WorldToViewportPoint(part.Position)
                    if not visible or screen.Z <= 0 then return end
                    score = (Vector2.new(screen.X, screen.Y) - center).Magnitude
                end
                if score > best or score == best and distance >= bestDistance then return end
                local points = {part.Position}
                if rage and folder:GetAttribute("RageMultipoint") ~= false then
                    points[#points + 1] = part.CFrame * Vector3.new(part.Size.X * 0.3, 0, 0)
                    points[#points + 1] = part.CFrame * Vector3.new(-part.Size.X * 0.3, 0, 0)
                    points[#points + 1] = part.CFrame * Vector3.new(0, part.Size.Y * 0.2, 0)
                    local alternate = part == hash.Head and hash.Torso or hash.Head
                    if alternate and alternate:IsDescendantOf(Workspace) then points[#points + 1] = alternate.Position end
                end
                local pos, start
                for _, point in ipairs(points) do
                    local candidate = origin
                    if rage or folder:GetAttribute("WallCheck") ~= false or folder:GetAttribute("OriginEnabled") then candidate = findOrigin(origin, point) end
                    if candidate then pos, start = point, candidate; break end
                end
                if not pos then return end
                local vel = entry._velspring and entry._velspring.t or Vector3.zero
                if folder:GetAttribute("Prediction") == false or typeof(vel) ~= "Vector3" then vel = Vector3.zero
                elseif rage and vel.Magnitude > 400 then vel = vel.Unit * 400
                elseif not rage and vel.Magnitude > 150 then vel = Vector3.zero end
                return {score = score, distance = distance, position = pos, velocity = vel, name = entry._player.Name, origin = start, entry = entry}
        end
        if rage and not entries and folder:GetAttribute("RageTargetLock") ~= false and state.rageLock then
            local ok, locked = pcall(evaluate, state.rageLock)
            if ok and locked then return locked.position, locked.velocity, locked.name, locked.origin, locked.entry end
            state.rageLock = nil
        end
        for _, entry in ipairs(entries or state.entries) do
            local ok, value = pcall(evaluate, entry)
            if ok and value and (value.score < best or value.score == best and value.distance < bestDistance) then
                best, bestDistance, position, velocity, name, selectedOrigin, selectedEntry = value.score, value.distance, value.position, value.velocity, value.name, value.origin, value.entry
            end
        end
        if rage and not entries then state.rageLock = selectedEntry end
        return position, velocity, name, selectedOrigin, selectedEntry
    end
    state.selectTarget = selectTarget
    local function trajectory(origin, position, velocity, speed, gravity, acceleration, life)
        if speed <= 0 or life <= 0 then return end
        local function residual(t)
            local offset = position + velocity * t - origin - gravity * (0.5 * t * t)
            return offset.Magnitude - speed * t - 0.5 * acceleration * t * t, offset
        end
        local low, high = 0, math.max((position - origin).Magnitude / speed, 0.0001)
        local bracketed = false
        for _ = 1, 40 do
            high = math.min(high, life)
            if residual(high) <= 0 then bracketed = true; break end
            if high >= life then return end
            high *= 1.2
        end
        if not bracketed then return end
        for _ = 1, 22 do local mid = (low + high) * 0.5; if residual(mid) > 0 then low = mid else high = mid end end
        local _, offset = residual((low + high) * 0.5)
        if offset.Magnitude > 0.0001 then return offset.Unit end
    end
    state.trajectory = trajectory
    local oldBullet, oldSend = bullets.newBullet, network.send
    local bulletHook, sendHook
    bulletHook = function(data, ...)
        if state.active and type(data) == "table" and data.extra and data.extra.firearmObject then
            state.localShots += 1
            if folder:GetAttribute("Enabled") or folder:GetAttribute("RageEnabled") then
                local ok, direction, targetName, acceleration, origin = pcall(function()
                    local source, now = data.position, os.clock()
                    local batch = state.volley
                    local position, velocity, name, start
                    local rage = folder:GetAttribute("RageEnabled") == true
                    if folder:GetAttribute("OriginEnabled") and batch and batch.rage == rage and batch.uniqueId == data.extra.uniqueId and batch.source == source and now - batch.time < 0.02 then
                        position, velocity, name, start = batch.position, batch.velocity, batch.name, batch.origin
                    else
                        position, velocity, name, start = selectTarget(source, rage)
                        if folder:GetAttribute("OriginEnabled") and position then state.volley = {rage = rage, uniqueId = data.extra.uniqueId, source = source, time = now, position = position, velocity = velocity, name = name, origin = start} end
                    end
                    if not position then return end
                    local speed = data.velocity.Magnitude
                    if speed <= 0 then return end
                    local accel = (data.acceleration - settings.bulletAcceleration):Dot(data.velocity.Unit)
                    return trajectory(start, position, velocity, speed, settings.bulletAcceleration, accel, data.life or 3), name, accel, start
                end)
                if ok and direction and data.extra.bulletTicket ~= nil then
                    state.pending[data.extra.bulletTicket] = {direction = direction, origin = origin ~= data.position and origin or nil, uniqueId = data.extra.uniqueId, time = os.clock()}
                    data.position = origin
                    data.velocity = direction * data.velocity.Magnitude
                    data.acceleration = settings.bulletAcceleration + direction * acceleration
                    state.redirected += 1
                    folder:SetAttribute("LastTarget", targetName)
                elseif not ok then folder:SetAttribute("Error", tostring(direction):sub(1, 180)) end
            end
        end
        if state.active and type(data) == "table" and data.extra and data.extra.firearmObject and feedback then
            local now, previous = os.clock(), state.feedbackShot
            if soundEnabled("Shoot") and not (previous and previous.uniqueId == data.extra.uniqueId and now - previous.time < 0.02) then
                state.feedbackShot = {uniqueId = data.extra.uniqueId, time = now}
                feedback:Fire("shoot")
            end
            if folder:GetAttribute("TracersEnabled") then
                local visual = typeof(data.visualorigin) == "Vector3" and data.visualorigin or data.position
                feedback:Fire("trace", visual, data.position, data.velocity, data.acceleration, data.life or 3)
                if folder:GetAttribute("ReplaceTracers") ~= false then data.tracerless = true end
            end
        end
        return oldBullet(data, ...)
    end
    local function syncPacket(packet, uniqueId)
        if type(packet) ~= "table" or type(packet.bullets) ~= "table" then return end
        local commonOrigin, mismatch
        for _, bullet in ipairs(packet.bullets) do
            local pending = state.pending[bullet[2]]
            if pending and (pending.uniqueId == nil or pending.uniqueId == uniqueId) then
                bullet[1] = pending.direction
                if commonOrigin and commonOrigin ~= pending.origin then mismatch = true else commonOrigin = pending.origin end
                state.pending[bullet[2]] = nil; state.synced += 1
            end
        end
        if commonOrigin and not mismatch and typeof(packet.firepos) == "Vector3" then packet.firepos = commonOrigin end
        local now = os.clock()
        for ticket, pending in pairs(state.pending) do if now - pending.time > 5 then state.pending[ticket] = nil end end
    end
    state.syncPacket = syncPacket
    sendHook = function(self, command, ...)
        local args = table.pack(...)
        if state.active and command == "newbullets" then syncPacket(args[2], args[1]) end
        return oldSend(self, command, table.unpack(args, 1, args.n))
    end
    local oldStat, oldRawStat, oldImpulse, oldStep, statHook, impulseHook, stepHook
    local function resetSpread(weapon)
        local s = weapon._spreadSpring; if s then s.p = Vector3.zero; s.v = Vector3.zero; s.a = Vector3.zero end
        local c = weapon._chokeSpring; if c then c.p = 0; c.v = 0; c.a = 0 end
    end
    if firearm and type(firearm.getWeaponStat) == "function" and type(firearm.impulseSprings) == "function" and type(firearm.step) == "function" then
        state.weaponClass = firearm
        oldStat, oldRawStat, oldImpulse, oldStep = firearm.getWeaponStat, rawget(firearm, "getWeaponStat"), firearm.impulseSprings, firearm.step
        statHook = function(self, key, ...)
            if state.active then
                if folder:GetAttribute("HideMuzzleEffects") and key == "nomuzzleeffects" then return true end
                if key == "firevolume" and soundEnabled("Shoot") then return 0 end
                if key == "animations" and folder:GetAttribute("InstantReload") then return reloadAnimations(self, oldStat(self, key, ...)) end
                if folder:GetAttribute("NoSpread") then
                    if key == "hipfirespread" then return 0 end
                    if key == "spread" or key == "aimchoke" or key == "variablechoke" then return nil end
                end
            end
            return oldStat(self, key, ...)
        end
        impulseHook = function(self, ...)
            local stability, suppress = self._firemodeStability, state.active and folder:GetAttribute("NoRecoil")
            if suppress then self._firemodeStability = 1 end
            local result = table.pack(pcall(oldImpulse, self, ...))
            if suppress then self._firemodeStability = stability end
            if state.active and folder:GetAttribute("NoSpread") then resetSpread(self) end
            if not result[1] then error(result[2], 0) end
            return table.unpack(result, 2, result.n)
        end
        stepHook = function(self, ...) if state.active and folder:GetAttribute("NoSpread") then resetSpread(self) end; return oldStep(self, ...) end
    end
    replace(firearm, "getAnimLength", function(original)
        return function(self, name, ...)
            if state.active and folder:GetAttribute("InstantReload") then
                local current = type(self.getCurrentReloadFile) == "function" and self:getCurrentReloadFile()
                if tostring(name):lower():find("reload", 1, true) or current and current.reloadName == name then return 0 end
            end
            return original(self, name, ...)
        end
    end)
    replace(firearm, "animationStateCheck", function(original)
        return function(self, stateName, ...)
            if state.active and folder:GetAttribute("InstantReload") and (stateName == "chamberedReloading" or stateName == "unchamberedReloading") then return true end
            return original(self, stateName, ...)
        end
    end)
    replace(crosshairs, "fireHitmarker", function(original)
        return function(...) if state.active and feedback and soundEnabled("Hit") then feedback:Fire("hit") end; return original(...) end
    end)
    replace(notifications, "bigAward", function(original)
        return function(reason, ...)
            if state.active and feedback and soundEnabled("Kill") and (reason == "kill" or reason == "infharvest") then feedback:Fire("kill") end
            return original(reason, ...)
        end
    end)
    replace(audio, "playSound", function(original)
        return function(name, ...) if state.active and name == "hitmarker" and soundEnabled("Hit") then return end; return original(name, ...) end
    end)
    replace(audio, "play", function(original)
        return function(name, ...)
            if state.active then
                if (name == "killshot" or name == "headshotkill") and soundEnabled("Kill") then return end
                if (name == "1PsniperBass" or name == "1PsniperEcho") and soundEnabled("Shoot") then return end
            end
            return original(name, ...)
        end
    end)
    -- Rage autofire is target-driven, not a crosshair trigger. Planning stays
    -- separate from native weapon calls so tests never need to fire live shots.
    local function planAutofire(t, now, target, weapon, blocked, manual, interval, automatic)
        local actions = {}
        if t.held and (blocked or manual or not target or not automatic and target ~= t.target or weapon ~= t.held or not automatic and now >= t.releaseAt) then
            if blocked or not manual or weapon ~= t.held then actions[#actions + 1] = {weapon = t.held, down = false} end
            t.held = nil
        end
        if blocked or manual or not target or not weapon then t.target, t.candidate = nil, nil; return actions end
        t.target, t.candidate = target, weapon
        if not t.held and now >= (t.nextShot or 0) then
            t.held, t.releaseAt, t.nextShot = weapon, automatic and math.huge or now + 0.06, now + interval
            actions[#actions + 1] = {weapon = weapon, down = true}
        end
        return actions
    end
    state.planAutofire, state.autofire = planAutofire, {}
    local function readyForInput(weapon)
        -- canFire() requires _auto/_burst to already be set. Never use it to
        -- decide whether to press shoot; native shoot() owns the firing gate.
        return weapon and type(weapon.shoot) == "function" and not weapon._knifePart and (weapon._magCount or 0) > 0
            and (type(weapon.isEquipped) ~= "function" or weapon:isEquipped())
            and (type(weapon.isEquipping) ~= "function" or not weapon:isEquipping())
            and (type(weapon.isReloading) ~= "function" or not weapon:isReloading())
    end
    state.readyForInput = readyForInput
    local function targetAlive(entry)
        if type(entry) ~= "table" or typeof(entry._player) ~= "Instance" or entry._player.Parent ~= Players or not entry._alive or not entry._isEnemy then return false end
        local ok, health = pcall(entry.getHealth, entry)
        return ok and type(health) == "number" and health > 0
    end
    state.targetAlive = targetAlive
    local rageElapsed = 0
    local function updateRage(now, dt)
        local enabled = folder:GetAttribute("RageEnabled") == true and folder:GetAttribute("RageAutoFire") ~= false
        local blocked, manual = not enabled or folder:GetAttribute("RageBlocked") ~= false or roundSystem and roundSystem.roundLock == true, folder:GetAttribute("RageManual") == true
        local weapon, target, automatic, statusWeapon
        if enabled then weapon = activeWeapon() end
        statusWeapon = weapon
        if enabled and not blocked and not manual then
            if weapon and not weapon._knifePart and (weapon._magCount or 0) <= 0 and (weapon._spareCount or 0) > 0
                and folder:GetAttribute("RageAutoReload") ~= false and type(weapon.reload) == "function"
                and (type(weapon.isReloading) ~= "function" or not weapon:isReloading())
                and (type(weapon.isStateReloading) ~= "function" or not weapon:isStateReloading()) and now >= (state.reloadRequestAt or 0) then
                state.reloadRequestAt = now + 0.3
                weapon:reload()
            end
            if readyForInput(weapon) then
                automatic = type(weapon.getFiremode) == "function" and weapon:getFiremode() == true
                rageElapsed += dt
                local interval = 1 / math.clamp(folder:GetAttribute("RageScanHz") or 40, 10, 60)
                if rageElapsed >= interval then
                    rageElapsed %= interval
                    local camera = Workspace.CurrentCamera
                    local barrel = weapon._barrelPart
                    local origin = typeof(barrel) == "Instance" and barrel.Position or camera and camera.CFrame.Position
                    if origin then local _, _, _, _, selected = selectTarget(origin, true); target = selected end
                elseif state.autofire.held and targetAlive(state.autofire.target) then target = state.autofire.target end
            else weapon = nil end
        end
        local actions = planAutofire(state.autofire, now, target, weapon, blocked, manual,
            math.clamp(folder:GetAttribute("RageInterval") or 100, 50, 1000) / 1000, automatic)
        for _, action in ipairs(actions) do
            local ok, err = pcall(action.weapon.shoot, action.weapon, action.down)
            if not ok then state.autofire.held = nil; folder:SetAttribute("RageError", tostring(err):sub(1, 180)) end
            if ok and action.down and automatic and action.weapon._auto == false then state.autofire.held = nil end
        end
        local status = "SEARCHING"
        if not folder:GetAttribute("RageEnabled") then status = "OFF"
        elseif folder:GetAttribute("RageBlocked") or roundSystem and roundSystem.roundLock then status = "PAUSED"
        elseif folder:GetAttribute("RageAutoFire") == false then status = "AIM ONLY"
        elseif manual then status = "MANUAL"
        elseif statusWeapon and (statusWeapon._magCount or 0) <= 0 then status = (statusWeapon._spareCount or 0) > 0 and "RELOADING" or "NO AMMO"
        elseif state.autofire.held then status = "FIRING"
        elseif target then status = "TARGET" end
        folder:SetAttribute("RageState", status)
        folder:SetAttribute("RageTarget", target and target._player.Name or state.autofire.target and state.autofire.target._player.Name or "")
    end
    state.uninstall = function()
        if not state.active then return end
        state.active = false
        if state.autofire.held then pcall(state.autofire.held.shoot, state.autofire.held, false); state.autofire.held = nil end
        if bullets.newBullet == bulletHook then bullets.newBullet = oldBullet end
        if network.send == sendHook then network.send = oldSend end
        if firearm and statHook then
            if rawget(firearm, "getWeaponStat") == statHook then rawset(firearm, "getWeaponStat", oldRawStat) end
            if firearm.impulseSprings == impulseHook then firearm.impulseSprings = oldImpulse end
            if firearm.step == stepHook then firearm.step = oldStep end
        end
        for index = #state.extraHooks, 1, -1 do
            local entry = state.extraHooks[index]
            if entry.owner[entry.key] == entry.hook then rawset(entry.owner, entry.key, entry.rawOriginal) end
        end
        for _, c in ipairs(state.connections) do c:Disconnect() end
        state.pending, state.volley, state.weaponClass = {}, nil, nil
        folder:SetAttribute("Enabled", false); folder:SetAttribute("Installed", false); folder:SetAttribute("WeaponHooksReady", false); folder:SetAttribute("Unloaded", true)
    end
    if not folder.Parent or folder:GetAttribute("UnloadRequested") then state.uninstall(); return end
    bullets.newBullet, network.send = bulletHook, sendHook
    if statHook then firearm.getWeaponStat, firearm.impulseSprings, firearm.step = statHook, impulseHook, stepHook end
    state.connections[#state.connections + 1] = folder:GetAttributeChangedSignal("UnloadRequested"):Connect(function() if folder:GetAttribute("UnloadRequested") then state.uninstall() end end)
    state.connections[#state.connections + 1] = folder.Destroying:Connect(state.uninstall)
    for _, attribute in ipairs({"RageEnabled", "RagePriority", "RageTargetLock", "RageMultipoint", "TargetPart"}) do
        state.connections[#state.connections + 1] = folder:GetAttributeChangedSignal(attribute):Connect(function()
            state.rageLock, state.volley = nil, nil
            if not folder:GetAttribute("RageEnabled") then folder:SetAttribute("RageState", "OFF"); folder:SetAttribute("RageTarget", "") end
        end)
    end
    local espElapsed, viewElapsed = 0, 0
    state.connections[#state.connections + 1] = RunService.Heartbeat:Connect(function(dt)
        if not state.active then return end
        if folder:GetAttribute("ESPEnabled") then espElapsed += dt; if espElapsed >= 0.1 then espElapsed %= 0.1; publishESP() end end
        viewElapsed += dt
        if viewElapsed >= 0.05 and (folder:GetAttribute("ViewmodelEnabled") or folder:GetAttribute("IndicatorEnabled") or folder:GetAttribute("StickerEnabled")) then
            viewElapsed %= 0.05
            local ok, err = pcall(publishViewmodel); folder:SetAttribute("ViewmodelError", not ok and tostring(err):sub(1, 180) or nil)
        end
        if folder:GetAttribute("RageEnabled") or state.autofire.held then
            local ok, err = pcall(updateRage, os.clock(), dt)
            if not ok then
                if state.autofire.held then pcall(state.autofire.held.shoot, state.autofire.held, false); state.autofire.held = nil end
                folder:SetAttribute("RageError", tostring(err):sub(1, 180))
            end
        end
    end)
    folder:SetAttribute("Installed", true)
    folder:SetAttribute("Enabled", folder:GetAttribute("RequestedEnabled") ~= false)
    folder:SetAttribute("WeaponHooksReady", statHook ~= nil)
    folder:SetAttribute("WeaponError", not statHook and "Weapon interfaces unavailable" or nil)
    folder:SetAttribute("Error", nil)
    print("[Vergil] Gameplay hooks installed.")
end
]==]
local folder = Instance.new("Folder")
folder.Name = "OC_PFSA_" .. game:GetService("HttpService"):GenerateGUID(false)
local defaults = {Enabled = false, Installed = false, RequestedEnabled = options.Enabled == true, FOV = options.FOV or 150, DrawFOV = options.DrawFOV == true,
    FOVColor = options.FOVColor or Color3.fromRGB(176, 188, 240), FOVAlpha = options.FOVAlpha or 0.35,
    TeamCheck = false, WallCheck = false, Prediction = false,
    TargetPart = "Head", MaxDistance = 2000, NoRecoil = false, NoSpread = false, HideMuzzleEffects = false, ESPEnabled = false, WeaponHooksReady = false,
    OriginEnabled = false, OriginRadius = 2, RageEnabled = false, RageAutoFire = false, RageInterval = 100, RageDistance = 2000,
    RagePriority = "Closest", RageBlocked = true, RageManual = false, RageAutoReload = false, InstantReload = false,
    RageTargetLock = false, RageMultipoint = false, RageScanHz = 30, RageState = "OFF", RageTarget = "", Ammo = -1, ReserveAmmo = 0, WeaponName = "",
    ViewmodelEnabled = false, IndicatorEnabled = false, StickerEnabled = false,
    ShootSoundEnabled = false, ShootSoundId = "", HitSoundEnabled = false, HitSoundId = "", KillSoundEnabled = false, KillSoundId = "",
    TracersEnabled = false, ReplaceTracers = false}
for n, v in pairs(defaults) do folder:SetAttribute(n, v) end
for _, n in ipairs({"ESPEntries", "Viewmodel"}) do local f = Instance.new("Folder"); f.Name, f.Parent = n, folder end
local feedback = Instance.new("BindableEvent"); feedback.Name, feedback.Parent = "Feedback", folder
for _, n in ipairs({"Gun", "LeftArm", "RightArm", "Muzzle"}) do local v = Instance.new("ObjectValue"); v.Name, v.Parent = n, folder.Viewmodel end
folder.Parent = game:GetService("ReplicatedFirst")
local gui = Instance.new("ScreenGui")
gui.Name, gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder = "PF Silent Aim", true, false, 60
gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
local circle = Instance.new("Frame")
circle.Name, circle.AnchorPoint, circle.Position, circle.BackgroundTransparency, circle.Parent = "FOVCircle", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), 1, gui
Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
local stroke = Instance.new("UIStroke", circle)
stroke.Name = "FOVOutline"
local function assign(object, key, value) if object[key] ~= value then object[key] = value end end
local connections, cleaned = {}, false
local ui = {folder = folder, gui = gui, circle = circle, stroke = stroke}
G.__OC_PFSA_UI = ui
local function update()
    if cleaned then return end
    circle.Visible = folder:GetAttribute("DrawFOV") == true and folder:GetAttribute("Installed") == true
        and folder:GetAttribute("Enabled") == true and folder:GetAttribute("RageEnabled") ~= true
    local radius = math.clamp(folder:GetAttribute("FOV") or 150, 0, 600)
    if radius == 0 then circle.Visible = false end
    local alpha = math.clamp(folder:GetAttribute("FOVAlpha") or 0.35, 0, 1)
    local color = folder:GetAttribute("FOVColor") or Color3.fromRGB(176, 188, 240)
    assign(circle, "Size", UDim2.fromOffset(radius * 2, radius * 2))
    assign(circle, "BackgroundTransparency", 1)
    assign(stroke, "Color", color); assign(stroke, "Transparency", alpha); assign(stroke, "Thickness", 1)
end
local function cleanup()
    if cleaned then return end
    cleaned = true
    for _, c in ipairs(connections) do c:Disconnect() end
    gui:Destroy(); folder:Destroy()
    if G.__OC_PFSA_UI == ui then G.__OC_PFSA_UI = nil end
end
local ranges = {FOV = {0,600}, FOVAlpha = {0,1},
    OriginRadius = {0,15}, RageDistance = {50,3000}, MaxDistance = {50,3000}, RageScanHz = {10,60}, RageInterval = {50,1000}}
local choices = {TargetPart = {"Head","Torso","Random"}, RagePriority = {"Closest","Lowest health"}}
ui.set = function(name, value)
    if cleaned or defaults[name] == nil then return false end
    local kind = typeof(defaults[name])
    if kind == "boolean" then value = value == true
    elseif kind == "number" then
        if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return false end
        if ranges[name] then value = math.clamp(value, ranges[name][1], ranges[name][2]) end
    elseif typeof(value) ~= kind then return false end
    if choices[name] and not table.find(choices[name], value) then return false end
    folder:SetAttribute(name, value); return true
end
ui.setEnabled = function(value)
    if cleaned then return end
    folder:SetAttribute("RequestedEnabled", value == true)
    folder:SetAttribute("Enabled", value == true and folder:GetAttribute("Installed") == true)
end
ui.unload = function()
    if cleaned then return end
    folder:SetAttribute("Enabled", false); folder:SetAttribute("ESPEnabled", false); folder:SetAttribute("RageEnabled", false); folder:SetAttribute("UnloadRequested", true)
    if not folder:GetAttribute("Installed") then cleanup() end
end
connections[#connections + 1] = folder.AttributeChanged:Connect(function(n)
    if n == "Unloaded" and folder:GetAttribute(n) then cleanup()
    elseif n == "Enabled" or n == "Installed" or n == "RageEnabled" or n == "DrawFOV" or n:sub(1, 3) == "FOV" then update() end
end)
if not options.NoControls then connections[#connections + 1] = game:GetService("UserInputService").InputBegan:Connect(function(i, processed) if not processed and i.KeyCode == Enum.KeyCode.RightControl then ui.setEnabled(not folder:GetAttribute("Enabled")) end end) end
update()
ui.updateFOV = update
for _, thread in ipairs(threads) do local ok, err = pcall(run_on_actor_thread, thread, actorSource .. string.format("\nbootstrap(%q)", folder.Name)); if not ok then warn("[Vergil] Actor dispatch: " .. tostring(err)) end end
task.delay(15, function() if not cleaned and not folder:GetAttribute("Installed") then folder:SetAttribute("Error", "Gameplay Actor unavailable") end end)
return ui
end

local function StartChams(...)
-- Cached full-model viewport chams; no per-frame clones or GC scans.
local options = ...
if type(options) ~= "table" then options = {} end
local G, Players, Workspace, RunService = getgenv(), game:GetService("Players"), game:GetService("Workspace"), game:GetService("RunService")
if G.__ViewportChamsCleanup then pcall(G.__ViewportChamsCleanup) end
local cfg = {Enabled = options.Enabled == true, TeamCheck = false, EnemyColor = Color3.fromRGB(255, 70, 80), AllyColor = Color3.fromRGB(65, 180, 255),
    UnknownColor = Color3.fromRGB(255, 200, 60), FillTransparency = 0, TintStrength = 0, PoseHz = 24, SelectionHz = 5, MaxDistance = 1200, MaxVisibleModels = 12}
local state = {alive = true, version = 3, renderer = "Viewport", records = {}, connections = {}, rootConnections = {}, teams = {}, cloneQueue = {},
    stats = {active = 0, tracked = 0, updates = 0, builds = 0, lastUpdateMs = 0, lastPoseMs = 0}}
G.__ViewportChamsState, G.__ViewportChamsConfig = state, cfg
local function enabled() return cfg.Enabled end
local function disconnect(list) for _, c in ipairs(list) do c:Disconnect() end; table.clear(list) end
local bridge = Instance.new("Folder"); bridge.Name = "PFChamsBridge_" .. game:GetService("HttpService"):GenerateGUID(false); bridge.Parent = game:GetService("ReplicatedFirst")
local localTeam = Instance.new("ObjectValue"); localTeam.Name, localTeam.Parent = "LocalTeamFolder", bridge
local gui = Instance.new("ScreenGui"); gui.Name, gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder = "ViewportChams", true, false, 50
gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
local viewport = Instance.new("ViewportFrame"); viewport.Name, viewport.Size, viewport.BackgroundTransparency, viewport.BorderSizePixel = "ChamsViewport", UDim2.fromScale(1, 1), 1, 0
viewport.Visible = false
viewport.Ambient, viewport.LightColor, viewport.LightDirection, viewport.Parent = Color3.new(1, 1, 1), Color3.new(1, 1, 1), Vector3.new(-1, -1, -1), gui
local world = Instance.new("WorldModel"); world.Name, world.Parent = "ChamsWorld", viewport
local camera = Instance.new("Camera"); camera.Parent, viewport.CurrentCamera = viewport, camera
state.gui, state.bridge, state.container, state.viewport, state.camera = gui, bridge, world, viewport, camera
state.renderToken = "ViewportChams_" .. game:GetService("HttpService"):GenerateGUID(false)
local function pose(d)
    for _, pair in ipairs(d.parts or {}) do
        local source, copy = pair.source, pair.copy
        if source.Parent and copy.Parent then
            local transparency = math.max(cfg.FillTransparency, 1 - (1 - source.Transparency) * (1 - source.LocalTransparencyModifier))
            if copy.Transparency ~= transparency then copy.Transparency = transparency end
            if transparency < 1 then if copy.CFrame ~= source.CFrame then copy.CFrame = source.CFrame end; if copy.Size ~= source.Size then copy.Size = source.Size end end
        elseif copy.Parent then copy.Transparency = 1 end
    end
    for _, pair in ipairs(d.bones or {}) do if pair.source.Parent and pair.copy.Parent then pair.copy.Transform = pair.source.Transform end end
end
local function appearance(d)
    for _, pair in ipairs(d.parts or {}) do
        local source, copy = pair.source, pair.copy
        if source.Parent and copy.Parent then
            local color = source.Color:Lerp(d.color or cfg.EnemyColor, math.clamp(cfg.TintStrength, 0, 1))
            if copy.Color ~= color then copy.Color = color end
            if copy.Material ~= source.Material then copy.Material = source.Material end
            if copy.Reflectance ~= source.Reflectance then copy.Reflectance = source.Reflectance end
        end
    end
end
local function build(d)
    if not state.alive or state.records[d.model] ~= d or not d.model.Parent then return end
    local archivable = d.model.Archivable
    local ok, clone = pcall(function() d.model.Archivable = true; return d.model:Clone() end)
    d.model.Archivable = archivable
    if not ok or not clone then d.retryAfter = os.clock() + 2; return end
    local parts, bones, lookup = {}, {}, {}
    local function match(source, copy)
        local buckets = {}
        for _, child in ipairs(source:GetChildren()) do local key = child.ClassName .. "|" .. child.Name; buckets[key] = buckets[key] or {next = 1}; table.insert(buckets[key], child) end
        for _, child in ipairs(copy:GetChildren()) do
            local bucket = buckets[child.ClassName .. "|" .. child.Name]; local original = bucket and bucket[bucket.next]
            if original then
                bucket.next += 1
                if original:IsA("BasePart") then local p = {source = original, copy = child}; parts[#parts + 1] = p; lookup[original] = p
                elseif original:IsA("Bone") then bones[#bones + 1] = {source = original, copy = child} end
                match(original, child)
            end
        end
    end
    match(d.model, clone)
    for _, o in ipairs(clone:GetDescendants()) do
        if o:IsA("BasePart") then o.Anchored, o.CanCollide, o.CanTouch, o.CanQuery, o.CastShadow, o.LocalTransparencyModifier = true, false, false, false, false, 0
        elseif o:IsA("Humanoid") then o.DisplayDistanceType, o.AutoRotate = Enum.HumanoidDisplayDistanceType.None, false; pcall(function() o.EvaluateStateMachine = false end)
        elseif o:IsA("LuaSourceContainer") or o:IsA("JointInstance") or o:IsA("Constraint") or o:IsA("WeldConstraint") or o:IsA("Animator") or o:IsA("AnimationController")
            or o:IsA("Sound") or o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Beam") or o:IsA("Light") or o:IsA("BillboardGui") or o:IsA("SurfaceGui") or o:IsA("ProximityPrompt") or o:IsA("ClickDetector") then o:Destroy() end
    end
    if d.clone then d.clone:Destroy() end
    d.clone, d.parts, d.bones, d.lookup, d.dirty = clone, parts, bones, lookup, false
    state.stats.builds += 1; pose(d); appearance(d); if enabled() and d.selected then clone.Parent = world end
end
local function enqueue(d)
    if not state.alive or not enabled() or not d.selected or d.queued or (d.retryAfter and os.clock() < d.retryAfter) then return end
    d.queued = true; state.cloneQueue[#state.cloneQueue + 1] = d
    if state.worker then return end
    state.worker = task.defer(function()
        while state.alive and #state.cloneQueue > 0 do
            local nextData = table.remove(state.cloneQueue, 1); nextData.queued = false
            if enabled() and nextData.selected and state.records[nextData.model] == nextData then build(nextData) end
            if #state.cloneQueue > 0 then RunService.Heartbeat:Wait() end
        end
        state.worker = nil
    end)
end
local function remove(model)
    local d = state.records[model]; if not d then return end
    disconnect(d.connections); if d.clone then d.clone:Destroy() end; state.records[model] = nil; state.stats.tracked -= 1
end
local function add(model, team)
    if not model:IsA("Model") or state.records[model] then return end
    local d = {model = model, team = team, part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true), dirty = true, bodyDirty = true, connections = {}}
    state.records[model] = d; state.stats.tracked += 1
    local function visual(o) return o:IsA("BasePart") or o:IsA("Decal") or o:IsA("Texture") or o:IsA("SpecialMesh") or o:IsA("SurfaceAppearance") or o:IsA("Clothing") or o:IsA("Bone") end
    d.connections[#d.connections + 1] = model.DescendantAdded:Connect(function(o) if o:IsA("BasePart") then d.bodyDirty = true; if not d.part or not d.part.Parent then d.part = o end end; if visual(o) then d.dirty = true end end)
    d.connections[#d.connections + 1] = model.DescendantRemoving:Connect(function(o) if o:IsA("BasePart") then d.bodyDirty = true end; if o == d.part then d.part = nil end; local p = d.lookup and d.lookup[o]; if p and p.copy.Parent then p.copy.Transparency = 1 end; if visual(o) then d.dirty = true end end)
end
local function unhook(team)
    if state.teams[team] then disconnect(state.teams[team]); state.teams[team] = nil end
    for model, d in pairs(state.records) do if d.team == team then remove(model) end end
end
local function hook(team)
    if not team:IsA("Folder") or state.teams[team] then return end
    local list = {}; state.teams[team] = list
    for _, model in ipairs(team:GetChildren()) do add(model, team) end
    list[#list + 1] = team.ChildAdded:Connect(function(model) add(model, team) end); list[#list + 1] = team.ChildRemoved:Connect(remove)
end
local function bind(root)
    if state.root == root then return end
    disconnect(state.rootConnections); for team in pairs(state.teams) do unhook(team) end; state.root = root
    if not root then return end
    for _, team in ipairs(root:GetChildren()) do hook(team) end
    state.rootConnections[#state.rootConnections + 1] = root.ChildAdded:Connect(hook); state.rootConnections[#state.rootConnections + 1] = root.ChildRemoved:Connect(unhook)
end
local candidates = {}
local visibilityParams = RaycastParams.new()
visibilityParams.FilterType, visibilityParams.IgnoreWater = Enum.RaycastFilterType.Exclude, true
local function isOccluded(data, main)
    if not main or not data.model.Parent then return false end
    if data.bodyDirty or not data.bodyParts then
        data.bodyParts, data.bodyDirty = {}, false
        for _, part in ipairs(data.model:GetChildren()) do if part:IsA("BasePart") and part.Transparency < 1 then data.bodyParts[#data.bodyParts + 1] = part end end
        table.sort(data.bodyParts, function(a,b) return a.Size.X*a.Size.Y*a.Size.Z > b.Size.X*b.Size.Y*b.Size.Z end)
    end
    local found = false
    for _, part in ipairs(data.bodyParts) do
        if part.Parent and part.Transparency < 1 then
            local screen, onScreen = main:WorldToViewportPoint(part.Position)
            if onScreen and screen.Z > 0 then
                found = true
                local ignore = {main, data.model}
                if state.root then ignore[#ignore+1] = state.root end
                local effects = Workspace:FindFirstChild("Ignore"); if effects then ignore[#ignore+1] = effects end
                if Players.LocalPlayer.Character then ignore[#ignore+1] = Players.LocalPlayer.Character end
                local hit, opaque
                for _ = 1, 4 do
                    visibilityParams.FilterDescendantsInstances = ignore
                    hit = Workspace:Raycast(main.CFrame.Position, part.Position-main.CFrame.Position, visibilityParams)
                    if not hit then return false end
                    if hit.Instance:IsA("BasePart") and math.max(hit.Instance.Transparency, hit.Instance.LocalTransparencyModifier) >= 0.35 then ignore[#ignore+1] = hit.Instance
                    else opaque = true; break end
                end
                if not opaque then return false end
            end
        end
    end
    return found
end
local function selectModels()
    if not state.alive or not enabled() then return end
    local main = Workspace.CurrentCamera; if not main then return end
    local started, own = os.clock(), localTeam.Value; table.clear(candidates)
    for model, d in pairs(state.records) do
        if model.Parent ~= d.team then remove(model)
        else
            d.selected = false
            if d.part and d.part.Parent and model ~= Players.LocalPlayer.Character and (not cfg.TeamCheck or own and d.team ~= own) then
                local screen = main:WorldToViewportPoint(d.part.Position); local distance = (main.CFrame.Position - d.part.Position).Magnitude
                if distance <= cfg.MaxDistance and screen.Z > 0 and screen.X >= -100 and screen.Y >= -100 and screen.X <= main.ViewportSize.X + 100 and screen.Y <= main.ViewportSize.Y + 100 then
                    d.distance, d.color = distance, not own and cfg.UnknownColor or (d.team == own and cfg.AllyColor or cfg.EnemyColor); candidates[#candidates + 1] = d
                end
            end
        end
    end
    table.sort(candidates, function(a, b) return a.distance < b.distance end)
    local selected = 0
    for _, data in ipairs(candidates) do
        if selected >= math.max(0, math.floor(cfg.MaxVisibleModels)) then break end
        if isOccluded(data, main) then data.selected = true; selected += 1 end
    end
    local active = 0
    for _, d in pairs(state.records) do
        if d.selected then
            if d.dirty or not d.clone then enqueue(d) end
            if d.clone then appearance(d); if d.clone.Parent ~= world then pose(d); d.clone.Parent = world end; active += 1 end
        elseif d.clone then d.clone.Parent = nil end
    end
    state.stats.active, state.stats.lastUpdateMs = active, (os.clock() - started) * 1000; state.stats.updates += 1
    viewport.Visible = active > 0
end
local cleanup
cleanup = function()
    if not state.alive then return end
    state.alive = false; RunService:UnbindFromRenderStep(state.renderToken)
    if state.worker then pcall(task.cancel, state.worker) end
    disconnect(state.connections); disconnect(state.rootConnections); for team in pairs(state.teams) do unhook(team) end; for model in pairs(state.records) do remove(model) end
    bridge:Destroy(); world:Destroy(); gui:Destroy(); table.clear(candidates); table.clear(state.cloneQueue)
    if G.__ViewportChamsCleanup == cleanup then G.__ViewportChamsCleanup = nil end
    if G.__ViewportChamsState == state then G.__ViewportChamsState = nil; G.__ViewportChamsConfig = nil end
end
G.__ViewportChamsCleanup = cleanup
local selectionElapsed, poseElapsed, visibilityElapsed = 0, 0, 0
RunService:BindToRenderStep(state.renderToken, Enum.RenderPriority.Camera.Value + 1, function(dt)
    if not state.alive or not enabled() then return end
    local main = Workspace.CurrentCamera; if not main then viewport.Visible = false; return end
    camera.CFrame = main.CFrame
    if camera.FieldOfView ~= main.FieldOfView then camera.FieldOfView = main.FieldOfView end
    if camera.FieldOfViewMode ~= main.FieldOfViewMode then camera.FieldOfViewMode = main.FieldOfViewMode end
end)
state.connections[#state.connections + 1] = RunService.Heartbeat:Connect(function(dt)
    if not state.alive or not enabled() then return end
    local main = Workspace.CurrentCamera; if not main then return end
    selectionElapsed += dt; poseElapsed += dt
    if selectionElapsed >= 1 / math.clamp(cfg.SelectionHz, 1, 10) then selectionElapsed %= 1 / math.clamp(cfg.SelectionHz, 1, 10); selectModels() end
    if poseElapsed >= 1 / math.clamp(cfg.PoseHz, 10, 60) then
        poseElapsed %= 1 / math.clamp(cfg.PoseHz, 10, 60); local started = os.clock()
        for _, d in ipairs(candidates) do if d.selected and d.clone and state.records[d.model] == d then pose(d) end end
        state.stats.lastPoseMs = (os.clock() - started) * 1000
    end
    visibilityElapsed += dt
    if visibilityElapsed >= 0.1 then
        visibilityElapsed %= 0.1
        local active = 0
        for _, data in ipairs(candidates) do
            if data.selected and state.records[data.model] == data then
                if not isOccluded(data, main) then data.selected = false; if data.clone then data.clone.Parent = nil end
                elseif data.clone and data.clone.Parent == world then active += 1 end
            end
        end
        state.stats.active, viewport.Visible = active, active > 0
    end
end)
state.connections[#state.connections + 1] = Workspace.ChildAdded:Connect(function(o) if o.Name == "Players" then bind(o) end end)
state.connections[#state.connections + 1] = Workspace.ChildRemoved:Connect(function(o) if o == state.root then bind(nil) end end)
state.connections[#state.connections + 1] = localTeam:GetPropertyChangedSignal("Value"):Connect(selectModels)
bind(Workspace:FindFirstChild("Players"))
local actorSource = [==[
local function resolve(name)
    local bridge = game:GetService("ReplicatedFirst"):FindFirstChild(name)
    local shared = getrenv().shared
    if not bridge or not shared or type(shared.require) ~= "function" then return end
    local ok, team = pcall(shared.require, "TeamConfig"); if not ok or type(team.getTeamFolder) ~= "function" then return end
    local globals, player = getrenv()._G, game:GetService("Players").LocalPlayer
    if globals.__ViewportChamsTeamObserver then globals.__ViewportChamsTeamObserver.stop() end
    local observer = {alive = true, connections = {}}; globals.__ViewportChamsTeamObserver = observer
    observer.stop = function() if not observer.alive then return end; observer.alive = false; for _, c in ipairs(observer.connections) do c:Disconnect() end; if globals.__ViewportChamsTeamObserver == observer then globals.__ViewportChamsTeamObserver = nil end end
    local function update() if not observer.alive or not bridge.Parent then return end; local ok, folder = pcall(team.getTeamFolder, player.TeamColor); bridge.LocalTeamFolder.Value = ok and typeof(folder) == "Instance" and folder or nil end
    observer.connections[#observer.connections + 1] = player:GetPropertyChangedSignal("TeamColor"):Connect(update)
    observer.connections[#observer.connections + 1] = game:GetService("Workspace").ChildAdded:Connect(function(o) if o.Name == "Players" then task.defer(update) end end)
    observer.connections[#observer.connections + 1] = bridge.Destroying:Connect(observer.stop); update()
end
]==]
if getactorthreads and run_on_actor_thread then for _, t in ipairs(getactorthreads()) do pcall(run_on_actor_thread, t, actorSource .. string.format("\nresolve(%q)", bridge.Name)) end end
local controller = {state = state, config = cfg, unload = cleanup}
controller.isOccluded = function(model, main) return isOccluded(state.records[model] or {model=model,bodyDirty=true}, main or Workspace.CurrentCamera) end
controller.refresh = selectModels
controller.setEnabled = function(v) if not state.alive then return end; cfg.Enabled = v == true; viewport.Visible = enabled(); if enabled() then selectModels() else for _, d in pairs(state.records) do if d.clone then d.clone.Parent = nil end end; state.stats.active = 0 end end
controller.set = function(n, v) if cfg[n] ~= nil then cfg[n] = v end end
return controller
end

local function StartESP(...)
-- Cached PF ESP using Actor-provided player/model/health references.
local options = ...
if type(options) ~= "table" then options = {} end
local G, Workspace, RunService = getgenv(), game:GetService("Workspace"), game:GetService("RunService")
local bridge = assert(options.Bridge, "ESP bridge missing")
local entries = assert(bridge:FindFirstChild("ESPEntries"), "ESP entries missing")
if G.__VergilPFESP then G.__VergilPFESP.unload() end
local white = Color3.new(1, 1, 1)
local cfg = {Enabled = options.Enabled == true, TeamCheck = false, Distance = 2000, UpdateHz = 24, MaxTargets = 24,
    Boxes = {Enabled = false, Style = "Corners", ["Bounding Box"] = {Enabled = false, IncludeAcsessories = false, BoxX = 0, BoxY = 0},
        ["Box Glow"] = {Enabled = false, Top = white, Bot = white, Transparency = {0.95, 0.95}}, Gradients = {Top = white, Bot = white},
        Filled = {Enabled = false, Top = white, Bot = white, Transparency = {1, 0.95}}},
    Bars = {["Health Bar"] = {Enabled = false, Top = Color3.fromRGB(0, 255, 0), Mid = Color3.fromRGB(255, 170, 0), Bot = Color3.fromRGB(255, 0, 0)}},
    Texts = {Name = {Enabled = false, Color = white}, Distance = {Enabled = false, Color = Color3.fromRGB(205, 210, 225)}, Weapon = {Enabled = false, Color = white}}}
local state = {alive = true, records = {}, connections = {}, revision = 1, stats = {active = 0, tracked = 0, lastUpdateMs = 0}}
local controller = {state = state, config = cfg, Table = cfg}
G.__VergilPFESP = controller
local gui = Instance.new("ScreenGui")
gui.Name, gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder, gui.ZIndexBehavior = "Vergil PF ESP", true, false, 65, Enum.ZIndexBehavior.Global
gui.Parent = options.Parent or (gethui and gethui()) or game:GetService("CoreGui")
state.gui = gui
local nameFont, smallFont
local startFonts
local function create(class, props, parent)
    local o = Instance.new(class); for k, v in pairs(props) do o[k] = v end; o.Parent = parent; return o
end
local function disconnect(list) for _, c in ipairs(list) do c:Disconnect() end; table.clear(list) end
local function text(parent, size)
    return create("TextLabel", {BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", TextSize = size, Font = Enum.Font.Code,
        TextColor3 = white, TextStrokeColor3 = Color3.new(0, 0, 0), TextStrokeTransparency = 0.35, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6,
        Size = UDim2.new(1, 80, 0, 14), AnchorPoint = Vector2.new(0.5, 0)}, parent)
end
local function add(record)
    if not state.alive or state.records[record] or not record:IsA("Folder") then return end
    local root = create("Frame", {BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false}, gui)
    local glow = create("ImageLabel", {BackgroundTransparency = 1, Image = "rbxassetid://110204605000367", ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(21, 21, 79, 79), ResampleMode = Enum.ResamplerMode.Pixelated, Position = UDim2.fromOffset(-21, -21), Size = UDim2.new(1, 42, 1, 42), ZIndex = 1}, root)
    local fill = create("Frame", {BorderSizePixel = 0, BackgroundColor3 = white, Size = UDim2.fromScale(1, 1), ZIndex = 2}, root)
    local outline = create("Frame", {BackgroundTransparency = 1, Visible = false}, root)
    local inline = create("Frame", {BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 4}, root)
    local stroke = create("UIStroke", {Thickness = 1, Color = white, BorderStrokePosition = Enum.BorderStrokePosition.Inner, LineJoinMode = Enum.LineJoinMode.Miter}, inline)
    local cornerHolder = create("Frame", {BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 4}, root)
    local corners = {}
    for index = 1, 8 do corners[index] = create("Frame", {BackgroundColor3 = white, BorderSizePixel = 0, ZIndex = 4}, cornerHolder) end
    local name, distance, weapon = text(root, 12), text(root, 9), text(root, 9)
    name.Position = UDim2.new(0.5, 0, 0, -17)
    local healthOutline = create("Frame", {BorderSizePixel = 0, BackgroundColor3 = Color3.new(0, 0, 0), Position = UDim2.fromOffset(-6, -1), Size = UDim2.new(0, 3, 1, 2), ZIndex = 5}, root)
    local health = create("Frame", {BorderSizePixel = 0, BackgroundColor3 = white, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 1, 1, -1), Size = UDim2.new(0, 1, 1, -2), ZIndex = 6}, healthOutline)
    local healthText = text(root, 9)
    healthText.AnchorPoint, healthText.Size, healthText.TextXAlignment = Vector2.new(1, 0.5), UDim2.fromOffset(35, 14), Enum.TextXAlignment.Right
    local data = {root = root, glow = glow, fill = fill, outline = outline, inline = inline, name = name, distance = distance, weapon = weapon,
        healthOutline = healthOutline, health = health, healthText = healthText, cornerHolder = cornerHolder, corners = corners, record = record, parts = {}, connections = {}, dirty = true}
    data.glowGradient, data.fillGradient, data.boxGradient, data.healthGradient = create("UIGradient", {Rotation = 90}, glow), create("UIGradient", {Rotation = 90}, fill), create("UIGradient", {Rotation = 90}, stroke), create("UIGradient", {Rotation = 90}, health)
    state.records[record] = data; state.stats.tracked += 1
end
local function remove(record)
    local data = state.records[record]; if not data then return end
    disconnect(data.connections); data.root:Destroy(); state.records[record] = nil; state.stats.tracked -= 1
end
local function bind(data, character)
    if data.character == character then return end
    disconnect(data.connections); data.character, data.dirty = character, true; table.clear(data.parts)
    if character then
        local function dirty() data.dirty = true end
        data.connections[#data.connections + 1] = character.DescendantAdded:Connect(dirty)
        data.connections[#data.connections + 1] = character.DescendantRemoving:Connect(dirty)
    end
end
local function box(data, camera)
    local bounds = cfg.Boxes["Bounding Box"]
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    if bounds.Enabled then
        if data.dirty or data.include ~= bounds.IncludeAcsessories then
            table.clear(data.parts); data.dirty, data.include = false, bounds.IncludeAcsessories
            for _, p in ipairs(data.character:GetDescendants()) do
                if p:IsA("BasePart") and (p.Parent == data.character or data.include and p:FindFirstAncestorOfClass("Accessory")) then data.parts[#data.parts + 1] = p end
            end
        end
        for _, p in ipairs(data.parts) do
            if p.Parent and p.Transparency < 1 then
                local half = p.Size * 0.5
                for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
                    local point = camera:WorldToViewportPoint(p.CFrame * Vector3.new(half.X * x, half.Y * y, half.Z * z))
                    if point.Z <= 0.1 then return end
                    minX, minY, maxX, maxY = math.min(minX, point.X), math.min(minY, point.Y), math.max(maxX, point.X), math.max(maxY, point.Y)
                end end end
            end
        end
    else
        local point = camera:WorldToViewportPoint(data.rootPart.Position); if point.Z <= 0.1 then return end
        local focal = camera.ViewportSize.Y / (2 * math.tan(math.rad(camera.FieldOfView) * 0.5))
        local w, h = 3.5 * focal / point.Z, 5.5 * focal / point.Z
        minX, minY, maxX, maxY = point.X - w * 0.5, point.Y - h * 0.5, point.X + w * 0.5, point.Y + h * 0.5
    end
    if minX == math.huge then return end
    minX -= bounds.BoxX * 0.5; maxX += bounds.BoxX * 0.5; minY -= bounds.BoxY * 0.5; maxY += bounds.BoxY * 0.5
    if maxX < 0 or maxY < 0 or minX > camera.ViewportSize.X or minY > camera.ViewportSize.Y then return end
    return math.floor(minX), math.floor(minY), math.max(1, math.floor(maxX - minX)), math.max(1, math.floor(maxY - minY))
end
local function sequence(t) return NumberSequence.new({NumberSequenceKeypoint.new(0, math.clamp(t[1], 0, 1)), NumberSequenceKeypoint.new(1, math.clamp(t[2], 0, 1))}) end
local function appearance(d)
    if d.revision == state.revision then return end
    d.revision = state.revision
    local b, t, h = cfg.Boxes, cfg.Texts, cfg.Bars["Health Bar"]
    d.glow.Visible, d.fill.Visible, d.inline.Visible, d.outline.Visible = b.Enabled and b["Box Glow"].Enabled, b.Enabled and b.Filled.Enabled, b.Enabled and b.Style == "Full", false
    d.cornerHolder.Visible = b.Enabled and b.Style == "Corners"
    for index, corner in ipairs(d.corners) do corner.BackgroundColor3 = index <= 4 and b.Gradients.Top or b.Gradients.Bot end
    d.glowGradient.Color, d.glowGradient.Transparency = ColorSequence.new(b["Box Glow"].Top, b["Box Glow"].Bot), sequence(b["Box Glow"].Transparency)
    d.fillGradient.Color, d.fillGradient.Transparency = ColorSequence.new(b.Filled.Top, b.Filled.Bot), sequence(b.Filled.Transparency)
    d.boxGradient.Color = ColorSequence.new(b.Gradients.Top, b.Gradients.Bot)
    d.name.Visible, d.distance.Visible = t.Name.Enabled, t.Distance.Enabled
    d.name.TextColor3, d.distance.TextColor3, d.weapon.TextColor3 = t.Name.Color, t.Distance.Color, t.Weapon.Color
    d.distance.Position, d.weapon.Position = UDim2.new(0.5, 0, 1, 2), UDim2.new(0.5, 0, 1, t.Distance.Enabled and 15 or 2)
    d.healthOutline.Visible, d.healthText.Visible = h.Enabled, h.Enabled
    d.healthGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, h.Top), ColorSequenceKeypoint.new(0.5, h.Mid), ColorSequenceKeypoint.new(1, h.Bot)})
    if nameFont then d.name.FontFace = nameFont end
    if smallFont then d.distance.FontFace = smallFont; d.weapon.FontFace = smallFont; d.healthText.FontFace = smallFont end
end
local function assign(o, k, v) if o[k] ~= v then o[k] = v end end
local function sizeCorners(d, width, height)
    local length = math.max(1, math.min(18, width * 0.25, height * 0.2))
    for index, corner in ipairs(d.corners) do
        local right = index == 3 or index == 4 or index == 7 or index == 8
        local bottom = index >= 5
        local horizontal = index % 2 == 1
        assign(corner, "AnchorPoint", Vector2.new(right and 1 or 0, bottom and 1 or 0))
        assign(corner, "Position", UDim2.fromScale(right and 1 or 0, bottom and 1 or 0))
        assign(corner, "Size", UDim2.fromOffset(horizontal and length or 1, horizontal and 1 or length))
    end
end
local candidates, elapsed = {}, 0
local function update(dt)
    if not state.alive then return end
    if not cfg.Enabled then return end
    if not bridge.Parent or not bridge:GetAttribute("Installed") then for _, d in pairs(state.records) do if d.root.Visible then d.root.Visible = false end end; state.stats.active = 0; return end
    elapsed += dt; local interval = 1 / math.clamp(cfg.UpdateHz, 10, 60); if elapsed < interval then return end; elapsed %= interval
    local started, camera = os.clock(), Workspace.CurrentCamera
    table.clear(candidates)
    for record, d in pairs(state.records) do
        d.drawn = false
        local model, owner, root = record:FindFirstChild("Character"), record:FindFirstChild("Player"), record:FindFirstChild("RootPart")
        bind(d, model and model.Value); d.rootPart, d.player = root and root.Value, owner and owner.Value
        local updated = record:GetAttribute("UpdatedAt")
        if camera and d.character and d.character:IsDescendantOf(Workspace) and d.rootPart and d.rootPart:IsDescendantOf(Workspace) and d.player and d.player.Parent
            and record:GetAttribute("Alive") and updated and os.clock() - updated < 1 and (not cfg.TeamCheck or record:GetAttribute("IsEnemy")) then
            d.distanceValue = (camera.CFrame.Position - d.rootPart.Position).Magnitude
            if d.distanceValue <= cfg.Distance then candidates[#candidates + 1] = d end
        end
    end
    table.sort(candidates, function(a, b) return a.distanceValue < b.distanceValue end)
    local active = 0
    for _, d in ipairs(candidates) do
        if active >= cfg.MaxTargets then break end
        local x, y, w, h = box(d, camera)
        if x then
            appearance(d); assign(d.root, "Position", UDim2.fromOffset(x, y)); assign(d.root, "Size", UDim2.fromOffset(w, h))
            if d.cornerWidth ~= w or d.cornerHeight ~= h then sizeCorners(d, w, h); d.cornerWidth, d.cornerHeight = w, h end
            assign(d.name, "Text", d.player.DisplayName); assign(d.distance, "Text", string.format("%d st", math.floor(d.distanceValue)))
            local weapon = d.record:GetAttribute("Weapon") or ""; d.weapon.Visible = cfg.Texts.Weapon.Enabled and weapon ~= ""; assign(d.weapon, "Text", weapon)
            local health, maximum = d.record:GetAttribute("Health") or 0, math.max(1, d.record:GetAttribute("MaxHealth") or 100)
            local ratio = math.clamp(health / maximum, 0, 1)
            d.healthText.Visible = cfg.Bars["Health Bar"].Enabled and ratio < 1
            assign(d.health, "Size", UDim2.new(0, 1, ratio, -2 * ratio)); assign(d.healthText, "Text", tostring(math.floor(health))); assign(d.healthText, "Position", UDim2.new(0, -9, 1 - ratio, 0))
            assign(d.root, "Visible", true); d.drawn = true; active += 1
        end
    end
    for _, d in pairs(state.records) do if not d.drawn then assign(d.root, "Visible", false) end end
    state.stats.active, state.stats.lastUpdateMs = active, (os.clock() - started) * 1000
end
controller.unload = function()
    if not state.alive then return end
    state.alive = false; if bridge.Parent then bridge:SetAttribute("ESPEnabled", false) end
    disconnect(state.connections); for record in pairs(state.records) do remove(record) end; gui:Destroy(); table.clear(candidates)
    if state.fontWorker then pcall(task.cancel, state.fontWorker) end
    if G.__VergilPFESP == controller then G.__VergilPFESP = nil end
end
controller.setEnabled = function(v) if state.alive then cfg.Enabled = v == true; bridge:SetAttribute("ESPEnabled", cfg.Enabled); if cfg.Enabled and startFonts then startFonts() end; if not cfg.Enabled then for _, d in pairs(state.records) do d.root.Visible = false end; state.stats.active = 0 end; elapsed = 1 end end
controller.set = function(path, value)
    if not state.alive then return end
    local keys, target = string.split(path, "."), cfg
    for i = 1, #keys - 1 do target = target[keys[i]]; if type(target) ~= "table" then return end end
    local key, current = keys[#keys], target[keys[#keys]]
    if current == nil then return false end
    if key == "Transparency" and type(current) == "table" then
        if type(value) ~= "table" or type(value[1]) ~= "number" or type(value[2]) ~= "number" or value[1] ~= value[1] or value[2] ~= value[2] then return false end
        value = {math.clamp(value[1], 0, 1), math.clamp(value[2], 0, 1)}
    end
    if type(current) == "boolean" then value = value == true
    elseif type(current) == "number" then if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return false end
    elseif typeof(current) ~= typeof(value) then return false end
    if path == "Boxes.Style" and not table.find({"Corners", "Full"}, value) then return false end
    if path == "Distance" then value = math.clamp(value, 1, 7520)
    elseif path == "UpdateHz" then value = math.clamp(value, 10, 60)
    elseif path == "MaxTargets" then value = math.clamp(math.floor(value), 1, 64) end
    target[key] = value; state.revision += 1; elapsed = 1; return true
end
for _, record in ipairs(entries:GetChildren()) do add(record) end
state.connections[#state.connections + 1] = entries.ChildAdded:Connect(add); state.connections[#state.connections + 1] = entries.ChildRemoved:Connect(remove)
state.connections[#state.connections + 1] = bridge.Destroying:Connect(controller.unload); state.connections[#state.connections + 1] = RunService.RenderStepped:Connect(update)
controller.setEnabled(cfg.Enabled)
if options.CustomFonts ~= false and isfile and writefile and getcustomasset then
    startFonts = function()
    if state.fontsStarted or not state.alive then return end
    state.fontsStarted = true
    state.fontWorker = task.defer(function()
        local function font(name, url)
            local file, definition = "vergil_esp_" .. name .. ".ttf", "vergil_esp_" .. name .. ".font"
            if not isfile(file) then local data = game:HttpGet(url); assert(#data > 1000); if not state.alive then return end; writefile(file, data) end
            if not state.alive then return end
            writefile(definition, game:GetService("HttpService"):JSONEncode({name = name, faces = {{name = "Normal", weight = 400, style = "normal", assetId = getcustomasset(file)}}}))
            return Font.new(getcustomasset(definition), Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        end
        local ok, f = pcall(font, "tahoma_bold", "https://raw.githubusercontent.com/sametexe001/luas/refs/heads/main/fonts/TAHOMA-8PT-BOLD-WINDOWS-XP.TTF"); if ok and state.alive then nameFont = f end
        if not state.alive then return end
        ok, f = pcall(font, "smallest_pixel", "https://raw.githubusercontent.com/sametexe001/luas/main/smallest_pixel-7.ttf"); if ok and state.alive then smallFont = f; state.revision += 1 end
        state.fontWorker = nil
    end)
    end
    if cfg.Enabled then startFonts() end
end
return controller
end

local function StartViewmodel(...)
-- Reversible first-person materials and arm/hand visibility; no world models.
local options = ...
if type(options) ~= "table" then options = {} end
local G, Workspace, RunService = getgenv(), game:GetService("Workspace"), game:GetService("RunService")
local bridge = assert(options.Bridge, "Viewmodel bridge missing")
local references = assert(bridge:FindFirstChild("Viewmodel"), "Viewmodel references missing")
if G.__VergilPFViewmodel then G.__VergilPFViewmodel.unload() end
local cfg = {Enabled = false, Material = "ForceField", Color = Color3.fromRGB(176, 188, 240), HideArms = false}
local materials = {ForceField = Enum.Material.ForceField, Neon = Enum.Material.Neon}
local state = {alive = true, roots = {}, connections = {}, renderToken = "VergilViewmodel_" .. game:GetService("HttpService"):GenerateGUID(false)}
local controller = {state = state, config = cfg}
G.__VergilPFViewmodel = controller
local function disconnect(list) for _, c in ipairs(list) do c:Disconnect() end; table.clear(list) end
local function capture(data, object)
    if data.lookup[object] then return end
    local original = {}
    if object:IsA("BasePart") then
        if data.arms then original.LocalTransparencyModifier = object.LocalTransparencyModifier
        else
            original.Material, original.Color, original.Reflectance, original.MaterialVariant = object.Material, object.Color, object.Reflectance, object.MaterialVariant
            if object:IsA("MeshPart") then original.TextureID = object.TextureID end
        end
    elseif object:IsA("Decal") or object:IsA("Texture") then original.Transparency = object.Transparency
    elseif not data.arms and object:IsA("SpecialMesh") then original.TextureId = object.TextureId
    elseif not data.arms and object:IsA("SurfaceAppearance") then original.Parent = object.Parent
    else return end
    local record = {object = object, original = original, applied = {}}
    data.lookup[object] = record; data.records[#data.records + 1] = record
end
local function assign(record, key, value)
    local current, previous = record.object[key], record.applied[key]
    if previous == nil or current ~= previous then record.original[key] = current end
    if current ~= value then record.object[key] = value; record.applied[key] = value end
end
local function restore(data)
    for _, record in ipairs(data.records) do
        pcall(function()
            for key, value in pairs(record.applied) do if record.object[key] == value then record.object[key] = record.original[key] end end
            table.clear(record.applied)
            if record.detached and record.object.Parent == nil then local parent = record.original.Parent; if parent and parent.Parent then record.object.Parent = parent end end
            record.detached = false
        end)
    end
    data.applied = false
end
local function bind(name, root)
    local previous = state.roots[name]
    if previous and previous.root == root then return end
    if previous then disconnect(previous.connections); restore(previous) end
    state.roots[name] = nil
    if not root then return end
    local data = {root = root, arms = name ~= "Gun", records = {}, lookup = {}, connections = {}}
    state.roots[name] = data; capture(data, root)
    for _, o in ipairs(root:GetDescendants()) do capture(data, o) end
    data.connections[#data.connections + 1] = root.DescendantAdded:Connect(function(o) if state.alive and state.roots[name] == data then capture(data, o) end end)
end
local function apply(data, camera)
    local enabled = (data.arms and cfg.HideArms or not data.arms and cfg.Enabled) and camera and data.root:IsDescendantOf(camera)
    if not enabled then if data.applied then restore(data) end; return end
    data.applied = true
    for _, record in ipairs(data.records) do
        local o = record.object
        if o.Parent and o:IsDescendantOf(data.root) then
            if o:IsA("BasePart") then
                if data.arms then assign(record, "LocalTransparencyModifier", 1)
                else
                    assign(record, "Material", materials[cfg.Material]); assign(record, "MaterialVariant", ""); assign(record, "Color", cfg.Color); assign(record, "Reflectance", 0)
                    if o:IsA("MeshPart") then assign(record, "TextureID", "") end
                end
            elseif o:IsA("Decal") or o:IsA("Texture") then assign(record, "Transparency", 1)
            elseif o:IsA("SpecialMesh") then assign(record, "TextureId", "")
            elseif o:IsA("SurfaceAppearance") then record.original.Parent = o.Parent; o.Parent = nil; record.detached = true end
        end
    end
end
local function update(force) if state.alive and (force or cfg.Enabled or cfg.HideArms) then for _, data in pairs(state.roots) do apply(data, Workspace.CurrentCamera) end end end
local function sync() if bridge.Parent then bridge:SetAttribute("ViewmodelEnabled", cfg.Enabled or cfg.HideArms) end end
controller.unload = function()
    if not state.alive then return end
    state.alive = false; RunService:UnbindFromRenderStep(state.renderToken); disconnect(state.connections)
    if bridge.Parent then bridge:SetAttribute("ViewmodelEnabled", false) end
    for _, data in pairs(state.roots) do disconnect(data.connections); restore(data) end
    table.clear(state.roots); if G.__VergilPFViewmodel == controller then G.__VergilPFViewmodel = nil end
end
controller.setEnabled = function(v) if state.alive then cfg.Enabled = v == true; sync(); update(true) end end
controller.set = function(n, v)
    if not state.alive or cfg[n] == nil or n == "Material" and not materials[v] or n == "Color" and typeof(v) ~= "Color3" then return end
    if type(cfg[n]) == "boolean" then v = v == true end
    cfg[n] = v; sync(); update(true)
end
for _, name in ipairs({"Gun", "LeftArm", "RightArm"}) do
    local reference = references:FindFirstChild(name)
    if reference then bind(name, reference.Value); state.connections[#state.connections + 1] = reference:GetPropertyChangedSignal("Value"):Connect(function() if state.alive then bind(name, reference.Value); update() end end) end
end
state.connections[#state.connections + 1] = bridge.Destroying:Connect(controller.unload)
RunService:BindToRenderStep(state.renderToken, Enum.RenderPriority.Camera.Value + 3, function() update(false) end)
return controller
end

local function StartMisc(...)
-- FOV lock follows replacement cameras and restores values/listeners on unload.
local options = ...
if type(options) ~= "table" then options = {} end
local G, RunService = getgenv(), game:GetService("RunService")
local source, bridge = options.CameraSource or game:GetService("Workspace"), options.Bridge
local lighting = options.LightingSource or game:GetService("Lighting")
local effectParent = options.EffectParent or game:GetService("Lighting")
if G.__VergilPFMisc then G.__VergilPFMisc.unload() end
local cfg = {FOVEnabled = false, FOV = 120, HideMuzzleEffects = false,
    MotionBlur = false, MotionStrength = 8,
    BloomEnabled = false, BloomIntensity = 0.4, BloomSize = 24, BloomThreshold = 1.1,
    SunRaysEnabled = false, SunRaysIntensity = 0.08,
    AmbientEnabled = false, Ambient = Color3.fromRGB(128, 128, 128), OutdoorAmbient = Color3.fromRGB(128, 128, 128),
    FogEnabled = false, FogDistance = 2000, FogColor = Color3.fromRGB(190, 210, 235)}
local token = "VergilMisc_" .. game:GetService("HttpService"):GenerateGUID(false)
local state = {alive = true, connections = {}, renderToken = token, worldToken = token .. "_World", effects = {}, lightingRecords = {}, blur = 0}
local controller = {state = state, config = cfg}
G.__VergilPFMisc = controller
local function effect(name, class)
    local object = Instance.new(class)
    object.Name, object.Enabled, object.Parent = token .. "_" .. name, false, effectParent
    state.effects[name] = object
    return object
end
local blur = effect("Motion", "BlurEffect")
local bloom, rays = effect("Bloom", "BloomEffect"), effect("SunRays", "SunRaysEffect")
local function restore(data)
    if not data or data.original == nil then return end
    data.writing = true
    if data.applied and math.abs(data.camera.FieldOfView - data.applied) < 0.001 then data.camera.FieldOfView = data.original end
    data.writing, data.original, data.applied = false, nil, nil
end
local function apply(data)
    if not state.alive or not cfg.FOVEnabled or not data or data.writing then return end
    if data.original == nil then data.original = data.camera.FieldOfView end
    local value = math.clamp(cfg.FOV, 40, 120) -- Roblox clamps a requested 200 to 120.
    data.writing = true
    if math.abs(data.camera.FieldOfView - value) > 0.001 then data.camera.FieldOfView = value end
    data.applied, data.writing = data.camera.FieldOfView, false
end
local function bind(camera)
    if state.cameraData and state.cameraData.camera == camera then return end
    local old = state.cameraData
    if old then old.connection:Disconnect(); restore(old) end
    state.cameraData = nil
    state.motionCamera, state.motionFrame, state.blur = nil, nil, 0
    blur.Size = 0
    if not camera then return end
    local data = {camera = camera}; state.cameraData = data
    data.connection = camera:GetPropertyChangedSignal("FieldOfView"):Connect(function() apply(data) end)
    apply(data)
end
local function equal(a, b)
    if type(a) == "number" and type(b) == "number" then return math.abs(a - b) < 0.001 end
    return a == b
end
local function desiredLighting(key)
    if key == "FogStart" then return cfg.FogEnabled and 0 or nil end
    if key == "FogEnd" then return cfg.FogEnabled and cfg.FogDistance or nil end
    if key == "FogColor" then return cfg.FogEnabled and cfg.FogColor or nil end
    if not cfg.AmbientEnabled then return nil end
    return cfg[key]
end
local function restoreLighting(record)
    if record.original == nil then return end
    record.writing = true
    if equal(lighting[record.key], record.applied) then lighting[record.key] = record.original end
    record.original, record.applied, record.writing = nil, nil, false
end
local function applyLighting(record)
    if not state.alive or record.writing then return end
    local value = desiredLighting(record.key)
    if value == nil then restoreLighting(record); return end
    local current = lighting[record.key]
    if record.original == nil or record.applied ~= nil and not equal(current, record.applied) then record.original = current end
    record.writing = true
    if not equal(current, value) then lighting[record.key] = value end
    record.applied, record.writing = lighting[record.key], false
end
local function updateWorld()
    bloom.Enabled, bloom.Intensity, bloom.Size, bloom.Threshold = cfg.BloomEnabled, cfg.BloomIntensity, cfg.BloomSize, cfg.BloomThreshold
    rays.Enabled, rays.Intensity = cfg.SunRaysEnabled, cfg.SunRaysIntensity
    blur.Enabled = cfg.MotionBlur
    if not cfg.MotionBlur then blur.Size = 0; state.blur, state.motionFrame = 0, nil end
    for _, record in pairs(state.lightingRecords) do applyLighting(record) end
end
local function stepMotion(dt)
    if not state.alive then return end
    local camera = source.CurrentCamera
    if not cfg.MotionBlur or not camera or dt <= 0 then
        state.motionCamera, state.motionFrame, state.blur = camera, nil, 0
        if blur.Size ~= 0 then blur.Size = 0 end
        return
    end
    local frame = camera.CFrame
    if camera ~= state.motionCamera or not state.motionFrame then
        state.motionCamera, state.motionFrame, state.blur = camera, frame, 0; blur.Size = 0; return
    end
    local previous = state.motionFrame
    local _, angle = previous:ToObjectSpace(frame):ToAxisAngle()
    local distance = (frame.Position - previous.Position).Magnitude
    state.motionFrame = frame
    -- Camera-motion blur approximation. Skip teleports/cutscene jumps instead
    -- of flashing a full-screen blur; ease out immediately when motion stops.
    local target = 0
    if distance < 50 and math.abs(angle) < math.rad(120) then
        target = cfg.MotionStrength * math.clamp(math.abs(angle) / math.max(dt, 0.001) / 5 + distance / math.max(dt, 0.001) / 480, 0, 1)
    end
    state.blur += (target - state.blur) * (1 - math.exp(-12 * math.min(dt, 0.25)))
    if state.blur < 0.01 then state.blur = 0 end
    if math.abs(blur.Size - state.blur) > 0.001 then blur.Size = state.blur end
end
controller.stepMotion = stepMotion
local ranges = {FOV = {40, 120},
    MotionStrength = {0, 32}, BloomIntensity = {0, 5}, BloomSize = {0, 56}, BloomThreshold = {0, 4},
    SunRaysIntensity = {0, 1}, FogDistance = {50, 10000}}
local colors = {Ambient = true, OutdoorAmbient = true, FogColor = true}
controller.set = function(name, value)
    if not state.alive or cfg[name] == nil then return end
    if ranges[name] then
        if type(value) ~= "number" or value ~= value then return end
        value = math.clamp(value, ranges[name][1], ranges[name][2])
    elseif colors[name] then if typeof(value) ~= "Color3" then return end
    else value = value == true end
    cfg[name] = value
    if name == "HideMuzzleEffects" then if bridge and bridge.Parent then bridge:SetAttribute("HideMuzzleEffects", value) end
    elseif name == "FOV" or name == "FOVEnabled" then
        if cfg.FOVEnabled then bind(source.CurrentCamera); apply(state.cameraData) else restore(state.cameraData) end
    else updateWorld() end
end
controller.unload = function()
    if not state.alive then return end
    state.alive = false; RunService:UnbindFromRenderStep(state.renderToken); RunService:UnbindFromRenderStep(state.worldToken)
    for _, c in ipairs(state.connections) do c:Disconnect() end
    if state.cameraData then state.cameraData.connection:Disconnect(); restore(state.cameraData); state.cameraData = nil end
    for _, record in pairs(state.lightingRecords) do restoreLighting(record) end
    for _, object in pairs(state.effects) do object:Destroy() end
    table.clear(state.effects)
    if bridge and bridge.Parent and bridge:GetAttribute("HideMuzzleEffects") == cfg.HideMuzzleEffects then bridge:SetAttribute("HideMuzzleEffects", false) end
    if G.__VergilPFMisc == controller then G.__VergilPFMisc = nil end
end
state.connections[#state.connections + 1] = source:GetPropertyChangedSignal("CurrentCamera"):Connect(function() if state.alive then bind(source.CurrentCamera) end end)
if bridge then state.connections[#state.connections + 1] = bridge.Destroying:Connect(controller.unload) end
for _, key in ipairs({"Ambient", "OutdoorAmbient", "FogStart", "FogEnd", "FogColor"}) do
    local record = {key = key}; state.lightingRecords[key] = record
    state.connections[#state.connections + 1] = lighting:GetPropertyChangedSignal(key):Connect(function() applyLighting(record) end)
end
bind(source.CurrentCamera)
updateWorld()
RunService:BindToRenderStep(state.renderToken, Enum.RenderPriority.Camera.Value - 1, function() if state.alive and cfg.FOVEnabled then bind(source.CurrentCamera); apply(state.cameraData) end end)
RunService:BindToRenderStep(state.worldToken, Enum.RenderPriority.Camera.Value + 4, stepMotion)
return controller
end

local function StartFeedback(...)
-- Local audio and cached custom beam tracers. No server events are generated.
local options = ...
if type(options) ~= "table" then options = {} end
local G, RunService, Workspace = getgenv(), game:GetService("RunService"), game:GetService("Workspace")
local bridge = assert(options.Bridge, "Feedback bridge missing")
local event = assert(bridge:FindFirstChild("Feedback"), "Feedback event missing")
if G.__VergilPFFeedback then G.__VergilPFFeedback.unload() end
local ping = "rbxasset://sounds/electronicpingshort.wav"
local cfg = {ShootSoundEnabled = false, ShootSoundId = ping, HitSoundEnabled = false, HitSoundId = ping, KillSoundEnabled = false, KillSoundId = ping,
    SoundVolume = 0.8, KillPitch = 1.25, TracersEnabled = false, ReplaceTracers = false, TracerColor = Color3.fromRGB(176, 188, 240),
    TracerWidth = 0.06, TracerLife = 0.2, TracerLength = 1200, TracerAlpha = 0.15, TracerTexture = "", MaxTracers = 32}
local state = {alive = true, connections = {}, tracers = {}, sounds = {}}
local controller = {state = state, config = cfg}
G.__VergilPFFeedback = controller
local root = Instance.new("Folder")
root.Name = "VergilFeedback_" .. game:GetService("HttpService"):GenerateGUID(false)
root.Parent = options.TracerParent or Workspace:FindFirstChild("Ignore") or Workspace
state.root = root
local soundParent = options.SoundParent or game:GetService("SoundService")
local function asset(value, sound)
    local text = tostring(value or ""):match("^%s*(.-)%s*$")
    if sound and text == ping then return text end
    local id = text:match("^(%d+)$") or text:match("^rbxassetid://(%d+)$")
    if id and #id <= 20 and tonumber(id) and tonumber(id) > 0 then return "rbxassetid://" .. id end
    return ""
end
controller.normalizeAsset = asset
local function sync()
    if not bridge.Parent then return end
    for _, key in ipairs({"ShootSoundEnabled", "ShootSoundId", "HitSoundEnabled", "HitSoundId", "KillSoundEnabled", "KillSoundId", "TracersEnabled", "ReplaceTracers"}) do bridge:SetAttribute(key, cfg[key]) end
end
local function dropSound(record)
    if record.connection then record.connection:Disconnect() end
    record.sound:Destroy()
end
local function play(kind)
    if not state.alive or not table.find({"shoot", "hit", "kill"}, kind) then return end
    local key = kind:sub(1, 1):upper() .. kind:sub(2)
    local id = cfg[key .. "SoundId"]
    if not id or id == "" then return end
    if #state.sounds >= 12 then dropSound(table.remove(state.sounds, 1)) end
    local sound = Instance.new("Sound")
    sound.Name, sound.SoundId, sound.Volume, sound.PlaybackSpeed, sound.Parent = "Vergil_" .. kind, id, cfg.SoundVolume, kind == "kill" and cfg.KillPitch or 1, soundParent
    local record = {sound = sound, expires = os.clock() + 5}
    state.sounds[#state.sounds + 1] = record
    record.connection = sound.Ended:Connect(function() record.expires = 0 end)
    if not options.SuppressPlayback then sound:Play() end
    return sound
end
controller.preview = play
local function dropTrace(trace) trace.part:Destroy() end
local function trace(visual, origin, velocity, acceleration, life)
    if not state.alive or not cfg.TracersEnabled or typeof(origin) ~= "Vector3" or typeof(velocity) ~= "Vector3" or velocity.Magnitude <= 0 then return end
    if type(life) ~= "number" or life ~= life then life = 3 end
    if #state.tracers >= cfg.MaxTracers then dropTrace(table.remove(state.tracers, 1)) end
    local part = Instance.new("Part")
    part.Name, part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.Transparency, part.Size = "TracerAnchor", true, false, false, false, 1, Vector3.new(0.05, 0.05, 0.05)
    part.Parent = root
    local first, second = Instance.new("Attachment"), Instance.new("Attachment")
    first.Parent, second.Parent = part, part
    first.WorldPosition, second.WorldPosition = typeof(visual) == "Vector3" and visual or origin, origin
    local beam = Instance.new("Beam")
    beam.Attachment0, beam.Attachment1, beam.FaceCamera = first, second, true
    beam.Color, beam.Width0, beam.Width1, beam.LightEmission, beam.Segments = ColorSequence.new(cfg.TracerColor), cfg.TracerWidth, cfg.TracerWidth, 1, 1
    beam.Transparency, beam.Texture, beam.Parent = NumberSequence.new(cfg.TracerAlpha), cfg.TracerTexture, part
    state.tracers[#state.tracers + 1] = {part = part, beam = beam, ending = second, origin = origin, previous = origin, velocity = velocity,
        acceleration = typeof(acceleration) == "Vector3" and acceleration or Vector3.zero, age = 0, life = math.min(cfg.TracerLife, math.max(0.01, life or 3)), distance = cfg.TracerLength}
end
controller.trace = trace
local params = RaycastParams.new()
params.FilterType, params.IgnoreWater = Enum.RaycastFilterType.Exclude, true
local function step(dt)
    if not state.alive or type(dt) ~= "number" or dt ~= dt or dt < 0 then return end
    if #state.tracers == 0 and #state.sounds == 0 then return end
    local ignore = {root}
    if Workspace.CurrentCamera then ignore[#ignore + 1] = Workspace.CurrentCamera end
    local ignored = Workspace:FindFirstChild("Ignore"); if ignored then ignore[#ignore + 1] = ignored end
    local character = game:GetService("Players").LocalPlayer.Character; if character then ignore[#ignore + 1] = character end
    params.FilterDescendantsInstances = ignore
    for index = #state.tracers, 1, -1 do
        local item = state.tracers[index]
        item.age += dt
        if item.age >= item.life or not cfg.TracersEnabled or not item.part.Parent or not item.beam.Parent then dropTrace(item); table.remove(state.tracers, index)
        else
            if not item.stopped then
                local time = math.min(item.age, item.distance / item.velocity.Magnitude)
                local position = item.origin + item.velocity * time + item.acceleration * (0.5 * time * time)
                local delta = position - item.previous
                local hit
                if delta.Magnitude > 0.001 and not options.SkipRaycast then hit = Workspace:Raycast(item.previous, delta, params) end
                if hit then position, item.stopped = hit.Position, true end
                item.previous, item.ending.WorldPosition = position, position
            end
            local alpha = cfg.TracerAlpha + (1 - cfg.TracerAlpha) * math.clamp(item.age / item.life, 0, 1)
            item.beam.Transparency = NumberSequence.new(alpha)
        end
    end
    for index = #state.sounds, 1, -1 do
        if state.sounds[index].expires <= os.clock() then dropSound(state.sounds[index]); table.remove(state.sounds, index) end
    end
end
controller.step = step
local ranges = {SoundVolume = {0, 2}, KillPitch = {0.5, 2}, TracerWidth = {0.01, 0.5}, TracerLife = {0.05, 1}, TracerLength = {100, 5000}, TracerAlpha = {0, 1}, MaxTracers = {1, 64}}
controller.set = function(key, value)
    if not state.alive or cfg[key] == nil then return end
    if key:find("SoundId", 1, true) then value = asset(value, true)
    elseif key == "TracerTexture" then value = asset(value, false)
    elseif key == "TracerColor" then if typeof(value) ~= "Color3" then return end
    elseif ranges[key] then if type(value) ~= "number" or value ~= value then return end; value = math.clamp(value, ranges[key][1], ranges[key][2])
    else value = value == true end
    if key == "MaxTracers" then value = math.floor(value) end
    cfg[key] = value; sync()
    for _, item in ipairs(state.tracers) do
        if item.beam.Parent then
            item.beam.Color, item.beam.Width0, item.beam.Width1, item.beam.Texture = ColorSequence.new(cfg.TracerColor), cfg.TracerWidth, cfg.TracerWidth, cfg.TracerTexture
        end
    end
    while #state.tracers > cfg.MaxTracers do dropTrace(table.remove(state.tracers, 1)) end
    if key == "TracersEnabled" and not value then for _, item in ipairs(state.tracers) do dropTrace(item) end; table.clear(state.tracers) end
end
controller.unload = function()
    if not state.alive then return end
    state.alive = false
    for _, connection in ipairs(state.connections) do connection:Disconnect() end
    for _, record in ipairs(state.sounds) do dropSound(record) end
    root:Destroy(); table.clear(state.tracers); table.clear(state.sounds)
    if bridge.Parent then for _, key in ipairs({"ShootSoundEnabled", "HitSoundEnabled", "KillSoundEnabled", "TracersEnabled"}) do bridge:SetAttribute(key, false) end end
    if G.__VergilPFFeedback == controller then G.__VergilPFFeedback = nil end
end
state.connections[#state.connections + 1] = event.Event:Connect(function(kind, ...)
    if kind == "trace" then trace(...)
    elseif kind == "shoot" and cfg.ShootSoundEnabled or kind == "hit" and cfg.HitSoundEnabled or kind == "kill" and cfg.KillSoundEnabled then play(kind) end
end)
state.connections[#state.connections + 1] = RunService.Heartbeat:Connect(step)
state.connections[#state.connections + 1] = bridge.Destroying:Connect(controller.unload)
state.connections[#state.connections + 1] = root.AncestryChanged:Connect(function() if state.alive and not root.Parent then controller.unload() end end)
sync()
return controller
end

local function StartIndicator(...)
-- Persistent HUD cloned from the library's real notification, not a new skin.
local options = ...
if type(options) ~= "table" then options = {} end
local Library, bridge = assert(options.Library), assert(options.Bridge)
local cfg = {Enabled = false, Position = "Under crosshair", Content = "Ragebot + ammo"}
local state = {alive = true, connections = {}, library = Library}
local controller = {state = state, config = cfg}
local previous = {}
for _, child in ipairs(Library.NotifHolder:GetChildren()) do previous[child] = true end
Library:Notification({Name = "Ragebot", Time = 0.01})
local template
for _, child in ipairs(Library.NotifHolder:GetChildren()) do if not previous[child] and child:IsA("TextLabel") then template = child; break end end
assert(template, "Library notification label unavailable")
local label = template:Clone()
template.Parent = nil -- Its normal finite notification timer still cleans it up.
label.Name, label.Parent, label.Visible, label.TextTransparency, label.TextStrokeTransparency = "VergilRageIndicator", Library.Holder, false, 0, 0
state.label, state.originalNotificationPosition = label, Library.NotifHolder.Position
local function escape(s) return tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;") end
local function assign(object, key, value) if object[key] ~= value then object[key] = value end end
local function update()
    if not state.alive then return end
    local preview = state.previewUntil and os.clock() < state.previewUntil
    local ammo, spare = bridge:GetAttribute("Ammo") or -1, bridge:GetAttribute("ReserveAmmo") or 0
    local weapon = bridge:GetAttribute("WeaponName") or ""
    local rage = bridge:GetAttribute("RageEnabled") == true
    local status, target = bridge:GetAttribute("RageState") or (rage and "SEARCHING" or "OFF"), bridge:GetAttribute("RageTarget") or ""
    if preview then ammo, spare, weapon, status = 30, 90, "M4A1", "READY" end
    assign(label, "Visible", cfg.Enabled and (preview or not Library.MenuOpen and (cfg.Content == "Ragebot" and rage or cfg.Content ~= "Ragebot" and ammo >= 0)) == true)
    local text = {}
    if cfg.Content ~= "Ammo" then text[#text + 1] = "Ragebot " .. status; if target ~= "" then text[#text + 1] = escape(target) end end
    if cfg.Content ~= "Ragebot" then text[#text + 1] = escape(weapon) .. " " .. tostring(math.max(0, ammo)) .. " / " .. tostring(spare) end
    local accent = Library.Theme["Element Accent"]
    local prefix = string.format('[<font color="rgb(%d, %d, %d)">%s</font>] ', math.floor(accent.R * 255), math.floor(accent.G * 255), math.floor(accent.B * 255), Library.Name)
    local value = prefix .. table.concat(text, " | ")
    if label.Text ~= value then label.Text = value end
    assign(label, "TextColor3", Library.Theme.Text)
    local placed = false
    if cfg.Position == "Gun point" then
        local refs = bridge:FindFirstChild("Viewmodel")
        local muzzle = refs and refs:FindFirstChild("Muzzle")
        local camera = workspace.CurrentCamera
        if camera and muzzle and muzzle.Value and muzzle.Value:IsA("BasePart") then
            local point, visible = camera:WorldToViewportPoint(muzzle.Value.Position)
            if visible and point.Z > 0 then
                local halfWidth = math.min(label.AbsoluteSize.X * 0.5 + 8, camera.ViewportSize.X * 0.5)
                assign(label, "AnchorPoint", Vector2.new(0.5, 0))
                assign(label, "Position", UDim2.fromOffset(math.clamp(point.X, halfWidth, camera.ViewportSize.X - halfWidth), math.clamp(point.Y + 18, 8, math.max(8, camera.ViewportSize.Y - 24))))
                placed = true
            end
        end
    end
    if cfg.Position == "Bottom right" then
        assign(label, "AnchorPoint", Vector2.new(1, 1)); assign(label, "Position", UDim2.new(1, -12, 1, -12)); assign(label, "TextXAlignment", Enum.TextXAlignment.Right)
    elseif not placed then
        assign(label, "AnchorPoint", Vector2.new(0.5, 0)); assign(label, "Position", UDim2.new(0.5, 0, 0.5, 32)); assign(label, "TextXAlignment", Enum.TextXAlignment.Center)
    else assign(label, "TextXAlignment", Enum.TextXAlignment.Center) end
    assign(Library.NotifHolder, "Position", cfg.Position == "Bottom right" and label.Visible and UDim2.new(1, -12, 1, -36) or state.originalNotificationPosition)
end
controller.set = function(key, value)
    if not state.alive or cfg[key] == nil then return end
    if key == "Position" and not table.find({"Gun point", "Under crosshair", "Bottom right"}, value) then return end
    if key == "Content" and not table.find({"Ragebot + ammo", "Ragebot", "Ammo"}, value) then return end
    if key == "Enabled" then value = value == true end
    cfg[key] = value
    if key == "Enabled" and bridge.Parent then bridge:SetAttribute("IndicatorEnabled", value) end
    update()
end
controller.preview = function() if state.alive then state.previewUntil = os.clock() + 3; update() end end
controller.update = update
controller.unload = function()
    if not state.alive then return end
    state.alive = false
    if bridge.Parent then bridge:SetAttribute("IndicatorEnabled", false) end
    for _, connection in ipairs(state.connections) do connection:Disconnect() end
    Library.NotifHolder.Position = state.originalNotificationPosition
    label:Destroy()
end
local dirty, elapsed = true, 0
state.connections[#state.connections + 1] = bridge.AttributeChanged:Connect(function(attribute)
    if table.find({"Ammo", "ReserveAmmo", "WeaponName", "RageEnabled", "RageState", "RageTarget"}, attribute) then dirty = true end
end)
state.connections[#state.connections + 1] = bridge.Destroying:Connect(controller.unload)
state.connections[#state.connections + 1] = game:GetService("RunService").RenderStepped:Connect(function(dt)
    if not cfg.Enabled then return end
    elapsed += dt
    if dirty or elapsed >= 0.1 or cfg.Position == "Gun point" and label.Visible then dirty, elapsed = false, 0; update() end
end)
update()
return controller
end

local function StartSticker(...)
-- Two optional static stickers, cached locally and attached to the gun point.
local options = ...
if type(options) ~= "table" then options = {} end
local G, RunService = getgenv(), game:GetService("RunService")
if G.__VergilSticker then G.__VergilSticker.unload() end
local payload = "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"
local metadataText = "{\"size\": 160, \"columns\": 2, \"frames\": 2, \"fps\": 0, \"static\": true, \"hash\": \"5d6c13463644\"}"
local cfg = {Enabled = false, Selection = "Both", Size = 128}
local state = {alive = true, connections = {}, renderToken = "VergilSticker_" .. game:GetService("HttpService"):GenerateGUID(false)}
local controller = {state = state, config = cfg}
G.__VergilSticker = controller
local gui = Instance.new("ScreenGui")
gui.Name, gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder = "VergilSticker", true, false, 70
gui.Parent = options.Parent or (gethui and gethui()) or game:GetService("CoreGui")
local image = Instance.new("ImageLabel")
image.Name, image.BackgroundTransparency, image.AnchorPoint, image.Visible, image.Parent = "Sticker", 1, Vector2.new(0.5, 0.5), false, gui
state.gui, state.image = gui, image
local second = image:Clone(); second.Name, second.Parent = "StickerTwo", gui
state.second = second
local function decode64(text)
    local alphabet, lookup = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", {}
    for index = 1, #alphabet do lookup[alphabet:sub(index,index)] = index-1 end
    local result, value, bits = {}, 0, 0
    for index = 1, #text do
        local digit = lookup[text:sub(index,index)]
        if digit then
            value = value * 64 + digit; bits += 6
            if bits >= 8 then
                bits -= 8
                local divisor = 2 ^ bits
                result[#result+1] = string.char(math.floor(value / divisor))
                value %= divisor
            end
        end
    end
    return table.concat(result)
end
local function load()
    if state.loaded then return true end
    if not writefile or not isfile or not getcustomasset or not isfolder or not makefolder then return false end
    local metadata = game:GetService("HttpService"):JSONDecode(metadataText)
    local directory = "Vergil/Assets"
    if not isfolder("Vergil") then makefolder("Vergil") end
    if not isfolder(directory) then makefolder(directory) end
    local path = directory .. "/sticker_" .. metadata.hash .. ".png"
    if not isfile(path) then writefile(path, decode64(payload)) end
    image.Image, image.ImageRectSize = getcustomasset(path), Vector2.new(metadata.size, metadata.size)
    second.Image, second.ImageRectSize = image.Image, image.ImageRectSize
    image.ImageRectOffset, second.ImageRectOffset = Vector2.zero, Vector2.new(metadata.size,0)
    state.metadata, state.loaded = metadata, true
    return true
end
local function layout()
    local camera=workspace.CurrentCamera
    if not camera then image.Visible,second.Visible=false,false; return end
    local center=camera.ViewportSize*0.5
    local refs=options.Bridge and options.Bridge:FindFirstChild("Viewmodel")
    local muzzle=refs and refs:FindFirstChild("Muzzle")
    if muzzle and muzzle.Value and muzzle.Value:IsA("BasePart") then
        local point,visible=camera:WorldToViewportPoint(muzzle.Value.Position)
        if visible and point.Z>0 then center=Vector2.new(point.X,point.Y) end
    end
    state.gunScreenPoint = center
    local both=cfg.Selection=="Both"
    image.Size,second.Size=UDim2.fromOffset(cfg.Size,cfg.Size),UDim2.fromOffset(cfg.Size,cfg.Size)
    image.AnchorPoint,second.AnchorPoint=Vector2.new(0.5,0.5),Vector2.new(0.5,0.5)
    image.Position=UDim2.fromOffset(center.X+90-(both and cfg.Size*0.5+4 or 0),center.Y-130)
    second.Position=UDim2.fromOffset(center.X+90+(both and cfg.Size*0.5+4 or 0),center.Y-130)
    image.Visible=cfg.Enabled and state.loaded and cfg.Selection~="Sticker 2"
    second.Visible=cfg.Enabled and state.loaded and cfg.Selection~="Sticker 1"
end
controller.layout = layout
local function show()
    if not state.alive or not cfg.Enabled then return end
    local ok, loaded = pcall(load)
    if not ok or not loaded then
        if options.Library then options.Library:Notification({Name="Sticker assets unavailable",Time=3}) end
        return
    end
    layout()
end
controller.preview = show
controller.set = function(key, value)
    if not state.alive or cfg[key] == nil then return end
    if key == "Enabled" then value = value == true
    elseif key == "Selection" and not table.find({"Sticker 1","Sticker 2","Both"},value) then return
    elseif key == "Size" then if type(value)~="number" or value~=value then return end; value=math.clamp(value,64,256) end
    cfg[key]=value
    if options.Bridge and options.Bridge.Parent then options.Bridge:SetAttribute("StickerEnabled",cfg.Enabled) end
    layout()
    if not cfg.Enabled then image.Visible,second.Visible=false,false else show() end
end
controller.unload = function()
    if not state.alive then return end
    state.alive=false
    RunService:UnbindFromRenderStep(state.renderToken)
    for _,connection in ipairs(state.connections) do connection:Disconnect() end
    if options.Bridge and options.Bridge.Parent then options.Bridge:SetAttribute("StickerEnabled",false) end
    gui:Destroy()
    if G.__VergilSticker==controller then G.__VergilSticker=nil end
end
if options.Bridge then
    state.connections[#state.connections+1]=options.Bridge.Destroying:Connect(controller.unload)
end
-- Draw after the camera/FOV and viewmodel updates. Offsets remain pixels,
-- never world-space units or values multiplied by the camera FieldOfView.
RunService:BindToRenderStep(state.renderToken, Enum.RenderPriority.Last.Value, function()
    if state.alive and cfg.Enabled and state.loaded then layout() end
end)
layout()
return controller
end

-- Single-file entry point; backend factories are supplied by build_vergil.py.
local G, TITLE = getgenv(), "Vergil Reborn PF"
local previousFocus = G.__VergilReborn and G.__VergilReborn.focused
if G.__VergilReborn and G.__VergilReborn.unload then G.__VergilReborn.unload() end
local loader, err = loadstring(game:HttpGet("https://raw.githubusercontent.com/14273l/Vergil-poopy/refs/heads/main/Library"))
assert(loader, err)
local Library = loader()
assert(type(Library) == "table" and Library.Window, "UI library unavailable")
Library.Name, Library.BlurEnabled, Library.SnowEnabled = TITLE, false, false
Library:SetSnowAmount(0); Library:UpdateEffects()
local runtime = {name = TITLE, library = Library, closed = false, connections = {}}
G.__VergilReborn = runtime
local originalExit = Library.Exit
Library.Exit = function(self)
    if runtime.closed then return end
    runtime.closed = true
    for _, c in ipairs(runtime.connections) do c:Disconnect() end
    for _, name in ipairs({"sticker", "indicator", "feedback", "esp", "viewmodel", "misc", "chams", "aim"}) do
        if runtime[name] then local ok, failure = pcall(runtime[name].unload); if not ok then warn("[Vergil] " .. name .. " cleanup: " .. tostring(failure)) end end
    end
    if G.__VergilReborn == runtime then G.__VergilReborn = nil end
    local ok, result = pcall(originalExit, self)
    if not ok then
        warn("[Vergil] Library cleanup fallback: " .. tostring(result))
        for _, name in ipairs({"Holder", "PopupHolder", "DragHolder", "SnowHolder", "Blur"}) do if Library[name] then pcall(function() Library[name]:Destroy() end) end end
        Library.Unloaded = true
        if G.VergilLibrary == Library then G.VergilLibrary = nil end
    end
    return ok and result or nil
end
runtime.unload = function() Library:Exit() end
local ok, failure = xpcall(function()
    runtime.aim = StartAim({NoControls = true, Enabled = false, DrawFOV = false, FOV = 150})
    runtime.chams = StartChams({Managed = true, Enabled = false})
    runtime.esp = StartESP({Bridge = runtime.aim.folder, Enabled = false})
    runtime.viewmodel = StartViewmodel({Bridge = runtime.aim.folder})
    runtime.misc = StartMisc({Bridge = runtime.aim.folder})
    runtime.feedback = StartFeedback({Bridge = runtime.aim.folder})
    local aim, chams, esp, viewmodel, misc = runtime.aim, runtime.chams, runtime.esp, runtime.viewmodel, runtime.misc
    local feedback = runtime.feedback
    local Window = Library:Window({Name = TITLE}); runtime.window = Window
    -- Hide only the library footer's username; leave game UI and ESP intact.
    local footer = Window.Items.BottomBar.Instance
    for _, child in ipairs(footer:GetChildren()) do
        if child:IsA("TextLabel") then
            if child.Text:sub(1, 1) == "@" then child.Visible = false
            else child.Size = UDim2.new(1, 0, 1, 0) end
        end
    end
    Library.Name = "Vergil" -- Preserve the supplied notification's [Vergil] prefix.
    runtime.indicator = StartIndicator({Library = Library, Bridge = aim.folder})
    local indicator = runtime.indicator
    runtime.sticker = StartSticker({Library = Library, Bridge = aim.folder})
    local sticker = runtime.sticker
    local Combat, Visuals = Window:Page({Name = "combat"}), Window:Page({Name = "visuals"})
    local WeaponsPage, MiscPage = Window:Page({Name = "weapons"}), Window:Page({Name = "misc"})
    local WorldPage = Window:Page({Name = "world"})
    local Silent, Targeting = Combat:Section({Name = "silent aim", Side = 1}), Combat:Section({Name = "targeting", Side = 2})
    local Rage, Origin = Combat:Section({Name = "ragebot", Side = 1}), Combat:Section({Name = "origin manipulation", Side = 2})
    local ESPMain, ESPStyle = Visuals:Section({Name = "player esp", Side = 1}), Visuals:Section({Name = "box style", Side = 2})
    local Models = Visuals:Section({Name = "viewport chams", Side = 1})
    local Weapons = WeaponsPage:Section({Name = "weapon controls", Side = 1})
    local Camera, Viewmodel = MiscPage:Section({Name = "camera", Side = 1}), MiscPage:Section({Name = "viewmodel", Side = 2})
    local Sounds, Tracers = MiscPage:Section({Name = "sounds", Side = 1}), MiscPage:Section({Name = "custom tracers", Side = 2})
    local Sticker = MiscPage:Section({Name = "anime sticker", Side = 2})
    local Post = WorldPage:Section({Name = "post processing", Side = 1})
    local World = WorldPage:Section({Name = "ambient lighting", Side = 2})
    Silent:Toggle({Name = "enabled", Flag = "pf_aim_enabled", Default = false, Callback = aim.setEnabled})
    Silent:Slider({Name = "fov radius", Flag = "pf_aim_fov", Min = 0, Max = 600, Default = 150, Decimals = 1, Suffix = " px", Callback = function(v) aim.set("FOV", v) end})
    Silent:Toggle({Name = "draw fov", Flag = "pf_aim_draw", Default = false, Callback = function(v) aim.set("DrawFOV", v) end}):Colorpicker({Flag = "pf_aim_color", Default = Color3.fromRGB(176, 188, 240), Alpha = 0.35, Callback = function(c,a) aim.set("FOVColor",c); aim.set("FOVAlpha",a) end})
    Targeting:Dropdown({Name = "target part", Flag = "pf_aim_part", Items = {"Head", "Torso", "Random"}, Default = "Head", Callback = function(v) aim.set("TargetPart", v) end})
    Targeting:Toggle({Name = "team check", Flag = "pf_aim_team", Default = false, Callback = function(v) aim.set("TeamCheck", v) end})
    Targeting:Toggle({Name = "visible targets only", Flag = "pf_aim_wall", Default = false, Callback = function(v) aim.set("WallCheck", v) end})
    Targeting:Toggle({Name = "motion prediction", Flag = "pf_aim_prediction", Default = false, Callback = function(v) aim.set("Prediction", v) end})
    Targeting:Slider({Name = "max distance", Flag = "pf_aim_distance", Min = 50, Max = 3000, Default = 2000, Decimals = 1, Suffix = " studs", Callback = function(v) aim.set("MaxDistance", v) end})
    Origin:Toggle({Name = "enabled", Flag = "pf_origin_enabled", Default = false, Callback = function(v) aim.set("OriginEnabled", v) end})
    Origin:Slider({Name = "offset radius", Flag = "pf_origin_radius", Min = 0, Max = 15, Default = 2, Decimals = 0.1, Suffix = " studs", Callback = function(v) aim.set("OriginRadius", v) end})
    Rage:Toggle({Name = "enabled", Flag = "pf_rage_enabled", Default = false, Callback = function(v) aim.set("RageEnabled", v) end})
    Rage:Toggle({Name = "auto shoot", Flag = "pf_rage_autofire", Default = false, Callback = function(v) aim.set("RageAutoFire", v) end})
    Rage:Toggle({Name = "auto reload", Flag = "pf_rage_autoreload", Default = false, Callback = function(v) aim.set("RageAutoReload", v) end})
    Rage:Toggle({Name = "target lock", Flag = "pf_rage_targetlock", Default = false, Callback = function(v) aim.set("RageTargetLock", v) end})
    Rage:Toggle({Name = "multipoint scan", Flag = "pf_rage_multipoint", Default = false, Callback = function(v) aim.set("RageMultipoint", v) end})
    Rage:Slider({Name = "scan rate", Flag = "pf_rage_scanrate", Min = 10, Max = 60, Default = 30, Decimals = 1, Suffix = " Hz", Callback = function(v) aim.set("RageScanHz", v) end})
    Rage:Dropdown({Name = "priority", Flag = "pf_rage_priority", Items = {"Closest", "Lowest health"}, Default = "Closest", Callback = function(v) aim.set("RagePriority", v) end})
    Rage:Slider({Name = "repeat interval", Flag = "pf_rage_interval", Min = 50, Max = 500, Default = 100, Decimals = 1, Suffix = " ms", Callback = function(v) aim.set("RageInterval", v) end})
    Rage:Slider({Name = "max distance", Flag = "pf_rage_distance", Min = 50, Max = 3000, Default = 2000, Decimals = 1, Suffix = " studs", Callback = function(v) aim.set("RageDistance", v) end})
    Rage:Toggle({Name = "indicator", Flag = "pf_rage_indicator", Default = false, Callback = function(v) indicator.set("Enabled", v) end})
    Rage:Dropdown({Name = "indicator content", Flag = "pf_rage_indicator_content", Items = {"Ragebot + ammo", "Ragebot", "Ammo"}, Default = "Ragebot + ammo", Callback = function(v) indicator.set("Content", v) end})
    Rage:Dropdown({Name = "indicator position", Flag = "pf_rage_indicator_position", Items = {"Gun point", "Under crosshair", "Bottom right"}, Default = "Under crosshair", Callback = function(v) indicator.set("Position", v) end})
    Rage:Button({Name = "preview indicator", Callback = indicator.preview})
    Weapons:Toggle({Name = "no recoil", Flag = "pf_no_recoil", Default = false, Callback = function(v) aim.set("NoRecoil", v) end})
    Weapons:Toggle({Name = "no spread", Flag = "pf_no_spread", Default = false, Callback = function(v) aim.set("NoSpread", v) end})
    Weapons:Toggle({Name = "instant reload", Flag = "pf_instant_reload", Default = false, Callback = function(v) aim.set("InstantReload", v) end})
    ESPMain:Toggle({Name = "enabled", Flag = "pf_esp_enabled", Default = false, Callback = esp.setEnabled})
    ESPMain:Toggle({Name = "enemies only", Flag = "pf_esp_team", Default = false, Callback = function(v) esp.set("TeamCheck", v) end})
    local function espToggle(section, name, flag, path) return section:Toggle({Name = name, Flag = flag, Default = false, Callback = function(v) esp.set(path .. ".Enabled", v) end}) end
    espToggle(ESPMain, "names", "pf_esp_names", "Texts.Name"):Colorpicker({Flag = "pf_esp_name_color", Default = Color3.new(1, 1, 1), Callback = function(v) esp.set("Texts.Name.Color", v) end})
    espToggle(ESPMain, "distance", "pf_esp_distance_text", "Texts.Distance"); espToggle(ESPMain, "weapons", "pf_esp_weapons", "Texts.Weapon"); espToggle(ESPMain, "health bar", "pf_esp_health", "Bars.Health Bar")
    ESPMain:Slider({Name = "max distance", Flag = "pf_esp_distance", Min = 100, Max = 7520, Default = 2000, Decimals = 1, Suffix = " studs", Callback = function(v) esp.set("Distance", v) end})
    espToggle(ESPStyle, "boxes", "pf_esp_boxes", "Boxes"); espToggle(ESPStyle, "accurate body bounds", "pf_esp_bounds", "Boxes.Bounding Box")
    ESPStyle:Dropdown({Name = "box style", Flag = "pf_esp_box_style", Items = {"Corners", "Full"}, Default = "Corners", Callback = function(v) esp.set("Boxes.Style", v) end})
    ESPStyle:Toggle({Name = "include accessories", Flag = "pf_esp_accessories", Default = false, Callback = function(v) esp.set("Boxes.Bounding Box.IncludeAcsessories", v) end})
    espToggle(ESPStyle, "box glow", "pf_esp_glow", "Boxes.Box Glow")
    ESPStyle:Slider({Name = "glow transparency", Flag = "pf_esp_glow_alpha", Min = 0, Max = 1, Default = 0.95, Decimals = 0.01, Callback = function(v) esp.set("Boxes.Box Glow.Transparency", {v, v}) end})
    espToggle(ESPStyle, "gradient fill", "pf_esp_fill", "Boxes.Filled")
    ESPStyle:Slider({Name = "fill top transparency", Flag = "pf_esp_fill_top_alpha", Min = 0, Max = 1, Default = 1, Decimals = 0.01, Callback = function(v) esp.set("Boxes.Filled.Transparency", {v, esp.config.Boxes.Filled.Transparency[2]}) end})
    ESPStyle:Slider({Name = "fill bottom transparency", Flag = "pf_esp_fill_bottom_alpha", Min = 0, Max = 1, Default = 0.95, Decimals = 0.01, Callback = function(v) esp.set("Boxes.Filled.Transparency", {esp.config.Boxes.Filled.Transparency[1], v}) end})
    ESPStyle:Label({Name = "gradient top"}):Colorpicker({Flag = "pf_esp_gradient_top", Default = Color3.fromRGB(176, 188, 240), Callback = function(v) esp.set("Boxes.Gradients.Top", v); esp.set("Boxes.Filled.Top", v); esp.set("Boxes.Box Glow.Top", v) end})
    ESPStyle:Label({Name = "gradient bottom"}):Colorpicker({Flag = "pf_esp_gradient_bottom", Default = Color3.fromRGB(115, 135, 200), Callback = function(v) esp.set("Boxes.Gradients.Bot", v); esp.set("Boxes.Filled.Bot", v); esp.set("Boxes.Box Glow.Bot", v) end})
    Models:Toggle({Name = "enabled", Flag = "pf_chams_enabled", Default = false, Callback = chams.setEnabled})
    Models:Toggle({Name = "enemies only", Flag = "pf_chams_team", Default = false, Callback = function(v) chams.set("TeamCheck", v) end})
    Models:Slider({Name = "transparency", Flag = "pf_chams_alpha", Min = 0, Max = 0.9, Default = 0, Decimals = 0.01, Callback = function(v) chams.set("FillTransparency", v) end})
    Models:Slider({Name = "team tint strength", Flag = "pf_chams_tint", Min = 0, Max = 1, Default = 0, Decimals = 0.01, Callback = function(v) chams.set("TintStrength", v) end})
    Models:Label({Name = "enemy tint"}):Colorpicker({Flag = "pf_chams_enemy_color", Default = Color3.fromRGB(255, 70, 80), Callback = function(v) chams.set("EnemyColor", v) end})
    Models:Label({Name = "ally tint"}):Colorpicker({Flag = "pf_chams_ally_color", Default = Color3.fromRGB(65, 180, 255), Callback = function(v) chams.set("AllyColor", v) end})
    Models:Slider({Name = "max distance", Flag = "pf_chams_distance", Min = 100, Max = 3000, Default = 1200, Decimals = 1, Suffix = " studs", Callback = function(v) chams.set("MaxDistance", v) end})
    Viewmodel:Toggle({Name = "gun material", Flag = "pf_gun_material_enabled", Default = false, Callback = viewmodel.setEnabled}):Colorpicker({Flag = "pf_gun_color", Default = Color3.fromRGB(176, 188, 240), Callback = function(v) viewmodel.set("Color", v) end})
    Viewmodel:Dropdown({Name = "material", Flag = "pf_gun_material", Items = {"ForceField", "Neon"}, Default = "ForceField", Callback = function(v) viewmodel.set("Material", v) end})
    Viewmodel:Toggle({Name = "hide arms / hands", Flag = "pf_hide_arms", Default = false, Callback = function(v) viewmodel.set("HideArms", v) end})
    Viewmodel:Toggle({Name = "hide muzzle flash / smoke", Flag = "pf_hide_muzzle_effects", Default = false, Callback = function(v) misc.set("HideMuzzleEffects", v) end})
    Camera:Toggle({Name = "fov lock", Flag = "pf_camera_fov_enabled", Default = false, Callback = function(v) misc.set("FOVEnabled", v) end})
    Camera:Slider({Name = "field of view", Flag = "pf_camera_fov", Min = 40, Max = 120, Default = 120, Decimals = 1, Callback = function(v) misc.set("FOV", v) end})
    local ping = "rbxasset://sounds/electronicpingshort.wav"
    for _, sound in ipairs({{name = "shoot", key = "Shoot"}, {name = "hit", key = "Hit"}, {name = "kill", key = "Kill"}}) do
        local name, key = sound.name, sound.key
        Sounds:Toggle({Name = "custom " .. name .. " sound", Flag = "pf_sound_" .. name, Default = false, Callback = function(v) feedback.set(key .. "SoundEnabled", v) end})
        Sounds:Textbox({Name = name .. " sound id", Flag = "pf_sound_" .. name .. "_id", Default = ping, Finished = true, Callback = function(v) feedback.set(key .. "SoundId", v) end})
        Sounds:Button({Name = "preview " .. name, Callback = function() feedback.preview(name) end})
    end
    Sounds:Slider({Name = "volume", Flag = "pf_sound_volume", Min = 0, Max = 2, Default = 0.8, Decimals = 0.01, Callback = function(v) feedback.set("SoundVolume", v) end})
    Sounds:Slider({Name = "kill pitch", Flag = "pf_sound_kill_pitch", Min = 0.5, Max = 2, Default = 1.25, Decimals = 0.01, Callback = function(v) feedback.set("KillPitch", v) end})
    Tracers:Toggle({Name = "enabled", Flag = "pf_tracers_enabled", Default = false, Callback = function(v) feedback.set("TracersEnabled", v) end}):Colorpicker({Flag = "pf_tracer_color", Default = Color3.fromRGB(176, 188, 240), Alpha = 0.15, Callback = function(v, a) feedback.set("TracerColor", v); feedback.set("TracerAlpha", a) end})
    Tracers:Toggle({Name = "replace native tracers", Flag = "pf_tracers_replace", Default = false, Callback = function(v) feedback.set("ReplaceTracers", v) end})
    Tracers:Slider({Name = "width", Flag = "pf_tracer_width", Min = 0.01, Max = 0.5, Default = 0.06, Decimals = 0.01, Callback = function(v) feedback.set("TracerWidth", v) end})
    Tracers:Slider({Name = "duration", Flag = "pf_tracer_life", Min = 0.05, Max = 1, Default = 0.2, Decimals = 0.01, Suffix = " s", Callback = function(v) feedback.set("TracerLife", v) end})
    Tracers:Slider({Name = "max length", Flag = "pf_tracer_length", Min = 100, Max = 5000, Default = 1200, Decimals = 1, Suffix = " studs", Callback = function(v) feedback.set("TracerLength", v) end})
    Tracers:Textbox({Name = "texture id", Flag = "pf_tracer_texture", Default = "", Finished = true, Callback = function(v) feedback.set("TracerTexture", v) end})
    Sticker:Toggle({Name="enabled",Flag="pf_sticker_enabled",Default=false,Callback=function(v) sticker.set("Enabled",v) end})
    Sticker:Dropdown({Name="sticker",Flag="pf_sticker_selection",Items={"Sticker 1","Sticker 2","Both"},Default="Both",Callback=function(v) sticker.set("Selection",v) end})
    Sticker:Slider({Name="size",Flag="pf_sticker_size",Min=64,Max=256,Default=128,Decimals=1,Suffix=" px",Callback=function(v) sticker.set("Size",v) end})
    Sticker:Button({Name="preview sticker",Callback=sticker.preview})
    local function worldToggle(section, name, flag, key, default)
        return section:Toggle({Name = name, Flag = flag, Default = default == true, Callback = function(v) misc.set(key, v) end})
    end
    local function worldSlider(section, name, flag, key, minimum, maximum, default, step)
        return section:Slider({Name = name, Flag = flag, Min = minimum, Max = maximum, Default = default, Decimals = step or 0.01, Callback = function(v) misc.set(key, v) end})
    end
    worldToggle(Post, "camera motion blur", "pf_world_motion", "MotionBlur")
    worldSlider(Post, "blur strength", "pf_world_motion_strength", "MotionStrength", 0, 32, 8, 1)
    worldToggle(Post, "bloom", "pf_world_bloom", "BloomEnabled")
    worldSlider(Post, "bloom intensity", "pf_world_bloom_intensity", "BloomIntensity", 0, 5, 0.4)
    worldSlider(Post, "bloom size", "pf_world_bloom_size", "BloomSize", 0, 56, 24, 1)
    worldToggle(World, "ambient override", "pf_world_ambient_enabled", "AmbientEnabled"):Colorpicker({Flag = "pf_world_ambient", Default = Color3.fromRGB(128, 128, 128), Callback = function(v) misc.set("Ambient", v) end})
    World:Label({Name = "outdoor ambient"}):Colorpicker({Flag = "pf_world_outdoor_ambient", Default = Color3.fromRGB(128, 128, 128), Callback = function(v) misc.set("OutdoorAmbient", v) end})
    worldToggle(World, "sun rays", "pf_world_sun_rays", "SunRaysEnabled")
    worldSlider(World, "sun intensity", "pf_world_sun_intensity", "SunRaysIntensity", 0, 1, 0.08)
    worldToggle(World, "fog override", "pf_world_fog", "FogEnabled"):Colorpicker({Flag = "pf_world_fog_color", Default = Color3.fromRGB(190, 210, 235), Callback = function(v) misc.set("FogColor", v) end})
    worldSlider(World, "fog distance", "pf_world_fog_distance", "FogDistance", 50, 10000, 2000, 1)
    local Input, focused = game:GetService("UserInputService"), previousFocus ~= false
    runtime.focused = focused
    local function syncInput()
        if runtime.closed then return end
        runtime.focused = focused
        local enabled = aim.folder:GetAttribute("RageEnabled") == true
        local manual = enabled and Input:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        local blocked = not focused or Library.MenuOpen == true or Input:GetFocusedTextBox() ~= nil
        if aim.folder:GetAttribute("RageManual") ~= manual then aim.set("RageManual", manual) end
        if aim.folder:GetAttribute("RageBlocked") ~= blocked then aim.set("RageBlocked", blocked) end
    end
    runtime.connections[#runtime.connections + 1] = Input.WindowFocusReleased:Connect(function() focused = false; syncInput() end)
    runtime.connections[#runtime.connections + 1] = Input.WindowFocused:Connect(function() focused = true; syncInput() end)
    runtime.connections[#runtime.connections + 1] = game:GetService("RunService").RenderStepped:Connect(syncInput)
    Window:InitWindow(); syncInput()
    -- Include library-owned settings such as config-window visibility: no
    -- checkbox or gameplay option starts enabled unless explicitly selected.
    for flag,value in pairs(Library.Flags) do if type(value)=="boolean" and value and Library.SetFlags[flag] then Library.SetFlags[flag](false) end end
    runtime.startupTogglesOff = true
    for _,value in pairs(Library.Flags) do if type(value)=="boolean" and value then runtime.startupTogglesOff = false end end
    Library:Notification({Name = "Loaded. Right Shift toggles the menu.", Time = 3})
end, debug.traceback)
if not ok then pcall(runtime.unload); error("Vergil ReBorn initialization failed: " .. tostring(failure), 0) end
return runtime
