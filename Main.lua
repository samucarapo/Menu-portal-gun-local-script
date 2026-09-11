local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer

local FlySpeed = 80
local ArrivalDistance = 2
local SlowDistance = 35
local Acceleration = 15
local Deceleration = 12
local ClickMaxTime = 0.25
local DragDistance = 8

local Character
local Humanoid
local RootPart

local Flying = false
local FlyTween = nil
local SavedPosition = nil
local CurrentFlySpeed = 0
local OriginalCollisions = {}
local LastValidPosition = nil
local CurrentTweenTarget = nil
local Closing = false

local ScreenGui
local Main
local Header
local Status
local CoordinateBox
local SpeedBox
local FlyButton
local TPButton
local StopButton
local SaveButton
local Confirm
local Mini

local function SetStatus(Text)
    if Status then
        Status.Text = Text
    end
end

local function UpdateCharacter()
    Character = Player.Character or Player.CharacterAdded:Wait()
    Humanoid = Character:FindFirstChildOfClass("Humanoid") or Character:WaitForChild("Humanoid")
    RootPart = Character:FindFirstChild("HumanoidRootPart") or Character:WaitForChild("HumanoidRootPart")
end

UpdateCharacter()

local function StopFly(KeepStatus)
    Flying = false
    CurrentTweenTarget = nil

    if FlyTween then
        FlyTween:Cancel()
        FlyTween = nil
    end

    CurrentFlySpeed = 0

    if RootPart and RootPart.Parent then
        RootPart.AssemblyLinearVelocity = Vector3.zero
        RootPart.AssemblyAngularVelocity = Vector3.zero
    end

    if Humanoid and Humanoid.Parent then
        Humanoid.PlatformStand = false
        Humanoid.AutoRotate = true
        Humanoid.WalkSpeed = 16
        Humanoid.JumpPower = 50
    end

    for Part, OriginalValue in pairs(OriginalCollisions) do
        if Part and Part.Parent then
            Part.CanCollide = OriginalValue
        end
    end

    OriginalCollisions = {}

    if FlyButton then
        FlyButton.Text = "VOAR"
    end

    if not KeepStatus then
        SetStatus("Pronto")
    end
end

Player.CharacterAdded:Connect(function(NewCharacter)
    if Closing then
        return
    end

    StopFly(true)
    Character = NewCharacter
    Humanoid = nil
    RootPart = nil

    task.wait(0.5)
    if Character and Character.Parent then
        UpdateCharacter()
    end
end)

local function EnableNoclip()
    if not Character then
        return
    end

    OriginalCollisions = {}

    for _, Part in ipairs(Character:GetDescendants()) do
        if Part:IsA("BasePart") then
            OriginalCollisions[Part] = Part.CanCollide
            Part.CanCollide = false
        end
    end
end

local function RestoreCollisions()
    for Part, OriginalValue in pairs(OriginalCollisions) do
        if Part and Part.Parent then
            Part.CanCollide = OriginalValue
        end
    end

    OriginalCollisions = {}
end

local function GetCoordinates()
    local Text = CoordinateBox.Text:gsub(",", " ")
    local Numbers = {}

    for Number in Text:gmatch("-?%d+%.?%d*") do
        Numbers[#Numbers + 1] = tonumber(Number)
    end

    if #Numbers < 3 then
        return nil
    end

    return Vector3.new(Numbers[1], Numbers[2], Numbers[3])
end

local function FormatVector(Position)
    return string.format("%.2f, %.2f, %.2f", Position.X, Position.Y, Position.Z)
end

local function GetFlyDuration(Distance, Speed)
    if Speed <= 0 then
        return 0.1
    end

    return math.max(Distance / Speed, 0.05)
end

local function FlyTo(Target)
    UpdateCharacter()

    if not RootPart or not Humanoid or Humanoid.Health <= 0 then
        SetStatus("Personagem indisponível")
        return
    end

    if Flying then
        StopFly(true)
    end

    local StartPosition = RootPart.Position
    local Distance = (Target - StartPosition).Magnitude

    if Distance <= ArrivalDistance then
        RootPart.CFrame = CFrame.new(Target)
        SetStatus("Destino alcançado")
        return
    end

    Flying = true
    CurrentFlySpeed = 0
    LastValidPosition = StartPosition
    CurrentTweenTarget = Target

    EnableNoclip()

    Humanoid.PlatformStand = false
    Humanoid.AutoRotate = false

    if FlyButton then
        FlyButton.Text = "PARAR VOO"
    end

    SetStatus("Voando...")

    local Direction = (Target - StartPosition).Unit
    local LookCFrame = CFrame.lookAt(Target, Target + Direction, Vector3.yAxis)
    local Duration = GetFlyDuration(Distance, FlySpeed)

    if Distance <= SlowDistance then
        local SlowFactor = math.clamp(Distance / SlowDistance, 0.18, 1)
        Duration = Duration / SlowFactor
    end

    FlyTween = TweenService:Create(
        RootPart,
        TweenInfo.new(Duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        {CFrame = LookCFrame}
    )

    local ThisTween = FlyTween

    FlyTween.Completed:Connect(function(State)
        if ThisTween ~= FlyTween or not Flying then
            return
        end

        FlyTween = nil
        CurrentTweenTarget = nil
        LastValidPosition = Target

        if State == Enum.PlaybackState.Completed then
            RootPart.CFrame = LookCFrame
            StopFly(true)
            SetStatus("Destino alcançado")
        else
            StopFly(true)
            SetStatus("Voo interrompido")
        end

        task.delay(1.5, function()
            if not Flying and not Closing then
                SetStatus("Pronto")
            end
        end)
    end)

    FlyTween:Play()
end

local function SmoothTeleport(TargetPosition)
    UpdateCharacter()

    if not RootPart or not Humanoid or Humanoid.Health <= 0 then
        SetStatus("Personagem indisponível")
        return
    end

    if Flying then
        StopFly(true)
    end

    local StartPosition = RootPart.Position
    local Distance = (TargetPosition - StartPosition).Magnitude

    if Distance <= 5 then
        RootPart.CFrame = CFrame.new(TargetPosition)
        RootPart.AssemblyLinearVelocity = Vector3.zero
        SetStatus("Teleportado")
        return
    end

    EnableNoclip()

    local Duration = math.clamp(Distance / 350, 0.12, 0.65)
    local Direction = (TargetPosition - StartPosition).Unit
    local TargetCFrame = CFrame.lookAt(TargetPosition, TargetPosition + Direction, Vector3.yAxis)

    SetStatus("Teleportando...")

    local Tween = TweenService:Create(
        RootPart,
        TweenInfo.new(Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {CFrame = TargetCFrame}
    )

    Tween.Completed:Connect(function()
        if RootPart and RootPart.Parent then
            RootPart.CFrame = TargetCFrame
            RootPart.AssemblyLinearVelocity = Vector3.zero
            RootPart.AssemblyAngularVelocity = Vector3.zero
        end

        RestoreCollisions()
        SetStatus("Teleportado")

        task.delay(1.5, function()
            if not Flying and not Closing then
                SetStatus("Pronto")
            end
        end)
    end)

    Tween:Play()
end

local function TeleportWithBypass(TargetPosition)
    SmoothTeleport(TargetPosition)
end

local function TeleportToMouse()
    local Mouse = Player:GetMouse()
    local Target = Mouse.Hit and Mouse.Hit.Position

    if Target then
        TeleportWithBypass(Target)
    else
        SetStatus("Nenhum alvo encontrado")
    end
end

local function EmergencyReset()
    if not Flying or not RootPart or not LastValidPosition then
        SetStatus("Nenhum voo ativo")
        return
    end

    StopFly(true)
    RootPart.CFrame = CFrame.new(LastValidPosition)
    RootPart.AssemblyLinearVelocity = Vector3.zero
    SetStatus("Voo resetado")
end

local function CreateCorner(Object, Radius)
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, Radius)
    Corner.Parent = Object
    return Corner
end

local function CreateStroke(Object, Transparency, Thickness)
    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(70, 74, 88)
    Stroke.Transparency = Transparency or 0.35
    Stroke.Thickness = Thickness or 1
    Stroke.Parent = Object
    return Stroke
end

ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FlyTP"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 285, 0, 280)
Main.Position = UDim2.new(0.5, -142, 0.5, -140)
Main.BackgroundColor3 = Color3.fromRGB(18, 20, 25)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui
CreateCorner(Main, 13)
CreateStroke(Main, 0.25, 1)

local MainPadding = Instance.new("UIPadding")
MainPadding.PaddingTop = UDim.new(0, 8)
MainPadding.PaddingBottom = UDim.new(0, 10)
MainPadding.PaddingLeft = UDim.new(0, 12)
MainPadding.PaddingRight = UDim.new(0, 12)
MainPadding.Parent = Main

Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 43)
Header.BackgroundTransparency = 1
Header.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -75, 0, 23)
Title.Position = UDim2.new(0, 2, 0, 2)
Title.BackgroundTransparency = 1
Title.Text = "Portal Gun"
Title.TextColor3 = Color3.fromRGB(245, 245, 250)
Title.TextSize = 17
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -75, 0, 15)
Status.Position = UDim2.new(0, 2, 0, 25)
Status.BackgroundTransparency = 1
Status.Text = "Pronto"
Status.TextColor3 = Color3.fromRGB(145, 150, 162)
Status.TextSize = 10
Status.Font = Enum.Font.Gotham
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Parent = Header

local function HeaderButton(Text, Position)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(0, 28, 0, 28)
    Button.Position = Position
    Button.BackgroundColor3 = Color3.fromRGB(31, 34, 41)
    Button.BorderSizePixel = 0
    Button.Text = Text
    Button.TextColor3 = Color3.fromRGB(225, 226, 232)
    Button.TextSize = 14
    Button.Font = Enum.Font.GothamBold
    Button.AutoButtonColor = true
    Button.Parent = Header
    CreateCorner(Button, 8)
    return Button
end

local MinimizeButton = HeaderButton("−", UDim2.new(1, -61, 0, 5))
local CloseButton = HeaderButton("×", UDim2.new(1, -28, 0, 5))
CloseButton.TextColor3 = Color3.fromRGB(255, 135, 140)

local function CreateLabel(Text, Position)
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 0, 14)
    Label.Position = Position
    Label.BackgroundTransparency = 1
    Label.Text = Text
    Label.TextColor3 = Color3.fromRGB(155, 159, 170)
    Label.TextSize = 9
    Label.Font = Enum.Font.GothamMedium
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Main
    return Label
end

CreateLabel("COORDENADAS", UDim2.new(0, 0, 0, 49))

CoordinateBox = Instance.new("TextBox")
CoordinateBox.Size = UDim2.new(1, 0, 0, 38)
CoordinateBox.Position = UDim2.new(0, 0, 0, 64)
CoordinateBox.BackgroundColor3 = Color3.fromRGB(28, 31, 38)
CoordinateBox.BorderSizePixel = 0
CoordinateBox.Text = ""
CoordinateBox.PlaceholderText = "X, Y, Z   ex: 728, 37, -13"
CoordinateBox.PlaceholderColor3 = Color3.fromRGB(100, 105, 116)
CoordinateBox.TextColor3 = Color3.fromRGB(240, 241, 245)
CoordinateBox.TextSize = 11
CoordinateBox.Font = Enum.Font.GothamMedium
CoordinateBox.ClearTextOnFocus = false
CoordinateBox.TextXAlignment = Enum.TextXAlignment.Left
CoordinateBox.Parent = Main
CreateCorner(CoordinateBox, 8)

local CoordinatePadding = Instance.new("UIPadding")
CoordinatePadding.PaddingLeft = UDim.new(0, 11)
CoordinatePadding.PaddingRight = UDim.new(0, 8)
CoordinatePadding.Parent = CoordinateBox

CreateLabel("VELOCIDADE", UDim2.new(0, 0, 0, 108))

SpeedBox = Instance.new("TextBox")
SpeedBox.Size = UDim2.new(1, 0, 0, 32)
SpeedBox.Position = UDim2.new(0, 0, 0, 123)
SpeedBox.BackgroundColor3 = Color3.fromRGB(28, 31, 38)
SpeedBox.BorderSizePixel = 0
SpeedBox.Text = tostring(FlySpeed)
SpeedBox.PlaceholderText = "80"
SpeedBox.PlaceholderColor3 = Color3.fromRGB(100, 105, 116)
SpeedBox.TextColor3 = Color3.fromRGB(240, 241, 245)
SpeedBox.TextSize = 11
SpeedBox.Font = Enum.Font.GothamMedium
SpeedBox.ClearTextOnFocus = false
SpeedBox.TextXAlignment = Enum.TextXAlignment.Left
SpeedBox.Parent = Main
CreateCorner(SpeedBox, 8)

local SpeedPadding = Instance.new("UIPadding")
SpeedPadding.PaddingLeft = UDim.new(0, 11)
SpeedPadding.Parent = SpeedBox

SpeedBox.FocusLost:Connect(function()
    local Value = tonumber(SpeedBox.Text)

    if Value and Value > 0 then
        FlySpeed = math.clamp(Value, 1, 1000)
        SpeedBox.Text = tostring(FlySpeed)
    else
        SpeedBox.Text = tostring(FlySpeed)
    end
end)

local function CreateButton(Text, Position, Size, Background)
    local Button = Instance.new("TextButton")
    Button.Size = Size
    Button.Position = Position
    Button.BackgroundColor3 = Background
    Button.BorderSizePixel = 0
    Button.Text = Text
    Button.TextColor3 = Color3.fromRGB(245, 245, 250)
    Button.TextSize = 11
    Button.Font = Enum.Font.GothamBold
    Button.AutoButtonColor = true
    Button.Parent = Main
    CreateCorner(Button, 8)
    return Button
end

FlyButton = CreateButton(
    "VOAR",
    UDim2.new(0, 0, 0, 165),
    UDim2.new(0.5, -5, 0, 35),
    Color3.fromRGB(58, 108, 210)
)

TPButton = CreateButton(
    "TELEPORTAR",
    UDim2.new(0.5, 5, 0, 165),
    UDim2.new(0.5, -5, 0, 35),
    Color3.fromRGB(68, 72, 86)
)

StopButton = CreateButton(
    "PARAR",
    UDim2.new(0, 0, 0, 207),
    UDim2.new(0.5, -5, 0, 32),
    Color3.fromRGB(145, 55, 62)
)

SaveButton = CreateButton(
    "SALVAR POSIÇÃO",
    UDim2.new(0.5, 5, 0, 207),
    UDim2.new(0.5, -5, 0, 32),
    Color3.fromRGB(55, 122, 80)
)

local Hint = Instance.new("TextLabel")
Hint.Size = UDim2.new(1, 0, 0, 22)
Hint.Position = UDim2.new(0, 0, 0, 248)
Hint.BackgroundTransparency = 1
Hint.Text = "T = teleportar para o mouse   •   R = resetar voo"
Hint.TextColor3 = Color3.fromRGB(100, 105, 116)
Hint.TextSize = 8
Hint.Font = Enum.Font.Gotham
Hint.TextXAlignment = Enum.TextXAlignment.Center
Hint.Parent = Main

Confirm = Instance.new("Frame")
Confirm.Name = "Confirm"
Confirm.Size = UDim2.new(0, 225, 0, 125)
Confirm.Position = UDim2.new(0.5, -112, 0.5, -62)
Confirm.BackgroundColor3 = Color3.fromRGB(23, 25, 31)
Confirm.BorderSizePixel = 0
Confirm.Visible = false
Confirm.ZIndex = 20
Confirm.Parent = ScreenGui
CreateCorner(Confirm, 11)
CreateStroke(Confirm, 0.25, 1)

local ConfirmTitle = Instance.new("TextLabel")
ConfirmTitle.Size = UDim2.new(1, -20, 0, 25)
ConfirmTitle.Position = UDim2.new(0, 10, 0, 12)
ConfirmTitle.BackgroundTransparency = 1
ConfirmTitle.Text = "Fechar interface?"
ConfirmTitle.TextColor3 = Color3.fromRGB(245, 245, 250)
ConfirmTitle.TextSize = 15
ConfirmTitle.Font = Enum.Font.GothamBold
ConfirmTitle.ZIndex = 21
ConfirmTitle.Parent = Confirm

local ConfirmText = Instance.new("TextLabel")
ConfirmText.Size = UDim2.new(1, -20, 0, 25)
ConfirmText.Position = UDim2.new(0, 10, 0, 38)
ConfirmText.BackgroundTransparency = 1
ConfirmText.Text = "Deseja realmente fechar?"
ConfirmText.TextColor3 = Color3.fromRGB(145, 150, 160)
ConfirmText.TextSize = 11
ConfirmText.Font = Enum.Font.Gotham
ConfirmText.ZIndex = 21
ConfirmText.Parent = Confirm

local YesButton = Instance.new("TextButton")
YesButton.Size = UDim2.new(0.42, 0, 0, 32)
YesButton.Position = UDim2.new(0.06, 0, 1, -42)
YesButton.BackgroundColor3 = Color3.fromRGB(145, 55, 60)
YesButton.Text = "SIM"
YesButton.TextColor3 = Color3.fromRGB(255, 240, 240)
YesButton.TextSize = 11
YesButton.Font = Enum.Font.GothamBold
YesButton.BorderSizePixel = 0
YesButton.ZIndex = 21
YesButton.Parent = Confirm
CreateCorner(YesButton, 7)

local NoButton = Instance.new("TextButton")
NoButton.Size = UDim2.new(0.42, 0, 0, 32)
NoButton.Position = UDim2.new(0.52, 0, 1, -42)
NoButton.BackgroundColor3 = Color3.fromRGB(55, 58, 68)
NoButton.Text = "NÃO"
NoButton.TextColor3 = Color3.fromRGB(235, 235, 240)
NoButton.TextSize = 11
NoButton.Font = Enum.Font.GothamBold
NoButton.BorderSizePixel = 0
NoButton.ZIndex = 21
NoButton.Parent = Confirm
CreateCorner(NoButton, 7)

Mini = Instance.new("TextButton")
Mini.Name = "Mini"
Mini.Size = UDim2.new(0, 52, 0, 52)
Mini.Position = UDim2.new(0, 20, 0.5, -26)
Mini.BackgroundColor3 = Color3.fromRGB(58, 108, 210)
Mini.BorderSizePixel = 0
Mini.Text = "F"
Mini.TextColor3 = Color3.fromRGB(255, 255, 255)
Mini.TextSize = 20
Mini.Font = Enum.Font.GothamBold
Mini.Visible = false
Mini.AutoButtonColor = false
Mini.Parent = ScreenGui
CreateCorner(Mini, 26)
local MiniStroke = CreateStroke(Mini, 0.05, 2)
MiniStroke.Color = Color3.fromRGB(105, 150, 240)

local function ConnectClickOnly(Object, Callback)
    local Pressed = false
    local StartTime = 0
    local StartPosition
    local Moved = false
    local MoveConnection

    Object.InputBegan:Connect(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        Pressed = true
        Moved = false
        StartTime = os.clock()
        StartPosition = Input.Position

        if MoveConnection then
            MoveConnection:Disconnect()
        end

        MoveConnection = UserInputService.InputChanged:Connect(function(Change)
            if not Pressed then
                return
            end

            if Change.UserInputType == Enum.UserInputType.MouseMovement or Change.UserInputType == Enum.UserInputType.Touch then
                if StartPosition and (Change.Position - StartPosition).Magnitude >= DragDistance then
                    Moved = true
                end
            end
        end)
    end)

    Object.InputEnded:Connect(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        if not Pressed then
            return
        end

        Pressed = false
        local HoldTime = os.clock() - StartTime

        if MoveConnection then
            MoveConnection:Disconnect()
            MoveConnection = nil
        end

        if HoldTime <= ClickMaxTime and not Moved then
            Callback()
        end
    end)
end

ConnectClickOnly(MinimizeButton, function()
    Main.Visible = false
    Confirm.Visible = false
    Mini.Visible = true
end)

ConnectClickOnly(CloseButton, function()
    Confirm.Visible = true
end)

NoButton.MouseButton1Click:Connect(function()
    Confirm.Visible = false
end)

YesButton.MouseButton1Click:Connect(function()
    Closing = true
    StopFly(true)
    RestoreCollisions()
    ScreenGui:Destroy()
end)

FlyButton.MouseButton1Click:Connect(function()
    if Flying then
        StopFly()
        return
    end

    local Target = GetCoordinates()
    if not Target then
        SetStatus("Coordenadas inválidas")
        return
    end

    FlyTo(Target)
end)

TPButton.MouseButton1Click:Connect(function()
    local Target = GetCoordinates()
    if not Target then
        SetStatus("Coordenadas inválidas")
        return
    end

    TeleportWithBypass(Target)
end)

StopButton.MouseButton1Click:Connect(function()
    if Flying then
        StopFly()
    else
        SetStatus("Nada para parar")
    end
end)

SaveButton.MouseButton1Click:Connect(function()
    UpdateCharacter()

    if not RootPart then
        SetStatus("Personagem indisponível")
        return
    end

    SavedPosition = RootPart.CFrame
    CoordinateBox.Text = FormatVector(RootPart.Position)
    SetStatus("Posição salva")

    task.delay(1.5, function()
        if not Flying and not Closing then
            SetStatus("Pronto")
        end
    end)
end)

local MiniDragging = false
local MiniMoved = false
local MiniStartPosition
local MiniStartInputPosition
local MiniStartTime

Mini.InputBegan:Connect(function(Input)
    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    MiniDragging = true
    MiniMoved = false
    MiniStartTime = os.clock()
    MiniStartInputPosition = Input.Position
    MiniStartPosition = Mini.Position
end)

UserInputService.InputChanged:Connect(function(Input)
    if not MiniDragging then
        return
    end

    if Input.UserInputType ~= Enum.UserInputType.MouseMovement and Input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local Delta = Input.Position - MiniStartInputPosition

    if Delta.Magnitude >= DragDistance then
        MiniMoved = true
    end

    Mini.Position = UDim2.new(
        MiniStartPosition.X.Scale,
        MiniStartPosition.X.Offset + Delta.X,
        MiniStartPosition.Y.Scale,
        MiniStartPosition.Y.Offset + Delta.Y
    )
end)

Mini.InputEnded:Connect(function(Input)
    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    if not MiniDragging then
        return
    end

    MiniDragging = false
    local HoldTime = os.clock() - MiniStartTime

    if HoldTime <= ClickMaxTime and not MiniMoved then
        Main.Visible = true
        Mini.Visible = false
    end
end)

local MainDragging = false
local MainStartPosition
local MainStartInputPosition

Header.InputBegan:Connect(function(Input)
    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    MainDragging = true
    MainStartInputPosition = Input.Position
    MainStartPosition = Main.Position
end)

UserInputService.InputChanged:Connect(function(Input)
    if not MainDragging then
        return
    end

    if Input.UserInputType ~= Enum.UserInputType.MouseMovement and Input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local Delta = Input.Position - MainStartInputPosition

    Main.Position = UDim2.new(
        MainStartPosition.X.Scale,
        MainStartPosition.X.Offset + Delta.X,
        MainStartPosition.Y.Scale,
        MainStartPosition.Y.Offset + Delta.Y
    )
end)

UserInputService.InputEnded:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
        MainDragging = false
    end
end)

UserInputService.InputBegan:Connect(function(Input, GameProcessed)
    if GameProcessed then
        return
    end

    if Input.KeyCode == Enum.KeyCode.R then
        EmergencyReset()
    elseif Input.KeyCode == Enum.KeyCode.T then
        TeleportToMouse()
    end
end)

SetStatus("Pronto")
