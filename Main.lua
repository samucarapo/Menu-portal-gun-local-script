local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local Player = Players.LocalPlayer

local FlySpeed = 80
local ArrivalDistance = 2
local SlowDistance = 35
local Acceleration = 15
local Deceleration = 12
local ClickMaxTime = 0.25
local DragDistance = 8

-- ===== CONFIGURAÇÕES DE BYPASS =====
local UseSwimMethod = true
local UsePropertySpoof = true
local UseNetworkSpoof = true
local UseVelocityFlicker = true
local UsePositionJitter = true
local UseTPSpoof = true
local TPFakeVelocity = true
local TPPartialTeleport = true

local VelocityOvershoot = 1.35
local JitterAmount = 0.5
local FlickerInterval = 0.05

-- ===== VARIÁVEIS GLOBAIS =====
local Character
local Humanoid
local RootPart

local Flying = false
local FlyConnection = nil
local SavedPosition = nil
local CurrentFlySpeed = 0
local OriginalCollisions = {}
local SwimMethodActive = false
local OriginalSwimState = {}
local LastValidPosition = nil
local FrameCounter = 0

local function UpdateCharacter()
    Character = Player.Character or Player.CharacterAdded:Wait()
    Humanoid = Character:WaitForChild("Humanoid")
    RootPart = Character:WaitForChild("HumanoidRootPart")
    LastValidPosition = RootPart.Position
end

local function SetStatus(Text)
    if StatusLabel then
        StatusLabel.Text = Text
    end
end

local function EnableSwimMethod()
    if not Humanoid then return end

    if not SwimMethodActive then
        OriginalSwimState[Enum.HumanoidStateType.Swimming] = Humanoid:GetStateEnabled(Enum.HumanoidStateType.Swimming)
        OriginalSwimState[Enum.HumanoidStateType.Climbing] = Humanoid:GetStateEnabled(Enum.HumanoidStateType.Climbing)
        OriginalSwimState[Enum.HumanoidStateType.FallingDown] = Humanoid:GetStateEnabled(Enum.HumanoidStateType.FallingDown)
        OriginalSwimState[Enum.HumanoidStateType.Freefall] = Humanoid:GetStateEnabled(Enum.HumanoidStateType.Freefall)

        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)

        SwimMethodActive = true
    end

    if Humanoid:GetState() ~= Enum.HumanoidStateType.Swimming then
        Humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
    end
end

local function DisableSwimMethod()
    if not Humanoid or not SwimMethodActive then return end

    for State, Enabled in pairs(OriginalSwimState) do
        Humanoid:SetStateEnabled(State, Enabled)
    end

    OriginalSwimState = {}
    SwimMethodActive = false
end

local function SpoofProperties(RealVelocity)
    if not UsePropertySpoof or not RootPart then
        return RealVelocity
    end

    if Humanoid then
        local FakeWalkSpeed = math.min(16, FlySpeed * 0.15)
        Humanoid.WalkSpeed = FakeWalkSpeed
        Humanoid.JumpPower = 50
        Humanoid.AutoRotate = true
        Humanoid.PlatformStand = false
    end

    return RealVelocity * 0.3
end

local function SpoofNetworkPosition(CurrentPos, Direction, Speed, DeltaTime)
    if not UseNetworkSpoof or not RootPart then
        return CurrentPos
    end

    local SpoofOffset = Vector3.new(
        math.sin(DeltaTime * 100) * 0.1,
        math.cos(DeltaTime * 80) * 0.1,
        math.sin(DeltaTime * 120 + 1) * 0.1
    )

    return CurrentPos + SpoofOffset
end

local function ApplyVelocityFlicker(Velocity)
    if not UseVelocityFlicker then return Velocity end

    FrameCounter = FrameCounter + 1

    if FrameCounter % 2 == 0 then
        return Velocity * 1.1
    else
        return Velocity * 0.9
    end
end

local function ApplyPositionJitter(Position)
    if not UsePositionJitter then return Position end

    local Time = tick()

    local Jitter = Vector3.new(
        math.sin(Time * 30) * JitterAmount,
        math.cos(Time * 25) * JitterAmount,
        math.sin(Time * 35 + 2) * JitterAmount
    )

    return Position + Jitter
end

local function ApplyFlyMovement(Direction, Speed, DeltaTime)
    if not RootPart then return end

    EnableSwimMethod()

    local RealVelocity = Direction * Speed
    local OvershootVelocity = RealVelocity * VelocityOvershoot
    local FlickeredVelocity = ApplyVelocityFlicker(OvershootVelocity)

    local CurrentPos = RootPart.Position
    local JitteredPos = ApplyPositionJitter(CurrentPos)

    JitteredPos = SpoofNetworkPosition(
        JitteredPos,
        Direction,
        Speed,
        DeltaTime
    ) or CurrentPos

    SpoofProperties(FlickeredVelocity)

    RootPart.AssemblyLinearVelocity = FlickeredVelocity

    RootPart.CFrame = CFrame.lookAt(
        JitteredPos,
        JitteredPos + Direction,
        Vector3.yAxis
    )
end

local function EnableNoclip()
    if not Character then return end

    OriginalCollisions = {}

    for _, Object in ipairs(Character:GetDescendants()) do
        if Object:IsA("BasePart") then
            OriginalCollisions[Object] = {
                CanCollide = Object.CanCollide,
                Friction = Object.Friction,
                Elasticity = Object.Elasticity,
                CollisionGroup = Object.CollisionGroup
            }

            Object.CanCollide = false
            Object.Friction = 0
            Object.Elasticity = 0
        end
    end

    if RootPart then
        PhysicsService:SetPartCollisionGroup(RootPart, "Debris")
    end
end

local function RestoreCollisions()
    for Object, OriginalValue in pairs(OriginalCollisions) do
        if Object and Object.Parent then
            Object.CanCollide = OriginalValue.CanCollide
            Object.Friction = OriginalValue.Friction
            Object.Elasticity = OriginalValue.Elasticity

            PhysicsService:SetPartCollisionGroup(
                Object,
                OriginalValue.CollisionGroup
            )
        end
    end

    OriginalCollisions = {}
end

local function SmoothTeleport(TargetPosition, Steps)
    Steps = Steps or 10

    local StartPos = RootPart.Position
    local Direction = TargetPosition - StartPos
    local Distance = Direction.Magnitude

    if Distance < 5 then
        RootPart.CFrame = CFrame.new(TargetPosition)
        return
    end

    for i = 1, Steps do
        local Progress = i / Steps
        local EasedProgress = Progress * Progress * (3 - 2 * Progress)
        local NewPos = StartPos + Direction * EasedProgress

        RootPart.CFrame = CFrame.new(NewPos)

        if TPFakeVelocity then
            local FakeSpeed = Distance / (Steps * 0.1)
            RootPart.AssemblyLinearVelocity = Direction.Unit * FakeSpeed
        end

        task.wait(0.05)
    end

    RootPart.CFrame = CFrame.new(TargetPosition)
end

local function SpoofedTeleport(TargetPosition)
    if not UseTPSpoof then
        RootPart.CFrame = CFrame.new(TargetPosition)
        return
    end

    local FakePos = TargetPosition + Vector3.new(
        math.random(-5, 5),
        math.random(-2, 2),
        math.random(-5, 5)
    )

    RootPart.CFrame = CFrame.new(FakePos)

    task.wait(0.01)

    RootPart.CFrame = CFrame.new(TargetPosition)
end

local function PartialTeleport(TargetPosition)
    if not TPPartialTeleport then
        RootPart.CFrame = CFrame.new(TargetPosition)
        return
    end

    local Parts = {}

    for _, Part in ipairs(Character:GetDescendants()) do
        if Part:IsA("BasePart") and Part ~= RootPart then
            table.insert(Parts, {
                Part = Part,
                Offset = Part.Position - RootPart.Position
            })
        end
    end

    RootPart.CFrame = CFrame.new(TargetPosition)

    task.wait(0.01)

    for _, Data in ipairs(Parts) do
        local Part = Data.Part

        if Part and Part.Parent then
            Part.CFrame = CFrame.new(
                TargetPosition + Data.Offset
            )
        end
    end
end

local function TeleportWithBypass(TargetPosition)
    UpdateCharacter()

    if not RootPart or not Humanoid then
        return
    end

    if Flying then
        StopFly()
        task.wait(0.05)
    end

    if Humanoid and UseSwimMethod then
        Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        task.wait(0.01)
    end

    EnableNoclip()

    local Distance = (TargetPosition - RootPart.Position).Magnitude

    if Distance > 200 then
        SpoofedTeleport(TargetPosition)
        task.wait(0.02)

        PartialTeleport(TargetPosition)
        task.wait(0.02)

        SmoothTeleport(TargetPosition, 15)

    elseif Distance > 50 then
        SpoofedTeleport(TargetPosition)
        task.wait(0.02)

        SmoothTeleport(TargetPosition, 5)

    else
        RootPart.CFrame = CFrame.new(TargetPosition)
    end

    if Humanoid then
        Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
        task.wait(0.05)
        Humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end

    RestoreCollisions()

    RootPart.AssemblyLinearVelocity = Vector3.new(
        math.random(-2, 2),
        math.random(0, 2),
        math.random(-2, 2)
    )

    LastValidPosition = RootPart.Position

    SetStatus("Teleportado")

    task.delay(1.5, function()
        if not Flying then
            SetStatus("Pronto")
        end
    end)
end

local function StopFly()
    Flying = false

    if FlyConnection then
        FlyConnection:Disconnect()
        FlyConnection = nil
    end

    DisableSwimMethod()
    RestoreCollisions()

    CurrentFlySpeed = 0

    if Humanoid then
        Humanoid.PlatformStand = false
        Humanoid.AutoRotate = true
        Humanoid.WalkSpeed = 16
        Humanoid.JumpPower = 50
    end

    if RootPart then
        RootPart.AssemblyLinearVelocity = Vector3.zero
        RootPart.AssemblyAngularVelocity = Vector3.zero
    end

    if FlyButton then
        FlyButton.Text = "VOAR"
    end

    SetStatus("Pronto")
end

local function FlyTo(Target)
    UpdateCharacter()

    if not RootPart or not Humanoid then
        return
    end

    if Flying then
        StopFly()
    end

    Flying = true
    CurrentFlySpeed = 0
    FrameCounter = 0

    EnableNoclip()
    EnableSwimMethod()

    UsePropertySpoof = true
    UseNetworkSpoof = true
    UseVelocityFlicker = true
    UsePositionJitter = true

    Humanoid.PlatformStand = false
    Humanoid.AutoRotate = true

    FlyButton.Text = "VOANDO"
    SetStatus("Voando...")

    FlyConnection = RunService.Heartbeat:Connect(function(DeltaTime)
        if not Flying then
            return
        end

        if not RootPart or not RootPart.Parent then
            StopFly()
            return
        end

        for Object in pairs(OriginalCollisions) do
            if Object and Object.Parent then
                Object.CanCollide = false
            end
        end

        EnableSwimMethod()

        local CurrentPosition = RootPart.Position
        local Offset = Target - CurrentPosition
        local Distance = Offset.Magnitude

        if Distance <= ArrivalDistance then
            RootPart.CFrame = CFrame.new(Target)
            RootPart.AssemblyLinearVelocity = Vector3.zero

            StopFly()
            SetStatus("Destino alcançado")

            task.delay(1.5, function()
                if not Flying then
                    SetStatus("Pronto")
                end
            end)

            return
        end

        local Direction = Offset.Unit

        if Distance > SlowDistance then
            CurrentFlySpeed = CurrentFlySpeed +
                (FlySpeed - CurrentFlySpeed) *
                math.clamp(DeltaTime * Acceleration, 0, 1)
        else
            local SlowFactor = math.clamp(
                Distance / SlowDistance,
                0.08,
                1
            )

            local TargetSpeed = FlySpeed * SlowFactor

            CurrentFlySpeed = CurrentFlySpeed +
                (TargetSpeed - CurrentFlySpeed) *
                math.clamp(DeltaTime * Deceleration, 0, 1)
        end

        ApplyFlyMovement(
            Direction,
            CurrentFlySpeed,
            DeltaTime
        )

        if FrameCounter % 10 == 0 then
            RootPart.AssemblyLinearVelocity =
                Direction *
                CurrentFlySpeed *
                VelocityOvershoot
        end

        LastValidPosition = RootPart.Position
    end)
end

local function EmergencyReset()
    if Flying and LastValidPosition then
        RootPart.CFrame = CFrame.new(LastValidPosition)
        RootPart.AssemblyLinearVelocity = Vector3.zero

        SetStatus("Reset aplicado")

        task.wait(0.1)

        if Flying then
            StopFly()
        end
    end
end

-- ===== INTERFACE GUI =====

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FlyTP"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 250, 0, 235)
Main.Position = UDim2.new(0.5, -125, 0.5, -117)
Main.BackgroundColor3 = Color3.fromRGB(20, 22, 27)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(55, 55, 65)
MainStroke.Thickness = 1
MainStroke.Parent = Main

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 38)
Header.BackgroundColor3 = Color3.fromRGB(28, 30, 36)
Header.BorderSizePixel = 0
Header.Parent = Main

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = Header

local HeaderFix = Instance.new("Frame")
HeaderFix.Size = UDim2.new(1, 0, 0, 10)
HeaderFix.Position = UDim2.new(0, 0, 1, -10)
HeaderFix.BackgroundColor3 = Color3.fromRGB(28, 30, 36)
HeaderFix.BorderSizePixel = 0
HeaderFix.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -80, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Portal Gun + Bypass"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Minimize = Instance.new("TextButton")
Minimize.Size = UDim2.new(0, 30, 0, 30)
Minimize.Position = UDim2.new(1, -68, 0, 4)
Minimize.BackgroundTransparency = 1
Minimize.Text = "−"
Minimize.TextColor3 = Color3.fromRGB(200, 200, 200)
Minimize.TextSize = 22
Minimize.Font = Enum.Font.GothamBold
Minimize.Parent = Header

local Close = Instance.new("TextButton")
Close.Size = UDim2.new(0, 30, 0, 30)
Close.Position = UDim2.new(1, -35, 0, 4)
Close.BackgroundTransparency = 1
Close.Text = "×"
Close.TextColor3 = Color3.fromRGB(255, 100, 100)
Close.TextSize = 22
Close.Font = Enum.Font.GothamBold
Close.Parent = Header

StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -24, 0, 25)
StatusLabel.Position = UDim2.new(0, 12, 0, 45)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Pronto - Bypass Ativo!"
StatusLabel.TextColor3 = Color3.fromRGB(170, 170, 180)
StatusLabel.TextSize = 12
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = Main

local CoordinateBox = Instance.new("TextBox")
CoordinateBox.Size = UDim2.new(1, -24, 0, 32)
CoordinateBox.Position = UDim2.new(0, 12, 0, 75)
CoordinateBox.BackgroundColor3 = Color3.fromRGB(30, 32, 38)
CoordinateBox.BorderSizePixel = 0
CoordinateBox.PlaceholderText = "X Y Z"
CoordinateBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 110)
CoordinateBox.Text = ""
CoordinateBox.TextColor3 = Color3.fromRGB(255, 255, 255)
CoordinateBox.TextSize = 12
CoordinateBox.Font = Enum.Font.Gotham
CoordinateBox.ClearTextOnFocus = false
CoordinateBox.Parent = Main

local CoordinateCorner = Instance.new("UICorner")
CoordinateCorner.CornerRadius = UDim.new(0, 6)
CoordinateCorner.Parent = CoordinateBox

local SpeedBox = Instance.new("TextBox")
SpeedBox.Size = UDim2.new(0, 70, 0, 32)
SpeedBox.Position = UDim2.new(1, -82, 0, 115)
SpeedBox.BackgroundColor3 = Color3.fromRGB(30, 32, 38)
SpeedBox.BorderSizePixel = 0
SpeedBox.Text = "80"
SpeedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedBox.TextSize = 12
SpeedBox.Font = Enum.Font.Gotham
SpeedBox.ClearTextOnFocus = false
SpeedBox.Parent = Main

local SpeedCorner = Instance.new("UICorner")
SpeedCorner.CornerRadius = UDim.new(0, 6)
SpeedCorner.Parent = SpeedBox

local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(0, 45, 0, 32)
SpeedLabel.Position = UDim2.new(1, -130, 0, 115)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Text = "Speed"
SpeedLabel.TextColor3 = Color3.fromRGB(170, 170, 180)
SpeedLabel.TextSize = 11
SpeedLabel.Font = Enum.Font.Gotham
SpeedLabel.Parent = Main

local function CreateButton(Text, Position, Size)
    local Button = Instance.new("TextButton")

    Button.Size = Size or UDim2.new(0, 108, 0, 32)
    Button.Position = Position
    Button.BackgroundColor3 = Color3.fromRGB(35, 37, 44)
    Button.BorderSizePixel = 0
    Button.Text = Text
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.TextSize = 11
    Button.Font = Enum.Font.GothamBold
    Button.Parent = Main

    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 6)
    ButtonCorner.Parent = Button

    return Button
end

FlyButton = CreateButton(
    "VOAR",
    UDim2.new(0, 12, 0, 155)
)

local TPButton = CreateButton(
    "TELEPORTAR",
    UDim2.new(0, 130, 0, 155)
)

local StopButton = CreateButton(
    "PARAR",
    UDim2.new(0, 12, 0, 195)
)

local SaveButton = CreateButton(
    "SALVAR",
    UDim2.new(0, 130, 0, 195)
)

local MiniButton = Instance.new("TextButton")
MiniButton.Size = UDim2.new(0, 42, 0, 42)
MiniButton.Position = UDim2.new(0.5, -21, 0.5, -21)
MiniButton.BackgroundColor3 = Color3.fromRGB(20, 22, 27)
MiniButton.BorderSizePixel = 0
MiniButton.Text = "F"
MiniButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MiniButton.TextSize = 18
MiniButton.Font = Enum.Font.GothamBold
MiniButton.Visible = false
MiniButton.Parent = ScreenGui

local MiniCorner = Instance.new("UICorner")
MiniCorner.CornerRadius = UDim.new(1, 0)
MiniCorner.Parent = MiniButton

local MiniStroke = Instance.new("UIStroke")
MiniStroke.Color = Color3.fromRGB(55, 55, 65)
MiniStroke.Thickness = 1
MiniStroke.Parent = MiniButton

local function GetCoordinates(Text)
    Text = Text:gsub(",", " ")

    local Numbers = {}

    for Number in Text:gmatch("-?%d+%.?%d*") do
        table.insert(Numbers, tonumber(Number))
    end

    if #Numbers >= 3 then
        return Vector3.new(
            Numbers[1],
            Numbers[2],
            Numbers[3]
        )
    end
end

local function TeleportToMouse()
    local Mouse = Player:GetMouse()

    if Mouse and Mouse.Hit then
        TeleportWithBypass(Mouse.Hit.Position)
    end
end

FlyButton.MouseButton1Click:Connect(function()
    local Target = GetCoordinates(CoordinateBox.Text)

    if not Target then
        SetStatus("Coordenadas inválidas")
        return
    end

    local Speed = tonumber(SpeedBox.Text)

    if Speed then
        FlySpeed = math.clamp(Speed, 1, 500)
    end

    FlyTo(Target)
end)

TPButton.MouseButton1Click:Connect(function()
    local Target = GetCoordinates(CoordinateBox.Text)

    if not Target then
        SetStatus("Coordenadas inválidas")
        return
    end

    TeleportWithBypass(Target)
end)

StopButton.MouseButton1Click:Connect(function()
    StopFly()
end)

SaveButton.MouseButton1Click:Connect(function()
    UpdateCharacter()

    if RootPart then
        SavedPosition = RootPart.CFrame

        local Position = RootPart.Position

        CoordinateBox.Text = string.format(
            "%.2f %.2f %.2f",
            Position.X,
            Position.Y,
            Position.Z
        )

        SetStatus("Posição salva")
    end
end)

local CloseConfirm = Instance.new("Frame")
CloseConfirm.Size = UDim2.new(0, 210, 0, 100)
CloseConfirm.Position = UDim2.new(0.5, -105, 0.5, -50)
CloseConfirm.BackgroundColor3 = Color3.fromRGB(25, 27, 32)
CloseConfirm.BorderSizePixel = 0
CloseConfirm.Visible = false
CloseConfirm.ZIndex = 10
CloseConfirm.Parent = Main

local ConfirmCorner = Instance.new("UICorner")
ConfirmCorner.CornerRadius = UDim.new(0, 8)
ConfirmCorner.Parent = CloseConfirm

local ConfirmText = Instance.new("TextLabel")
ConfirmText.Size = UDim2.new(1, -20, 0, 45)
ConfirmText.Position = UDim2.new(0, 10, 0, 5)
ConfirmText.BackgroundTransparency = 1
ConfirmText.Text = "Fechar o menu?"
ConfirmText.TextColor3 = Color3.fromRGB(255, 255, 255)
ConfirmText.TextSize = 13
ConfirmText.Font = Enum.Font.GothamBold
ConfirmText.Parent = CloseConfirm

local ConfirmYes = Instance.new("TextButton")
ConfirmYes.Size = UDim2.new(0, 85, 0, 30)
ConfirmYes.Position = UDim2.new(0, 15, 1, -40)
ConfirmYes.BackgroundColor3 = Color3.fromRGB(50, 52, 60)
ConfirmYes.BorderSizePixel = 0
ConfirmYes.Text = "SIM"
ConfirmYes.TextColor3 = Color3.fromRGB(255, 255, 255)
ConfirmYes.TextSize = 11
ConfirmYes.Font = Enum.Font.GothamBold
ConfirmYes.ZIndex = 11
ConfirmYes.Parent = CloseConfirm

local ConfirmNo = Instance.new("TextButton")
ConfirmNo.Size = UDim2.new(0, 85, 0, 30)
ConfirmNo.Position = UDim2.new(1, -100, 1, -40)
ConfirmNo.BackgroundColor3 = Color3.fromRGB(50, 52, 60)
ConfirmNo.BorderSizePixel = 0
ConfirmNo.Text = "NÃO"
ConfirmNo.TextColor3 = Color3.fromRGB(255, 255, 255)
ConfirmNo.TextSize = 11
ConfirmNo.Font = Enum.Font.GothamBold
ConfirmNo.ZIndex = 11
ConfirmNo.Parent = CloseConfirm

Minimize.MouseButton1Click:Connect(function()
    Main.Visible = false
    MiniButton.Visible = true
end)

MiniButton.MouseButton1Click:Connect(function()
    Main.Visible = true
    MiniButton.Visible = false
end)

Close.MouseButton1Click:Connect(function()
    CloseConfirm.Visible = true
end)

ConfirmNo.MouseButton1Click:Connect(function()
    CloseConfirm.Visible = false
end)

ConfirmYes.MouseButton1Click:Connect(function()
    StopFly()
    ScreenGui:Destroy()
end)

local Dragging = false
local DragStart
local StartPosition
local DragMoved = false

Header.InputBegan:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1
        or Input.UserInputType == Enum.UserInputType.Touch then

        Dragging = true
        DragMoved = false
        DragStart = Input.Position
        StartPosition = Main.Position

        Input.Changed:Connect(function()
            if Input.UserInputState == Enum.UserInputState.End then
                Dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(Input)
    if Dragging and (
        Input.UserInputType == Enum.UserInputType.MouseMovement
        or Input.UserInputType == Enum.UserInputType.Touch
    ) then

        local Delta = Input.Position - DragStart

        if Delta.Magnitude > DragDistance then
            DragMoved = true
        end

        Main.Position = UDim2.new(
            StartPosition.X.Scale,
            StartPosition.X.Offset + Delta.X,
            StartPosition.Y.Scale,
            StartPosition.Y.Offset + Delta.Y
        )
    end
end)

local MiniDragging = false
local MiniDragStart
local MiniStartPosition

MiniButton.InputBegan:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1
        or Input.UserInputType == Enum.UserInputType.Touch then

        MiniDragging = true
        MiniDragStart = Input.Position
        MiniStartPosition = MiniButton.Position

        Input.Changed:Connect(function()
            if Input.UserInputState == Enum.UserInputState.End then
                MiniDragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(Input)
    if MiniDragging and (
        Input.UserInputType == Enum.UserInputType.MouseMovement
        or Input.UserInputType == Enum.UserInputType.Touch
    ) then

        local Delta = Input.Position - MiniDragStart

        MiniButton.Position = UDim2.new(
            MiniStartPosition.X.Scale,
            MiniStartPosition.X.Offset + Delta.X,
            MiniStartPosition.Y.Scale,
            MiniStartPosition.Y.Offset + Delta.Y
        )
    end
end)

UserInputService.InputBegan:Connect(function(Input, GameProcessed)
    if GameProcessed then return end

    if Input.KeyCode == Enum.KeyCode.R and Flying then
        EmergencyReset()

    elseif Input.KeyCode == Enum.KeyCode.T then
        TeleportToMouse()
    end
end)

Player.CharacterAdded:Connect(function()
    if Flying then
        StopFly()
    end

    task.wait()

    UpdateCharacter()
end)

UpdateCharacter()

SetStatus("Pronto - Bypass Ativo!")
