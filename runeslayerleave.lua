local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local CheckInterval = 1 -- How often to check (in seconds)
local RetryInterval = 10 -- How often to retry rejoining after a failure
local DeathDelay = 10 -- delay

-- Function to handle rejoin
local function rejoinGame()
    print("Detected disconnection or error. Rejoining the game...")
    local success, errorMessage = pcall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer) -- Teleports back to the same game
    end)
    if not success then
        print("❌ Rejoin failed:", errorMessage)
    end
end

-- Function to detect if the player is disconnected
local function checkForDisconnection()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        rejoinGame()
    end
end

-- Function to fetch a list of available servers
local function getServerList()
    local servers = {}
    local nextCursor = nil
    local retryLimit = 3
    local retries = 0

    repeat
        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100" .. (nextCursor and "&cursor=" .. nextCursor or ""), true))
        end)

        if success and result and result.data then
            for _, server in pairs(result.data) do
                if server.id ~= game.JobId and server.playing >= 3 and server.playing <= 8 then
                    table.insert(servers, server)
                end
            end
            if #servers > 0 then
                return servers
            else
                print("❌ No suitable servers found in this batch.")
            end
        else
            retries = retries + 1
            print("❌ Failed to fetch server list. Retrying... (" .. retries .. "/" .. retryLimit .. ")")
            wait(10)
        end
    until retries >= retryLimit

    return servers
end

-- Function to hop to a new server
local function hopServer()
    print("🔍 Searching for a new server (3-8 players)...")

    local suitableServers = getServerList()

    if #suitableServers > 0 then
        local serverToJoin = suitableServers[math.random(1, #suitableServers)]
        print("🌍 Hopping to server: " .. serverToJoin.id)
        local success, errorMessage = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, serverToJoin.id, LocalPlayer)
        end)
        if not success then
            print("❌ Teleport failed: " .. errorMessage)
            wait(RetryInterval)
            hopServer() -- Retry
        end
    else
        print("❌ No suitable servers found. Retrying in 10 seconds...")
        wait(10)
        hopServer()
    end
end

-- Function to count players in proximity (excluding self)
local function getPlayersInRadius(radius)
    local count = 0
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (LocalPlayer.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).magnitude
            if distance <= radius then
                count = count + 1
            end
        end
    end
    return count
end

-- Function to handle respawn event
local function onCharacterAdded(character)
    print("Character respawned. Waiting for " .. DeathDelay .. " seconds before starting the script.")
    wait(DeathDelay)
end

-- Listen for character respawn
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

-- Continuous check for player proximity and disconnection
while true do
    wait(CheckInterval)

    -- Check if the player is disconnected
    checkForDisconnection()

    -- Check player proximity
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local playerCount = getPlayersInRadius(200)
        print("Players in radius:", playerCount)

        -- Only hop if there are players nearby
        if playerCount > 0 then
            print("Players found nearby. Searching for a new server...")
            hopServer()
        end
    end
end
