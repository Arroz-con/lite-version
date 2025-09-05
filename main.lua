local __DARKLUA_BUNDLE_MODULES

__DARKLUA_BUNDLE_MODULES = {
    cache = {},
    load = function(m)
        if not __DARKLUA_BUNDLE_MODULES.cache[m] then
            __DARKLUA_BUNDLE_MODULES.cache[m] = {
                c = __DARKLUA_BUNDLE_MODULES[m](),
            }
        end

        return __DARKLUA_BUNDLE_MODULES.cache[m].c
    end,
}

do
    function __DARKLUA_BUNDLE_MODULES.a()
        local SecureService = {}

        function SecureService.TrySecure(service)
            local _game = (cloneref and {
                (cloneref(game)),
            } or {game})[1]
            local _, result = pcall(function()
                return (cloneref and {
                    (cloneref(_game:GetService(service))),
                } or {
                    (_game:GetService(service)),
                })[1]
            end)

            return result
        end

        SecureService.TrySecure = (newcclosure and {
            (newcclosure(SecureService.TrySecure)),
        } or {
            (SecureService.TrySecure),
        })[1]

        return SecureService
    end
    function __DARKLUA_BUNDLE_MODULES.b()
        local SecureService = __DARKLUA_BUNDLE_MODULES.load('a')
        local VirtualInputManager = (SecureService.TrySecure('VirtualInputManager'))
        local Workspace = (SecureService.TrySecure('Workspace'))
        local ReplicatedStorage = (SecureService.TrySecure('ReplicatedStorage'))
        local Players = (SecureService.TrySecure('Players'))
        local Utils = {}
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local RouterClient = Bypass('RouterClient')
        local debugMode = getgenv().SETTINGS.DEBUG_MODE or false
        local localPlayer = Players.LocalPlayer

        function Utils.PlaceFLoorUnderPlayer()
            if Workspace:FindFirstChild('FloorUnderPlayer') then
                return
            end

            local humanoidRootPart = Utils.GetHumanoidRootPart()
            local floorPart = Instance.new('Part')

            floorPart.Position = humanoidRootPart.Position + Vector3.new(0, -2.2, 0)
            floorPart.Size = Vector3.new(100, 2, 100)
            floorPart.Anchored = true
            floorPart.Transparency = 0
            floorPart.Name = 'FloorUnderPlayer'
            floorPart.Parent = Workspace
        end
        function Utils.RemoveHandHeldItem()
            local character = Utils.GetCharacter()
            local tool = (character and {
                (character:FindFirstChildOfClass('Tool')),
            } or {nil})[1]

            if not tool then
                return
            end

            local unique = tool:FindFirstChild('unique')

            if not unique then
                return
            end
            if not unique:IsA('StringValue') then
                return
            end

            RouterClient.get('ToolAPI/Unequip'):InvokeServer(unique.Value, {})
        end
        function Utils.FindBait()
            local baits = getgenv().SETTINGS.BAIT_TO_USE_IN_ORDER

            if not baits then
                baits = {
                    'ice_dimension_2025_shiver_cone_bait',
                    'ice_dimension_2025_subzero_popsicle_bait',
                    'ice_dimension_2025_ice_soup_bait',
                }
            end

            for _, id in ipairs(baits)do
                for _, v in pairs(ClientData.get_data()[localPlayer.Name].inventory.food)do
                    if id == v.id then
                        return v.unique
                    end
                end
            end

            return nil
        end
        function Utils.PlaceBaitOrPickUp(normalLureKey, baitUnique)
            if not (normalLureKey and baitUnique) then
                return
            end
            if typeof(normalLureKey) ~= 'string' then
                return
            end

            Utils.PrintDebug('placing bait or picking up')

            local args = {
                [1] = localPlayer,
                [2] = normalLureKey,
                [3] = 'UseBlock',
                [4] = {
                    ['bait_unique'] = baitUnique,
                },
                [5] = localPlayer.Character,
            }
            local success, errorMessage = pcall(function()
                return RouterClient.get('HousingAPI/ActivateFurniture'):InvokeServer(table.unpack(args))
            end)

            Utils.PrintDebug('BAITBOX:', success, errorMessage)
        end
        function Utils.GetPlayersInGame()
            local playerTable = {}

            for _, player in Players:GetPlayers()do
                if player.Name == localPlayer.Name then
                    continue
                end

                table.insert(playerTable, player.Name)
            end

            table.sort(playerTable)

            return playerTable
        end
        function Utils.ConsumeItem(potionName)
            local agePotion = Workspace:WaitForChild('PetObjects'):WaitForChild(potionName, 15)

            if not agePotion then
                return
            end

            RouterClient.get('PetAPI/ConsumeFoodObject'):FireServer(agePotion, ClientData.get('pet_char_wrappers')[1].pet_unique)
        end
        function Utils.CreatePetObject(objectUnique)
            local args = {
                [1] = '__Enum_PetObjectCreatorType_2',
                [2] = {
                    ['pet_unique'] = ClientData.get('pet_char_wrappers')[1].pet_unique,
                    ['unique_id'] = objectUnique,
                },
            }

            RouterClient.get('PetObjectAPI/CreatePetObject'):InvokeServer(unpack(args))
        end
        function Utils.FeedAgePotion(petEggs, FoodPassOn)
            for _, v in ClientData.get_data()[localPlayer.Name].inventory.food do
                if v.id == FoodPassOn then
                    if not ClientData.get('pet_char_wrappers')[1] then
                        return
                    end

                    local isEgg = table.find(petEggs, ClientData.get('pet_char_wrappers')[1]['pet_id']) and true or false
                    local petAge = ClientData.get('pet_char_wrappers')[1]['pet_progression']['age']

                    if isEgg or petAge >= 6 then
                        return
                    end

                    local args = {
                        [1] = '__Enum_PetObjectCreatorType_2',
                        [2] = {
                            ['pet_unique'] = ClientData.get('pet_char_wrappers')[1].pet_unique,
                            ['unique_id'] = v.unique,
                        },
                    }

                    RouterClient.get('PetObjectAPI/CreatePetObject'):InvokeServer(unpack(args))
                    Utils.ConsumeItem('AgePotion')

                    return
                end
            end

            return
        end
        function Utils.IsCollectorInGame(collectorNames)
            for _, player in Players:GetPlayers()do
                if player.Name == localPlayer.Name then
                    continue
                end
                if table.find(collectorNames, player.Name) then
                    return true
                end
            end

            return false
        end
        function Utils.BucksAmount()
            return ClientData.get_data()[localPlayer.Name].money or 0
        end
        function Utils.EventCurrencyAmount()
            return ClientData.get_data()[localPlayer.Name].domestic_shards_2025 or 0
        end
        function Utils.FoodItemCount(nameId)
            local count = 0

            for ExampleObjects, v in ClientData.get_data()[localPlayer.Name].inventory.food do
                if v.id == nameId then
                    count = count + 1
                end
            end

            return count
        end
        function Utils.FormatNumber(num)
            if num >= 1e6 then
                return string.format('%.2fM', num / 1e6)
            elseif num >= 1e3 then
                return string.format('%.1fK', num / 1e3)
            else
                return string.format('%.0f', num)
            end
        end
        function Utils.FormatTime(currentTime)
            local hours = math.floor(currentTime / 3600)
            local minutes = math.floor((currentTime % 3600) / 60)
            local seconds = currentTime % 60

            return string.format('%02d:%02d:%02d', hours, minutes, seconds)
        end
        function Utils.ClickGuiButton(button, xOffset, yOffset)
            if not button then
                return
            end

            pcall(function()
                local xOffset1 = xOffset or 60
                local yOffset1 = yOffset or 60

                task.wait()
                VirtualInputManager:SendMouseButtonEvent(button.AbsolutePosition.X + xOffset1, button.AbsolutePosition.Y + yOffset1, 0, true, game, 1)
                task.wait()
                VirtualInputManager:SendMouseButtonEvent(button.AbsolutePosition.X + xOffset1, button.AbsolutePosition.Y + yOffset1, 0, false, game, 1)
            end)

            return
        end
        function Utils.FireButton(button)
            if not button then
                return
            end
            if firesignal then
                pcall(function()
                    local mouseButton1Down = button.MouseButton1Down
                    local mouseButton1Click = button.MouseButton1Click

                    firesignal(mouseButton1Down)
                    task.wait(1)
                    firesignal(mouseButton1Click)
                    task.wait(1)
                end)
            else
                Utils.ClickGuiButton(button)
            end
        end
        function Utils.FindButton(text, dialogFramePassOn)
            task.wait(0.1)

            dialogFramePassOn = dialogFramePassOn or 'NormalDialog'

            if not dialogFramePassOn then
                return
            end

            local dialog = localPlayer:WaitForChild('PlayerGui'):WaitForChild('DialogApp'):WaitForChild('Dialog')
            local buttons = dialog:WaitForChild(dialogFramePassOn):WaitForChild('Buttons', 10)

            if not buttons then
                Utils.PrintDebug('NO BUTTONS')

                return
            end

            for _, v in buttons:GetDescendants()do
                if v:IsA('TextLabel') and v.Text == text then
                    local button = v:FindFirstAncestorWhichIsA('ImageButton') or v:FindFirstAncestorWhichIsA('TextButton')

                    if not button then
                        return
                    end

                    Utils.FireButton(button)

                    return
                end
            end
        end
        function Utils.IsPetEquipped(whichPet)
            local petIndex = ClientData.get('pet_char_wrappers')[whichPet]

            if not petIndex then
                return false
            end
            if not petIndex['char'] then
                return false
            end

            return true
        end
        function Utils.UnEquip(petUnique, EquipAsLast)
            local success, errorMessage = pcall(function()
                RouterClient.get('ToolAPI/Unequip'):InvokeServer(petUnique, {
                    ['equip_as_last'] = EquipAsLast,
                })
            end)

            if not success then
                Utils.PrintDebug('Failed to Unequip pet:', errorMessage)

                return false
            end

            return true
        end
        function Utils.UnEquipAllPets()
            repeat
                if Utils.IsPetEquipped(1) then
                    Utils.UnEquip(ClientData.get('pet_char_wrappers')[1].pet_unique, false)
                end

                task.wait(1)
            until not Utils.IsPetEquipped(1)

            Utils.PrintDebug('UnEquipped all pets')
        end
        function Utils.Equip(petUnique, EquipAsLast)
            local success, errorMessage = pcall(function()
                RouterClient.get('ToolAPI/Equip'):InvokeServer(petUnique, {
                    ['equip_as_last'] = EquipAsLast,
                })
            end)

            if not success then
                Utils.PrintDebug('Failed to equip pet:', errorMessage)

                return false
            end

            return true
        end
        function Utils.ReEquipPet(whichPet)
            local hasPetChar = false
            local EquipTimeout = 0

            if not ClientData.get('pet_char_wrappers') then
                return false
            end
            if not ClientData.get('pet_char_wrappers')[whichPet] then
                return false
            end

            local petUnique = ClientData.get('pet_char_wrappers')[whichPet].pet_unique

            if whichPet == 1 then
                if not Utils.UnEquip(petUnique, false) then
                    return false
                end

                task.wait(1)

                if not Utils.Equip(petUnique, false) then
                    return false
                end
            elseif whichPet == 2 then
                if not Utils.UnEquip(petUnique, true) then
                    return false
                end

                task.wait(1)

                if not Utils.Equip(petUnique, true) then
                    return false
                end
            end

            repeat
                task.wait(1)

                hasPetChar = ClientData.get('pet_char_wrappers') and ClientData.get('pet_char_wrappers')[whichPet] and ClientData.get('pet_char_wrappers')[whichPet]['char'] and true or false
                EquipTimeout = EquipTimeout + 1
            until hasPetChar or EquipTimeout >= 20

            if EquipTimeout >= 20 then
                Utils.PrintDebug('\u{26a0}\u{fe0f} Waited too long for Equipping pet \u{26a0}\u{fe0f}')

                return false
            end

            Utils.PrintDebug(string.format('ReEquipPet: success in equipping %s', tostring(whichPet)))

            return true
        end
        function Utils.PrintDebug(...)
            if not debugMode then
                return
            end

            print(string.format('[Debug] %s', tostring(...)))
        end
        function Utils.CenterText(text, width)
            local textLength = #text

            if textLength >= width then
                return text
            end

            local padding = width - textLength
            local left = math.floor(padding / 2)
            local right = padding - left

            return string.format('%s %s %s', tostring(string.rep(' ', left)), tostring(text), tostring(string.rep(' ', right)))
        end
        function Utils.WaitForPetToEquip(timeout)
            local maxTimeout = timeout or 20
            local hasPetChar = nil
            local stuckTimer = 0

            repeat
                task.wait(1)

                hasPetChar = ClientData.get('pet_char_wrappers') and ClientData.get('pet_char_wrappers')[1] and ClientData.get('pet_char_wrappers')[1].pet_unique and true or false
                stuckTimer = stuckTimer + 1
            until hasPetChar or stuckTimer > maxTimeout

            if stuckTimer > maxTimeout then
                return false
            end

            return true
        end
        function Utils.GetCharacter()
            return localPlayer.Character or localPlayer.CharacterAdded:Wait()
        end
        function Utils.GetHumanoidRootPart()
            return (Utils.GetCharacter():WaitForChild('HumanoidRootPart'))
        end
        function Utils.FireRedeemCode(code)
            RouterClient.get('CodeRedemptionAPI/AttemptRedeemCode'):InvokeServer(code)
        end

        return Utils
    end
    function __DARKLUA_BUNDLE_MODULES.c()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local RouterClient = Bypass('RouterClient')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('b')
        local self = {}
        local localPlayer = Players.LocalPlayer
        local furnitures = {
            basiccrib = 'nil',
            stylishshower = 'nil',
            modernshower = 'nil',
            piano = 'nil',
            lures_2023_normal_lure = 'nil',
            ailments_refresh_2024_litter_box = 'nil',
        }

        function self.GetFurnituresKey()
            Utils.PrintDebug('getting furniture ids')

            for key, value in ClientData.get_data()[localPlayer.Name].house_interior.furniture do
                if value.id == 'basiccrib' then
                    furnitures['basiccrib'] = key
                elseif value.id == 'stylishshower' or value.id == 'modernshower' then
                    furnitures['stylishshower'] = key
                    furnitures['modernshower'] = key
                elseif value.id == 'piano' then
                    furnitures['piano'] = key
                elseif value.id == 'lures_2023_normal_lure' then
                    furnitures['lures_2023_normal_lure'] = key
                elseif value.id == 'ailments_refresh_2024_litter_box' then
                    furnitures['ailments_refresh_2024_litter_box'] = key
                end
            end

            return furnitures
        end
        function self.BuyFurniture(furnitureId)
            local args = {
                {
                    {
                        ['kind'] = furnitureId,
                        ['properties'] = {
                            ['cframe'] = CFrame.new(14, 2, -22) * CFrame.Angles(-0, 8.7, 3.8),
                        },
                    },
                },
            }

            RouterClient.get('HousingAPI/BuyFurnitures'):InvokeServer(unpack(args))
        end

        return self
    end
    function __DARKLUA_BUNDLE_MODULES.d()
        return {
            Denylist = {
                'practice_dog',
                'starter_egg',
                'dog',
                'cat',
                'cracked_egg',
                'basic_egg_2022_ant',
                'basic_egg_2022_mouse',
                'spring_2025_minigame_spiked_kaijunior',
                'spring_2025_minigame_scorching_kaijunior',
                'spring_2025_minigame_toxic_kaijunior',
                'spring_2025_minigame_spotted_kaijunior',
                'beach_2024_mahi_spinning_rod_temporary',
                'sandwich-default',
                'squeaky_bone_default',
                'trade_license',
            },
            Allowlist = {
                'ice_dimension_2025_frostbite_bear',
            },
        }
    end
    function __DARKLUA_BUNDLE_MODULES.e()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local RouterClient = Bypass('RouterClient')
        local InventoryDB = Bypass('InventoryDB')
        local AllowOrDenyList = __DARKLUA_BUNDLE_MODULES.load('d')
        local TrashItemsList = {}
        local Utils = __DARKLUA_BUNDLE_MODULES.load('b')
        local self = {}
        local localPlayer = Players.LocalPlayer
        local lowTierRarity = {
            'common',
            'uncommon',
            'rare',
            'ultra_rare',
        }
        local inActiveTrade = function()
            local timeOut = 60

            repeat
                task.wait(1)

                timeOut = timeOut - 1
            until ClientData.get_data()[localPlayer.Name].in_active_trade or timeOut <= 0

            if timeOut <= 0 then
                return
            end
            if #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= 18 then
                return
            end
        end
        local waitForActiveTrade = function()
            local timeOut = 60

            while not ClientData.get_data()[localPlayer.Name].in_active_trade do
                task.wait(1)

                timeOut = timeOut - 1

                if timeOut <= 0 then
                    return false, Utils.PrintDebug('\u{26a0}\u{fe0f} waiting for trade timedout \u{26a0}\u{fe0f}')
                end
            end

            return true
        end
        local isMulesInGame = function(playerMulesTable)
            for _, player in Players:GetPlayers()do
                if player.Name == localPlayer.Name then
                    continue
                end
                if table.find(playerMulesTable, player.Name) then
                    return true
                end
            end

            return false
        end
        local convertPetAges = function(options)
            local agesNumber = {}

            for _, v in options['ages']do
                if v == 'Newborn/Reborn' then
                    table.insert(agesNumber, 1)
                elseif v == 'Junior/Twinkle' then
                    table.insert(agesNumber, 2)
                elseif v == 'Pre_Teen/Sparkle' then
                    table.insert(agesNumber, 3)
                elseif v == 'Teen/Flare' then
                    table.insert(agesNumber, 4)
                elseif v == 'Post_Teen/Sunshine' then
                    table.insert(agesNumber, 5)
                elseif v == 'Full_Grown/Luminous' then
                    table.insert(agesNumber, 6)
                end
            end

            return agesNumber
        end
        local MultipleOptionsTradeLoop = function(
            newOptions,
            isNeon,
            isMegaNeon
        )
            local raritys = newOptions['rarity']
            local ages = newOptions['ages']
            local waitForAdded = 0

            for _, petDB in InventoryDB.pets do
                for _, pet in ClientData.get_data()[localPlayer.Name].inventory.pets do
                    if table.find(AllowOrDenyList.Denylist, pet.id) then
                        continue
                    end
                    if petDB.id ~= pet.id then
                        continue
                    end
                    if not table.find(raritys, petDB.rarity) then
                        continue
                    end
                    if not table.find(ages, pet.properties.age) then
                        continue
                    end
                    if pet.properties.neon == isNeon and pet.properties.mega_neon == isMegaNeon then
                        if not ClientData.get_data()[localPlayer.Name].in_active_trade then
                            return false
                        end
                        if #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= 18 then
                            return true
                        end

                        RouterClient.get('TradeAPI/AddItemToOffer'):FireServer(pet.unique)

                        waitForAdded = waitForAdded + 1

                        repeat
                            task.wait(0.1)
                        until #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= waitForAdded or not ClientData.get_data()[localPlayer.Name].in_active_trade
                    end
                end
            end

            if not ClientData.get_data()[localPlayer.Name].in_active_trade then
                return false
            end
            if #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= 1 then
                return true
            else
                return false
            end
        end
        local hasTrashItems = function()
            for _, v in ClientData.get_data()[localPlayer.Name].inventory do
                for _, item in v do
                    if not table.find(TrashItemsList, item.id) then
                        continue
                    end
                    if not item.properties.age then
                        return true
                    end
                    if item.properties.age == 6 or item.properties.neon or item.properties.mega_neon then
                        continue
                    end

                    return true
                end
            end

            return false
        end

        function self.AcceptNegotiationAndConfirm()
            local timeOut = 30

            repeat
                task.wait(1)

                if ClientData.get_data()[localPlayer.Name].in_active_trade then
                    if ClientData.get_data()[localPlayer.Name].trade.current_stage == 'negotiation' then
                        if not ClientData.get_data()[localPlayer.Name].trade.sender_offer.negotiated then
                            RouterClient.get('TradeAPI/AcceptNegotiation'):FireServer()
                        end
                    end
                    if #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items == 0 and #ClientData.get_data()[localPlayer.Name].trade.recipient_offer.items == 0 then
                        RouterClient.get('TradeAPI/DeclineTrade'):FireServer()

                        return false
                    end
                    if ClientData.get_data()[localPlayer.Name].trade.current_stage == 'confirmation' then
                        if not ClientData.get_data()[localPlayer.Name].trade.sender_offer.confirmed then
                            RouterClient.get('TradeAPI/ConfirmTrade'):FireServer()
                        end
                    end
                end

                timeOut = timeOut - 1
            until not ClientData.get_data()[localPlayer.Name].in_active_trade or timeOut <= 0

            return true
        end
        function self.SendTradeRequest(playerTable)
            if typeof(playerTable) ~= 'table' then
                return false, Utils.PrintDebug('playerTable is not a table')
            end

            while true do
                if not isMulesInGame(playerTable) then
                    return false
                end

                local TradeApp = (localPlayer:WaitForChild('PlayerGui'):WaitForChild('TradeApp'))
                local TradeFrame = (TradeApp:WaitForChild('Frame'))

                if TradeFrame.Visible then
                    return true
                end

                for _, player in Players:GetPlayers()do
                    if not table.find(playerTable, player.Name) then
                        continue
                    end
                    if ClientData.get_data()[player.Name] and not ClientData.get_data()[player.Name].in_active_trade then
                        RouterClient.get('TradeAPI/SendTradeRequest'):FireServer(player)
                        task.wait(1)
                    end
                end

                task.wait(math.random(20, 30))
            end
        end
        function self.SelectTabAndTrade(tab, selectedItem)
            inActiveTrade()

            for _, item in ClientData.get_data()[localPlayer.Name].inventory[tab]do
                if item.id == selectedItem then
                    if not ClientData.get_data()[localPlayer.Name].in_active_trade then
                        return
                    end

                    RouterClient.get('TradeAPI/AddItemToOffer'):FireServer(item.unique)

                    if #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= 18 then
                        return
                    end

                    task.wait(0.1)
                end
            end
        end
        function self.NeonNewbornToPostteen()
            inActiveTrade()

            for _, pet in ClientData.get_data()[localPlayer.Name].inventory.pets do
                if table.find(AllowOrDenyList.Denylist, pet.id) then
                    continue
                end
                if pet.properties.age <= 5 and pet.properties.neon then
                    if not ClientData.get_data()[localPlayer.Name].in_active_trade then
                        return
                    end

                    RouterClient.get('TradeAPI/AddItemToOffer'):FireServer(pet.unique)

                    if #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= 18 then
                        return
                    end

                    task.wait(0.1)
                end
            end
        end
        function self.MultipleOptions(options)
            if typeof(options) ~= 'table' then
                return
            end

            local newOptions = table.clone(options)
            local isNormal = table.find(newOptions['neons'], 'normal') and true or nil
            local isNeon = table.find(newOptions['neons'], 'neon') and true or nil
            local isMegaNeon = table.find(newOptions['neons'], 'mega_neon') and true or nil

            newOptions['ages'] = convertPetAges(newOptions)

            inActiveTrade()

            if isNormal then
                if MultipleOptionsTradeLoop(newOptions, nil, nil) then
                    return
                end
            end
            if isNeon then
                if MultipleOptionsTradeLoop(newOptions, true, nil) then
                    return
                end
            end
            if isMegaNeon then
                if MultipleOptionsTradeLoop(newOptions, nil, true) then
                    return
                end
            end

            return
        end
        function self.LowTiers()
            inActiveTrade()

            for _, petDB in InventoryDB.pets do
                for _, pet in ClientData.get_data()[localPlayer.Name].inventory.pets do
                    if table.find(AllowOrDenyList.Denylist, pet.id) then
                        continue
                    end
                    if petDB.id == pet.id and table.find(lowTierRarity, petDB.rarity) and pet.properties.age <= 5 and not pet.properties.neon and not pet.properties.mega_neon then
                        if not ClientData.get_data()[localPlayer.Name].in_active_trade then
                            return
                        end

                        RouterClient.get('TradeAPI/AddItemToOffer'):FireServer(pet.unique)

                        if #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= 18 then
                            return
                        end

                        task.wait(0.1)
                    end
                end
            end
        end
        function self.NewbornToPostteen(rarity)
            inActiveTrade()

            for _, petDB in InventoryDB.pets do
                for _, pet in ClientData.get_data()[localPlayer.Name].inventory.pets do
                    if table.find(AllowOrDenyList.Denylist, pet.id) then
                        continue
                    end
                    if petDB.id == pet.id and petDB.rarity == rarity and pet.properties.age <= 5 and not pet.properties.neon and not pet.properties.mega_neon then
                        if not ClientData.get_data()[localPlayer.Name].in_active_trade then
                            return
                        end

                        RouterClient.get('TradeAPI/AddItemToOffer'):FireServer(pet.unique)

                        if #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= 18 then
                            return
                        end

                        task.wait(0.1)
                    end
                end
            end
        end
        function self.NewbornToPostteenByPetId(petIds)
            if typeof(petIds) ~= 'table' then
                return
            end

            inActiveTrade()

            for _, pet in ClientData.get_data()[localPlayer.Name].inventory.pets do
                if table.find(AllowOrDenyList.Denylist, pet.id) then
                    continue
                end
                if table.find(petIds, pet.id) and pet.properties.age <= 5 and not pet.properties.mega_neon then
                    if not ClientData.get_data()[localPlayer.Name].in_active_trade then
                        return
                    end

                    RouterClient.get('TradeAPI/AddItemToOffer'):FireServer(pet.unique)

                    if #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= 18 then
                        return
                    end

                    task.wait(0.1)
                end
            end
        end
        function self.FullgrownAndAnyNeonsAndMegas()
            inActiveTrade()

            for _, pet in ClientData.get_data()[localPlayer.Name].inventory.pets do
                if pet.properties.age == 6 or pet.properties.neon or pet.properties.mega_neon then
                    if not ClientData.get_data()[localPlayer.Name].in_active_trade then
                        return
                    end

                    RouterClient.get('TradeAPI/AddItemToOffer'):FireServer(pet.unique)

                    if #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= 18 then
                        return
                    end

                    task.wait(0.1)
                end
            end
        end
        function self.Fullgrown()
            inActiveTrade()

            for _, pet in ClientData.get_data()[localPlayer.Name].inventory.pets do
                if pet.properties.age == 6 or (pet.properties.age == 6 and pet.properties.neon) or pet.properties.mega_neon then
                    if not ClientData.get_data()[localPlayer.Name].in_active_trade then
                        return
                    end

                    RouterClient.get('TradeAPI/AddItemToOffer'):FireServer(pet.unique)

                    if #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= 18 then
                        return
                    end

                    task.wait(0.1)
                end
            end
        end
        function self.AllPetsOfSameRarity(rarity)
            inActiveTrade()

            for _, petDB in InventoryDB.pets do
                for _, pet in ClientData.get_data()[localPlayer.Name].inventory.pets do
                    if table.find(AllowOrDenyList.Denylist, pet.id) then
                        continue
                    end
                    if petDB.id == pet.id and petDB.rarity == rarity then
                        if not ClientData.get_data()[localPlayer.Name].in_active_trade then
                            return
                        end

                        RouterClient.get('TradeAPI/AddItemToOffer'):FireServer(pet.unique)

                        if #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= 18 then
                            return
                        end

                        task.wait(0.1)
                    end
                end
            end
        end
        function self.AutoAcceptTrade()
            if ClientData.get_data()[localPlayer.Name].in_active_trade then
                if ClientData.get_data()[localPlayer.Name].trade.sender_offer.negotiated then
                    RouterClient.get('TradeAPI/AcceptNegotiation'):FireServer()
                end
                if ClientData.get_data()[localPlayer.Name].trade.sender_offer.confirmed then
                    RouterClient.get('TradeAPI/ConfirmTrade'):FireServer()
                end
            end
        end
        function self.AllInventory(TabPassOn)
            inActiveTrade()

            for _, item in ClientData.get_data()[localPlayer.Name].inventory[TabPassOn]do
                if table.find(AllowOrDenyList.Denylist, item.id) then
                    continue
                end
                if not ClientData.get_data()[localPlayer.Name].in_active_trade then
                    return
                end

                RouterClient.get('TradeAPI/AddItemToOffer'):FireServer(item.unique)

                if #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= 18 then
                    return
                end

                task.wait(0.1)
            end
        end
        function self.AllPets()
            inActiveTrade()

            for _, pet in ClientData.get_data()[localPlayer.Name].inventory.pets do
                if table.find(AllowOrDenyList.Denylist, pet.id) then
                    continue
                end
                if not ClientData.get_data()[localPlayer.Name].in_active_trade then
                    return
                end

                RouterClient.get('TradeAPI/AddItemToOffer'):FireServer(pet.unique)

                if #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= 18 then
                    return
                end

                task.wait(0.1)
            end
        end
        function self.AllNeons(version)
            inActiveTrade()

            for _, pet in ClientData.get_data()[localPlayer.Name].inventory.pets do
                if pet.properties[version] then
                    if not ClientData.get_data()[localPlayer.Name].in_active_trade then
                        return
                    end

                    RouterClient.get('TradeAPI/AddItemToOffer'):FireServer(pet.unique)

                    if #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= 18 then
                        return
                    end

                    task.wait(0.1)
                end
            end
        end
        function self.CheckInventory()
            if not isMulesInGame(getgenv().SETTINGS.TRADE_COLLECTOR_NAME) then
                Utils.PrintDebug('Collecters no longer ingame')

                return false
            end
            if getgenv().SETTINGS.TRADE_ONLY_LUMINOUS_MEGA then
                for _, v in ClientData.get_data()[localPlayer.Name].inventory do
                    for _, item in v do
                        if table.find(AllowOrDenyList.Denylist, item.id) then
                            continue
                        end
                        if table.find(getgenv().SETTINGS.TRADE_LIST, item.id) or (item.properties.neon and item.properties.age == 6) or item.properties.mega_neon then
                            return true
                        end
                    end
                end
            else
                for _, v in ClientData.get_data()[localPlayer.Name].inventory do
                    for _, item in v do
                        if table.find(AllowOrDenyList.Denylist, item.id) then
                            continue
                        end
                        if table.find(getgenv().SETTINGS.TRADE_LIST, item.id) or item.properties.age == 6 or item.properties.neon or item.properties.mega_neon then
                            return true
                        end
                    end
                end
            end

            return false
        end
        function self.TradeCollector(namePassOn)
            local isInventoryFull = false

            if typeof(namePassOn) ~= 'table' then
                return Utils.PrintDebug(string.format('\u{1f6ab} %s is not a table', tostring(namePassOn)))
            end
            if typeof(getgenv().SETTINGS.TRADE_LIST) ~= 'table' then
                return Utils.PrintDebug('TRADE_LIST is not a table')
            end
            if table.find(namePassOn, localPlayer.Name) then
                return Utils.PrintDebug('\u{1f6ab} MULE CANNOT TRADE ITSELF OR OTHER MULES')
            end

            while getgenv().SETTINGS.ENABLE_TRADE_COLLECTOR do
                if not isMulesInGame(getgenv().SETTINGS.TRADE_COLLECTOR_NAME) then
                    return Utils.PrintDebug('\u{26a0}\u{fe0f} MULE NOT INGAME \u{26a0}\u{fe0f}')
                end
                if not self.CheckInventory() then
                    return Utils.PrintDebug('\u{1f6ab} NO ITEMS TO TRADE')
                end
                if not self.SendTradeRequest(namePassOn) then
                    return Utils.PrintDebug('\u{26a0}\u{fe0f} NO MULES TO TRADE \u{26a0}\u{fe0f}')
                end
                if not waitForActiveTrade() then
                    task.wait(1)

                    continue
                end
                if getgenv().SETTINGS.TRADE_ONLY_LUMINOUS_MEGA then
                    for _, v in ClientData.get_data()[localPlayer.Name].inventory do
                        if isInventoryFull then
                            break
                        end

                        for _, item in v do
                            if table.find(getgenv().SETTINGS.TRADE_LIST, item.id) or (item.properties.neon and item.properties.age == 6) or item.properties.mega_neon then
                                if table.find(AllowOrDenyList.Denylist, item.id) then
                                    continue
                                end
                                if not ClientData.get_data()[localPlayer.Name].in_active_trade then
                                    return
                                end

                                RouterClient.get('TradeAPI/AddItemToOffer'):FireServer(item.unique)

                                if #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= 18 then
                                    isInventoryFull = true

                                    break
                                end

                                task.wait(0.1)
                            end
                        end

                        if isInventoryFull then
                            break
                        end
                    end
                else
                    for _, v in ClientData.get_data()[localPlayer.Name].inventory do
                        if isInventoryFull then
                            break
                        end

                        for _, item in v do
                            if table.find(getgenv().SETTINGS.TRADE_LIST, item.id) or item.properties.age == 6 or item.properties.neon or item.properties.mega_neon then
                                if table.find(AllowOrDenyList.Denylist, item.id) then
                                    continue
                                end
                                if not ClientData.get_data()[localPlayer.Name].in_active_trade then
                                    return
                                end

                                RouterClient.get('TradeAPI/AddItemToOffer'):FireServer(item.unique)

                                if #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= 18 then
                                    isInventoryFull = true

                                    break
                                end

                                task.wait(0.1)
                            end
                        end

                        if isInventoryFull then
                            break
                        end
                    end
                end

                local hasPets = self.AcceptNegotiationAndConfirm()

                if not hasPets then
                    Utils.PrintDebug('\u{1f389} DONE TRADING ITEMS \u{1f389}')

                    return
                end

                isInventoryFull = false
            end

            return
        end
        function self.TradeTrashCollector(namePassOn)
            local isInventoryFull = false

            if table.find(namePassOn, localPlayer.Name) then
                return Utils.PrintDebug('\u{1f6ab} MULE CANNOT TRADE ITSELF')
            end

            while getgenv().SETTINGS.ENABLE_TRASH_COLLECTOR do
                if not isMulesInGame(namePassOn) then
                    return Utils.PrintDebug('\u{26a0}\u{fe0f} MULE NOT INGAME \u{26a0}\u{fe0f}')
                end
                if not hasTrashItems() then
                    return Utils.PrintDebug('\u{1f6ab} NO ITEMS TO TRADE')
                end
                if not self.SendTradeRequest(namePassOn) then
                    return Utils.PrintDebug('\u{26a0}\u{fe0f} NO MULES TO TRADE \u{26a0}\u{fe0f}')
                end
                if not waitForActiveTrade() then
                    task.wait(1)

                    continue
                end

                for _, v in ClientData.get_data()[localPlayer.Name].inventory do
                    if isInventoryFull then
                        break
                    end

                    for _, item in v do
                        if not table.find(TrashItemsList, item.id) then
                            continue
                        end
                        if item.properties.age and (item.properties.age == 6 or item.properties.neon or item.properties.mega_neon) then
                            continue
                        end
                        if not ClientData.get_data()[localPlayer.Name].in_active_trade then
                            return
                        end

                        RouterClient.get('TradeAPI/AddItemToOffer'):FireServer(item.unique)

                        if #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= 18 then
                            isInventoryFull = true

                            break
                        end

                        task.wait(0.1)
                    end

                    if isInventoryFull then
                        break
                    end
                end

                local hasPets = self.AcceptNegotiationAndConfirm()

                if not hasPets then
                    Utils.PrintDebug('\u{1f389} DONE TRADING ITEMS \u{1f389}')

                    return
                end

                isInventoryFull = false
            end

            return
        end

        return self
    end
    function __DARKLUA_BUNDLE_MODULES.f()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local Workspace = cloneref(game:GetService('Workspace'))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local CollisionsClient = Bypass('CollisionsClient')
        local self = {}
        local localPlayer = Players.LocalPlayer
        local getconstants = getconstants or debug.getconstants
        local getgc = getgc or get_gc_objects or debug.getgc
        local get_thread_identity = getthreadidentity or get_thread_identity or gti or getidentity or syn.get_thread_identity or fluxus.get_thread_identity
        local set_thread_identity = setthreadidentity or set_thread_context or sti or setthreadcontext or setidentity or syn.set_thread_identity or fluxus.set_thread_identity
        local SetLocationTP
        local rng = Random.new()

        for _, v in pairs(getgc())do
            if type(v) == 'function' then
                if getfenv(v).script == ReplicatedStorage.ClientModules.Core.InteriorsM.InteriorsM then
                    if table.find(getconstants(v), 'LocationAPI/SetLocation') then
                        SetLocationTP = v

                        break
                    end
                end
            end
        end

        local SetLocationFunc = function(a, b, c)
            local k = get_thread_identity()

            set_thread_identity(2)
            SetLocationTP(a, b, c)
            set_thread_identity(k)
        end

        function self.Init() end
        function self.PlaceFloorAtFarmingHome()
            if Workspace:FindFirstChild('FarmingHomeLocation') then
                return
            end

            local part = Instance.new('Part')
            local SurfaceGui = Instance.new('SurfaceGui')
            local TextLabel = Instance.new('TextLabel')

            part.Position = Vector3.new(10000, 0, 10000)
            part.Size = Vector3.new(200, 2, 200)
            part.Anchored = true
            part.Transparency = 1
            part.Name = 'FarmingHomeLocation'
            part.Parent = Workspace
            SurfaceGui.Parent = part
            SurfaceGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            SurfaceGui.AlwaysOnTop = false
            SurfaceGui.CanvasSize = Vector2.new(600, 600)
            SurfaceGui.Face = Enum.NormalId.Top
            TextLabel.Parent = SurfaceGui
            TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
            TextLabel.BorderSizePixel = 0
            TextLabel.Size = UDim2.new(1, 0, 1, 0)
            TextLabel.Font = Enum.Font.SourceSans
            TextLabel.Text = '\u{1f3e1}'
            TextLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
            TextLabel.TextScaled = true
            TextLabel.TextSize = 14
            TextLabel.TextWrapped = true
        end
        function self.PlaceCameraPart()
            if Workspace:FindFirstChild('CameraPartLocation') then
                return
            end

            local part = Instance.new('Part')

            part.Position = Vector3.new(100000, 10000, 100000)
            part.Size = Vector3.new(2, 2, 2)
            part.Anchored = true
            part.Transparency = 1
            part.Name = 'CameraPartLocation'
            part.Parent = Workspace
        end
        function self.PlaceFloorAtCampSite()
            if Workspace:FindFirstChild('CampingLocation') then
                return
            end

            local campsite = Workspace.StaticMap.Campsite.CampsiteOrigin
            local part = Instance.new('Part')

            part.Position = campsite.Position + Vector3.new(0, -1, 0)
            part.Size = Vector3.new(200, 2, 200)
            part.Anchored = true
            part.Transparency = 1
            part.Name = 'CampingLocation'
            part.Parent = Workspace
        end
        function self.PlaceFloorAtBeachParty()
            if Workspace:FindFirstChild('BeachPartyLocation') then
                return
            end

            local part = Instance.new('Part')

            part.Position = Workspace.StaticMap.Beach.BeachPartyAilmentTarget.Position + Vector3.new(0, 
-10, 0)
            part.Size = Vector3.new(1000, 2, 1000)
            part.Anchored = true
            part.Transparency = 0
            part.Name = 'BeachPartyLocation'
            part.Parent = Workspace
        end
        function self.placeFloorOnJoinZone()
            for _, v in Workspace:GetChildren()do
                if v.Name == 'FloorPart2' then
                    return
                end
            end

            local part = Instance.new('Part')

            part.Position = game.Workspace.Interiors:WaitForChild('Halloween2024Shop'):WaitForChild('TileSkip'):WaitForChild('JoinZone'):WaitForChild('EmitterPart').Position + Vector3.new(0, 
-2, 0)
            part.Size = Vector3.new(100, 2, 100)
            part.Anchored = true
            part.Name = 'FloorPart2'
            part.Parent = Workspace
        end
        function self.DeleteWater()
            Workspace.Terrain:Clear()
        end
        function self.FarmingHome()
            localPlayer.Character:WaitForChild('HumanoidRootPart').Anchored = true
            localPlayer.Character.HumanoidRootPart.CFrame = Workspace.FarmingHomeLocation.CFrame * CFrame.new(rng:NextInteger(1, 40), 10, rng:NextInteger(1, 40))
            localPlayer.Character:WaitForChild('HumanoidRootPart').Anchored = false

            localPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
            self.DeleteWater()
        end
        function self.MainMap()
            local isAlreadyOnMainMap = Workspace:FindFirstChild('Interiors'):FindFirstChild('center_map_plot', true)

            if isAlreadyOnMainMap then
                return
            end

            CollisionsClient.set_collidable(false)

            localPlayer.Character:WaitForChild('HumanoidRootPart').Anchored = true

            SetLocationFunc('MainMap', 'Neighborhood/MainDoor', {})
            Workspace.Interiors:WaitForChild(tostring(Workspace.Interiors:FindFirstChildWhichIsA('Model')))

            localPlayer.Character.PrimaryPart.CFrame = Workspace:WaitForChild('StaticMap'):WaitForChild('Campsite'):WaitForChild('CampsiteOrigin').CFrame + Vector3.new(math.random(1, 5), 10, math.random(1, 5))
            localPlayer.Character:WaitForChild('HumanoidRootPart').Anchored = false

            localPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
            self.DeleteWater()
            task.wait(2)
        end
        function self.Nursery()
            localPlayer.Character:WaitForChild('HumanoidRootPart').Anchored = true

            SetLocationFunc('Nursery', 'MainDoor', {})
            task.wait(1)
            Workspace.Interiors:WaitForChild(tostring(Workspace.Interiors:FindFirstChildWhichIsA('Model')))

            localPlayer.Character.PrimaryPart.CFrame = Workspace.Interiors.Nursery:WaitForChild('GumballMachine'):WaitForChild('Root').CFrame + Vector3.new(
-8, 10, 0)
            localPlayer.Character:WaitForChild('HumanoidRootPart').Anchored = false

            localPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
            task.wait(2)
        end
        function self.CampSite()
            ReplicatedStorage.API['LocationAPI/SetLocation']:FireServer('MainMap', localPlayer, ClientData.get_data()[localPlayer.Name].LiveOpsMapType)
            task.wait(1)

            localPlayer.Character.PrimaryPart.CFrame = Workspace.CampingLocation.CFrame + Vector3.new(rng:NextInteger(1, 30), 5, rng:NextInteger(1, 30))

            localPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
            self.DeleteWater()
        end
        function self.BeachParty()
            ReplicatedStorage.API['LocationAPI/SetLocation']:FireServer('MainMap', localPlayer, ClientData.get_data()[localPlayer.Name].LiveOpsMapType)
            task.wait(1)

            localPlayer.Character.PrimaryPart.CFrame = Workspace.BeachPartyLocation.CFrame + Vector3.new(math.random(1, 30), 5, math.random(1, 30))

            localPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
            self.DeleteWater()
        end
        function self.Bonfire()
            ReplicatedStorage.API['LocationAPI/SetLocation']:FireServer('MainMap', localPlayer, ClientData.get_data()[localPlayer.Name].LiveOpsMapType)
            task.wait(1)

            local npc = workspace.HouseInteriors.furniture:FindFirstChild('summerfest_2025_bonfire_npc', true)

            if not npc then
                return
            end

            local location = npc.PrimaryPart.Position + Vector3.new(math.random(1, 15), 5, math.random(1, 15))

            localPlayer.Character:MoveTo(location)
            localPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
            self.DeleteWater()
        end
        function self.PlayGround(vec)
            localPlayer.Character:WaitForChild('HumanoidRootPart').Anchored = true

            SetLocationFunc('MainMap', 'Neighborhood/MainDoor', {})
            task.wait(1)
            Workspace.Interiors:WaitForChild(tostring(Workspace.Interiors:FindFirstChildWhichIsA('Model')))

            localPlayer.Character.PrimaryPart.CFrame = Workspace:WaitForChild('StaticMap'):WaitForChild('Park'):WaitForChild('Roundabout').PrimaryPart.CFrame + vec
            localPlayer.Character:WaitForChild('HumanoidRootPart').Anchored = false

            localPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
            self.DeleteWater()
        end
        function self.DownloadMainMap()
            local interiors = Workspace:WaitForChild('Interiors', 30)

            if not interiors then
                return
            end

            local isAlreadyOnMainMap = interiors:FindFirstChild('center_map_plot', true)

            if isAlreadyOnMainMap then
                return false
            end

            localPlayer.Character:WaitForChild('HumanoidRootPart').Anchored = true

            SetLocationFunc('MainMap', 'Neighborhood/MainDoor', {})
            task.wait(1)
            Workspace.Interiors:WaitForChild(tostring(Workspace.Interiors:FindFirstChildWhichIsA('Model')))

            localPlayer.Character:WaitForChild('HumanoidRootPart').Anchored = false

            localPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
            self.DeleteWater()

            return true
        end
        function self.MoonZone()
            localPlayer.Character:WaitForChild('HumanoidRootPart').Anchored = true

            SetLocationFunc('MoonInterior', 'MainDoor', {})
            task.wait(1)
            Workspace.Interiors:WaitForChild(tostring(Workspace.Interiors:FindFirstChildWhichIsA('Model')))

            localPlayer.Character:WaitForChild('HumanoidRootPart').Anchored = false

            localPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
        end
        function self.SkyCastle()
            localPlayer.Character:WaitForChild('HumanoidRootPart').Anchored = true

            local isAlreadyOnSkyCastle = Workspace:WaitForChild('Interiors'):FindFirstChild('SkyCastle')

            if not isAlreadyOnSkyCastle then
                SetLocationFunc('SkyCastle', 'MainDoor', {})
            end

            task.wait(1)
            Workspace.Interiors:WaitForChild(tostring(Workspace.Interiors:FindFirstChildWhichIsA('Model')))

            local skyCastle = Workspace.Interiors:FindFirstChild('SkyCastle')

            if not skyCastle then
                return
            end

            skyCastle:WaitForChild('Potions')
            skyCastle.Potions:WaitForChild('GrowPotion')
            skyCastle.Potions.GrowPotion:WaitForChild('Part')

            localPlayer.Character.PrimaryPart.CFrame = skyCastle.Potions.GrowPotion.Part.CFrame + Vector3.new(math.random(1, 5), 10, math.random(
-5, -1))
            localPlayer.Character:WaitForChild('HumanoidRootPart').Anchored = false

            localPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
        end
        function self.Neighborhood()
            localPlayer.Character:WaitForChild('HumanoidRootPart').Anchored = true

            SetLocationFunc('Neighborhood', 'MainDoor', {})
            task.wait(1)
            Workspace.Interiors:WaitForChild(tostring(Workspace.Interiors:FindFirstChildWhichIsA('Model')))

            if not Workspace.Interiors:FindFirstChild('Neighborhood!Fall') then
                return
            end

            Workspace.Interiors['Neighborhood!Fall']:WaitForChild('InteriorOrigin')

            localPlayer.Character.PrimaryPart.CFrame = Workspace.Interiors['Neighborhood!Fall'].InteriorOrigin.CFrame + Vector3.new(0, 
-10, 0)
            localPlayer.Character:WaitForChild('HumanoidRootPart').Anchored = false

            localPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
            self.DeleteWater()
        end

        return self
    end
    function __DARKLUA_BUNDLE_MODULES.g()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local RouterClient = Bypass('RouterClient')
        local InventoryDB = Bypass('InventoryDB')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('b')
        local self = {}
        local localPlayer = Players.LocalPlayer
        local buyItem = function(valuesTable, howManyToBuy)
            local hasMoney = Bypass('RouterClient').get('ShopAPI/BuyItem'):InvokeServer(valuesTable.category, valuesTable.id, {
                ['buy_count'] = howManyToBuy,
            })

            if hasMoney ~= 'success' then
                return false
            end

            return true
        end
        local getAmountToPurchase = function(valuesTable, currencyLimit)
            local currency = ClientData.get_data()[localPlayer.Name][valuesTable.currency_id] or ClientData.get_data()[localPlayer.Name]['money']

            if not currency then
                return 0, Utils.PrintDebug('NO CURRENCY ON PLAYER')
            end

            currency = currency - currencyLimit

            local count = 0

            while true do
                local moneyLeft = currency - valuesTable.cost

                if moneyLeft <= 0 then
                    break
                end
                if count >= 99 then
                    break
                end

                currency = moneyLeft
                count = count + 1

                task.wait()
            end

            return count
        end
        local getHowManyCanPurchase = function(valuesTable, maxAmount)
            local currency = ClientData.get_data()[localPlayer.Name][valuesTable.currency_id] or ClientData.get_data()[localPlayer.Name]['money']

            if not currency then
                return 0, Utils.PrintDebug('NO CURRENCY ON PLAYER')
            end
            if not valuesTable.cost then
                return 0, Utils.PrintDebug('Pet doesnt have Cost to it?')
            end

            local count = 0

            while true do
                local moneyLeft = currency - valuesTable.cost

                if moneyLeft <= 0 then
                    break
                end
                if count >= maxAmount or count >= 99 then
                    break
                end

                currency = moneyLeft
                count = count + 1

                task.wait()
            end

            Utils.PrintDebug(string.format('getHowManyCanPurchase: %s', tostring(count)))

            return count
        end
        local getItemInfoFromDatabase = function(nameId)
            assert(typeof(nameId) == 'string', 'getItemInfoFromDatabase: is not a string')

            for _, v in InventoryDB do
                for key, value in v do
                    if key == nameId then
                        return value
                    end
                end
            end

            return nil
        end
        local getAmountNeeded = function(nameId, maxAmount)
            local itemValues = getItemInfoFromDatabase(nameId)

            if not itemValues then
                return 0
            end

            local count = 0

            for _, item in ClientData.get_data()[localPlayer.Name].inventory[itemValues.category]do
                if nameId == item.id then
                    count = count + 1
                end
            end

            if count < maxAmount then
                return (maxAmount - count)
            end

            return 0
        end
        local buyPet = function(valuesTable, howManyToBuy)
            local hasMoney = RouterClient.get('ShopAPI/BuyItem'):InvokeServer(valuesTable.category, valuesTable.id, {
                ['buy_count'] = howManyToBuy,
            })

            if hasMoney ~= 'success' then
                return false
            end

            return true
        end
        local openBox = function(nameId)
            local itemValues = getItemInfoFromDatabase(nameId)

            if not itemValues then
                return
            end

            for _, v in ClientData.get_data()[localPlayer.Name].inventory[itemValues.category]do
                if v.id == nameId then
                    RouterClient.get('LootBoxAPI/ExchangeItemForReward'):InvokeServer(v['id'], v['unique'])
                    task.wait(0.1)
                end
            end
        end

        function self.StartBuyItems(itemToBuy)
            for _, value in ipairs(itemToBuy)do
                while true do
                    local itemValues = getItemInfoFromDatabase(value.NameId)

                    if not itemValues then
                        break
                    end

                    local amountNeeded = getAmountNeeded(value.NameId, value.MaxAmount)

                    if amountNeeded == 0 then
                        Utils.PrintDebug(string.format('has max amount of: %s skipping', tostring(value.NameId)))

                        break
                    end

                    local amountPurchase = getHowManyCanPurchase(itemValues, amountNeeded)

                    if amountPurchase == 0 then
                        Utils.PrintDebug(string.format('amount to purchase is: %s', tostring(amountPurchase)))

                        break
                    end
                    if not buyPet(itemValues, amountPurchase) then
                        Utils.PrintDebug('Has no money to buy more or something went wrong.')

                        break
                    end

                    task.wait()
                end
            end
        end
        function self.OpenItems(nameIdTable)
            assert(typeof(nameIdTable) == 'table', 'is not a table')

            for _, v in nameIdTable do
                openBox(v)
            end
        end
        function self.BuyGlormy()
            local stones = ClientData.get_data()[localPlayer.Name].social_stones_2025 or 0

            if stones <= 24 then
                return
            end

            RouterClient.get('SocialStonesAPI/AttemptExchange'):FireServer('pets', 'moon_2025_glormy_dolphin', 1)
        end
        function self.BuyItemWithCurrencyLimit(itemNameId, currencyLimit)
            while Bypass('ClientData').get_data()[localPlayer.Name].money >= currencyLimit do
                local itemValues = getItemInfoFromDatabase(itemNameId)

                if not itemValues then
                    break
                end

                local amountPurchase = getAmountToPurchase(itemValues, currencyLimit)

                if amountPurchase <= 0 then
                    break
                end
                if not buyItem(itemValues, amountPurchase) then
                    break
                end

                task.wait(1)
            end
        end

        return self
    end
    function __DARKLUA_BUNDLE_MODULES.h()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = (Bypass('ClientData'))
        local self = {}
        local localPlayer = Players.LocalPlayer
        local getFullgrownPets = function(mega)
            local fullgrownTable = {}

            if mega then
                for _, v in ClientData.get_data()[localPlayer.Name].inventory.pets do
                    if v.properties.age == 6 and v.properties.neon then
                        if not fullgrownTable[v.id] then
                            fullgrownTable[v.id] = {
                                ['count'] = 0,
                                ['unique'] = {},
                            }
                        end

                        do
                            local __DARKLUA_VAR = fullgrownTable[v.id]

                            __DARKLUA_VAR['count'] = __DARKLUA_VAR['count'] + 1
                        end

                        table.insert(fullgrownTable[v.id]['unique'], v.unique)

                        if fullgrownTable[v.id]['count'] >= 4 then
                            break
                        end
                    end
                end
            else
                for _, v in ClientData.get_data()[localPlayer.Name].inventory.pets do
                    if v.properties.age == 6 and not v.properties.neon and not v.properties.mega_neon then
                        if not fullgrownTable[v.id] then
                            fullgrownTable[v.id] = {
                                ['count'] = 0,
                                ['unique'] = {},
                            }
                        end

                        do
                            local __DARKLUA_VAR = fullgrownTable[v.id]

                            __DARKLUA_VAR['count'] = __DARKLUA_VAR['count'] + 1
                        end

                        table.insert(fullgrownTable[v.id]['unique'], v.unique)

                        if fullgrownTable[v.id]['count'] >= 4 then
                            break
                        end
                    end
                end
            end

            return fullgrownTable
        end

        function self.MakeMega(bool)
            repeat
                local fusionReady = {}
                local fullgrownTable = getFullgrownPets(bool)

                for _, valueTable in fullgrownTable do
                    if valueTable.count >= 4 then
                        table.insert(fusionReady, valueTable.unique[1])
                        table.insert(fusionReady, valueTable.unique[2])
                        table.insert(fusionReady, valueTable.unique[3])
                        table.insert(fusionReady, valueTable.unique[4])

                        break
                    end
                end

                if #fusionReady >= 4 then
                    ReplicatedStorage.API:FindFirstChild('PetAPI/DoNeonFusion'):InvokeServer({
                        unpack(fusionReady),
                    })
                    task.wait()
                end
            until #fusionReady <= 3
        end

        return self
    end
    function __DARKLUA_BUNDLE_MODULES.i()
        local ReplicatedStorage = game:GetService('ReplicatedStorage')
        local Players = game:GetService('Players')
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = (Bypass('ClientData'))
        local RouterClient = Bypass('RouterClient')
        local InventoryDB = Bypass('InventoryDB')
        local AllowOrDenyList = __DARKLUA_BUNDLE_MODULES.load('d')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('b')
        local self = {}
        local localPlayer = Players.LocalPlayer
        local eggList = {}
        local equipWhichPet = function(whichPet, petUnique)
            if whichPet == 1 then
                RouterClient.get('ToolAPI/Equip'):InvokeServer(petUnique, {
                    ['equip_as_last'] = false,
                })

                getgenv().petCurrentlyFarming1 = petUnique

                return true
            elseif whichPet == 2 then
                RouterClient.get('ToolAPI/Equip'):InvokeServer(petUnique, {
                    ['equip_as_last'] = true,
                })

                getgenv().petCurrentlyFarming2 = petUnique

                return true
            end

            return false
        end

        function self.GetAgeablePets()
            local ageablePets = {}
            local eggList = self.GetPetEggs()

            for _, pet in ClientData.get_data()[localPlayer.Name].inventory.pets do
                if table.find(AllowOrDenyList.Denylist, pet.id) then
                    continue
                end
                if table.find(eggList, pet.id) then
                    continue
                end
                if pet.properties.age == 6 or (pet.properties.neon and pet.properties.age == 6) or pet.properties.mega_neon then
                    continue
                end
                if table.find(ageablePets, pet.id) then
                    continue
                end

                table.insert(ageablePets, pet.id)
            end

            table.sort(ageablePets)

            return ageablePets
        end
        function self.GetAll()
            return ClientData.get_data()[localPlayer.Name].inventory
        end
        function self.TabId(tabId)
            local inventoryTable = {}

            for _, v in ClientData.get_data()[localPlayer.Name].inventory[tabId]do
                if table.find(AllowOrDenyList.Denylist, v.id) then
                    continue
                end
                if table.find(inventoryTable, v.id) then
                    continue
                end

                table.insert(inventoryTable, v.id)
            end

            table.sort(inventoryTable)

            return inventoryTable
        end
        function self.IsFarmingSelectedPet(hasProHandler)
            if hasProHandler then
                if not ClientData.get('pet_char_wrappers')[2] then
                    return
                end
                if getgenv().petCurrentlyFarming2 == ClientData.get('pet_char_wrappers')[2]['pet_unique'] then
                    return
                end

                RouterClient.get('ToolAPI/Equip'):InvokeServer(getgenv().petCurrentlyFarming2, {})
            end
            if not ClientData.get('pet_char_wrappers')[1] then
                return
            end
            if getgenv().petCurrentlyFarming1 == ClientData.get('pet_char_wrappers')[1]['pet_unique'] then
                return
            end

            RouterClient.get('ToolAPI/Equip'):InvokeServer(getgenv().petCurrentlyFarming1, {})
            task.wait(2)
        end
        function self.GetPetFriendship(petTable, whichPet)
            local level = 0
            local petUnique = nil

            for _, pet in ClientData.get_data()[localPlayer.Name].inventory.pets do
                if table.find(AllowOrDenyList.Denylist, pet.id) then
                    continue
                end
                if not table.find(petTable, pet.id) then
                    continue
                end
                if not pet.properties then
                    continue
                end
                if not pet.properties.friendship_level then
                    continue
                end
                if pet.properties.friendship_level > level then
                    if pet.unique == getgenv().petCurrentlyFarming1 then
                        continue
                    end
                    if pet.unique == getgenv().petCurrentlyFarming2 then
                        continue
                    end

                    level = pet.properties.friendship_level
                    petUnique = pet.unique
                end
            end

            if not petUnique then
                return false
            end

            equipWhichPet(whichPet, petUnique)

            return true
        end
        function self.GetHighestGrownPet(age, whichPet)
            local PetageCounter = age
            local isNeon = true
            local petFound = false

            while not petFound do
                for _, pet in ClientData.get_data()[localPlayer.Name].inventory.pets do
                    if table.find(AllowOrDenyList.Denylist, pet.id) then
                        continue
                    end
                    if pet.properties.age == PetageCounter and pet.properties.neon == isNeon then
                        if pet.unique == getgenv().petCurrentlyFarming1 then
                            continue
                        end
                        if pet.unique == getgenv().petCurrentlyFarming2 then
                            continue
                        end

                        equipWhichPet(whichPet, pet.unique)

                        return true
                    end
                end

                PetageCounter = PetageCounter - 1

                if PetageCounter <= 0 and isNeon then
                    PetageCounter = age
                    isNeon = nil
                elseif PetageCounter <= 0 and isNeon == nil then
                    return false
                end

                task.wait()
            end

            return false
        end
        function self.GetPetRarity()
            if not Utils.IsPetEquipped(1) then
                return nil
            end

            local farmingPetId = ClientData.get('pet_char_wrappers')[1]['pet_id']

            for _, petDB in InventoryDB.pets do
                if petDB.id == farmingPetId then
                    return petDB.rarity
                end
            end

            return nil
        end
        function self.PetRarityAndAge(rarity, age, whichPet)
            local PetageCounter = age
            local isNeon = true
            local petFound = false

            while not petFound do
                for _, pet in ClientData.get_data()[localPlayer.Name].inventory.pets do
                    for _, petDB in InventoryDB.pets do
                        if table.find(AllowOrDenyList.Denylist, pet.id) then
                            continue
                        end
                        if rarity == petDB.rarity and pet.id == petDB.id and pet.properties.age == PetageCounter and pet.properties.neon == isNeon then
                            if pet.unique == getgenv().petCurrentlyFarming1 then
                                continue
                            end
                            if pet.unique == getgenv().petCurrentlyFarming2 then
                                continue
                            end

                            equipWhichPet(whichPet, pet.unique)

                            return true
                        end
                    end
                end

                PetageCounter = PetageCounter - 1

                if PetageCounter <= 0 and isNeon then
                    PetageCounter = age
                    isNeon = nil
                elseif PetageCounter <= 0 and isNeon == nil then
                    return false
                end

                task.wait()
            end

            return false
        end
        function self.CheckForPetAndEquip(nameIds, whichPet)
            local level = 0
            local petUnique = nil

            for _, pet in ClientData.get_data()[localPlayer.Name].inventory['pets']do
                if table.find(nameIds, pet.id) then
                    if not pet.properties then
                        continue
                    end
                    if not pet.properties.friendship_level then
                        continue
                    end
                    if pet.properties.friendship_level > level then
                        if pet.unique == getgenv().petCurrentlyFarming1 then
                            continue
                        end
                        if pet.unique == getgenv().petCurrentlyFarming2 then
                            continue
                        end

                        level = pet.properties.friendship_level
                        petUnique = pet.unique
                    end
                end
            end

            if petUnique then
                equipWhichPet(whichPet, petUnique)

                return true
            end

            local PetageCounter = 6
            local isNeon = true
            local petFound = false

            while not petFound do
                for _, pet in ClientData.get_data()[localPlayer.Name].inventory.pets do
                    if table.find(nameIds, pet.id) and pet.properties.age == PetageCounter and pet.properties.neon == isNeon then
                        if pet.unique == getgenv().petCurrentlyFarming1 then
                            continue
                        end
                        if pet.unique == getgenv().petCurrentlyFarming2 then
                            continue
                        end

                        equipWhichPet(whichPet, pet.unique)

                        return true
                    end
                end

                PetageCounter = PetageCounter - 1

                if PetageCounter <= 0 and isNeon then
                    PetageCounter = 6
                    isNeon = nil
                elseif PetageCounter <= 0 and isNeon == nil then
                    return false
                end

                task.wait()
            end

            return false
        end
        function self.GetUniqueId(tabId, nameId)
            for _, v in ClientData.get_data()[localPlayer.Name].inventory[tabId]do
                if v.id == nameId then
                    return v.unique
                end
            end

            return nil
        end
        function self.IsPetInInventory(tabId, uniqueId)
            for _, v in ClientData.get_data()[localPlayer.Name].inventory[tabId]do
                if v.unique == uniqueId then
                    return true
                end
            end

            return false
        end
        function self.PriorityEgg(whichPet)
            for _, v in ipairs(getgenv().SETTINGS.HATCH_EGG_PRIORITY_NAMES)do
                for _, v2 in ClientData.get_data()[localPlayer.Name].inventory.pets do
                    if table.find(AllowOrDenyList.Denylist, v2.id) then
                        continue
                    end
                    if v == v2.id then
                        if v2.unique == getgenv().petCurrentlyFarming1 then
                            continue
                        end
                        if v2.unique == getgenv().petCurrentlyFarming2 then
                            continue
                        end

                        equipWhichPet(whichPet, v2.unique)

                        return true
                    end
                end
            end

            return false
        end
        function self.GetPetEggs()
            if #eggList >= 1 then
                return eggList
            end

            for i, v in InventoryDB.pets do
                if v.is_egg then
                    table.insert(eggList, v.id)
                end
            end

            return eggList
        end
        function self.GetNeonPet(whichPet)
            local Petage = 5
            local isNeon = true
            local found_pet = false

            while not found_pet do
                for _, v in ClientData.get_data()[localPlayer.Name].inventory.pets do
                    if table.find(AllowOrDenyList.Denylist, v.id) then
                        continue
                    end
                    if v.properties.age == Petage and v.properties.neon == isNeon then
                        if v.unique == getgenv().petCurrentlyFarming1 then
                            continue
                        end
                        if v.unique == getgenv().petCurrentlyFarming2 then
                            continue
                        end

                        equipWhichPet(whichPet, v.unique)

                        return true
                    end
                end

                if not found_pet then
                    Petage = Petage - 1

                    if Petage == 0 and isNeon == true then
                        return false
                    end
                end

                task.wait()
            end

            return false
        end
        function self.PriorityPet(whichPet)
            local Petage = 5
            local isNeon = true
            local found_pet = false

            while found_pet == false do
                for _, v in ipairs(getgenv().SETTINGS.PET_ONLY_PRIORITY_NAMES)do
                    for _, v2 in pairs(ClientData.get_data()[localPlayer.Name].inventory.pets)do
                        if v2.unique == getgenv().petCurrentlyFarming1 then
                            continue
                        end
                        if v2.unique == getgenv().petCurrentlyFarming2 then
                            continue
                        end
                        if table.find(AllowOrDenyList.Denylist, v2.id) then
                            continue
                        end
                        if v == v2.id and v2.properties.age == Petage and v2.properties.neon == isNeon then
                            equipWhichPet(whichPet, v2.unique)

                            return true
                        end
                    end
                end

                if found_pet == false then
                    Petage = Petage - 1

                    if Petage == 0 and isNeon == true then
                        Petage = 5
                        isNeon = nil
                    elseif Petage == 0 and isNeon == nil then
                        return false
                    end
                end

                task.wait()
            end

            return false
        end

        return self
    end
    function __DARKLUA_BUNDLE_MODULES.j()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local PetPotionEffectsDB = (require(ReplicatedStorage:WaitForChild('ClientDB'):WaitForChild('PetPotionEffectsDB')))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local RouterClient = Bypass('RouterClient')
        local Fusion = __DARKLUA_BUNDLE_MODULES.load('h')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('b')
        local GetInventory = __DARKLUA_BUNDLE_MODULES.load('i')
        local BulkPotion = {}
        local localPlayer = Players.LocalPlayer

        BulkPotion.SameUnqiue = {}
        BulkPotion.SameUnqiueCount = 0
        BulkPotion.StopAging = false
        BulkPotion.PetAge = 0
        BulkPotion.PetUniqueId = ''

        local waitForPetToEquip = function()
            local startTime = DateTime.now().UnixTimestamp
            local isStuck = false

            repeat
                task.wait()

                local isEquipped = ClientData.get('pet_char_wrappers')[1]
                local currentTime = DateTime.now().UnixTimestamp

                if currentTime - startTime >= 10 then
                    isStuck = true
                end
            until isEquipped or isStuck

            if isStuck then
                Utils.PrintDebug('Unable to equip pet')

                return false
            end

            Utils.PrintDebug('Pet is Equipped')

            return true
        end
        local getMaxMega = function(petId)
            local count = 0

            for _, v in ClientData.get_data()[localPlayer.Name].inventory.pets do
                if v.id == petId and v.properties.mega_neon then
                    count = count + 1
                end
            end

            return count
        end
        local getPotionUniques = function(nameId)
            local potions = {}
            local amountNeeded = PetPotionEffectsDB[nameId].multi_use_count(ClientData.get('pet_char_wrappers')[1], ClientData.get_data()[localPlayer.Name].inventory.pets[ClientData.get('pet_char_wrappers')[1].pet_unique])

            if amountNeeded <= 0 then
                return potions
            end

            for _, v in ClientData.get_data()[localPlayer.Name].inventory.food do
                if v.id == nameId then
                    table.insert(potions, v.unique)

                    amountNeeded = amountNeeded - 1

                    if amountNeeded <= 0 then
                        break
                    end
                end
            end

            return potions
        end
        local createPotionObject = function(potionTable)
            local petIndex = ClientData.get('pet_char_wrappers')[1]
            local petUnique = (petIndex and {
                (petIndex.pet_unique),
            } or {nil})[1]

            if not petUnique then
                return false
            end
            if #potionTable == 1 then
                return RouterClient.get('PetObjectAPI/CreatePetObject'):InvokeServer('__Enum_PetObjectCreatorType_2', {
                    ['pet_unique'] = petUnique,
                    ['unique_id'] = potionTable[1],
                })
            elseif #potionTable >= 2 then
                local newpotionTable = table.clone(potionTable)

                table.remove(newpotionTable, 1)

                return RouterClient.get('PetObjectAPI/CreatePetObject'):InvokeServer('__Enum_PetObjectCreatorType_2', {
                    ['pet_unique'] = petUnique,
                    ['unique_id'] = potionTable[1],
                    ['additional_consume_uniques'] = newpotionTable,
                })
            end

            return false
        end
        local hasAgeUpPotion = function()
            for _, v in ClientData.get_data()[localPlayer.Name].inventory.food do
                if v.id == 'pet_age_potion' or v.id == 'tiny_pet_age_potion' then
                    return true
                end
            end

            return false
        end
        local formatTableToDict = function(tableToFormat)
            Utils.PrintDebug('[DEBUG] formatting table')

            local mytable = {}

            for _, v in tableToFormat do
                table.insert(mytable, {
                    NameId = v,
                    MaxAmount = 666,
                })
            end

            return mytable
        end

        function BulkPotion.IsPetNormal(petName)
            BulkPotion.PetAge = 0
            BulkPotion.PetUniqueId = ''

            for _, v in ClientData.get_data()[localPlayer.Name].inventory.pets do
                if v.id == petName and v.id ~= 'practice_dog' and v.properties.age ~= 6 and not v.properties.mega_neon then
                    if BulkPotion.PetAge < v.properties.age then
                        BulkPotion.PetAge = v.properties.age
                        BulkPotion.PetUniqueId = v.unique
                    end
                end
            end

            if BulkPotion.PetUniqueId ~= '' then
                RouterClient.get('ToolAPI/Unequip'):InvokeServer(BulkPotion.PetUniqueId, {
                    ['use_sound_delay'] = true,
                })
                task.wait(1)
                RouterClient.get('ToolAPI/Equip'):InvokeServer(BulkPotion.PetUniqueId, {
                    ['use_sound_delay'] = true,
                })
                waitForPetToEquip()
                Utils.PrintDebug(string.format('pet age: %s, and NORMAL', tostring(BulkPotion.PetAge)))

                return true
            end

            return false
        end
        function BulkPotion.IsPetNeon(petName)
            BulkPotion.PetAge = 0
            BulkPotion.PetUniqueId = ''

            for _, v in ClientData.get_data()[localPlayer.Name].inventory.pets do
                if v.id == petName and v.id ~= 'practice_dog' and v.properties.age ~= 6 and v.properties.neon and not v.properties.mega_neon then
                    if BulkPotion.PetAge < v.properties.age then
                        BulkPotion.PetAge = v.properties.age
                        BulkPotion.PetUniqueId = v.unique
                    end
                end
            end

            if BulkPotion.PetUniqueId ~= '' then
                RouterClient.get('ToolAPI/Unequip'):InvokeServer(BulkPotion.PetUniqueId, {
                    ['use_sound_delay'] = true,
                })
                task.wait(1)
                RouterClient.get('ToolAPI/Equip'):InvokeServer(BulkPotion.PetUniqueId, {
                    ['use_sound_delay'] = true,
                })
                waitForPetToEquip()
                Utils.PrintDebug(string.format('pet age: %s and NEON', tostring(BulkPotion.PetAge)))

                return true
            end
            if BulkPotion.IsPetNormal(petName) then
                return true
            else
                return false
            end
        end
        function BulkPotion.IsSameUnique()
            for _, v in ClientData.get_data()[localPlayer.Name].inventory.food do
                if v.id == 'pet_age_potion' or v.id == 'tiny_pet_age_potion' then
                    if table.find(BulkPotion.SameUnqiue, v.unique) then
                        Utils.PrintDebug('has same unqiue age up potion')

                        BulkPotion.SameUnqiueCount = BulkPotion.SameUnqiueCount + 1

                        if BulkPotion.SameUnqiueCount >= 15 then
                            Utils.PrintDebug('\u{26a0}\u{fe0f} SAME POTION HAS BEEN TRIED 15 TIMES. MUST BE STUCK \u{26a0}\u{fe0f}')

                            BulkPotion.SameUnqiueCount = 0
                            BulkPotion.SameUnqiue = {}
                        end

                        task.wait(1)

                        return true
                    end
                end
            end

            BulkPotion.SameUnqiueCount = 0
            BulkPotion.SameUnqiue = {}

            return false
        end
        function BulkPotion.IsEgg()
            local EquipTimeout = 0
            local hasPetChar = false

            repeat
                task.wait(1)

                hasPetChar = ClientData.get('pet_char_wrappers')[1] and ClientData.get('pet_char_wrappers')[1]['char'] and true or false
                EquipTimeout = EquipTimeout + 1
            until hasPetChar or EquipTimeout >= 30

            if EquipTimeout >= 30 then
                Utils.PrintDebug('\u{26a0}\u{fe0f} Waited too long for Equipping pet so Stopping aging \u{26a0}\u{fe0f}')

                BulkPotion.StopAging = true

                return true
            end

            local isEgg = table.find(GetInventory.GetPetEggs(), ClientData.get('pet_char_wrappers')[1]['pet_id']) and true or false

            return isEgg
        end
        function BulkPotion.FeedAgePotion()
            if BulkPotion.IsEgg() then
                return
            end
            if BulkPotion.IsSameUnique() then
                return
            end

            BulkPotion.SameUnqiueCount = 0

            local potionUniques

            potionUniques = getPotionUniques('pet_age_potion')

            if #potionUniques <= 0 then
                table.clear(potionUniques)

                potionUniques = getPotionUniques('tiny_pet_age_potion')
            end
            if #potionUniques <= 0 then
                return
            end

            BulkPotion.SameUnqiue = potionUniques

            Utils.PrintDebug(string.format('USING POTIONS: %s', tostring(#potionUniques)))
            Utils.PrintDebug(createPotionObject(potionUniques))
            task.wait(2)

            local UpdateTextEvent = (ReplicatedStorage:WaitForChild('UpdateTextEvent'))

            UpdateTextEvent:Fire()

            return
        end
        function BulkPotion.AgeAllPetsOfSameName(petId, maxAmount)
            if getgenv().SETTINGS.PET_AUTO_FUSION then
                Fusion.MakeMega(false)
                task.wait(1)
                Fusion.MakeMega(true)
                task.wait(1)
            end

            local result = getMaxMega(petId)

            if result >= maxAmount then
                return false
            end

            local hasPet = BulkPotion.IsPetNeon(petId)

            if not hasPet then
                return false
            end

            while true do
                if BulkPotion.IsEgg() then
                    return false
                end
                if ClientData.get('pet_char_wrappers')[1]['pet_progression']['age'] >= 6 then
                    break
                end
                if not hasAgeUpPotion() then
                    BulkPotion.StopAging = true

                    return false
                end

                BulkPotion.FeedAgePotion()
                task.wait()
            end

            if BulkPotion.StopAging then
                return false
            end

            BulkPotion.AgeAllPetsOfSameName(petId, maxAmount)

            return false
        end
        function BulkPotion.StartAgingPets(petsTable)
            assert(typeof(petsTable) == 'table', 'is not a table')

            if typeof(petsTable[1]) ~= 'table' then
                petsTable = formatTableToDict(petsTable)
            end

            for _, value in ipairs(petsTable)do
                if BulkPotion.StopAging then
                    Utils.PrintDebug('stop aging is true, so stopped')

                    return
                end

                local result = getMaxMega(value.NameId)

                if not value.MaxAmount then
                    value.MaxAmount = 666
                end
                if result >= value.MaxAmount then
                    return false, Utils.PrintDebug(string.format('Pet: %s has maxed Amount: %s', tostring(value.NameId), tostring(result)))
                end

                BulkPotion.AgeAllPetsOfSameName(value.NameId, value.MaxAmount)
            end

            return
        end

        return BulkPotion
    end
    function __DARKLUA_BUNDLE_MODULES.k()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local VirtualUser = cloneref(game:GetService('VirtualUser'))
        local Players = cloneref(game:GetService('Players'))
        local StarterGui = cloneref(game:GetService('StarterGui'))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local RouterClient = Bypass('RouterClient')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('b')
        local Furniture = __DARKLUA_BUNDLE_MODULES.load('c')
        local Trade = __DARKLUA_BUNDLE_MODULES.load('e')
        local Teleport = __DARKLUA_BUNDLE_MODULES.load('f')
        local BuyItem = __DARKLUA_BUNDLE_MODULES.load('g')
        local BulkPotion = __DARKLUA_BUNDLE_MODULES.load('j')
        local Fusion = __DARKLUA_BUNDLE_MODULES.load('h')
        local self = {}
        local localPlayer = Players.LocalPlayer
        local rng = Random.new()
        local PlayerGui = localPlayer:WaitForChild('PlayerGui')
        local DialogApp = (PlayerGui:WaitForChild('DialogApp'))
        local NewsApp = (PlayerGui:WaitForChild('NewsApp'))
        local pickColorConn = nil
        local pickColorTutorial = function()
            local colorButton = (DialogApp.Dialog.ThemeColorDialog:WaitForChild('Info'):WaitForChild('Response'):WaitForChild('ColorTemplate'))

            if not colorButton then
                return
            end

            Utils.FireButton(colorButton)
            task.wait(3)

            local doneButton = (DialogApp.Dialog.ThemeColorDialog:WaitForChild('Buttons'):WaitForChild('ButtonTemplate'))

            if not doneButton then
                return
            end

            Utils.FireButton(doneButton)
            Utils.PrintDebug('PICKED COLOR')
        end
        local isPlayersInGame = function(playerList)
            for _, player in Players:GetPlayers()do
                if table.find(playerList, player.Name) then
                    return true
                end
            end

            return false
        end
        local loopFurniture = function(dict)
            local updateWithNewKey = false

            for key, value in dict do
                if dict[key] == 'nil' then
                    updateWithNewKey = true

                    Utils.PrintDebug(string.format('\u{1f4b8} No key: %s value: %s , so trying to buy it \u{1f4b8}', tostring(key), tostring(value)))
                    Furniture.BuyFurniture(key)
                    task.wait(1)
                end
            end

            if updateWithNewKey then
                Furniture.GetFurnituresKey()
            end
        end
        local findHomeButtonAndClick = function()
            local homeFrame = (DialogApp:FindFirstChild('Home', true))

            if not homeFrame or not homeFrame.Visible then
                return
            end

            local button = (homeFrame:WaitForChild('Button', 6))

            if not button then
                return
            end

            Utils.FireButton(button)
        end

        function self.Init()
            DialogApp.Dialog.ThemeColorDialog:GetPropertyChangedSignal('Visible'):Connect(pickColorTutorial)
            DialogApp.Dialog.SpawnChooserDialog:GetPropertyChangedSignal('Visible'):Connect(findHomeButtonAndClick)
            Players.PlayerAdded:Connect(function(player)
                player.CharacterAdded:Connect(function(character)
                    if table.find(getgenv().SETTINGS.TRADE_COLLECTOR_NAME, localPlayer.Name) then
                        return
                    end
                    if not table.find(getgenv().SETTINGS.TRADE_COLLECTOR_NAME, player.Name) then
                        return
                    end

                    local humanoidRootPart = character:WaitForChild('HumanoidRootPart', 120)

                    if not humanoidRootPart then
                        return
                    end

                    task.wait(rng:NextNumber(1, 20))

                    if getgenv().SETTINGS.ENABLE_TRASH_COLLECTOR then
                        getgenv().SETTINGS.ENABLE_TRADE_COLLECTOR = false

                        Utils.PrintDebug('TRADING trash collector')
                        Trade.TradeTrashCollector(getgenv().SETTINGS.TRASH_COLLECTOR_NAMES)
                    elseif getgenv().SETTINGS.ENABLE_TRADE_COLLECTOR then
                        Trade.TradeCollector(getgenv().SETTINGS.TRADE_COLLECTOR_NAME)
                    end
                end)
            end)

            local queueOnTeleport = (syn and syn.queue_on_teleport) or queue_on_teleport

            if queueOnTeleport then
                queueOnTeleport('            game:Shutdown()\n        ')
            end
        end
        function self.Start()
            setfpscap(getgenv().SETTINGS.SET_FPS)
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Captures, false)

            if DialogApp.Dialog.ThemeColorDialog.Visible then
                Utils.PrintDebug('picking color')
                pickColorTutorial()

                if pickColorConn then
                    pickColorConn:Disconnect()
                end
            end
            if NewsApp.Enabled then
                Utils.PrintDebug('NEWSAPP ENABLED')

                local AbsPlay = (NewsApp:WaitForChild('EnclosingFrame'):WaitForChild('MainFrame'):WaitForChild('Buttons'):WaitForChild('PlayButton'))

                Utils.FireButton(AbsPlay)
                Utils.PrintDebug('NEWSAPP CLICKED')
            end

            findHomeButtonAndClick()

            if not localPlayer.Character then
                Utils.PrintDebug('NO CHARACTER SO WAITING')
                localPlayer.CharacterAdded:Wait()
            end

            RouterClient.get('HousingAPI/SetDoorLocked'):InvokeServer(true)
            Utils.PlaceFLoorUnderPlayer()
            RouterClient.get('TeamAPI/ChooseTeam'):InvokeServer('Babies', {
                ['dont_send_back_home'] = true,
            })
            Utils.PrintDebug('turned to baby')

            if not localPlayer.Character then
                Utils.PrintDebug('NO CHARACTER SO WAITING')
                localPlayer.CharacterAdded:Wait()
            end

            local furnitureKeys = Furniture.GetFurnituresKey()

            loopFurniture(furnitureKeys)
            Utils.PrintDebug(string.format('Bed: %s \u{1f6cf}\u{fe0f}', tostring(furnitureKeys.basiccrib)))
            Utils.PrintDebug(string.format('Shower: %s \u{1f6c1}', tostring(furnitureKeys.stylishshower)))
            Utils.PrintDebug(string.format('Piano: %s \u{1f3b9}', tostring(furnitureKeys.piano)))
            Utils.PrintDebug(string.format('Normal Lure: %s \u{1f4e6}', tostring(furnitureKeys.lures_2023_normal_lure)))
            Utils.PrintDebug(string.format('LitterBox: %s \u{1f6bd}', tostring(furnitureKeys.ailments_refresh_2024_litter_box)))

            local baitUnique = Utils.FindBait()

            Utils.PrintDebug(string.format('baitUnique: %s \u{1f36a}', tostring(baitUnique)))
            Utils.PlaceBaitOrPickUp(furnitureKeys.lures_2023_normal_lure, baitUnique)
            task.wait(1)
            Utils.PlaceBaitOrPickUp(furnitureKeys.lures_2023_normal_lure, baitUnique)
            task.wait(1)
            Utils.UnEquipAllPets()
            Teleport.PlaceFloorAtFarmingHome()
            Teleport.PlaceFloorAtCampSite()
            Teleport.PlaceFloorAtBeachParty()

            for _, v in getconnections((localPlayer.Idled))do
                v:Disable()
            end

            localPlayer.Idled:Connect(function()
                VirtualUser:ClickButton2(Vector2.new())
            end)

            local UpdateTextEvent = (ReplicatedStorage:WaitForChild('UpdateTextEvent'))

            UpdateTextEvent:Fire()

            if getgenv().BUY_BEFORE_FARMING then
                localPlayer:SetAttribute('StopFarmingTemp', true)
                BuyItem.StartBuyItems(getgenv().BUY_BEFORE_FARMING)
            end
            if getgenv().OPEN_ITEMS_BEFORE_FARMING then
                localPlayer:SetAttribute('StopFarmingTemp', true)
                BuyItem.OpenItems(getgenv().OPEN_ITEMS_BEFORE_FARMING)
            end
            if getgenv().AGE_PETS_BEFORE_FARMING then
                localPlayer:SetAttribute('StopFarmingTemp', true)
                BulkPotion.StartAgingPets(getgenv().AGE_PETS_BEFORE_FARMING)
                Utils.PrintDebug('DONE aging pets')
            end
            if getgenv().SETTINGS.PET_AUTO_FUSION then
                Fusion.MakeMega(false)
                Fusion.MakeMega(true)
            end
            if getgenv().SETTINGS.ENABLE_TRASH_COLLECTOR and isPlayersInGame(getgenv().SETTINGS.TRASH_COLLECTOR_NAMES) then
                getgenv().SETTINGS.ENABLE_TRADE_COLLECTOR = false

                Utils.PrintDebug('Trading TRASH collector')
                Trade.TradeTrashCollector(getgenv().SETTINGS.TRASH_COLLECTOR_NAMES)
            elseif getgenv().SETTINGS.ENABLE_TRADE_COLLECTOR and isPlayersInGame(getgenv().SETTINGS.TRADE_COLLECTOR_NAME) then
                Utils.PrintDebug('Trading MULE collector')
                Trade.TradeCollector(getgenv().SETTINGS.TRADE_COLLECTOR_NAME)
            end

            localPlayer:SetAttribute('StopFarmingTemp', false)
            RouterClient.get('CodeRedemptionAPI/AttemptRedeemCode'):InvokeServer('VISITS')
        end

        return self
    end
    function __DARKLUA_BUNDLE_MODULES.l()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local RouterClient = Bypass('RouterClient')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('b')
        local self = {}
        local localPlayer = Players.LocalPlayer
        local PlayerGui = localPlayer:WaitForChild('PlayerGui')
        local DailyLoginApp = PlayerGui:WaitForChild('DailyLoginApp')
        local DailyRewardTable = {
            [9] = 'reward_1',
            [30] = 'reward_2',
            [90] = 'reward_3',
            [140] = 'reward_4',
            [180] = 'reward_5',
            [210] = 'reward_6',
            [230] = 'reward_7',
            [280] = 'reward_8',
            [300] = 'reward_9',
            [320] = 'reward_10',
            [360] = 'reward_11',
            [400] = 'reward_12',
            [460] = 'reward_13',
            [500] = 'reward_14',
            [550] = 'reward_15',
            [600] = 'reward_16',
            [660] = 'reward_17',
        }
        local DailyRewardTable2 = {
            [9] = 'reward_1',
            [65] = 'reward_2',
            [120] = 'reward_3',
            [180] = 'reward_4',
            [225] = 'reward_5',
            [280] = 'reward_6',
            [340] = 'reward_7',
            [400] = 'reward_8',
            [450] = 'reward_9',
            [520] = 'reward_10',
            [600] = 'reward_11',
            [660] = 'reward_12',
        }
        local grabDailyReward = function()
            Utils.PrintDebug('getting daily rewards')

            local Daily = ClientData.get('daily_login_manager')

            if Daily.prestige % 2 == 0 then
                for i, v in pairs(DailyRewardTable)do
                    if i < Daily.stars or i == Daily.stars then
                        if not Daily.claimed_star_rewards[v] then
                            Utils.PrintDebug('grabbing dialy reward!')
                            RouterClient.get('DailyLoginAPI/ClaimStarReward'):InvokeServer(v)
                        end
                    end
                end
            else
                for i, v in pairs(DailyRewardTable2)do
                    if i < Daily.stars or i == Daily.stars then
                        if not Daily.claimed_star_rewards[v] then
                            Utils.PrintDebug('grabbing dialy reward!')
                            RouterClient.get('DailyLoginAPI/ClaimStarReward'):InvokeServer(v)
                        end
                    end
                end
            end
        end
        local dailyLoginAppClick = function()
            Utils.PrintDebug('Clicking on Daily login app')

            local frame = (DailyLoginApp and {
                (DailyLoginApp:FindFirstChild('Frame')),
            } or {nil})[1]
            local body = (frame and {
                (frame:FindFirstChild('Body')),
            } or {nil})[1]
            local buttons = (body and {
                (body:FindFirstChild('Buttons')),
            } or {nil})[1]

            if not buttons then
                return
            end

            for _, v in buttons:GetDescendants()do
                if v:IsA('TextLabel') then
                    if v.Text == 'CLOSE' and v.Parent and v.Parent.Parent then
                        local button = (v.Parent.Parent)

                        Utils.PrintDebug('pressed Close on daily login')
                        Utils.FireButton(button)
                        task.wait(1)
                        grabDailyReward()
                    elseif v.Text == 'CLAIM!' and v.Parent and v.Parent.Parent then
                        local button = (v.Parent.Parent)

                        Utils.PrintDebug('pressed claim on daily login')
                        Utils.FireButton(button)
                        task.wait(1)
                        Utils.FireButton(button)
                        grabDailyReward()
                    end
                end
            end
        end

        function self.Init()
            self.DailyClaimConnection = DailyLoginApp:GetPropertyChangedSignal('Enabled'):Connect(function(
            )
                dailyLoginAppClick()

                if self.DailyClaimConnection then
                    self.DailyClaimConnection:Disconnect()
                end
            end)
        end
        function self.Start()
            dailyLoginAppClick()
        end

        return self
    end
    function __DARKLUA_BUNDLE_MODULES.m()
        local Players = cloneref(game:GetService('Players'))
        local Utils = __DARKLUA_BUNDLE_MODULES.load('b')
        local Trade = __DARKLUA_BUNDLE_MODULES.load('e')
        local Teleport = __DARKLUA_BUNDLE_MODULES.load('f')
        local self = {}
        local localPlayer = Players.LocalPlayer
        local PlayerGui = localPlayer:WaitForChild('PlayerGui')
        local DialogApp = (PlayerGui:WaitForChild('DialogApp'))
        local MinigameRewardsApp = (PlayerGui:WaitForChild('MinigameRewardsApp'))
        local MinigameInGameApp = (PlayerGui:WaitForChild('MinigameInGameApp'))
        local TradeApp = (PlayerGui:WaitForChild('TradeApp'))
        local certificateConn
        local starterPackAppConn
        local getNormalDialogTextLabel = function()
            local Dialog = (DialogApp and {
                (DialogApp:FindFirstChild('Dialog')),
            } or {nil})[1]
            local NormalDialog = (Dialog and {
                (Dialog:FindFirstChild('NormalDialog')),
            } or {nil})[1]
            local Info = (NormalDialog and {
                (NormalDialog:FindFirstChild('Info')),
            } or {nil})[1]

            if not Info then
                return nil
            end

            local TextLabel = (Info:FindFirstChild('TextLabel'))

            if not TextLabel then
                return nil
            end

            return TextLabel
        end
        local onTextChangedNormalDialog = function()
            local TextLabel = getNormalDialogTextLabel()

            if not TextLabel then
                return
            end

            Utils.PrintDebug(string.format('onTextChangedNormalDialog: %s', tostring(TextLabel.Text)))

            if TextLabel.Text:match('Be careful when trading') then
                Utils.FindButton('Okay')
            elseif TextLabel.Text:match('This trade seems unbalanced') then
                Utils.FindButton('Next')
            elseif TextLabel.Text:match('Social Stones!') then
                Utils.FindButton('Okay')
            elseif TextLabel.Text:match("Today's 2x Code is") then
                Utils.FindButton('Awesome!')
                pcall(function()
                    local message = TextLabel.Text:split("Today's 2x Code is")
                    local code = message[2]:split('- Use at the Safety Hub!')[1]:gsub('%s+', '')

                    Utils.FireRedeemCode(code)
                end)
            elseif TextLabel.Text:match('sent you a trade request') then
                Utils.FindButton('Accept')
            elseif TextLabel.Text:match('Trade request from') then
                Utils.FindButton('Okay')
            elseif TextLabel.Text:match('Any items lost') then
                Utils.FindButton('I understand')
            elseif TextLabel.Text:match('4.5%% Legendary') then
                Utils.FindButton('Okay')
            elseif TextLabel.Text:match('You have been awarded') then
                Utils.FindButton('Awesome!')
            elseif TextLabel.Text:match('Thanks for subscribing!') then
                Utils.FindButton('Okay')
            elseif TextLabel.Text:match("Let's start the day") then
                Utils.FindButton('Start')
            elseif TextLabel.Text:match('Are you subscribed') then
                Utils.FindButton('Yes')
            elseif TextLabel.Text:match('your inventory!') then
                Utils.FindButton('Awesome!')
            elseif TextLabel.Text:match("You've chosen this") then
                Utils.FindButton('Yes')
            elseif TextLabel.Text:match('You can change this option') then
                Utils.FindButton('Okay')
            elseif TextLabel.Text:match('You have enough') then
                Utils.FindButton('Okay')
            elseif TextLabel.Text:match('Thanks for') then
                Utils.FindButton('Okay')
            elseif TextLabel.Text:match('Right now') then
                Utils.FindButton('Next')
            elseif TextLabel.Text:match('You can customize it') then
                Utils.FindButton('Start')
            elseif TextLabel.Text:match('Your subscription') then
                Utils.FindButton('Okay!')
            elseif TextLabel.Text:match('You have been refunded') then
                Utils.FindButton('Awesome!')
            elseif TextLabel.Text:match("You can't afford this") then
                Utils.FindButton('Okay')
            elseif TextLabel.Text:match('mailbox') then
                Utils.FindButton('Okay')
            elseif TextLabel.Text:match('Pay 1500 Bucks') then
                Utils.FindButton('Yes')
            elseif TextLabel.Text:match("You've completed the entire Homepass!") then
                Utils.FindButton('Okay')
            elseif TextLabel.Text:match('The Homepass has been restarted') then
                Utils.FindButton('Okay')
            end
        end
        local removeGameOverButton = function(screenGuiName)
            task.wait(0.1)

            local guiFrame = localPlayer:WaitForChild('PlayerGui'):FindFirstChild(screenGuiName)

            if not guiFrame then
                return
            end

            local body = guiFrame:FindFirstChild('Body')
            local button = (body and {
                (body:WaitForChild('Button', 10)),
            } or {nil})[1]
            local face = (button and {
                (button:WaitForChild('Face', 10)),
            } or {nil})[1]

            if not (button and face) then
                return
            end

            for _, v in pairs(button:GetDescendants())do
                if v:IsA('TextLabel') and v.Text == 'NICE!' and v.Parent then
                    local guiButton = (v.Parent.Parent)

                    Utils.FireButton(guiButton)

                    return
                end
            end
        end
        local onTextChangedMiniGame = function()
            local hasStartedFarming = localPlayer:GetAttribute('hasStartedFarming')

            if getgenv().SETTINGS.EVENT and getgenv().SETTINGS.EVENT.DO_MINIGAME and hasStartedFarming then
                Utils.FindButton('No')
            else
                Utils.FindButton('No')
            end
        end
        local friendTradeAccept = function()
            local dialogFrame = (DialogApp:WaitForChild('Dialog'))

            if not dialogFrame.Visible then
                return
            end

            local HeaderDialog = (dialogFrame:WaitForChild('HeaderDialog', 10))

            if not HeaderDialog then
                return
            end

            HeaderDialog:GetPropertyChangedSignal('Visible'):Connect(function()
                if not HeaderDialog.Visible then
                    return
                end

                local Info = HeaderDialog:WaitForChild('Info', 10)

                if not Info then
                    return
                end

                local TextLabel = (Info:WaitForChild('TextLabel', 10))

                if not TextLabel then
                    return
                end

                TextLabel:GetPropertyChangedSignal('Text'):Connect(function()
                    if not TextLabel.Visible then
                        return
                    end
                    if TextLabel.Text:match('sent you a trade request') then
                        Utils.FindButton('Accept', 'HeaderDialog')
                    end
                end)
            end)
        end

        function self.Init()
            local Dialog = (DialogApp:WaitForChild('Dialog'))

            Dialog:GetPropertyChangedSignal('Visible'):Connect(friendTradeAccept)
            Dialog:WaitForChild('FriendAfterTradeDialog'):GetPropertyChangedSignal('Visible'):Connect(function(
            )
                if not Dialog.FriendAfterTradeDialog.Visible then
                    return
                end

                local exitButton = (Dialog:WaitForChild('ExitButton', 60))

                task.wait(1)

                if not exitButton or not exitButton.Visible then
                    return
                end

                Utils.FireButton(exitButton)
            end)

            local normalDialog = (Dialog:WaitForChild('NormalDialog'))

            normalDialog:GetPropertyChangedSignal('Visible'):Connect(function()
                if normalDialog.Visible then
                    normalDialog:WaitForChild('Info')
                    normalDialog.Info:WaitForChild('TextLabel')
                    normalDialog.Info.TextLabel:GetPropertyChangedSignal('Text'):Connect(onTextChangedNormalDialog)
                end
            end)
            Dialog.ChildAdded:Connect(function(Child)
                if Child.Name ~= 'NormalDialog' then
                    return
                end

                Child:GetPropertyChangedSignal('Visible'):Connect(function()
                    local myChild = Child

                    if not myChild.Visible then
                        return
                    end

                    myChild:WaitForChild('Info')
                    myChild.Info:WaitForChild('TextLabel')
                    myChild.Info.TextLabel:GetPropertyChangedSignal('Text'):Connect(onTextChangedNormalDialog)
                end)
            end)

            local CertificateApp = (PlayerGui:WaitForChild('CertificateApp'))

            certificateConn = CertificateApp:GetPropertyChangedSignal('Enabled'):Connect(function(
            )
                if not CertificateApp.Enabled then
                    return
                end
                if not CertificateApp:WaitForChild('Content', 10) then
                    return
                end
                if not CertificateApp.Content:WaitForChild('ExitButton', 10) then
                    return
                end

                Utils.FireButton(CertificateApp.Content.ExitButton)

                if certificateConn then
                    certificateConn:Disconnect()
                end
            end)

            local FTUEStarterPackApp = (PlayerGui:WaitForChild('FTUEStarterPackApp'))

            starterPackAppConn = FTUEStarterPackApp.Popups.Default:GetPropertyChangedSignal('Visible'):Connect(function(
            )
                if not FTUEStarterPackApp.Popups.Default.Visible then
                    return
                end
                if not FTUEStarterPackApp.Popups.Default:WaitForChild('ExitButton', 10) then
                    return
                end

                Utils.FireButton(FTUEStarterPackApp.Popups.Default.ExitButton)

                if starterPackAppConn then
                    starterPackAppConn:Disconnect()
                end
            end)

            DialogApp.Dialog.NormalDialog:GetPropertyChangedSignal('Visible'):Connect(function(
            )
                if not DialogApp.Dialog.NormalDialog.Visible then
                    return
                end

                DialogApp.Dialog.NormalDialog:WaitForChild('Info')
                DialogApp.Dialog.NormalDialog.Info:WaitForChild('TextLabel')
                DialogApp.Dialog.NormalDialog.Info.TextLabel:GetPropertyChangedSignal('Text'):Connect(function(
                )
                    if DialogApp.Dialog.NormalDialog.Info.TextLabel.Text:match('Treasure Defense is starting') then
                        onTextChangedMiniGame()
                    elseif DialogApp.Dialog.NormalDialog.Info.TextLabel.Text:match('Cannon Circle is starting') then
                        onTextChangedMiniGame()
                    elseif DialogApp.Dialog.NormalDialog.Info.TextLabel.Text:match('invitation') then
                        localPlayer:Kick()
                        game:Shutdown()
                    elseif DialogApp.Dialog.NormalDialog.Info.TextLabel.Text:match('You found a') then
                        Utils.FindButton('Okay')
                    end
                end)
            end)
            DialogApp.Dialog.ChildAdded:Connect(function(child)
                if child.Name ~= 'NormalDialog' then
                    return
                end

                local NormalDialogChild = child

                NormalDialogChild:GetPropertyChangedSignal('Visible'):Connect(function(
                )
                    if not NormalDialogChild.Visible then
                        return
                    end

                    NormalDialogChild:WaitForChild('Info')
                    NormalDialogChild.Info:WaitForChild('TextLabel')
                    NormalDialogChild.Info.TextLabel:GetPropertyChangedSignal('Text'):Connect(function(
                    )
                        if NormalDialogChild.Info.TextLabel.Text:match('Treasure Defense is starting') then
                            onTextChangedMiniGame()
                        elseif NormalDialogChild.Info.TextLabel.Text:match('Cannon Circle is starting') then
                            onTextChangedMiniGame()
                        elseif NormalDialogChild.Info.TextLabel.Text:match('invitation') then
                            localPlayer:Kick()
                            game:Shutdown()
                        elseif NormalDialogChild.Info.TextLabel.Text:match('You found a') then
                            Utils.FindButton('Okay')
                        end
                    end)
                end)
            end)
            MinigameInGameApp:GetPropertyChangedSignal('Enabled'):Connect(function(
            )
                if MinigameInGameApp.Enabled then
                    MinigameInGameApp:WaitForChild('Body')
                    MinigameInGameApp.Body:WaitForChild('Middle')
                    MinigameInGameApp.Body.Middle:WaitForChild('Container')
                    MinigameInGameApp.Body.Middle.Container:WaitForChild('TitleLabel')

                    if MinigameInGameApp.Body.Middle.Container.TitleLabel.Text:match('TREASURE DEFENSE') then
                        if getgenv().SETTINGS.EVENT and getgenv().SETTINGS.EVENT.DO_MINIGAME then
                            localPlayer:SetAttribute('StopFarmingTemp', true)
                            task.wait(2)
                        end
                    elseif MinigameInGameApp.Body.Middle.Container.TitleLabel.Text:match('CANNON CIRCLE') then
                        if getgenv().SETTINGS.EVENT and getgenv().SETTINGS.EVENT.DO_MINIGAME then
                            localPlayer:SetAttribute('StopFarmingTemp', true)
                            task.wait(2)
                        end
                    end
                end
            end)
            MinigameRewardsApp.Body:GetPropertyChangedSignal('Visible'):Connect(function(
            )
                if MinigameRewardsApp.Body.Visible then
                    MinigameRewardsApp.Body:WaitForChild('Button')
                    MinigameRewardsApp.Body.Button:WaitForChild('Face')
                    MinigameRewardsApp.Body.Button.Face:WaitForChild('TextLabel')
                    MinigameRewardsApp.Body:WaitForChild('Reward')
                    MinigameRewardsApp.Body.Reward:WaitForChild('TitleLabel')

                    if MinigameRewardsApp.Body.Button.Face.TextLabel.Text:match('NICE!') then
                        local character = (localPlayer.Character)
                        local humanoidRootPart = (character:WaitForChild('HumanoidRootPart'))

                        humanoidRootPart.Anchored = false

                        task.wait()
                        removeGameOverButton('MinigameRewardsApp')
                        localPlayer:SetAttribute('StopFarmingTemp', false)
                        Teleport.FarmingHome()
                    end
                end
            end)
        end
        function self.Start()
            TradeApp.Frame.NegotiationFrame.Body.PartnerOffer.Accepted:GetPropertyChangedSignal('ImageTransparency'):Connect(function(
            )
                Trade.AutoAcceptTrade()
            end)
            TradeApp.Frame.ConfirmationFrame.PartnerOffer.Accepted:GetPropertyChangedSignal('ImageTransparency'):Connect(function(
            )
                Trade.AutoAcceptTrade()
            end)
        end

        return self
    end
    function __DARKLUA_BUNDLE_MODULES.n()
        local Workspace = (cloneref(game:GetService('Workspace')))
        local Terrain = (Workspace:WaitForChild('Terrain'))
        local Lighting = (cloneref(game:GetService('Lighting')))
        local self = {}
        local TURN_ON = false
        local lowSpecTerrain = function()
            Terrain.WaterReflectance = 0
            Terrain.WaterTransparency = 1
            Terrain.WaterWaveSize = 0
            Terrain.WaterWaveSpeed = 0
        end
        local lowSpecLighting = function()
            Lighting.Brightness = 0
            Lighting.GlobalShadows = false
            Lighting.FogEnd = math.huge
            Lighting.FogStart = 0
        end
        local lowSpecTextures = function(v)
            if v:IsA('Part') then
                v.Material = Enum.Material.Plastic
                v.EnableFluidForces = false
                v.CastShadow = false
                v.Reflectance = 0
                v.Transparency = 1
            elseif v:IsA('BasePart') and not v:IsA('MeshPart') then
                v.Material = Enum.Material.Plastic
                v.Reflectance = 0
                v.Transparency = 1
            elseif v:IsA('Decal') or v:IsA('Texture') then
                v.Transparency = 1
            elseif v:IsA('Explosion') then
                v.BlastPressure = 1
                v.BlastRadius = 1
            elseif v:IsA('Fire') or v:IsA('SpotLight') or v:IsA('Smoke') or v:IsA('Sparkles') then
                v.Enabled = false
            elseif v:IsA('MeshPart') then
                v.Material = Enum.Material.Plastic
                v.EnableFluidForces = false
                v.CastShadow = false
                v.Reflectance = 0
                v.TextureID = '10385902758728957'
                v.Transparency = 1
            elseif v:IsA('SpecialMesh') then
                v.TextureId = 0
            elseif v:IsA('ShirtGraphic') then
                v.Graphic = 1
            end
        end

        function self.Init() end
        function self.Start()
            if not TURN_ON then
                return
            end

            lowSpecTerrain()
            lowSpecLighting()
            Lighting:ClearAllChildren()
            Terrain:Clear()

            for _, v in pairs(Workspace:GetDescendants())do
                lowSpecTextures(v)
            end

            Workspace.DescendantAdded:Connect(function(v)
                lowSpecTextures(v)
            end)
        end

        return self
    end
    function __DARKLUA_BUNDLE_MODULES.o()
        local Players = cloneref(game:GetService('Players'))
        local CoreGui = (game:GetService('CoreGui'))
        local Utils = __DARKLUA_BUNDLE_MODULES.load('b')
        local StatsGuiClass = {}

        StatsGuiClass.__index = StatsGuiClass

        local localPlayer = Players.LocalPlayer
        local hud = (gethui and {
            (gethui()),
        } or {
            (CoreGui.RobloxGui),
        })[1]
        local otherGuis = {}
        local DEFAULT_COLOR = Color3.fromRGB(0, 204, 255)
        local setButtonUiSettings = function(buttonSettings)
            local button = Instance.new('TextButton')

            button.Name = buttonSettings.Name
            button.AnchorPoint = Vector2.new(0.5, 0.5)
            button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            button.BackgroundTransparency = 1
            button.BorderColor3 = Color3.fromRGB(0, 0, 0)
            button.BorderSizePixel = 0
            button.Position = buttonSettings.Position
            button.Size = UDim2.new(0.2, 0, 0.2, 0)
            button.Font = Enum.Font.FredokaOne
            button.Text = buttonSettings.Text
            button.TextColor3 = Color3.fromRGB(0, 0, 0)
            button.TextScaled = true
            button.TextSize = 14
            button.TextWrapped = true
            button.TextXAlignment = Enum.TextXAlignment.Left
            button.Parent = hud:WaitForChild('StatsGui')

            return button
        end

        function StatsGuiClass.new(name)
            local self = setmetatable({}, StatsGuiClass)

            self.TextLabel = Instance.new('TextLabel')
            self.UICorner = Instance.new('UICorner')
            self.TextLabel.Name = name
            self.TextLabel.BackgroundColor3 = DEFAULT_COLOR
            self.TextLabel.BackgroundTransparency = 0.25
            self.TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
            self.TextLabel.BorderSizePixel = 0
            self.TextLabel.Size = UDim2.new(0.330000013, 0, 0.486617982, 0)
            self.TextLabel.Font = Enum.Font.FredokaOne
            self.TextLabel.RichText = false
            self.TextLabel.Text = ''
            self.TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            self.TextLabel.TextScaled = true
            self.TextLabel.TextSize = 14
            self.TextLabel.TextStrokeTransparency = 0
            self.TextLabel.TextWrapped = true
            self.StatsGui = hud:WaitForChild('StatsGui')
            self.TextLabel.Parent = self.StatsGui:WaitForChild('MainFrame'):WaitForChild('MiddleFrame')
            self.UICorner.CornerRadius = UDim.new(0, 16)
            self.UICorner.Parent = self.TextLabel
            self.Debounce = false

            return self
        end
        function StatsGuiClass.Init()
            local StatsGui = Instance.new('ScreenGui')

            StatsGui.Name = 'StatsGui'
            StatsGui.DisplayOrder = 1000
            StatsGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            StatsGui.ResetOnSpawn = false
            StatsGui.IgnoreGuiInset = true
            StatsGui.Parent = hud

            local blackFrame = Instance.new('Frame')

            blackFrame.Name = 'BlackFrame'
            blackFrame.Size = UDim2.new(1, 0, 1, 0)
            blackFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            blackFrame.BackgroundTransparency = 0
            blackFrame.LayoutOrder = 0
            blackFrame.Visible = true
            blackFrame.Parent = StatsGui

            local MainFrame = Instance.new('Frame')

            MainFrame.Name = 'MainFrame'
            MainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            MainFrame.BackgroundTransparency = 1
            MainFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
            MainFrame.BorderSizePixel = 0
            MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
            MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
            MainFrame.Size = UDim2.new(0.6, 0, 0.75, 0)
            MainFrame.LayoutOrder = 1
            MainFrame.Parent = StatsGui
            otherGuis.TimeLabel = Instance.new('TextLabel')
            otherGuis.TimeLabel.Name = 'TimeLabel'
            otherGuis.TimeLabel.BackgroundColor3 = DEFAULT_COLOR
            otherGuis.TimeLabel.BackgroundTransparency = 0.25
            otherGuis.TimeLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
            otherGuis.TimeLabel.BorderSizePixel = 0
            otherGuis.TimeLabel.Size = UDim2.new(1, 0, 0.200000018, 0)
            otherGuis.TimeLabel.Font = Enum.Font.FredokaOne
            otherGuis.TimeLabel.RichText = false
            otherGuis.TimeLabel.Text = '\u{23f1}\u{fe0f} time'
            otherGuis.TimeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            otherGuis.TimeLabel.TextScaled = true
            otherGuis.TimeLabel.TextSize = 14
            otherGuis.TimeLabel.TextStrokeTransparency = 0
            otherGuis.TimeLabel.TextWrapped = true
            otherGuis.TimeLabel.Parent = MainFrame

            local UICorner = Instance.new('UICorner')

            UICorner.CornerRadius = UDim.new(0, 16)
            UICorner.Parent = otherGuis.TimeLabel

            local MiddleFrame = Instance.new('Frame')

            MiddleFrame.Name = 'MiddleFrame'
            MiddleFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            MiddleFrame.BackgroundTransparency = 1
            MiddleFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
            MiddleFrame.BorderSizePixel = 0
            MiddleFrame.Position = UDim2.new(0, 0, 0.219711155, 0)
            MiddleFrame.Size = UDim2.new(0.999243617, 0, 0.55549103, 0)
            MiddleFrame.Parent = MainFrame

            local UIGridLayout = Instance.new('UIGridLayout')

            UIGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
            UIGridLayout.CellPadding = UDim2.new(0.00999999978, 0, 0.00999999978, 0)
            UIGridLayout.CellSize = UDim2.new(0.242, 0, 0.5, 0)
            UIGridLayout.FillDirectionMaxCells = 0
            UIGridLayout.Parent = MiddleFrame

            local TextButton = Instance.new('TextButton')

            TextButton.AnchorPoint = Vector2.new(0.5, 0.5)
            TextButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            TextButton.BackgroundTransparency = 1
            TextButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
            TextButton.BorderSizePixel = 0
            TextButton.Position = UDim2.new(0.33, 0, 0.08, 0)
            TextButton.Size = UDim2.new(0.1, 0, 0.1, 0)
            TextButton.Font = Enum.Font.FredokaOne
            TextButton.Text = '\u{1f648}'
            TextButton.TextColor3 = Color3.fromRGB(0, 0, 0)
            TextButton.TextScaled = true
            TextButton.TextSize = 14
            TextButton.TextWrapped = true
            TextButton.TextXAlignment = Enum.TextXAlignment.Left
            TextButton.LayoutOrder = 100
            TextButton.Parent = StatsGui

            local TIME_SAVED

            otherGuis.TimeLabel.MouseEnter:Connect(function()
                TIME_SAVED = otherGuis.TimeLabel.Text
                otherGuis.TimeLabel.Text = string.format('\u{1f916} %s', tostring(localPlayer.Name))
            end)
            otherGuis.TimeLabel.MouseLeave:Connect(function()
                otherGuis.TimeLabel.Text = TIME_SAVED
            end)

            local isVisible = true

            TextButton.Activated:Connect(function()
                isVisible = not isVisible
                MainFrame.Visible = isVisible
                blackFrame.Visible = isVisible
            end)
        end
        function StatsGuiClass.SetTimeLabelText(startTime)
            local currentTime = DateTime.now().UnixTimestamp
            local timeElapsed = currentTime - startTime

            otherGuis.TimeLabel.Text = string.format('\u{23f1}\u{fe0f} %s', tostring(Utils.FormatTime(timeElapsed)))
        end
        function StatsGuiClass.CreateButton(buttonSettings)
            local button = setButtonUiSettings(buttonSettings)

            button.Activated:Connect(function()
                buttonSettings.Callback()

                button.Text = '\u{2705}'

                task.wait(1)

                button.Text = buttonSettings.Text
            end)
        end
        function StatsGuiClass.UpdateTextForTotal(self)
            if self.TextLabel.Name == 'TotalPotions' then
                local formatted = Utils.FormatNumber(Utils.FoodItemCount('pet_age_potion'))

                self.TextLabel.Text = string.format('\u{1f9ea} %s', tostring(formatted))
            elseif self.TextLabel.Name == 'TotalTinyPotions' then
                local formatted = Utils.FormatNumber(Utils.FoodItemCount('tiny_pet_age_potion'))

                self.TextLabel.Text = string.format('\u{2697}\u{fe0f} %s', tostring(formatted))
            elseif self.TextLabel.Name == 'TotalBucks' then
                local formatted = Utils.FormatNumber(Utils.BucksAmount())

                self.TextLabel.Text = string.format('\u{1f4b0} %s', tostring(formatted))
            elseif self.TextLabel.Name == 'TotalEventCurrency' then
                local formatted = Utils.FormatNumber(Utils.EventCurrencyAmount())

                self.TextLabel.Text = string.format('\u{1f3e0} %s', tostring(formatted))
            elseif self.TextLabel.Name == 'TotalShiverBaits' then
                local formatted = Utils.FormatNumber(Utils.FoodItemCount('ice_dimension_2025_shiver_cone_bait'))

                self.TextLabel.Text = string.format('\u{1f43a} %s', tostring(formatted))
            elseif self.TextLabel.Name == 'TotalSubzeroBaits' then
                local formatted = Utils.FormatNumber(Utils.FoodItemCount('ice_dimension_2025_subzero_popsicle_bait'))

                self.TextLabel.Text = string.format('\u{1f982} %s', tostring(formatted))
            end
        end
        function StatsGuiClass.UpdateTextForTemp(self, amount)
            if self.TextLabel.Name == 'TempPotions' and amount then
                self.TextLabel.Text = string.format('\u{1f9ea} %s', tostring(Utils.FormatNumber(amount)))
            elseif self.TextLabel.Name == 'TempTinyPotions' and amount then
                self.TextLabel.Text = string.format('\u{2697}\u{fe0f} %s', tostring(Utils.FormatNumber(amount)))
            elseif self.TextLabel.Name == 'TempBucks' and amount then
                self.TextLabel.Text = string.format('\u{1f4b0} %s', tostring(Utils.FormatNumber(amount)))
            elseif self.TextLabel.Name == 'TempEventCurrency' and amount then
                self.TextLabel.Text = string.format('\u{1f3e0} %s', tostring(Utils.FormatNumber(amount)))
            end
        end

        return StatsGuiClass
    end
    function __DARKLUA_BUNDLE_MODULES.p()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local StatsGuiClass = __DARKLUA_BUNDLE_MODULES.load('o')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('b')
        local self = {}
        local localPlayer = Players.LocalPlayer
        local HintApp = (localPlayer:WaitForChild('PlayerGui'):WaitForChild('HintApp'))
        local startTime = DateTime.now().UnixTimestamp
        local startPotionAmount
        local startTinyPotionAmount
        local startEventCurrencyAmount
        local potionsGained = 0
        local tinyPotionsGained = 0
        local bucksGained = 0
        local eventCurrencyGained = 0
        local UpdateTextEvent = Instance.new('BindableEvent')

        UpdateTextEvent.Name = 'UpdateTextEvent'
        UpdateTextEvent.Parent = ReplicatedStorage

        StatsGuiClass.Init()

        self.TempPotions = StatsGuiClass.new('TempPotions')
        self.TempTinyPotions = StatsGuiClass.new('TempTinyPotions')
        self.TempBucks = StatsGuiClass.new('TempBucks')
        self.TempEventCurrency = StatsGuiClass.new('TempEventCurrency')
        self.TotalPotions = StatsGuiClass.new('TotalPotions')
        self.TotalTinyPotions = StatsGuiClass.new('TotalTinyPotions')
        self.TotalBucks = StatsGuiClass.new('TotalBucks')
        self.TotalEventCurrency = StatsGuiClass.new('TotalEventCurrency')
        self.BlankSlot1 = StatsGuiClass.new('BlankSlot1')
        self.BlankSlot2 = StatsGuiClass.new('BlankSlot2')
        self.TotalShiverBaits = StatsGuiClass.new('TotalShiverBaits')
        self.TotalSubzeroBaits = StatsGuiClass.new('TotalSubzeroBaits')

        local updateAllStatsGui = function()
            StatsGuiClass.SetTimeLabelText(startTime)

            potionsGained = Utils.FoodItemCount('pet_age_potion') - startPotionAmount

            if potionsGained < 0 then
                potionsGained = 0
            end

            self.TempPotions:UpdateTextForTemp(potionsGained)

            tinyPotionsGained = Utils.FoodItemCount('tiny_pet_age_potion') - startTinyPotionAmount

            if tinyPotionsGained < 0 then
                tinyPotionsGained = 0
            end

            self.TempTinyPotions:UpdateTextForTemp(tinyPotionsGained)

            local currentEventCurrency = Utils.EventCurrencyAmount()

            if currentEventCurrency >= startEventCurrencyAmount then
                eventCurrencyGained = eventCurrencyGained + (currentEventCurrency - startEventCurrencyAmount)
                startEventCurrencyAmount = currentEventCurrency
            elseif currentEventCurrency < startEventCurrencyAmount then
                startEventCurrencyAmount = currentEventCurrency
            end

            self.TempEventCurrency:UpdateTextForTemp(eventCurrencyGained)
            self.TotalEventCurrency:UpdateTextForTotal()
            self.TotalPotions:UpdateTextForTotal()
            self.TotalTinyPotions:UpdateTextForTotal()
            self.TotalBucks:UpdateTextForTotal()
            self.TotalShiverBaits:UpdateTextForTotal()
            self.TotalSubzeroBaits:UpdateTextForTotal()
        end

        function self.Init()
            startPotionAmount = Utils.FoodItemCount('pet_age_potion')
            startTinyPotionAmount = Utils.FoodItemCount('tiny_pet_age_potion')
            startEventCurrencyAmount = Utils.EventCurrencyAmount()

            UpdateTextEvent.Event:Connect(updateAllStatsGui)
            HintApp.TextLabel:GetPropertyChangedSignal('Text'):Connect(function()
                if HintApp.TextLabel.Text:match('Bucks') then
                    local text = HintApp.TextLabel.Text

                    if not text then
                        return
                    end
                    if not text:split('+')[2] then
                        return
                    end

                    local amount = tonumber(text:split('+')[2]:split(' ')[1])

                    if not amount then
                        return
                    end

                    bucksGained = bucksGained + amount

                    self.TempBucks:UpdateTextForTemp(bucksGained)
                end
            end)
        end
        function self.Start()
            UpdateTextEvent:Fire()
        end

        return self
    end
    function __DARKLUA_BUNDLE_MODULES.q()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local RouterClient = Bypass('RouterClient')
        local self = {}
        local localPlayer = Players.LocalPlayer
        local getTradeLicense = function()
            for _, v in ClientData.get_data()[localPlayer.Name].inventory.toys do
                if v.id == 'trade_license' then
                    return
                end
            end

            pcall(function()
                RouterClient.get('SettingsAPI/SetBooleanFlag'):FireServer('has_talked_to_trade_quest_npc', true)
                task.wait(1)
                RouterClient.get('TradeAPI/BeginQuiz'):FireServer()
                task.wait(1)

                for _, v in pairs(ClientData.get('trade_license_quiz_manager')['quiz'])do
                    RouterClient.get('TradeAPI/AnswerQuizQuestion'):FireServer(v['answer'])
                end
            end)
        end

        function self.Init() end
        function self.Start()
            getTradeLicense()
        end

        return self
    end
    function __DARKLUA_BUNDLE_MODULES.r()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local RouterClient = Bypass('RouterClient')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('b')
        local LegacyTutorial = (require(ReplicatedStorage:WaitForChild('ClientModules'):WaitForChild('Game'):WaitForChild('Tutorial'):WaitForChild('LegacyTutorial')))
        local self = {}
        local localPlayer = Players.LocalPlayer
        local completeNewStarterTutorial = function()
            local success, errorMessage = pcall(function()
                task.wait(10)
                RouterClient.get('TutorialAPI/ReportDiscreteStep'):FireServer('npc_interaction')
                task.wait(2)
                RouterClient.get('TutorialAPI/ChoosePet'):FireServer('dog')
                task.wait(2)
                RouterClient.get('TutorialAPI/ReportDiscreteStep'):FireServer('cured_dirty_ailment')
                task.wait(2)
                RouterClient.get('TutorialAPI/ReportTutorialCompleted'):FireServer()
                task.wait(2)
                LegacyTutorial.cancel_tutorial()
                task.wait(2)
                RouterClient.get('LegacyTutorialAPI/MarkTutorialCompleted'):FireServer()
            end)

            Utils.PrintDebug('CompleteNewStarterTutorial:', success, errorMessage)
        end
        local doStarterTutorial = function()
            Utils.FindButton('Next')
            task.wait(2)
            Utils.PrintDebug('doing tutorial')
            completeNewStarterTutorial()
            task.wait(1)
            Utils.PrintDebug('doing trade license')
            task.wait(1)
            Utils.FindButton('Next')
        end

        function self.Init() end
        function self.Start()
            local tutorial3Completed = ClientData.get_data()[localPlayer.Name].boolean_flags.tutorial_v3_completed
            local tutorialManagerComleted = ClientData.get_data()[localPlayer.Name].tutorial_manager.completed

            if not tutorial3Completed and not tutorialManagerComleted then
                Utils.PrintDebug('New alt detected. doing tutorial')
                doStarterTutorial()
            end
        end

        return self
    end
    function __DARKLUA_BUNDLE_MODULES.s()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Workspace = cloneref(game:GetService('Workspace'))
        local Players = cloneref(game:GetService('Players'))
        local Ailment = {}
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = (Bypass('ClientData'))
        local Utils = __DARKLUA_BUNDLE_MODULES.load('b')
        local GetInventory = __DARKLUA_BUNDLE_MODULES.load('i')
        local Teleport = __DARKLUA_BUNDLE_MODULES.load('f')
        local localPlayer = Players.LocalPlayer
        local doctorId = nil

        Ailment.whichPet = 1

        local consumeFood = function()
            local foodItem = Workspace.PetObjects:WaitForChild(tostring(Workspace.PetObjects:FindFirstChildWhichIsA('Model')), 10)

            if not foodItem then
                Utils.PrintDebug('NO food item in workspace')

                return
            end
            if not Utils.IsPetEquipped(Ailment.whichPet) then
                return
            end

            ReplicatedStorage.API['PetAPI/ConsumeFoodObject']:FireServer(foodItem, ClientData.get('pet_char_wrappers')[Ailment.whichPet].pet_unique)
        end

        local function FoodAilments(FoodPassOn)
            local hasFood = false

            for _, v in ClientData.get_data()[localPlayer.Name].inventory.food do
                if v.id == FoodPassOn then
                    hasFood = true

                    if not Utils.IsPetEquipped(Ailment.whichPet) then
                        Utils.PrintDebug('\u{26a0}\u{fe0f} Trying to feed pet but no pet equipped \u{26a0}\u{fe0f}')

                        return
                    end

                    local args = {
                        [1] = '__Enum_PetObjectCreatorType_2',
                        [2] = {
                            ['pet_unique'] = ClientData.get('pet_char_wrappers')[Ailment.whichPet].pet_unique,
                            ['unique_id'] = v.unique,
                        },
                    }

                    ReplicatedStorage.API['PetObjectAPI/CreatePetObject']:InvokeServer(unpack(args))
                    consumeFood()

                    return
                end
            end

            if not hasFood then
                ReplicatedStorage.API['ShopAPI/BuyItem']:InvokeServer('food', FoodPassOn, {})
                task.wait(2)
                FoodAilments(FoodPassOn)
            end
        end

        local getKeyFrom = function(itemId)
            for key, value in ClientData.get_data()[localPlayer.Name].house_interior.furniture do
                if value.id == itemId then
                    return key
                end
            end

            return nil
        end
        local useToolOnBaby = function(uniqueId)
            ReplicatedStorage.API['ToolAPI/ServerUseTool']:FireServer(uniqueId, 'END')
        end
        local PianoAilment = function(pianoId, petCharOrPlayerChar)
            local args = {
                localPlayer,
                pianoId,
                'Seat1',
                {
                    ['cframe'] = localPlayer.Character.HumanoidRootPart.CFrame,
                },
                petCharOrPlayerChar,
            }

            task.spawn(function()
                ReplicatedStorage.API:FindFirstChild('HousingAPI/ActivateFurniture'):InvokeServer(unpack(args))
            end)
        end
        local furnitureAilments = function(nameId, petCharOrPlayerChar)
            task.spawn(function()
                ReplicatedStorage.API['HousingAPI/ActivateFurniture']:InvokeServer(localPlayer, nameId, 'UseBlock', {
                    ['cframe'] = localPlayer.Character.HumanoidRootPart.CFrame,
                }, petCharOrPlayerChar)
            end)
        end
        local isDoctorLoaded = function()
            local stuckCount = 0
            local isStuck = false
            local doctor = Workspace.HouseInteriors.furniture:FindFirstChild('Doctor', true)

            if not doctor then
                repeat
                    task.wait(5)

                    doctor = Workspace.HouseInteriors.furniture:FindFirstChild('Doctor', true)
                    stuckCount = stuckCount + 5
                    isStuck = stuckCount > 30 and true or false
                until doctor or isStuck
            end
            if isStuck then
                Utils.PrintDebug("\u{26a0}\u{fe0f} Wasn't able to find Doctor Id \u{26a0}\u{fe0f}")

                return false
            end

            return true
        end
        local getDoctorId = function()
            if doctorId then
                Utils.PrintDebug(string.format('Doctor Id: %s', tostring(doctorId)))

                return
            end

            Utils.PrintDebug('\u{1fa79} Getting Doctor ID \u{1fa79}')

            local stuckCount = 0
            local isStuck = false

            ReplicatedStorage.API['LocationAPI/SetLocation']:FireServer('Hospital')
            task.wait(5)

            local doctor = Workspace.HouseInteriors.furniture:FindFirstChild('Doctor', true)

            if not doctor then
                repeat
                    task.wait(5)

                    doctor = Workspace.HouseInteriors.furniture:FindFirstChild('Doctor', true)
                    stuckCount = stuckCount + 5
                    isStuck = stuckCount > 30 and true or false
                until doctor or isStuck
            end
            if isStuck then
                Utils.PrintDebug("\u{26a0}\u{fe0f} Wasn't able to find Doctor Id \u{26a0}\u{fe0f}")

                return
            end
            if doctor then
                doctorId = doctor:GetAttribute('furniture_unique')

                if doctorId then
                    Utils.PrintDebug(string.format('Found doctor Id: %s', tostring(doctorId)))
                end
            end
        end
        local useStroller = function()
            local strollerTool = localPlayer.Character:FindFirstChild('StrollerTool')

            if not strollerTool then
                return false
            end

            local args = {
                localPlayer,
                ClientData.get('pet_char_wrappers')[Ailment.whichPet].char,
                localPlayer.Character.StrollerTool.ModelHandle.TouchToSits.TouchToSit,
            }

            ReplicatedStorage.API:FindFirstChild('AdoptAPI/UseStroller'):InvokeServer(unpack(args))

            return true
        end
        local babyJump = function()
            if localPlayer.Character.Humanoid:GetState() == Enum.HumanoidStateType.Freefall then
                return
            end

            localPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
        local getUpFromSitting = function()
            ReplicatedStorage.API['AdoptAPI/ExitSeatStates']:FireServer()
            task.wait()
            ReplicatedStorage.API['AdoptAPI/ExitSeatStates']:FireServer()
            task.wait(1)
            Utils.PrintDebug('Exited from seat')
        end

        local function babyGetFoodAndEat(FoodPassOn)
            local hasFood = false

            for _, v in ClientData.get_data()[localPlayer.Name].inventory.food do
                if v.id == FoodPassOn then
                    hasFood = true

                    ReplicatedStorage.API['ToolAPI/Equip']:InvokeServer(v.unique, {})
                    task.wait(1)
                    useToolOnBaby(v.unique)

                    return
                end
            end

            if not hasFood then
                ReplicatedStorage.API['ShopAPI/BuyItem']:InvokeServer('food', FoodPassOn, {})
                task.wait(1)
                babyGetFoodAndEat(FoodPassOn)
            end
        end

        local pickMysteryTask = function(mysteryId, petUnique)
            Utils.PrintDebug(string.format('mystery id: %s', tostring(mysteryId)))

            local ailmentsList = {}

            for i, _ in ClientData.get_data()[localPlayer.Name].ailments_manager.ailments[petUnique][mysteryId]['components']['mystery']['components']do
                table.insert(ailmentsList, i)
            end

            for i = 1, 3 do
                for _, ailment in ailmentsList do
                    Utils.PrintDebug(string.format('card: %s, ailment: %s', tostring(i), tostring(ailment)))
                    ReplicatedStorage.API['AilmentsAPI/ChooseMysteryAilment']:FireServer(petUnique, 'mystery', i, ailment)
                    task.wait(3)

                    if not ClientData.get_data()[localPlayer.Name].ailments_manager.ailments[petUnique][mysteryId] then
                        Utils.PrintDebug(string.format('\u{1f449} Picked %s ailment from mystery card \u{1f448}', tostring(ailment)))

                        return
                    end
                end
            end
        end
        local waitForTaskToFinish = function(ailment, petUnique)
            Utils.PrintDebug(string.format('\u{23f3} Waiting for %s to finish \u{23f3}', tostring(string.upper(ailment))))

            local count = 0

            repeat
                task.wait(5)

                local taskActive = ClientData.get_data()[localPlayer.Name].ailments_manager.ailments[petUnique] and ClientData.get_data()[localPlayer.Name].ailments_manager.ailments[petUnique][ailment] and true or false

                count = count + 5
            until not taskActive or count >= 60

            if count >= 60 then
                Utils.PrintDebug(string.format('\u{26a0}\u{fe0f} Waited too long for ailment: %s, must be stuck \u{26a0}\u{fe0f}', tostring(ailment)))
                Utils.ReEquipPet(1)
                Utils.ReEquipPet(2)
            else
                Utils.PrintDebug(string.format('\u{1f389} %s task finished \u{1f389}', tostring(ailment)))
            end
        end
        local waitForJumpingToFinish = function(ailment, petUnique)
            Utils.PrintDebug(string.format('\u{23f3} Waiting for %s to finish \u{23f3}', tostring(string.upper(ailment))))

            local stuckCount = tick()
            local isStuck = false

            repeat
                babyJump()
                task.wait(0.5)

                local taskActive = ClientData.get_data()[localPlayer.Name].ailments_manager.ailments[petUnique] and ClientData.get_data()[localPlayer.Name].ailments_manager.ailments[petUnique][ailment] and true or false

                task.wait(0.5)

                isStuck = (tick() - stuckCount) >= 120 and true or false
            until not taskActive or isStuck

            if isStuck then
                Utils.PrintDebug(string.format('\u{26d4} %s ailment is stuck so exiting task \u{26d4}', tostring(ailment)))
            else
                Utils.PrintDebug(string.format('\u{1f389} %s ailment finished \u{1f389}', tostring(ailment)))
            end
        end
        local babyWaitForTaskToFinish = function(ailment)
            Utils.PrintDebug(string.format('\u{23f3} Waiting for BABY %s to finish \u{23f3}', tostring(string.upper(ailment))))

            local count = 0

            repeat
                task.wait(5)

                local taskActive = ClientData.get_data()[localPlayer.Name].ailments_manager.baby_ailments and ClientData.get_data()[localPlayer.Name].ailments_manager.baby_ailments[ailment] and true or false

                count = count + 5
            until not taskActive or count >= 60

            if count >= 60 then
                Utils.PrintDebug(string.format('\u{26a0}\u{fe0f} Waited too long for ailment: %s, must be stuck \u{26a0}\u{fe0f}', tostring(ailment)))
            else
                Utils.PrintDebug(string.format('\u{1f389} %s task finished \u{1f389}', tostring(string.upper(ailment))))
            end
        end

        function Ailment.HungryAilment()
            Utils.PrintDebug(string.format('\u{1f356} Doing hungry task on %s \u{1f356}', tostring(Ailment.whichPet)))
            Utils.ReEquipPet(Ailment.whichPet)
            FoodAilments('icecream')
            Utils.PrintDebug(string.format('\u{1f356} Finished hungry task on %s \u{1f356}', tostring(Ailment.whichPet)))
        end
        function Ailment.ThirstyAilment()
            Utils.PrintDebug(string.format('\u{1f95b} Doing thirsty task on %s \u{1f95b}', tostring(Ailment.whichPet)))
            Utils.ReEquipPet(Ailment.whichPet)
            FoodAilments('water')
            Utils.PrintDebug(string.format('\u{1f95b} Finished thirsty task on %s \u{1f95b}', tostring(Ailment.whichPet)))
        end
        function Ailment.SickAilment()
            Utils.ReEquipPet(Ailment.whichPet)

            if doctorId then
                Utils.PrintDebug(string.format('\u{1fa79} Doing sick task on %s \u{1fa79}', tostring(Ailment.whichPet)))
                ReplicatedStorage.API['LocationAPI/SetLocation']:FireServer('Hospital')

                if not isDoctorLoaded() then
                    Utils.PrintDebug(string.format('\u{1fa79}\u{26a0}\u{fe0f} Doctor didnt load on %s \u{1fa79}\u{26a0}\u{fe0f}', tostring(Ailment.whichPet)))

                    return
                end

                local args = {
                    [1] = doctorId,
                    [2] = 'UseBlock',
                    [3] = 'Yes',
                    [4] = game:GetService('Players').LocalPlayer.Character,
                }

                ReplicatedStorage.API:FindFirstChild('HousingAPI/ActivateInteriorFurniture'):InvokeServer(unpack(args))
                Utils.PrintDebug(string.format('\u{1fa79} SICK task Finished on %s \u{1fa79}', tostring(Ailment.whichPet)))
            else
                getDoctorId()
            end
        end
        function Ailment.PetMeAilment()
            Utils.ReEquipPet(Ailment.whichPet)
            Utils.PrintDebug(string.format('\u{1f431} Doing pet me task on %s \u{1f431}', tostring(Ailment.whichPet)))

            if not Utils.IsPetEquipped(Ailment.whichPet) then
                return
            end

            ReplicatedStorage.API['AdoptAPI/FocusPet']:FireServer(ClientData.get('pet_char_wrappers')[Ailment.whichPet].char)
            task.wait(1)

            if not Utils.IsPetEquipped(Ailment.whichPet) then
                return
            end

            ReplicatedStorage.API['PetAPI/ReplicateActivePerformances']:FireServer(ClientData.get('pet_char_wrappers')[Ailment.whichPet].char, {
                ['FocusPet'] = true,
                ['Petting'] = true,
            })
            task.wait(1)

            if not Utils.IsPetEquipped(Ailment.whichPet) then
                return
            end

            Bypass('RouterClient').get('AilmentsAPI/ProgressPetMeAilment'):FireServer(ClientData.get('pet_char_wrappers')[Ailment.whichPet].pet_unique)
            Utils.PrintDebug('\u{1f431} RAN PETME AILMENT \u{1f431}')
        end
        function Ailment.SalonAilment(ailment, petUnique)
            Utils.ReEquipPet(Ailment.whichPet)
            Utils.PrintDebug(string.format('\u{1f457} Doing salon task on %s \u{1f457}', tostring(Ailment.whichPet)))
            ReplicatedStorage.API['LocationAPI/SetLocation']:FireServer('Salon')
            waitForTaskToFinish(ailment, petUnique)
            Utils.PrintDebug(string.format('\u{1f457} Finished salon task on %s \u{1f457}', tostring(Ailment.whichPet)))
        end
        function Ailment.MoonAilment(ailment, petUnique)
            Utils.ReEquipPet(Ailment.whichPet)
            Utils.PrintDebug(string.format('\u{1f31a} Doing moon task on %s \u{1f31a}', tostring(Ailment.whichPet)))
            ReplicatedStorage.API['LocationAPI/SetLocation']:FireServer('MoonInterior')
            waitForTaskToFinish(ailment, petUnique)
            Utils.PrintDebug(string.format('\u{1f31a} Doing moon task on %s \u{1f31a}', tostring(Ailment.whichPet)))
        end
        function Ailment.PizzaPartyAilment(ailment, petUnique)
            Utils.ReEquipPet(Ailment.whichPet)
            Utils.PrintDebug(string.format('\u{1f355} Doing pizza party task on %s \u{1f355}', tostring(Ailment.whichPet)))
            ReplicatedStorage.API['LocationAPI/SetLocation']:FireServer('PizzaShop')
            waitForTaskToFinish(ailment, petUnique)
            Utils.PrintDebug(string.format('\u{1f355} Finished pizza party task on %s \u{1f355}', tostring(Ailment.whichPet)))
        end
        function Ailment.SchoolAilment(ailment, petUnique)
            Utils.ReEquipPet(Ailment.whichPet)
            Utils.PrintDebug(string.format('\u{1f3eb} Doing school task on %s \u{1f3eb}', tostring(Ailment.whichPet)))
            ReplicatedStorage.API['LocationAPI/SetLocation']:FireServer('School')
            waitForTaskToFinish(ailment, petUnique)
            Utils.PrintDebug(string.format('\u{1f3eb} Finished school task on %s \u{1f3eb}', tostring(Ailment.whichPet)))
        end
        function Ailment.BoredAilment(pianoId, petUnique)
            Utils.ReEquipPet(Ailment.whichPet)
            Utils.PrintDebug(string.format('\u{1f971} Doing bored task on %s \u{1f971}', tostring(Ailment.whichPet)))

            if pianoId then
                if not Utils.IsPetEquipped(Ailment.whichPet) then
                    return
                end

                PianoAilment(pianoId, ClientData.get('pet_char_wrappers')[Ailment.whichPet]['char'])
            else
                Teleport.PlayGround(Vector3.new(20, 10, math.random(15, 30)))
            end

            waitForTaskToFinish('bored', petUnique)
            Utils.PrintDebug(string.format('\u{1f971} Finished bored task on %s \u{1f971}', tostring(Ailment.whichPet)))
        end
        function Ailment.SleepyAilment(bedId, petUnique)
            if not bedId then
                Utils.PrintDebug(string.format('NO bedId: %s', tostring(bedId)))

                return
            end

            Utils.ReEquipPet(Ailment.whichPet)
            Utils.PrintDebug(string.format('\u{1f634} Doing sleep task on %s \u{1f634}', tostring(Ailment.whichPet)))

            if not Utils.IsPetEquipped(Ailment.whichPet) then
                return
            end

            furnitureAilments(bedId, ClientData.get('pet_char_wrappers')[Ailment.whichPet]['char'])
            waitForTaskToFinish('sleepy', petUnique)
        end
        function Ailment.DirtyAilment(showerId, petUnique)
            if not showerId then
                Utils.PrintDebug(string.format('NO showerId: %s', tostring(showerId)))

                return
            end

            Utils.ReEquipPet(Ailment.whichPet)
            Utils.PrintDebug(string.format('\u{1f9fc} Doing dirty task on %s \u{1f9fc}', tostring(Ailment.whichPet)))

            if not Utils.IsPetEquipped(Ailment.whichPet) then
                return
            end

            furnitureAilments(showerId, ClientData.get('pet_char_wrappers')[Ailment.whichPet]['char'])
            waitForTaskToFinish('dirty', petUnique)
        end
        function Ailment.ToiletAilment(litterBoxId, petUnique)
            Utils.ReEquipPet(Ailment.whichPet)
            Utils.PrintDebug(string.format('\u{1f6bd} Doing toilet task on %s \u{1f6bd}', tostring(Ailment.whichPet)))

            if litterBoxId then
                if not Utils.IsPetEquipped(Ailment.whichPet) then
                    return
                end

                furnitureAilments(litterBoxId, ClientData.get('pet_char_wrappers')[Ailment.whichPet]['char'])
            else
                Teleport.DownloadMainMap()
                task.wait(5)

                localPlayer.Character.HumanoidRootPart.CFrame = Workspace.HouseInteriors.furniture:FindFirstChild('AilmentsRefresh2024FireHydrant', true).PrimaryPart.CFrame + Vector3.new(5, 5, 5)

                task.wait(2)
                Utils.ReEquipPet(Ailment.whichPet)
            end

            waitForTaskToFinish('toilet', petUnique)
        end
        function Ailment.BeachPartyAilment(petUnique)
            Utils.PrintDebug(string.format('\u{1f3d6}\u{fe0f} Doing beach party on %s \u{1f3d6}\u{fe0f}', tostring(Ailment.whichPet)))
            Teleport.BeachParty()
            task.wait(2)
            Utils.ReEquipPet(Ailment.whichPet)
            waitForTaskToFinish('beach_party', petUnique)
        end
        function Ailment.CampingAilment(petUnique)
            Utils.PrintDebug(string.format('\u{1f3d5}\u{fe0f} Doing camping task on %s \u{1f3d5}\u{fe0f}', tostring(Ailment.whichPet)))
            Teleport.CampSite()
            task.wait(2)
            Utils.ReEquipPet(Ailment.whichPet)
            waitForTaskToFinish('camping', petUnique)
        end
        function Ailment.WalkAilment(petUnique)
            Utils.ReEquipPet(Ailment.whichPet)
            Utils.PrintDebug(string.format('\u{1f9ae} Doing walking task on %s \u{1f9ae}', tostring(Ailment.whichPet)))

            if not Utils.IsPetEquipped(Ailment.whichPet) then
                return
            end

            ReplicatedStorage.API['AdoptAPI/HoldBaby']:FireServer(ClientData.get('pet_char_wrappers')[Ailment.whichPet]['char'])
            waitForJumpingToFinish('walk', petUnique)

            if not Utils.IsPetEquipped(Ailment.whichPet) then
                return
            end

            ReplicatedStorage.API:FindFirstChild('AdoptAPI/EjectBaby'):FireServer(ClientData.get('pet_char_wrappers')[Ailment.whichPet]['char'])
        end
        function Ailment.RideAilment(strollerId, petUnique)
            if not strollerId then
                Utils.PrintDebug(string.format('NO strollerId: %s', tostring(strollerId)))

                return
            end

            Utils.ReEquipPet(Ailment.whichPet)
            Utils.PrintDebug(string.format('\u{1f697} Doing ride task on %s \u{1f697}', tostring(Ailment.whichPet)))
            ReplicatedStorage.API:FindFirstChild('ToolAPI/Equip'):InvokeServer(strollerId, {})
            task.wait(1)

            if not Utils.IsPetEquipped(Ailment.whichPet) then
                return
            end
            if not useStroller() then
                return
            end

            waitForJumpingToFinish('ride', petUnique)

            if not Utils.IsPetEquipped(Ailment.whichPet) then
                return
            end

            ReplicatedStorage.API:FindFirstChild('AdoptAPI/EjectBaby'):FireServer(ClientData.get('pet_char_wrappers')[Ailment.whichPet]['char'])
        end
        function Ailment.PlayAilment(ailment, petUnique)
            Utils.ReEquipPet(Ailment.whichPet)
            Utils.PrintDebug(string.format('\u{1f9b4} Doing play task on %s \u{1f9b4}', tostring(Ailment.whichPet)))

            local toyId = GetInventory.GetUniqueId('toys', 'squeaky_bone_default')

            if not toyId then
                return false, Utils.PrintDebug("\u{26a0}\u{fe0f} Doesn't have squeaky_bone so exiting \u{26a0}\u{fe0f}")
            end

            local args = {
                [1] = '__Enum_PetObjectCreatorType_1',
                [2] = {
                    ['reaction_name'] = 'ThrowToyReaction',
                    ['unique_id'] = toyId,
                },
            }
            local count = 0

            repeat
                Utils.PrintDebug('\u{1f9b4} Throwing toy \u{1f9b4}')
                ReplicatedStorage.API:FindFirstChild('PetObjectAPI/CreatePetObject'):InvokeServer(unpack(args))
                task.wait(10)

                local taskActive = ClientData.get_data()[localPlayer.Name].ailments_manager.ailments[petUnique] and ClientData.get_data()[localPlayer.Name].ailments_manager.ailments[petUnique][ailment] and true or false

                count = count + 1
            until not taskActive or count >= 6

            if count >= 6 then
                Utils.PrintDebug('Play task got stuck so requiping pet')
                Utils.ReEquipPet(Ailment.whichPet)

                return false
            end

            Utils.PrintDebug(string.format('\u{1f9b4} Finished play task on %s \u{1f9b4}', tostring(Ailment.whichPet)))

            return true
        end
        function Ailment.MysteryAilment(mysteryId, petUnique)
            Utils.PrintDebug('\u{2753} Picking mystery task \u{2753}')
            pickMysteryTask(mysteryId, petUnique)
        end
        function Ailment.BonfireAilment(petUnique)
            Utils.PrintDebug(string.format('\u{1f3d6}\u{fe0f} Doing bonfire on %s \u{1f3d6}\u{fe0f}', tostring(Ailment.whichPet)))
            Teleport.Bonfire()
            task.wait(2)
            Utils.ReEquipPet(Ailment.whichPet)
            waitForTaskToFinish('summerfest_bonfire', petUnique)
        end
        function Ailment.BuccaneerBandAilment(petUnique)
            ReplicatedStorage.API['LocationAPI/SetLocation']:FireServer('MainMap', localPlayer, ClientData.get_data()[localPlayer.Name].LiveOpsMapType)
            task.wait(2)

            local key = getKeyFrom('summerfest_2025_buccaneer_band')

            if not key then
                Utils.PrintDebug('didnt find key for band')

                return
            end

            Utils.PrintDebug('Doing Band task')

            local args = {
                key,
                'Guitar',
                {
                    ['cframe'] = CFrame.new(-607, 35, -1641, -0, -0, -1, 0, 1, -0, 1, -0, -0),
                },
                localPlayer.Character,
            }

            task.spawn(function()
                ReplicatedStorage.API:FindFirstChild('HousingAPI/ActivateInteriorFurniture'):InvokeServer(unpack(args))
            end)
            waitForTaskToFinish('buccaneer_band', petUnique)
            getUpFromSitting()
        end
        function Ailment.BabyHungryAilment()
            Utils.PrintDebug('\u{1f476}\u{1f374} Doing baby hungry task \u{1f476}\u{1f374}')

            local stuckCount = 0

            repeat
                babyGetFoodAndEat('icecream')

                stuckCount = stuckCount + 1

                task.wait(2)
            until not ClientData.get_data()[localPlayer.Name].ailments_manager.baby_ailments['hungry'] or stuckCount >= 30

            if stuckCount >= 30 then
                Utils.PrintDebug('\u{26a0}\u{fe0f} Waited too long for Baby Hungry. Must be stuck \u{26a0}\u{fe0f}')
            else
                Utils.PrintDebug('\u{1f476}\u{1f374} Baby hungry task Finished \u{1f476}\u{1f374}')
            end
        end
        function Ailment.BabyThirstyAilment()
            Utils.PrintDebug('\u{1f476}\u{1f95b} Doing baby water task \u{1f476}\u{1f95b}')

            local stuckCount = 0

            repeat
                babyGetFoodAndEat('lemonade')

                stuckCount = stuckCount + 1

                task.wait(2)
            until not ClientData.get_data()[localPlayer.Name].ailments_manager.baby_ailments['thirsty'] or stuckCount >= 30

            if stuckCount >= 30 then
                Utils.PrintDebug('\u{26a0}\u{fe0f} Waited too long for Baby Thirsty. Must be stuck \u{26a0}\u{fe0f}')
            else
                Utils.PrintDebug('\u{1f476}\u{1f95b} Baby water task Finished \u{1f476}\u{1f95b}')
            end
        end
        function Ailment.BabyBoredAilment(pianoId)
            Utils.PrintDebug('\u{1f476}\u{1f971} Doing bored task \u{1f476}\u{1f971}')
            getUpFromSitting()

            if pianoId then
                PianoAilment(pianoId, localPlayer.Character)
            else
                Teleport.PlayGround(Vector3.new(20, 10, math.random(15, 30)))
            end

            babyWaitForTaskToFinish('bored')
            getUpFromSitting()
        end
        function Ailment.BabySleepyAilment(bedId)
            if not bedId then
                Utils.PrintDebug(string.format('NO bedId: %s', tostring(bedId)))

                return
            end

            Utils.PrintDebug('\u{1f476}\u{1f634} Doing sleepy task \u{1f476}\u{1f634}')
            getUpFromSitting()
            furnitureAilments(bedId, localPlayer.Character)
            babyWaitForTaskToFinish('sleepy')
            getUpFromSitting()
        end
        function Ailment.BabyDirtyAilment(showerId)
            if not showerId then
                Utils.PrintDebug(string.format('NO showerId: %s', tostring(showerId)))

                return
            end

            Utils.PrintDebug('\u{1f476}\u{1f9fc} Doing dirty task \u{1f476}\u{1f9fc}')
            getUpFromSitting()
            furnitureAilments(showerId, localPlayer.Character)
            babyWaitForTaskToFinish('dirty')
            getUpFromSitting()
        end

        return Ailment
    end
    function __DARKLUA_BUNDLE_MODULES.t()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local RouterClient = Bypass('RouterClient')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('b')
        local GetInventory = __DARKLUA_BUNDLE_MODULES.load('i')
        local Fusion = __DARKLUA_BUNDLE_MODULES.load('h')
        local Teleport = __DARKLUA_BUNDLE_MODULES.load('f')
        local FarmingPet = {}
        local localPlayer = Players.LocalPlayer
        local potionFarmPets = {
            'dog',
            'cat',
            'starter_egg',
            'cracked_egg',
            'basic_egg_2022_ant',
            'basic_egg_2022_mouse',
        }
        local petEggs = GetInventory.GetPetEggs()
        local farmEgg = function()
            if not Utils.IsPetEquipped(1) then
                FarmingPet.GetPetToFarm(1)
            end

            local petName = tostring(ClientData.get('pet_char_wrappers')[1].char)

            if petName:match('Egg') then
                return true
            end
            if GetInventory.CheckForPetAndEquip({
                'aztec_egg_2025_aztec_egg',
            }, 1) then
                return true
            else
                local hasMoney = RouterClient.get('ShopAPI/BuyItem'):InvokeServer('pets', 'aztec_egg_2025_aztec_egg', {})

                if hasMoney then
                    return true
                end

                return false
            end
        end
        local isfocusFarmPets = function()
            local equippedPet = ClientData.get('pet_char_wrappers') and ClientData.get('pet_char_wrappers')[1]

            if not equippedPet then
                return false
            end

            local petId = equippedPet.pet_id

            if not petId then
                return false
            end

            local result = table.find(potionFarmPets, petId) and true or false

            return result
        end
        local isProHandler = function()
            local subscription = ClientData.get_data()[localPlayer.Name].subscription_equip_2x_pets

            if not subscription then
                localPlayer:SetAttribute('isProHandler', false)

                return
            end

            localPlayer:SetAttribute('isProHandler', subscription.active)
        end
        local getEgg = function()
            for _, v in ClientData.get_data()[localPlayer.Name].inventory.pets do
                if v.id == getgenv().SETTINGS.PET_TO_BUY and v.id ~= 'practice_dog' and v.properties.age ~= 6 and not v.properties.mega_neon then
                    RouterClient.get('ToolAPI/Equip'):InvokeServer(v.unique, {
                        ['use_sound_delay'] = true,
                    })

                    getgenv().petCurrentlyFarming1 = v.unique

                    return true
                end
            end

            local BuyEgg = RouterClient.get('ShopAPI/BuyItem'):InvokeServer('pets', getgenv().SETTINGS.PET_TO_BUY, {})

            if BuyEgg == 'too little money' then
                return false
            end

            return false
        end

        function FarmingPet.SwitchOutFullyGrown(whichPet)
            if localPlayer:GetAttribute('StopFarmingTemp') == true then
                return
            end
            if not ClientData.get('pet_char_wrappers')[whichPet] then
                if not Utils.ReEquipPet(whichPet) then
                    Utils.PrintDebug('switchOutFullyGrown: GETTING NEW PETS')
                    FarmingPet.GetPetToFarm(whichPet)

                    return
                end

                task.wait(1)
            end

            local PetAge = ClientData.get('pet_char_wrappers')[whichPet]['pet_progression']['age']

            if PetAge == 6 then
                if getgenv().SETTINGS.PET_AUTO_FUSION then
                    Fusion.MakeMega(false)
                    Fusion.MakeMega(true)
                end

                FarmingPet.GetPetToFarm(whichPet)

                return
            end
        end
        function FarmingPet.GetPetToFarm(whichPet)
            if getgenv().SETTINGS.FOCUS_FARM_AGE_POTION then
                if whichPet == 1 and isfocusFarmPets() then
                    Utils.PrintDebug(string.format('Has focusFarmpets equipped, %s', tostring(whichPet)))

                    return
                end

                isProHandler()

                if whichPet == 2 and localPlayer:GetAttribute('isProHandler') == true and getgenv().petCurrentlyFarming2 then
                    return
                end

                Utils.PrintDebug(string.format('\u{1f414}\u{1f414} Getting pet to Farm age up potion, %s \u{1f414}\u{1f414}', tostring(whichPet)))

                if GetInventory.CheckForPetAndEquip({
                    'starter_egg',
                }, whichPet) then
                    return
                end

                Utils.PrintDebug(string.format('\u{1f414}\u{1f414} No starter egg found, trying cdog or cat %s \u{1f414}\u{1f414}', tostring(whichPet)))

                if GetInventory.GetPetFriendship(potionFarmPets, whichPet) then
                    return
                end

                Utils.PrintDebug(string.format('\u{1f414}\u{1f414} No friendship pet. checking if pet without friend exist %s \u{1f414}\u{1f414}', tostring(whichPet)))

                if GetInventory.CheckForPetAndEquip(potionFarmPets, whichPet) then
                    return
                end
                if GetInventory.CheckForPetAndEquip({
                    'cracked_egg',
                }, whichPet) then
                    return
                end

                Utils.PrintDebug(string.format('\u{1f414}\u{1f414} No cracked egg found, buying it %s \u{1f414}\u{1f414}', tostring(whichPet)))

                local hasMoney = RouterClient.get('ShopAPI/BuyItem'):InvokeServer('pets', 'cracked_egg', {})

                Utils.PrintDebug(string.format('hasMoney: %s', tostring(hasMoney)))

                if hasMoney then
                    return
                end
            end
            if getgenv().SETTINGS.HATCH_EGG_PRIORITY then
                if GetInventory.PriorityEgg(whichPet) then
                    return
                end

                local hasMoney = RouterClient.get('ShopAPI/BuyItem'):InvokeServer('pets', getgenv().SETTINGS.HATCH_EGG_PRIORITY_NAMES[1], {})

                if hasMoney then
                    return
                end
            end
            if getgenv().SETTINGS.PET_ONLY_PRIORITY then
                if GetInventory.PriorityPet(whichPet) then
                    return
                end
            end
            if getgenv().SETTINGS.PET_NEON_PRIORITY then
                if GetInventory.GetNeonPet(whichPet) then
                    return
                end
            end
            if GetInventory.PetRarityAndAge('legendary', 5, whichPet) then
                return
            end
            if GetInventory.PetRarityAndAge('ultra_rare', 5, whichPet) then
                return
            end
            if GetInventory.PetRarityAndAge('rare', 5, whichPet) then
                return
            end
            if GetInventory.PetRarityAndAge('uncommon', 5, whichPet) then
                return
            end
            if GetInventory.PetRarityAndAge('common', 5, whichPet) then
                return
            end
            if getEgg() then
                return
            end

            return
        end
        function FarmingPet.CheckIfEgg(whichPet)
            if not ClientData.get('pet_char_wrappers') then
                return
            end
            if not ClientData.get('pet_char_wrappers')[whichPet] then
                return
            end
            if table.find(petEggs, ClientData.get('pet_char_wrappers')[whichPet].pet_id) then
                return
            end

            Utils.PrintDebug(string.format('NOT A EGG SO GETTING NEW EGG %s', tostring(whichPet)))
            FarmingPet.GetPetToFarm(whichPet)

            return
        end
        function FarmingPet.GetTaskBoardPet(whichPet)
            print('Getting Task Board Pet')

            if not Utils.IsPetEquipped(whichPet) then
                FarmingPet.GetPetToFarm(whichPet)
            end

            for _, v in ClientData.get('quest_manager')['quests_cached']do
                if v['entry_name']:match('house_pets_2025_potion_drank') then
                    for _, v in ClientData.get_data()[localPlayer.Name].inventory.food do
                        if v['id'] == 'pet_grow_potion' then
                            print('Found potion, using it')
                            Utils.CreatePetObject(v['unique'])

                            return true
                        end
                    end

                    if Utils.BucksAmount() >= 10000 then
                        print('Buying grow potion')
                        RouterClient.get('ShopAPI/BuyItem'):InvokeServer('food', 'pet_grow_potion', {buy_count = 1})
                        task.wait(1)
                    end
                end
            end
            for _, v in ClientData.get('quest_manager')['quests_cached']do
                if v['entry_name']:match('house_pets_2025_small_hatch_egg') or v['entry_name']:match('house_pets_2025_medium_hatch_egg') then
                    if farmEgg() then
                        return true
                    end
                end
            end
            for _, v in ClientData.get('quest_manager')['quests_cached']do
                if v['entry_name']:match('house_pets_2025_buy_gumball_egg') then
                    if Utils.BucksAmount() >= 10000 then
                        print('Buying gumball egg')
                        Teleport.Nursery()
                        RouterClient.get('ShopAPI/BuyItem'):InvokeServer('pets', 'aztec_egg_2025_aztec_egg', {})
                    end
                end
            end
            for _, v in ClientData.get('quest_manager')['quests_cached']do
                if v['entry_name']:match('house_pets_2025_large_ailments_common') then
                    if GetInventory.GetPetRarity() == 'common' then
                        return true
                    end
                    if GetInventory.PetRarityAndAge('common', 6, whichPet) then
                        return true
                    end
                end
            end
            for _, v in ClientData.get('quest_manager')['quests_cached']do
                if v['entry_name']:match('house_pets_2025_large_ailments_uncommon') then
                    if GetInventory.GetPetRarity() == 'uncommon' then
                        return true
                    end
                    if GetInventory.PetRarityAndAge('uncommon', 6, whichPet) then
                        return true
                    end
                end
            end
            for _, v in ClientData.get('quest_manager')['quests_cached']do
                if v['entry_name']:match('house_pets_2025_large_ailments_rare') then
                    if GetInventory.GetPetRarity() == 'rare' then
                        return true
                    end
                    if GetInventory.PetRarityAndAge('rare', 6, whichPet) then
                        return true
                    end
                end
            end
            for _, v in ClientData.get('quest_manager')['quests_cached']do
                if v['entry_name']:match('house_pets_2025_large_ailments_ultra_rare') then
                    if GetInventory.GetPetRarity() == 'ultra_rare' then
                        return true
                    end
                    if GetInventory.PetRarityAndAge('ultra_rare', 6, whichPet) then
                        return true
                    end
                end
            end
            for _, v in ClientData.get('quest_manager')['quests_cached']do
                if v['entry_name']:match('house_pets_2025_large_ailments_legendary') then
                    if GetInventory.GetPetRarity() == 'legendary' then
                        return true
                    end
                    if GetInventory.PetRarityAndAge('legendary', 6, whichPet) then
                        return true
                    end
                end
            end

            return false
        end

        return FarmingPet
    end
    function __DARKLUA_BUNDLE_MODULES.u()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local RouterClient = Bypass('RouterClient')
        local Taskboard = {}
        local localPlayer = Players.LocalPlayer
        local PlayerGui = localPlayer:WaitForChild('PlayerGui')
        local neonTable = {
            ['neon_fusion'] = true,
            ['mega_neon_fusion'] = true,
        }
        local claimTable = {
            ['hatch_three_eggs'] = {3},
            ['fully_age_three_pets'] = {3},
            ['make_two_trades'] = {2},
            ['equip_two_accessories'] = {2},
            ['buy_three_furniture_items_with_friends_coop_budget'] = {3},
            ['buy_five_furniture_items'] = {5},
            ['buy_fifteen_furniture_items'] = {15},
            ['play_as_a_baby_for_twenty_five_minutes'] = {1500},
            ['play_for_thirty_minutes'] = {1800},
            ['sunshine_2024_playtime'] = {2400},
            ['bonus_week_2024_small_ailments'] = {5},
            ['bonus_week_2024_small_hatch_egg'] = {1},
            ['bonus_week_2024_small_age_potion_drank'] = {1},
            ['bonus_week_2024_small_ailment_orange'] = {1},
            ['bonus_week_2024_medium_ailment_hungry_sleepy_bored'] = {3},
            ['bonus_week_2024_medium_ailment_catch_bored'] = {2},
            ['bonus_week_2024_medium_ailment_toilet_dirty_sleepy'] = {3},
            ['bonus_week_2024_medium_ailment_pizza_hungry'] = {2},
            ['bonus_week_2024_medium_ailment_salon_dirty'] = {2},
            ['bonus_week_2024_medium_ailment_school_ride'] = {2},
            ['bonus_week_2024_medium_ailment_walk_beach'] = {2},
            ['bonus_week_2024_medium_ailments'] = {15},
            ['bonus_week_2024_large_ailments_common'] = {30},
            ['bonus_week_2024_large_ailments_legendary'] = {30},
            ['bonus_week_2024_large_ailments_ultra_rare'] = {30},
            ['bonus_week_2024_large_ailments_uncommon'] = {30},
            ['bonus_week_2024_large_ailments_rare'] = {30},
            ['bonus_week_2024_large_ailments'] = {30},
            ['house_pets_2025_small_ailment_blue'] = {2},
            ['house_pets_2025_small_open_gift'] = {1},
            ['house_pets_2025_potion_drank'] = {1},
            ['house_pets_2025_small_hatch_egg'] = {1},
            ['house_pets_2025_small_ailments'] = {5},
            ['house_pets_2025_small_ailment_orange'] = {1},
            ['house_pets_2025_medium_ailment_hungry_sleepy_bored'] = {3},
            ['house_pets_2025_medium_ailments'] = {15},
            ['house_pets_2025_medium_ailment_beach_camping_bored'] = {3},
            ['house_pets_2025_medium_blue_ailments'] = {6},
            ['house_pets_2025_medium_ailment_salon_shower'] = {2},
            ['house_pets_2025_medium_hatch_egg'] = {3},
            ['house_pets_2025_large_ailments'] = {30},
            ['house_pets_2025_large_ailments_common'] = {30},
            ['house_pets_2025_large_ailments_ultra_rare'] = {30},
            ['house_pets_2025_large_ailments_uncommon'] = {30},
            ['house_pets_2025_large_ailments_rare'] = {30},
            ['house_pets_2025_large_ailments_legendary'] = {30},
            ['house_pets_2025_buy_gumball_egg'] = {1},
        }

        Taskboard.NewTaskBool = true
        Taskboard.NewClaimBool = true
        Taskboard.NeonTable = neonTable
        Taskboard.ClaimTable = claimTable

        function Taskboard.QuestCount()
            local Count = 0

            for _, v in pairs(ClientData.get('quest_manager')['quests_cached'])do
                if v['entry_name']:match('teleport') or v['entry_name']:match('navigate') or v['entry_name']:match('nav') or v['entry_name']:match('gosh_2022_sick') then
                    Count = Count + 0
                else
                    Count = Count + 1
                end
            end

            return Count
        end

        local reRollCount = function()
            for _, v in pairs(ClientData.get('quest_manager')['daily_quest_data'])do
                if v == 1 or v == 0 then
                    return v
                end
            end

            return 0
        end

        function Taskboard:NewTask()
            Taskboard.NewTaskBool = false

            for _, v in pairs(ClientData.get('quest_manager')['quests_cached'])do
                if v['entry_name']:match('teleport') then
                    task.wait()
                elseif v['entry_name']:match('tutorial') then
                    RouterClient.get('QuestAPI/ClaimQuest'):InvokeServer(v['unique_id'])
                    task.wait()
                elseif v['entry_name']:match('house_pets_2025_small_open_gift') then
                    RouterClient.get('ShopAPI/BuyItem'):InvokeServer('gifts', 'smallgift', {})
                    task.wait(1)

                    for _, v in ClientData.get_data()[localPlayer.Name].inventory.gifts do
                        if v['id'] == 'smallgift' then
                            RouterClient.get('ShopAPI/OpenGift'):InvokeServer(v['unique'])

                            break
                        end
                    end

                    task.wait()
                else
                    if Taskboard.QuestCount() == 1 then
                        if Taskboard.NeonTable[v['entry_name'] ] then
                            RouterClient.get('QuestAPI/ClaimQuest'):InvokeServer(v['unique_id'])
                            task.wait()
                        elseif not Taskboard.NeonTable[v['entry_name'] ] and reRollCount() >= 1 then
                            RouterClient.get('QuestAPI/RerollQuest'):FireServer(v['unique_id'])
                            task.wait()
                        end
                    elseif Taskboard.QuestCount() > 1 then
                        if Taskboard.NeonTable[v['entry_name'] ] then
                            RouterClient.get('QuestAPI/ClaimQuest'):InvokeServer(v['unique_id'])
                            task.wait()
                        elseif not Taskboard.NeonTable[v['entry_name'] ] and reRollCount() >= 1 then
                            RouterClient.get('QuestAPI/RerollQuest'):FireServer(v['unique_id'])
                            task.wait()
                        elseif not Taskboard.NeonTable[v['entry_name'] ] and reRollCount() <= 0 then
                            RouterClient.get('QuestAPI/ClaimQuest'):InvokeServer(v['unique_id'])
                            task.wait()
                        end
                    end
                end
            end

            task.wait(1)

            Taskboard.NewTaskBool = true
        end
        function Taskboard:NewClaim()
            Taskboard.NewClaimBool = false

            for _, v in pairs(ClientData.get('quest_manager')['quests_cached'])do
                if Taskboard.ClaimTable[v['entry_name'] ] then
                    if v['steps_completed'] == Taskboard.ClaimTable[v['entry_name'] ][1] then
                        RouterClient.get('QuestAPI/ClaimQuest'):InvokeServer(v['unique_id'])
                        task.wait()
                    end
                elseif not Taskboard.ClaimTable[v['entry_name'] ] and v['steps_completed'] == 1 then
                    RouterClient.get('QuestAPI/ClaimQuest'):InvokeServer(v['unique_id'])
                    task.wait()
                end
            end

            task.wait(1)

            Taskboard.NewClaimBool = true
        end

        local ImageButton = PlayerGui:WaitForChild('QuestIconApp'):WaitForChild('ImageButton')
        local IsNew = ImageButton:WaitForChild('EventContainer'):WaitForChild('IsNew')
        local IsClaimable = ImageButton:WaitForChild('EventContainer'):WaitForChild('IsClaimable')

        IsNew:GetPropertyChangedSignal('Position'):Connect(function()
            if Taskboard.NewTaskBool then
                Taskboard.NewTaskBool = false

                RouterClient.get('QuestAPI/MarkQuestsViewed'):FireServer()
                Taskboard:NewTask()
            end
        end)
        IsClaimable:GetPropertyChangedSignal('Position'):Connect(function()
            if Taskboard.NewClaimBool then
                Taskboard.NewClaimBool = false

                Taskboard:NewClaim()
            end
        end)

        return Taskboard
    end
    function __DARKLUA_BUNDLE_MODULES.v()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local RouterClient = Bypass('RouterClient')
        local CollisionsClient = Bypass('CollisionsClient')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('b')
        local Ailment = __DARKLUA_BUNDLE_MODULES.load('s')
        local Furniture = __DARKLUA_BUNDLE_MODULES.load('c')
        local Teleport = __DARKLUA_BUNDLE_MODULES.load('f')
        local GetInventory = __DARKLUA_BUNDLE_MODULES.load('i')
        local FarmingPet = __DARKLUA_BUNDLE_MODULES.load('t')
        local Fusion = __DARKLUA_BUNDLE_MODULES.load('h')
        local Taskboard = __DARKLUA_BUNDLE_MODULES.load('u')
        local self = {}
        local UpdateTextEvent = (ReplicatedStorage:WaitForChild('UpdateTextEvent'))
        local localPlayer = Players.LocalPlayer
        local rng = Random.new(DateTime.now().UnixTimestamp)
        local jobId = game.JobId
        local furniture = Furniture.GetFurnituresKey()
        local baitboxCount = 0
        local strollerId = GetInventory.GetUniqueId('strollers', 'stroller-default')
        local tryRedeemHomepass = function()
            local count = ClientData.get_data()[localPlayer.Name].battle_pass_manager.house_pets_2025_pass_1.rewards_claimed

            if not count then
                return
            end
            if count >= 20 then
                if Utils.BucksAmount() >= 1500 then
                    print('max redeemed. need to reset homepass')
                    RouterClient.get('BattlePassAPI/AttemptBattlePassReset'):InvokeServer('house_pets_2025_pass_1')

                    return
                end

                print('max redeemed. but has no money to reset')

                return
            end

            RouterClient.get('BattlePassAPI/ClaimReward'):InvokeServer('house_pets_2025_pass_1', count + 1)
        end
        local tryFeedAgePotion = function()
            if not getgenv().SETTINGS.FOCUS_FARM_AGE_POTION then
                if ClientData.get('pet_char_wrappers')[1] and table.find(GetInventory.GetPetEggs(), ClientData.get('pet_char_wrappers')[1].pet_id) then
                    Utils.PrintDebug('is egg, not feeding age potion')
                else
                    if ClientData.get('pet_char_wrappers')[1] and table.find(getgenv().SETTINGS.PET_ONLY_PRIORITY_NAMES, ClientData.get('pet_char_wrappers')[1].pet_unique) then
                        Utils.PrintDebug('FEEDING AGE POTION')
                        Utils.FeedAgePotion(GetInventory.GetPetEggs(), 'pet_age_potion')
                        task.wait()
                        Utils.FeedAgePotion(GetInventory.GetPetEggs(), 'tiny_pet_age_potion')
                    end
                end
            end
        end
        local completeBabyAilments = function()
            if localPlayer:GetAttribute('StopFarmingTemp') == true then
                return
            end

            for key, _ in ClientData.get_data()[localPlayer.Name].ailments_manager.baby_ailments do
                if key == 'hungry' then
                    Ailment.BabyHungryAilment()

                    return
                elseif key == 'thirsty' then
                    Ailment.BabyThirstyAilment()

                    return
                elseif key == 'bored' then
                    if furniture.piano == 'nil' then
                        continue
                    end

                    Ailment.BabyBoredAilment(furniture.piano)

                    return
                elseif key == 'sleepy' then
                    if furniture.basiccrib == 'nil' then
                        continue
                    end

                    Ailment.BabySleepyAilment(furniture.basiccrib)

                    return
                elseif key == 'dirty' then
                    if furniture.stylishshower == 'nil' then
                        continue
                    end

                    Ailment.BabyDirtyAilment(furniture.stylishshower)

                    return
                end
            end
        end
        local completePetAilments = function(whichPet)
            if localPlayer:GetAttribute('StopFarmingTemp') == true then
                return false
            end
            if localPlayer:GetAttribute('IsProHandler') == false and whichPet == 2 then
                return false
            end

            local petWrapper = ClientData.get_data()[localPlayer.Name].pet_char_wrappers

            if not petWrapper or not petWrapper[whichPet] then
                if not Utils.IsPetEquipped(whichPet) then
                    Utils.PrintDebug('Getting pet because its not equipped')
                    FarmingPet.GetPetToFarm(whichPet)
                end
            end
            if not ClientData.get_data()[localPlayer.Name].ailments_manager then
                return false
            end
            if not ClientData.get_data()[localPlayer.Name].ailments_manager.ailments then
                return false
            end
            if not ClientData.get_data()[localPlayer.Name].pet_char_wrappers then
                return false
            end
            if not ClientData.get_data()[localPlayer.Name].pet_char_wrappers[whichPet] then
                return false
            end

            local petUnique = ClientData.get_data()[localPlayer.Name].pet_char_wrappers[whichPet].pet_unique

            if not petUnique then
                return false
            end
            if not ClientData.get_data()[localPlayer.Name].ailments_manager.ailments[petUnique] then
                return false
            end

            local petcount = 0

            for _ in ClientData.get_data()[localPlayer.Name].ailments_manager.ailments[petUnique]do
                petcount = petcount + 1
            end

            if petcount == 0 then
                return false
            end

            Ailment.whichPet = whichPet

            for key, _ in ClientData.get_data()[localPlayer.Name].ailments_manager.ailments[petUnique]do
                if key == 'hungry' then
                    Ailment.HungryAilment()

                    return true
                elseif key == 'thirsty' then
                    Ailment.ThirstyAilment()

                    return true
                elseif key == 'sick' then
                    Ailment.SickAilment()

                    return true
                elseif key == 'pet_me' then
                    Ailment.PetMeAilment()

                    return true
                end
            end
            for key, _ in ClientData.get_data()[localPlayer.Name].ailments_manager.ailments[petUnique]do
                if key == 'salon' then
                    Ailment.SalonAilment(key, petUnique)
                    Teleport.FarmingHome()

                    return true
                elseif key == 'moon' then
                    Ailment.MoonAilment(key, petUnique)

                    return true
                elseif key == 'pizza_party' then
                    Ailment.PizzaPartyAilment(key, petUnique)
                    Teleport.FarmingHome()

                    return true
                elseif key == 'school' then
                    Ailment.SchoolAilment(key, petUnique)
                    Teleport.FarmingHome()

                    return true
                elseif key == 'bored' then
                    if furniture.piano == 'nil' then
                        continue
                    end

                    Ailment.BoredAilment(furniture.piano, petUnique)

                    return true
                elseif key == 'sleepy' then
                    if furniture.basiccrib == 'nil' then
                        continue
                    end

                    Ailment.SleepyAilment(furniture.basiccrib, petUnique)

                    return true
                elseif key == 'dirty' then
                    if furniture.stylishshower == 'nil' then
                        continue
                    end

                    Ailment.DirtyAilment(furniture.stylishshower, petUnique)

                    return true
                elseif key == 'walk' then
                    Ailment.WalkAilment(petUnique)

                    return true
                elseif key == 'toilet' then
                    if furniture.ailments_refresh_2024_litter_box == 'nil' then
                        continue
                    end

                    Ailment.ToiletAilment(furniture.ailments_refresh_2024_litter_box, petUnique)

                    return true
                elseif key == 'ride' then
                    Ailment.RideAilment(strollerId, petUnique)

                    return true
                elseif key == 'play' then
                    if not Ailment.PlayAilment(key, petUnique) then
                        return false
                    end

                    return true
                end
            end
            for key, _ in ClientData.get_data()[localPlayer.Name].ailments_manager.ailments[petUnique]do
                if key == 'beach_party' then
                    Teleport.PlaceFloorAtBeachParty()
                    Ailment.BeachPartyAilment(petUnique)
                    Teleport.FarmingHome()

                    return true
                elseif key == 'camping' then
                    Teleport.PlaceFloorAtCampSite()
                    Ailment.CampingAilment(petUnique)
                    Teleport.FarmingHome()

                    return true
                elseif key == 'buccaneer_band' then
                    Ailment.BuccaneerBandAilment(petUnique)
                    Teleport.FarmingHome()

                    return true
                elseif key == 'summerfest_bonfire' then
                    Ailment.BonfireAilment(petUnique)
                    Teleport.FarmingHome()

                    return true
                end
            end
            for key, _ in ClientData.get_data()[localPlayer.Name].ailments_manager.ailments[petUnique]do
                if key:match('mystery') then
                    Ailment.MysteryAilment(key, petUnique)

                    return true
                end
            end

            return false
        end
        local setupFloor = function()
            Teleport.PlaceFloorAtFarmingHome()
            Teleport.PlaceFloorAtCampSite()
            Teleport.PlaceFloorAtBeachParty()
        end
        local startAutoFarm = function()
            task.spawn(function()
                while getgenv().SETTINGS.ENABLE_AUTO_FARM do
                    if game.JobId ~= jobId then
                        getgenv().SETTINGS.ENABLE_AUTO_FARM = false

                        Utils.PrintDebug(' \u{26d4} not same jobid so exiting \u{26d4}')
                        task.wait(60)
                        game:Shutdown()

                        return
                    end
                    if localPlayer:GetAttribute('StopFarmingTemp') == true then
                        local count = 0

                        repeat
                            Utils.PrintDebug('Stopping because its buying or aging or in minigame')

                            count = count + 20

                            task.wait(20)
                        until not localPlayer:GetAttribute('StopFarmingTemp') or count > 300

                        localPlayer:SetAttribute('StopFarmingTemp', false)
                    end

                    Utils.RemoveHandHeldItem()

                    if getgenv().SETTINGS.HATCH_EGG_PRIORITY then
                        FarmingPet.CheckIfEgg(1)
                        task.wait(1)

                        if localPlayer:GetAttribute('isProHandler') then
                            FarmingPet.CheckIfEgg(2)
                            task.wait(1)
                        end
                    end
                    if getgenv().SETTINGS.FOCUS_FARM_AGE_POTION then
                        Taskboard:NewClaim()

                        if not FarmingPet.GetTaskBoardPet(1) then
                            FarmingPet.GetPetToFarm(1)
                        end

                        task.wait(1)
                    end
                    if not completePetAilments(1) then
                        task.wait()
                        completeBabyAilments()
                    end

                    task.wait(1)

                    if not getgenv().SETTINGS.FOCUS_FARM_AGE_POTION then
                        FarmingPet.SwitchOutFullyGrown(1)

                        if localPlayer:GetAttribute('isProHandler') then
                            FarmingPet.SwitchOutFullyGrown(2)
                        end
                    end
                    if baitboxCount > 600 then
                        local baitUnique = Utils.FindBait()

                        Utils.PlaceBaitOrPickUp(furniture.lures_2023_normal_lure, baitUnique)
                        task.wait(2)
                        Utils.PlaceBaitOrPickUp(furniture.lures_2023_normal_lure, baitUnique)

                        baitboxCount = 0
                    end

                    tryFeedAgePotion()
                    tryRedeemHomepass()
                    UpdateTextEvent:Fire()

                    local waitTime = rng:NextNumber(5, 15)

                    baitboxCount = baitboxCount + waitTime

                    Utils.PrintDebug(string.format('waiting %s', tostring(waitTime)))
                    task.wait(waitTime)
                end
            end)
        end

        function self.Init() end
        function self.Start()
            if not getgenv().SETTINGS.ENABLE_AUTO_FARM then
                Utils.PrintDebug('ENABLE_AUTO_FARM is false')

                return
            end
            if getgenv().SETTINGS.PET_AUTO_FUSION then
                Fusion.MakeMega(false)
                Fusion.MakeMega(true)
                task.wait(2)
            end

            setupFloor()
            CollisionsClient.set_collidable(false)
            task.wait(2)
            Teleport.FarmingHome()
            Utils.PrintDebug('teleported to farming place')
            Utils.PrintDebug('Started Farming')
            localPlayer:SetAttribute('hasStartedFarming', true)
            Utils.UnEquipAllPets()
            task.wait(2)
            FarmingPet.GetPetToFarm(1)
            task.wait(2)

            if localPlayer:GetAttribute('isProHandler') == true then
                FarmingPet.GetPetToFarm(2)
            end

            startAutoFarm()
        end

        return self
    end
end

getgenv().SETTINGS = {
    DEBUG_MODE = true,
    EVENT = {
        DO_MINIGAME = true,
        IS_AUTO_BUY = false,
        BUY = 'halloween_2024_chick_box',
    },
    BAIT_TO_USE_IN_ORDER = {
        'ice_dimension_2025_shiver_cone_bait',
        'ice_dimension_2025_subzero_popsicle_bait',
        'ice_dimension_2025_ice_soup_bait',
    },
    PET_TO_BUY = 'moon_2025_egg',
    FOCUS_FARM_AGE_POTION = true,
    ENABLE_AUTO_FARM = true,
    SET_FPS = 2,
    PET_NEON_PRIORITY = true,
    PET_AUTO_FUSION = true,
    ENABLE_TRASH_COLLECTOR = false,
    TRASH_COLLECTOR_NAMES = {
        'Levi_FUSI0N2003YT',
    },
    ENABLE_TRADE_COLLECTOR = true,
    TRADE_ONLY_LUMINOUS_MEGA = true,
    TRADE_COLLECTOR_NAME = {
        'gottago83',
        'exp_potion',
        'Tiredbloxypets',
        'Chest19548',
        'Chest28745',
        'tr67ht',
        'McneilLeahw9',
        'WeissKennethp9',
        'FlynnJeanettec0286',
        'CareyPattyd191',
        'WadeTonyz9',
    },
    TRADE_LIST = {},
    HATCH_EGG_PRIORITY = false,
    HATCH_EGG_PRIORITY_NAMES = {
        'aztec_egg_2025_aztec_egg',
    },
    PET_ONLY_PRIORITY = false,
    PET_ONLY_PRIORITY_NAMES = {
        'moon_2025_glormy_dolphin',
    },
}

setfpscap(getgenv().SETTINGS.SET_FPS or 2)

if not game:IsLoaded() then
    game.Loaded:Wait()
end
if game.PlaceId ~= 920587237 then
    return
end

setfpscap(getgenv().SETTINGS.SET_FPS or 2)

local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local Players = cloneref(game:GetService('Players'))
local UserGameSettings = UserSettings():GetService('UserGameSettings')

UserGameSettings.GraphicsQualityLevel = 1
UserGameSettings.MasterVolume = 0

local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
local RouterClient = (Bypass('RouterClient'))
local localPlayer = Players.LocalPlayer
local NewsApp = (localPlayer:WaitForChild('PlayerGui'):WaitForChild('NewsApp'))

repeat
    task.wait(5)
until NewsApp.Enabled or localPlayer.Character

for i, v in debug.getupvalue(RouterClient.init, 7)do
    v.Name = i
end

getgenv().auto_accept_trade = false
getgenv().auto_trade_all_pets = false
getgenv().auto_trade_fullgrown_neon_and_mega = false
getgenv().auto_trade_multi_choice = false
getgenv().auto_trade_custom = false
getgenv().auto_trade_semi_auto = false
getgenv().auto_trade_lowtier_pets = false
getgenv().auto_trade_rarity_pets = false
getgenv().auto_farm = false
getgenv().auto_make_neon = false
getgenv().auto_trade_Legendary = false
getgenv().auto_trade_custom_gifts = false
getgenv().auto_trade_all_neons = false
getgenv().auto_trade_eggs = false
getgenv().auto_trade_all_inventory = false
getgenv().feedAgeUpPotionToggle = false
getgenv().petCurrentlyFarming1 = nil
getgenv().petCurrentlyFarming2 = nil
Utils = __DARKLUA_BUNDLE_MODULES.load('b')

local files = {
    {
        PrepareAccountHandler = __DARKLUA_BUNDLE_MODULES.load('k'),
    },
    {
        DailyRewardHandler = __DARKLUA_BUNDLE_MODULES.load('l'),
    },
    {
        GameGuiHandler = __DARKLUA_BUNDLE_MODULES.load('m'),
    },
    {
        PotatoModeHandler = __DARKLUA_BUNDLE_MODULES.load('n'),
    },
    {
        StatsGuiHandler = __DARKLUA_BUNDLE_MODULES.load('p'),
    },
    {
        TradeLicenseHandler = __DARKLUA_BUNDLE_MODULES.load('q'),
    },
    {
        TutorialHandler = __DARKLUA_BUNDLE_MODULES.load('r'),
    },
    {
        AutoFarmHandler = __DARKLUA_BUNDLE_MODULES.load('v'),
    },
}

Utils.PrintDebug('----- INITIALIZING MODULES -----')

for index, _table in ipairs(files)do
    for moduleName, _ in _table do
        if files[index][moduleName].Init then
            Utils.PrintDebug(string.format('INITIALIZING: %s', tostring(moduleName)))
            files[index][moduleName].Init()
            task.wait(1)
        end
    end
end

Utils.PrintDebug('----- STARTING MODULES -----')

for index, _table in ipairs(files)do
    for moduleName, _ in _table do
        if files[index][moduleName].Start then
            Utils.PrintDebug(string.format('STARTING: %s', tostring(moduleName)))
            files[index][moduleName].Start()
            task.wait(1)
        end
    end
end
