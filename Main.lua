local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer

local FlySpeed = 80
local ArrivalDistance = 2
local SlowDistance = 35
local Acceleration = 7
local Deceleration = 9
local ClickMaxTime = 0.25
local DragDistance = 8

local Character
local Humanoid
local RootPart

local Flying = false
local FlyConnection = nil
local SavedPosition = nil
local CurrentFlySpeed = 0
local OriginalCollisions = {}

local function UpdateCharacter()
    Character = Player.Character or Player.CharacterAdded:Wait()
    Humanoid = Character:WaitForChild("Humanoid")
    RootPart = Character:WaitForChild("HumanoidRootPart")
end

UpdateCharacter()

Player.CharacterAdded:Connect(function()
    Flying = false

    if FlyConnection then
        FlyConnection:Disconnect()
        FlyConnection = nil
    end

    OriginalCollisions = {}
    CurrentFlySpeed = 0

    task.wait(0.5)
    UpdateCharacter()
end)

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
MainStroke.Color = Color3.fromRGB(55, 58, 68)
MainStroke.Transparency = 0.3
MainStroke.Thickness = 1
MainStroke.Parent = Main

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 45)
Header.BackgroundTransparency = 1
Header.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -85, 0, 25)
Title.Position = UDim2.new(0, 15, 0, 7)
Title.BackgroundTransparency = 1
Title.Text = "menu portal gun"
Title.TextColor3 = Color3.fromRGB(245, 245, 250)
Title.TextSize = 17
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -85, 0, 15)
Status.Position = UDim2.new(0, 15, 0, 28)
Status.BackgroundTransparency = 1
Status.Text = "Pronto"
Status.TextColor3 = Color3.fromRGB(140, 145, 155)
Status.TextSize = 10
Status.Font = Enum.Font.Gotham
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Parent = Header

local function HeaderButton(Text, Position)
    local Button = Instance.new("TextButton")

    Button.Size = UDim2.new(0, 27, 0, 27)
    Button.Position = Position
    Button.BackgroundColor3 = Color3.fromRGB(32, 35, 42)
    Button.BorderSizePixel = 0
    Button.Text = Text
    Button.TextColor3 = Color3.fromRGB(220, 220, 225)
    Button.TextSize = 13
    Button.Font = Enum.Font.GothamBold
    Button.AutoButtonColor = true
    Button.Parent = Header

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 7)
    Corner.Parent = Button

    return Button
end

local MinimizeButton = HeaderButton(
    "−",
    UDim2.new(1, -65, 0, 9)
)

local CloseButton = HeaderButton(
    "×",
    UDim2.new(1, -34, 0, 9)
)

CloseButton.TextColor3 = Color3.fromRGB(255, 130, 135)

local CoordinateBox = Instance.new("TextBox")
CoordinateBox.Size = UDim2.new(1, -30, 0, 40)
CoordinateBox.Position = UDim2.new(0, 15, 0, 50)
CoordinateBox.BackgroundColor3 = Color3.fromRGB(30, 33, 40)
CoordinateBox.BorderSizePixel = 0
CoordinateBox.Text = ""
CoordinateBox.PlaceholderText = "X, Y, Z   ex: 728, 37, -13"
CoordinateBox.PlaceholderColor3 = Color3.fromRGB(105, 110, 120)
CoordinateBox.TextColor3 = Color3.fromRGB(240, 240, 245)
CoordinateBox.TextSize = 12
CoordinateBox.Font = Enum.Font.GothamMedium
CoordinateBox.ClearTextOnFocus = false
CoordinateBox.TextXAlignment = Enum.TextXAlignment.Left
CoordinateBox.Parent = Main

local CoordinatePadding = Instance.new("UIPadding")
CoordinatePadding.PaddingLeft = UDim.new(0, 12)
CoordinatePadding.Parent = CoordinateBox

local CoordinateCorner = Instance.new("UICorner")
CoordinateCorner.CornerRadius = UDim.new(0, 8)
CoordinateCorner.Parent = CoordinateBox

local SpeedBox = Instance.new("TextBox")
SpeedBox.Size = UDim2.new(1, -30, 0, 32)
SpeedBox.Position = UDim2.new(0, 15, 0, 95)
SpeedBox.BackgroundColor3 = Color3.fromRGB(30, 33, 40)
SpeedBox.BorderSizePixel = 0
SpeedBox.Text = "80"
SpeedBox.PlaceholderText = "Velocidade"
SpeedBox.PlaceholderColor3 = Color3.fromRGB(105, 110, 120)
SpeedBox.TextColor3 = Color3.fromRGB(235, 235, 240)
SpeedBox.TextSize = 12
SpeedBox.Font = Enum.Font.GothamMedium
SpeedBox.ClearTextOnFocus = false
SpeedBox.TextXAlignment = Enum.TextXAlignment.Left
SpeedBox.Parent = Main

local SpeedPadding = Instance.new("UIPadding")
SpeedPadding.PaddingLeft = UDim.new(0, 12)
SpeedPadding.Parent = SpeedBox

local SpeedCorner = Instance.new("UICorner")
SpeedCorner.CornerRadius = UDim.new(0, 8)
SpeedCorner.Parent = SpeedBox

SpeedBox.FocusLost:Connect(function()
    local Value = tonumber(SpeedBox.Text)

    if Value and Value > 0 then
        FlySpeed = Value
        SpeedBox.Text = tostring(FlySpeed)
    else
        SpeedBox.Text = tostring(FlySpeed)
    end
end)

local function CreateButton(Text, Position, Size, Color)
    local Button = Instance.new("TextButton")

    Button.Size = Size
    Button.Position = Position
    Button.BackgroundColor3 = Color
    Button.BorderSizePixel = 0
    Button.Text = Text
    Button.TextColor3 = Color3.fromRGB(245, 245, 250)
    Button.TextSize = 12
    Button.Font = Enum.Font.GothamBold
    Button.AutoButtonColor = true
    Button.Parent = Main

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Button

    return Button
end

local FlyButton = CreateButton(
    "VOAR",
    UDim2.new(0, 15, 0, 138),
    UDim2.new(0.5, -8, 0, 35),
    Color3.fromRGB(55, 105, 205)
)

local TPButton = CreateButton(
    "TELEPORTAR",
    UDim2.new(0.5, 1, 0, 138),
    UDim2.new(0.5, -16, 0, 35),
    Color3.fromRGB(75, 78, 92)
)

local StopButton = CreateButton(
    "PARAR",
    UDim2.new(0, 15, 0, 182),
    UDim2.new(0.5, -8, 0, 30),
    Color3.fromRGB(145, 55, 60)
)

local SaveButton = CreateButton(
    "SALVAR",
    UDim2.new(0.5, 1, 0, 182),
    UDim2.new(0.5, -16, 0, 30),
    Color3.fromRGB(55, 125, 80)
)

local Confirm = Instance.new("Frame")
Confirm.Name = "Confirm"
Confirm.Size = UDim2.new(0, 220, 0, 125)
Confirm.Position = UDim2.new(0.5, -110, 0.5, -62)
Confirm.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
Confirm.BorderSizePixel = 0
Confirm.Visible = false
Confirm.ZIndex = 20
Confirm.Parent = ScreenGui

local ConfirmCorner = Instance.new("UICorner")
ConfirmCorner.CornerRadius = UDim.new(0, 11)
ConfirmCorner.Parent = Confirm

local ConfirmStroke = Instance.new("UIStroke")
ConfirmStroke.Color = Color3.fromRGB(65, 68, 78)
ConfirmStroke.Thickness = 1
ConfirmStroke.Parent = Confirm

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

local YesCorner = Instance.new("UICorner")
YesCorner.CornerRadius = UDim.new(0, 7)
YesCorner.Parent = YesButton

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

local NoCorner = Instance.new("UICorner")
NoCorner.CornerRadius = UDim.new(0, 7)
NoCorner.Parent = NoButton

local Mini = Instance.new("TextButton")
Mini.Name = "Mini"
Mini.Size = UDim2.new(0, 52, 0, 52)
Mini.Position = UDim2.new(0, 20, 0.5, -26)
Mini.BackgroundColor3 = Color3.fromRGB(55, 105, 205)
Mini.BorderSizePixel = 0
Mini.Text = "F"
Mini.TextColor3 = Color3.fromRGB(255, 255, 255)
Mini.TextSize = 20
Mini.Font = Enum.Font.GothamBold
Mini.Visible = false
Mini.AutoButtonColor = false
Mini.Parent = ScreenGui

local MiniCorner = Instance.new("UICorner")
MiniCorner.CornerRadius = UDim.new(1, 0)
MiniCorner.Parent = Mini

local MiniStroke = Instance.new("UIStroke")
MiniStroke.Color = Color3.fromRGB(100, 145, 235)
MiniStroke.Thickness = 2
MiniStroke.Parent = Mini

local function GetCoordinates()
    local Text = CoordinateBox.Text
    Text = Text:gsub(",", " ")

    local Numbers = {}

    for Number in Text:gmatch("-?%d+%.?%d*") do
        table.insert(Numbers, tonumber(Number))
    end

    if #Numbers < 3 then
        return nil
    end

    return Vector3.new(
        Numbers[1],
        Numbers[2],
        Numbers[3]
    )
end

local function SetStatus(Text)
    Status.Text = Text
end

local function EnableNoclip()
    if not Character then
        return
    end

    OriginalCollisions = {}

    for _, Object in ipairs(Character:GetDescendants()) do
        if Object:IsA("BasePart") then
            OriginalCollisions[Object] = Object.CanCollide
            Object.CanCollide = false
        end
    end
end

local function RestoreCollisions()
    for Object, OriginalValue in pairs(OriginalCollisions) do
        if Object and Object.Parent then
            Object.CanCollide = OriginalValue
        end
    end

    OriginalCollisions = {}
end

local function StopFly()
    Flying = false

    if FlyConnection then
        FlyConnection:Disconnect()
        FlyConnection = nil
    end

    RestoreCollisions()

    CurrentFlySpeed = 0

    if Humanoid then
        Humanoid.PlatformStand = false
        Humanoid.AutoRotate = true
    end

    if RootPart then
        RootPart.AssemblyLinearVelocity = Vector3.zero
        RootPart.AssemblyAngularVelocity = Vector3.zero
    end

    FlyButton.Text = "VOAR"
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

    EnableNoclip()

    Humanoid.PlatformStand = true
    Humanoid.AutoRotate = false

    FlyButton.Text = "VOANDO"
    SetStatus("Voando até o destino...")

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
            CurrentFlySpeed =
                CurrentFlySpeed +
                (FlySpeed - CurrentFlySpeed) *
                math.clamp(
                    DeltaTime * Acceleration,
                    0,
                    1
                )
        else
            local SlowFactor =
                math.clamp(
                    Distance / SlowDistance,
                    0.08,
                    1
                )

            local TargetSpeed =
                FlySpeed * SlowFactor

            CurrentFlySpeed =
                CurrentFlySpeed +
                (TargetSpeed - CurrentFlySpeed) *
                math.clamp(
                    DeltaTime * Deceleration,
                    0,
                    1
                )
        end

        RootPart.AssemblyLinearVelocity =
            Direction * CurrentFlySpeed

        RootPart.CFrame =
            CFrame.lookAt(
                CurrentPosition,
                CurrentPosition + Direction,
                Vector3.yAxis
            )
    end)
end

FlyButton.MouseButton1Click:Connect(function()
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

    UpdateCharacter()

    if Flying then
        StopFly()
    end

    RootPart.CFrame = CFrame.new(Target)

    SetStatus("Teleportado")

    task.delay(1.5, function()
        if not Flying then
            SetStatus("Pronto")
        end
    end)
end)

StopButton.MouseButton1Click:Connect(function()
    if Flying then
        StopFly()
    else
        SetStatus("Nenhum voo ativo")
    end
end)

SaveButton.MouseButton1Click:Connect(function()
    UpdateCharacter()

    if not RootPart then
        return
    end

    SavedPosition = RootPart.CFrame

    CoordinateBox.Text = string.format(
        "%.2f, %.2f, %.2f",
        RootPart.Position.X,
        RootPart.Position.Y,
        RootPart.Position.Z
    )

    SetStatus("Posição salva")

    task.delay(1.5, function()
        if not Flying then
            SetStatus("Pronto")
        end
    end)
end)

local function ConnectClickOnly(Object, Callback)
    local Pressed = false
    local StartTime = 0
    local StartPosition = nil
    local Moved = false
    local MoveConnection = nil

    Object.InputBegan:Connect(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1
            and Input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        Pressed = true
        Moved = false
        StartTime = os.clock()
        StartPosition = Input.Position

        if MoveConnection then
            MoveConnection:Disconnect()
        end

        MoveConnection =
            UserInputService.InputChanged:Connect(function(Change)
                if not Pressed then
                    return
                end

                if Change.UserInputType == Enum.UserInputType.MouseMovement
                    or Change.UserInputType == Enum.UserInputType.Touch then

                    if StartPosition then
                        local Distance =
                            (Change.Position - StartPosition).Magnitude

                        if Distance >= DragDistance then
                            Moved = true
                        end
                    end
                end
            end)
    end)

    Object.InputEnded:Connect(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1
            and Input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        if not Pressed then
            return
        end

        Pressed = false

        local HoldTime =
            os.clock() - StartTime

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
    StopFly()
    ScreenGui:Destroy()
end)

local MiniDragging = false
local MiniMoved = false
local MiniStartPosition
local MiniStartInputPosition
local MiniStartTime

Mini.InputBegan:Connect(function(Input)
    if Input.UserInputType ~= Enum.UserInputType.MouseButton1
        and Input.UserInputType ~= Enum.UserInputType.Touch then
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

    if Input.UserInputType ~= Enum.UserInputType.MouseMovement
        and Input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local Delta =
        Input.Position -
        MiniStartInputPosition

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
    if Input.UserInputType ~= Enum.UserInputType.MouseButton1
        and Input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    if not MiniDragging then
        return
    end

    MiniDragging = false

    local HoldTime =
        os.clock() - MiniStartTime

    if HoldTime <= ClickMaxTime and not MiniMoved then
        Main.Visible = true
        Mini.Visible = false
    end
end)

local MainDragging = false
local MainStartPosition
local MainStartInputPosition

Header.InputBegan:Connect(function(Input)
    if Input.UserInputType ~= Enum.UserInputType.MouseButton1
        and Input.UserInputType ~= Enum.UserInputType.Touch then
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

    if Input.UserInputType ~= Enum.UserInputType.MouseMovement
        and Input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local Delta =
        Input.Position -
        MainStartInputPosition

    Main.Position = UDim2.new(
        MainStartPosition.X.Scale,
        MainStartPosition.X.Offset + Delta.X,
        MainStartPosition.Y.Scale,
        MainStartPosition.Y.Offset + Delta.Y
    )
end)

UserInputService.InputEnded:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1
        or Input.UserInputType == Enum.UserInputType.Touch then

        MainDragging = false
    end
end)

SetStatus("Pronto")
