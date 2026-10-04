-- ============================================================
-- BAIT SCANNER + PARALLEL AUTO SCOOP (MINIMAL + MINIMIZE)
-- ============================================================
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local getPlayerDataById = require(RS.TS.state["player-data"]).getPlayerDataById
local gearUseFishFeeder = RS.rbxts_include.node_modules["@rbxts"].remo.src.container["gear.useFishFeeder"]

-- ====== CONFIG ======
local SCOOP_ITEM = "GoldenFoodScoop"
local SCAN_INTERVAL = 3

-- ====== STATE ======
local scanned, queue, active, threads = {}, {}, {}, {}
local sent, failed = 0, 0
local autoScan, query = true, ""
local delay = 0.5
local minimized = false

-- ====== HELPERS ======
local function baitName(b)
    if type(b) == "string" then return b end
    if type(b) ~= "table" then return "?" end
    for _, k in ipairs({"baitType","type","baitId","id","name"}) do
        if type(b[k]) == "string" then return b[k] end
    end
    return "?"
end

local function scan()
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local ok, d = pcall(getPlayerDataById, tostring(p.UserId))
        if ok and d and d.ponds then
            local pond = d.ponds[d.currentPond]
            if pond and pond.baits then
                local list = {}
                for uid, b in pairs(pond.baits) do
                    table.insert(list, {
                        uid = tostring(uid),
                        type = baitName(b),
                        amount = (type(b)=="table" and (b.amount or b.count)) or 1,
                        owner = p.Name,
                        pond = tostring(d.currentPond),
                    })
                end
                out[p.Name] = { pond = tostring(d.currentPond), baits = list }
            end
        end
    end
    return out
end

-- ====== COLORS ======
local C = {
    bg      = Color3.fromRGB(22,24,30),
    panel   = Color3.fromRGB(30,33,41),
    alt     = Color3.fromRGB(42,46,56),
    accent  = Color3.fromRGB(88,166,255),
    text    = Color3.fromRGB(230,232,238),
    dim     = Color3.fromRGB(150,155,165),
    ok      = Color3.fromRGB(80,200,120),
    bad     = Color3.fromRGB(240,90,90),
    sel     = Color3.fromRGB(180,130,240),
}

-- ====== GUI ======
local gui = Instance.new("ScreenGui")
gui.Name = "BaitScanner"
gui.ResetOnSpawn = false
gui.Parent = game:GetService("CoreGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 400, 0, 300)
main.Position = UDim2.new(0.5, -200, 0.5, -150)
main.BackgroundColor3 = C.bg
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

local stroke = Instance.new("UIStroke", main)
stroke.Color = C.accent
stroke.Transparency = 0.5

-- TITLE
local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, -60, 0, 24)
title.Position = UDim2.new(0, 8, 0, 4)
title.BackgroundTransparency = 1
title.Text = "🎣 Bait Scanner"
title.TextColor3 = C.text
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left

local btnMin = Instance.new("TextButton", main)
btnMin.Size = UDim2.new(0, 20, 0, 20)
btnMin.Position = UDim2.new(1, -48, 0, 6)
btnMin.BackgroundColor3 = C.accent
btnMin.Text = "–"
btnMin.TextColor3 = C.text
btnMin.Font = Enum.Font.GothamBold
btnMin.TextSize = 14
Instance.new("UICorner", btnMin).CornerRadius = UDim.new(0, 4)

local close = Instance.new("TextButton", main)
close.Size = UDim2.new(0, 20, 0, 20)
close.Position = UDim2.new(1, -24, 0, 6)
close.BackgroundColor3 = C.bad
close.Text = "✕"
close.TextColor3 = C.text
close.Font = Enum.Font.GothamBold
close.TextSize = 11
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 4)

-- ROW 1: SEARCH + SCAN
local search = Instance.new("TextBox", main)
search.Size = UDim2.new(1, -122, 0, 22)
search.Position = UDim2.new(0, 8, 0, 32)
search.BackgroundColor3 = C.alt
search.BorderSizePixel = 0
search.PlaceholderText = "🔎 Cari..."
search.TextColor3 = C.text
search.PlaceholderColor3 = C.dim
search.Font = Enum.Font.Gotham
search.TextSize = 11
search.TextXAlignment = Enum.TextXAlignment.Left
search.ClearTextOnFocus = false
Instance.new("UICorner", search).CornerRadius = UDim.new(0, 4)
Instance.new("UIPadding", search).PaddingLeft = UDim.new(0, 8)

local btnScan = Instance.new("TextButton", main)
btnScan.Size = UDim2.new(0, 50, 0, 22)
btnScan.Position = UDim2.new(1, -110, 0, 32)
btnScan.BackgroundColor3 = C.accent
btnScan.Text = "🔄 Scan"
btnScan.TextColor3 = C.text
btnScan.Font = Enum.Font.GothamBold
btnScan.TextSize = 10
Instance.new("UICorner", btnScan).CornerRadius = UDim.new(0, 4)

local btnAuto = Instance.new("TextButton", main)
btnAuto.Size = UDim2.new(0, 48, 0, 22)
btnAuto.Position = UDim2.new(1, -56, 0, 32)
btnAuto.BackgroundColor3 = C.ok
btnAuto.Text = "⚡ ON"
btnAuto.TextColor3 = C.text
btnAuto.Font = Enum.Font.GothamBold
btnAuto.TextSize = 10
Instance.new("UICorner", btnAuto).CornerRadius = UDim.new(0, 4)

-- ROW 2: ACTION
local btnStart = Instance.new("TextButton", main)
btnStart.Size = UDim2.new(0, 80, 0, 22)
btnStart.Position = UDim2.new(0, 8, 0, 58)
btnStart.BackgroundColor3 = C.ok
btnStart.Text = "▶ Start"
btnStart.TextColor3 = C.text
btnStart.Font = Enum.Font.GothamBold
btnStart.TextSize = 11
Instance.new("UICorner", btnStart).CornerRadius = UDim.new(0, 4)

local btnStop = Instance.new("TextButton", main)
btnStop.Size = UDim2.new(0, 60, 0, 22)
btnStop.Position = UDim2.new(0, 92, 0, 58)
btnStop.BackgroundColor3 = C.bad
btnStop.Text = "■ Stop"
btnStop.TextColor3 = C.text
btnStop.Font = Enum.Font.GothamBold
btnStop.TextSize = 11
Instance.new("UICorner", btnStop).CornerRadius = UDim.new(0, 4)

local lblDelay = Instance.new("TextLabel", main)
lblDelay.Size = UDim2.new(0, 34, 0, 22)
lblDelay.Position = UDim2.new(0, 156, 0, 58)
lblDelay.BackgroundTransparency = 1
lblDelay.Text = "Delay:"
lblDelay.TextColor3 = C.dim
lblDelay.Font = Enum.Font.GothamBold
lblDelay.TextSize = 10
lblDelay.TextXAlignment = Enum.TextXAlignment.Right

local boxDelay = Instance.new("TextBox", main)
boxDelay.Size = UDim2.new(0, 40, 0, 22)
boxDelay.Position = UDim2.new(0, 192, 0, 58)
boxDelay.BackgroundColor3 = C.alt
boxDelay.BorderSizePixel = 0
boxDelay.Text = "0.5"
boxDelay.TextColor3 = C.text
boxDelay.Font = Enum.Font.Code
boxDelay.TextSize = 11
boxDelay.ClearTextOnFocus = false
Instance.new("UICorner", boxDelay).CornerRadius = UDim.new(0, 4)

local queueLbl = Instance.new("TextLabel", main)
queueLbl.Size = UDim2.new(0, 100, 0, 22)
queueLbl.Position = UDim2.new(0, 236, 0, 58)
queueLbl.BackgroundTransparency = 1
queueLbl.Text = "Q:0 A:0 S:0 F:0"
queueLbl.TextColor3 = C.dim
queueLbl.Font = Enum.Font.Code
queueLbl.TextSize = 10
queueLbl.TextXAlignment = Enum.TextXAlignment.Left

local btnClear = Instance.new("TextButton", main)
btnClear.Size = UDim2.new(0, 40, 0, 22)
btnClear.Position = UDim2.new(1, -48, 0, 58)
btnClear.BackgroundColor3 = C.alt
btnClear.Text = "🧹"
btnClear.TextColor3 = C.text
btnClear.Font = Enum.Font.GothamBold
btnClear.TextSize = 11
Instance.new("UICorner", btnClear).CornerRadius = UDim.new(0, 4)

-- LIST
local list = Instance.new("ScrollingFrame", main)
list.Size = UDim2.new(1, -16, 1, -116)
list.Position = UDim2.new(0, 8, 0, 88)
list.BackgroundColor3 = C.panel
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.ScrollBarImageColor3 = C.accent
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", list).CornerRadius = UDim.new(0, 5)
Instance.new("UIListLayout", list).Padding = UDim.new(0, 2)
Instance.new("UIPadding", list).PaddingTop = UDim.new(0, 4)
Instance.new("UIPadding", list).PaddingBottom = UDim.new(0, 4)
Instance.new("UIPadding", list).PaddingLeft = UDim.new(0, 4)
Instance.new("UIPadding", list).PaddingRight = UDim.new(0, 4)

-- STATUS
local status = Instance.new("TextLabel", main)
status.Size = UDim2.new(1, -16, 0, 16)
status.Position = UDim2.new(0, 8, 1, -20)
status.BackgroundTransparency = 1
status.Text = "Ready."
status.TextColor3 = C.dim
status.Font = Enum.Font.Gotham
status.TextSize = 10
status.TextXAlignment = Enum.TextXAlignment.Left

-- ====== MINIMIZE ======
local fullSize = main.Size
local fullPos = main.Position
local compactSize = UDim2.new(0, 160, 0, 28)

local function setMinimize(state)
    minimized = state
    if minimized then
        fullSize = main.Size
        fullPos = main.Position
        search.Visible = false
        btnScan.Visible = false
        btnAuto.Visible = false
        btnStart.Visible = false
        btnStop.Visible = false
        lblDelay.Visible = false
        boxDelay.Visible = false
        queueLbl.Visible = false
        btnClear.Visible = false
        list.Visible = false
        status.Visible = false
        title.Size = UDim2.new(1, -60, 1, 0)
        title.Position = UDim2.new(0, 8, 0, 0)
        title.Text = "🎣 " .. string.format("Q:%d", (function()
            local n=0 for _ in pairs(queue) do n=n+1 end return n
        end)())
        btnMin.Text = "+"
        main.Size = compactSize
        main.Position = UDim2.new(
            fullPos.X.Scale, fullPos.X.Offset,
            fullPos.Y.Scale, fullPos.Y.Offset
        )
    else
        search.Visible = true
        btnScan.Visible = true
        btnAuto.Visible = true
        btnStart.Visible = true
        btnStop.Visible = true
        lblDelay.Visible = true
        boxDelay.Visible = true
        queueLbl.Visible = true
        btnClear.Visible = true
        list.Visible = true
        status.Visible = true
        title.Size = UDim2.new(1, -60, 0, 24)
        title.Position = UDim2.new(0, 8, 0, 4)
        title.Text = "🎣 Bait Scanner"
        btnMin.Text = "–"
        main.Size = fullSize
        main.Position = fullPos
    end
end

btnMin.MouseButton1Click:Connect(function()
    setMinimize(not minimized)
end)

-- ====== SCOOP ======
local function stopUID(uid)
    active[uid] = nil
    if threads[uid] then
        pcall(task.cancel, threads[uid])
        threads[uid] = nil
    end
end

local function startUID(uid)
    if active[uid] or not queue[uid] then return end
    active[uid] = true
    threads[uid] = task.spawn(function()
        task.wait(math.random() * delay)
        while active[uid] and queue[uid] and gui.Parent do
            local ok = pcall(function()
                gearUseFishFeeder:FireServer(SCOOP_ITEM, uid)
            end)
            if ok then
                sent = sent + 1
                status.Text = "✔ " .. queue[uid].owner .. " " .. uid:sub(1, 6)
            else
                failed = failed + 1
            end
            queueLbl.Text = string.format("Q:%d A:%d S:%d F:%d",
                (function() local n=0 for _ in pairs(queue) do n=n+1 end return n end)(),
                (function() local n=0 for _ in pairs(active) do n=n+1 end return n end)(),
                sent, failed)
            task.wait(delay)
        end
        active[uid] = nil
        threads[uid] = nil
    end)
end

local function stopAll()
    for uid in pairs(active) do stopUID(uid) end
end

-- ====== RENDER ======
local function render()
    for _, c in ipairs(list:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end

    local q = string.lower(query)
    local order, total, players = 0, 0, 0
    local names = {}
    for n in pairs(scanned) do table.insert(names, n) end
    table.sort(names)

    for _, name in ipairs(names) do
        local info = scanned[name]
        local shown = 0
        for _, b in ipairs(info.baits) do
            local match = (q == "")
                or string.find(string.lower(name), q, 1, true)
                or string.find(string.lower(b.type), q, 1, true)
                or string.find(string.lower(b.uid), q, 1, true)
            if match then
                shown = shown + 1
                order = order + 1
                total = total + 1

                local row = Instance.new("Frame", list)
                row.Size = UDim2.new(1, 0, 0, 26)
                row.BackgroundColor3 = C.alt
                row.BorderSizePixel = 0
                row.LayoutOrder = order
                Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

                local ind = Instance.new("Frame", row)
                ind.Size = UDim2.new(0, 3, 1, 0)
                ind.BackgroundColor3 = C.accent
                ind.BorderSizePixel = 0
                ind.Visible = false
                Instance.new("UICorner", ind).CornerRadius = UDim.new(0, 3)

                local btn = Instance.new("TextButton", row)
                btn.Size = UDim2.new(1, 0, 1, 0)
                btn.BackgroundTransparency = 1
                btn.Text = ""

                local n1 = Instance.new("TextLabel", row)
                n1.Size = UDim2.new(0, 90, 1, 0)
                n1.Position = UDim2.new(0, 8, 0, 0)
                n1.BackgroundTransparency = 1
                n1.Text = name
                n1.TextColor3 = C.accent
                n1.Font = Enum.Font.GothamBold
                n1.TextSize = 10
                n1.TextXAlignment = Enum.TextXAlignment.Left
                n1.TextTruncate = Enum.TextTruncate.AtEnd

                local n2 = Instance.new("TextLabel", row)
                n2.Size = UDim2.new(0, 100, 1, 0)
                n2.Position = UDim2.new(0, 100, 0, 0)
                n2.BackgroundTransparency = 1
                n2.Text = b.type
                n2.TextColor3 = C.text
                n2.Font = Enum.Font.GothamMedium
                n2.TextSize = 10
                n2.TextXAlignment = Enum.TextXAlignment.Left
                n2.TextTruncate = Enum.TextTruncate.AtEnd

                local n3 = Instance.new("TextLabel", row)
                n3.Size = UDim2.new(0, 80, 1, 0)
                n3.Position = UDim2.new(0, 202, 0, 0)
                n3.BackgroundTransparency = 1
                n3.Text = b.uid:sub(1, 8)
                n3.TextColor3 = C.dim
                n3.Font = Enum.Font.Code
                n3.TextSize = 9
                n3.TextXAlignment = Enum.TextXAlignment.Left

                local n4 = Instance.new("TextLabel", row)
                n4.Size = UDim2.new(0, 40, 1, 0)
                n4.Position = UDim2.new(1, -80, 0, 0)
                n4.BackgroundTransparency = 1
                n4.Text = "x" .. tostring(b.amount)
                n4.TextColor3 = C.dim
                n4.Font = Enum.Font.Code
                n4.TextSize = 9
                n4.TextXAlignment = Enum.TextXAlignment.Left

                local st = Instance.new("TextLabel", row)
                st.Size = UDim2.new(0, 30, 1, 0)
                st.Position = UDim2.new(1, -36, 0, 0)
                st.BackgroundTransparency = 1
                st.Text = ""
                st.Font = Enum.Font.GothamBold
                st.TextSize = 11
                st.TextXAlignment = Enum.TextXAlignment.Right

                if active[b.uid] then
                    row.BackgroundColor3 = C.ok:Lerp(C.alt, 0.75)
                    ind.BackgroundColor3 = C.ok
                    ind.Visible = true
                    st.Text = "▶"
                    st.TextColor3 = C.ok
                elseif queue[b.uid] then
                    row.BackgroundColor3 = C.sel:Lerp(C.alt, 0.7)
                    ind.BackgroundColor3 = C.sel
                    ind.Visible = true
                    st.Text = "✓"
                    st.TextColor3 = C.sel
                end

                btn.MouseButton1Click:Connect(function()
                    if queue[b.uid] then
                        stopUID(b.uid)
                        queue[b.uid] = nil
                        row.BackgroundColor3 = C.alt
                        ind.Visible = false
                        st.Text = ""
                    else
                        queue[b.uid] = { uid = b.uid, owner = name }
                        row.BackgroundColor3 = C.sel:Lerp(C.alt, 0.7)
                        ind.BackgroundColor3 = C.sel
                        ind.Visible = true
                        st.Text = "✓"
                        st.TextColor3 = C.sel
                    end
                    local qn, an = 0, 0
                    for _ in pairs(queue) do qn = qn + 1 end
                    for _ in pairs(active) do an = an + 1 end
                    queueLbl.Text = string.format("Q:%d A:%d S:%d F:%d", qn, an, sent, failed)
                    if minimized then
                        title.Text = "🎣 Q:" .. qn
                    end
                end)
            end
        end
        if shown > 0 then players = players + 1 end
    end
    status.Text = string.format("P:%d B:%d Q:%d", players, total, (function()
        local n=0 for _ in pairs(queue) do n=n+1 end return n
    end)())
end

-- ====== EVENTS ======
boxDelay.FocusLost:Connect(function()
    local n = tonumber(boxDelay.Text)
    if n and n >= 0.05 then delay = n
    else boxDelay.Text = tostring(delay) end
end)

search:GetPropertyChangedSignal("Text"):Connect(function()
    query = search.Text
    render()
end)

btnScan.MouseButton1Click:Connect(function()
    scanned = scan()
    render()
end)

btnAuto.MouseButton1Click:Connect(function()
    autoScan = not autoScan
    btnAuto.BackgroundColor3 = autoScan and C.ok or C.bad
    btnAuto.Text = autoScan and "⚡ ON" or "⏸ OFF"
end)

btnStart.MouseButton1Click:Connect(function()
    for uid in pairs(queue) do startUID(uid) end
    render()
end)

btnStop.MouseButton1Click:Connect(function()
    stopAll()
    render()
end)

btnClear.MouseButton1Click:Connect(function()
    stopAll()
    for uid in pairs(queue) do queue[uid] = nil end
    queueLbl.Text = "Q:0 A:0 S:0 F:0"
    render()
end)

close.MouseButton1Click:Connect(function()
    stopAll()
    gui:Destroy()
end)

-- ====== INIT ======
scanned = scan()
render()

task.spawn(function()
    while gui.Parent do
        if autoScan then
            scanned = scan()
            render()
        end
        task.wait(SCAN_INTERVAL)
    end
end)
