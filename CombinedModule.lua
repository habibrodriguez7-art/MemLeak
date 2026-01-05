local CombinedModules = {}

-- Module instantaaa
CombinedModules.instant = (function()
    -- ⚡ ULTRA SPEED AUTO FISHING v29.4 (Fast Mode - Safe Config Loading)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")
    local localPlayer = Players.LocalPlayer
    local Character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    local Humanoid = Character:WaitForChild("Humanoid")

    -- Hentikan script lama jika masih aktif
    if _G.FishingScriptFast then
        _G.FishingScriptFast.Stop()
        task.wait(0.1)
    end

    -- Inisialisasi koneksi network
    local netFolder = ReplicatedStorage
        :WaitForChild("Packages")
        :WaitForChild("_Index")
        :WaitForChild("sleitnick_net@0.2.0")
        :WaitForChild("net")

    local RF_ChargeFishingRod = netFolder:WaitForChild("RF/ChargeFishingRod")
    local RF_RequestMinigame = netFolder:WaitForChild("RF/RequestFishingMinigameStarted")
    local RF_CancelFishingInputs = netFolder:WaitForChild("RF/CancelFishingInputs")
    local RF_UpdateAutoFishingState = netFolder:WaitForChild("RF/UpdateAutoFishingState")
    local RE_FishingCompleted = netFolder:WaitForChild("RE/FishingCompleted")
    local RE_MinigameChanged = netFolder:WaitForChild("RE/FishingMinigameChanged")
    local RE_FishCaught = netFolder:WaitForChild("RE/FishCaught")

    -- ⭐ SAFE CONFIG LOADING - Check if function exists
    local function safeGetConfig(key, default)
        -- Check if GetConfigValue exists in _G
        if _G.GetConfigValue and type(_G.GetConfigValue) == "function" then
            local success, value = pcall(function()
                return _G.GetConfigValue(key, default)
            end)
            if success and value ~= nil then
                return value
            end
        end
        -- Return default if function doesn't exist or fails
        return default
    end

    -- ⭐ AUTO-LOAD SETTINGS FROM CONFIG (with safety check)
    local function loadConfigSettings()
        local maxWait = safeGetConfig("InstantFishing.FishingDelay", 1.30)
        local cancelDelay = safeGetConfig("InstantFishing.CancelDelay", 0.19)
        
        return maxWait, cancelDelay
    end

    -- Load settings saat module pertama kali diinisialisasi
    local initialMaxWait, initialCancelDelay = loadConfigSettings()

    -- Modul utama
    local fishing = {
        Running = false,
        WaitingHook = false,
        CurrentCycle = 0,
        TotalFish = 0,
        Connections = {},
        -- ⭐ Settings langsung dari config (dengan safety check)
        Settings = {
            FishingDelay = 0.01,
            CancelDelay = initialCancelDelay,
            HookDetectionDelay = 0.05,
            RetryDelay = 0.1,
            MaxWaitTime = initialMaxWait,
        }
    }

    _G.FishingScriptFast = fishing

    -- ⭐ Auto-refresh settings setiap kali akan Start (dengan safety check)
    local function refreshSettings()
        local maxWait = safeGetConfig("InstantFishing.FishingDelay", fishing.Settings.MaxWaitTime)
        local cancelDelay = safeGetConfig("InstantFishing.CancelDelay", fishing.Settings.CancelDelay)
        
        fishing.Settings.MaxWaitTime = maxWait
        fishing.Settings.CancelDelay = cancelDelay
    end

    -- Nonaktifkan animasi
    local function disableFishingAnim()
        pcall(function()
            for _, track in pairs(Humanoid:GetPlayingAnimationTracks()) do
                local name = track.Name:lower()
                if name:find("fish") or name:find("rod") or name:find("cast") or name:find("reel") then
                    track:Stop(0)
                end
            end
        end)

        task.spawn(function()
            local rod = Character:FindFirstChild("Rod") or Character:FindFirstChildWhichIsA("Tool")
            if rod and rod:FindFirstChild("Handle") then
                local handle = rod.Handle
                local weld = handle:FindFirstChildOfClass("Weld") or handle:FindFirstChildOfClass("Motor6D")
                if weld then
                    weld.C0 = CFrame.new(0, -1, -1.2) * CFrame.Angles(math.rad(-10), 0, 0)
                end
            end
        end)
    end

    -- Fungsi cast (⭐ Menggunakan Settings.MaxWaitTime dan Settings.CancelDelay)
    function fishing.Cast()
        if not fishing.Running or fishing.WaitingHook then return end

        disableFishingAnim()
        fishing.CurrentCycle += 1

        local castSuccess = pcall(function()
            RF_ChargeFishingRod:InvokeServer({[10] = tick()})
            task.wait(0.07)
            RF_RequestMinigame:InvokeServer(9, 0, tick())
            fishing.WaitingHook = true

            task.delay(fishing.Settings.MaxWaitTime * 0.7, function()
                if fishing.WaitingHook and fishing.Running then
                    pcall(function()
                        RE_FishingCompleted:FireServer()
                    end)
                end
            end)

            task.delay(fishing.Settings.MaxWaitTime, function()
                if fishing.WaitingHook and fishing.Running then
                    fishing.WaitingHook = false
                    pcall(function()
                        RE_FishingCompleted:FireServer()
                    end)

                    task.wait(fishing.Settings.RetryDelay)
                    pcall(function()
                        RF_CancelFishingInputs:InvokeServer()
                    end)

                    task.wait(fishing.Settings.FishingDelay)
                    if fishing.Running then
                        fishing.Cast()
                    end
                end
            end)
        end)

        if not castSuccess then
            task.wait(fishing.Settings.RetryDelay)
            if fishing.Running then
                fishing.Cast()
            end
        end
    end

    -- Start (⭐ Auto-refresh settings sebelum start)
    function fishing.Start()
        if fishing.Running then return end
        
        -- ⭐ Refresh settings dari config sebelum start
        refreshSettings()
        
        fishing.Running = true
        fishing.CurrentCycle = 0
        fishing.TotalFish = 0

        disableFishingAnim()

        fishing.Connections.Minigame = RE_MinigameChanged.OnClientEvent:Connect(function(state)
            if fishing.WaitingHook and typeof(state) == "string" then
                local s = string.lower(state)
                if string.find(s, "hook") or string.find(s, "bite") or string.find(s, "catch") then
                    fishing.WaitingHook = false
                    task.wait(fishing.Settings.HookDetectionDelay)

                    pcall(function()
                        RE_FishingCompleted:FireServer()
                    end)

                    task.wait(fishing.Settings.CancelDelay)
                    pcall(function()
                        RF_CancelFishingInputs:InvokeServer()
                    end)

                    task.wait(fishing.Settings.FishingDelay)
                    if fishing.Running then
                        fishing.Cast()
                    end
                end
            end
        end)

        fishing.Connections.Caught = RE_FishCaught.OnClientEvent:Connect(function(_, data)
            if fishing.Running then
                fishing.WaitingHook = false
                fishing.TotalFish += 1

                pcall(function()
                    task.wait(fishing.Settings.CancelDelay)
                    RF_CancelFishingInputs:InvokeServer()
                end)

                task.wait(fishing.Settings.FishingDelay)
                if fishing.Running then
                    fishing.Cast()
                end
            end
        end)

        fishing.Connections.AnimDisabler = task.spawn(function()
            while fishing.Running do
                disableFishingAnim()
                task.wait(0.15)
            end
        end)

        task.wait(0.5)
        fishing.Cast()
    end

    -- Stop
    function fishing.Stop()
        if not fishing.Running then return end
        fishing.Running = false
        fishing.WaitingHook = false

        for _, conn in pairs(fishing.Connections) do
            if typeof(conn) == "RBXScriptConnection" then
                conn:Disconnect()
            elseif typeof(conn) == "thread" then
                task.cancel(conn)
            end
        end
        fishing.Connections = {}
        
        pcall(function()
            RF_UpdateAutoFishingState:InvokeServer(true)
        end)
        
        task.wait(0.2)
        
        pcall(function()
            RF_CancelFishingInputs:InvokeServer()
        end)
    end

    -- ⭐ Function untuk update settings dari GUI (tetap ada untuk backward compatibility)
    function fishing.UpdateSettings(maxWaitTime, cancelDelay)
        if maxWaitTime then
            fishing.Settings.MaxWaitTime = maxWaitTime
        end
        if cancelDelay then
            fishing.Settings.CancelDelay = cancelDelay
        end
    end

    return fishing
end)()

-- Module blatantv1
CombinedModules.blatantv1 = (function()
    -- ⚠️ ULTRA BLATANT AUTO FISHING - GUI COMPATIBLE MODULE
    -- DESIGNED TO WORK WITH EXTERNAL GUI SYSTEM
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")

    -- Network initialization
    local netFolder = ReplicatedStorage
        :WaitForChild("Packages")
        :WaitForChild("_Index")
        :WaitForChild("sleitnick_net@0.2.0")
        :WaitForChild("net")

    local RF_ChargeFishingRod = netFolder:WaitForChild("RF/ChargeFishingRod")
    local RF_RequestMinigame = netFolder:WaitForChild("RF/RequestFishingMinigameStarted")
    local RF_CancelFishingInputs = netFolder:WaitForChild("RF/CancelFishingInputs")
    local RF_UpdateAutoFishingState = netFolder:WaitForChild("RF/UpdateAutoFishingState")  -- ⭐ ADDED untuk stop function
    local RE_FishingCompleted = netFolder:WaitForChild("RE/FishingCompleted")
    local RE_MinigameChanged = netFolder:WaitForChild("RE/FishingMinigameChanged")

    -- Module table
    local UltraBlatant = {}
    UltraBlatant.Active = false
    UltraBlatant.BackupConnection = nil  -- ⭐ MEMORY LEAK FIX: Track backup listener
    UltraBlatant.Stats = {
        castCount = 0,
        startTime = 0
    }

    -- Settings (sesuai dengan pattern GUI kamu)
    UltraBlatant.Settings = {
        CompleteDelay = 0.001,    -- Delay sebelum complete
        CancelDelay = 0.001       -- Delay setelah complete sebelum cancel
    }

    ----------------------------------------------------------------
    -- CORE FUNCTIONS
    ----------------------------------------------------------------

    local function safeFire(func)
        task.spawn(function()
            pcall(func)
        end)
    end

    -- MAIN SPAM LOOP
    local function ultraSpamLoop()
        while UltraBlatant.Active do
            local currentTime = tick()
            
            -- 1x CHARGE & REQUEST (CASTING)
            safeFire(function()
                RF_ChargeFishingRod:InvokeServer({[1] = currentTime})
            end)
            safeFire(function()
                RF_RequestMinigame:InvokeServer(1, 0, currentTime)
            end)
            
            UltraBlatant.Stats.castCount = UltraBlatant.Stats.castCount + 1
            
            -- Wait CompleteDelay then fire complete once
            task.wait(UltraBlatant.Settings.CompleteDelay)
            
            safeFire(function()
                RE_FishingCompleted:FireServer()
            end)
            
            -- Cancel with CancelDelay
            task.wait(UltraBlatant.Settings.CancelDelay)
            safeFire(function()
                RF_CancelFishingInputs:InvokeServer()
            end)
        end
    end

    -- ⭐ MEMORY LEAK FIX: Backup listener function (akan di-connect saat Start)
    local function setupBackupListener()
        -- Disconnect existing connection jika ada
        if UltraBlatant.BackupConnection then
            UltraBlatant.BackupConnection:Disconnect()
            UltraBlatant.BackupConnection = nil
        end
        
        UltraBlatant.BackupConnection = RE_MinigameChanged.OnClientEvent:Connect(function(state)
            if not UltraBlatant.Active then return end
            
            task.spawn(function()
                task.wait(UltraBlatant.Settings.CompleteDelay)
                
                safeFire(function()
                    RE_FishingCompleted:FireServer()
                end)
                
                task.wait(UltraBlatant.Settings.CancelDelay)
                safeFire(function()
                    RF_CancelFishingInputs:InvokeServer()
                end)
            end)
        end)
    end

    ----------------------------------------------------------------
    -- PUBLIC API (Compatible dengan pattern GUI kamu)
    ----------------------------------------------------------------

    -- ⭐ NEW: Update Settings function
    function UltraBlatant.UpdateSettings(completeDelay, cancelDelay)
        if completeDelay ~= nil then
            UltraBlatant.Settings.CompleteDelay = completeDelay
        end
        
        if cancelDelay ~= nil then
            UltraBlatant.Settings.CancelDelay = cancelDelay
        end
    end

    -- Start function
    function UltraBlatant.Start()
        if UltraBlatant.Active then 
            return
        end
        
        UltraBlatant.Active = true
        UltraBlatant.Stats.castCount = 0
        UltraBlatant.Stats.startTime = tick()
        
        -- ⭐ MEMORY LEAK FIX: Setup backup listener saat start
        setupBackupListener()
        
        task.spawn(ultraSpamLoop)
    end

    -- ⭐ ENHANCED Stop function - Nyalakan auto fishing game
    function UltraBlatant.Stop()
        if not UltraBlatant.Active then 
            return
        end
        
        UltraBlatant.Active = false
        
        -- ⭐ MEMORY LEAK FIX: Disconnect backup listener
        if UltraBlatant.BackupConnection then
            UltraBlatant.BackupConnection:Disconnect()
            UltraBlatant.BackupConnection = nil
        end
        
        -- ⭐ Nyalakan auto fishing game (biarkan tetap nyala)
        safeFire(function()
            RF_UpdateAutoFishingState:InvokeServer(true)
        end)
        
        -- Wait sebentar untuk game process
        task.wait(0.2)
        
        -- Cancel fishing inputs untuk memastikan karakter berhenti
        safeFire(function()
            RF_CancelFishingInputs:InvokeServer()
        end)
    end

    -- Return module
    return UltraBlatant
end)()

-- Module AntiAFK
CombinedModules.AntiAFK = (function()
    -- 💤 FungsiKeaby/Misc/AntiAFK.lua
    local VirtualUser = game:GetService("VirtualUser")
    local Players = game:GetService("Players")
    local localPlayer = Players.LocalPlayer

    local AntiAFK = {
        Enabled = false,
        Connection = nil
    }

    function AntiAFK.Start()
        if AntiAFK.Enabled then return end
        AntiAFK.Enabled = true
        print("🟢 Anti-AFK diaktifkan")

        AntiAFK.Connection = localPlayer.Idled:Connect(function()
            if AntiAFK.Enabled then
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
                print("💤 [AntiAFK] Mencegah kick karena idle...")
            end
        end)
    end

    function AntiAFK.Stop()
        if not AntiAFK.Enabled then return end
        AntiAFK.Enabled = false
        print("🔴 Anti-AFK dimatikan")

        if AntiAFK.Connection then
            AntiAFK.Connection:Disconnect()
            AntiAFK.Connection = nil
        end
    end

    return AntiAFK
end)()

-- Module UnlockFPS
CombinedModules.UnlockFPS = (function()
    -- ⚡ FungsiKeaby/Misc/UnlockFPS.lua
    local UnlockFPS = {
        Enabled = false,
        CurrentCap = 60,
    }

    -- daftar pilihan FPS yang bisa dipilih dari dropdown GUI
    UnlockFPS.AvailableCaps = {60, 90, 120, 240}

    function UnlockFPS.SetCap(fps)
        if setfpscap then
            setfpscap(fps)
            UnlockFPS.CurrentCap = fps
            print(string.format("🎯 [UnlockFPS] FPS cap diatur ke %d", fps))
        else
            warn("⚠️ setfpscap() tidak tersedia di executor kamu.")
        end
    end

    function UnlockFPS.Start()
        if UnlockFPS.Enabled then return end
        UnlockFPS.Enabled = true
        UnlockFPS.SetCap(UnlockFPS.CurrentCap)
        print(string.format("⚡ [UnlockFPS] Aktif (cap: %d)", UnlockFPS.CurrentCap))
    end

    function UnlockFPS.Stop()
        if not UnlockFPS.Enabled then return end
        UnlockFPS.Enabled = false
        if setfpscap then
            setfpscap(60)
            print("🛑 [UnlockFPS] Dinonaktifkan (kembali ke 60fps)")
        end
    end

    return UnlockFPS
end)()

-- Module FPSBooster
CombinedModules.FPSBooster = (function()
    -- ==============================================================
    --                ⭐ FPS BOOSTER MODULE (OPTIMIZED) ⭐
    --                    Ready untuk GUI Integration
    -- ==============================================================

    local FPSBooster = {}
    FPSBooster.Enabled = false

    local RunService = game:GetService("RunService")
    local Lighting = game:GetService("Lighting")
    local Terrain = workspace:FindFirstChildOfClass("Terrain")

    -- Storage untuk restore
    local originalStates = {
        reflectance = {},
        transparency = {},
        lighting = {},
        effects = {},
        waterProperties = {}
    }

    -- Connection untuk new objects
    local newObjectConnection = nil

    -- Fungsi untuk optimize single object
    local function optimizeObject(obj)
        if not FPSBooster.Enabled then return end
        
        pcall(function()
            -- Optimize BasePart (Bangunan, model, dll)
            if obj:IsA("BasePart") then
                -- Simpan original states (JANGAN UBAH WARNA & MATERIAL)
                if not originalStates.reflectance[obj] then
                    originalStates.reflectance[obj] = obj.Reflectance
                end
                
                -- Hapus reflections & shadows saja
                obj.Reflectance = 0
                obj.CastShadow = false
            end
            
            -- Matikan Decals & Textures
            if obj:IsA("Decal") or obj:IsA("Texture") then
                if not originalStates.transparency[obj] then
                    originalStates.transparency[obj] = obj.Transparency
                end
                obj.Transparency = 1 -- Invisible
            end
            
            -- Matikan SurfaceAppearance (texture PBR)
            if obj:IsA("SurfaceAppearance") then
                obj:Destroy()
            end
            
            -- Matikan ParticleEmitter (debu, asap, dll)
            if obj:IsA("ParticleEmitter") then
                obj.Enabled = false
            end
            
            -- Matikan Trail effects
            if obj:IsA("Trail") then
                obj.Enabled = false
            end
            
            -- Matikan Beam effects
            if obj:IsA("Beam") then
                obj.Enabled = false
            end
            
            -- Matikan Fire, Smoke, Sparkles
            if obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                obj.Enabled = false
            end
        end)
    end

    -- Fungsi untuk restore single object
    local function restoreObject(obj)
        pcall(function()
            if obj:IsA("BasePart") then
                if originalStates.reflectance[obj] then
                    obj.Reflectance = originalStates.reflectance[obj]
                    obj.CastShadow = true
                end
            end
            
            if obj:IsA("Decal") or obj:IsA("Texture") then
                if originalStates.transparency[obj] then
                    obj.Transparency = originalStates.transparency[obj]
                end
            end
            
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
                obj.Enabled = true
            end
            
            if obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                obj.Enabled = true
            end
        end)
    end

    -- ============================================
    -- MAIN ENABLE FUNCTION
    -- ============================================
    function FPSBooster.Enable()
        if FPSBooster.Enabled then
            return false, "Already enabled"
        end
        
        FPSBooster.Enabled = true
        
        -----------------------------------------
        -- 1. Optimize semua existing objects
        -----------------------------------------
        for _, obj in ipairs(workspace:GetDescendants()) do
            optimizeObject(obj)
        end
        
        -----------------------------------------
        -- 2. MATIKAN ANIMASI AIR (Terrain Water)
        -----------------------------------------
        if Terrain then
            pcall(function()
                -- Simpan water properties
                originalStates.waterProperties = {
                    WaterReflectance = Terrain.WaterReflectance,
                    WaterWaveSize = Terrain.WaterWaveSize,
                    WaterWaveSpeed = Terrain.WaterWaveSpeed
                }
                
                -- Matikan animasi air (WARNA TETAP DEFAULT)
                Terrain.WaterWaveSize = 0 -- NO WAVES
                Terrain.WaterWaveSpeed = 0 -- NO ANIMATION
                Terrain.WaterReflectance = 0 -- NO REFLECTION
            end)
        end
        
        -----------------------------------------
        -- 3. Optimize Lighting (Hapus Shadows & Fog)
        -----------------------------------------
        originalStates.lighting = {
            GlobalShadows = Lighting.GlobalShadows,
            FogEnd = Lighting.FogEnd,
            FogStart = Lighting.FogStart
        }
        
        Lighting.GlobalShadows = false -- NO SHADOWS
        Lighting.FogStart = 0
        Lighting.FogEnd = 1000000 -- NO FOG
        
        -----------------------------------------
        -- 4. Matikan Post-Processing Effects
        -----------------------------------------
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") then
                originalStates.effects[effect] = effect.Enabled
                effect.Enabled = false
            end
        end
        
        -----------------------------------------
        -- 5. Set Render Quality ke MINIMUM
        -----------------------------------------
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        
        -----------------------------------------
        -- 6. Hook new objects yang spawn
        -----------------------------------------
        newObjectConnection = workspace.DescendantAdded:Connect(function(obj)
            if FPSBooster.Enabled then
                task.wait(0.1) -- Delay kecil
                optimizeObject(obj)
            end
        end)
        
        return true, "FPS Booster enabled"
    end

    -- ============================================
    -- MAIN DISABLE FUNCTION
    -- ============================================
    function FPSBooster.Disable()
        if not FPSBooster.Enabled then
            return false, "Already disabled"
        end
        
        FPSBooster.Enabled = false
        
        -----------------------------------------
        -- 1. Restore semua objects
        -----------------------------------------
        for _, obj in ipairs(workspace:GetDescendants()) do
            restoreObject(obj)
        end
        
        -----------------------------------------
        -- 2. Restore Terrain Water
        -----------------------------------------
        if Terrain and originalStates.waterProperties then
            pcall(function()
                Terrain.WaterReflectance = originalStates.waterProperties.WaterReflectance
                Terrain.WaterWaveSize = originalStates.waterProperties.WaterWaveSize
                Terrain.WaterWaveSpeed = originalStates.waterProperties.WaterWaveSpeed
            end)
        end
        
        -----------------------------------------
        -- 3. Restore Lighting
        -----------------------------------------
        if originalStates.lighting.GlobalShadows ~= nil then
            Lighting.GlobalShadows = originalStates.lighting.GlobalShadows
            Lighting.FogEnd = originalStates.lighting.FogEnd
            Lighting.FogStart = originalStates.lighting.FogStart
        end
        
        -----------------------------------------
        -- 4. Restore Post-Processing
        -----------------------------------------
        for effect, state in pairs(originalStates.effects) do
            if effect and effect.Parent then
                effect.Enabled = state
            end
        end
        
        -----------------------------------------
        -- 5. Restore Render Quality
        -----------------------------------------
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
        
        -----------------------------------------
        -- 6. Disconnect hook
        -----------------------------------------
        if newObjectConnection then
            newObjectConnection:Disconnect()
            newObjectConnection = nil
        end
        
        -- Clear original states
        originalStates = {
            reflectance = {},
            transparency = {},
            lighting = {},
            effects = {},
            waterProperties = {}
        }
        
        return true, "FPS Booster disabled"
    end

    -- ============================================
    -- UTILITY FUNCTIONS
    -- ============================================
    function FPSBooster.IsEnabled()
        return FPSBooster.Enabled
    end

    return FPSBooster
end)()

-- Module instant2
CombinedModules.instant2 = (function()
    -- ⚡ ULTRA PERFECT CAST AUTO FISHING v35.2 (Safe Config Loading)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local localPlayer = Players.LocalPlayer
    local Character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    local Humanoid = Character:WaitForChild("Humanoid")

    if _G.FishingScript then
        _G.FishingScript.Stop()
        task.wait(0.1)
    end

    local netFolder = ReplicatedStorage
        :WaitForChild("Packages")
        :WaitForChild("_Index")
        :WaitForChild("sleitnick_net@0.2.0")
        :WaitForChild("net")

    local RF_ChargeFishingRod = netFolder:WaitForChild("RF/ChargeFishingRod")
    local RF_RequestMinigame = netFolder:WaitForChild("RF/RequestFishingMinigameStarted")
    local RF_CancelFishingInputs = netFolder:WaitForChild("RF/CancelFishingInputs")
    local RF_UpdateAutoFishingState = netFolder:WaitForChild("RF/UpdateAutoFishingState")
    local RE_FishingCompleted = netFolder:WaitForChild("RE/FishingCompleted")
    local RE_MinigameChanged = netFolder:WaitForChild("RE/FishingMinigameChanged")
    local RE_FishCaught = netFolder:WaitForChild("RE/FishCaught")
    local RE_FishingStopped = netFolder:WaitForChild("RE/FishingStopped")

    -- ⭐ SAFE CONFIG LOADING - Check if function exists
    local function safeGetConfig(key, default)
        -- Check if GetConfigValue exists in _G
        if _G.GetConfigValue and type(_G.GetConfigValue) == "function" then
            local success, value = pcall(function()
                return _G.GetConfigValue(key, default)
            end)
            if success and value ~= nil then
                return value
            end
        end
        -- Return default if function doesn't exist or fails
        return default
    end

    -- ⭐ SAFE: Load saved settings dari GUI config
    local function loadSavedSettings()
        local maxWait = safeGetConfig("InstantFishing.FishingDelay", 1.5)
        local cancelDelay = safeGetConfig("InstantFishing.CancelDelay", 0.19)
        
        return {
            MaxWaitTime = maxWait,
            CancelDelay = cancelDelay
        }
    end

    local savedSettings = loadSavedSettings()

    local fishing = {
        Running = false,
        WaitingHook = false,
        CurrentCycle = 0,
        TotalFish = 0,
        PerfectCasts = 0,
        AmazingCasts = 0,
        FailedCasts = 0,
        Connections = {},
        Settings = {
            FishingDelay = 0.07,
            CancelDelay = savedSettings.CancelDelay,  -- ⭐ Use saved value
            HookDetectionDelay = 0.03,
            RetryDelay = 0.04,
            MaxWaitTime = savedSettings.MaxWaitTime,  -- ⭐ Use saved value
            FailTimeout = 2.5,
            PerfectChargeTime = 0.34,
            PerfectReleaseDelay = 0.005,
            PerfectPower = 0.95,
            UseMultiDetection = true,
            UseVisualDetection = true,
            UseSoundDetection = false,
        }
    }

    _G.FishingScript = fishing

    -- ⭐ Auto-refresh settings setiap kali akan Start (dengan safety check)
    local function refreshSettings()
        local maxWait = safeGetConfig("InstantFishing.FishingDelay", fishing.Settings.MaxWaitTime)
        local cancelDelay = safeGetConfig("InstantFishing.CancelDelay", fishing.Settings.CancelDelay)
        
        fishing.Settings.MaxWaitTime = maxWait
        fishing.Settings.CancelDelay = cancelDelay
    end

    local function disableFishingAnim()
        pcall(function()
            for _, track in pairs(Humanoid:GetPlayingAnimationTracks()) do
                local name = track.Name:lower()
                if name:find("fish") or name:find("rod") or name:find("cast") or name:find("reel") then
                    track:Stop(0)
                    track.TimePosition = 0
                end
            end
        end)

        task.spawn(function()
            local rod = Character:FindFirstChild("Rod") or Character:FindFirstChildWhichIsA("Tool")
            if rod and rod:FindFirstChild("Handle") then
                local handle = rod.Handle
                local weld = handle:FindFirstChildOfClass("Weld") or handle:FindFirstChildOfClass("Motor6D")
                if weld then
                    weld.C0 = CFrame.new(0, -1, -1.2) * CFrame.Angles(math.rad(-10), 0, 0)
                end
            end
        end)
    end

    local function handleFailedCast()
        fishing.WaitingHook = false
        fishing.FailedCasts += 1
        
        pcall(function()
            RF_CancelFishingInputs:InvokeServer()
        end)
        
        task.wait(fishing.Settings.RetryDelay)
        
        if fishing.Running then
            fishing.PerfectCast()
        end
    end

    function fishing.PerfectCast()
        if not fishing.Running or fishing.WaitingHook then 
            return 
        end

        disableFishingAnim()
        fishing.CurrentCycle += 1

        local castSuccess = pcall(function()
            local startTime = tick()
            local chargeData = {[1] = startTime}
            
            local chargeResult = RF_ChargeFishingRod:InvokeServer(chargeData)
            if not chargeResult then 
                error("Charge fishing rod failed") 
            end

            local waitTime = fishing.Settings.PerfectChargeTime
            local endTime = tick() + waitTime
            while tick() < endTime and fishing.Running do
                task.wait(0.01)
            end

            task.wait(fishing.Settings.PerfectReleaseDelay)

            local releaseTime = tick()
            local perfectPower = 0.95

            local minigameResult = RF_RequestMinigame:InvokeServer(
                perfectPower,
                0,
                releaseTime
            )
            
            if not minigameResult then 
                handleFailedCast()
                return
            end

            fishing.WaitingHook = true
            local hookDetected = false
            local castStartTime = tick()
            local eventDetection

            eventDetection = RE_MinigameChanged.OnClientEvent:Connect(function(state)
                if fishing.WaitingHook and typeof(state) == "string" then
                    local s = state:lower()
                    if s:find("hook") or s:find("bite") or s:find("catch") or s == "!" then
                        hookDetected = true
                        eventDetection:Disconnect()
                        
                        fishing.WaitingHook = false

                        task.wait(fishing.Settings.HookDetectionDelay)
                        pcall(function()
                            RE_FishingCompleted:FireServer()
                        end)

                        task.wait(fishing.Settings.CancelDelay)
                        pcall(function()
                            RF_CancelFishingInputs:InvokeServer()
                        end)

                        task.wait(fishing.Settings.FishingDelay)
                        if fishing.Running then
                            fishing.PerfectCast()
                        end
                    end
                end
            end)

            task.delay(fishing.Settings.MaxWaitTime, function()
                if fishing.WaitingHook and fishing.Running then
                    if not hookDetected then
                        fishing.WaitingHook = false
                        eventDetection:Disconnect()

                        pcall(function()
                            RE_FishingCompleted:FireServer()
                        end)

                        task.wait(fishing.Settings.RetryDelay)
                        pcall(function()
                            RF_CancelFishingInputs:InvokeServer()
                        end)

                        task.wait(fishing.Settings.FishingDelay)
                        if fishing.Running then
                            fishing.PerfectCast()
                        end
                    end
                end
            end)
            
            task.delay(fishing.Settings.FailTimeout, function()
                if fishing.WaitingHook and fishing.Running then
                    local elapsedTime = tick() - castStartTime
                    
                    if elapsedTime >= fishing.Settings.FailTimeout then
                        if eventDetection then
                            eventDetection:Disconnect()
                        end
                        
                        handleFailedCast()
                    end
                end
            end)
        end)

        if not castSuccess then
            task.wait(fishing.Settings.RetryDelay)
            if fishing.Running then
                fishing.PerfectCast()
            end
        end
    end

    function fishing.Start()
        if fishing.Running then return end
        
        -- ⭐ Refresh settings dari config sebelum start
        refreshSettings()
        
        fishing.Running = true
        fishing.CurrentCycle = 0
        fishing.TotalFish = 0
        fishing.PerfectCasts = 0
        fishing.AmazingCasts = 0
        fishing.FailedCasts = 0

        disableFishingAnim()

        fishing.Connections.FishingStopped = RE_FishingStopped.OnClientEvent:Connect(function()
            if fishing.Running and fishing.WaitingHook then
                handleFailedCast()
            end
        end)

        fishing.Connections.Caught = RE_FishCaught.OnClientEvent:Connect(function(name, data)
            if fishing.Running then
                fishing.WaitingHook = false
                fishing.TotalFish += 1

                local castResult = data and data.CastResult or "Unknown"
                if castResult == "Perfect" then
                    fishing.PerfectCasts += 1
                elseif castResult == "Amazing" then
                    fishing.AmazingCasts += 1
                end

                task.wait(fishing.Settings.CancelDelay)
                pcall(function()
                    RF_CancelFishingInputs:InvokeServer()
                end)

                task.wait(fishing.Settings.FishingDelay)
                if fishing.Running then
                    fishing.PerfectCast()
                end
            end
        end)

        fishing.Connections.AnimDisabler = task.spawn(function()
            while fishing.Running do
                disableFishingAnim()
                task.wait(0.1)
            end
        end)

        fishing.Connections.StatsReporter = task.spawn(function()
            while fishing.Running do
                task.wait(30)
            end
        end)

        task.wait(0.3)
        fishing.PerfectCast()
    end

    function fishing.Stop()
        if not fishing.Running then return end
        fishing.Running = false
        fishing.WaitingHook = false

        for _, conn in pairs(fishing.Connections) do
            if typeof(conn) == "RBXScriptConnection" then
                conn:Disconnect()
            elseif typeof(conn) == "thread" then
                task.cancel(conn)
            end
        end

        fishing.Connections = {}
        
        pcall(function()
            RF_UpdateAutoFishingState:InvokeServer(true)
        end)
        
        task.wait(0.2)
        
        pcall(function()
            RF_CancelFishingInputs:InvokeServer()
        end)
    end

    -- ⭐ Function untuk update settings dari GUI (tetap ada untuk backward compatibility)
    function fishing.UpdateSettings(maxWaitTime, cancelDelay)
        if maxWaitTime then
            fishing.Settings.MaxWaitTime = maxWaitTime
        end
        if cancelDelay then
            fishing.Settings.CancelDelay = cancelDelay
        end
    end

    return fishing
end)()

-- Module UltraBlatant
CombinedModules.UltraBlatant = (function()
    -- ⚡ ULTRA BLATANT AUTO FISHING MODULE - CLEAN VERSION
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")

    -- Network initialization
    local netFolder = ReplicatedStorage
        :WaitForChild("Packages")
        :WaitForChild("_Index")
        :WaitForChild("sleitnick_net@0.2.0")
        :WaitForChild("net")
        
    local RF_ChargeFishingRod = netFolder:WaitForChild("RF/ChargeFishingRod")
    local RF_RequestMinigame = netFolder:WaitForChild("RF/RequestFishingMinigameStarted")
    local RF_CancelFishingInputs = netFolder:WaitForChild("RF/CancelFishingInputs")
    local RF_UpdateAutoFishingState = netFolder:WaitForChild("RF/UpdateAutoFishingState")
    local RE_FishingCompleted = netFolder:WaitForChild("RE/FishingCompleted")
    local RE_MinigameChanged = netFolder:WaitForChild("RE/FishingMinigameChanged")

    -- Module
    local UltraBlatant = {}
    UltraBlatant.Active = false
    UltraBlatant.BackupConnection = nil  -- ⭐ MEMORY LEAK FIX

    UltraBlatant.Settings = {
        CompleteDelay = 0.73,
        CancelDelay = 0.3,
        ReCastDelay = 0.001
    }

    -- State tracking
    local FishingState = {
        lastCompleteTime = 0,
        completeCooldown = 0.4
    }

    ----------------------------------------------------------------
    -- CORE FUNCTIONS
    ----------------------------------------------------------------

    local function safeFire(func)
        task.spawn(function()
            pcall(func)
        end)
    end

    local function protectedComplete()
        local now = tick()
        
        if now - FishingState.lastCompleteTime < FishingState.completeCooldown then
            return false
        end
        
        FishingState.lastCompleteTime = now
        safeFire(function()
            RE_FishingCompleted:FireServer()
        end)
        
        return true
    end

    local function performCast()
        local now = tick()
        
        safeFire(function()
            RF_ChargeFishingRod:InvokeServer({[1] = now})
        end)
        safeFire(function()
            RF_RequestMinigame:InvokeServer(1, 0, now)
        end)
    end

    local function fishingLoop()
        while UltraBlatant.Active do
            performCast()
            
            task.wait(UltraBlatant.Settings.CompleteDelay)
            
            if UltraBlatant.Active then
                protectedComplete()
            end
            
            task.wait(UltraBlatant.Settings.CancelDelay)
            
            if UltraBlatant.Active then
                safeFire(function()
                    RF_CancelFishingInputs:InvokeServer()
                end)
            end
            
            task.wait(UltraBlatant.Settings.ReCastDelay)
        end
    end

    -- ⭐ MEMORY LEAK FIX: Backup listener vars
    local lastEventTime = 0
    
    local function setupBackupListener()
        if UltraBlatant.BackupConnection then
            UltraBlatant.BackupConnection:Disconnect()
            UltraBlatant.BackupConnection = nil
        end
        
        UltraBlatant.BackupConnection = RE_MinigameChanged.OnClientEvent:Connect(function(state)
            if not UltraBlatant.Active then return end
            
            local now = tick()
            
            if now - lastEventTime < 0.2 then
                return
            end
            lastEventTime = now
            
            if now - FishingState.lastCompleteTime < 0.3 then
                return
            end
            
            task.spawn(function()
                task.wait(UltraBlatant.Settings.CompleteDelay)
                
                if protectedComplete() then
                    task.wait(UltraBlatant.Settings.CancelDelay)
                    safeFire(function()
                        RF_CancelFishingInputs:InvokeServer()
                    end)
                end
            end)
        end)
    end

    ----------------------------------------------------------------
    -- PUBLIC API
    ----------------------------------------------------------------

    function UltraBlatant.UpdateSettings(completeDelay, cancelDelay, reCastDelay)
        if completeDelay ~= nil then
            UltraBlatant.Settings.CompleteDelay = completeDelay
        end
        
        if cancelDelay ~= nil then
            UltraBlatant.Settings.CancelDelay = cancelDelay
        end
        
        if reCastDelay ~= nil then
            UltraBlatant.Settings.ReCastDelay = reCastDelay
        end
    end

    function UltraBlatant.Start()
        if UltraBlatant.Active then 
            return
        end
        
        UltraBlatant.Active = true
        FishingState.lastCompleteTime = 0
        
        -- ⭐ MEMORY LEAK FIX: Setup backup listener
        setupBackupListener()
        
        safeFire(function()
            RF_UpdateAutoFishingState:InvokeServer(true)
        end)
        
        task.wait(0.2)
        task.spawn(fishingLoop)
    end

    function UltraBlatant.Stop()
        if not UltraBlatant.Active then 
            return
        end
        
        UltraBlatant.Active = false
        
        -- ⭐ MEMORY LEAK FIX: Disconnect backup listener
        if UltraBlatant.BackupConnection then
            UltraBlatant.BackupConnection:Disconnect()
            UltraBlatant.BackupConnection = nil
        end
        
        safeFire(function()
            RF_UpdateAutoFishingState:InvokeServer(true)
        end)
        
        task.wait(0.2)
        
        safeFire(function()
            RF_CancelFishingInputs:InvokeServer()
        end)
    end

    return UltraBlatant
end)()

-- Module FreecamModule
CombinedModules.FreecamModule = (function()
-- ============================================
-- FREECAM MODULE - UNIVERSAL PC & MOBILE
-- ============================================
-- File: FreecamModule.lua

local FreecamModule = {}

-- Services
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Variables
local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local PlayerGui = Player:WaitForChild("PlayerGui")

local freecam = false
local camPos = Vector3.new()
local camRot = Vector3.new()
local speed = 50
local sensitivity = 0.3
local hiddenGuis = {}

-- Mobile detection
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

-- Mobile joystick variables
local mobileJoystickInput = Vector3.new(0, 0, 0)
local joystickConnections = {}
local dynamicThumbstick = nil
local thumbstickCenter = Vector2.new(0, 0)
local thumbstickRadius = 60

-- Touch input for camera rotation
local cameraTouch = nil
local cameraTouchStartPos = nil
local joystickTouch = nil

-- Connections
local renderConnection = nil
local inputChangedConnection = nil
local inputEndedConnection = nil
local inputBeganConnection = nil

-- Character references
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

Player.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = Character:WaitForChild("Humanoid")
end)

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

local function LockCharacter(state)
    if not Humanoid then return end
    
    if state then
        Humanoid.WalkSpeed = 0
        Humanoid.JumpPower = 0
        Humanoid.AutoRotate = false
        if Character:FindFirstChild("HumanoidRootPart") then
            Character.HumanoidRootPart.Anchored = true
        end
    else
        Humanoid.WalkSpeed = 16
        Humanoid.JumpPower = 50
        Humanoid.AutoRotate = true
        if Character:FindFirstChild("HumanoidRootPart") then
            Character.HumanoidRootPart.Anchored = false
        end
    end
end

local function HideAllGuis()
    hiddenGuis = {}
    
    for _, gui in pairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            if mainGuiName and gui.Name == mainGuiName then
                continue
            end
            
            local guiName = gui.Name:lower()
            if guiName:find("main") or guiName:find("hub") or guiName:find("menu") or guiName:find("ui") then
                continue
            end
            
            table.insert(hiddenGuis, gui)
            gui.Enabled = false
        end
    end
end

local function ShowAllGuis()
    for _, gui in pairs(hiddenGuis) do
        if gui and gui:IsA("ScreenGui") then
            gui.Enabled = true
        end
    end
    
    hiddenGuis = {}
end

local function GetMovement()
    local move = Vector3.zero
    
    if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + Vector3.new(0, 0, 1) end
    if UIS:IsKeyDown(Enum.KeyCode.S) then move = move + Vector3.new(0, 0, -1) end
    if UIS:IsKeyDown(Enum.KeyCode.A) then move = move + Vector3.new(-1, 0, 0) end
    if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + Vector3.new(1, 0, 0) end
    if UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E) then 
        move = move + Vector3.new(0, 1, 0) 
    end
    if UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.Q) then 
        move = move + Vector3.new(0, -1, 0) 
    end
    
    if isMobile then
        move = move + mobileJoystickInput
    end
    
    return move
end

-- ============================================
-- MOBILE JOYSTICK DETECTION
-- ============================================

local function DetectDynamicThumbstick()
    if not isMobile then return end
    
    local function searchForThumbstick(parent, depth)
        depth = depth or 0
        if depth > 10 then return end
        
        for _, child in pairs(parent:GetChildren()) do
            local name = child.Name:lower()
            if name:find("thumbstick") or name:find("joystick") then
                if child:IsA("Frame") then
                    return child
                end
            end
            local result = searchForThumbstick(child, depth + 1)
            if result then return result end
        end
        return nil
    end
    
    pcall(function()
        dynamicThumbstick = searchForThumbstick(PlayerGui)
        
        if dynamicThumbstick then
            print("✅ DynamicThumbstick terdeteksi: " .. dynamicThumbstick.Name)
            
            -- Hitung center dan radius thumbstick
            local pos = dynamicThumbstick.AbsolutePosition
            local size = dynamicThumbstick.AbsoluteSize
            thumbstickCenter = pos + (size / 2)
            thumbstickRadius = math.min(size.X, size.Y) / 2
            
            print("📍 Thumbstick Center: " .. tostring(thumbstickCenter))
            print("📏 Thumbstick Radius: " .. thumbstickRadius)
        end
    end)
end

local function IsPositionInThumbstick(pos)
    if not dynamicThumbstick then return false end
    
    -- Fallback: check absolute position dari thumbstick frame
    local thumbPos = dynamicThumbstick.AbsolutePosition
    local thumbSize = dynamicThumbstick.AbsoluteSize
    
    -- Check apakah pos berada dalam bounding box thumbstick
    local isWithinX = pos.X >= thumbPos.X - 50 and pos.X <= (thumbPos.X + thumbSize.X + 50)
    local isWithinY = pos.Y >= thumbPos.Y - 50 and pos.Y <= (thumbPos.Y + thumbSize.Y + 50)
    
    return isWithinX and isWithinY
end

local function GetJoystickInput(touchPos)
    if not dynamicThumbstick then return Vector3.new(0, 0, 0) end
    
    -- Convert to Vector2
    local touchPos2D = Vector2.new(touchPos.X, touchPos.Y)
    local delta = touchPos2D - thumbstickCenter
    local magnitude = delta.Magnitude
    
    if magnitude < 5 then
        return Vector3.new(0, 0, 0)
    end
    
    -- Normalize joystick input
    local maxDist = thumbstickRadius
    local normalized = delta / maxDist
    
    -- Clamp nilai
    normalized = Vector2.new(
        math.max(-1, math.min(1, normalized.X)),
        math.max(-1, math.min(1, normalized.Y))
    )
    
    -- Convert to movement direction (X = strafe, Z = forward)
    return Vector3.new(normalized.X, 0, normalized.Y)
end

-- ============================================
-- MAIN FREECAM FUNCTIONS
-- ============================================

function FreecamModule.Start()
    if freecam then return end
    
    freecam = true
    
    local currentCF = Camera.CFrame
    camPos = currentCF.Position
    local x, y, z = currentCF:ToEulerAnglesYXZ()
    camRot = Vector3.new(x, y, z)
    
    LockCharacter(true)
    HideAllGuis()
    Camera.CameraType = Enum.CameraType.Scriptable
    
    task.wait()
    
    if not isMobile then
        UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
        UIS.MouseIconEnabled = false
    else
        DetectDynamicThumbstick()
    end
    
    -- Mobile input handling
    if isMobile then
        inputBeganConnection = UIS.InputBegan:Connect(function(input, gameProcessed)
            if not freecam then return end
            
            if input.UserInputType == Enum.UserInputType.Touch then
                local pos = input.Position
                
                -- Gunakan pcall untuk avoid error dari script game lain
                local isInThumbstick = false
                pcall(function()
                    isInThumbstick = IsPositionInThumbstick(pos)
                end)
                
                if isInThumbstick then
                    joystickTouch = input
                else
                    -- Camera touch di area lain
                    cameraTouch = input
                    cameraTouchStartPos = input.Position
                end
            end
        end)
        
        inputChangedConnection = UIS.InputChanged:Connect(function(input, gameProcessed)
            if not freecam then return end
            
            if input.UserInputType == Enum.UserInputType.Touch then
                -- Handle joystick touch
                if input == joystickTouch then
                    pcall(function()
                        mobileJoystickInput = GetJoystickInput(input.Position)
                    end)
                end
                
                -- Handle camera touch
                if input == cameraTouch and cameraTouch then
                    local delta = input.Position - cameraTouchStartPos
                    
                    if delta.Magnitude > 0 then
                        camRot = camRot + Vector3.new(
                            -delta.Y * sensitivity * 0.003,
                            -delta.X * sensitivity * 0.003,
                            0
                        )
                        
                        cameraTouchStartPos = input.Position
                    end
                end
            end
        end)
        
        inputEndedConnection = UIS.InputEnded:Connect(function(input, gameProcessed)
            if not freecam then return end
            
            if input.UserInputType == Enum.UserInputType.Touch then
                if input == joystickTouch then
                    joystickTouch = nil
                    mobileJoystickInput = Vector3.new(0, 0, 0)
                end
                
                if input == cameraTouch then
                    cameraTouch = nil
                    cameraTouchStartPos = nil
                end
            end
        end)
    end
    
    renderConnection = RunService.RenderStepped:Connect(function(dt)
        if not freecam then return end
        
        if not isMobile then
            local mouseDelta = UIS:GetMouseDelta()
            
            if mouseDelta.Magnitude > 0 then
                camRot = camRot + Vector3.new(
                    -mouseDelta.Y * sensitivity * 0.01,
                    -mouseDelta.X * sensitivity * 0.01,
                    0
                )
            end
        end
        
        local rotationCF = CFrame.new(camPos) * CFrame.fromEulerAnglesYXZ(camRot.X, camRot.Y, camRot.Z)
        
        local moveInput = GetMovement()
        if moveInput.Magnitude > 0 then
            moveInput = moveInput.Unit
            
            local moveCF = CFrame.new(camPos) * CFrame.fromEulerAnglesYXZ(camRot.X, camRot.Y, camRot.Z)
            local velocity = (moveCF.LookVector * moveInput.Z) +
                             (moveCF.RightVector * moveInput.X) +
                             (moveCF.UpVector * moveInput.Y)
            
            camPos = camPos + velocity * speed * dt
        end
        
        Camera.CFrame = CFrame.new(camPos) * CFrame.fromEulerAnglesYXZ(camRot.X, camRot.Y, camRot.Z)
    end)
    
    return true
end

function FreecamModule.Stop()
    if not freecam then return end
    
    freecam = false
    
    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
    
    if inputChangedConnection then
        inputChangedConnection:Disconnect()
        inputChangedConnection = nil
    end
    
    if inputEndedConnection then
        inputEndedConnection:Disconnect()
        inputEndedConnection = nil
    end
    
    if inputBeganConnection then
        inputBeganConnection:Disconnect()
        inputBeganConnection = nil
    end
    
    for _, conn in pairs(joystickConnections) do
        if conn then
            conn:Disconnect()
        end
    end
    joystickConnections = {}
    
    LockCharacter(false)
    ShowAllGuis()
    Camera.CameraType = Enum.CameraType.Custom
    Camera.CameraSubject = Humanoid
    
    UIS.MouseBehavior = Enum.MouseBehavior.Default
    UIS.MouseIconEnabled = true
    
    cameraTouch = nil
    cameraTouchStartPos = nil
    joystickTouch = nil
    mobileJoystickInput = Vector3.new(0, 0, 0)
    
    return true
end

function FreecamModule.Toggle()
    if freecam then
        return FreecamModule.Stop()
    else
        return FreecamModule.Start()
    end
end

function FreecamModule.IsActive()
    return freecam
end

function FreecamModule.SetSpeed(newSpeed)
    speed = math.max(1, newSpeed)
end

function FreecamModule.SetSensitivity(newSensitivity)
    sensitivity = math.max(0.01, math.min(5, newSensitivity))
end

function FreecamModule.GetSpeed()
    return speed
end

function FreecamModule.GetSensitivity()
    return sensitivity
end

-- ============================================
-- SET MAIN GUI NAME
-- ============================================
local mainGuiName = nil

function FreecamModule.SetMainGuiName(guiName)
    mainGuiName = guiName
    print("✅ Main GUI set to: " .. guiName)
end

function FreecamModule.GetMainGuiName()
    return mainGuiName
end

-- ============================================
-- F3 KEYBIND - PC ONLY (MASTER SWITCH LOGIC)
-- ============================================
local f3KeybindActive = false

function FreecamModule.EnableF3Keybind(enable)
    f3KeybindActive = enable
    
    -- Jika toggle GUI dimatikan, matikan freecam juga
    if not enable and freecam then
        FreecamModule.Stop()
        print("🔴 Freecam disabled (Toggle GUI OFF)")
    end
    
    if not isMobile then
        local status = f3KeybindActive and "ENABLED (Press F3 to activate)" or "DISABLED"
        print("⚙️ F3 Keybind: " .. status)
    end
end

function FreecamModule.IsF3KeybindActive()
    return f3KeybindActive
end

-- F3 Input Handler (PC Only)
if not isMobile then
    UIS.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        -- Cek apakah F3 ditekan DAN toggle GUI aktif
        if input.KeyCode == Enum.KeyCode.F3 and f3KeybindActive then
            FreecamModule.Toggle()
            
            if freecam then
                print("🎥 Freecam ACTIVATED via F3")
            else
                print("🔴 Freecam DEACTIVATED via F3")
            end
        end
    end)
end


return FreecamModule
end)()

-- Module UnlimitedZoom
CombinedModules.UnlimitedZoom = (function()
-- ============================================
-- UNLIMITED ZOOM CAMERA MODULE
-- ============================================
-- Character can walk normally, camera can zoom unlimited

local UnlimitedZoomModule = {}

-- Services
local Players = game:GetService("Players")

-- Variables
local Player = Players.LocalPlayer

-- Save original zoom settings
local originalMinZoom = Player.CameraMinZoomDistance
local originalMaxZoom = Player.CameraMaxZoomDistance

-- State
local unlimitedZoomActive = false

-- ============================================
-- MAIN FUNCTIONS
-- ============================================

function UnlimitedZoomModule.Enable()
    if unlimitedZoomActive then return false end
    
    unlimitedZoomActive = true
    
    -- Remove zoom limits (character can still move)
    Player.CameraMinZoomDistance = 0.5
    Player.CameraMaxZoomDistance = 9999
    
    print("✅ Unlimited Zoom: ENABLED")
    print("📷 Scroll to zoom in/out without limits")
    print("🏃 Character can move normally")
    
    return true
end

function UnlimitedZoomModule.Disable()
    if not unlimitedZoomActive then return false end
    
    unlimitedZoomActive = false
    
    -- Restore original zoom limits
    Player.CameraMinZoomDistance = originalMinZoom
    Player.CameraMaxZoomDistance = originalMaxZoom
    
    print("🔴 Unlimited Zoom: DISABLED")
    print("📷 Zoom limits restored")
    
    return true
end

function UnlimitedZoomModule.IsActive()
    return unlimitedZoomActive
end


return UnlimitedZoomModule
end)()

-- Module DisableRendering
CombinedModules.DisableRendering = (function()
-- =====================================================
-- DISABLE 3D RENDERING MODULE (CLEAN VERSION)
-- For integration with Lynx GUI v2.3
-- =====================================================

local DisableRendering = {}

-- =====================================================
-- SERVICES
-- =====================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- =====================================================
-- CONFIGURATION
-- =====================================================
DisableRendering.Settings = {
    AutoPersist = true -- Keep active after respawn
}

-- =====================================================
-- STATE VARIABLES
-- =====================================================
local State = {
    RenderingDisabled = false,
    RenderConnection = nil
}

-- =====================================================
-- PUBLIC API FUNCTIONS
-- =====================================================

-- Start disable rendering
function DisableRendering.Start()
    if State.RenderingDisabled then
        return false, "Already disabled"
    end
    
    local success, err = pcall(function()
        -- Disable 3D rendering
        State.RenderConnection = RunService.RenderStepped:Connect(function()
            pcall(function()
                RunService:Set3dRenderingEnabled(false)
            end)
        end)
        
        State.RenderingDisabled = true
    end)
    
    if not success then
        warn("[DisableRendering] Failed to start:", err)
        return false, "Failed to start"
    end
    
    return true, "Rendering disabled"
end

-- Stop disable rendering
function DisableRendering.Stop()
    if not State.RenderingDisabled then
        return false, "Already enabled"
    end
    
    local success, err = pcall(function()
        -- Disconnect render loop
        if State.RenderConnection then
            State.RenderConnection:Disconnect()
            State.RenderConnection = nil
        end
        
        -- Re-enable rendering
        RunService:Set3dRenderingEnabled(true)
        
        State.RenderingDisabled = false
    end)
    
    if not success then
        warn("[DisableRendering] Failed to stop:", err)
        return false, "Failed to stop"
    end
    
    return true, "Rendering enabled"
end

-- Toggle rendering
function DisableRendering.Toggle()
    if State.RenderingDisabled then
        return DisableRendering.Stop()
    else
        return DisableRendering.Start()
    end
end

-- Get current status
function DisableRendering.IsDisabled()
    return State.RenderingDisabled
end

-- =====================================================
-- AUTO-PERSIST ON RESPAWN
-- =====================================================
if DisableRendering.Settings.AutoPersist then
    LocalPlayer.CharacterAdded:Connect(function()
        if State.RenderingDisabled then
            task.wait(0.5)
            pcall(function()
                RunService:Set3dRenderingEnabled(false)
            end)
        end
    end)
end

-- =====================================================
-- CLEANUP FUNCTION
-- =====================================================
function DisableRendering.Cleanup()
    -- Enable rendering if disabled
    if State.RenderingDisabled then
        pcall(function()
            RunService:Set3dRenderingEnabled(true)
        end)
    end
    
    -- Disconnect all connections
    if State.RenderConnection then
        State.RenderConnection:Disconnect()
    end
end

return DisableRendering
end)()

-- Module HideStats
CombinedModules.HideStats = (function()
-- Hide Stats Identifier Module untuk Fisch Roblox
-- Standalone version untuk dipanggil via loadstring

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local HideStatsModule = {}

-- Settings
local HideStatsEnabled = false
local FakeName = "Bagi Sikrit bang"
local FakeLevel = "1"
local ScriptName = "-LynX-"

-- Variable untuk menyimpan original text
local OriginalTexts = {}
local ActiveGradientThreads = {}

-- Warna untuk efek shimmer/berkilau Orange-Putih
local ShimmerColors = {
    Color3.fromRGB(255, 140, 0),   -- Dark Orange
    Color3.fromRGB(255, 180, 50),  -- Orange
    Color3.fromRGB(255, 220, 150), -- Light Orange
    Color3.fromRGB(255, 255, 255), -- Putih (kilau)
    Color3.fromRGB(255, 220, 150), -- Light Orange
    Color3.fromRGB(255, 180, 50),  -- Orange
    Color3.fromRGB(255, 140, 0),   -- Dark Orange
}

-- Fungsi untuk membuat UIGradient shimmer effect yang bergerak
local function createMovingGradient(label)
    if not label or not label:IsA("TextLabel") then return end
    
    -- Hapus gradient lama jika ada
    local oldGradient = label:FindFirstChild("ShimmerGradient")
    if oldGradient then oldGradient:Destroy() end
    
    -- Buat UIGradient baru
    local gradient = Instance.new("UIGradient")
    gradient.Name = "ShimmerGradient"
    gradient.Parent = label
    
    -- Setup ColorSequence untuk efek shimmer/berkilau
    local colorKeypoints = {}
    
    local basePattern = {
        {0.00, Color3.fromRGB(255, 140, 0)},
        {0.10, Color3.fromRGB(255, 160, 30)},
        {0.20, Color3.fromRGB(255, 200, 100)},
        {0.30, Color3.fromRGB(255, 255, 255)},
        {0.40, Color3.fromRGB(255, 200, 100)},
        {0.50, Color3.fromRGB(255, 160, 30)},
        {0.60, Color3.fromRGB(255, 140, 0)},
        {0.70, Color3.fromRGB(255, 160, 30)},
        {0.80, Color3.fromRGB(255, 200, 100)},
        {0.90, Color3.fromRGB(255, 255, 255)},
        {1.00, Color3.fromRGB(255, 140, 0)},
    }
    
    for _, data in ipairs(basePattern) do
        table.insert(colorKeypoints, ColorSequenceKeypoint.new(data[1], data[2]))
    end
    
    gradient.Color = ColorSequence.new(colorKeypoints)
    
    -- Mulai animasi shimmer dari kiri ke kanan
    local threadId = tostring(label)
    ActiveGradientThreads[threadId] = true
    
    -- ⭐ MEMORY LEAK FIX: Gunakan task.spawn dan task.wait
    task.spawn(function()
        local offset = 0
        while label and label.Parent and ActiveGradientThreads[threadId] and HideStatsEnabled do
            offset = offset + 0.015
            if offset >= 1 then
                offset = 0
            end
            
            gradient.Offset = Vector2.new(offset, 0)
            task.wait(0.02)
        end
    end)
    
    return gradient
end

-- Fungsi untuk membuat clone TextLabel untuk script name
local function createScriptNameLabel(nameLabel, billboard)
    if not nameLabel or not billboard then return end
    
    local existingFrame = billboard:FindFirstChild("LynxFrame")
    if existingFrame then 
        return existingFrame
    end
    
    local nameFrame = nameLabel.Parent
    if not nameFrame or not nameFrame:IsA("Frame") then return end
    
    local originalNamePos = nameFrame.Position
    nameFrame.Position = UDim2.new(
        originalNamePos.X.Scale,
        originalNamePos.X.Offset,
        originalNamePos.Y.Scale + 0.25,
        originalNamePos.Y.Offset
    )
    
    local lynxFrame = Instance.new("Frame")
    lynxFrame.Name = "LynxFrame"
    lynxFrame.Size = nameFrame.Size
    lynxFrame.Position = originalNamePos
    lynxFrame.BackgroundTransparency = 1
    lynxFrame.Parent = billboard
    
    local scriptLabel = nameLabel:Clone()
    scriptLabel.Name = "LynxLabel"
    scriptLabel.Text = ScriptName
    scriptLabel.TextScaled = true
    scriptLabel.Font = Enum.Font.GothamBold
    scriptLabel.TextStrokeTransparency = 0.5
    scriptLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    scriptLabel.Parent = lynxFrame
    
    createMovingGradient(scriptLabel)
    
    return lynxFrame
end

-- Fungsi untuk menghapus semua script name labels
local function removeAllScriptNames()
    local character = LocalPlayer.Character
    if not character then return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local overhead = hrp:FindFirstChild("Overhead")
    if not overhead then return end
    
    local lynxFrame = overhead:FindFirstChild("LynxFrame")
    if lynxFrame then
        for threadId, _ in pairs(ActiveGradientThreads) do
            ActiveGradientThreads[threadId] = nil
        end
        
        local nameLabel = overhead:FindFirstChild("Header", true)
        if nameLabel then
            local nameFrame = nameLabel.Parent
            if nameFrame and nameFrame:IsA("Frame") then
                local currentPos = nameFrame.Position
                nameFrame.Position = UDim2.new(
                    currentPos.X.Scale,
                    currentPos.X.Offset,
                    currentPos.Y.Scale - 0.25,
                    currentPos.Y.Offset
                )
            end
        end
        
        lynxFrame:Destroy()
    end
end

-- Fungsi untuk mengubah nama dan level di overhead display
local function updateStats()
    if not HideStatsEnabled then 
        removeAllScriptNames()
        return 
    end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local overhead = hrp:FindFirstChild("Overhead")
    if not overhead or not overhead:IsA("BillboardGui") then return end
    
    for _, obj in pairs(overhead:GetDescendants()) do
        if obj:IsA("TextLabel") then
            local fullPath = obj:GetFullName()
            
            if not OriginalTexts[fullPath] then
                OriginalTexts[fullPath] = obj.Text
            end
            
            local originalText = OriginalTexts[fullPath]
            
            if originalText and originalText ~= "" then
                if obj.Name == "Header" then
                    if not overhead:FindFirstChild("LynxFrame") then
                        createScriptNameLabel(obj, overhead)
                    end
                    obj.Text = FakeName
                elseif string.find(string.lower(originalText), "lvl") then
                    obj.Text = string.gsub(originalText, "%d+", FakeLevel)
                end
            end
        end
    end
end

-- Auto-update loop
-- ⭐ MEMORY LEAK FIX: Track update loop thread
local updateLoop = false
local updateLoopThread = nil

local function startUpdateLoop()
    if updateLoop then return end
    updateLoop = true
    
    -- ⭐ MEMORY LEAK FIX: Cancel existing thread if any
    if updateLoopThread then
        task.cancel(updateLoopThread)
        updateLoopThread = nil
    end
    
    updateLoopThread = task.spawn(function()
        while updateLoop and HideStatsEnabled do
            updateStats()
            task.wait(0.2)
        end
    end)
end

-- PUBLIC FUNCTIONS
function HideStatsModule.Enable()
    HideStatsEnabled = true
    startUpdateLoop()
    updateStats()
end

function HideStatsModule.Disable()
    HideStatsEnabled = false
    
    -- ⭐ MEMORY LEAK FIX: Stop update loop
    updateLoop = false
    if updateLoopThread then
        task.cancel(updateLoopThread)
        updateLoopThread = nil
    end
    
    -- ⭐ MEMORY LEAK FIX: Stop all gradient threads
    for threadId, _ in pairs(ActiveGradientThreads) do
        ActiveGradientThreads[threadId] = nil
    end
    
    -- Restore original texts
    for path, originalText in pairs(OriginalTexts) do
        local obj = game
        for part in string.gmatch(path, "[^.]+") do
            obj = obj:FindFirstChild(part)
            if not obj then break end
        end
        if obj and obj:IsA("TextLabel") then
            obj.Text = originalText
        end
    end
    
    removeAllScriptNames()
end

function HideStatsModule.SetFakeName(name)
    FakeName = name or "Guest"
    if HideStatsEnabled then
        updateStats()
    end
end

function HideStatsModule.SetFakeLevel(level)
    FakeLevel = tostring(level or "1")
    if HideStatsEnabled then
        updateStats()
    end
end

function HideStatsModule.IsEnabled()
    return HideStatsEnabled
end

function HideStatsModule.GetSettings()
    return {
        enabled = HideStatsEnabled,
        fakeName = FakeName,
        fakeLevel = FakeLevel
    }
end

-- Character respawn handler
-- ⭐ MEMORY LEAK FIX: Gunakan task.wait
LocalPlayer.CharacterAdded:Connect(function(character)
    OriginalTexts = {}
    
    -- ⭐ MEMORY LEAK FIX: Clear gradient threads properly
    for threadId, _ in pairs(ActiveGradientThreads) do
        ActiveGradientThreads[threadId] = nil
    end
    
    task.wait(1)
    if HideStatsEnabled then
        updateStats()
    end
end)

-- Monitor untuk GUI baru
if LocalPlayer.Character then
    LocalPlayer.Character.DescendantAdded:Connect(function(descendant)
        if HideStatsEnabled and descendant:IsA("BillboardGui") then
            wait(0.1)
            updateStats()
        end
    end)
end

-- Initial setup
if LocalPlayer.Character then
    wait(1)
    if HideStatsEnabled then
        updateStats()
    end
end

return HideStatsModule
end)()

-- Module MovementModule
CombinedModules.MovementModule = (function()
local MovementModule = {}

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Variables
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- Settings
MovementModule.Settings = {
    SprintSpeed = 50,
    DefaultSpeed = 16,
    SprintEnabled = false,
    InfiniteJumpEnabled = false
}

-- Internal State
local connections = {}
local jumpConnection = nil
local sprintConnection = nil

local function cleanup()
    for _, conn in pairs(connections) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end
    connections = {}
    
    if jumpConnection then
        jumpConnection:Disconnect()
        jumpConnection = nil
    end
    
    if sprintConnection then
        sprintConnection:Disconnect()
        sprintConnection = nil
    end
end

local function maintainSprintSpeed()
    if sprintConnection then
        sprintConnection:Disconnect()
    end
    
    -- Loop yang terus memantau dan mempertahankan sprint speed
    sprintConnection = RunService.Heartbeat:Connect(function()
        if MovementModule.Settings.SprintEnabled and humanoid and humanoid.WalkSpeed ~= MovementModule.Settings.SprintSpeed then
            humanoid.WalkSpeed = MovementModule.Settings.SprintSpeed
        end
    end)
end

function MovementModule.SetSprintSpeed(speed)
    MovementModule.Settings.SprintSpeed = math.clamp(speed, 16, 200)
    
    if MovementModule.Settings.SprintEnabled and humanoid then
        humanoid.WalkSpeed = MovementModule.Settings.SprintSpeed
    end
end

function MovementModule.EnableSprint()
    if MovementModule.Settings.SprintEnabled then return false end
    
    MovementModule.Settings.SprintEnabled = true
    
    if humanoid then
        humanoid.WalkSpeed = MovementModule.Settings.SprintSpeed
    end
    
    -- Aktifkan loop pemantau sprint speed
    maintainSprintSpeed()
    
    return true
end

function MovementModule.DisableSprint()
    if not MovementModule.Settings.SprintEnabled then return false end
    
    MovementModule.Settings.SprintEnabled = false
    
    -- Matikan loop pemantau
    if sprintConnection then
        sprintConnection:Disconnect()
        sprintConnection = nil
    end
    
    if humanoid then
        humanoid.WalkSpeed = MovementModule.Settings.DefaultSpeed
    end
    
    return true
end

function MovementModule.IsSprintEnabled()
    return MovementModule.Settings.SprintEnabled
end

function MovementModule.GetSprintSpeed()
    return MovementModule.Settings.SprintSpeed
end

local function enableInfiniteJump()
    if jumpConnection then
        jumpConnection:Disconnect()
    end
    
    jumpConnection = UserInputService.JumpRequest:Connect(function()
        if MovementModule.Settings.InfiniteJumpEnabled and humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
end

function MovementModule.EnableInfiniteJump()
    if MovementModule.Settings.InfiniteJumpEnabled then return false end
    
    MovementModule.Settings.InfiniteJumpEnabled = true
    enableInfiniteJump()
    
    return true
end

function MovementModule.DisableInfiniteJump()
    if not MovementModule.Settings.InfiniteJumpEnabled then return false end
    
    MovementModule.Settings.InfiniteJumpEnabled = false
    
    if jumpConnection then
        jumpConnection:Disconnect()
        jumpConnection = nil
    end
    
    return true
end

function MovementModule.IsInfiniteJumpEnabled()
    return MovementModule.Settings.InfiniteJumpEnabled
end

table.insert(connections, player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = character:WaitForChild("Humanoid")
    
    -- Re-apply sprint if enabled
    if MovementModule.Settings.SprintEnabled then
        task.wait(0.1)
        humanoid.WalkSpeed = MovementModule.Settings.SprintSpeed
        maintainSprintSpeed() -- Aktifkan kembali loop pemantau
    end
    
    -- Re-apply infinite jump if enabled
    if MovementModule.Settings.InfiniteJumpEnabled then
        enableInfiniteJump()
    end
end))

function MovementModule.Start()
    MovementModule.Settings.SprintEnabled = false
    MovementModule.Settings.InfiniteJumpEnabled = false
    enableInfiniteJump()
    return true
end

function MovementModule.Stop()
    MovementModule.DisableSprint()
    MovementModule.DisableInfiniteJump()
    cleanup()
    return true
end

-- Initialize
MovementModule.Start()

return MovementModule
end)()

-- Module PingPanel
CombinedModules.PingPanel = (function()
-- Lynx Panel - Ping Monitor (Clean & Smooth)fef
-- Module yang bisa dipanggil dengan PingMonitor:Show() dan :Hide()

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local PingMonitor = {}
PingMonitor.__index = PingMonitor

local player = Players.LocalPlayer
local pingUpdateConnection
local gui = {}
local isVisible = false

-- Fungsi untuk membuat GUI
local function createMonitorGUI()
    -- Main ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LynxPanelMonitor"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    screenGui.DisplayOrder = 999999
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = CoreGui
    
    -- Container Frame
    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(0, 180, 0, 70)
    container.Position = UDim2.new(0.5, -90, 0, 50)
    container.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    container.BackgroundTransparency = 0.3
    container.BorderSizePixel = 0
    container.Visible = false
    container.Parent = screenGui
    
    local containerCorner = Instance.new("UICorner")
    containerCorner.CornerRadius = UDim.new(0, 10)
    containerCorner.Parent = container
    
    -- Header
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 35)
    header.BackgroundTransparency = 1
    header.Parent = container
    
    -- Logo Icon
    local logoIcon = Instance.new("ImageLabel")
    logoIcon.Name = "LogoIcon"
    logoIcon.Size = UDim2.new(0, 24, 0, 24)
    logoIcon.Position = UDim2.new(0, 8, 0, 5)
    logoIcon.BackgroundTransparency = 1
    logoIcon.Image = "rbxassetid://118176705805619"
    logoIcon.ImageTransparency = 0
    logoIcon.ScaleType = Enum.ScaleType.Fit
    logoIcon.Parent = header
    
    local logoCorner = Instance.new("UICorner")
    logoCorner.CornerRadius = UDim.new(0, 6)
    logoCorner.Parent = logoIcon
    
    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, -40, 1, 0)
    titleLabel.Position = UDim2.new(0, 36, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "LYNX PANEL"
    titleLabel.TextColor3 = Color3.fromRGB(255, 140, 50)
    titleLabel.TextTransparency = 0
    titleLabel.TextSize = 13
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = header
    
    -- Separator
    local separator = Instance.new("Frame")
    separator.Name = "Separator"
    separator.Size = UDim2.new(1, -16, 0, 1)
    separator.Position = UDim2.new(0, 8, 0, 35)
    separator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    separator.BackgroundTransparency = 0.7
    separator.BorderSizePixel = 0
    separator.Parent = container
    
    -- Content
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -16, 1, -42)
    content.Position = UDim2.new(0, 8, 0, 40)
    content.BackgroundTransparency = 1
    content.Parent = container
    
    -- Ping Display
    local pingLabel = Instance.new("TextLabel")
    pingLabel.Name = "PingLabel"
    pingLabel.Size = UDim2.new(1, 0, 1, 0)
    pingLabel.Position = UDim2.new(0, 0, 0, 0)
    pingLabel.BackgroundTransparency = 1
    pingLabel.Text = "Ping: 0 ms"
    pingLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    pingLabel.TextTransparency = 0
    pingLabel.TextSize = 15
    pingLabel.Font = Enum.Font.SourceSansBold
    pingLabel.TextXAlignment = Enum.TextXAlignment.Center
    pingLabel.Parent = content
    
    -- Make draggable with smooth movement
    local dragging = false
    local dragInput, dragStart, startPos
    
    container.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = container.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    container.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            container.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    return {
        ScreenGui = screenGui,
        Container = container,
        PingLabel = pingLabel,
        LogoIcon = logoIcon
    }
end

-- Get Ping
local function getPing()
    local ping = 0
    pcall(function()
        local networkStats = Stats:FindFirstChild("Network")
        if networkStats then
            local serverStatsItem = networkStats:FindFirstChild("ServerStatsItem")
            if serverStatsItem then
                local pingStr = serverStatsItem["Data Ping"]:GetValueString()
                ping = tonumber(pingStr:match("%d+")) or 0
            end
        end
        
        if ping == 0 then
            ping = math.floor(player:GetNetworkPing() * 1000)
        end
    end)
    return ping
end

-- Update colors with smooth transition
local function updatePingColor(pingLabel, value)
    local ping = tonumber(value)
    local targetColor
    
    if ping <= 50 then
        targetColor = Color3.fromRGB(100, 255, 150)
    elseif ping <= 100 then
        targetColor = Color3.fromRGB(255, 220, 100)
    elseif ping <= 150 then
        targetColor = Color3.fromRGB(255, 170, 100)
    else
        targetColor = Color3.fromRGB(255, 100, 100)
    end
    
    -- Smooth color transition
    TweenService:Create(
        pingLabel,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {TextColor3 = targetColor}
    ):Play()
end

-- Initialize GUI
local function initializeGUI()
    local existing = CoreGui:FindFirstChild("LynxPanelMonitor")
    if existing then
        existing:Destroy()
        task.wait(0.1)
    end
    
    gui = createMonitorGUI()
end

-- Show function
function PingMonitor:Show()
    if not gui or not gui.ScreenGui then
        initializeGUI()
    end
    
    if gui and gui.Container then
        gui.Container.Visible = true
        isVisible = true
        
        -- Smooth fade in
        gui.Container.BackgroundTransparency = 1
        TweenService:Create(
            gui.Container,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 0.3}
        ):Play()
        
        -- Start ping update loop
        local lastPingUpdate = 0
        pingUpdateConnection = RunService.Heartbeat:Connect(function()
            if not gui or not gui.ScreenGui or not gui.ScreenGui.Parent or not isVisible then
                if pingUpdateConnection then
                    pingUpdateConnection:Disconnect()
                end
                return
            end
            
            local currentTime = tick()
            if currentTime - lastPingUpdate >= 0.5 then
                local ping = getPing()
                gui.PingLabel.Text = "Ping: " .. ping .. " ms"
                updatePingColor(gui.PingLabel, ping)
                lastPingUpdate = currentTime
            end
        end)
        
        print("✅ Lynx Monitor aktif!")
    end
end

-- Hide function
function PingMonitor:Hide()
    if gui and gui.Container then
        -- Smooth fade out
        TweenService:Create(
            gui.Container,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {BackgroundTransparency = 1}
        ):Play()
        
        task.wait(0.3)
        gui.Container.Visible = false
        isVisible = false
        
        -- Disconnect update loop
        if pingUpdateConnection then
            pingUpdateConnection:Disconnect()
            pingUpdateConnection = nil
        end
        
        print("✅ Lynx Monitor disembunyikan!")
    end
end

-- Cleanup function
function PingMonitor:Destroy()
    if pingUpdateConnection then
        pingUpdateConnection:Disconnect()
    end
    if gui and gui.ScreenGui then
        gui.ScreenGui:Destroy()
    end
    gui = {}
end

return PingMonitor
end)()

-- Module Webhook
CombinedModules.Webhook = (function()
local WebhookModule = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local function getHTTPRequest()
    -- Coba berbagai metode request berdasarkan executor
    local requestFunctions = {
        -- Metode standar
        request,
        http_request,
        -- Syn/Synapse
        (syn and syn.request),
        -- Fluxus
        (fluxus and fluxus.request),
        -- Script-Ware
        (http and http.request),
        -- Solara (khusus)
        (solara and solara.request),
        -- Fallback lainnya
        (game and game.HttpGet and function(opts)
            if opts.Method == "GET" then
                return {Body = game:HttpGet(opts.Url)}
            end
        end)
    }
    
    for _, func in ipairs(requestFunctions) do
        if func and type(func) == "function" then
            return func
        end
    end
    
    return nil
end

local httpRequest = getHTTPRequest()

WebhookModule.Config = {
    WebhookURL = "",
    DiscordUserID = "",
    DebugMode = false,
    EnabledRarities = {},
    UseSimpleMode = false -- Mode sederhana tanpa thumbnail API
}

local Items, Variants

-- Safe module loading
local function loadGameModules()
    local success, err = pcall(function()
        Items = require(ReplicatedStorage:WaitForChild("Items"))
        Variants = require(ReplicatedStorage:WaitForChild("Variants"))
    end)
    
    return success
end

local TIER_NAMES = {
    [1] = "Common",
    [2] = "Uncommon", 
    [3] = "Rare",
    [4] = "Epic",
    [5] = "Legendary",
    [6] = "Mythic",
    [7] = "SECRET"
}

local TIER_COLORS = {
    [1] = 9807270,
    [2] = 3066993,
    [3] = 3447003,
    [4] = 10181046,
    [5] = 15844367,
    [6] = 16711680,
    [7] = 1752220
}

local isRunning = false
local eventConnection = nil

local function getPlayerDisplayName()
    return LocalPlayer.DisplayName or LocalPlayer.Name
end

local function getDiscordImageUrl(assetId)
    if not assetId then return nil end
    
    local thumbnailUrl = string.format(
        "https://thumbnails.roblox.com/v1/assets?assetIds=%s&returnPolicy=PlaceHolder&size=420x420&format=Png&isCircular=false",
        tostring(assetId)
    )
    
    local rbxcdnUrl = string.format(
        "https://tr.rbxcdn.com/180DAY-%s/420/420/Image/Png",
        tostring(assetId)
    )
    
    -- Coba Thumbnail API dulu (jika httpRequest tersedia)
    if httpRequest then
        local success, result = pcall(function()
            local response = httpRequest({
                Url = thumbnailUrl,
                Method = "GET"
            })
            
            if response and response.Body then
                local data = HttpService:JSONDecode(response.Body)
                if data and data.data and data.data[1] and data.data[1].imageUrl then
                    return data.data[1].imageUrl
                end
            end
        end)
        
        if success and result then
            return result
        end
    end
    
    -- Fallback ke rbxcdn
    return rbxcdnUrl
end

local function getFishImageUrl(fish)
    local assetId = nil
    
    if fish.Data.Icon then
        assetId = tostring(fish.Data.Icon):match("%d+")
    elseif fish.Data.ImageId then
        assetId = tostring(fish.Data.ImageId)
    elseif fish.Data.Image then
        assetId = tostring(fish.Data.Image):match("%d+")
    end
    
    if assetId then
        local discordUrl = getDiscordImageUrl(assetId)
        if discordUrl then
            return discordUrl
        end
    end
    
    return "https://i.imgur.com/8yZqFqM.png"
end

local function getFish(itemId)
    if not Items then return nil end
    
    for _, f in pairs(Items) do
        if f.Data and f.Data.Id == itemId then
            return f
        end
    end
end

local function getVariant(id)
    if not id or not Variants then return nil end
    
    local idStr = tostring(id)
    
    for _, v in pairs(Variants) do
        if v.Data then
            if tostring(v.Data.Id) == idStr or tostring(v.Data.Name) == idStr then
                return v
            end
        end
    end
    
    return nil
end

local function send(fish, meta, extra)
    -- Validasi webhook URL
    if not WebhookModule.Config.WebhookURL or WebhookModule.Config.WebhookURL == "" then
        return
    end
    
    -- Validasi HTTP request function
    if not httpRequest then
        return
    end
    
    local tier = TIER_NAMES[fish.Data.Tier] or "Unknown"
    local color = TIER_COLORS[fish.Data.Tier] or 3447003
    
    -- FILTER RARITY
    if WebhookModule.Config.EnabledRarities and #WebhookModule.Config.EnabledRarities > 0 then
        local isEnabled = false
        
        for _, enabledTier in ipairs(WebhookModule.Config.EnabledRarities) do
            if enabledTier == tier then
                isEnabled = true
                break
            end
        end
        
        if not isEnabled then
            return
        end
    end
    
    local mutationText = "None"
    local finalPrice = fish.SellPrice or 0
    local variantId = nil
    
    if extra then
        variantId = extra.Variant or extra.Mutation or extra.VariantId or extra.MutationId
    end
    
    if not variantId and meta then
        variantId = meta.Variant or meta.Mutation or meta.VariantId or meta.MutationId
    end
    
    local isShiny = (meta and meta.Shiny) or (extra and extra.Shiny)
    if isShiny then
        mutationText = "Shiny"
        finalPrice = finalPrice * 2
    end
    
    if variantId then
        local v = getVariant(variantId)
        if v then
            mutationText = v.Data.Name .. " (" .. v.SellMultiplier .. "x)"
            finalPrice = finalPrice * v.SellMultiplier
        else
            mutationText = variantId
        end
    end
    
    local imageUrl = getFishImageUrl(fish)
    local playerDisplayName = getPlayerDisplayName()
    local mention = WebhookModule.Config.DiscordUserID ~= "" and "<@" .. WebhookModule.Config.DiscordUserID .. "> " or ""
    
    local congratsMsg = string.format(
        "%s **%s** You have obtained a new **%s** fish!",
        mention,
        playerDisplayName,
        tier
    )
    
    local fields = {
        {
            name = "Fish Name :",
            value = "> " .. fish.Data.Name,
            inline = false
        },
        {
            name = "Fish Tier :",
            value = "> " .. tier,
            inline = false
        },
        {
            name = "Weight :",
            value = string.format("> %.2f Kg", meta.Weight or 0),
            inline = false
        },
        {
            name = "Mutation :",
            value = "> " .. mutationText,
            inline = false
        },
        {
            name = "Sell Price :",
            value = "> $" .. math.floor(finalPrice),
            inline = false
        }
    }
    
    local payload = {
        embeds = {{
            author = {
                name = "Lynxx Webhook | Fish Caught"
            },
            description = congratsMsg,
            color = color,
            fields = fields,
            image = {
                url = imageUrl
            },
            footer = {
                text = "Lynxx Webhook • " .. os.date("%m/%d/%Y %H:%M"),
                icon_url = "https://i.imgur.com/shnNZuT.png"
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }
    
    pcall(function()
        httpRequest({
            Url = WebhookModule.Config.WebhookURL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(payload)
        })
    end)
end

function WebhookModule:SetWebhookURL(url)
    self.Config.WebhookURL = url
end

function WebhookModule:SetDiscordUserID(id)
    self.Config.DiscordUserID = id
end

function WebhookModule:SetDebugMode(enabled)
    self.Config.DebugMode = enabled
end

function WebhookModule:SetEnabledRarities(rarities)
    self.Config.EnabledRarities = rarities
end

function WebhookModule:SetSimpleMode(enabled)
    self.Config.UseSimpleMode = enabled
end

function WebhookModule:GetTierNames()
    return TIER_NAMES
end

function WebhookModule:Start()
    if isRunning then
        return false
    end
    
    if not self.Config.WebhookURL or self.Config.WebhookURL == "" then
        return false
    end
    
    if not httpRequest then
        return false
    end
    
    -- Load game modules
    if not loadGameModules() then
        return false
    end
    
    local success, Event = pcall(function()
        return ReplicatedStorage.Packages
            ._Index["sleitnick_net@0.2.0"]
            .net["RE/ObtainedNewFishNotification"]
    end)
    
    if not success or not Event then
        return false
    end
    
    eventConnection = Event.OnClientEvent:Connect(function(itemId, metadata, extraData)
        local fish = getFish(itemId)
        if fish then
            task.spawn(function()
                send(fish, metadata, extraData)
            end)
        end
    end)
    
    isRunning = true
    return true
end

function WebhookModule:Stop()
    if not isRunning then
        return false
    end
    
    if eventConnection then
        eventConnection:Disconnect()
        eventConnection = nil
    end
    
    isRunning = false
    return true
end

function WebhookModule:IsRunning()
    return isRunning
end

function WebhookModule:GetConfig()
    return self.Config
end

-- Check if executor supports webhook
function WebhookModule:IsSupported()
    return httpRequest ~= nil
end

return WebhookModule
end)()

-- Module TeleportModule
CombinedModules.TeleportModule = (function()
-- 🌍 TeleportModule.lua
-- Modul fungsi teleport + daftar lokasi

local TeleportModule = {}

TeleportModule.Locations = {
    ["Ancient Jungle"] = Vector3.new(1467.8480224609375, 7.447117328643799, -327.5971984863281),
    ["Ancient Ruin"] = Vector3.new(6045.40234375, -588.600830078125, 4608.9375),
    ["Coral Reefs"] = Vector3.new(-2921.858154296875, 3.249999761581421, 2083.2978515625),
    ["Crater Island"] = Vector3.new(1078.454345703125, 5.0720038414001465, 5099.396484375),
    ["Classic Island"] = Vector3.new(1253.974853515625, 9.999999046325684, 2816.7646484375),
    ["Christmas Island"] = Vector3.new(1130.576904, 23.854950, 1554.231567),
    ["Christmas Cave"] = Vector3.new(535.279724121093750, -580.581359863281250, 8900.060546875000000),
    ["Iron Cavern"] = Vector3.new(-8881.52734375, -581.7500610351562, 156.1653289794922),
    ["The Iron Cafe"] = Vector3.new(-8642.7265625, -547.5001831054688, 159.8160400390625),
    ["Esoteric Depths"] = Vector3.new(3224.075927734375, -1302.85498046875, 1404.9346923828125),
    ["Fisherman Island"] = Vector3.new(92.80695343017578, 9.531265258789062, 2762.082275390625),
    ["Kohana"] = Vector3.new(-643.3051147460938, 16.03544807434082, 622.3605346679688),
    ["Kohana Volcano"] = Vector3.new(-572.0244750976562, 39.4923210144043, 112.49259185791016),
    ["Lost Isle"] = Vector3.new(-3701.1513671875, 5.425841808319092, -1058.9107666015625),
    ["Sysiphus Statue"] = Vector3.new(-3656.56201171875, -134.5314178466797, -964.3167724609375),
    ["Sacred Temple"] = Vector3.new(1476.30810546875, -21.8499755859375, -630.8220825195312),
    ["Treasure Room"] = Vector3.new(-3601.568359375, -266.57373046875, -1578.998779296875),
    ["Tropical Grove"] = Vector3.new(-2104.467041015625, 6.268016815185547, 3718.2548828125),
    ["Underground Cellar"] = Vector3.new(2162.577392578125, -91.1981430053711, -725.591552734375),
    ["Weather Machine"] = Vector3.new(-1513.9249267578125, 6.499999523162842, 1892.10693359375)
}

function TeleportModule.TeleportTo(name)
    local player = game.Players.LocalPlayer
    local char = player.Character or player.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")

    local target = TeleportModule.Locations[name]
    if not target then
        warn("⚠️ Lokasi '" .. tostring(name) .. "' tidak ditemukan!")
        return
    end

    root.CFrame = CFrame.new(target)
    print("✅ Teleported to:", name)
end

return TeleportModule
end)()

-- Module TeleportToPlayer
CombinedModules.TeleportToPlayer = (function()
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local TeleportToPlayer = {}

function TeleportToPlayer.TeleportTo(playerName)
    local target = Players:FindFirstChild(playerName)
    local myChar = localPlayer.Character
    if not target or not target.Character then return end

    local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")

    if targetHRP and myHRP then
        myHRP.CFrame = targetHRP.CFrame + Vector3.new(0, 3, 0)
        print("[Teleport] 🚀 Teleported to player: " .. playerName)
    else
        warn("[Teleport] ❌ Gagal teleport, HRP tidak ditemukan.")
    end
end

return TeleportToPlayer
end)()

-- Module SavedLocation
CombinedModules.SavedLocation = (function()
-- SaveLocation.lua
local SaveLocation = {}

local savedPos = nil

-- RAW Notification (langsung SetCore)
local function Notify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 4
        })
    end)
end

-- Simpan posisi
function SaveLocation.Save()
    local player = game.Players.LocalPlayer
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")

    savedPos = hrp.Position

    Notify("Saved Location", "Lokasi tersimpan!", 4)
end

-- Teleport ke lokasi tersimpan
function SaveLocation.Teleport()
    if not savedPos then
        Notify("Error", "Belum ada lokasi yang disimpan!", 4)
        return false
    end
    
    local player = game.Players.LocalPlayer
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")

    hrp.CFrame = CFrame.new(savedPos)

    Notify("Teleported", "Teleport berhasil!", 4)
    return true
end

-- Reset lokasi tersimpan
function SaveLocation.Reset()
    savedPos = nil
    Notify("Location Reset", "Lokasi tersimpan dihapus!", 4)
end

return SaveLocation
end)()

CombinedModules.EventTeleportDynamic = (function()
    -- EventTeleportDynamic.lua
-- Optimized version: no lag + proper height offset + smart event detection
-- Put this file on your raw hosting and call it from GUI via loadstring or require

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local module = {}

-- =======================
-- Event coordinate database (copy from game's module)
-- =======================
module.Events = {
    ["Shark Hunt"] = {
        Vector3.new(1.64999, -1.3500, 2095.72),
        Vector3.new(1369.94, -1.3500, 930.125),
        Vector3.new(-1585.5, -1.3500, 1242.87),
        Vector3.new(-1896.8, -1.3500, 2634.37),
    },

    ["Worm Hunt"] = {
        Vector3.new(2190.85, -1.3999, 97.5749),
        Vector3.new(-2450.6, -1.3999, 139.731),
        Vector3.new(-267.47, -1.3999, 5188.53),
    },

    ["Megalodon Hunt"] = {
        Vector3.new(-1076.3, -1.3999, 1676.19),
        Vector3.new(-1191.8, -1.3999, 3597.30),
        Vector3.new(412.700, -1.3999, 4134.39),
    },

    ["Ghost Shark Hunt"] = {
        Vector3.new(489.558, -1.3500, 25.4060),
        Vector3.new(-1358.2, -1.3500, 4100.55),
        Vector3.new(627.859, -1.3500, 3798.08),
    },

    ["Treasure Hunt"] = nil, -- no static coords
}

-- =======================
-- Config
-- =======================
module.SearchRadius = 25            -- radius (studs) to consider "spawned object at coord"
module.ScanInterval = 2.0           -- seconds between scans (increased to reduce lag)
module.HeightOffset = 15            -- studs above detected position to teleport (avoid drowning)
module.MaxPartsToCheck = 500        -- limit parts checked per scan (anti-lag)
module.RequireEventSpawned = true   -- only teleport if event object actually detected
module.CacheValidPosition = true    -- use cached position when available
module.CacheDuration = 5            -- seconds to trust cached position
module.TeleportRadius = 50          -- if player within this radius of target, skip teleport (anti-spam)

-- =======================
-- Internal state
-- =======================
local running = false
local currentEventName = nil
local scanCoroutine = nil
local lastValidPosition = nil       -- cache last known good position
local lastValidTime = 0             -- when was last valid position found
local eventDetectedOnce = false     -- track if we ever detected the event spawning
local cachedParts = {}              -- cache workspace parts to reduce GetDescendants calls
local lastCacheUpdate = 0
local cacheUpdateInterval = 5       -- update part cache every 5 seconds

-- ================
-- Utilities
-- ================
local function safeCharacter()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char
end

local function getHRP()
    local char = LocalPlayer.Character
    return char and (char:FindFirstChild("HumanoidRootPart"))
end

-- Update cached parts list (happens infrequently to reduce lag)
local function updatePartCache()
    local now = tick()
    if now - lastCacheUpdate < cacheUpdateInterval then
        return -- use existing cache
    end
    
    lastCacheUpdate = now
    cachedParts = {}
    
    -- Only cache parts that could be event objects (filter out terrain, player characters, etc)
    local count = 0
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("BasePart") and inst.Parent and inst.Parent.Name ~= "Terrain" then
            -- Skip player characters
            local isPlayerPart = false
            local ancestor = inst.Parent
            for i = 1, 3 do -- check up to 3 levels up
                if ancestor and Players:GetPlayerFromCharacter(ancestor) then
                    isPlayerPart = true
                    break
                end
                ancestor = ancestor.Parent
                if not ancestor then break end
            end
            
            if not isPlayerPart then
                table.insert(cachedParts, inst)
                count = count + 1
                if count >= module.MaxPartsToCheck * 2 then
                    break -- limit initial cache size
                end
            end
        end
    end
end

-- Optimized: find parts near position using cached list and spatial optimization
local function findNearbyObject(centerPos, radius)
    local bestPart = nil
    local bestDist = math.huge
    local radiusSq = radius * radius -- use squared distance to avoid sqrt calculations
    
    -- Try fast path first: GetPartBoundsInBox (most efficient)
    if Workspace.GetPartBoundsInBox then
        local ok, parts = pcall(function()
            return Workspace:GetPartBoundsInBox(
                CFrame.new(centerPos), 
                Vector3.new(radius*2, radius*2, radius*2)
            )
        end)
        
        if ok and parts and #parts > 0 then
            for _, p in ipairs(parts) do
                if p and p:IsA("BasePart") then
                    -- Quick squared distance check
                    local offset = p.Position - centerPos
                    local distSq = offset.X*offset.X + offset.Y*offset.Y + offset.Z*offset.Z
                    
                    if distSq <= radiusSq and distSq < bestDist then
                        bestDist = distSq
                        bestPart = p
                    end
                end
            end
            return bestPart
        end
    end
    
    -- Fallback: use cached parts list (much faster than GetDescendants every time)
    updatePartCache()
    
    local checked = 0
    for _, part in ipairs(cachedParts) do
        if part and part.Parent then -- ensure part still exists
            -- Quick squared distance check
            local offset = part.Position - centerPos
            local distSq = offset.X*offset.X + offset.Y*offset.Y + offset.Z*offset.Z
            
            if distSq <= radiusSq and distSq < bestDist then
                bestDist = distSq
                bestPart = part
            end
            
            checked = checked + 1
            if checked >= module.MaxPartsToCheck then
                break -- anti-lag: limit checks per scan
            end
        end
    end
    
    return bestPart
end

-- Smart position resolver with caching
local function resolveActivePosition(eventName)
    local coords = module.Events[eventName]
    if not coords or #coords == 0 then
        return nil, false
    end
    
    -- Use cached position if still valid (reduces scanning frequency)
    if module.CacheValidPosition and lastValidPosition then
        local age = tick() - lastValidTime
        if age < module.CacheDuration then
            return lastValidPosition, true -- use cached position
        end
    end
    
    -- Scan for event spawn (optimized)
    for _, coord in ipairs(coords) do
        local part = findNearbyObject(coord, module.SearchRadius)
        if part then
            -- EVENT DETECTED! Apply height offset and cache
            local safePos = part.Position + Vector3.new(0, module.HeightOffset, 0)
            lastValidPosition = safePos
            lastValidTime = tick()
            return safePos, true
        end
    end
    
    -- No event detected
    if module.RequireEventSpawned then
        -- Clear cache if event despawned
        if lastValidPosition then
            lastValidPosition = nil
            lastValidTime = 0
        end
        return nil, false
    else
        -- Fallback mode: return closest coord with height offset
        local hrp = getHRP()
        if hrp then
            local best = nil
            local minDistSq = math.huge
            for _, coord in ipairs(coords) do
                local offset = hrp.Position - coord
                local distSq = offset.X*offset.X + offset.Y*offset.Y + offset.Z*offset.Z
                if distSq < minDistSq then
                    minDistSq = distSq
                    best = coord
                end
            end
            if best then
                return best + Vector3.new(0, module.HeightOffset, 0), false
            end
        end
        return coords[1] + Vector3.new(0, module.HeightOffset, 0), false
    end
end

-- Optimized teleport (single operation) with radius check
local function doTeleportToPos(pos)
    if not pos then return false end
    
    local char = LocalPlayer.Character
    if not char then return false end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    -- Check if player is already near target position (anti-spam teleport)
    local currentPos = hrp.Position
    local offset = currentPos - pos
    local distanceSq = offset.X*offset.X + offset.Y*offset.Y + offset.Z*offset.Z
    local radiusSq = module.TeleportRadius * module.TeleportRadius
    
    if distanceSq <= radiusSq then
        return false -- already near target, skip teleport
    end
    
    -- Single teleport operation (most reliable)
    local success = pcall(function()
        hrp.CFrame = CFrame.new(pos)
    end)
    
    return success
end

-- Exposed simple call: teleport once now to eventName
function module.TeleportNow(eventName)
    if not eventName then return false end
    
    local ok, pos, isSpawned = pcall(function()
        return resolveActivePosition(eventName)
    end)
    
    if not ok or not pos then
        return false
    end
    
    if module.RequireEventSpawned and not isSpawned then
        return false
    end
    
    return doTeleportToPos(pos)
end

-- Start auto-teleport loop (optimized, non-blocking)
function module.Start(eventName)
    if running then return false end
    if not eventName or not module.Events[eventName] then return false end
    
    running = true
    currentEventName = eventName
    eventDetectedOnce = false
    lastValidPosition = nil
    lastValidTime = 0
    
    -- Non-blocking coroutine loop
    scanCoroutine = task.spawn(function()
        while running do
            -- Wrap in pcall to prevent errors from breaking loop
            local ok, pos, isSpawned = pcall(function()
                return resolveActivePosition(currentEventName)
            end)
            
            if ok and pos then
                if module.RequireEventSpawned then
                    if isSpawned then
                        if not eventDetectedOnce then
                            eventDetectedOnce = true
                        end
                        doTeleportToPos(pos)
                    end
                else
                    doTeleportToPos(pos)
                end
            end
            
            -- Wait before next scan (reduces CPU usage significantly)
            task.wait(module.ScanInterval)
        end
    end)
    
    return true
end

function module.Stop()
    running = false
    currentEventName = nil
    eventDetectedOnce = false
    lastValidPosition = nil
    lastValidTime = 0
    cachedParts = {}
    
    if scanCoroutine then
        task.cancel(scanCoroutine)
        scanCoroutine = nil
    end
    
    return true
end

-- Utility: get event list (names)
function module.GetEventNames()
    local list = {}
    for name, _ in pairs(module.Events) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

-- Utility: returns whether event has static coords
function module.HasCoords(eventName)
    local v = module.Events[eventName]
    return v ~= nil and #v > 0
end

-- Utility: check if event is currently spawned (cached result)
function module.IsEventActive(eventName)
    if not eventName then return false end
    
    -- Quick check using cache
    if lastValidPosition and currentEventName == eventName then
        local age = tick() - lastValidTime
        if age < module.CacheDuration then
            return true
        end
    end
    
    -- Full check if needed
    local ok, pos, isSpawned = pcall(function()
        return resolveActivePosition(eventName)
    end)
    
    return ok and isSpawned or false
end

-- Utility: get performance stats
function module.GetStats()
    return {
        running = running,
        eventName = currentEventName,
        eventDetected = eventDetectedOnce,
        cachedParts = #cachedParts,
        hasCachedPosition = lastValidPosition ~= nil,
        cacheAge = lastValidPosition and (tick() - lastValidTime) or 0
    }
end

return module
end)()

-- Module AutoBuyWeather
CombinedModules.AutoBuyWeather = (function()
-- AutoBuyWeather.lua (MODULE VERSION)

local AutoBuyWeather = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetPackage = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"]
local RFPurchaseWeatherEvent = NetPackage.net["RF/PurchaseWeatherEvent"]

-- STATE
local isRunning = false
local selected = {}

AutoBuyWeather.AllWeathers = {
    "Cloudy",
    "Storm",
    "Wind",
    "Snow",
    "Radiant",
    "Shark Hunt"
}

-- Set cuaca terpilih
function AutoBuyWeather.SetSelected(list)
    selected = list
end

-- Start auto maintain
function AutoBuyWeather.Start()
    if isRunning then return end
    isRunning = true

    task.spawn(function()
        while isRunning do
            for _, weather in ipairs(selected) do
                if not isRunning then break end
                pcall(function()
                    RFPurchaseWeatherEvent:InvokeServer(weather)
                end)
                task.wait(2)
            end
            task.wait(15)
        end
    end)
end

-- Stop auto maintain
function AutoBuyWeather.Stop()
    isRunning = false
end

-- Getter untuk GUI status
function AutoBuyWeather.GetStatus()
    return {
        Running = isRunning,
        Selected = selected
    }
end

return AutoBuyWeather
end)()

-- Module AutoSell
CombinedModules.AutoSell = (function()
-- FungsiKeaby/ShopFeatures/AutoSell.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AutoSell = {}

local function findSellRemotes()
	local sellRemotes = {}
	local keywords = { "sell", "vendor", "trade", "shop", "merchant", "salvage", "exchange", "deposit", "convert" }

	for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
		if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
			local name = string.lower(obj.Name)
			for _, key in ipairs(keywords) do
				if string.find(name, key) then
					table.insert(sellRemotes, obj)
					if string.find(name, "sellall") then
						print("🎯 Found SellAll Remote:", obj:GetFullName())
						return obj
					end
				end
			end
		end
	end
	return sellRemotes[1]
end

function AutoSell.SellOnce()
	print("💸 Attempting to sell all fish...")

	local remote = findSellRemotes()
	if not remote then
		warn("❌ Sell remote not found!")
		return
	end

	pcall(function()
		if remote:IsA("RemoteEvent") then
			remote:FireServer("all")
			print("✅ Sold via RemoteEvent:", remote.Name)
		elseif remote:IsA("RemoteFunction") then
			remote:InvokeServer("all")
			print("✅ Sold via RemoteFunction:", remote.Name)
		else
			warn("⚠️ Invalid remote type for selling")
		end
	end)
end

_G.AutoSell = AutoSell
return AutoSell
end)()

-- Module AutoSellSystem
CombinedModules.AutoSellSystem = (function()
-- AutoSellSystem.lua
-- COMBINED: Sell All, Auto Sell Timer, Auto Sell By Count
-- Clean module version - no GUI, no logs

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- ===== FIND SELL REMOTE =====
local function findSellRemote()
	local packages = ReplicatedStorage:FindFirstChild("Packages")
	if not packages then return nil end
	
	local index = packages:FindFirstChild("_Index")
	if not index then return nil end
	
	local sleitnick = index:FindFirstChild("sleitnick_net@0.2.0")
	if not sleitnick then return nil end
	
	local net = sleitnick:FindFirstChild("net")
	if not net then return nil end
	
	local sellRemote = net:FindFirstChild("RF/SellAllItems")
	if sellRemote then return sellRemote end
	
	local rf = net:FindFirstChild("RF")
	if rf then
		sellRemote = rf:FindFirstChild("SellAllItems")
		if sellRemote then return sellRemote end
	end
	
	for _, child in ipairs(net:GetDescendants()) do
		if child.Name == "SellAllItems" or child.Name == "RF/SellAllItems" then
			return child
		end
	end
	
	return nil
end

local SellRemote = findSellRemote()

-- ===== BAG PARSER (for Auto Sell By Count) =====
local function parseNumber(text)
	if not text or text == "" then return 0 end
	local cleaned = tostring(text):gsub("%D", "")
	if cleaned == "" then return 0 end
	return tonumber(cleaned) or 0
end

local function getBagCount()
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then return 0, 0 end

	local inv = gui:FindFirstChild("Inventory")
	if not inv then return 0, 0 end

	local label = inv:FindFirstChild("Main")
		and inv.Main:FindFirstChild("Top")
		and inv.Main.Top:FindFirstChild("Options")
		and inv.Main.Top.Options:FindFirstChild("Fish")
		and inv.Main.Top.Options.Fish:FindFirstChild("Label")
		and inv.Main.Top.Options.Fish.Label:FindFirstChild("BagSize")

	if not label or not label:IsA("TextLabel") then return 0, 0 end

	local curText, maxText = label.Text:match("(.+)%/(.+)")
	if not curText or not maxText then return 0, 0 end

	return parseNumber(curText), parseNumber(maxText)
end

-- ===== MAIN MODULE =====
local AutoSellSystem = {
	Remote = SellRemote,
	
	-- Sell All Stats
	_totalSells = 0,
	_lastSellTime = 0,
	
	-- Timer Mode
	Timer = {
		Enabled = false,
		Interval = 5,
		Thread = nil,
		_sellCount = 0
	},
	
	-- Count Mode
	Count = {
		Enabled = false,
		Target = 235,
		CheckDelay = 1.5,
		_lastSell = 0,
		_thread = nil
	}
}

-- ===== CORE SELL FUNCTION =====
local function executeSell()
	if not SellRemote then return false end
	
	local success, result = pcall(function()
		return SellRemote:InvokeServer()
	end)
	
	if success then
		AutoSellSystem._totalSells = AutoSellSystem._totalSells + 1
		AutoSellSystem._lastSellTime = tick()
		return true
	end
	
	return false
end

-- ===== SELL ALL (MANUAL) =====
function AutoSellSystem.SellOnce()
	if not SellRemote then return false end
	if tick() - AutoSellSystem._lastSellTime < 0.5 then return false end
	return executeSell()
end

-- ===== TIMER MODE =====
function AutoSellSystem.Timer.Start(interval)
	if AutoSellSystem.Timer.Enabled then return false end
	if not SellRemote then return false end
	
	if interval and tonumber(interval) and tonumber(interval) >= 1 then
		AutoSellSystem.Timer.Interval = tonumber(interval)
	end
	
	AutoSellSystem.Timer.Enabled = true
	AutoSellSystem.Timer._sellCount = 0
	
	AutoSellSystem.Timer.Thread = task.spawn(function()
		while AutoSellSystem.Timer.Enabled do
			task.wait(AutoSellSystem.Timer.Interval)
			
			if not AutoSellSystem.Timer.Enabled then break end
			
			if executeSell() then
				AutoSellSystem.Timer._sellCount = AutoSellSystem.Timer._sellCount + 1
			end
		end
	end)
	
	return true
end

function AutoSellSystem.Timer.Stop()
	if not AutoSellSystem.Timer.Enabled then return false end
	AutoSellSystem.Timer.Enabled = false
	return true
end

function AutoSellSystem.Timer.SetInterval(seconds)
	if tonumber(seconds) and seconds >= 1 then
		AutoSellSystem.Timer.Interval = tonumber(seconds)
		return true
	end
	return false
end

function AutoSellSystem.Timer.GetStatus()
	return {
		enabled = AutoSellSystem.Timer.Enabled,
		interval = AutoSellSystem.Timer.Interval,
		sellCount = AutoSellSystem.Timer._sellCount
	}
end

-- ===== COUNT MODE =====
function AutoSellSystem.Count.Start(target)
	if AutoSellSystem.Count.Enabled then return false end
	if not SellRemote then return false end
	
	if target and tonumber(target) and tonumber(target) > 0 then
		AutoSellSystem.Count.Target = tonumber(target)
	end
	
	AutoSellSystem.Count.Enabled = true
	
	AutoSellSystem.Count._thread = task.spawn(function()
		while AutoSellSystem.Count.Enabled do
			task.wait(AutoSellSystem.Count.CheckDelay)
			
			if not AutoSellSystem.Count.Enabled then break end
			
			local current, max = getBagCount()
			
			if AutoSellSystem.Count.Target > 0 and current >= AutoSellSystem.Count.Target then
				if tick() - AutoSellSystem.Count._lastSell < 3 then
					continue
				end
				
				AutoSellSystem.Count._lastSell = tick()
				executeSell()
				task.wait(2)
			end
		end
	end)
	
	return true
end

function AutoSellSystem.Count.Stop()
	if not AutoSellSystem.Count.Enabled then return false end
	AutoSellSystem.Count.Enabled = false
	return true
end

function AutoSellSystem.Count.SetTarget(count)
	if tonumber(count) and tonumber(count) > 0 then
		AutoSellSystem.Count.Target = tonumber(count)
		return true
	end
	return false
end

function AutoSellSystem.Count.GetStatus()
	local cur, max = getBagCount()
	return {
		enabled = AutoSellSystem.Count.Enabled,
		target = AutoSellSystem.Count.Target,
		current = cur,
		max = max
	}
end

-- ===== UTILITY =====
function AutoSellSystem.GetStats()
	return {
		totalSells = AutoSellSystem._totalSells,
		lastSellTime = AutoSellSystem._lastSellTime,
		remoteFound = SellRemote ~= nil,
		timerStatus = AutoSellSystem.Timer.GetStatus(),
		countStatus = AutoSellSystem.Count.GetStatus()
	}
end

function AutoSellSystem.ResetStats()
	AutoSellSystem._totalSells = 0
	AutoSellSystem._lastSellTime = 0
	AutoSellSystem.Timer._sellCount = 0
end

_G.AutoSellSystem = AutoSellSystem
return AutoSellSystem
end)()

-- Module AutoSellTimer
CombinedModules.AutoSellTimer = (function()
-- FungsiKeaby/ShopFeatures/AutoSellTimer.lua
local AutoSellTimer = {
	Enabled = false,
	Interval = 5,
	Thread = nil
}

-- RAW Notification (langsung SetCore)
local function Notify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 4
        })
    end)
end

function AutoSellTimer.Start(interval)
	if AutoSellTimer.Enabled then
		warn("⚠️ AutoSellTimer sudah aktif!")
		return
	end

	if interval and tonumber(interval) and tonumber(interval) >= 1 then
		AutoSellTimer.Interval = tonumber(interval)
	end

	local AutoSell = _G.AutoSell
	if not AutoSell then
		warn("❌ Modul AutoSell belum dimuat!")
		return
	end

	AutoSellTimer.Enabled = true
	print("✅ AutoSellTimer dimulai (" .. AutoSellTimer.Interval .. " detik)")
	Notify("Auto Sell Running", "Auto Sell Berjalan!", 4)

	AutoSellTimer.Thread = task.spawn(function()
		while AutoSellTimer.Enabled do
			task.wait(AutoSellTimer.Interval)
			if AutoSellTimer.Enabled and AutoSell and AutoSell.SellOnce then
				print("💸 Auto selling (interval " .. AutoSellTimer.Interval .. "s)")
				pcall(AutoSell.SellOnce)
			end
		end
	end)
end

function AutoSellTimer.Stop()
	if not AutoSellTimer.Enabled then
		warn("⚠️ AutoSellTimer belum aktif.")
		return
	end

	AutoSellTimer.Enabled = false
	print("🛑 AutoSellTimer dihentikan.")
	Notify("Auto Sell Stopped", "Auto Sell Berhenti!", 4)
end

function AutoSellTimer.SetInterval(seconds)
	if tonumber(seconds) and seconds >= 1 then
		AutoSellTimer.Interval = tonumber(seconds)
		print("⏰ Interval auto sell diatur ke " .. seconds .. " detik.")
	else
		warn("❌ Interval tidak valid, harus >= 1 detik.")
	end
end

function AutoSellTimer.GetStatus()
	print("\n📊 AUTO SELL TIMER STATUS:")
	print("✅ Enabled:", AutoSellTimer.Enabled)
	print("⏰ Interval:", AutoSellTimer.Interval .. " detik")
end

return AutoSellTimer
end)()

-- Module AutoTotem3x
CombinedModules.AutoTotem3X = (function()
    local AutoTotem3X = {}
    
    local Players = game:GetService("Players")
    local RS = game:GetService("ReplicatedStorage")
    local VirtualUser = game:GetService("VirtualUser")
    local LP = Players.LocalPlayer
    
    -- Services
    local Net = RS.Packages["_Index"]["sleitnick_net@0.2.0"].net
    local RE_EquipToolFromHotbar = Net["RE/EquipToolFromHotbar"]
    
    -- Settings
    local HOTBAR_SLOT = 2
    local CLICK_COUNT = 5
    local CLICK_DELAY = 0.2
    local TRIANGLE_RADIUS = 58
    local CENTER_OFFSET = Vector3.new(0, 0, -7.25)
    
    -- State
    local isRunning = false
    local currentTask = nil
    
    -- Teleport Function
    local function tp(pos)
        local char = LP.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = CFrame.new(pos)
            task.wait(0.5)
            return true
        end
        return false
    end
    
    -- Equip Totem
    local function equipTotem()
        local success = pcall(function()
            RE_EquipToolFromHotbar:FireServer(HOTBAR_SLOT)
        end)
        task.wait(1.5)
        return success
    end
    
    -- Auto Click
    local function autoClick()
        for i = 1, CLICK_COUNT do
            if not isRunning then break end
            
            pcall(function()
                VirtualUser:Button1Down(Vector2.new(0, 0))
                task.wait(0.05)
                VirtualUser:Button1Up(Vector2.new(0, 0))
            end)
            task.wait(CLICK_DELAY)
            
            local char = LP.Character
            if char then
                for _, tool in pairs(char:GetChildren()) do
                    if tool:IsA("Tool") then
                        pcall(function()
                            tool:Activate()
                        end)
                    end
                end
            end
            task.wait(CLICK_DELAY)
        end
    end
    
    -- Main Function
    function AutoTotem3X.Start()
        print("[AutoTotem3X] Start() called") -- Debug
        
        if isRunning then
            print("[AutoTotem3X] Already running")
            return false, "Auto Totem sudah berjalan"
        end
        
        -- Check if character exists
        if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then
            print("[AutoTotem3X] Character not found")
            return false, "Character tidak ditemukan"
        end
        
        isRunning = true
        print("[AutoTotem3X] Starting task...")
        
        currentTask = task.spawn(function()
            local success, err = pcall(function()
                local char = LP.Character or LP.CharacterAdded:Wait()
                local root = char:WaitForChild("HumanoidRootPart")
                
                local centerPos = root.Position
                local adjustedCenter = centerPos + CENTER_OFFSET
                
                -- Calculate 3 totem positions (Triangle pattern)
                local angles = {90, 210, 330}
                local totemPositions = {}
                
                for i, angleDeg in ipairs(angles) do
                    local angleRad = math.rad(angleDeg)
                    local offsetX = TRIANGLE_RADIUS * math.cos(angleRad)
                    local offsetZ = TRIANGLE_RADIUS * math.sin(angleRad)
                    table.insert(totemPositions, adjustedCenter + Vector3.new(offsetX, 0, offsetZ))
                end
                
                -- Place totems
                for i, pos in ipairs(totemPositions) do
                    if not isRunning then 
                        print("[AutoTotem3X] Stopped by user")
                        break 
                    end
                    
                    print("[AutoTotem3X] Placing totem " .. i .. " of 3")
                    tp(pos)
                    equipTotem()
                    autoClick()
                    task.wait(2)
                end
                
                -- Return to start position
                if isRunning then
                    print("[AutoTotem3X] Returning to start position")
                    tp(centerPos)
                    task.wait(1)
                end
            end)
            
            if not success then
                warn("[AutoTotem3X] Error: " .. tostring(err))
            end
            
            isRunning = false
            currentTask = nil
            print("[AutoTotem3X] Process completed")
        end)
        
        return true, "Auto Totem 3X dimulai"
    end
    
    function AutoTotem3X.Stop()
        print("[AutoTotem3X] Stop() called") -- Debug
        
        if not isRunning then
            print("[AutoTotem3X] Not running")
            return false, "Auto Totem tidak sedang berjalan"
        end
        
        isRunning = false
        
        if currentTask then
            task.cancel(currentTask)
            currentTask = nil
        end
        
        print("[AutoTotem3X] Stopped successfully")
        return true, "Auto Totem 3X dihentikan"
    end
    
    function AutoTotem3X.IsRunning()
        return isRunning
    end
    
    -- Debug: Print saat module di-load
    print("[AutoTotem3X] Module loaded successfully")
    
    return AutoTotem3X
end)()

-- Module BlatantAutoFishing
CombinedModules.BlatantAutoFishing = (function()
-- BlatantAutoFishing.lua
-- Mode Blatant: Ultra fast fishing based on working Instant2X

local BlatantAutoFishing = {}
BlatantAutoFishing.Enabled = false
BlatantAutoFishing.Settings = {
    FishingDelay = 0.01,      -- Delay setelah catch (blatant: 0.01s)
    CancelDelay = 0.01,       -- Delay cancel (blatant: 0.01s)
    HookDetectionDelay = 0.01, -- Delay deteksi hook (blatant: 0.01s)
    RequestMinigameDelay = 0.01, -- Delay request minigame (blatant: 0.01s)
    TimeoutDelay = 0.5,       -- Timeout fallback (blatant: 0.5s)
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

-- Network events
local netFolder = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index")
    :WaitForChild("sleitnick_net@0.2.0"):WaitForChild("net")

local RF_ChargeFishingRod = netFolder:WaitForChild("RF/ChargeFishingRod")
local RF_RequestMinigame = netFolder:WaitForChild("RF/RequestFishingMinigameStarted")
local RF_CancelFishingInputs = netFolder:WaitForChild("RF/CancelFishingInputs")
local RE_FishingCompleted = netFolder:WaitForChild("RE/FishingCompleted")
local RE_MinigameChanged = netFolder:WaitForChild("RE/FishingMinigameChanged")
local RE_FishCaught = netFolder:WaitForChild("RE/FishCaught")

-- Variables
local WaitingHook = false
local CurrentCycle = 0
local TotalFish = 0
local MinigameConnection = nil
local FishCaughtConnection = nil

local function log(msg)
    print("[Blatant] " .. msg)
end

-- Fungsi Cast
local function Cast()
    if not BlatantAutoFishing.Enabled or WaitingHook then return end
    
    CurrentCycle = CurrentCycle + 1
    
    pcall(function()
        -- 1. Charge fishing rod
        RF_ChargeFishingRod:InvokeServer({[22] = tick()})
        log("🎣 Cast #" .. CurrentCycle)
        
        -- 2. Delay minimal lalu request minigame
        task.wait(BlatantAutoFishing.Settings.RequestMinigameDelay)
        RF_RequestMinigame:InvokeServer(9, 0, tick())
        log("🎯 Minigame requested, waiting hook...")
        
        WaitingHook = true
        
        -- 3. Timeout fallback (jika hook tidak terdeteksi)
        task.delay(BlatantAutoFishing.Settings.TimeoutDelay, function()
            if WaitingHook and BlatantAutoFishing.Enabled then
                WaitingHook = false
                
                -- Force complete
                RE_FishingCompleted:FireServer()
                log("⏱️ Timeout - Force complete")
                
                task.wait(BlatantAutoFishing.Settings.CancelDelay)
                pcall(function() RF_CancelFishingInputs:InvokeServer() end)
                
                task.wait(BlatantAutoFishing.Settings.FishingDelay)
                if BlatantAutoFishing.Enabled then Cast() end
            end
        end)
    end)
end

-- Setup event listeners
local function setupListeners()
    -- Listen untuk MinigameChanged (hook detection)
    if MinigameConnection then MinigameConnection:Disconnect() end
    
    MinigameConnection = RE_MinigameChanged.OnClientEvent:Connect(function(state)
        if not BlatantAutoFishing.Enabled then return end
        if not WaitingHook then return end
        
        -- Deteksi hook state
        if typeof(state) == "string" and string.find(string.lower(state), "hook") then
            WaitingHook = false
            
            -- Delay minimal untuk hook detection
            task.wait(BlatantAutoFishing.Settings.HookDetectionDelay)
            
            -- Complete fishing
            RE_FishingCompleted:FireServer()
            log("✅ Hook detected - Fish caught!")
            
            task.wait(BlatantAutoFishing.Settings.CancelDelay)
            pcall(function() RF_CancelFishingInputs:InvokeServer() end)
            
            task.wait(BlatantAutoFishing.Settings.FishingDelay)
            if BlatantAutoFishing.Enabled then Cast() end
        end
    end)
    
    -- Listen untuk FishCaught
    if FishCaughtConnection then FishCaughtConnection:Disconnect() end
    
    FishCaughtConnection = RE_FishCaught.OnClientEvent:Connect(function(fishName, data)
        if not BlatantAutoFishing.Enabled then return end
        
        WaitingHook = false
        TotalFish = TotalFish + 1
        
        log("🐟 Fish caught: " .. tostring(fishName) .. " | Total: " .. TotalFish)
        
        task.wait(BlatantAutoFishing.Settings.CancelDelay)
        pcall(function() RF_CancelFishingInputs:InvokeServer() end)
        
        task.wait(BlatantAutoFishing.Settings.FishingDelay)
        if BlatantAutoFishing.Enabled then Cast() end
    end)
end

-- Fungsi Start
function BlatantAutoFishing.Start()
    if BlatantAutoFishing.Enabled then
        warn("⚠️ Blatant Mode sudah aktif!")
        return
    end
    
    print("="..string.rep("=", 50))
    print("🔥 BLATANT MODE AKTIF!")
    print("="..string.rep("=", 50))
    print("⚡ Fishing Delay:", BlatantAutoFishing.Settings.FishingDelay, "s")
    print("⚡ Cancel Delay:", BlatantAutoFishing.Settings.CancelDelay, "s")
    print("⚡ Hook Detection Delay:", BlatantAutoFishing.Settings.HookDetectionDelay, "s")
    print("⚡ Request Minigame Delay:", BlatantAutoFishing.Settings.RequestMinigameDelay, "s")
    print("⚡ Timeout Delay:", BlatantAutoFishing.Settings.TimeoutDelay, "s")
    print("="..string.rep("=", 50))
    print("⚠️ WARNING: Ultra fast mode - HIGH BAN RISK!")
    print("="..string.rep("=", 50))
    
    BlatantAutoFishing.Enabled = true
    WaitingHook = false
    CurrentCycle = 0
    TotalFish = 0
    
    -- Setup listeners
    setupListeners()
    log("✅ Event listeners installed")
    
    -- Start fishing
    task.wait(0.5)
    Cast()
    
    log("✅ Blatant fishing started!")
end

-- Fungsi Stop
function BlatantAutoFishing.Stop()
    if not BlatantAutoFishing.Enabled then
        warn("⚠️ Blatant Mode sudah tidak aktif!")
        return
    end
    
    BlatantAutoFishing.Enabled = false
    WaitingHook = false
    
    -- Disconnect listeners
    if MinigameConnection then
        MinigameConnection:Disconnect()
        MinigameConnection = nil
    end
    
    if FishCaughtConnection then
        FishCaughtConnection:Disconnect()
        FishCaughtConnection = nil
    end
    
    -- Cancel current fishing
    pcall(function() RF_CancelFishingInputs:InvokeServer() end)
    
    log("🔴 Blatant Mode stopped | Total fish: " .. TotalFish)
end

-- Handle respawn
Players.LocalPlayer.CharacterAdded:Connect(function()
    if BlatantAutoFishing.Enabled then
        task.wait(2)
        
        log("🔄 Character respawned, restarting...")
        
        WaitingHook = false
        
        -- Reconnect listeners
        if MinigameConnection then MinigameConnection:Disconnect() end
        if FishCaughtConnection then FishCaughtConnection:Disconnect() end
        
        setupListeners()
        
        task.wait(1)
        Cast()
    end
end)

-- Cleanup
Players.PlayerRemoving:Connect(function(player)
    if player == localPlayer then
        if BlatantAutoFishing.Enabled then
            BlatantAutoFishing.Stop()
        end
    end
end)

return BlatantAutoFishing
end)()

-- Module BlatantFixedV1
CombinedModules.BlatantFixedV1 = (function()
-- ⚠️ BLATANT V2 AUTO FISHING - CLEAN VERSION
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Network initialization
local netFolder = ReplicatedStorage
    :WaitForChild("Packages")
    :WaitForChild("_Index")
    :WaitForChild("sleitnick_net@0.2.0")
    :WaitForChild("net")

local RF_ChargeFishingRod = netFolder:WaitForChild("RF/ChargeFishingRod")
local RF_RequestMinigame = netFolder:WaitForChild("RF/RequestFishingMinigameStarted")
local RF_CancelFishingInputs = netFolder:WaitForChild("RF/CancelFishingInputs")
local RF_UpdateAutoFishingState = netFolder:WaitForChild("RF/UpdateAutoFishingState")
local RE_FishingCompleted = netFolder:WaitForChild("RE/FishingCompleted")
local RE_MinigameChanged = netFolder:WaitForChild("RE/FishingMinigameChanged")

-- Module table
local BlatantV2 = {}
BlatantV2.Active = false
BlatantV2.BackupConnection = nil  -- ⭐ MEMORY LEAK FIX

-- Settings
BlatantV2.Settings = {
    ChargeDelay = 0.007,
    CompleteDelay = 0.001,
    CancelDelay = 0.001
}

----------------------------------------------------------------
-- CORE FISHING FUNCTIONS
----------------------------------------------------------------

local function safeFire(func)
    task.spawn(function()
        pcall(func)
    end)
end

local function ultraSpamLoop()
    while BlatantV2.Active do
        local startTime = tick()
        
        safeFire(function()
            RF_ChargeFishingRod:InvokeServer({[1] = startTime})
        end)
        
        task.wait(BlatantV2.Settings.ChargeDelay)
        
        local releaseTime = tick()
        safeFire(function()
            RF_RequestMinigame:InvokeServer(1, 0, releaseTime)
        end)
        
        task.wait(BlatantV2.Settings.CompleteDelay)
        
        safeFire(function()
            RE_FishingCompleted:FireServer()
        end)
        
        task.wait(BlatantV2.Settings.CancelDelay)
        safeFire(function()
            RF_CancelFishingInputs:InvokeServer()
        end)
    end
end

-- ⭐ MEMORY LEAK FIX: Setup backup listener function
local function setupBackupListener()
    if BlatantV2.BackupConnection then
        BlatantV2.BackupConnection:Disconnect()
        BlatantV2.BackupConnection = nil
    end
    
    BlatantV2.BackupConnection = RE_MinigameChanged.OnClientEvent:Connect(function(state)
        if not BlatantV2.Active then return end
        
        task.spawn(function()
            task.wait(BlatantV2.Settings.CompleteDelay)
            
            safeFire(function()
                RE_FishingCompleted:FireServer()
            end)
            
            task.wait(BlatantV2.Settings.CancelDelay)
            safeFire(function()
                RF_CancelFishingInputs:InvokeServer()
            end)
        end)
    end)
end

----------------------------------------------------------------
-- PUBLIC API
----------------------------------------------------------------

-- Update Settings function
function BlatantV2.UpdateSettings(completeDelay, cancelDelay)
    if completeDelay ~= nil then
        BlatantV2.Settings.CompleteDelay = completeDelay
    end
    
    if cancelDelay ~= nil then
        BlatantV2.Settings.CancelDelay = cancelDelay
    end
end

-- Start function
function BlatantV2.Start()
    if BlatantV2.Active then 
        return
    end
    
    BlatantV2.Active = true
    
    -- ⭐ MEMORY LEAK FIX: Setup backup listener
    setupBackupListener()
    
    task.spawn(ultraSpamLoop)
end

-- Stop function
function BlatantV2.Stop()
    if not BlatantV2.Active then 
        return
    end
    
    BlatantV2.Active = false
    
    -- ⭐ MEMORY LEAK FIX: Disconnect backup listener
    if BlatantV2.BackupConnection then
        BlatantV2.BackupConnection:Disconnect()
        BlatantV2.BackupConnection = nil
    end
    
    safeFire(function()
        RF_UpdateAutoFishingState:InvokeServer(true)
    end)
    
    task.wait(0.2)
    
    safeFire(function()
        RF_CancelFishingInputs:InvokeServer()
    end)
end

return BlatantV2
end)()

-- Module BlatantV2
CombinedModules.BlatantV2 = (function()
-- ⚡ ULTRA BLATANT AUTO FISHING MODULE - CLEAN VERSION
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Network initialization
local netFolder = ReplicatedStorage
    :WaitForChild("Packages")
    :WaitForChild("_Index")
    :WaitForChild("sleitnick_net@0.2.0")
    :WaitForChild("net")
    
local RF_ChargeFishingRod = netFolder:WaitForChild("RF/ChargeFishingRod")
local RF_RequestMinigame = netFolder:WaitForChild("RF/RequestFishingMinigameStarted")
local RF_CancelFishingInputs = netFolder:WaitForChild("RF/CancelFishingInputs")
local RF_UpdateAutoFishingState = netFolder:WaitForChild("RF/UpdateAutoFishingState")
local RE_FishingCompleted = netFolder:WaitForChild("RE/FishingCompleted")
local RE_MinigameChanged = netFolder:WaitForChild("RE/FishingMinigameChanged")

-- Module
local UltraBlatant = {}
UltraBlatant.Active = false
UltraBlatant.BackupConnection = nil  -- ⭐ MEMORY LEAK FIX

UltraBlatant.Settings = {
    CompleteDelay = 0.73,
    CancelDelay = 0.3,
    ReCastDelay = 0.001
}

-- State tracking
local FishingState = {
    lastCompleteTime = 0,
    completeCooldown = 0.4
}

----------------------------------------------------------------
-- CORE FUNCTIONS
----------------------------------------------------------------

local function safeFire(func)
    task.spawn(function()
        pcall(func)
    end)
end

local function protectedComplete()
    local now = tick()
    
    if now - FishingState.lastCompleteTime < FishingState.completeCooldown then
        return false
    end
    
    FishingState.lastCompleteTime = now
    safeFire(function()
        RE_FishingCompleted:FireServer()
    end)
    
    return true
end

local function performCast()
    local now = tick()
    
    safeFire(function()
        RF_ChargeFishingRod:InvokeServer({[1] = now})
    end)
    safeFire(function()
        RF_RequestMinigame:InvokeServer(1, 0, now)
    end)
end

local function fishingLoop()
    while UltraBlatant.Active do
        performCast()
        
        task.wait(UltraBlatant.Settings.CompleteDelay)
        
        if UltraBlatant.Active then
            protectedComplete()
        end
        
        task.wait(UltraBlatant.Settings.CancelDelay)
        
        if UltraBlatant.Active then
            safeFire(function()
                RF_CancelFishingInputs:InvokeServer()
            end)
        end
        
        task.wait(UltraBlatant.Settings.ReCastDelay)
    end
end

-- ⭐ MEMORY LEAK FIX: Backup listener vars
local lastEventTime = 0

local function setupBackupListener()
    if UltraBlatant.BackupConnection then
        UltraBlatant.BackupConnection:Disconnect()
        UltraBlatant.BackupConnection = nil
    end
    
    UltraBlatant.BackupConnection = RE_MinigameChanged.OnClientEvent:Connect(function(state)
        if not UltraBlatant.Active then return end
        
        local now = tick()
        
        if now - lastEventTime < 0.2 then
            return
        end
        lastEventTime = now
        
        if now - FishingState.lastCompleteTime < 0.3 then
            return
        end
        
        task.spawn(function()
            task.wait(UltraBlatant.Settings.CompleteDelay)
            
            if protectedComplete() then
                task.wait(UltraBlatant.Settings.CancelDelay)
                safeFire(function()
                    RF_CancelFishingInputs:InvokeServer()
                end)
            end
        end)
    end)
end

----------------------------------------------------------------
-- PUBLIC API
----------------------------------------------------------------

function UltraBlatant.UpdateSettings(completeDelay, cancelDelay, reCastDelay)
    if completeDelay ~= nil then
        UltraBlatant.Settings.CompleteDelay = completeDelay
    end
    
    if cancelDelay ~= nil then
        UltraBlatant.Settings.CancelDelay = cancelDelay
    end
    
    if reCastDelay ~= nil then
        UltraBlatant.Settings.ReCastDelay = reCastDelay
    end
end

function UltraBlatant.Start()
    if UltraBlatant.Active then 
        return
    end
    
    UltraBlatant.Active = true
    FishingState.lastCompleteTime = 0
    
    -- ⭐ MEMORY LEAK FIX: Setup backup listener
    setupBackupListener()
    
    safeFire(function()
        RF_UpdateAutoFishingState:InvokeServer(true)
    end)
    
    task.wait(0.2)
    task.spawn(fishingLoop)
end

function UltraBlatant.Stop()
    if not UltraBlatant.Active then 
        return
    end
    
    UltraBlatant.Active = false
    
    -- ⭐ MEMORY LEAK FIX: Disconnect backup listener
    if UltraBlatant.BackupConnection then
        UltraBlatant.BackupConnection:Disconnect()
        UltraBlatant.BackupConnection = nil
    end
    
    safeFire(function()
        RF_UpdateAutoFishingState:InvokeServer(true)
    end)
    
    task.wait(0.2)
    
    safeFire(function()
        RF_CancelFishingInputs:InvokeServer()
    end)
end

return UltraBlatant
end)()

-- Module DisableCutscenes
CombinedModules.DisableCutscenes = (function()
--=====================================================
-- DisableCutscenes.lua (FINAL MODULE VERSION)
-- Memiliki: Start(), Stop()
--=====================================================

local DisableCutscenes = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Index = Packages:WaitForChild("_Index")
local NetFolder = Index:WaitForChild("sleitnick_net@0.2.0")
local net = NetFolder:WaitForChild("net")

local ReplicateCutscene = net:FindFirstChild("ReplicateCutscene")
local StopCutscene = net:FindFirstChild("StopCutscene")
local BlackoutScreen = net:FindFirstChild("BlackoutScreen")

local running = false
local _connections = {}
local _loopThread = nil

local function connect(event, fn)
    if event then
        local c = event.OnClientEvent:Connect(fn)
        table.insert(_connections, c)
    end
end

-----------------------------------------------------
-- START
-----------------------------------------------------
function DisableCutscenes.Start()
    if running then return end
    running = true

    -- Block ReplicateCutscene
    connect(ReplicateCutscene, function(...)
        if running and StopCutscene then
            StopCutscene:FireServer()
        end
    end)

    -- Block BlackoutScreen
    connect(BlackoutScreen, function(...)
        -- just ignore
    end)

    -- Loop paksa StopCutscene tiap 1 detik
    _loopThread = task.spawn(function()
        while running do
            if StopCutscene then
                StopCutscene:FireServer()
            end
            task.wait(1)
        end
    end)
end

-----------------------------------------------------
-- STOP
-----------------------------------------------------
function DisableCutscenes.Stop()
    if not running then return end
    running = false

    -- Hapus semua koneksi listener
    for _, c in ipairs(_connections) do
        c:Disconnect()
    end

    _connections = {}

    -- Stop loop
    if _loopThread then
        task.cancel(_loopThread)
        _loopThread = nil
    end
end

-----------------------------------------------------
return DisableCutscenes
end)()

-- Module DisableExtras
CombinedModules.DisableExtras = (function()
-- DisableExtras.lua
local module = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local VFXFolder = ReplicatedStorage:WaitForChild("VFX")

local activeSmallNotif = false
local activeSkinEffect = false

-- ⭐ MEMORY LEAK FIX: Track connections
local notifHeartbeatConn = nil
local notifChildAddedConn = nil
local skinHeartbeatConn = nil
local skinChildAddedConn = nil

-- =========================
-- Small Notification
-- =========================
local function disableNotifications()
    if not player or not player:FindFirstChild("PlayerGui") then return end
    local gui = player.PlayerGui
    local existing = gui:FindFirstChild("Small Notification")
    if existing then
        existing:Destroy()
    end
end

-- =========================
-- Skin Effect Dive
-- =========================
local function disableDiveEffects()
    for _, child in pairs(VFXFolder:GetChildren()) do
        if child.Name:match("Dive$") then
            child:Destroy()
        end
    end
end

-- =========================
-- Start / Stop Small Notification
-- =========================
function module.StartSmallNotification()
    if activeSmallNotif then return end
    activeSmallNotif = true

    -- ⭐ MEMORY LEAK FIX: Disconnect existing connections first
    if notifHeartbeatConn then
        notifHeartbeatConn:Disconnect()
        notifHeartbeatConn = nil
    end
    if notifChildAddedConn then
        notifChildAddedConn:Disconnect()
        notifChildAddedConn = nil
    end

    -- Loop setiap frame
    notifHeartbeatConn = RunService.Heartbeat:Connect(function()
        if activeSmallNotif then
            disableNotifications()
        end
    end)

    -- Deteksi GUI baru
    notifChildAddedConn = player.PlayerGui.ChildAdded:Connect(function(child)
        if activeSmallNotif and child.Name == "Small Notification" then
            child:Destroy()
        end
    end)
end

function module.StopSmallNotification()
    activeSmallNotif = false
    
    -- ⭐ MEMORY LEAK FIX: Disconnect connections
    if notifHeartbeatConn then
        notifHeartbeatConn:Disconnect()
        notifHeartbeatConn = nil
    end
    if notifChildAddedConn then
        notifChildAddedConn:Disconnect()
        notifChildAddedConn = nil
    end
end

-- =========================
-- Start / Stop Skin Effect
-- =========================
function module.StartSkinEffect()
    if activeSkinEffect then return end
    activeSkinEffect = true

    -- Hapus efek yang sudah ada
    disableDiveEffects()

    -- ⭐ MEMORY LEAK FIX: Disconnect existing connections first
    if skinHeartbeatConn then
        skinHeartbeatConn:Disconnect()
        skinHeartbeatConn = nil
    end
    if skinChildAddedConn then
        skinChildAddedConn:Disconnect()
        skinChildAddedConn = nil
    end

    -- Loop setiap frame
    skinHeartbeatConn = RunService.Heartbeat:Connect(function()
        if activeSkinEffect then
            disableDiveEffects()
        end
    end)

    -- Pantau child baru di VFX
    skinChildAddedConn = VFXFolder.ChildAdded:Connect(function(child)
        if activeSkinEffect and child.Name:match("Dive$") then
            child:Destroy()
        end
    end)
end

function module.StopSkinEffect()
    activeSkinEffect = false
    
    -- ⭐ MEMORY LEAK FIX: Disconnect connections
    if skinHeartbeatConn then
        skinHeartbeatConn:Disconnect()
        skinHeartbeatConn = nil
    end
    if skinChildAddedConn then
        skinChildAddedConn:Disconnect()
        skinChildAddedConn = nil
    end
end

return module
end)()

-- Module NoFishingAnimation
CombinedModules.NoFishingAnimation = (function()
-- NoFishingAnimation.lua
-- Auto freeze karakter di pose fishing dengan ZERO animasi
-- Ready untuk diintegrasikan ke GUI

local NoFishingAnimation = {}
NoFishingAnimation.Enabled = false
NoFishingAnimation.Connection = nil
NoFishingAnimation.SavedPose = {}
NoFishingAnimation.ReelingTrack = nil
NoFishingAnimation.AnimationBlocker = nil

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer

-- Fungsi untuk find ReelingIdle animation
local function getOrCreateReelingAnimation()
    local success, result = pcall(function()
        local character = localPlayer.Character
        if not character then return nil end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return nil end
        
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then return nil end
        
        -- Cari animasi ReelingIdle yang sudah ada
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            local name = track.Name
            if name:find("Reel") and name:find("Idle") then
                return track
            end
        end
        
        -- Cari di semua loaded animations
        for _, track in pairs(humanoid.Animator:GetPlayingAnimationTracks()) do
            if track.Animation then
                if track.Name:find("Reel") then
                    return track
                end
            end
        end
        
        -- Jika tidak ada, coba cari di character tools
        for _, tool in pairs(character:GetChildren()) do
            if tool:IsA("Tool") then
                for _, anim in pairs(tool:GetDescendants()) do
                    if anim:IsA("Animation") then
                        local name = anim.Name
                        if name:find("Reel") and name:find("Idle") then
                            local track = animator:LoadAnimation(anim)
                            return track
                        end
                    end
                end
            end
        end
        
        return nil
    end)
    
    if success then
        return result
    end
    return nil
end

-- Fungsi untuk capture pose dari Motor6D
local function capturePose()
    NoFishingAnimation.SavedPose = {}
    local count = 0
    
    pcall(function()
        local character = localPlayer.Character
        if not character then return end
        
        -- Simpan SEMUA Motor6D
        for _, descendant in pairs(character:GetDescendants()) do
            if descendant:IsA("Motor6D") then
                NoFishingAnimation.SavedPose[descendant.Name] = {
                    Part = descendant,
                    C0 = descendant.C0,
                    C1 = descendant.C1,
                    Transform = descendant.Transform
                }
                count = count + 1
            end
        end
    end)
    
    return count > 0
end

-- Fungsi untuk STOP SEMUA animasi secara permanent
local function killAllAnimations()
    pcall(function()
        local character = localPlayer.Character
        if not character then return end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return nil end
        
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then return nil end
        
        -- STOP semua playing animations
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            track:Stop(0)
            track:Destroy()
        end
        
        -- STOP semua humanoid animations
        for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
            track:Stop(0)
            track:Destroy()
        end
    end)
end

-- Fungsi untuk BLOCK animasi baru agar tidak play
local function blockNewAnimations()
    if NoFishingAnimation.AnimationBlocker then
        NoFishingAnimation.AnimationBlocker:Disconnect()
    end
    
    pcall(function()
        local character = localPlayer.Character
        if not character then return end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then return nil end
        
        -- Hook semua animasi baru yang mau play
        NoFishingAnimation.AnimationBlocker = animator.AnimationPlayed:Connect(function(animTrack)
            if NoFishingAnimation.Enabled then
                animTrack:Stop(0)
                animTrack:Destroy()
            end
        end)
    end)
end

-- Fungsi untuk freeze pose
local function freezePose()
    if NoFishingAnimation.Connection then
        NoFishingAnimation.Connection:Disconnect()
    end
    
    NoFishingAnimation.Connection = RunService.RenderStepped:Connect(function()
        if not NoFishingAnimation.Enabled then return end
        
        pcall(function()
            local character = localPlayer.Character
            if not character then return end
            
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid then return end
            
            -- FORCE STOP semua animasi setiap frame
            for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
                track:Stop(0)
            end
            
            -- APPLY SAVED POSE setiap frame
            for jointName, poseData in pairs(NoFishingAnimation.SavedPose) do
                local motor = character:FindFirstChild(jointName, true)
                if motor and motor:IsA("Motor6D") then
                    motor.C0 = poseData.C0
                    motor.C1 = poseData.C1
                end
            end
        end)
    end)
end

-- Fungsi Stop
local function stopFreeze()
    if NoFishingAnimation.Connection then
        NoFishingAnimation.Connection:Disconnect()
        NoFishingAnimation.Connection = nil
    end
    
    if NoFishingAnimation.AnimationBlocker then
        NoFishingAnimation.AnimationBlocker:Disconnect()
        NoFishingAnimation.AnimationBlocker = nil
    end
    
    if NoFishingAnimation.ReelingTrack then
        NoFishingAnimation.ReelingTrack:Stop()
        NoFishingAnimation.ReelingTrack = nil
    end
    
    NoFishingAnimation.SavedPose = {}
end

-- ============================================
-- PUBLIC FUNCTIONS (untuk GUI)
-- ============================================

-- Fungsi Start (AUTO - tanpa perlu memancing dulu)
function NoFishingAnimation.Start()
    if NoFishingAnimation.Enabled then
        return false, "Already enabled"
    end
    
    local character = localPlayer.Character
    if not character then 
        return false, "Character not found"
    end
    
    -- 1. Cari atau buat ReelingIdle animation
    local reelingTrack = getOrCreateReelingAnimation()
    
    if reelingTrack then
        -- 2. Play animasi (pause setelah beberapa frame)
        reelingTrack:Play()
        reelingTrack:AdjustSpeed(0) -- Pause animasi di frame pertama
        
        NoFishingAnimation.ReelingTrack = reelingTrack
        
        -- 3. Tunggu animasi apply ke Motor6D
        task.wait(0.2)
        
        -- 4. Capture pose
        local success = capturePose()
        
        if success then
            -- 5. KILL semua animasi
            killAllAnimations()
            
            -- 6. Block animasi baru
            blockNewAnimations()
            
            -- 7. Enable freeze
            NoFishingAnimation.Enabled = true
            freezePose()
            
            return true, "Pose frozen successfully"
        else
            reelingTrack:Stop()
            return false, "Failed to capture pose"
        end
    else
        return false, "Reeling animation not found"
    end
end

-- Fungsi Start dengan delay (RECOMMENDED)
function NoFishingAnimation.StartWithDelay(delay, callback)
    if NoFishingAnimation.Enabled then
        return false, "Already enabled"
    end
    
    delay = delay or 2
    
    -- Jalankan di coroutine agar tidak blocking
    task.spawn(function()
        task.wait(delay)
        
        local success = capturePose()
        
        if success then
            -- KILL semua animasi
            killAllAnimations()
            
            -- Block animasi baru
            blockNewAnimations()
            
            -- Enable freeze
            NoFishingAnimation.Enabled = true
            freezePose()
            
            -- Callback jika ada
            if callback then
                callback(true, "Pose frozen successfully")
            end
        else
            -- Callback error
            if callback then
                callback(false, "Failed to capture pose")
            end
        end
    end)
    
    return true, "Starting with delay..."
end

-- Fungsi Stop
function NoFishingAnimation.Stop()
    if not NoFishingAnimation.Enabled then
        return false, "Already disabled"
    end
    
    NoFishingAnimation.Enabled = false
    stopFreeze()
    
    return true, "Pose unfrozen"
end

-- Fungsi untuk cek status
function NoFishingAnimation.IsEnabled()
    return NoFishingAnimation.Enabled
end

-- ============================================
-- EVENT HANDLERS
-- ============================================

-- Handle respawn
localPlayer.CharacterAdded:Connect(function(character)
    if NoFishingAnimation.Enabled then
        NoFishingAnimation.Enabled = false
        stopFreeze()
    end
end)

-- Cleanup
game:GetService("Players").PlayerRemoving:Connect(function(player)
    if player == localPlayer then
        if NoFishingAnimation.Enabled then
            NoFishingAnimation.Stop()
        end
    end
end)

return NoFishingAnimation
end)()

-- Module WalkOnWater
CombinedModules.WalkOnWater = (function()
-- ULTRA STABLE WALK ON WATER V3.2 (MODULE EDITION)
-- AUTO SURFACE LIFT
-- NO CHAT COMMAND
-- GUI / TOGGLE FRIENDLY
-- CLIENT SAFE | RAYCAST ONLY

repeat task.wait() until game:IsLoaded()

----------------------------------------------------------
-- SERVICES
----------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

----------------------------------------------------------
-- STATE
----------------------------------------------------------
local WalkOnWater = {
	Enabled = false,
	Platform = nil,
	AlignPos = nil,
	Connection = nil
}

local PLATFORM_SIZE = 14
local OFFSET = 3
local LAST_WATER_Y = nil

----------------------------------------------------------
-- CHARACTER
----------------------------------------------------------
local function GetCharacterReferences()
	local char = LocalPlayer.Character
	if not char then return end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then return end

	return char, humanoid, hrp
end

----------------------------------------------------------
-- FORCE SURFACE LIFT (ANTI STUCK)
----------------------------------------------------------
local function ForceSurfaceLift()
	local _, humanoid, hrp = GetCharacterReferences()
	if not humanoid or not hrp then return end

	if humanoid:GetState() ~= Enum.HumanoidStateType.Swimming then
		return
	end

	for _ = 1, 60 do
		hrp.Velocity = Vector3.new(0, 80, 0)
		task.wait(0.03)

		if humanoid:GetState() ~= Enum.HumanoidStateType.Swimming then
			break
		end
	end

	hrp.CFrame = hrp.CFrame + Vector3.new(0, 3, 0)
end

----------------------------------------------------------
-- WATER DETECTION (RAYCAST ONLY)
----------------------------------------------------------
local function GetWaterHeight()
	local _, _, hrp = GetCharacterReferences()
	if not hrp then return LAST_WATER_Y end

	local origin = hrp.Position + Vector3.new(0, 5, 0)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = { LocalPlayer.Character }
	params.IgnoreWater = false

	local result = Workspace:Raycast(
		origin,
		Vector3.new(0, -600, 0),
		params
	)

	if result then
		LAST_WATER_Y = result.Position.Y
		return LAST_WATER_Y
	end

	return LAST_WATER_Y
end

----------------------------------------------------------
-- PLATFORM
----------------------------------------------------------
local function CreatePlatform()
	if WalkOnWater.Platform then
		WalkOnWater.Platform:Destroy()
	end

	local p = Instance.new("Part")
	p.Size = Vector3.new(PLATFORM_SIZE, 1, PLATFORM_SIZE)
	p.Anchored = true
	p.CanCollide = true
	p.Transparency = 1
	p.CanQuery = false
	p.CanTouch = false
	p.Name = "WaterLockPlatform"
	p.Parent = Workspace

	WalkOnWater.Platform = p
end

----------------------------------------------------------
-- ALIGN POSITION
----------------------------------------------------------
local function SetupAlign()
	local _, _, hrp = GetCharacterReferences()
	if not hrp then return false end

	if WalkOnWater.AlignPos then
		WalkOnWater.AlignPos:Destroy()
	end

	local att = hrp:FindFirstChild("RootAttachment")
	if not att then
		att = Instance.new("Attachment")
		att.Name = "RootAttachment"
		att.Parent = hrp
	end

	local ap = Instance.new("AlignPosition")
	ap.Attachment0 = att
	ap.MaxForce = math.huge
	ap.MaxVelocity = math.huge
	ap.Responsiveness = 200
	ap.RigidityEnabled = true
	ap.Parent = hrp

	WalkOnWater.AlignPos = ap
	return true
end

----------------------------------------------------------
-- CLEANUP
----------------------------------------------------------
local function Cleanup()
	if WalkOnWater.Connection then
		WalkOnWater.Connection:Disconnect()
		WalkOnWater.Connection = nil
	end

	if WalkOnWater.AlignPos then
		WalkOnWater.AlignPos:Destroy()
		WalkOnWater.AlignPos = nil
	end

	if WalkOnWater.Platform then
		WalkOnWater.Platform:Destroy()
		WalkOnWater.Platform = nil
	end
end

----------------------------------------------------------
-- START
----------------------------------------------------------
function WalkOnWater.Start()
	if WalkOnWater.Enabled then return end

	local char, humanoid, hrp = GetCharacterReferences()
	if not char or not humanoid or not hrp then return end

	ForceSurfaceLift()

	WalkOnWater.Enabled = true
	LAST_WATER_Y = nil

	CreatePlatform()
	if not SetupAlign() then
		WalkOnWater.Enabled = false
		Cleanup()
		return
	end

	WalkOnWater.Connection = RunService.Heartbeat:Connect(function()
		if not WalkOnWater.Enabled then return end

		local _, _, currentHRP = GetCharacterReferences()
		if not currentHRP then return end

		local waterY = GetWaterHeight()
		if not waterY then return end

		if WalkOnWater.Platform then
			WalkOnWater.Platform.CFrame = CFrame.new(
				currentHRP.Position.X,
				waterY - 0.5,
				currentHRP.Position.Z
			)
		end

		if WalkOnWater.AlignPos then
			WalkOnWater.AlignPos.Position = Vector3.new(
				currentHRP.Position.X,
				waterY + OFFSET,
				currentHRP.Position.Z
			)
		end
	end)
end

----------------------------------------------------------
-- STOP
----------------------------------------------------------
function WalkOnWater.Stop()
	WalkOnWater.Enabled = false
	Cleanup()
end

----------------------------------------------------------
-- RESPAWN SAFE
----------------------------------------------------------
LocalPlayer.CharacterAdded:Connect(function()
	if WalkOnWater.Enabled then
		task.wait(0.5)
		Cleanup()
		WalkOnWater.Enabled = false
		WalkOnWater.Start()
	end
end)

----------------------------------------------------------
return WalkOnWater
end)()

-- Module AutoFavorite
CombinedModules.AutoFavorite = (function()
-- ============================================
-- AUTO FAVORITE MODULE - LYNX GUI COMPATIBLE
-- Optimized for integration with LynxGUI v2.3.1
-- FIXED: Instant loading, no delay on first toggle
-- ============================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AutoFavoriteModule = {}

-- ============================================
-- CONFIGURATION
-- ============================================
local TIER_MAP = {
    ["Common"] = 1,
    ["Uncommon"] = 2,
    ["Rare"] = 3,
    ["Epic"] = 4,
    ["Legendary"] = 5,
    ["Mythic"] = 6,
    ["SECRET"] = 7
}

local TIER_NAMES = {
    [1] = "Common",
    [2] = "Uncommon",
    [3] = "Rare",
    [4] = "Epic",
    [5] = "Legendary",
    [6] = "Mythic",
    [7] = "SECRET"
}

-- ============================================
-- STATE VARIABLES
-- ============================================
local AUTO_FAVORITE_TIERS = {}
local AUTO_FAVORITE_ENABLED = false
local AUTO_FAVORITE_VARIANTS = {}
local AUTO_FAVORITE_VARIANT_ENABLED = false

-- ============================================
-- CACHED REFERENCES (Pre-loaded)
-- ============================================
local FavoriteEvent, NotificationEvent, itemsModule
local referencesInitialized = false
local initializationAttempted = false

local function InitializeReferences()
    if referencesInitialized then return true end
    if initializationAttempted then return referencesInitialized end
    
    initializationAttempted = true
    
    local success = pcall(function()
        -- Reduced timeout from 5 to 2 seconds for faster loading
        FavoriteEvent = ReplicatedStorage:WaitForChild("Packages", 2)
            :WaitForChild("_Index", 2)
            :WaitForChild("sleitnick_net@0.2.0", 2)
            :WaitForChild("net", 2)
            :WaitForChild("RE/FavoriteItem", 2)

        NotificationEvent = ReplicatedStorage:WaitForChild("Packages", 2)
            :WaitForChild("_Index", 2)
            :WaitForChild("sleitnick_net@0.2.0", 2)
            :WaitForChild("net", 2)
            :WaitForChild("RE/ObtainedNewFishNotification", 2)

        itemsModule = require(ReplicatedStorage:WaitForChild("Items", 2))
        referencesInitialized = true
    end)
    
    if not success then
        initializationAttempted = false -- Allow retry
    end
    
    return success
end

-- ============================================
-- FISH DATA HELPER (Cached)
-- ============================================
local fishDataCache = {}

local function getFishData(itemId)
    if fishDataCache[itemId] then
        return fishDataCache[itemId]
    end
    
    if not itemsModule then 
        InitializeReferences()
        if not itemsModule then return nil end
    end
    
    for _, fish in pairs(itemsModule) do
        if fish.Data and fish.Data.Id == itemId then
            fishDataCache[itemId] = fish
            return fish
        end
    end
    
    return nil
end

-- ============================================
-- TIER MANAGEMENT (GUI Compatible)
-- ============================================
function AutoFavoriteModule.EnableTiers(tierNames)
    if type(tierNames) == "string" then
        tierNames = {tierNames}
    end
    
    for _, tierName in ipairs(tierNames) do
        local tier = TIER_MAP[tierName]
        if tier then
            AUTO_FAVORITE_TIERS[tier] = true
            AUTO_FAVORITE_ENABLED = true
        end
    end
end

function AutoFavoriteModule.DisableTiers(tierNames)
    if type(tierNames) == "string" then
        tierNames = {tierNames}
    end
    
    for _, tierName in ipairs(tierNames) do
        local tier = TIER_MAP[tierName]
        if tier then
            AUTO_FAVORITE_TIERS[tier] = nil
        end
    end
    
    -- Check if any tier still enabled
    local anyEnabled = false
    for _ in pairs(AUTO_FAVORITE_TIERS) do
        anyEnabled = true
        break
    end
    AUTO_FAVORITE_ENABLED = anyEnabled
end

function AutoFavoriteModule.ClearTiers()
    table.clear(AUTO_FAVORITE_TIERS)
    AUTO_FAVORITE_ENABLED = false
end

function AutoFavoriteModule.GetEnabledTiers()
    local enabled = {}
    for tier, _ in pairs(AUTO_FAVORITE_TIERS) do
        table.insert(enabled, TIER_NAMES[tier])
    end
    return enabled
end

function AutoFavoriteModule.IsTierEnabled(tierName)
    local tier = TIER_MAP[tierName]
    return tier and AUTO_FAVORITE_TIERS[tier] == true
end

-- ============================================
-- VARIANT/MUTATION MANAGEMENT (GUI Compatible)
-- ============================================
function AutoFavoriteModule.EnableVariants(variantNames)
    if type(variantNames) == "string" then
        variantNames = {variantNames}
    end
    
    for _, variantName in ipairs(variantNames) do
        AUTO_FAVORITE_VARIANTS[variantName] = true
        AUTO_FAVORITE_VARIANT_ENABLED = true
    end
end

function AutoFavoriteModule.DisableVariants(variantNames)
    if type(variantNames) == "string" then
        variantNames = {variantNames}
    end
    
    for _, variantName in ipairs(variantNames) do
        AUTO_FAVORITE_VARIANTS[variantName] = nil
    end
    
    -- Check if any variant still enabled
    local anyEnabled = false
    for _ in pairs(AUTO_FAVORITE_VARIANTS) do
        anyEnabled = true
        break
    end
    AUTO_FAVORITE_VARIANT_ENABLED = anyEnabled
end

function AutoFavoriteModule.ClearVariants()
    table.clear(AUTO_FAVORITE_VARIANTS)
    AUTO_FAVORITE_VARIANT_ENABLED = false
end

function AutoFavoriteModule.GetEnabledVariants()
    local enabled = {}
    for variant, _ in pairs(AUTO_FAVORITE_VARIANTS) do
        table.insert(enabled, variant)
    end
    return enabled
end

function AutoFavoriteModule.IsVariantEnabled(variantName)
    return AUTO_FAVORITE_VARIANTS[variantName] == true
end

-- ============================================
-- STATUS & INFO (For GUI)
-- ============================================
function AutoFavoriteModule.IsEnabled()
    return AUTO_FAVORITE_ENABLED or AUTO_FAVORITE_VARIANT_ENABLED
end

function AutoFavoriteModule.IsReady()
    return referencesInitialized and connectionEstablished
end

function AutoFavoriteModule.GetStatus()
    return {
        TierEnabled = AUTO_FAVORITE_ENABLED,
        VariantEnabled = AUTO_FAVORITE_VARIANT_ENABLED,
        EnabledTiers = AutoFavoriteModule.GetEnabledTiers(),
        EnabledVariants = AutoFavoriteModule.GetEnabledVariants(),
        Ready = AutoFavoriteModule.IsReady()
    }
end

function AutoFavoriteModule.GetAllTiers()
    return {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "SECRET"}
end

function AutoFavoriteModule.GetAllVariants()
    return {
        "Galaxy", "Corrupt", "Gemstone", "Fairy Dust", "Midnight",
        "Color Burn", "Holographic", "Lightning", "Radioactive",
        "Ghost", "Gold", "Frozen", "1x1x1x1", "Stone", "Sandy",
        "Noob", "Moon Fragment", "Festive", "Albino", "Arctic Frost", "Disco"
    }
end

-- ============================================
-- AUTO FAVORITE CONNECTION (Optimized)
-- ============================================
local connectionEstablished = false
local eventConnection = nil

local function EstablishConnection()
    if connectionEstablished then return true end
    
    -- Initialize references if not already done
    if not referencesInitialized then
        local success = InitializeReferences()
        if not success then
            return false
        end
    end
    
    -- Setup the connection
    eventConnection = NotificationEvent.OnClientEvent:Connect(function(itemId, metadata, extraData, boolFlag)
        -- Quick exit if no filters enabled
        if not AUTO_FAVORITE_ENABLED and not AUTO_FAVORITE_VARIANT_ENABLED then
            return
        end
        
        local inventoryItem = extraData and extraData.InventoryItem
        local uuid = inventoryItem and inventoryItem.UUID
        
        -- Quick validation
        if not uuid or inventoryItem.Favorited then 
            return 
        end
        
        local shouldFavorite = false
        local favoriteReason = ""
        
        -- =====================
        -- CHECK TIER
        -- =====================
        if AUTO_FAVORITE_ENABLED then
            local fishData = getFishData(itemId)
            if fishData and fishData.Data and fishData.Data.Tier then
                if AUTO_FAVORITE_TIERS[fishData.Data.Tier] then
                    shouldFavorite = true
                    local tierName = TIER_NAMES[fishData.Data.Tier] or "Unknown"
                    favoriteReason = "[TIER: " .. tierName .. "]"
                end
            end
        end
        
        -- =====================
        -- CHECK VARIANT
        -- =====================
        if not shouldFavorite and AUTO_FAVORITE_VARIANT_ENABLED then
            local variantId = metadata and metadata.VariantId
            if variantId and variantId ~= "None" and AUTO_FAVORITE_VARIANTS[variantId] then
                shouldFavorite = true
                favoriteReason = "[VARIANT: " .. variantId .. "]"
            end
        end
        
        -- =====================
        -- EXECUTE FAVORITE
        -- =====================
        if shouldFavorite then
            task.delay(0.35, function()
                pcall(function()
                    FavoriteEvent:FireServer(uuid)
                end)
            end)
        end
    end)
    
    connectionEstablished = true
    return true
end

-- ============================================
-- START/STOP FUNCTIONS (Added for GUI control)
-- ============================================
function AutoFavoriteModule.Start()
    if not referencesInitialized then
        local success = InitializeReferences()
        if not success then
            return false, "Failed to initialize references"
        end
    end
    
    if not connectionEstablished then
        local success = EstablishConnection()
        if not success then
            return false, "Failed to establish connection"
        end
    end
    
    return true, "AutoFavorite started successfully"
end

function AutoFavoriteModule.Stop()
    -- Just disable the filters, keep connection alive
    AUTO_FAVORITE_ENABLED = false
    AUTO_FAVORITE_VARIANT_ENABLED = false
    return true, "AutoFavorite stopped"
end

-- ============================================
-- PRE-LOAD ON MODULE INITIALIZATION
-- ============================================
task.spawn(function()
    -- Wait for game to be fully loaded
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
    
    -- Small delay to ensure ReplicatedStorage is ready
    task.wait(0.1)
    
    -- Attempt initialization
    local success = InitializeReferences()
    
    if success then
        -- Establish connection immediately
        EstablishConnection()
    else
        -- Retry after delay if failed
        task.wait(1)
        InitializeReferences()
        EstablishConnection()
    end
end)

-- ============================================
-- CLEANUP
-- ============================================
function AutoFavoriteModule.Cleanup()
    -- Disconnect event
    if eventConnection then
        eventConnection:Disconnect()
        eventConnection = nil
    end
    
    -- Clear data
    table.clear(AUTO_FAVORITE_TIERS)
    table.clear(AUTO_FAVORITE_VARIANTS)
    table.clear(fishDataCache)
    
    -- Reset flags
    AUTO_FAVORITE_ENABLED = false
    AUTO_FAVORITE_VARIANT_ENABLED = false
    connectionEstablished = false
    referencesInitialized = false
    initializationAttempted = false
end

return AutoFavoriteModule
end)()

-- Module LockPosition
CombinedModules.LockPosition = (function()
-- LockPosition.lua
local RunService = game:GetService("RunService")

local LockPosition = {}
LockPosition.Enabled = false
LockPosition.LockedPos = nil
LockPosition.Connection = nil

-- Aktifkan Lock Position
function LockPosition.Start()
    if LockPosition.Enabled then return end
    LockPosition.Enabled = true

    local player = game.Players.LocalPlayer
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")

    LockPosition.LockedPos = hrp.CFrame

    -- Loop untuk menjaga posisi
    LockPosition.Connection = RunService.Heartbeat:Connect(function()
        if not LockPosition.Enabled then return end

        local c = player.Character
        if not c then return end
        
        local hrp2 = c:FindFirstChild("HumanoidRootPart")
        if not hrp2 then return end

        -- Selalu kembalikan ke posisi yang dikunci
        hrp2.CFrame = LockPosition.LockedPos
    end)

    print("Lock Position: Activated")
end

-- Nonaktifkan Lock Position
function LockPosition.Stop()
    LockPosition.Enabled = false

    if LockPosition.Connection then
        LockPosition.Connection:Disconnect()
        LockPosition.Connection = nil
    end

    print("Lock Position: Deactivated")
end

return LockPosition
end)()

-- Module SkinSwapAnimation
CombinedModules.SkinSwapAnimation = (function()
--====================================================--
-- ⚡ SKIN ANIMATION REPLACER MODULE
-- Optimized for GUI integration
--====================================================--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid")

local Animator = humanoid:FindFirstChildOfClass("Animator")
if not Animator then
    Animator = Instance.new("Animator", humanoid)
end

--====================================================--
-- 📦 MODULE
--====================================================--

local SkinAnimation = {}

--====================================================--
-- 🎨 SKIN DATABASE
--====================================================--

local SkinDatabase = {
    ["Eclipse"] = "rbxassetid://107940819382815",
    ["HolyTrident"] = "rbxassetid://128167068291703",
    ["SoulScythe"] = "rbxassetid://82259219343456",
    ["OceanicHarpoon"] = "rbxassetid://76325124055693",
    ["BinaryEdge"] = "rbxassetid://109653945741202",
    ["Vanquisher"] = "rbxassetid://93884986836266",
    ["KrampusScythe"] = "rbxassetid://134934781977605",
    ["BanHammer"] = "rbxassetid://96285280763544",
    ["CorruptionEdge"] = "rbxassetid://126613975718573",
    ["PrincessParasol"] = "rbxassetid://99143072029495"
}

--====================================================--
-- 🎬 CORE VARIABLES
--====================================================--

local CurrentSkin = nil
local AnimationPool = {}
local IsEnabled = false
local POOL_SIZE = 3

local killedTracks = {}
local replaceCount = 0
local currentPoolIndex = 1

--====================================================--
-- 🔄 LOAD ANIMATION POOL
--====================================================--

local function LoadAnimationPool(skinId)
    local animId = SkinDatabase[skinId]
    if not animId then
        return false
    end
    
    -- Clear old pool
    for _, track in ipairs(AnimationPool) do
        pcall(function()
            track:Stop(0)
            track:Destroy()
        end)
    end
    AnimationPool = {}
    
    -- Create animation
    local anim = Instance.new("Animation")
    anim.AnimationId = animId
    anim.Name = "CUSTOM_SKIN_ANIM"
    
    -- Load pool of tracks
    for i = 1, POOL_SIZE do
        local track = Animator:LoadAnimation(anim)
        track.Priority = Enum.AnimationPriority.Action4
        track.Looped = false
        track.Name = "SKIN_POOL_" .. i
        
        -- Pre-cache
        task.spawn(function()
            pcall(function()
                track:Play(0, 1, 0)
                task.wait(0.05)
                track:Stop(0)
            end)
        end)
        
        table.insert(AnimationPool, track)
    end
    
    currentPoolIndex = 1
    return true
end

--====================================================--
-- 🎯 GET NEXT TRACK
--====================================================--

local function GetNextTrack()
    for i = 1, POOL_SIZE do
        local track = AnimationPool[i]
        if track and not track.IsPlaying then
            return track
        end
    end
    
    currentPoolIndex = currentPoolIndex % POOL_SIZE + 1
    return AnimationPool[currentPoolIndex]
end

--====================================================--
-- 🛡️ DETECTION
--====================================================--

local function IsFishCaughtAnimation(track)
    if not track or not track.Animation then return false end
    
    local trackName = string.lower(track.Name or "")
    local animName = string.lower(track.Animation.Name or "")
    
    if string.find(trackName, "fishcaught") or 
       string.find(animName, "fishcaught") or
       string.find(trackName, "caught") or 
       string.find(animName, "caught") then
        return true
    end
    
    return false
end

--====================================================--
-- ⚡ INSTANT REPLACE
--====================================================--

local function InstantReplace(originalTrack)
    local nextTrack = GetNextTrack()
    if not nextTrack then return end
    
    replaceCount = replaceCount + 1
    killedTracks[originalTrack] = tick()
    
    -- Kill original
    task.spawn(function()
        for i = 1, 10 do
            pcall(function()
                if originalTrack.IsPlaying then
                    originalTrack:Stop(0)
                    originalTrack:AdjustSpeed(0)
                    originalTrack.TimePosition = 0
                end
            end)
            task.wait()
        end
    end)
    
    -- Play custom
    pcall(function()
        if nextTrack.IsPlaying then
            nextTrack:Stop(0)
        end
        nextTrack:Play(0, 1, 1)
        nextTrack:AdjustSpeed(1)
    end)
    
    -- Cleanup
    task.delay(1, function()
        killedTracks[originalTrack] = nil
    end)
end

--====================================================--
-- 🔥 MONITORING LOOPS
--====================================================--

-- AnimationPlayed Hook
humanoid.AnimationPlayed:Connect(function(track)
    if not IsEnabled then return end
    
    if IsFishCaughtAnimation(track) then
        task.spawn(function()
            InstantReplace(track)
        end)
    end
end)

-- RenderStepped Monitor
RunService.RenderStepped:Connect(function()
    if not IsEnabled then return end
    
    local tracks = humanoid:GetPlayingAnimationTracks()
    
    for _, track in ipairs(tracks) do
        if string.find(string.lower(track.Name or ""), "skin_pool") then
            continue
        end
        
        if killedTracks[track] then
            if track.IsPlaying then
                pcall(function()
                    track:Stop(0)
                    track:AdjustSpeed(0)
                end)
            end
            continue
        end
        
        if track.IsPlaying and IsFishCaughtAnimation(track) then
            task.spawn(function()
                InstantReplace(track)
            end)
        end
    end
end)

-- Heartbeat Backup
RunService.Heartbeat:Connect(function()
    if not IsEnabled then return end
    
    local tracks = humanoid:GetPlayingAnimationTracks()
    
    for _, track in ipairs(tracks) do
        if string.find(string.lower(track.Name or ""), "skin_pool") then
            continue
        end
        
        if killedTracks[track] and track.IsPlaying then
            pcall(function()
                track:Stop(0)
                track:AdjustSpeed(0)
            end)
        end
    end
end)

-- Stepped Ultra Aggressive
RunService.Stepped:Connect(function()
    if not IsEnabled then return end
    
    for track, _ in pairs(killedTracks) do
        if track and track.IsPlaying then
            pcall(function()
                track:Stop(0)
                track:AdjustSpeed(0)
            end)
        end
    end
end)

--====================================================--
-- 🔄 RESPAWN HANDLER
--====================================================--

player.CharacterAdded:Connect(function(newChar)
    task.wait(1.5)
    
    char = newChar
    humanoid = char:WaitForChild("Humanoid")
    Animator = humanoid:FindFirstChildOfClass("Animator")
    if not Animator then
        Animator = Instance.new("Animator", humanoid)
    end
    
    killedTracks = {}
    replaceCount = 0
    
    if IsEnabled and CurrentSkin then
        task.wait(0.5)
        LoadAnimationPool(CurrentSkin)
    end
end)

--====================================================--
-- 📡 PUBLIC API
--====================================================--

function SkinAnimation.SwitchSkin(skinId)
    if not SkinDatabase[skinId] then
        return false
    end
    
    CurrentSkin = skinId
    
    if IsEnabled then
        return LoadAnimationPool(skinId)
    end
    
    return true
end

function SkinAnimation.Enable()
    if IsEnabled then
        return false
    end
    
    if not CurrentSkin then
        return false
    end
    
    local success = LoadAnimationPool(CurrentSkin)
    if success then
        IsEnabled = true
        killedTracks = {}
        replaceCount = 0
        return true
    end
    
    return false
end

function SkinAnimation.Disable()
    if not IsEnabled then
        return false
    end
    
    IsEnabled = false
    killedTracks = {}
    replaceCount = 0
    
    for _, track in ipairs(AnimationPool) do
        pcall(function()
            track:Stop(0)
        end)
    end
    
    return true
end

function SkinAnimation.IsEnabled()
    return IsEnabled
end

function SkinAnimation.GetCurrentSkin()
    return CurrentSkin
end

function SkinAnimation.GetReplaceCount()
    return replaceCount
end

--====================================================--
-- 🚀 RETURN MODULE
--====================================================--

return SkinAnimation
end)()

-- Module NotificationModule
CombinedModules.NotificationModule = (function()
local Notification = {}

function Notification.Send(title, text, duration)
    duration = duration or 4

    -- Gunakan pcall supaya tidak error di Delta / exploit lain
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration
        })
    end)
end

return Notification
end)()

-- Module GoodPerfectionStable
CombinedModules.GoodPerfectionStable = (function()
-- Auto Fish Module untuk Roblox
-- Module ini dapat diintegrasikan dengan GUI eksternal

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Table
local GoodPerfectionStable = {}
GoodPerfectionStable.Enabled = false

-- Fungsi untuk menghapus UIGradient
local function removeUIGradient()
    local success, err = pcall(function()
        local playerGui = LocalPlayer:WaitForChild("PlayerGui", 5)
        if not playerGui then
            return false
        end
        
        local fishing = playerGui:FindFirstChild("Fishing")
        if not fishing then
            return false
        end
        
        local main = fishing:FindFirstChild("Main")
        if not main then
            return false
        end
        
        local display = main:FindFirstChild("Display")
        if not display then
            return false
        end
        
        local animationBG = display:FindFirstChild("AnimationBG")
        if not animationBG then
            return false
        end
        
        local uiGradient = animationBG:FindFirstChild("UIGradient")
        
        if uiGradient then
            uiGradient:Destroy()
            return true
        else
            return true -- Return true karena tujuan tercapai (tidak ada gradient)
        end
    end)
    
    if not success then
        return false
    end
    
    return true
end

-- Fungsi untuk mengaktifkan auto fishing in-game
local function enableAutoFishing(state)
    local success, result = pcall(function()
        -- Path lengkap sesuai dengan yang Anda berikan
        local packages = ReplicatedStorage:WaitForChild("Packages", 5)
        if not packages then
            warn("Packages tidak ditemukan")
            return false
        end
        
        local index = packages:WaitForChild("_Index", 5)
        if not index then
            warn("_Index tidak ditemukan")
            return false
        end
        
        local sleitnick = index:WaitForChild("sleitnick_net@0.2.0", 5)
        if not sleitnick then
            warn("sleitnick_net@0.2.0 tidak ditemukan")
            return false
        end
        
        local net = sleitnick:WaitForChild("net", 5)
        if not net then
            warn("net tidak ditemukan")
            return false
        end
        
        -- Nama remote adalah "RF/UpdateAutoFishingState" (dengan slash)
        local updateAutoFishing = net:WaitForChild("RF/UpdateAutoFishingState", 5)
        if not updateAutoFishing then
            warn("RF/UpdateAutoFishingState tidak ditemukan")
            return false
        end
        
        if updateAutoFishing:IsA("RemoteFunction") then
            local invokeResult = updateAutoFishing:InvokeServer(state)
            print("Auto Fishing", state and "diaktifkan" or "dinonaktifkan", "- Result:", invokeResult)
            return true
        else
            warn("RF/UpdateAutoFishingState bukan RemoteFunction")
            return false
        end
    end)
    
    if not success then
        warn("Error saat mengaktifkan auto fishing:", result)
        return false
    end
    
    return result
end

-- Fungsi Start - Dipanggil saat toggle ON
function GoodPerfectionStable.Start()
    print("=== Memulai Auto Fish ===")
    GoodPerfectionStable.Enabled = true
    
    -- Tunggu sebentar untuk memastikan game sudah siap
    task.wait(0.3)
    
    -- Hapus UIGradient
    print("Menghapus UIGradient...")
    local gradientRemoved = removeUIGradient()
    print("UIGradient removed:", gradientRemoved)
    
    -- Tunggu sebentar sebelum mengaktifkan auto
    task.wait(0.5)
    
    -- Aktifkan auto fishing in-game
    print("Mengaktifkan Auto Fishing...")
    local autoEnabled = enableAutoFishing(true)
    print("Auto Fishing enabled:", autoEnabled)
    
    if autoEnabled then
        print("✓ Auto Fish berhasil diaktifkan!")
    else
        warn("✗ Auto Fish gagal diaktifkan!")
    end
    
    return autoEnabled
end

-- Fungsi Stop - Dipanggil saat toggle OFF
function GoodPerfectionStable.Stop()
    print("=== Menghentikan Auto Fish ===")
    GoodPerfectionStable.Enabled = false
    
    -- Nonaktifkan auto fishing in-game
    local success = enableAutoFishing(false)
    
    if success then
        print("✓ Auto Fish berhasil dinonaktifkan!")
    else
        warn("✗ Auto Fish gagal dinonaktifkan!")
    end
    
    return success
end

-- Fungsi untuk check status
function GoodPerfectionStable.IsEnabled()
    return GoodPerfectionStable.Enabled
end

-- Export module
return GoodPerfectionStable
end)()

-- Module MerchantSystem
CombinedModules.MerchantSystem = (function()
-- Remote Merchant System (Standalone Version)
-- Bisa dijalankan via raw link (loadstring + HttpGet)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Merchant UI di PlayerGui
local MerchantUI = PlayerGui:WaitForChild("Merchant")

-- ==== FUNCTIONS ====

local function OpenMerchant()
    if MerchantUI then
        MerchantUI.Enabled = true
    end
end

local function CloseMerchant()
    if MerchantUI then
        MerchantUI.Enabled = false
    end
end

return {
    Open = OpenMerchant,
    Close = CloseMerchant
}
end)()

return CombinedModules
