local workspace = game:GetService("Workspace")
local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local localPlayer = players.LocalPlayer
local BASE_THRESHOLD = 0.2
local VELOCITY_SCALING_FACTOR_FAST = 0.050
local VELOCITY_SCALING_FACTOR_SLOW = 0.1
local IMMEDIATE_PARRY_DISTANCE = 15
local IMMEDIATE_HIGH_VELOCITY_THRESHOLD = 85
local UserInputService = game:GetService("UserInputService")
local responses = {"lol what", "??", "wdym", "bru what", "mad cuz bad", "skill issue", "cry"}
local gameEndResponses = {"ggs", "gg :3", "good game", "ggs yall", "wp", "ggs man"}
local keywords = {"auto parry", "auto", "cheating", "hacking"}
local heartbeatConnection
local focusedBall, displayBall = nil, nil
local originalCharacter = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local ballsFolder = workspace:WaitForChild("Balls")
local parryButtonPress = replicatedStorage.Remotes.ParryButtonPress
local abilityButtonPress = replicatedStorage.Remotes.AbilityButtonPress
local sliderValue = 20
local distanceVisualizer = nil
local isRunning = false
local notifyparried = false
local PlayerGui = localPlayer:WaitForChild("PlayerGui")
local Hotbar = PlayerGui:WaitForChild("Hotbar")
local UseRage = false

local uigrad1 = Hotbar.Block.border1.UIGradient
local uigrad2 = Hotbar.Ability.border2.UIGradient

local function isPlayerOnMobile()
    return UserInputService.TouchEnabled and not (UserInputService.KeyboardEnabled or UserInputService.GamepadEnabled)
end

local RayfieldURL = isPlayerOnMobile() and 
                    'https://raw.githubusercontent.com/Hosvile/Refinement/main/MC%3AArrayfield%20Library' or 
                    'https://sirius.menu/rayfield'

local Rayfield = loadstring(game:HttpGet(RayfieldURL))()

local Window = Rayfield:CreateWindow({
   Name = "Blade Ball",
   LoadingTitle = "Atlas Services",
   LoadingSubtitle = "by Settqnta",
   ConfigurationSaving = {
      Enabled = false,
      FolderName = "Atlas Services",
      FileName = "Atlas Services"
   },
   Discord = {
      Enabled = true,
      Invite = "XRHESYyUTb",
      RememberJoins = true
   },
   KeySystem = true,
   KeySettings = {
      Title = "Atlas Services",
      Subtitle = "Key System",
      Note = "Join the discord (discord.gg/XRHESYyUTb)",
      FileName = "SettqntaKey",
      SaveKey = true,
      GrabKeyFromSite = false,
      Key = "SettqntaKey"
   }
})

local AutoParry = Window:CreateTab("Auto Parry", 13014537525)

local function notify(title, content, duration)
    Rayfield:Notify({
        Title = title,
        Content = content,
        Duration = duration or 0.7,
        Image = 10010348543
    })
end

local function chooseNewFocusedBall()
    local balls = ballsFolder:GetChildren()
    for _, ball in ipairs(balls) do
        if ball:GetAttribute("realBall") ~= nil and ball:GetAttribute("realBall") == true then
            focusedBall = ball
            print(focusedBall.Name)
            break
        elseif ball:GetAttribute("target") ~= nil then
            focusedBall = ball
            print(focusedBall.Name)
            break
        end
    end
    
    if focusedBall == nil then
        print("Debug: Could not find a ball that's the realBall or has a target.")
        wait(1)
        chooseNewFocusedBall()
    end
    return focusedBall
end

local function getDynamicThreshold(ballVelocityMagnitude)
    if ballVelocityMagnitude > 60 then
        return math.max(0.20, BASE_THRESHOLD - (ballVelocityMagnitude * VELOCITY_SCALING_FACTOR_FAST))
    else
        return math.min(0.01, BASE_THRESHOLD + (ballVelocityMagnitude * VELOCITY_SCALING_FACTOR_SLOW))
    end
end

local function timeUntilImpact(ballVelocity, distanceToPlayer, playerVelocity)
    if not originalCharacter then return end
    local directionToPlayer = (originalCharacter.HumanoidRootPart.Position - focusedBall.Position).Unit
    local velocityTowardsPlayer = ballVelocity:Dot(directionToPlayer) - playerVelocity:Dot(directionToPlayer)
    
    if velocityTowardsPlayer <= 0 then
        return math.huge
    end
    
    return (distanceToPlayer - sliderValue) / velocityTowardsPlayer
end

local function updateDistanceVisualizer()
    local charPos = originalCharacter and originalCharacter.PrimaryPart and originalCharacter.PrimaryPart.Position
    if charPos and focusedBall then
        if distanceVisualizer then
            distanceVisualizer:Destroy()
        end

        local timeToImpactValue = timeUntilImpact(focusedBall.Velocity, (focusedBall.Position - charPos).Magnitude, originalCharacter.PrimaryPart.Velocity)
        local ballFuturePosition = focusedBall.Position + focusedBall.Velocity * timeToImpactValue

        distanceVisualizer = Instance.new("Part")
        distanceVisualizer.Size = Vector3.new(1, 1, 1)
        distanceVisualizer.Anchored = true
        distanceVisualizer.CanCollide = false
        distanceVisualizer.Position = ballFuturePosition
        distanceVisualizer.Parent = workspace    
    end
end

local function checkIfTarget()
    for _, v in pairs(ballsFolder:GetChildren()) do
        if v:IsA("Part") and v.BrickColor == BrickColor.new("Really red") then 
            print("Ball is targetting player.")
            return true 
        end 
    end 
    return false
end

local function isCooldownInEffect(uigradient)
    return uigradient.Offset.Y < 0.5
end

local function checkBallDistance()
    if not originalCharacter or not checkIfTarget() then return end

    local charPos = originalCharacter.PrimaryPart.Position
    local charVel = originalCharacter.PrimaryPart.Velocity

    if focusedBall and not focusedBall.Parent then
        print("Focused ball lost parent. Choosing a new focused ball.")
        chooseNewFocusedBall()
    end
    if not focusedBall then 
        print("No focused ball.")
        chooseNewFocusedBall()
    end

    local ball = focusedBall
    local distanceToPlayer = (ball.Position - charPos).Magnitude
    local ballVelocityTowardsPlayer = ball.Velocity:Dot((charPos - ball.Position).Unit)
    
    if distanceToPlayer < 15 then
        parryButtonPress:Fire()
        task.wait()
    end

    if timeUntilImpact(ball.Velocity, distanceToPlayer, charVel) < getDynamicThreshold(ballVelocityTowardsPlayer) then
        if (originalCharacter.Abilities["Raging Deflection"].Enabled or originalCharacter.Abilities["Rapture"].Enabled) and UseRage == true then
            if not isCooldownInEffect(uigrad2) then
                abilityButtonPress:Fire()
            end

            if isCooldownInEffect(uigrad2) and not isCooldownInEffect(uigrad1) then
                parryButtonPress:Fire()
                if notifyparried == true then
                    notify("Auto Parry", "Manually Parried Ball (Ability on CD)", 0.3)
                end
            end

        elseif not isCooldownInEffect(uigrad1) then
            print(isCooldownInEffect(uigrad1))
            parryButtonPress:Fire()
            if notifyparried == true then
                notify("Auto Parry", "Automatically Parried Ball", 0.3)
            end
            task.wait(0.3)
        end
    end
end

local function autoParryCoroutine()
    while isRunning do
        checkBallDistance()
        updateDistanceVisualizer()
        task.wait()
    end
end

localPlayer.CharacterAdded:Connect(function(newCharacter)
    originalCharacter = newCharacter
    chooseNewFocusedBall()
    updateDistanceVisualizer()
end)

localPlayer.CharacterRemoving:Connect(function()
    if distanceVisualizer then
        distanceVisualizer:Destroy()
        distanceVisualizer = nil
    end
end)

local function startAutoParry()
    print("Script successfully ran.")
    
    chooseNewFocusedBall()
    
    isRunning = true
    local co = coroutine.create(autoParryCoroutine)
    coroutine.resume(co)
end

local function stopAutoParry()
    isRunning = false
end

local AutoParrySection = AutoParry:CreateSection("Auto Parry")

local AutoParryToggle = AutoParry:CreateToggle({
    Name = "Auto Parry",
    CurrentValue = false,
    Flag = "AutoParryFlag",
    Callback = function(Value)
        if Value then
            startAutoParry()
            notify("Auto Parry", "Auto Parry has been started", 1)
        else
            stopAutoParry()
            notify("Auto Parry", "Auto Parry has been disabled", 1)
        end
    end,
})

local AutoRagingDeflect = AutoParry:CreateToggle({
    Name = "Auto Rage Parry/Rapture Parry (MUST EQUIP PROPER ABILITY)",
    CurrentValue = false,
    Flag = "AutoRagingDeflectFlag",
    Callback = function(Value)
        if Value then
            startAutoParry()
            UseRage = Value
            notify("Auto Parry", "Auto Parry with Ability has been started", 1)
        else
            stopAutoParry()
            UseRage = Value
            notify("Auto Parry", "Auto Parry with Ability has been disabled", 1)
        end
    end,
})

local CloseFighting = AutoParry:CreateSection("Close Fighting")

local SpamParry = AutoParry:CreateKeybind({
    Name = "Spam Parry (Hold)",
    CurrentKeybind = "C",
    HoldToInteract = true,
    Flag = "ToggleParrySpam", 
    Callback = function(Keybind)
        parryButtonPress:Fire()
    end,
})

local Configuration = AutoParry:CreateSection("Configuration")

local DistanceSlider = AutoParry:CreateSlider({
    Name = "Distance Configuration",
    Range = {0, 100},
    Increment = 1,
    Suffix = "Distance",
    CurrentValue = 20,
    Flag = "DistanceSlider",
    Callback = function(Value)
        sliderValue = Value
    end,
})

local ToggleParryOn = AutoParry:CreateKeybind({
    Name = "Toggle Parry On (Bind)",
    CurrentKeybind = "One",
    HoldToInteract = false,
    Flag = "ToggleParryOn", 
    Callback = function(Keybind)
        AutoParryToggle:Set(true)
    end,
})

local ToggleParryOff = AutoParry:CreateKeybind({
    Name = "Toggle Parry Off (Bind)",
    CurrentKeybind = "Two",
    HoldToInteract = false,
    Flag = "ToggleParryOff",
    Callback = function(Keybind)
        AutoParryToggle:Set(false)
    end,
})

local ToggleParryOffPlus = AutoParry:CreateKeybind({
    Name = "+ 10 range",
    CurrentKeybind = "X",
    HoldToInteract = false,
    Flag = "ToggleParryOffPlus",
    Callback = function()
         if sliderValue < 200 then
             sliderValue = sliderValue + 10
             DistanceSlider:Set(sliderValue)
             notify("Range Increased", "New Range: " .. sliderValue)
         end
    end,
})

local ToggleParryOffMinus = AutoParry:CreateKeybind({
    Name = "- 10 range",
    CurrentKeybind = "Z",
    HoldToInteract = false,
    Flag = "ToggleParryOffMinus",
    Callback = function()
         if sliderValue > 0 then
             sliderValue = sliderValue - 10
             DistanceSlider:Set(sliderValue)
             notify("Range Decreased", "New Range: " .. sliderValue)
         end
    end,
})

local AutoGGToggle = AutoParry:CreateToggle({
    Name = "Auto GG",
    CurrentValue = false,
    Flag = "AutoGGFlage",
    Callback = function(Value)
        return
    end,
})

local AutoResponseToggle = AutoParry:CreateToggle({
    Name = "Auto Response",
    CurrentValue = false,
    Flag = "AutoResponseFlage",
    Callback = function(Value)
        return
    end,
})

local notifyparriedthing = AutoParry:CreateButton({
    Name = "Enable/Disable Notify when parried",
    Callback = function()
        if not notifyparried == true then
            notifyparried = true
            notify("Auto Parry", "Auto Parry Notify when parried has been enabled", 0.7)
        else
            notifyparried = false
            notify("Auto Parry", "Auto Parry Notify when parried has been disabled", 0.7)
        end
    end,
})

local ChangeDistanceTo30thing = AutoParry:CreateKeybind({
    Name = "Distance 30",
    CurrentKeybind = "V",
    HoldToInteract = false,
    Flag = "Distanceto100",
    Callback = function(Keybind)
        DistanceSlider:Set(30)
        sliderValue = 30
        notify("Range Set", "New Range: " .. sliderValue)
    end,
})

local ChangeDistanceTo100thing = AutoParry:CreateKeybind({
    Name = "Distance 100",
    CurrentKeybind = "B",
    HoldToInteract = false,
    Flag = "Distanceto100",
    Callback = function(Keybind)
        sliderValue = 100
        DistanceSlider:Set(100)
        notify("Range Set", "New Range: " .. sliderValue)
    end,
})

workspace:FindFirstChild("Alive").ChildRemoved:Connect(function()
    if #(workspace.Alive:GetChildren()) <= 1 and AutoGGToggle.CurrentValue and not ggdebounce then
        ggdebounce = true
        local randomResponse = math.random(1, #gameEndResponses)
        wait(math.random(2,3.5))
        replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(gameEndResponses[randomResponse],"All")
        task.wait(math.random(1.5,3.3))
        ggdebounce = false
    end
end)

players.PlayerChatted:Connect(function(PlayerChatType,Player,Message)
    for _,v in pairs(keywords) do
        if (string.find(Message, v)) and Player ~= localPlayer and AutoResponseToggle.CurrentValue and not responsedebounce then
            responsedebounce = true
            local choice = math.random(1, #responses)
            replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(responses[choice],"All")
            task.wait(2,5)
            responsedebounce = false
        end
    end
end)
