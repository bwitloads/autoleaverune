local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local CheckInterval = 1 -- How often to check (in seconds)
local RetryInterval = 10 -- How often to retry rejoining after a failure
local DeathDelay = 5 -- delay

-- Function to handle rejoin
local function rejoinGame()
    print("Detected disconnection or error. Rejoining the game...")
    -- Rejoin the game using the same place
    pcall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer) -- Teleports back to the same game
    end)
end

-- Function to detect if the player is disconnected (error screen pop-up or lost connection)
local function checkForDisconnection()
    -- If the player's character is nil or their HumanoidRootPart is missing, it's likely disconnected
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        rejoinGame()  -- Rejoin the game if disconnected
    end
end

-- Function to detect teleportation failure
local function handleTeleportFailure()
    -- Retry teleportation in case of failure (for example, "Failed to Connect" or server issues)
    pcall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
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

-- Function to find and join a new server (3-8 players only)
local function hopServer()
    local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")).data
    local suitableServers = {}

    -- Find servers with 3-8 players
    for _, server in pairs(servers) do
        if server.playing >= 3 and server.playing <= 8 and server.id ~= game.JobId then
            table.insert(suitableServers, server)
        end
    end

    -- If we find suitable servers, join one of them
    if #suitableServers > 0 then
        local serverToJoin = suitableServers[math.random(1, #suitableServers)]
        print("Hopping to new server: " .. serverToJoin.id)
        local success, errorMessage = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, serverToJoin.id, LocalPlayer)
        end)
        if not success then
            print("Teleport failed: " .. errorMessage)
            handleTeleportFailure() -- Retry teleport if it fails
        end
    else
        -- Panic join if no suitable servers (3-8 players) are found
        print("No suitable servers found. Panic joining any available server...")
        local randomServer = servers[math.random(1, #servers)] -- Select a random server from the list
        print("Joining random server: " .. randomServer.id)
        local success, errorMessage = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, randomServer.id, LocalPlayer)
        end)
        if not success then
            print("Teleport failed: " .. errorMessage)
            handleTeleportFailure() -- Retry teleport if it fails
        end
    end
end

-- Function to handle respawn event
local function onCharacterAdded(character)
    print("Character respawned. Waiting for " .. DeathDelay .. " seconds before starting the script.")
    wait(DeathDelay) -- Wait for 5 seconds after respawn
end

-- Listen for character respawn
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

-- Continuous check for player proximity and disconnection
while true do
    wait(CheckInterval)

    -- Check if the player is disconnected and rejoin
    checkForDisconnection()

    -- Check player proximity if not in the delay period
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local playerCount = getPlayersInRadius(100)
        print("Players in radius:", playerCount)

        -- Only hop if there are players nearby (playerCount > 0)
        if playerCount > 0 then
            print("Players found in proximity. Searching for a new server (3-8 players)...")
            hopServer()
        end
    end
end
