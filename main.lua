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
        local VirtualInputManager = cloneref(game:GetService('VirtualInputManager'))
        local Workspace = cloneref(game:GetService('Workspace'))
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local Utils = {}
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local RouterClient = Bypass('RouterClient')
        local debugMode = getgenv().SETTINGS.DEBUG_MODE or false
        local localPlayer = Players.LocalPlayer

        getgenv().lastTimeFarming = DateTime.now().UnixTimestamp

        local timeChecked = false

        function Utils.SetConfigFarming(configId)
            if not getgenv().FARMSYNC then
                return
            end
            if not getgenv().FARMSYNC.ENABLED then
                return
            end
            if getgenv().client and getgenv().client:ChangeConfig(configId) then
                task.wait(math.random(1, 5))
                getgenv().client:Disconnect()
                localPlayer:Kick()
                game:Shutdown()
            end
        end
        function Utils.GetPugTamingProgress()
            return ClientData.get_data()[localPlayer.Name].snowball_pug_manager.snowballpug_taming_progress or 0
        end
        function Utils.MoveToWithTimeout(humanoid, target, timeout)
            local reached = false
            local connection

            humanoid:MoveTo(target)

            connection = humanoid.MoveToFinished:Connect(function(success)
                reached = success
            end)

            local startTime = tick()

            repeat
                task.wait(0.1)
            until reached or (tick() - startTime) >= timeout

            if connection then
                connection:Disconnect()
            end

            return reached
        end
        function Utils.PlaceFLoorUnderPlayer()
            if Workspace:FindFirstChild('FloorUnderPlayer') then
                return
            end

            local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
            local humanoidRootPart = (character:WaitForChild('HumanoidRootPart'))
            local floorPart = Instance.new('Part')

            floorPart.Position = humanoidRootPart.Position + Vector3.new(0, -2.2, 0)
            floorPart.Size = Vector3.new(100, 2, 100)
            floorPart.Anchored = true
            floorPart.Transparency = 0
            floorPart.Name = 'FloorUnderPlayer'
            floorPart.Parent = Workspace
        end
        function Utils.RemoveHandHeldItem()
            local character = localPlayer.Character
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
            return ClientData.get_data()[localPlayer.Name].gingerbread_2025 or 0
        end
        function Utils.FoodItemCount(nameId)
            local count = 0

            for _, v in ClientData.get_data()[localPlayer.Name].inventory.food do
                if v.id == nameId then
                    count = count + 1
                end
            end

            return count
        end
        function Utils.PetItemCount(nameId)
            local count = 0

            for _, v in ClientData.get_data()[localPlayer.Name].inventory.pets do
                if v.id == nameId then
                    count = count + 1
                end
            end

            return count
        end
        function Utils.IsMuleInGame(playerMulesTable)
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

            if minutes % 10 == 0 and not timeChecked and getgenv().SETTINGS.ENABLE_AUTO_FARM == true then
                if not Utils.IsMuleInGame(getgenv().SETTINGS.TRADE_COLLECTOR_NAME) or localPlayer:GetAttribute('hasStartedFarming') == true then
                    timeChecked = true

                    print('10 mins has pasted checking if account is farming')

                    local timeElapsed = DateTime.now().UnixTimestamp - getgenv().lastTimeFarming

                    if timeElapsed >= (540) then
                        localPlayer:Kick('GOT STUCK')
                        game:Shutdown()
                    end

                    task.delay(60, function()
                        timeChecked = false
                    end)
                end
            end

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
                    local mouseButton1Up = button.MouseButton1Up

                    firesignal(mouseButton1Down)
                    task.wait()
                    firesignal(mouseButton1Click)
                    task.wait()
                    firesignal(mouseButton1Up)
                end)
            else
                Utils.ClickGuiButton(button)
            end
        end
        function Utils.FindButton(text, dialogFramePassOn)
            task.wait(0.1)

            dialogFramePassOn = dialogFramePassOn or 'NormalDialog'

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
                ReplicatedStorage.API['ToolAPI/Unequip']:InvokeServer(petUnique, {
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
        function Utils.Equip(unique, EquipAsLast)
            local success, errorMessage = pcall(function()
                ReplicatedStorage.API['ToolAPI/Equip']:InvokeServer(unique, {
                    ['equip_as_last'] = EquipAsLast,
                })
            end)

            if not success then
                Utils.PrintDebug('Failed to equip:', errorMessage)

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

            print(string.format('\u{1f41e} DEBUG | %s', tostring(...)))
        end
        function Utils.IsDayAndHour(day, utcHour)
            local now = DateTime.now()
            local weekday = now:FormatUniversalTime('dddd', 'en-us')
            local hour = tonumber(now:FormatUniversalTime('H', 'en-us'))

            return weekday == day and hour == utcHour
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
        function Utils.WaitForPetToEquip()
            local hasPetChar = nil
            local stuckTimer = 0

            repeat
                hasPetChar = ClientData.get('pet_char_wrappers') and ClientData.get('pet_char_wrappers')[1] and ClientData.get('pet_char_wrappers')[1].pet_unique and true or false
                stuckTimer = stuckTimer + 1

                task.wait(1)
            until hasPetChar or stuckTimer > 20

            if stuckTimer > 20 then
                return false
            end

            return true
        end
        function Utils.GetCharacter()
            return localPlayer.Character or localPlayer.CharacterAdded:Wait()
        end
        function Utils.GetHumanoid()
            local humanoid = Utils.GetCharacter():FindFirstChild('Humanoid')

            return humanoid
        end
        function Utils.GetHumanoidRootPart()
            local humanoidRootPart = Utils.GetCharacter():FindFirstChild('HumanoidRootPart')

            return humanoidRootPart
        end
        function Utils.WaitForHumanoidRootPart()
            local humanoidRootPart = Utils.GetHumanoidRootPart()

            while not humanoidRootPart do
                task.wait(1)

                humanoidRootPart = Utils.GetHumanoidRootPart()
            end

            return humanoidRootPart
        end
        function Utils.FireRedeemCode(code)
            RouterClient.get('CodeRedemptionAPI/AttemptRedeemCode'):InvokeServer(code)
        end

        return Utils
    end
    function __DARKLUA_BUNDLE_MODULES.b()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local RouterClient = Bypass('RouterClient')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('a')
        local Furniture = {}
        local localPlayer = Players.LocalPlayer

        Furniture.items = {
            basiccrib = 'nil',
            stylishshower = 'nil',
            modernshower = 'nil',
            piano = 'nil',
            lures_2023_normal_lure = 'nil',
            ailments_refresh_2024_litter_box = 'nil',
        }

        function Furniture.GetFurnituresKey()
            Utils.PrintDebug('getting furniture ids')

            local houseInterior = ClientData.get_data()[localPlayer.Name].house_interior

            if houseInterior then
                for key, value in houseInterior.furniture do
                    if value.id == 'basiccrib' then
                        Furniture.items['basiccrib'] = key
                    elseif value.id == 'stylishshower' or value.id == 'modernshower' then
                        Furniture.items['stylishshower'] = key
                        Furniture.items['modernshower'] = key
                    elseif value.id == 'piano' then
                        Furniture.items['piano'] = key
                    elseif value.id == 'lures_2023_normal_lure' then
                        Furniture.items['lures_2023_normal_lure'] = key
                    elseif value.id == 'ailments_refresh_2024_litter_box' then
                        Furniture.items['ailments_refresh_2024_litter_box'] = key
                    end
                end
            end
        end
        function Furniture.BuyFurniture(furnitureId)
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
        function Furniture.subscribeToHouse(playerName)
            RouterClient.get('HousingAPI/SubscribeToHouse'):FireServer(playerName)
        end

        return Furniture
    end
    function __DARKLUA_BUNDLE_MODULES.c()
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
                'penguins_2025_dango_penguins',
                'pet_recycler_2025_giant_panda',
            },
        }
    end
    function __DARKLUA_BUNDLE_MODULES.d()
        return {
            'soda_fountain_water',
            'coffee_paper_cup',
            'pizza_shop_pizza',
            'popcorn',
            'hotdog',
            'ice_cream_2025_snow_cone',
            'lures_2023_magma_melon',
            'apple',
            'candy_floss_chew',
            'smores',
            'pizza_shop_tomato',
            'raspberry_pie',
            'snow_2022_ice_lolly',
            'water',
            'donut',
            'tea',
            'soda',
            'chocolate_milk',
            'lemonade',
            'cheese',
            'jasmine_tea_cup',
            'seaweed',
            'pizza',
            'baby_bottle',
            'cookie',
            'candycane',
            'chocolate_drop',
            'gibbon_2025_cinnamon_roasted_almonds',
            'ice_cream_2025_cup',
            'fall_2022_cinnamon_roll',
            'burger',
            'patterns_egg',
            'sofahog_2024_diner_hot_dog_and_fries',
            'honey_candy',
            'watermelon',
            'oolong_tea_cup',
            'sandwich',
            'ice_tub',
            'sofahog_2024_diner_milkshake',
            'honey',
            'pizza_shop_mushroom',
            'pet_food',
            'dim_sum',
            'golden_goldfish',
            'water_paper_cup',
            'stripes_egg',
            'cake',
            'soda_fountain_soda',
            'green_tea_cup',
            'chocolate_twist',
            'ham',
            'pizza_shop_ham',
            'stars_egg',
            'coffee',
            'cotton_candy_stick',
            'blueberry_pie',
            'sofahog_2024_diner_mac_and_cheese',
            'icecream',
            'babyformula',
            'lolipop',
            'rain_2023_coconut_drink',
            'sofahog_2024_diner_lemonade',
            'winter_2023_hot_cocoa',
            'pizza_shop_pepperoni',
            'lures_2023_overcooked_tart',
            'taco',
            'sofahog_2024_diner_pancakes',
            'sofahog_2024_diner_apple_pie',
            'pizza_shop_pineapple',
            'desert_2022_mud_ball',
            'mooncake',
            'pizza_shop_cheese',
            'rose',
            'halloween_2022_bat_lollipop_earrings',
            'pink_instant_camera',
            'cassette',
            'pink_cap',
            'gifthat_november_2024_ponytail',
            'fall_2022_candy_apple',
            'gifthat_may_2024_duck_feet',
            'fur_boots',
            'pink_bowtie',
            'halloween_2021_pumpkin_friend',
            'fez',
            'gifthat_2023_fire_axe',
            'legend_hat_sept_2022_writing_brush',
            'gift_refresh_2023_heart_ribbon',
            'easter_2022_spring_bunny_hood',
            'legend_hat_2022_fantasy_blade',
            'gifthat_may_2024_unfortunate_eyelashes',
            'gifthat_may_2024_clown_wig',
            'winter_2023_elf_bandana',
            'legend_hat_2022_tool_box',
            'wave_badge',
            'rain_2023_spyglass_glasses',
            'ace_pride_pin',
            'black_hightops',
            'halo',
            'legend_hat_sept_2022_paper_bag_hat',
            'winter_2021_red_christmas_stocking_shoes',
            'detective_hat',
            'legend_hat_sept_2022_puffer_jacket',
            'yellow_5_panel_cap',
            'gift_refresh_2023_ar_headset',
            'legend_hat_sept_2022_bumblebee_hat',
            'legend_hat_2022_cool_quad_skates',
            'gifthat_2023_potion_necklace',
            'soccer_2024_italy_scarf',
            'red_ribbon',
            'winter_2021_red_scarf',
            'halloween_2023_wicked_boots',
            'growing_flower_hat',
            'eyepatch',
            'eco_grey_origami_boat_hat',
            'summerfest_2024_corndog_mustache',
            'winter_2023_ugly_christmas_cape',
            'gifthat_may_2024_exposed_brain',
            'legend_hat_2022_leaf_sprout_hat',
            'lny_2022_collar',
            'snow_2022_fluffy_earmuffs',
            'lavender_scarf',
            'bee_hive',
            'springfest_2023_flower_bunny_ears',
            'spring_2025_sakura_wings',
            'briefcase',
            'gifthat_november_2024_bush_backpack',
            'winter_2024_ice_shoes',
            'gifthat_may_2024_castle_tower',
            'gay_man_pride_pin',
            'halloween_2022_mule_baskets',
            'halloween_2024_gothic_horns',
            'legend_hat_sept_2022_glass_slippers',
            'fall_2022_badge',
            'antenna',
            'star_rewards_2022_wind_turbine_earrings',
            'sketchbook',
            [[gifthat_november_2024_strawberry_shortcake_bat_dragon_backpack]],
            'legend_hat_2022_sandwich_hat',
            'gifthat_november_2024_natures_crown',
            'legend_hat_2022_back_taco',
            'halloween_2024_slime_shades',
            'gifthat_november_2024_radish_friend',
            'gifthat_2023_gemstone_band',
            'jade_moth_wings',
            'legend_hat_sept_2022_brain_jar',
            'winter_2023_marshmallow_friend',
            'snow_2022_snow_cloud_wings',
            'eco_red_apple_basket_hat',
            'aromantic_pride_pin',
            'red_bowtie',
            'rgb_laptop',
            'soccer_2024_denmark_soccer_earrings',
            'eco_orange_maple_leaf_scarf',
            'gift_refresh_2023_rain_cloud_hat',
            'gifthat_may_2024_human_feet_shoes',
            'red_beanie',
            'winter_2024_gingerbread_beard',
            'watermelon_backpack',
            'sky_ux_2023_macaw_wings',
            'lunar_2024_hanbok',
            'gorilla_fair_2023_tuxedo_top_hat',
            'explorer_hat',
            'legend_hat_2022_magical_staff',
            'lunar_2024_rice_cake_hat',
            'beaked_whale_badge',
            'legend_hat_2022_crayon_mohawk',
            'ice_wings',
            'lunar_2025_dancing_lion_mask',
            'gifthat_2023_bell_flower_hat',
            'gifthat_november_2024_microphone',
            'fall_2022_rake_wings',
            'moon_tome',
            'gifthat_may_2024_angry_eyebrows',
            'angel_wings',
            'yellow_designer_backpack',
            'bucket_hat',
            'flower_crown',
            'pride_2022_butterfly_clip',
            'gifthat_2023_flower_lapel',
            'spring_2025_ninja_collar',
            'gifthat_november_2024_cactus_bat',
            'eco_blue_recycling_bin_badge',
            'eco_brown_hiking_backpack',
            'fall_2022_pumpkin_knit_hat',
            'springfest_2023_cherry_blossom_earring',
            'halloween_2023_jack_o_lantern_shades',
            'wings_2022_invisible_wings',
            'gifthat_may_2024_doggy_door_face',
            'forgotten_flower',
            'legend_hat_2022_modern_jetpack',
            'pib_2022_boots',
            'gifthat_may_2024_sheriffs_badge',
            'gifthat_november_2024_gothic_necklace',
            'legend_hat_sept_2022_bamboo_bindle',
            'purple_and_green_beads',
            'sing2_reward_space_helmet',
            'pride_2022_pride_headphones',
            'legend_hat_2022_ten_gallon_hat',
            'gifthat_november_2024_jailers_keys',
            'pride_2022_pride_glasses',
            'legend_hat_2022_crystal_necklace',
            'halloween_2022_candy_corn_hat',
            'gifthat_2023_formal_big_bow_hat',
            'eco_orange_maple_leaf_mustache',
            'bee_wings',
            'ice_crown',
            'legend_hat_sept_2022_aviator_hat',
            'winter_2023_festive_beard',
            'legend_hat_sept_2022_knight_helmet',
            'black_boots',
            'legend_hat_sept_2022_viking_shield',
            'gifthat_november_2024_steel_toe_heel',
            'gifthat_2023_two_toned_fedora',
            'gifthat_2023_mailbox_hat',
            'gifthat_2023_cyborg_eye',
            'lny_2023_earring',
            'halloween_2022_bat_backpack',
            'fall_2022_striped_fall_scarf',
            'gifthat_2023_balloon_dog',
            'beret',
            'gorilla_fair_2023_chef_accessory',
            'gifthat_november_2024_sky_wings',
            'gifthat_may_2024_african_bead_necklace',
            'ivy_necklace',
            'egg_barrette',
            'legend_hat_2022_cowboy_boots',
            'legend_hat_2022_victorian_collar',
            'gift_refresh_2023_carrot_headphones',
            'legend_hat_sept_2022_lightbulb_hat',
            'gifthat_2023_copter_cap',
            'ski_goggles',
            'winter_2023_hot_cocoa_hat',
            'eco_red_cranberry_branch_wings',
            'summerfest_2023_summer_straw_hat',
            'socks_and_sandals',
            'soccer_2024_switzerland_soccer_boots',
            'ice_dimension_2025_ice_monocle',
            'gifthat_may_2024_solar_system_necklace',
            'gifthat_november_2024_raven_hood',
            'eco_green_leaf_glasses',
            'eco_green_vine_barrette',
            'rain_2023_parrot_hood',
            'wings_2022_magpie_wings',
            'snow_2022_snowflake_earrings',
            'nautilus_shell_necklace',
            'legend_hat_2022_puddleducks_hood',
            'winter_2022_gingerbread_star_eye_patch',
            'windup_key',
            'st_patricks_2025_leprechaun_shoes',
            'summerfest_2024_peace_shades',
            'summerfest_2023_flowery_sunhat',
            'spike_collar',
            'gifthat_november_2024_balloon_flower_hat',
            'green_lotus',
            'sperm_whale_badge',
            'ruff',
            'winter_2024_snowy_tree_hat',
            'gifthat_2023_bone_booties',
            'rgb_headset',
            'summerfest_2024_sticky_hand_earrings',
            'legend_hat_sept_2022_chimney_hat',
            'orange_backpack',
            'pink_heart_glasses',
            'lunar_2025_knot_earrings',
            'striped_necktie',
            'red_back_ribbon',
            'legend_hat_2022_rainbow_bucket_hat',
            'legend_hat_2022_rainbow_maker',
            'halloween_2024_witch_nose',
            'rain_2023_rain_leaf_wings',
            'gifthat_2023_living_wizard_hat',
            'legend_hat_sept_2022_skull_toy',
            'capuchin_2024_cool_sunglasses',
            'spring_2025_kaijunior_hat',
            'gay_pride_pin',
            'halloween_2023_death_cloak',
            'gifthat_may_2024_long_fringe',
            'halloween_2023_monster_hat',
            'halloween_2021_gravestone_backpack',
            'halloween_2022_spider_web_crown',
            'gifthat_2023_thimble_cap',
            'legend_hat_2022_ronin_hat',
            'ice_dimension_2025_ice_cape',
            'chick_hat',
            'traffic_cone',
            'gift_refresh_2023_fragile_box',
            'ice_dimension_2025_frozen_crown',
            'witch_boots',
            'winter_2023_wreath_necklace',
            'gift_refresh_2023_fairy_bell_necklace',
            'gifthat_november_2024_star_hoodie',
            'legend_hat_2022_guitar_case',
            'white_cozy_hood',
            'gibbon_2025_mobile_phone',
            'gifthat_may_2024_bucket_shoes',
            'gift_refresh_2023_golden_circlet',
            'party_crown',
            'rain_2023_rain_badge',
            'gift_refresh_2023_winged_necklace',
            'moon_2025_crater_flag_hat',
            'sky_ux_2023_fairy_wings',
            'rb_battles_trophy_hat',
            'capuchin_2024_preppy_sweater',
            'halloween_2024_midnight_wings',
            'skeleton_shell',
            'red_necktie',
            'gorilla_fair_2023_tuxedo_tie',
            'halloween_2024_web_cape',
            'birthday_2022_party_hat',
            'gifthat_may_2024_brick_pile',
            'hoop_earrings',
            'sunshine_2024_sports_shirt',
            'gifthat_may_2024_ferris_wheel_hat',
            'legend_hat_2022_gold_coin_monocle',
            'reindeer_antlers',
            'legend_hat_sept_2022_snorkel_set',
            'sky_ux_2023_clockwork_wings',
            'gifthat_2023_cheese_hat',
            'gifthat_2023_plunger_hat',
            'eco_yellow_corncob_bowtie',
            'desert_2022_pyramids_badge',
            'gift_refresh_2023_sausage_link',
            'sunhat',
            'birthday_2022_party_horn',
            'birthday_2022_cupcake_shoes',
            'gifthat_november_2024_stylish_neckerchief',
            'headset',
            'black_bandana',
            'newsboy_cap',
            'sunshine_2024_silver_medal',
            'springfest_2023_flower_wreath_pin',
            'gifthat_2023_sticky_stick',
            'halloween_2021_cauldron_hat',
            'gifthat_2023_water_can',
            'rain_2023_rainy_cloud_earrings',
            'gift_refresh_2023_lace_heart_backpack',
            'desert_2022_lotus_earrings',
            'gifthat_may_2024_walrus_tusks',
            'legend_hat_2022_nest_of_eggs',
            'legend_hat_2022_unicorn_horn',
            'gifthat_november_2024_orange_hat',
            'gift_refresh_2023_welders_mask',
            'gifthat_november_2024_flower_drop_earrings',
            'red_sneakers',
            'halloween_2022_ghost_hat',
            'witch_broom',
            'halloween_2024_sorcerer_wand',
            'gifthat_2023_bready_necklace',
            'fire_dimension_2024_flame_cape',
            'cute_circle_glasses',
            'summerfest_2023_beach_umbrella',
            'black_purse',
            'summerfest_2024_strongperson_barbell',
            'white_purse',
            'gift_refresh_2023_stitched_up_beanie',
            'buzz_off_skateboard',
            'capuchin_2024_princess_booties',
            'moon_2025_lunar_new_year_headdress',
            'snow_2022_cosy_snow_scarf',
            'wings_2022_magic_girl_wings',
            'ice_earrings',
            'shuriken',
            'gifthat_2023_triangle_shades',
            'winter_2024_ice_halo',
            'winter_2024_tree_skirt',
            'moon_2025_moon_boots',
            'legend_hat_sept_2022_boxing_glove_necklace',
            'winter_2024_santas_bow',
            'gift_refresh_2023_frigid_hat',
            'winter_2024_gold_fairy_crown',
            'sky_ux_2023_gull_wings',
            'jetpack',
            'winter_2024_adopt_lanyard',
            'desert_2022_nemes_headdress',
            'winter_2024_snowman_nose',
            'birthday_2022_confetti_drape',
            'gibbon_2025_whistle_necklace',
            'winter_2024_jinglebell_earrings',
            'legend_hat_2022_angler_fish_light',
            'winter_2023_christmas_tree_earrings',
            'legend_hat_2022_googly_eye_glasses',
            'legend_hat_sept_2022_hair_buns',
            'desert_2022_wesekh_necklace',
            'winter_2023_poinsettia_hair_clip',
            'halloween_2023_ball_and_chain_earrings',
            'winter_2023_holly_crown',
            'winter_2023_christmas_boots',
            'legend_hat_2022_saucepan_hat',
            'legend_hat_2022_clan_banner',
            'winter_2023_reindeer_hood',
            'winter_2023_gingerbread_wings',
            'sunglasses',
            'gift_refresh_2023_foragers_reward',
            'sky_ux_2023_ember_wings',
            'winter_2023_sleigh_earrings',
            'gifthat_november_2024_butterfly_headphones',
            'winter_2023_2024_glasses',
            'winter_2023_candy_cane_wings',
            'winter_2022_strawberry_crown',
            'gift_refresh_2023_laced_yellow_heels',
            'winter_2021_red_mistletoe_hat',
            'winter_2021_golden_walrus_crown',
            'trans_pride_pin',
            'winter_2021_red_candy_cane',
            'winter_2021_yellow_star_pin',
            'leaf_wings',
            'gift_refresh_2023_joystick_controller',
            'winter_2021_blue_eggnog_hat',
            'eco_glowing_lightbulb_necklace',
            'neckerchief',
            'bug_net',
            'sunshine_2024_sports_hat',
            'gift_refresh_2023_heart_bucket_hat',
            'golden_headset',
            'sky_ux_2023_flying_fish_wings',
            'black_bowtie',
            'legend_hat_sept_2022_winged_cap',
            'lny_2022_red_envelope',
            'fire_dimension_2024_heat_vent_hat',
            'eco_brown_pinecone_earrings',
            'gift_refresh_2023_feather_boa',
            'springfest_2023_strawberry_clip',
            'birthday_2022_confetti_cannon',
            'respectful_mustache',
            'bunny_ear_tiara',
            'snow_2022_tundra_explorer_goggles',
            'summerfest_2024_cotton_candy_hat',
            'leprechaun_hat',
            'detective_mustache',
            'eco_orange_pumpkin_pie_wings',
            'legend_hat_sept_2022_curved_bow',
            'headband',
            'fried_egg',
            'gold_chain',
            'bi_pride_pin',
            'capuchin_2024_royal_capuchin_cape',
            'pink_bandana',
            'goth_shoes',
            'fall_2022_donut_glasses',
            'legend_hat_2022_cowboy_saddle',
            'blue_sneakers',
            'legend_hat_2022_spikey_hair_wig',
            'moon_2025_alien_eyes_hat',
            'gift_refresh_2023_shovel',
            'lures_2023_flame_glasses',
            'festive_tree_hat',
            'k9_badge',
            'sunshine_2024_bronze_medal',
            'celestial_2024_galaxy_boots',
            'legend_hat_sept_2022_yarn_ball_toy',
            'eco_orange_pumpkin_eyepatch',
            'demi_pride_pin',
            'chicken_hat',
            'gifthat_may_2024_chinese_tea_tray',
            'morion',
            'flower_collar',
            'number_one_ribbon',
            'easter_2024_flower_bunny_clip',
            'eco_green_vine_badge',
            'pearl_necklace',
            'sun_tome',
            'aviators',
            'easter_2022_three_egg_basket',
            'pink_butterfly_wings',
            'gifthat_november_2024_love_letter',
            'jokes_2024_arrow_through_head_hat',
            'legend_hat_2022_carrot_on_a_stick',
            'rain_boots',
            'pink_designer_backpack',
            'gifthat_may_2024_snack_and_beverage_carrier',
            'pink_boots',
            'gifthat_november_2024_flower_scarf',
            'amber_earrings',
            'gifthat_may_2024_steampunk_clock_hat',
            'pink_hightops',
            'pink_lotus',
            'sky_ux_2023_flower_wings',
            'firey_aura',
            'platinum_tiara',
            'purple_masquerade_mask',
            'halloween_2024_fang_necklace',
            'gardener_hat',
            'luggage',
            'black_cozy_hood',
            'construction_hat',
            'eco_orange_maple_cape',
            'prescription_glasses',
            'gifthat_2023_fire_hydrant',
            'rain_hat',
            'valentines_2025_heart_bow',
            'red_and_yellow_beads',
            'eco_orange_maple_headpiece',
            'red_butterfly',
            'red_masquerade_mask',
            'easter_2022_spring_bunny_nose',
            'red_purse',
            'pretty_red_bow',
            'gift_refresh_2023_winged_cap',
            'whale_badge',
            'winter_2024_winter_bow_wings',
            'penguin_comp_2022_ice_cream_cone_hat',
            'daisy_glasses',
            'santa_hat',
            'eco_brown_branch_headphones',
            'capuchin_2024_royal_capuchin_saber_pin',
            'gift_refresh_2023_safety_pin_beanie',
            'shadow_wings',
            'gifthat_2023_heavy_anvil',
            'legend_hat_sept_2022_walkie_talkie',
            'springfest_2023_flower_beret',
            'head_tie',
            'spin_masters_purse_pet',
            'springfest_2023_flower_monocle',
            'lny_2023_dumpling_friend',
            'scythe',
            'silver_chain',
            'chef_hat',
            'blue_backpack',
            'gifthat_november_2024_fortune_teller_hood',
            'black_5_panel_cap',
            'legend_hat_2022_battle_axe',
            'legend_hat_sept_2022_fur_collared_cape',
            'gift_refresh_2023_burger_boots',
            'beluga_badge',
            'clear_glasses',
            'skis',
            'adventurers_hood',
            'legend_hat_sept_2022_rubber_ducks',
            'gifthat_2023_dino_hood',
            'strawberry_hat',
            'winter_scarf',
            'gift_refresh_2023_spikey_goggles',
            'winter_2021_summer_walrus_sunhat',
            'spring_glasses',
            'soccer_2024_romania_soccer_cap',
            'striped_tophat',
            'gifthat_november_2024_heart_eyepatch',
            'soccer_2024_belgium_scarf',
            'gift_refresh_2023_bear_cap',
            'jeffs_nametag',
            'halloween_2021_skull_hat',
            'sunshine_2024_sports_shoes',
            'black_scarf',
            'soccer_2024_france_soccer_cap',
            'turtle_shell',
            'sombrero',
            'gifthat_november_2024_rocket_ship_hat',
            'umbrella_hat',
            'vampire_cape',
            'easter_2024_egg_friends_backpack',
            'legend_hat_2022_life_preserver',
            'legend_hat_sept_2022_flower_power_earrings',
            'pink_cat_ear_headphones',
            'legend_hat_sept_2022_vr_goggles',
            'fancy_top_hat',
            'propeller_hat',
            'gifthat_2023_satellite_spinner',
            'gifthat_may_2024_dancing_tube_hat',
            'halloween_2021_axe_guitar',
            'white_designer_backpack',
            'spring_2025_spiky_blue_hair',
            'white_winter_hat',
            'pride_2022_gender_queer_pride_pin',
            'halloween_2024_monster_friend_hat',
            'witch_hat',
            'gift_refresh_2023_card_reader',
            'gifthat_november_2024_watermelon_shoes',
            'soccer_2024_england_soccer_boots',
            'kiwi_2023_red_scarf',
            'legend_hat_sept_2022_bear_hood',
            'wool_beard',
            'pink_5_panel_cap',
            'gibbon_2025_folded_paper_wings',
            'yellow_cap',
            'gibbon_2025_firefighter_boots',
            'halloween_2022_planchette_hair_clip',
            'snowman_winter_hat',
            'monkey_king_crown',
            'gifthat_may_2024_viking_beard',
            'summerfest_2023_lei',
            'pink_sneakers',
            'summerfest_2024_target_board',
            'cowboy_hat',
            'white_visor',
            'summerfest_2024_pretzel_eye_patch',
            'flowery_hair_bow',
            'gibbon_2025_fire_hose_scarf',
            'eco_green_vine_mustache',
            'genderfluid_pride_pin',
            'leaf_crown',
            'black_sneakers',
            'legend_hat_sept_2022_money_hat',
            'wings_2022_fantasy_wings',
            'gifthat_2023_personal_controller',
            'gifthat_november_2024_tv_hood',
            'eco_white_spider_web_badge',
            'halloween_2023_skull_bow',
            'chick_backpack',
            'gift_refresh_2023_pancake_stack',
            'lures_2023_volcano_hat',
            'yellow_instant_camera',
            'gifthat_november_2024_shooting_star_glasses',
            'red_collar',
            'lny_2022_shoes',
            'soccer_2024_germany_bucket_hat',
            'gift_refresh_2023_winged_heels',
            'blue_butterfly_wings',
            'blue_cap',
            'yellow_sneakers',
            'lny_2023_shoes',
            'eco_blue_recycling_bin_hat',
            'easter_2024_flower_hair',
            'celestial_2024_galaxy_collar',
            'picnic_basket',
            'sky_ux_2023_paper_wings',
            'gifthat_may_2024_venus_flytrap_hat',
            'gifthat_2023_robotic_runners',
            'conductor_hat',
            'halloween_2021_evil_barrel_backpack',
            'egg_glasses',
            'eco_green_leaf_afro',
            'shark_fin',
            'eco_red_apple_hat',
            'gifthat_november_2024_raven_collar',
            'orange_glasses',
            'flamenco_hat',
            'froggy_hat',
            'gifthat_november_2024_bow_shoes',
            'eco_orange_maple_earrings',
            'k9_hat',
            'handheld',
            'eco_black_tree_motif_cap',
            'killer_whale_badge',
            'enby_pride_pin',
            'gift_refresh_2023_waterfall_hat',
            'yellow_beanie',
            'gold_circle_glasses',
            'shadow_shuriken',
            'pride_2022_pride_wings',
            'rain_2023_captains_jacket',
            'adventurers_sword',
            'gift_refresh_2023_royal_crown_pillow',
            'agender_pride_pin',
            'gifthat_november_2024_cherry_blossom_glasses',
            'pride_2022_pride_earrings',
            'black_designer_backpack',
            'lgbtq_pride_pin',
            'monocle',
            'guitar_accessory',
            'soccer_2024_spain_soccer_earrings',
            'capuchin_2024_ship_wheel_necklace',
            'head_chef',
            'wdc_badge',
            'spring_2025_black_hero_hair',
            'thermometer',
            'eco_orange_leaf_wings',
            'icepack',
            'legend_hat_2022_honey_jar',
            'bat_wings',
            'elf_hat',
            'gifthat_2023_flower_cloche',
            'pirate_hat_and_friend',
            'gifthat_november_2024_constellation_cape',
            'pride_2022_omnisex_pride_pin',
            'bewitched_hat',
            'dolphin_badge',
            'eco_blue_solar_panel_backpack',
            'gift_refresh_2023_katana_set',
            'gifthat_2023_spray_can',
            'eco_blue_reusable_bottle_backpack',
            'tusks',
            'wizard_hat',
            'white_bandana',
            'cutlass',
            'gifthat_2023_fox_eared_beret',
            'gifthat_may_2024_monstera_plant_pot',
            'legend_hat_sept_2022_skater_helmet',
            'bowler',
            'valentines_2025_heart_heels',
            'gift_refresh_2023_monstera_leaf_cape',
            'watermelon_hat',
            'rain_2023_fishers_headdress',
            'gibbon_2025_police_cap',
            'summerfest_2024_magic_hat_face',
            'gifthat_may_2024_honey_bee_collar',
            'winter_2023_festive_light_crown',
            'pirate_hat',
            'legend_hat_sept_2022_footwrap_shoes',
            'gorilla_fair_2023_tuxedo_walking_stick',
            'shadow_aura',
            'gibbon_2025_villainous_eyebrows',
            'black_fedora',
            'cyborg_shades',
            'gifthat_2023_golden_hair',
            'pocket_protector',
            'gifthat_may_2024_nose_goop',
            'springfest_2023_buttercup_collar',
            'eco_brown_earth_wizard_hat',
            'eco_red_mushroom_hood',
            'pan_pride_pin',
            'brown_cozy_hood',
            'gifthat_2023_fancy_footwear',
            'legend_hat_2022_toaster_hat',
            'cherry_earrings',
            'purple_rose',
            'buttoned_ushanka',
            'pib_2022_sword',
            'gifthat_2023_claw_grabber',
            'gifthat_2023_nap_mask',
            'birthday_2022_birthday_cake',
            'jokes_2024_disguise_glasses',
            'icey_aura',
            'cowbell',
            'gift_refresh_2023_hourglass',
            'desert_2022_horus_monocle',
            'halloween_2023_evil_headphones',
            'sunshine_2024_gold_medal',
            'wings_2022_clam_wings',
            'legend_hat_sept_2022_stethoscope',
            'sunshine_2024_laurel_wreath',
            'gifthat_may_2024_viking_helmet',
            'lny_2022_mandarin_hat',
            'gifthat_2023_safety_scissors',
            'white_bowtie',
            'clout_goggles',
            'legend_hat_sept_2022_space_helmet',
            'gibbon_2025_fancy_top_hat',
            'gift_refresh_2023_fishbone_badge',
            'halloween_2023_eye_bat_monocle',
            'legend_hat_sept_2022_sock_hat',
            'gift_refresh_2023_giraffe_bucket_hat',
            'halloween_2021_candy_corn_earrings',
            'purple_heart_glasses',
            'summerfest_2023_shark_swim',
            'eco_brown_wooden_clogs',
            'fall_2022_wreath_necklace',
            'summerfest_2024_shooting_star_earrings',
            'gorilla_fair_2023_karate_accessory',
            'gifthat_may_2024_half_skirt',
            'bear_winter_hat',
            'halloween_2022_ghost_kitty_backpack',
            'nest',
            'gifthat_2023_winged_medal',
            'summerfest_2023_drinks_cooler',
            'summerfest_2023_star_sunglasses',
            'likes_reward_2025_cap',
            'halloween_2024_sorcerer_hat',
            'summerfest_2024_knockdown_cans',
            'summerfest_2023_duck_floatie',
            'gibbon_2025_super_hero_hair',
            'gifthat_november_2024_kraken_hat',
            'gift_refresh_2023_lava_lamp_hat',
            'summerfest_2023_diving_fins',
            'st_patricks_2025_leprechaun_jacket',
            'sailor_cap',
            'rgb_collar',
            'spring_2025_pink_twintails',
            'lures_2023_flame_crown',
            'spring_2025_energy_wings',
            'spring_2025_magic_wing_badge',
            'gifthat_2023_buttoned_front',
            'spring_2025_kage_scarf',
            'spring_2025_sakura_scythe',
            'legend_hat_sept_2022_brim_beanie',
            'springfest_2023_heart_lock_necklace',
            'gold_tiara',
            'springfest_2023_dandelion_hat',
            'spin_master_2022_llama_purse_pet',
            'spring_2025_kage_cape',
            'soccer_2024_netherlands_bucket_hat',
            'legend_hat_2022_tropical_flower',
            'sun_and_moon_earrings',
            'fire_dimension_2024_fire_helmet',
            'magnifying_glass',
            'gifthat_may_2024_silly_duck_hat',
            'lesbian_pride_pin',
            'winter_2024_2025_crown',
            'hype_crown',
            'gorilla_fair_2023_emperor_accessory',
            'tutorial_2023_graduation_cap',
            'snow_2022_cosy_snow_hat',
            'snow_2022_snowflake_badge',
            'lunar_2024_rainbow_dragon_hat',
            'easter_2024_cupcake_sprinkle_wings',
            'gift_refresh_2023_music_box_hat',
            'bone_wings',
            'lny_2023_coin_necklace',
            'winter_2024_shooting_star_wings',
            'sky_ux_2023_balloon_wings',
            'gift_refresh_2023_star_barrette',
            'winter_2024_elf_shoes',
            'gifthat_may_2024_cd_stack',
            'legend_hat_2022_dueling_swords',
            'fall_2022_yarn_ball_earrings',
            'gifthat_may_2024_chest_monster',
            'gifthat_november_2024_dog_backpack',
            'legend_hat_sept_2022_jester_hat',
            'easter_2022_spring_bunny_feet',
            'gift_refresh_2023_bear_keychain',
            'capuchin_2024_inmate_cap',
            'fire_dimension_2024_volcanic_boots',
            'desert_2022_sun_wings',
            'gifthat_may_2024_springy_heart',
            'rain_2023_glowing_skull_key',
            'birthday_2022_badge',
            'legend_hat_sept_2022_leaf_hat',
            'pride_2022_intersex_pride_pin',
            'spring_2025_sakura_earrings',
            'lny_2022_gold_ingot',
            'pib_2022_feather',
            'gifthat_2023_regal_collar',
            'gorilla_fair_2023_astronaut_accessory',
            'gift_refresh_2023_combat_target_dummy',
            'blue_cat_ear_headphones',
            'ninja_headband',
            'gifthat_2023_football_helmet',
            'gifthat_november_2024_grape_earrings',
            'pib_2022_hat',
            'legend_hat_sept_2022_pink_trainer_shoes',
            'neck_ribbon',
            'lures_2023_magma_greatsword',
            'legend_hat_2022_sack_of_cash',
            'halloween_2023_slime_backpack',
            'legend_hat_sept_2022_bunny_straw_hat',
            'legend_hat_sept_2022_funky_disco_boots',
            'legend_hat_sept_2022_banana_hat',
            'legend_hat_2022_bionic_arms',
            'legend_hat_sept_2022_heart_hat',
            'halloween_2022_crescent_moon_ornament',
            'gifthat_november_2024_ice_cream_heels',
            'gifthat_2023_flower_heels',
            'legend_hat_sept_2022_bolero_hat',
            'first_aid_bag',
            'gifthat_november_2024_mystic_wing_crown',
            'playsets_2024_cherry_on_top_hat',
            'legend_hat_2022_flower_aura',
            'desert_2022_crown',
            'gifthat_2023_butter_knife',
            'sushi_skateboard',
            'gifthat_november_2024_fishbowl_hat',
            'gift_refresh_2023_sock_shoes',
            'sky_ux_2023_owl_wings',
            'smallgift',
            'gifthat_november_2024_winged_skates',
            'vehicle_shop_2022_jet_boat',
            'standard_roller_skates',
            'car',
            'raw_bone',
            'gibbon_2025_teacup_vehicle',
            'spring_2025_mecha_rabbit_sticker',
            'stickers_2024_diamond_ladybug_pet',
            'fossil_2024_dilophosaurus_pet',
            'pride_2024_gay_snake_in_a_boot_pet',
            'stickers_2024_toad_pet',
            'spring_2025_hang_glider_sticker',
            'stickers_2024_beaver_pet',
            'stickers_2024_lamb_pet',
            'ice_dimension_2025_fire_dimension_portal_sticker',
            'ocean_2024_treasure_chest_sticker',
            'stickers_2024_cow_pet',
            'ice_dimension_2025_ice_dimension_portal_sticker',
            'spring_2025_cherry_blossom_tree',
            'stickers_2024_pig_pet',
            'winter_2024_christmas_tree_sticker',
            'halloween_2024_scarecrow_sticker',
            'stickers_2024_grass_platform_environment',
            'stickers_2024_kiwi_pet',
            'spring_2025_wood_pigeon_sticker',
            'stickers_2024_diamond_bee_pet',
            'spring_2025_cabbit_sticker',
            'ocean_2024_octopus_sticker',
            'halloween_2024_zombie_wolf_sticker',
            'ice_dimension_2025_volcanic_rhino_sticker',
            'fossil_2024_sabertooth_pet',
            'ocean_2024_dracula_fish_sticker',
            'subscription_2024_goldhorn_pet',
            'stickers_2024_mouse_pet',
            'fossil_2024_tasmanian_tiger_pet',
            'halloween_2024_basilisk_sticker',
            'pride_2024_demisexual_bat_pet',
            'stickers_2024_fire_emote',
            'ocean_2024_lionfish_sticker',
            'stickers_2024_unicorn_pet',
            'summerfest_2024_show_pony_sticker',
            'fossil_2024_stegosaurus_pet',
            'pride_2024_omnisex_pegasus_pet',
            'summerfest_2024_castle_hermit_crab_sticker',
            'subscription_2024_yule_log_dog_pet',
            'winter_2024_bauble_buddies_sticker',
            'winter_2024_nutcracker_squirrel_sticker',
            'subscription_2024_owl_meme',
            'stickers_2024_tree_1_environment',
            'fossil_2024_elasmosaurus_pet',
            'fossil_2024_copper_pickaxe_misc',
            'halloween_2024_slime_sticker',
            'stickers_2024_fallow_deer_pet',
            'summerfest_2024_hot_doggo_sticker',
            'summerfest_2024_corn_doggo_sticker',
            'ocean_2024_cranky_coin_sticker',
            'halloween_2024_sea_skeleton_panda_sticker',
            'subscription_2024_ram_pet',
            'summerfest_2024_leviathan_sticker',
            'stickers_2024_ham_and_pineapple_pizza_misc',
            'stickers_2024_koala_pet',
            'subscription_2024_axolotl_pet',
            'subscription_2024_puffin_pet',
            'summerfest_2024_pirate_hermit_crab_sticker',
            'halloween_2024_marabou_stork_sticker',
            'stickers_2024_star_emote',
            'spring_2025_kage_crow_sticker',
            'summerfest_2024_punk_pony_sticker',
            'summerfest_2024_mini_pig_sticker',
            'stickers_2024_kitsune_pet',
            'winter_2024_snowman_sticker',
            'ocean_2024_urchin_sticker',
            'subscription_2024_snowball_meme',
            'pride_2024_genderqueer_seahorse_pet',
            'ice_dimension_2025_shiver_wolf_sticker',
            'fossil_2024_woolly_mammoth_pet',
            'spring_2025_super_saru_sticker',
            'ocean_2024_wishing_well_sticker',
            'winter_2024_partridge_sticker',
            'winter_2024_yeti_sticker',
            'ocean_2024_dolphin_sticker',
            'ocean_2024_white_sand_dollar_sticker',
            'pride_2024_intersex_ringed_octopus_pet',
            'stickers_2024_walrus_pet',
            'spring_2025_kappakid_sticker',
            'summerfest_2024_ice_cream_hermit_crab_sticker',
            'ocean_2024_mahi_mahi_sticker',
            'stickers_2024_donkey_pet',
            'halloween_2024_white_skeleton_dog_sticker',
            'subscription_2024_african_painted_dog_pet',
            'ice_dimension_2025_magma_moose_sticker',
            'pride_2024_lesbian_flag_misc',
            'pride_2024_happy_pride_zebra_pet',
            'subscription_2024_butterfly_pet',
            'spring_2025_scorching_kaijunior_sticker',
            'ocean_2024_shark_sticker',
            'stickers_2024_mushroom_pizza_misc',
            'ocean_2024_jellyfish_sticker',
            'stickers_2024_panda_pet',
            'pride_2024_agender_flag_misc',
            'ice_dimension_2025_magma_snail_sticker',
            'pride_2024_intersex_flag_misc',
            'stickers_2024_grey_cat_pet',
            'summerfest_2024_kid_goat_sticker',
            'spring_2025_sakura_spirit_sticker',
            'winter_2024_robin_sticker',
            'fossil_2024_trex_throw_toy',
            'stickers_2024_angry_emote',
            'stickers_2024_poodle_pet',
            'subscription_2024_pudding_cat_pet',
            'subscription_2024_cat_meme',
            'pride_2024_bi_dodo_pet',
            'fossil_2024_amber_bone',
            'stickers_2024_sloth_pet',
            'subscription_2024_chick_pet',
            'stickers_2024_elephant_pet',
            'ice_dimension_2025_campfire_cookies_bait_sticker',
            'ocean_2024_crab_sticker',
            'stickers_2024_cloud_1_environment',
            'stickers_2024_surprised_emote',
            'ocean_2024_narwhal_sticker',
            'stickers_2024_parrot_pet',
            'stickers_2024_spiral_emote',
            'summerfest_2024_leopard_shark_sticker',
            'stickers_2024_eyes_emote',
            'stickers_2024_silly_duck_pet',
            'stickers_2024_cool_emote',
            'pride_2024_transgender_flag_misc',
            'stickers_2024_plain_cheese_pizza_misc',
            'stickers_2024_red_panda_pet',
            'pride_2024_trans_glyptodon_barv_pet',
            'stickers_2024_pepperoni_pizza_misc',
            'winter_2024_tree_sasquatch_sticker',
            'stickers_2024_sasquatch_pet',
            'pride_2024_bi_flag_misc',
            'spring_2025_toxic_kaijunior_sticker',
            'fossil_2024_trex_pet',
            'stickers_2024_penguin_pet',
            'pride_2024_gender_fluid_ghost_dog_pet',
            'pride_2024_ace_flag_misc',
            'subscription_2024_hamster_meme',
            'summerfest_2024_cow_calf_sticker',
            'ocean_2024_clownfish_sticker',
            'halloween_2024_evil_unicorn_sticker',
            'stickers_2024_zzz_emote',
            'halloween_2024_frankenfeline_sticker',
            'stickers_2024_frog_pet',
            'stickers_2024_phoenix_pet',
            'stickers_2024_cloud_2_environment',
            'stickers_2024_raccoon_pet',
            'stickers_2024_tree_2_environment',
            'summerfest_2024_lobster_sticker',
            'spring_2025_cherry_blossom_flower_sticker',
            'stickers_2024_koi_fish_pet',
            'pride_2024_gender_queer_flag_misc',
            'summerfest_2024_pink_betta_fish_sticker',
            'fossil_2024_dimorphodon_pet',
            'pride_2024_lesbian_cat_snake_alliance_pet',
            'stickers_2024_100_emote',
            'halloween_2024_bat_sticker',
            'summerfest_2024_many_mackerel_sticker',
            'pride_2024_progress_pride_flag_misc',
            'stickers_2024_dog_pet',
            'halloween_2024_jousting_horse_sticker',
            'fossil_2024_diamond_pickaxe_misc',
            'pride_2024_aromatic_trex_pet',
            'summerfest_2024_happy_clam_sticker',
            'stickers_2024_sweat_emote',
            'pride_2024_enby_flag_misc',
            'stickers_2024_heart_emote',
            'summerfest_2024_orange_betta_fish_sticker',
            'ocean_2024_rare_chest_sticker',
            'spring_2025_candyfloss_chick_sticker',
            'halloween_2024_trick_or_treat_basket_sticker',
            'stickers_2024_turtle_pet',
            'ocean_2024_stringray_sticker',
            'stickers_2024_silly_rock_pet',
            'spring_2025_dotted_eggy_sticker',
            'winter_2024_aurora_fox_sticker',
            'ice_dimension_2025_subzero_scorpion_sticker',
            'stickers_2024_rat_pet',
            'ocean_2024_nautilus_sticker',
            'ice_dimension_2025_toasty_red_panda_sticker',
            'winter_2024_reindeer_sticker',
            'stickers_2024_laugh_cry_emote',
            'winter_2024_winter_doe_sticker',
            'winter_2024_shetland_pony_dark_brown_sticker',
            'stickers_2024_parakeet_pet',
            'pride_2024_gay_man_flag_misc',
            'winter_2024_santas_throne_sticker',
            'winter_2024_naughty_mistletroll_sticker',
            'winter_2024_merry_mistletroll_sticker',
            'winter_2024_fairy_bat_dragon_sticker',
            'winter_2024_gingerbread_hare_sticker',
            'ice_dimension_2025_frostbite_bear_sticker',
            'halloween_2024_slug_sticker',
            'ice_dimension_2025_christmas_pudding_pup_sticker',
            'winter_2024_ratatoskr_sticker',
            'ice_dimension_2025_wildfire_hawk_sticker',
            'stickers_2024_squid_pet',
            'pride_2024_pan_flag_misc',
            'winter_2024_santa_sticker',
            'winter_2024_peppermint_penguin_sticker',
            'stickers_2024_ocelot_pet',
            'stickers_2024_bucks_misc',
            'halloween_2024_grim_dragon_sticker',
            'subscription_2024_lavender_dragon_pet',
            'winter_2024_husky_sticker',
            'winter_2024_great_pyrenees_sticker',
            'summerfest_2024_rodeo_bull_sticker',
            'summerfest_2024_pretty_pony_sticker',
            'summerfest_2024_majestic_pony_sticker',
            'summerfest_2024_arctic_tern_sticker',
            'stickers_2024_flamingo_pet',
            'fossil_2024_trex_rattle',
            'fossil_2024_dodo_pet',
            'summerfest_2024_hermit_crab_sticker',
            'summerfest_2024_tortuga_de_la_isla_sticker',
            'stickers_2024_orange_cat_pet',
            'summerfest_2024_blue_betta_fish_sticker',
            'summerfest_2024_flying_fish_sticker',
            'stickers_2024_question_emote',
            'summerfest_2024_balloon_unicorn_sticker',
            'fossil_2024_stegosaurus_throw_toy',
            'halloween_2024_indian_flying_fox_sticker',
            'summerfest_2024_shark_puppy_sticker',
            'ice_dimension_2025_flaming_zebra_sticker',
            'spring_2025_flower_power_duckling_sticker',
            'ocean_2024_kraken_sticker',
            'stickers_2024_toucan_pet',
            'stickers_2024_blue_dog_pet',
            'stickers_2024_dragon_pet',
            'fossil_2024_ground_sloth_pet',
            'subscription_2024_chameleon_pet',
            'spring_2025_kaijunior_sticker',
            'stickers_2024_bee_pet',
            'pride_2024_non_beenary_pet',
            'subscription_2024_capricorn_pet',
            'fossil_2024_deinonychus_pet',
            'subscription_2024_starfish_pet',
            'ice_dimension_2025_burning_bunny_sticker',
            'pride_2024_omnisex_flag_misc',
            'fossil_2024_velociraptor_pet',
            'pride_2024_pan_parrot_pet',
            'spring_2025_egg_basket_sticker',
            'winter_2024_snow_globe_sticker',
            'halloween_2024_cuteacabra_sticker',
            'pride_2024_ace_goose_pet',
            'subscription_2024_gold_penguin_pet',
            'halloween_2024_ghost_sticker',
            'fossil_2024_ankylosaurus_pet',
            'ocean_2024_sea_angel_sticker',
            'fossil_2024_iron_pickaxe_misc',
            'stickers_2024_pink_cat_pet',
            'fossil_2024_brachiosaurus_pet',
            'halloween_2024_scarebear_sticker',
            'ice_dimension_2025_ash_zebra_sticker',
            'stickers_2024_space_whale_pet',
            'ice_dimension_2025_cold_tim_sticker',
            'ice_dimension_2025_chilly_penguin_sticker',
            'stickers_2024_smile_emote',
            'stickers_2024_tree_3_environment',
            'pride_2024_aromantic_flag_misc',
            'stickers_2024_ladybug_pet',
            'stickers_2024_shiba_inu_pet',
            'stickers_2024_red_fox_pet',
            'spring_2025_easter_egg_sticker',
            'halloween_2024_ghost_bunny_sticker',
            'halloween_2024_chickatrice_sticker',
            'stickers_2024_bat_dragon_pet',
            'stickers_2024_question_mark_emote',
            'pride_2024_gender_fluid_flag_misc',
            'spring_2025_bakeneko_sticker',
            'pride_2024_agender_rat_pet',
            'stickers_2024_winged_horse_pet',
            'stickers_2024_otter_pet',
            'fossil_2024_glyptodon_pet',
            'stickers_2024_zebra_pet',
            'ice_dimension_2025_icy_porcupine_sticker',
            'stickers_2024_rose_environment',
            'stickers_2024_exclamation_emote',
            'subscription_2024_pelican_pet',
            'ice_dimension_2025_flaming_fox_sticker',
            'stickers_2024_dalmation_pet',
            'stickers_2024_seahorse_pet',
            'stickers_2024_confetti_emote',
            'ice_dimension_2025_snowy_mammoth_sticker',
            'fossil_2024_triceratops_pet',
            'spring_2025_mirai_moth_sticker',
            'fossil_2024_pterodactyl_pet',
            'subscription_2024_red_panda_meme',
            'spring_2025_primal_kaijunior_sticker',
            'pride_2024_demi_flag_misc',
            'fossil_2024_long_neck_throw_toy',
        }
    end
    function __DARKLUA_BUNDLE_MODULES.e()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local RouterClient = Bypass('RouterClient')
        local InventoryDB = Bypass('InventoryDB')
        local AllowOrDenyList = __DARKLUA_BUNDLE_MODULES.load('c')
        local TrashItemsList = __DARKLUA_BUNDLE_MODULES.load('d')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('a')
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
            local timeOut = math.random(10, 20)

            while not ClientData.get_data()[localPlayer.Name].in_active_trade do
                task.wait(1)

                timeOut = timeOut - 1

                if timeOut <= 0 then
                    return false
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

                if waitForActiveTrade() then
                    return true
                end

                task.wait()
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
        function self.NormalFullgrownOnly()
            if not waitForActiveTrade() then
                return
            end

            local waitForAdded = 0

            for _, pet in ClientData.get_data()[localPlayer.Name].inventory.pets do
                if table.find(AllowOrDenyList.Denylist, pet.id) then
                    continue
                end
                if getgenv().SETTINGS.ENABLE_RELEASE_PETS == true and table.find(getgenv().SETTINGS.PETS_TO_AGE_IN_PEN, pet.id) then
                    continue
                end
                if pet.properties.age == 6 and not (pet.properties.neon or pet.properties.mega_neon) then
                    if not ClientData.get_data()[localPlayer.Name].in_active_trade then
                        return
                    end
                    if #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= 18 then
                        return
                    end

                    RouterClient.get('TradeAPI/AddItemToOffer'):FireServer(pet.unique)

                    waitForAdded = waitForAdded + 1

                    repeat
                        task.wait(0.1)
                    until #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= waitForAdded or not ClientData.get_data()[localPlayer.Name].in_active_trade
                end
            end
        end
        function self.NormalNewbornToPostteen()
            if not waitForActiveTrade() then
                return
            end

            local waitForAdded = 0

            for _, pet in ClientData.get_data()[localPlayer.Name].inventory.pets do
                if table.find(AllowOrDenyList.Denylist, pet.id) then
                    continue
                end
                if getgenv().SETTINGS.ENABLE_RELEASE_PETS == true and table.find(getgenv().SETTINGS.PETS_TO_AGE_IN_PEN, pet.id) then
                    continue
                end
                if pet.properties.age <= 5 and not (pet.properties.neon or pet.properties.mega_neon) then
                    if not ClientData.get_data()[localPlayer.Name].in_active_trade then
                        return
                    end
                    if #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= 18 then
                        return
                    end

                    RouterClient.get('TradeAPI/AddItemToOffer'):FireServer(pet.unique)

                    waitForAdded = waitForAdded + 1

                    repeat
                        task.wait(0.1)
                    until #ClientData.get_data()[localPlayer.Name].trade.sender_offer.items >= waitForAdded or not ClientData.get_data()[localPlayer.Name].in_active_trade

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
            if getgenv().SETTINGS.TRADE_ONLY_NEON_LUMINOUS_AND_MEGA then
                for _, v in ClientData.get_data()[localPlayer.Name].inventory do
                    for _, item in v do
                        if getgenv().SETTINGS.ENABLE_RELEASE_PETS == true and table.find(getgenv().SETTINGS.PETS_TO_AGE_IN_PEN, item.id) then
                            continue
                        end
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
                        if getgenv().SETTINGS.ENABLE_RELEASE_PETS == true and table.find(getgenv().SETTINGS.PETS_TO_AGE_IN_PEN, item.id) then
                            continue
                        end
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
                if getgenv().SETTINGS.TRADE_ONLY_NEON_LUMINOUS_AND_MEGA then
                    for _, v in ClientData.get_data()[localPlayer.Name].inventory do
                        if isInventoryFull then
                            break
                        end

                        for _, item in v do
                            if table.find(getgenv().SETTINGS.TRADE_LIST, item.id) or (item.properties.neon and item.properties.age == 6) or item.properties.mega_neon then
                                if getgenv().SETTINGS.ENABLE_RELEASE_PETS == true and table.find(getgenv().SETTINGS.PETS_TO_AGE_IN_PEN, item.id) then
                                    continue
                                end
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
                                if getgenv().SETTINGS.ENABLE_RELEASE_PETS == true and table.find(getgenv().SETTINGS.PETS_TO_AGE_IN_PEN, item.id) then
                                    continue
                                end
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
        local Utils = __DARKLUA_BUNDLE_MODULES.load('a')
        local Teleport = {}
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

            print(string.format('Current identity: %s', tostring(k)))
            set_thread_identity(2)
            SetLocationTP(a, b, c)
            set_thread_identity(k)
        end

        function Teleport.Init() end
        function Teleport.PlaceFloorAtFarmingHome()
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
            TextLabel.Text = ''
            TextLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
            TextLabel.TextScaled = true
            TextLabel.TextSize = 14
            TextLabel.TextWrapped = true
        end
        function Teleport.PlaceCameraPart()
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
        function Teleport.PlaceFloorAtCampSite()
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
        function Teleport.PlaceFloorAtBeachParty()
            if Workspace:FindFirstChild('BeachPartyLocation') then
                return
            end

            local part = Instance.new('Part')

            part.Position = Workspace.StaticMap.Beach.BeachPartyAilmentTarget.Position + Vector3.new(0, 
-12, 0)
            part.Size = Vector3.new(1000, 2, 1000)
            part.Anchored = true
            part.Transparency = 0
            part.Name = 'BeachPartyLocation'
            part.Parent = Workspace
        end
        function Teleport.DeleteWater()
            Workspace.Terrain:Clear()
        end
        function Teleport.FarmingHome()
            Utils.GetCharacter():WaitForChild('HumanoidRootPart').Anchored = true

            Utils.GetCharacter():MoveTo(Workspace.FarmingHomeLocation.Position + Vector3.new(0, 5, 0))

            Utils.GetCharacter():WaitForChild('HumanoidRootPart').Anchored = false

            Utils.GetCharacter().Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
            Teleport.DeleteWater()
        end
        function Teleport.MainMap()
            local isAlreadyOnMainMap = Workspace:FindFirstChild('Interiors'):FindFirstChild('center_map_plot', true)

            if isAlreadyOnMainMap then
                return
            end

            CollisionsClient.set_collidable(false)

            Utils.GetHumanoidRootPart().Anchored = true

            SetLocationFunc('MainMap', 'Neighborhood/MainDoor', {})
            Workspace.Interiors:WaitForChild(tostring(Workspace.Interiors:FindFirstChildWhichIsA('Model')))

            localPlayer.Character.PrimaryPart.CFrame = Workspace:WaitForChild('StaticMap'):WaitForChild('Campsite'):WaitForChild('CampsiteOrigin').CFrame + Vector3.new(math.random(1, 5), 10, math.random(1, 5))
            Utils.GetHumanoidRootPart().Anchored = false

            Utils.GetHumanoid():ChangeState(Enum.HumanoidStateType.Landed)
            Teleport.DeleteWater()
            task.wait(2)
        end
        function Teleport.CampSite()
            ReplicatedStorage.API['LocationAPI/SetLocation']:FireServer('MainMap', localPlayer, ClientData.get_data()[localPlayer.Name].LiveOpsMapType)
            task.wait(1)

            localPlayer.Character.PrimaryPart.CFrame = Workspace.CampingLocation.CFrame + Vector3.new(rng:NextInteger(1, 30), 5, rng:NextInteger(1, 30))
            Utils.GetHumanoidRootPart().Anchored = false

            Utils.GetHumanoid():ChangeState(Enum.HumanoidStateType.Landed)
            Teleport.DeleteWater()
        end
        function Teleport.BeachParty()
            ReplicatedStorage.API['LocationAPI/SetLocation']:FireServer('MainMap', localPlayer, ClientData.get_data()[localPlayer.Name].LiveOpsMapType)
            task.wait(1)

            localPlayer.Character.PrimaryPart.CFrame = Workspace.BeachPartyLocation.CFrame + Vector3.new(math.random(1, 30), 5, math.random(1, 30))
            Utils.GetHumanoidRootPart().Anchored = false

            Utils.GetHumanoid():ChangeState(Enum.HumanoidStateType.Landed)
            Teleport.DeleteWater()
        end
        function Teleport.GingerbreadCollectionCircle()
            ReplicatedStorage.API['LocationAPI/SetLocation']:FireServer('MainMap', localPlayer, ClientData.get_data()[localPlayer.Name].LiveOpsMapType)
            task.wait(1)

            local iceSkatingPart = workspace.StaticMap.TeleportLocations:FindFirstChild('ice_skating')

            if not iceSkatingPart then
                return
            end

            Utils.GetHumanoidRootPart().Anchored = true

            localPlayer.Character:MoveTo(iceSkatingPart.Position)

            Utils.GetHumanoidRootPart().Anchored = false

            Utils.GetHumanoid():ChangeState(Enum.HumanoidStateType.Landed)
            Teleport.DeleteWater()
        end
        function Teleport.SpinningDome()
            ReplicatedStorage.API['LocationAPI/SetLocation']:FireServer('MainMap', localPlayer, ClientData.get_data()[localPlayer.Name].LiveOpsMapType)
            task.wait(1)

            local discoPart = workspace.StaticMap:FindFirstChild('DiscoOrigin')

            if not discoPart then
                return
            end

            Utils.GetCharacter():MoveTo(discoPart.Position)

            Utils.GetHumanoidRootPart().Anchored = false

            Utils.GetHumanoid():ChangeState(Enum.HumanoidStateType.Landed)
            Teleport.DeleteWater()
        end

        return Teleport
    end
    function __DARKLUA_BUNDLE_MODULES.g()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local RouterClient = Bypass('RouterClient')
        local InventoryDB = Bypass('InventoryDB')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('a')
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
        local AllowOrDenyList = __DARKLUA_BUNDLE_MODULES.load('c')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('a')
        local GetInventory = {}
        local PetsToReleaseList = getgenv().SETTINGS.PETS_TO_AGE_IN_PEN or {}
        local localPlayer = Players.LocalPlayer
        local eggList = {}
        local equipWhichPet = function(whichPet, petUnique)
            if whichPet == 1 then
                RouterClient.get('ToolAPI/Equip'):InvokeServer(petUnique, {
                    ['equip_as_last'] = false,
                })

                getgenv().petCurrentlyFarming1 = petUnique

                Utils.WaitForPetToEquip()

                return true
            elseif whichPet == 2 then
                RouterClient.get('ToolAPI/Equip'):InvokeServer(petUnique, {
                    ['equip_as_last'] = true,
                })

                getgenv().petCurrentlyFarming2 = petUnique

                Utils.WaitForPetToEquip()

                return true
            end

            return false
        end
        local petPenFilter = function(petId, isNeon)
            local petUniques = {}

            for petAge = 5, 1, -1 do
                for _, pet in ClientData.get_data()[localPlayer.Name].inventory.pets do
                    if petId ~= pet.id then
                        continue
                    end
                    if table.find(AllowOrDenyList.Denylist, pet.id) then
                        continue
                    end
                    if pet.properties.age == petAge and pet.properties.neon == isNeon then
                        if pet.unique == getgenv().petCurrentlyFarming1 then
                            continue
                        end
                        if pet.unique == getgenv().petCurrentlyFarming2 then
                            continue
                        end

                        table.insert(petUniques, pet.unique)
                    end
                end
            end

            return petUniques
        end

        function GetInventory.GetPetUniquesForPetPen(petIdList, MaxAmount)
            local petUniques = {}

            for _, petId in ipairs(petIdList)do
                local result1 = petPenFilter(petId, true)

                for _, unique in ipairs(result1)do
                    table.insert(petUniques, unique)

                    if #petUniques >= MaxAmount then
                        break
                    end
                end

                local result2 = petPenFilter(petId, nil)

                for _, unique in ipairs(result2)do
                    table.insert(petUniques, unique)

                    if #petUniques >= MaxAmount then
                        break
                    end
                end
            end

            return petUniques
        end
        function GetInventory.GetPetsRarityAndAgeForPen(rarity)
            local PetageCounter = 5
            local isNeon = true
            local petFound = false
            local petUniques = {}

            while not petFound do
                for _, pet in ClientData.get_data()[localPlayer.Name].inventory.pets do
                    for _, petDB in InventoryDB.pets do
                        if table.find(AllowOrDenyList.Denylist, pet.id) then
                            continue
                        end
                        if table.find(eggList, pet.id) then
                            continue
                        end
                        if rarity == petDB.rarity and pet.id == petDB.id and pet.properties.age == PetageCounter and pet.properties.neon == isNeon then
                            if pet.unique == getgenv().petCurrentlyFarming1 then
                                continue
                            end
                            if pet.unique == getgenv().petCurrentlyFarming2 then
                                continue
                            end

                            table.insert(petUniques, pet.unique)

                            if #petUniques >= 4 then
                                return petUniques
                            end
                        end
                    end
                end

                PetageCounter = PetageCounter - 1

                if PetageCounter <= 0 and isNeon then
                    PetageCounter = 5
                    isNeon = nil
                elseif PetageCounter <= 0 and isNeon == nil then
                    return petUniques
                end

                task.wait(1)
            end

            return petUniques
        end
        function GetInventory.GetPetsToRelease()
            local petUniques = {}

            for _, pet in ClientData.get_data()[localPlayer.Name].inventory.pets do
                if not table.find(PetsToReleaseList, pet.id) then
                    continue
                end
                if pet.properties.mega_neon then
                    petUniques[pet.unique] = true
                end
            end

            return petUniques
        end
        function GetInventory.GetAgeablePets()
            local ageablePets = {}
            local eggList2 = GetInventory.GetPetEggs()

            for _, pet in ClientData.get_data()[localPlayer.Name].inventory.pets do
                if table.find(AllowOrDenyList.Denylist, pet.id) then
                    continue
                end
                if table.find(eggList2, pet.id) then
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
        function GetInventory.GetAll()
            return ClientData.get_data()[localPlayer.Name].inventory
        end
        function GetInventory.TabId(tabId)
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
        function GetInventory.IsFarmingSelectedPet(hasProHandler)
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
        function GetInventory.GetPetFriendship(petTable, whichPet)
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
        function GetInventory.GetHighestGrownPet(age, whichPet)
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
        function GetInventory.GetHighestGrownPetForIdle(age)
            local PetageCounter = age
            local isNeon = true
            local petFound = false
            local petUniques = {}

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

                        table.insert(petUniques, pet.unique)

                        if #petUniques >= 4 then
                            return petUniques
                        end
                    end
                end

                PetageCounter = PetageCounter - 1

                if PetageCounter <= 0 and isNeon then
                    PetageCounter = age
                    isNeon = nil
                elseif PetageCounter <= 0 and isNeon == nil then
                    return petUniques
                end

                task.wait()
            end

            return petUniques
        end
        function GetInventory.GetPetRarity()
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
        function GetInventory.PetRarityAndAge(rarity, age, whichPet)
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
        function GetInventory.CheckForPetAndEquip(nameIds, whichPet)
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
        function GetInventory.GetUniqueId(tabId, nameId)
            for _, v in ClientData.get_data()[localPlayer.Name].inventory[tabId]do
                if v.id == nameId then
                    return v.unique
                end
            end

            return nil
        end
        function GetInventory.IsPetInInventory(tabId, uniqueId)
            for _, v in ClientData.get_data()[localPlayer.Name].inventory[tabId]do
                if v.unique == uniqueId then
                    return true
                end
            end

            return false
        end
        function GetInventory.PriorityEgg(whichPet)
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
        function GetInventory.GetPetEggs()
            if #eggList >= 1 then
                return eggList
            end

            for _, v in InventoryDB.pets do
                if v.is_egg then
                    table.insert(eggList, v.id)
                end
            end

            return eggList
        end
        function GetInventory.GetNeonPet(whichPet)
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
        function GetInventory.PriorityPet(whichPet)
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

        return GetInventory
    end
    function __DARKLUA_BUNDLE_MODULES.j()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local PetPotionEffectsDB = (require(ReplicatedStorage:WaitForChild('ClientDB'):WaitForChild('PetPotionEffectsDB')))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local RouterClient = Bypass('RouterClient')
        local Fusion = __DARKLUA_BUNDLE_MODULES.load('h')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('a')
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
        local ReplicatedStorage = game:GetService('ReplicatedStorage')
        local VirtualUser = game:GetService('VirtualUser')
        local Players = game:GetService('Players')
        local StarterGui = game:GetService('StarterGui')
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local RouterClient = Bypass('RouterClient')
        local ClientData = Bypass('ClientData')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('a')
        local Furniture = __DARKLUA_BUNDLE_MODULES.load('b')
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
                if player.Name == localPlayer.Name then
                    continue
                end
                if table.find(playerList, player.Name) then
                    return true
                end
            end

            return false
        end
        local buyFurnitureIfMissing = function()
            local updateWithNewKey = false

            for key, value in Furniture.items do
                if Furniture.items[key] == 'nil' then
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
            RouterClient.get('SettingsAPI/SetBooleanFlag'):FireServer('arachnophobia_mode_seen', true)
            task.wait()
            RouterClient.get('SettingsAPI/SetSetting'):FireServer('arachnophobia_mode', false)
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
                    if not getgenv().FARMSYNC then
                        return
                    end
                    if not getgenv().FARMSYNC.ENABLED then
                        return
                    end

                    Utils.SetConfigFarming(getgenv().FARMSYNC.FARMING_CONFIG_ID)
                end)
            end)

            local queueOnTeleport = (syn and syn.queue_on_teleport) or queue_on_teleport

            if queueOnTeleport then
                queueOnTeleport(
[[            localPlayer:Kick("IS IN PUBLIC SERVER");
            game:Shutdown()
        ]])
            end
        end
        function self.Start()
            print('Preparing account for farming...')
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
            RouterClient.get('HousingAPI/SetDoorLocked'):InvokeServer(true)
            Utils.WaitForHumanoidRootPart()
            RouterClient.get('TeamAPI/ChooseTeam'):InvokeServer('Babies', {
                ['dont_respawn'] = false,
            })
            task.wait(1)
            Utils.WaitForHumanoidRootPart()

            local count = 0

            while true do
                RouterClient.get('HousingAPI/SubscribeToHouse'):FireServer(Players.LocalPlayer)
                task.wait(1)

                if ClientData.get_data()[localPlayer.Name].house_interior.house_id then
                    break
                end

                count = count + 1

                if count >= 30 then
                    Utils.PrintDebug(
[[Failed to subscribe to house after 30 seconds, trying again...]])

                    break
                end
            end

            Furniture.GetFurnituresKey()
            buyFurnitureIfMissing()
            Utils.PrintDebug(string.format('Bed: %s \u{1f6cf}\u{fe0f}', tostring(Furniture.items.basiccrib)))
            Utils.PrintDebug(string.format('Shower: %s \u{1f6c1}', tostring(Furniture.items.stylishshower)))
            Utils.PrintDebug(string.format('Piano: %s \u{1f3b9}', tostring(Furniture.items.piano)))
            Utils.PrintDebug(string.format('Normal Lure: %s \u{1f4e6}', tostring(Furniture.items.lures_2023_normal_lure)))
            Utils.PrintDebug(string.format('LitterBox: %s \u{1f6bd}', tostring(Furniture.items.ailments_refresh_2024_litter_box)))

            local baitUnique = Utils.FindBait()

            Utils.PrintDebug(string.format('baitUnique: %s \u{1f36a}', tostring(baitUnique)))
            Utils.PlaceBaitOrPickUp(Furniture.items.lures_2023_normal_lure, baitUnique)
            task.wait(1)
            Utils.PlaceBaitOrPickUp(Furniture.items.lures_2023_normal_lure, baitUnique)
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

            if getgenv().BUY_BEFORE_FARMING then
                localPlayer:SetAttribute('StopFarmingTemp', true)
                localPlayer:SetAttribute('AgingPets', true)
                BuyItem.StartBuyItems(getgenv().BUY_BEFORE_FARMING)
            end
            if getgenv().OPEN_ITEMS_BEFORE_FARMING then
                localPlayer:SetAttribute('StopFarmingTemp', true)
                localPlayer:SetAttribute('AgingPets', true)
                BuyItem.OpenItems(getgenv().OPEN_ITEMS_BEFORE_FARMING)
            end
            if getgenv().AGE_PETS_BEFORE_FARMING then
                localPlayer:SetAttribute('StopFarmingTemp', true)
                localPlayer:SetAttribute('AgingPets', true)
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

                if not getgenv().FARMSYNC then
                    return
                end
                if not getgenv().FARMSYNC.ENABLED then
                    return
                end

                Utils.SetConfigFarming(getgenv().FARMSYNC.FARMING_CONFIG_ID)
            end

            Utils.PlaceFLoorUnderPlayer()
            Teleport.FarmingHome()
            localPlayer:SetAttribute('StopFarmingTemp', false)
            localPlayer:SetAttribute('AgingPets', false)
        end

        return self
    end
    function __DARKLUA_BUNDLE_MODULES.l()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local RouterClient = Bypass('RouterClient')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('a')
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
        local TextChatService = game:GetService('TextChatService')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('a')
        local Trade = __DARKLUA_BUNDLE_MODULES.load('e')
        local Teleport = __DARKLUA_BUNDLE_MODULES.load('f')
        local self = {}
        local localPlayer = Players.LocalPlayer
        local PlayerGui = localPlayer:WaitForChild('PlayerGui')
        local DialogApp = (PlayerGui:WaitForChild('DialogApp'))
        local MinigameRewardsApp = (PlayerGui:WaitForChild('MinigameRewardsApp'))
        local MinigameInGameApp = (PlayerGui:WaitForChild('MinigameInGameApp'))
        local TradeApp = (PlayerGui:WaitForChild('TradeApp'))
        local PlaytimePayoutsApp = (PlayerGui:WaitForChild('PlaytimePayoutsApp'))
        local certificateConn
        local starterPackAppConn
        local patterns = {
            ["You haven't collected the Gingerbread"] = 'No',
            ['Be careful when trading'] = 'Okay',
            ['This trade seems unbalanced'] = 'Next',
            ['Social Stones!'] = 'Okay',
            ['sent you a trade request'] = 'Accept',
            ['Trade request from'] = 'Okay',
            ['Any items lost'] = 'I understand',
            ['4.5%% Legendary'] = 'Okay',
            ['You have been awarded'] = 'Awesome!',
            ['Thanks for subscribing!'] = 'Okay',
            ["Let's start the day"] = 'Start',
            ['Are you subscribed'] = 'Yes',
            ['your inventory!'] = 'Awesome!',
            ["You've chosen this"] = 'Yes',
            ['You can change this option'] = 'Okay',
            ['You have enough'] = 'Okay',
            ['Thanks for'] = 'Okay',
            ['Right now'] = 'Next',
            ['You can customize it'] = 'Start',
            ['Your subscription'] = 'Okay!',
            ['You have been refunded'] = 'Awesome!',
            ["You can't afford this"] = 'Okay',
            ['mailbox'] = 'Okay',
            ['Pay 1500 Bucks'] = 'Yes',
            ['Pet Pen!'] = 'Go to Pet Pen',
            ['The Homepass has been restarted'] = 'Okay',
            ['Costume Party starts'] = 'Okay',
            ['Step away from'] = 'Okay',
            ['spawn a vehicle'] = 'Okay',
            ['Welcome to Adopt Me!'] = 'Next',
        }
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

            for pattern, button in patterns do
                if TextLabel.Text:match(pattern) then
                    Utils.FindButton(button)

                    return
                end
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
        local tryClickPlaytimePayout = function()
            if not PlaytimePayoutsApp.Enabled then
                return
            end
            if not PlaytimePayoutsApp:WaitForChild('Frame', 10) then
                return
            end
            if not PlaytimePayoutsApp.Frame:WaitForChild('Container', 10) then
                return
            end
            if not PlaytimePayoutsApp.Frame.Container:WaitForChild('CashOutContainer', 10) then
                return
            end
            if not PlaytimePayoutsApp.Frame.Container.CashOutContainer:WaitForChild('CashOutButton', 10) then
                return
            end

            local button = (PlaytimePayoutsApp.Frame.Container.CashOutContainer.CashOutButton:WaitForChild('DepthButton', 10))

            Utils.FireButton(button)
            task.wait(1)
            Utils.PrintDebug('\u{1f911} Cashed out playtime rewards')
        end

        function self.Init()
            TextChatService.MessageReceived:Connect(function(message)
                if not (message.TextSource and message.TextSource.UserId) then
                    print('ignoring message with no text source')

                    return
                end
                if message.TextSource.UserId == localPlayer.UserId then
                    print(string.format('ignoring own message: %s', tostring(message.Text)))

                    return
                end
                if message.Text:match('Server') then
                    return
                end

                print(string.format('got message from %s: %s', tostring(message.TextSource.Name), tostring(message.Text)))
                localPlayer:Kick('IS IN PUBLIC SERVER')
                game:Shutdown()
            end)

            local Dialog = (DialogApp:WaitForChild('Dialog'))

            Dialog:WaitForChild('ExitButton'):GetPropertyChangedSignal('Visible'):Connect(function(
            )
                if not Dialog.ExitButton.Visible then
                    return
                end

                Utils.FireButton(Dialog.ExitButton)
            end)
            Dialog:WaitForChild('ItemPreviewDialog'):GetPropertyChangedSignal('Visible'):Connect(function(
            )
                if not Dialog.ItemPreviewDialog.Visible then
                    return
                end

                task.wait(5)
                localPlayer:Kick('GOT NEW PET. SO RESTART GAME')
                game:Shutdown()
            end)
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
                    if not normalDialog:WaitForChild('Info', 10) then
                        return
                    end
                    if not normalDialog.Info:WaitForChild('TextLabel', 10) then
                        return
                    end

                    normalDialog.Info.TextLabel:GetPropertyChangedSignal('Text'):Connect(onTextChangedNormalDialog)
                end
            end)
            Dialog.ChildAdded:Connect(function(Child)
                if Child.Name == 'NormalDialog' then
                    Child:GetPropertyChangedSignal('Visible'):Connect(function()
                        local myChild = Child

                        if not myChild.Visible then
                            return
                        end
                        if not myChild:WaitForChild('Info', 10) then
                            return
                        end
                        if not myChild.Info:WaitForChild('TextLabel', 10) then
                            return
                        end

                        myChild.Info.TextLabel:GetPropertyChangedSignal('Text'):Connect(onTextChangedNormalDialog)
                    end)
                elseif Child.Name == 'ItemPreviewDialog' then
                    Child:GetPropertyChangedSignal('Visible'):Connect(function()
                        local myChild = Child

                        if not myChild.Visible then
                            return
                        end

                        task.wait(2)
                        localPlayer:Kick()
                        game:Shutdown()
                    end)
                end
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
                if not DialogApp.Dialog.NormalDialog:WaitForChild('Info', 10) then
                    return
                end
                if not DialogApp.Dialog.NormalDialog.Info:WaitForChild('TextLabel', 10) then
                    return
                end

                DialogApp.Dialog.NormalDialog.Info.TextLabel:GetPropertyChangedSignal('Text'):Connect(function(
                )
                    local text = DialogApp.Dialog.NormalDialog.Info.TextLabel.Text

                    if text:match('is starting soon!') then
                        Utils.FindButton('No')
                    elseif DialogApp.Dialog.NormalDialog.Info.TextLabel.Text:match('invitation') then
                        localPlayer:Kick('IS IN PUBLIC SERVER')
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
                    if not NormalDialogChild:WaitForChild('Info', 10) then
                        return
                    end
                    if not NormalDialogChild.Info:WaitForChild('TextLabel', 10) then
                        return
                    end

                    NormalDialogChild.Info.TextLabel:GetPropertyChangedSignal('Text'):Connect(function(
                    )
                        local text = NormalDialogChild.Info.TextLabel.Text

                        if text:match('is starting soon!') then
                            Utils.FindButton('No')
                        elseif NormalDialogChild.Info.TextLabel.Text:match('invitation') then
                            localPlayer:Kick('IS IN PUBLIC SERVER')
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
                    if not MinigameInGameApp:WaitForChild('Body', 10) then
                        return
                    end
                    if not MinigameInGameApp.Body:WaitForChild('Middle', 10) then
                        return
                    end
                    if not MinigameInGameApp.Body.Middle:WaitForChild('Container', 10) then
                        return
                    end
                    if not MinigameInGameApp.Body.Middle.Container:WaitForChild('TitleLabel', 10) then
                        return
                    end

                    local text = MinigameInGameApp.Body.Middle.Container.TitleLabel.Text

                    if text:match('TREASURE DEFENSE') or text:match('CANNON CIRCLE') then
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
                    if not MinigameRewardsApp.Body:WaitForChild('Button', 10) then
                        return
                    end
                    if not MinigameRewardsApp.Body.Button:WaitForChild('Face', 10) then
                        return
                    end
                    if not MinigameRewardsApp.Body.Button.Face:WaitForChild('TextLabel', 10) then
                        return
                    end
                    if not MinigameRewardsApp.Body:WaitForChild('Reward', 10) then
                        return
                    end
                    if not MinigameRewardsApp.Body.Reward:WaitForChild('TitleLabel', 10) then
                        return
                    end
                    if MinigameRewardsApp.Body.Button.Face.TextLabel.Text:match('NICE!') then
                        Utils.WaitForHumanoidRootPart().Anchored = true

                        task.wait(2)
                        removeGameOverButton('MinigameRewardsApp')
                        Utils.GetCharacter()
                        task.wait(6)
                        Teleport.FarmingHome()

                        Utils.WaitForHumanoidRootPart().Anchored = false

                        localPlayer:SetAttribute('StopFarmingTemp', false)
                    end
                end
            end)
            PlaytimePayoutsApp:GetPropertyChangedSignal('Enabled'):Connect(function(
            )
                tryClickPlaytimePayout()
            end)
            TradeApp.Frame.NegotiationFrame.Body.PartnerOffer.Accepted:GetPropertyChangedSignal('ImageTransparency'):Connect(function(
            )
                Trade.AutoAcceptTrade()
            end)
            TradeApp.Frame.ConfirmationFrame.PartnerOffer.Accepted:GetPropertyChangedSignal('ImageTransparency'):Connect(function(
            )
                Trade.AutoAcceptTrade()
            end)
        end
        function self.Start()
            tryClickPlaytimePayout()
        end

        return self
    end
    function __DARKLUA_BUNDLE_MODULES.n()
        local ReplicatedStorage = game:GetService('ReplicatedStorage')
        local Players = game:GetService('Players')
        local Workspace = (cloneref(game:GetService('Workspace')))
        local Terrain = (Workspace:WaitForChild('Terrain'))
        local Lighting = (cloneref(game:GetService('Lighting')))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local self = {}
        local localPlayer = Players.LocalPlayer
        local liveOpsMapType = ClientData.get_data()[localPlayer.Name].LiveOpsMapType
        local namesToRemove = {
            string.format('MainMap!%s', tostring(liveOpsMapType)),
            string.format('Neighborhood!%s', tostring(liveOpsMapType)),
        }
        local TURN_ON = getgenv().SETTINGS.POTATO_MODE or false
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

        function self.Init() end
        function self.Start()
            if not TURN_ON then
                return
            end

            lowSpecTerrain()
            lowSpecLighting()
            Lighting:ClearAllChildren()
            Terrain:Clear()

            for _, v in Workspace:WaitForChild('Interiors'):GetChildren()do
                if v:IsA('Model') then
                    v:Destroy()
                end
            end

            Workspace:WaitForChild('Interiors').ChildAdded:Connect(function(v)
                if v:IsA('Model') and table.find(namesToRemove, v.Name) then
                    v:Destroy()
                end
            end)
        end

        return self
    end
    function __DARKLUA_BUNDLE_MODULES.o()
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
    function __DARKLUA_BUNDLE_MODULES.p()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local HttpService = cloneref(game:GetService('HttpService'))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local AllowOrDenyList = __DARKLUA_BUNDLE_MODULES.load('c')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('a')
        local self = {}
        local localPlayer = Players.LocalPlayer
        local getThumbnailImage = function(rbxassetidLink)
            local assetid = rbxassetidLink:match('rbxassetid://(%d+)')

            if not assetid then
                return nil
            end

            local url = string.format(
[[https://thumbnails.roblox.com/v1/assets?assetIds=%s&size=420x420&format=png&isCircular=false]], tostring(assetid))
            local request = request or syn.request
            local headers = {
                ['Content-Type'] = 'application/json',
            }
            local requestOptions = {
                Url = url,
                Method = 'GET',
                Headers = headers,
            }
            local success, result = pcall(function()
                return request(requestOptions).Body
            end)

            if success then
                local data = HttpService:JSONDecode(result)

                if data and data.data and data.data[1] and data.data[1].imageUrl then
                    return data.data[1].imageUrl
                end
            end

            return nil
        end
        local getItemFromDatabase = function(nameId)
            return Bypass('InventoryDB').pets[nameId] or nil
        end
        local getPetNeonOrMega = function(itemData)
            local info = {}

            if itemData.properties.neon then
                info = {
                    ['Name'] = 'Neon',
                    ['Value'] = 'Yes',
                }
            elseif itemData.properties.mega_neon then
                info = {
                    ['Name'] = 'Mega',
                    ['Value'] = 'Yes',
                }
            else
                info = {
                    ['Name'] = 'Normal',
                    ['Value'] = 'Yes',
                }
            end

            return info
        end
        local filterData = function(data)
            local itemDatabase = getItemFromDatabase(data['id'])

            if not itemDatabase then
                return false
            end
            if not itemDatabase.image then
                return false
            end

            self.SendWebHook(data, itemDatabase)

            return true
        end
        local startWebHook = function()
            Utils.PrintDebug('Webhook Started')

            local DataPartiallyChanged = Bypass('RouterClient').get_event('DataAPI/DataPartiallyChanged')

            self.Connection = DataPartiallyChanged.OnClientEvent:Connect(function(
                playerName,
                _,
                dataInfo,
                _
            )
                if playerName ~= localPlayer.Name then
                    return
                end
                if typeof(dataInfo) ~= 'table' then
                    return
                end
                if not dataInfo.category or dataInfo.category ~= 'pets' then
                    return
                end
                if dataInfo.newness_order and dataInfo.newness_order <= 0 then
                    return
                end
                if table.find(AllowOrDenyList.Denylist, dataInfo.id) then
                    return
                end
                if not dataInfo.properties then
                    return
                end
                if not table.find(AllowOrDenyList.Allowlist, dataInfo.id) then
                    return
                end
                if self.UniqueString == dataInfo.unique then
                    return
                end

                self.UniqueString = dataInfo.unique

                filterData(dataInfo)

                if not getgenv().FARMSYNC then
                    return
                end
                if not getgenv().FARMSYNC.ENABLED then
                    return
                end
                if getgenv().client and getgenv().client:ChangeConfig(getgenv().FARMSYNC.TRADING_CONFIG_ID) then
                    if table.find(getgenv().SETTINGS.TRADE_COLLECTOR_NAME, localPlayer.Name) then
                        print('Skipping change config because its the trade collector')

                        return
                    end

                    task.wait(math.random(1, 5))
                    getgenv().client:Disconnect()
                    localPlayer:Kick('')
                    game:Shutdown()
                end
            end)
        end

        function self.Init()
            self.Connection = nil
            self.Cooldown = false
            self.UniqueString = ''
        end
        function self.Start()
            if getgenv().WEBHOOK and getgenv().WEBHOOK.URL and #getgenv().WEBHOOK.URL >= 10 then
                startWebHook()
            end
        end
        function self.SendWebHook(itemData, itemDataDB)
            local imageUrl = getThumbnailImage(itemDataDB['image'])
            local petStats = getPetNeonOrMega(itemData)
            local embed = {
                title = 'NEW PET DETECTED!',
                description = string.format('[%s] %s got it', tostring(getgenv().WEBHOOK.VPS_NAME or 'None'), tostring(localPlayer.Name)),
                color = 0xccff,
                fields = {
                    {
                        name = 'Pet Name',
                        value = itemDataDB.name,
                        inline = true,
                    },
                    {
                        name = 'Rarity',
                        value = itemDataDB.rarity,
                        inline = true,
                    },
                    {
                        name = 'Age',
                        value = itemData.properties.age,
                        inline = true,
                    },
                    {
                        name = tostring(petStats.Name),
                        value = petStats.Value,
                        inline = true,
                    },
                },
                footer = {
                    text = string.format('\nShittyHub - %s', tostring(DateTime.now():FormatLocalTime('LLL', 'en-us'))),
                },
            }

            if imageUrl then
                embed.thumbnail = {url = imageUrl}
            end

            local dataFrame = {
                username = 'Pet Notifier',
                avatar_url = string.format(
[[https://www.roblox.com/headshot-thumbnail/image?userId=%s&width=420&height=420&format=png]], tostring(localPlayer.UserId)),
                embeds = {embed},
            }
            local request = request or syn.request
            local headers = {
                ['Content-Type'] = 'application/json',
            }
            local jsonData = HttpService:JSONEncode(dataFrame)
            local requestData = {
                Url = getgenv().WEBHOOK.URL,
                Method = 'POST',
                Headers = headers,
                Body = jsonData,
            }
            local success, result = pcall(function()
                return request(requestData)
            end)

            if success then
                Utils.PrintDebug(string.format('Request Succesful: %s', tostring(result)))
            else
                Utils.PrintDebug(string.format('Request Failed: %s', tostring(result)))
            end

            return nil
        end
        function self.Cleanup()
            if self.Connection then
                self.Connection:Disconnect()
            end
        end

        return self
    end
    function __DARKLUA_BUNDLE_MODULES.q()
        if debugX then
            warn('Initialising Rayfield')
        end

        local getService = function(name)
            local service = game:GetService(name)

            return (cloneref and {
                (cloneref(service)),
            } or {service})[1]
        end
        local loadWithTimeout = function(url, timeout)
            assert(type(url) == 'string', 'Expected string, got ' .. type(url))

            timeout = timeout or 5

            local requestCompleted = false
            local success, result = false, nil
            local requestThread = task.spawn(function()
                local fetchSuccess, fetchResult = pcall(game.HttpGet, game, url)

                if not fetchSuccess or #fetchResult == 0 then
                    if #fetchResult == 0 then
                        fetchResult = 'Empty response'
                    end

                    success, result = false, fetchResult
                    requestCompleted = true

                    return
                end

                local content = fetchResult
                local execSuccess, execResult = pcall(function()
                    return loadstring(content)()
                end)

                success, result = execSuccess, execResult
                requestCompleted = true
            end)
            local timeoutThread = task.delay(timeout, function()
                if not requestCompleted then
                    warn(string.format('Request for %s timed out after %s seconds', tostring(url), tostring(timeout)))
                    task.cancel(requestThread)

                    result = 'Request timed out'
                    requestCompleted = true
                end
            end)

            while not requestCompleted do
                task.wait()
            end

            if coroutine.status(timeoutThread) ~= 'dead' then
                task.cancel(timeoutThread)
            end
            if not success then
                warn(string.format('Failed to process %s: %s', tostring(url), tostring(result)))
            end

            return (success and {result} or {nil})[1]
        end
        local requestsDisabled = true
        local InterfaceBuild = '3K3W'
        local Release = 'Build 1.68'
        local RayfieldFolder = 'Rayfield'
        local ConfigurationFolder = RayfieldFolder .. '/Configurations'
        local ConfigurationExtension = '.rfld'
        local settingsTable = {
            General = {
                rayfieldOpen = {
                    Type = 'bind',
                    Value = 'K',
                    Name = 'Rayfield Keybind',
                },
            },
            System = {
                usageAnalytics = {
                    Type = 'toggle',
                    Value = true,
                    Name = 'Anonymised Analytics',
                },
            },
        }
        local overriddenSettings = {}
        local overrideSetting = function(category, name, value)
            overriddenSettings[string.format('%s.%s', tostring(category), tostring(name))] = value
        end
        local getSetting = function(category, name)
            if overriddenSettings[string.format('%s.%s', tostring(category), tostring(name))] ~= nil then
                return overriddenSettings[string.format('%s.%s', tostring(category), tostring(name))]
            elseif settingsTable[category][name] ~= nil then
                return settingsTable[category][name].Value
            end
        end

        if requestsDisabled then
            overrideSetting('System', 'usageAnalytics', false)
        end

        local HttpService = getService('HttpService')
        local RunService = getService('RunService')
        local useStudio = RunService:IsStudio() or false
        local settingsCreated = false
        local settingsInitialized = false
        local cachedSettings
        local prompt = loadWithTimeout(
[[https://raw.githubusercontent.com/SiriusSoftwareLtd/Sirius/refs/heads/request/prompt.lua]])
        local requestFunc = (syn and syn.request) or (fluxus and fluxus.request) or (http and http.request) or http_request or request

        if not prompt and not useStudio then
            warn('Failed to load prompt library, using fallback')

            prompt = {
                create = function() end,
            }
        end

        local loadSettings = function()
            local file = nil
            local success, _ = pcall(function()
                task.spawn(function()
                    if isfolder and isfolder(RayfieldFolder) then
                        if isfile and isfile(RayfieldFolder .. '/settings' .. ConfigurationExtension) then
                            file = readfile(RayfieldFolder .. '/settings' .. ConfigurationExtension)
                        end
                    end
                    if useStudio then
                        file = '\t\t{"General":{"rayfieldOpen":{"Value":"K","Type":"bind","Name":"Rayfield Keybind","Element":{"HoldToInteract":false,"Ext":true,"Name":"Rayfield Keybind","Set":null,"CallOnChange":true,"Callback":null,"CurrentKeybind":"K"}}},"System":{"usageAnalytics":{"Value":false,"Type":"toggle","Name":"Anonymised Analytics","Element":{"Ext":true,"Name":"Anonymised Analytics","Set":null,"CurrentValue":false,"Callback":null}}}}\n\t'
                    end
                    if file then
                        local success2, decodedFile = pcall(function()
                            return HttpService:JSONDecode(file)
                        end)

                        if success2 then
                            file = decodedFile
                        else
                            file = {}
                        end
                    else
                        file = {}
                    end
                    if not settingsCreated then
                        cachedSettings = file

                        return
                    end
                    if next(file) ~= nil then
                        for categoryName, settingCategory in pairs(settingsTable)do
                            if file[categoryName] then
                                for settingName, setting in pairs(settingCategory)do
                                    if file[categoryName][settingName] then
                                        setting.Value = file[categoryName][settingName].Value

                                        setting.Element:Set(getSetting(categoryName, settingName))
                                    end
                                end
                            end
                        end
                    end

                    settingsInitialized = true
                end)
            end)

            if not success then
                if writefile then
                    warn(
[[Rayfield had an issue accessing configuration saving capability.]])
                end
            end
        end

        if debugX then
            warn('Now Loading Settings Configuration')
        end

        loadSettings()

        if debugX then
            warn('Settings Loaded')
        end

        local analyticsLib
        local sendReport = function(ev_n, sc_n)
            warn('Failed to load report function')
        end

        if not requestsDisabled then
            if debugX then
                warn('Querying Settings for Reporter Information')
            end

            analyticsLib = loadWithTimeout('https://analytics.sirius.menu/script')

            if not analyticsLib then
                warn('Failed to load analytics reporter')

                analyticsLib = nil
            elseif analyticsLib and type(analyticsLib.load) == 'function' then
                analyticsLib:load()
            else
                warn('Analytics library loaded but missing load function')

                analyticsLib = nil
            end

            sendReport = function(ev_n, sc_n)
                if not (type(analyticsLib) == 'table' and type(analyticsLib.isLoaded) == 'function' and analyticsLib:isLoaded()) then
                    warn('Analytics library not loaded')

                    return
                end
                if useStudio then
                    print('Sending Analytics')
                else
                    if debugX then
                        warn('Reporting Analytics')
                    end

                    analyticsLib:report({
                        ['name'] = ev_n,
                        ['script'] = {
                            ['name'] = sc_n,
                            ['version'] = Release,
                        },
                    }, {
                        ['version'] = InterfaceBuild,
                    })

                    if debugX then
                        warn('Finished Report')
                    end
                end
            end

            if cachedSettings and (#cachedSettings == 0 or (cachedSettings.System and cachedSettings.System.usageAnalytics and cachedSettings.System.usageAnalytics.Value)) then
                sendReport('execution', 'Rayfield')
            end
        end

        local promptUser = 2

        if promptUser == 1 and prompt and type(prompt.create) == 'function' then
            prompt.create('Be cautious when running scripts', 
[[Please be careful when running scripts from unknown developers. This script has already been ran.

<font transparency='0.3'>Some scripts may steal your items or in-game goods.</font>]], 'Okay', '', function(
            ) end)
        end
        if debugX then
            warn('Moving on to continue initialisation')
        end

        local RayfieldLibrary = {
            Flags = {},
            Theme = {
                Default = {
                    TextColor = Color3.fromRGB(240, 240, 240),
                    Background = Color3.fromRGB(25, 25, 25),
                    Topbar = Color3.fromRGB(34, 34, 34),
                    Shadow = Color3.fromRGB(20, 20, 20),
                    NotificationBackground = Color3.fromRGB(20, 20, 20),
                    NotificationActionsBackground = Color3.fromRGB(230, 230, 230),
                    TabBackground = Color3.fromRGB(80, 80, 80),
                    TabStroke = Color3.fromRGB(85, 85, 85),
                    TabBackgroundSelected = Color3.fromRGB(210, 210, 210),
                    TabTextColor = Color3.fromRGB(240, 240, 240),
                    SelectedTabTextColor = Color3.fromRGB(50, 50, 50),
                    ElementBackground = Color3.fromRGB(35, 35, 35),
                    ElementBackgroundHover = Color3.fromRGB(40, 40, 40),
                    SecondaryElementBackground = Color3.fromRGB(25, 25, 25),
                    ElementStroke = Color3.fromRGB(50, 50, 50),
                    SecondaryElementStroke = Color3.fromRGB(40, 40, 40),
                    SliderBackground = Color3.fromRGB(50, 138, 220),
                    SliderProgress = Color3.fromRGB(50, 138, 220),
                    SliderStroke = Color3.fromRGB(58, 163, 255),
                    ToggleBackground = Color3.fromRGB(30, 30, 30),
                    ToggleEnabled = Color3.fromRGB(0, 146, 214),
                    ToggleDisabled = Color3.fromRGB(100, 100, 100),
                    ToggleEnabledStroke = Color3.fromRGB(0, 170, 255),
                    ToggleDisabledStroke = Color3.fromRGB(125, 125, 125),
                    ToggleEnabledOuterStroke = Color3.fromRGB(100, 100, 100),
                    ToggleDisabledOuterStroke = Color3.fromRGB(65, 65, 65),
                    DropdownSelected = Color3.fromRGB(40, 40, 40),
                    DropdownUnselected = Color3.fromRGB(30, 30, 30),
                    InputBackground = Color3.fromRGB(30, 30, 30),
                    InputStroke = Color3.fromRGB(65, 65, 65),
                    PlaceholderColor = Color3.fromRGB(178, 178, 178),
                },
                Ocean = {
                    TextColor = Color3.fromRGB(230, 240, 240),
                    Background = Color3.fromRGB(20, 30, 30),
                    Topbar = Color3.fromRGB(25, 40, 40),
                    Shadow = Color3.fromRGB(15, 20, 20),
                    NotificationBackground = Color3.fromRGB(25, 35, 35),
                    NotificationActionsBackground = Color3.fromRGB(230, 240, 240),
                    TabBackground = Color3.fromRGB(40, 60, 60),
                    TabStroke = Color3.fromRGB(50, 70, 70),
                    TabBackgroundSelected = Color3.fromRGB(100, 180, 180),
                    TabTextColor = Color3.fromRGB(210, 230, 230),
                    SelectedTabTextColor = Color3.fromRGB(20, 50, 50),
                    ElementBackground = Color3.fromRGB(30, 50, 50),
                    ElementBackgroundHover = Color3.fromRGB(40, 60, 60),
                    SecondaryElementBackground = Color3.fromRGB(30, 45, 45),
                    ElementStroke = Color3.fromRGB(45, 70, 70),
                    SecondaryElementStroke = Color3.fromRGB(40, 65, 65),
                    SliderBackground = Color3.fromRGB(0, 110, 110),
                    SliderProgress = Color3.fromRGB(0, 140, 140),
                    SliderStroke = Color3.fromRGB(0, 160, 160),
                    ToggleBackground = Color3.fromRGB(30, 50, 50),
                    ToggleEnabled = Color3.fromRGB(0, 130, 130),
                    ToggleDisabled = Color3.fromRGB(70, 90, 90),
                    ToggleEnabledStroke = Color3.fromRGB(0, 160, 160),
                    ToggleDisabledStroke = Color3.fromRGB(85, 105, 105),
                    ToggleEnabledOuterStroke = Color3.fromRGB(50, 100, 100),
                    ToggleDisabledOuterStroke = Color3.fromRGB(45, 65, 65),
                    DropdownSelected = Color3.fromRGB(30, 60, 60),
                    DropdownUnselected = Color3.fromRGB(25, 40, 40),
                    InputBackground = Color3.fromRGB(30, 50, 50),
                    InputStroke = Color3.fromRGB(50, 70, 70),
                    PlaceholderColor = Color3.fromRGB(140, 160, 160),
                },
                AmberGlow = {
                    TextColor = Color3.fromRGB(255, 245, 230),
                    Background = Color3.fromRGB(45, 30, 20),
                    Topbar = Color3.fromRGB(55, 40, 25),
                    Shadow = Color3.fromRGB(35, 25, 15),
                    NotificationBackground = Color3.fromRGB(50, 35, 25),
                    NotificationActionsBackground = Color3.fromRGB(245, 230, 215),
                    TabBackground = Color3.fromRGB(75, 50, 35),
                    TabStroke = Color3.fromRGB(90, 60, 45),
                    TabBackgroundSelected = Color3.fromRGB(230, 180, 100),
                    TabTextColor = Color3.fromRGB(250, 220, 200),
                    SelectedTabTextColor = Color3.fromRGB(50, 30, 10),
                    ElementBackground = Color3.fromRGB(60, 45, 35),
                    ElementBackgroundHover = Color3.fromRGB(70, 50, 40),
                    SecondaryElementBackground = Color3.fromRGB(55, 40, 30),
                    ElementStroke = Color3.fromRGB(85, 60, 45),
                    SecondaryElementStroke = Color3.fromRGB(75, 50, 35),
                    SliderBackground = Color3.fromRGB(220, 130, 60),
                    SliderProgress = Color3.fromRGB(250, 150, 75),
                    SliderStroke = Color3.fromRGB(255, 170, 85),
                    ToggleBackground = Color3.fromRGB(55, 40, 30),
                    ToggleEnabled = Color3.fromRGB(240, 130, 30),
                    ToggleDisabled = Color3.fromRGB(90, 70, 60),
                    ToggleEnabledStroke = Color3.fromRGB(255, 160, 50),
                    ToggleDisabledStroke = Color3.fromRGB(110, 85, 75),
                    ToggleEnabledOuterStroke = Color3.fromRGB(200, 100, 50),
                    ToggleDisabledOuterStroke = Color3.fromRGB(75, 60, 55),
                    DropdownSelected = Color3.fromRGB(70, 50, 40),
                    DropdownUnselected = Color3.fromRGB(55, 40, 30),
                    InputBackground = Color3.fromRGB(60, 45, 35),
                    InputStroke = Color3.fromRGB(90, 65, 50),
                    PlaceholderColor = Color3.fromRGB(190, 150, 130),
                },
                Light = {
                    TextColor = Color3.fromRGB(40, 40, 40),
                    Background = Color3.fromRGB(245, 245, 245),
                    Topbar = Color3.fromRGB(230, 230, 230),
                    Shadow = Color3.fromRGB(200, 200, 200),
                    NotificationBackground = Color3.fromRGB(250, 250, 250),
                    NotificationActionsBackground = Color3.fromRGB(240, 240, 240),
                    TabBackground = Color3.fromRGB(235, 235, 235),
                    TabStroke = Color3.fromRGB(215, 215, 215),
                    TabBackgroundSelected = Color3.fromRGB(255, 255, 255),
                    TabTextColor = Color3.fromRGB(80, 80, 80),
                    SelectedTabTextColor = Color3.fromRGB(0, 0, 0),
                    ElementBackground = Color3.fromRGB(240, 240, 240),
                    ElementBackgroundHover = Color3.fromRGB(225, 225, 225),
                    SecondaryElementBackground = Color3.fromRGB(235, 235, 235),
                    ElementStroke = Color3.fromRGB(210, 210, 210),
                    SecondaryElementStroke = Color3.fromRGB(210, 210, 210),
                    SliderBackground = Color3.fromRGB(150, 180, 220),
                    SliderProgress = Color3.fromRGB(100, 150, 200),
                    SliderStroke = Color3.fromRGB(120, 170, 220),
                    ToggleBackground = Color3.fromRGB(220, 220, 220),
                    ToggleEnabled = Color3.fromRGB(0, 146, 214),
                    ToggleDisabled = Color3.fromRGB(150, 150, 150),
                    ToggleEnabledStroke = Color3.fromRGB(0, 170, 255),
                    ToggleDisabledStroke = Color3.fromRGB(170, 170, 170),
                    ToggleEnabledOuterStroke = Color3.fromRGB(100, 100, 100),
                    ToggleDisabledOuterStroke = Color3.fromRGB(180, 180, 180),
                    DropdownSelected = Color3.fromRGB(230, 230, 230),
                    DropdownUnselected = Color3.fromRGB(220, 220, 220),
                    InputBackground = Color3.fromRGB(240, 240, 240),
                    InputStroke = Color3.fromRGB(180, 180, 180),
                    PlaceholderColor = Color3.fromRGB(140, 140, 140),
                },
                Amethyst = {
                    TextColor = Color3.fromRGB(240, 240, 240),
                    Background = Color3.fromRGB(30, 20, 40),
                    Topbar = Color3.fromRGB(40, 25, 50),
                    Shadow = Color3.fromRGB(20, 15, 30),
                    NotificationBackground = Color3.fromRGB(35, 20, 40),
                    NotificationActionsBackground = Color3.fromRGB(240, 240, 250),
                    TabBackground = Color3.fromRGB(60, 40, 80),
                    TabStroke = Color3.fromRGB(70, 45, 90),
                    TabBackgroundSelected = Color3.fromRGB(180, 140, 200),
                    TabTextColor = Color3.fromRGB(230, 230, 240),
                    SelectedTabTextColor = Color3.fromRGB(50, 20, 50),
                    ElementBackground = Color3.fromRGB(45, 30, 60),
                    ElementBackgroundHover = Color3.fromRGB(50, 35, 70),
                    SecondaryElementBackground = Color3.fromRGB(40, 30, 55),
                    ElementStroke = Color3.fromRGB(70, 50, 85),
                    SecondaryElementStroke = Color3.fromRGB(65, 45, 80),
                    SliderBackground = Color3.fromRGB(100, 60, 150),
                    SliderProgress = Color3.fromRGB(130, 80, 180),
                    SliderStroke = Color3.fromRGB(150, 100, 200),
                    ToggleBackground = Color3.fromRGB(45, 30, 55),
                    ToggleEnabled = Color3.fromRGB(120, 60, 150),
                    ToggleDisabled = Color3.fromRGB(94, 47, 117),
                    ToggleEnabledStroke = Color3.fromRGB(140, 80, 170),
                    ToggleDisabledStroke = Color3.fromRGB(124, 71, 150),
                    ToggleEnabledOuterStroke = Color3.fromRGB(90, 40, 120),
                    ToggleDisabledOuterStroke = Color3.fromRGB(80, 50, 110),
                    DropdownSelected = Color3.fromRGB(50, 35, 70),
                    DropdownUnselected = Color3.fromRGB(35, 25, 50),
                    InputBackground = Color3.fromRGB(45, 30, 60),
                    InputStroke = Color3.fromRGB(80, 50, 110),
                    PlaceholderColor = Color3.fromRGB(178, 150, 200),
                },
                Green = {
                    TextColor = Color3.fromRGB(30, 60, 30),
                    Background = Color3.fromRGB(235, 245, 235),
                    Topbar = Color3.fromRGB(210, 230, 210),
                    Shadow = Color3.fromRGB(200, 220, 200),
                    NotificationBackground = Color3.fromRGB(240, 250, 240),
                    NotificationActionsBackground = Color3.fromRGB(220, 235, 220),
                    TabBackground = Color3.fromRGB(215, 235, 215),
                    TabStroke = Color3.fromRGB(190, 210, 190),
                    TabBackgroundSelected = Color3.fromRGB(245, 255, 245),
                    TabTextColor = Color3.fromRGB(50, 80, 50),
                    SelectedTabTextColor = Color3.fromRGB(20, 60, 20),
                    ElementBackground = Color3.fromRGB(225, 240, 225),
                    ElementBackgroundHover = Color3.fromRGB(210, 225, 210),
                    SecondaryElementBackground = Color3.fromRGB(235, 245, 235),
                    ElementStroke = Color3.fromRGB(180, 200, 180),
                    SecondaryElementStroke = Color3.fromRGB(180, 200, 180),
                    SliderBackground = Color3.fromRGB(90, 160, 90),
                    SliderProgress = Color3.fromRGB(70, 130, 70),
                    SliderStroke = Color3.fromRGB(100, 180, 100),
                    ToggleBackground = Color3.fromRGB(215, 235, 215),
                    ToggleEnabled = Color3.fromRGB(60, 130, 60),
                    ToggleDisabled = Color3.fromRGB(150, 175, 150),
                    ToggleEnabledStroke = Color3.fromRGB(80, 150, 80),
                    ToggleDisabledStroke = Color3.fromRGB(130, 150, 130),
                    ToggleEnabledOuterStroke = Color3.fromRGB(100, 160, 100),
                    ToggleDisabledOuterStroke = Color3.fromRGB(160, 180, 160),
                    DropdownSelected = Color3.fromRGB(225, 240, 225),
                    DropdownUnselected = Color3.fromRGB(210, 225, 210),
                    InputBackground = Color3.fromRGB(235, 245, 235),
                    InputStroke = Color3.fromRGB(180, 200, 180),
                    PlaceholderColor = Color3.fromRGB(120, 140, 120),
                },
                Bloom = {
                    TextColor = Color3.fromRGB(60, 40, 50),
                    Background = Color3.fromRGB(255, 240, 245),
                    Topbar = Color3.fromRGB(250, 220, 225),
                    Shadow = Color3.fromRGB(230, 190, 195),
                    NotificationBackground = Color3.fromRGB(255, 235, 240),
                    NotificationActionsBackground = Color3.fromRGB(245, 215, 225),
                    TabBackground = Color3.fromRGB(240, 210, 220),
                    TabStroke = Color3.fromRGB(230, 200, 210),
                    TabBackgroundSelected = Color3.fromRGB(255, 225, 235),
                    TabTextColor = Color3.fromRGB(80, 40, 60),
                    SelectedTabTextColor = Color3.fromRGB(50, 30, 50),
                    ElementBackground = Color3.fromRGB(255, 235, 240),
                    ElementBackgroundHover = Color3.fromRGB(245, 220, 230),
                    SecondaryElementBackground = Color3.fromRGB(255, 235, 240),
                    ElementStroke = Color3.fromRGB(230, 200, 210),
                    SecondaryElementStroke = Color3.fromRGB(230, 200, 210),
                    SliderBackground = Color3.fromRGB(240, 130, 160),
                    SliderProgress = Color3.fromRGB(250, 160, 180),
                    SliderStroke = Color3.fromRGB(255, 180, 200),
                    ToggleBackground = Color3.fromRGB(240, 210, 220),
                    ToggleEnabled = Color3.fromRGB(255, 140, 170),
                    ToggleDisabled = Color3.fromRGB(200, 180, 185),
                    ToggleEnabledStroke = Color3.fromRGB(250, 160, 190),
                    ToggleDisabledStroke = Color3.fromRGB(210, 180, 190),
                    ToggleEnabledOuterStroke = Color3.fromRGB(220, 160, 180),
                    ToggleDisabledOuterStroke = Color3.fromRGB(190, 170, 180),
                    DropdownSelected = Color3.fromRGB(250, 220, 225),
                    DropdownUnselected = Color3.fromRGB(240, 210, 220),
                    InputBackground = Color3.fromRGB(255, 235, 240),
                    InputStroke = Color3.fromRGB(220, 190, 200),
                    PlaceholderColor = Color3.fromRGB(170, 130, 140),
                },
                DarkBlue = {
                    TextColor = Color3.fromRGB(230, 230, 230),
                    Background = Color3.fromRGB(20, 25, 30),
                    Topbar = Color3.fromRGB(30, 35, 40),
                    Shadow = Color3.fromRGB(15, 20, 25),
                    NotificationBackground = Color3.fromRGB(25, 30, 35),
                    NotificationActionsBackground = Color3.fromRGB(45, 50, 55),
                    TabBackground = Color3.fromRGB(35, 40, 45),
                    TabStroke = Color3.fromRGB(45, 50, 60),
                    TabBackgroundSelected = Color3.fromRGB(40, 70, 100),
                    TabTextColor = Color3.fromRGB(200, 200, 200),
                    SelectedTabTextColor = Color3.fromRGB(255, 255, 255),
                    ElementBackground = Color3.fromRGB(30, 35, 40),
                    ElementBackgroundHover = Color3.fromRGB(40, 45, 50),
                    SecondaryElementBackground = Color3.fromRGB(35, 40, 45),
                    ElementStroke = Color3.fromRGB(45, 50, 60),
                    SecondaryElementStroke = Color3.fromRGB(40, 45, 55),
                    SliderBackground = Color3.fromRGB(0, 90, 180),
                    SliderProgress = Color3.fromRGB(0, 120, 210),
                    SliderStroke = Color3.fromRGB(0, 150, 240),
                    ToggleBackground = Color3.fromRGB(35, 40, 45),
                    ToggleEnabled = Color3.fromRGB(0, 120, 210),
                    ToggleDisabled = Color3.fromRGB(70, 70, 80),
                    ToggleEnabledStroke = Color3.fromRGB(0, 150, 240),
                    ToggleDisabledStroke = Color3.fromRGB(75, 75, 85),
                    ToggleEnabledOuterStroke = Color3.fromRGB(20, 100, 180),
                    ToggleDisabledOuterStroke = Color3.fromRGB(55, 55, 65),
                    DropdownSelected = Color3.fromRGB(30, 70, 90),
                    DropdownUnselected = Color3.fromRGB(25, 30, 35),
                    InputBackground = Color3.fromRGB(25, 30, 35),
                    InputStroke = Color3.fromRGB(45, 50, 60),
                    PlaceholderColor = Color3.fromRGB(150, 150, 160),
                },
                Serenity = {
                    TextColor = Color3.fromRGB(50, 55, 60),
                    Background = Color3.fromRGB(240, 245, 250),
                    Topbar = Color3.fromRGB(215, 225, 235),
                    Shadow = Color3.fromRGB(200, 210, 220),
                    NotificationBackground = Color3.fromRGB(210, 220, 230),
                    NotificationActionsBackground = Color3.fromRGB(225, 230, 240),
                    TabBackground = Color3.fromRGB(200, 210, 220),
                    TabStroke = Color3.fromRGB(180, 190, 200),
                    TabBackgroundSelected = Color3.fromRGB(175, 185, 200),
                    TabTextColor = Color3.fromRGB(50, 55, 60),
                    SelectedTabTextColor = Color3.fromRGB(30, 35, 40),
                    ElementBackground = Color3.fromRGB(210, 220, 230),
                    ElementBackgroundHover = Color3.fromRGB(220, 230, 240),
                    SecondaryElementBackground = Color3.fromRGB(200, 210, 220),
                    ElementStroke = Color3.fromRGB(190, 200, 210),
                    SecondaryElementStroke = Color3.fromRGB(180, 190, 200),
                    SliderBackground = Color3.fromRGB(200, 220, 235),
                    SliderProgress = Color3.fromRGB(70, 130, 180),
                    SliderStroke = Color3.fromRGB(150, 180, 220),
                    ToggleBackground = Color3.fromRGB(210, 220, 230),
                    ToggleEnabled = Color3.fromRGB(70, 160, 210),
                    ToggleDisabled = Color3.fromRGB(180, 180, 180),
                    ToggleEnabledStroke = Color3.fromRGB(60, 150, 200),
                    ToggleDisabledStroke = Color3.fromRGB(140, 140, 140),
                    ToggleEnabledOuterStroke = Color3.fromRGB(100, 120, 140),
                    ToggleDisabledOuterStroke = Color3.fromRGB(120, 120, 130),
                    DropdownSelected = Color3.fromRGB(220, 230, 240),
                    DropdownUnselected = Color3.fromRGB(200, 210, 220),
                    InputBackground = Color3.fromRGB(220, 230, 240),
                    InputStroke = Color3.fromRGB(180, 190, 200),
                    PlaceholderColor = Color3.fromRGB(150, 150, 150),
                },
            },
        }
        local UserInputService = getService('UserInputService')
        local TweenService = getService('TweenService')
        local Players = getService('Players')
        local CoreGui = getService('CoreGui')
        local Rayfield = useStudio and script.Parent:FindFirstChild('Rayfield') or game:GetObjects('rbxassetid://10804731440')[1]
        local buildAttempts = 0
        local correctBuild = false
        local warned
        local globalLoaded
        local rayfieldDestroyed = false

        repeat
            if Rayfield:FindFirstChild('Build') and Rayfield.Build.Value == InterfaceBuild then
                correctBuild = true

                break
            end

            correctBuild = false

            if not warned then
                warn('Rayfield | Build Mismatch')
                print(
[[Rayfield may encounter issues as you are running an incompatible interface version (]] .. ((Rayfield:FindFirstChild('Build') and Rayfield.Build.Value) or 'No Build') .. 
[[).

This version of Rayfield is intended for interface build ]] .. InterfaceBuild .. '.')

                warned = true
            end

            toDestroy, Rayfield = Rayfield, useStudio and script.Parent:FindFirstChild('Rayfield') or game:GetObjects('rbxassetid://10804731440')[1]

            if toDestroy and not useStudio then
                toDestroy:Destroy()
            end

            buildAttempts = buildAttempts + 1
        until buildAttempts >= 2

        Rayfield.Enabled = false

        if gethui then
            Rayfield.Parent = gethui()
        elseif syn and syn.protect_gui then
            syn.protect_gui(Rayfield)

            Rayfield.Parent = CoreGui
        elseif not useStudio and CoreGui:FindFirstChild('RobloxGui') then
            Rayfield.Parent = CoreGui:FindFirstChild('RobloxGui')
        elseif not useStudio then
            Rayfield.Parent = CoreGui
        end
        if gethui then
            for _, Interface in ipairs(gethui():GetChildren())do
                if Interface.Name == Rayfield.Name and Interface ~= Rayfield then
                    Interface.Enabled = false
                    Interface.Name = 'Rayfield-Old'
                end
            end
        elseif not useStudio then
            for _, Interface in ipairs(CoreGui:GetChildren())do
                if Interface.Name == Rayfield.Name and Interface ~= Rayfield then
                    Interface.Enabled = false
                    Interface.Name = 'Rayfield-Old'
                end
            end
        end

        local minSize = Vector2.new(1024, 768)
        local useMobileSizing

        if Rayfield.AbsoluteSize.X < minSize.X and Rayfield.AbsoluteSize.Y < minSize.Y then
            useMobileSizing = true
        end
        if UserInputService.TouchEnabled then
            useMobilePrompt = true
        end

        local Main = Rayfield.Main
        local MPrompt = Rayfield:FindFirstChild('Prompt')
        local Topbar = Main.Topbar
        local Elements = Main.Elements
        local LoadingFrame = Main.LoadingFrame
        local TabList = Main.TabList
        local dragBar = Rayfield:FindFirstChild('Drag')
        local dragInteract = dragBar and dragBar.Interact or nil
        local dragBarCosmetic = dragBar and dragBar.Drag or nil
        local dragOffset = 255
        local dragOffsetMobile = 150

        Rayfield.DisplayOrder = 100
        LoadingFrame.Version.Text = Release

        local Icons = loadWithTimeout(
[[https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/refs/heads/main/icons.lua]])
        local CFileName = nil
        local CEnabled = false
        local Minimised = false
        local Hidden = false
        local Debounce = false
        local searchOpen = false
        local Notifications = Rayfield.Notifications
        local SelectedTheme = RayfieldLibrary.Theme.Default
        local ChangeTheme = function(Theme)
            if typeof(Theme) == 'string' then
                SelectedTheme = RayfieldLibrary.Theme[Theme]
            elseif typeof(Theme) == 'table' then
                SelectedTheme = Theme
            end

            Rayfield.Main.BackgroundColor3 = SelectedTheme.Background
            Rayfield.Main.Topbar.BackgroundColor3 = SelectedTheme.Topbar
            Rayfield.Main.Topbar.CornerRepair.BackgroundColor3 = SelectedTheme.Topbar
            Rayfield.Main.Shadow.Image.ImageColor3 = SelectedTheme.Shadow
            Rayfield.Main.Topbar.ChangeSize.ImageColor3 = SelectedTheme.TextColor
            Rayfield.Main.Topbar.Hide.ImageColor3 = SelectedTheme.TextColor
            Rayfield.Main.Topbar.Search.ImageColor3 = SelectedTheme.TextColor

            if Topbar:FindFirstChild('Settings') then
                Rayfield.Main.Topbar.Settings.ImageColor3 = SelectedTheme.TextColor
                Rayfield.Main.Topbar.Divider.BackgroundColor3 = SelectedTheme.ElementStroke
            end

            Main.Search.BackgroundColor3 = SelectedTheme.TextColor
            Main.Search.Shadow.ImageColor3 = SelectedTheme.TextColor
            Main.Search.Search.ImageColor3 = SelectedTheme.TextColor
            Main.Search.Input.PlaceholderColor3 = SelectedTheme.TextColor
            Main.Search.UIStroke.Color = SelectedTheme.SecondaryElementStroke

            if Main:FindFirstChild('Notice') then
                Main.Notice.BackgroundColor3 = SelectedTheme.Background
            end

            for _, text in ipairs(Rayfield:GetDescendants())do
                if text.Parent.Parent ~= Notifications then
                    if text:IsA('TextLabel') or text:IsA('TextBox') then
                        text.TextColor3 = SelectedTheme.TextColor
                    end
                end
            end
            for _, TabPage in ipairs(Elements:GetChildren())do
                for _, Element in ipairs(TabPage:GetChildren())do
                    if Element.ClassName == 'Frame' and Element.Name ~= 'Placeholder' and Element.Name ~= 'SectionSpacing' and Element.Name ~= 'Divider' and Element.Name ~= 'SectionTitle' and Element.Name ~= 'SearchTitle-fsefsefesfsefesfesfThanks' then
                        Element.BackgroundColor3 = SelectedTheme.ElementBackground
                        Element.UIStroke.Color = SelectedTheme.ElementStroke
                    end
                end
            end
        end
        local getIcon = function(name)
            if not Icons then
                warn(
[[Lucide Icons: Cannot use icons as icons library is not loaded]])

                return
            end

            name = (string.match(string.lower(name), '^%s*(.*)%s*$'))

            local sizedicons = Icons['48px']
            local r = sizedicons[name]

            if not r then
                error(string.format('Lucide Icons: Failed to find icon by the name of "%s"', tostring(name)), 2)
            end

            local rirs = r[2]
            local riro = r[3]

            if type(r[1]) ~= 'number' or type(rirs) ~= 'table' or type(riro) ~= 'table' then
                error(
[[Lucide Icons: Internal error: Invalid auto-generated asset entry]])
            end

            local irs = Vector2.new(rirs[1], rirs[2])
            local iro = Vector2.new(riro[1], riro[2])
            local asset = {
                id = r[1],
                imageRectSize = irs,
                imageRectOffset = iro,
            }

            return asset
        end
        local getAssetUri = function(id)
            local assetUri = 'rbxassetid://0'

            if type(id) == 'number' then
                assetUri = 'rbxassetid://' .. id
            elseif type(id) == 'string' and not Icons then
                warn(
[[Rayfield | Cannot use Lucide icons as icons library is not loaded]])
            else
                warn(
[[Rayfield | The icon argument must either be an icon ID (number) or a Lucide icon name (string)]])
            end

            return assetUri
        end
        local makeDraggable = function(
            object,
            dragObject,
            enableTaptic,
            tapticOffset
        )
            local dragging = false
            local relative = nil
            local offset = Vector2.zero
            local screenGui = object:FindFirstAncestorWhichIsA('ScreenGui')

            if screenGui and screenGui.IgnoreGuiInset then
                offset = offset + getService('GuiService'):GetGuiInset()
            end

            local connectFunctions = function()
                if dragBar and enableTaptic then
                    dragBar.MouseEnter:Connect(function()
                        if not dragging and not Hidden then
                            TweenService:Create(dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                                BackgroundTransparency = 0.5,
                                Size = UDim2.new(0, 120, 0, 4),
                            }):Play()
                        end
                    end)
                    dragBar.MouseLeave:Connect(function()
                        if not dragging and not Hidden then
                            TweenService:Create(dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                                BackgroundTransparency = 0.7,
                                Size = UDim2.new(0, 100, 0, 4),
                            }):Play()
                        end
                    end)
                end
            end

            connectFunctions()
            dragObject.InputBegan:Connect(function(input, processed)
                if processed then
                    return
                end

                local inputType = input.UserInputType.Name

                if inputType == 'MouseButton1' or inputType == 'Touch' then
                    dragging = true
                    relative = object.AbsolutePosition + object.AbsoluteSize * object.AnchorPoint - UserInputService:GetMouseLocation()

                    if enableTaptic and not Hidden then
                        TweenService:Create(dragBarCosmetic, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                            Size = UDim2.new(0, 110, 0, 4),
                            BackgroundTransparency = 0,
                        }):Play()
                    end
                end
            end)

            local inputEnded = UserInputService.InputEnded:Connect(function(
                input
            )
                if not dragging then
                    return
                end

                local inputType = input.UserInputType.Name

                if inputType == 'MouseButton1' or inputType == 'Touch' then
                    dragging = false

                    connectFunctions()

                    if enableTaptic and not Hidden then
                        TweenService:Create(dragBarCosmetic, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                            Size = UDim2.new(0, 100, 0, 4),
                            BackgroundTransparency = 0.7,
                        }):Play()
                    end
                end
            end)
            local renderStepped = RunService.RenderStepped:Connect(function()
                if dragging and not Hidden then
                    local position = UserInputService:GetMouseLocation() + relative + offset

                    if enableTaptic and tapticOffset then
                        TweenService:Create(object, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                            Position = UDim2.fromOffset(position.X, position.Y),
                        }):Play()
                        TweenService:Create(dragObject.Parent, TweenInfo.new(0.05, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                            Position = UDim2.fromOffset(position.X, position.Y + ((useMobileSizing and tapticOffset[2]) or tapticOffset[1])),
                        }):Play()
                    else
                        if dragBar and tapticOffset then
                            dragBar.Position = UDim2.fromOffset(position.X, position.Y + ((useMobileSizing and tapticOffset[2]) or tapticOffset[1]))
                        end

                        object.Position = UDim2.fromOffset(position.X, position.Y)
                    end
                end
            end)

            object.Destroying:Connect(function()
                if inputEnded then
                    inputEnded:Disconnect()
                end
                if renderStepped then
                    renderStepped:Disconnect()
                end
            end)
        end
        local PackColor = function(Color)
            return {
                R = Color.R * 255,
                G = Color.G * 255,
                B = Color.B * 255,
            }
        end
        local UnpackColor = function(Color)
            return Color3.fromRGB(Color.R, Color.G, Color.B)
        end
        local LoadConfiguration = function(Configuration)
            local success, Data = pcall(function()
                return HttpService:JSONDecode(Configuration)
            end)
            local changed

            if not success then
                warn(
[[Rayfield had an issue decoding the configuration file, please try delete the file and reopen Rayfield.]])

                return
            end

            for FlagName, Flag in pairs(RayfieldLibrary.Flags)do
                local FlagValue = Data[FlagName]

                if (typeof(FlagValue) == 'boolean' and FlagValue == false) or FlagValue then
                    task.spawn(function()
                        if Flag.Type == 'ColorPicker' then
                            changed = true

                            Flag:Set(UnpackColor(FlagValue))
                        else
                            if (Flag.CurrentValue or Flag.CurrentKeybind or Flag.CurrentOption or Flag.Color) ~= FlagValue then
                                changed = true

                                Flag:Set(FlagValue)
                            end
                        end
                    end)
                else
                    warn("Rayfield | Unable to find '" .. FlagName .. "' in the save file.")
                    print(
[[The error above may not be an issue if new elements have been added or not been set values.]])
                end
            end

            return changed
        end
        local SaveConfiguration = function()
            if not CEnabled or not globalLoaded then
                return
            end
            if debugX then
                print('Saving')
            end

            local Data = {}

            for i, v in pairs(RayfieldLibrary.Flags)do
                if v.Type == 'ColorPicker' then
                    Data[i] = PackColor(v.Color)
                else
                    if typeof(v.CurrentValue) == 'boolean' then
                        if v.CurrentValue == false then
                            Data[i] = false
                        else
                            Data[i] = v.CurrentValue or v.CurrentKeybind or v.CurrentOption or v.Color
                        end
                    else
                        Data[i] = v.CurrentValue or v.CurrentKeybind or v.CurrentOption or v.Color
                    end
                end
            end

            if useStudio then
                if script.Parent:FindFirstChild('configuration') then
                    script.Parent.configuration:Destroy()
                end

                local ScreenGui = Instance.new('ScreenGui')

                ScreenGui.Parent = script.Parent
                ScreenGui.Name = 'configuration'

                local TextBox = Instance.new('TextBox')

                TextBox.Parent = ScreenGui
                TextBox.Size = UDim2.new(0, 800, 0, 50)
                TextBox.AnchorPoint = Vector2.new(0.5, 0)
                TextBox.Position = UDim2.new(0.5, 0, 0, 30)
                TextBox.Text = HttpService:JSONEncode(Data)
                TextBox.ClearTextOnFocus = false
            end
            if debugX then
                warn(HttpService:JSONEncode(Data))
            end
            if writefile then
                writefile(ConfigurationFolder .. '/' .. CFileName .. ConfigurationExtension, tostring(HttpService:JSONEncode(Data)))
            end
        end

        function RayfieldLibrary:Notify(data)
            task.spawn(function()
                local newNotification = Notifications.Template:Clone()

                newNotification.Name = data.Title or 'No Title Provided'
                newNotification.Parent = Notifications
                newNotification.LayoutOrder = #Notifications:GetChildren()
                newNotification.Visible = false
                newNotification.Title.Text = data.Title or 'Unknown Title'
                newNotification.Description.Text = data.Content or 'Unknown Content'

                if data.Image then
                    if typeof(data.Image) == 'string' and Icons then
                        local asset = getIcon(data.Image)

                        newNotification.Icon.Image = 'rbxassetid://' .. asset.id
                        newNotification.Icon.ImageRectOffset = asset.imageRectOffset
                        newNotification.Icon.ImageRectSize = asset.imageRectSize
                    else
                        newNotification.Icon.Image = getAssetUri(data.Image)
                    end
                else
                    newNotification.Icon.Image = 'rbxassetid://0'
                end

                newNotification.Title.TextColor3 = SelectedTheme.TextColor
                newNotification.Description.TextColor3 = SelectedTheme.TextColor
                newNotification.BackgroundColor3 = SelectedTheme.Background
                newNotification.UIStroke.Color = SelectedTheme.TextColor
                newNotification.Icon.ImageColor3 = SelectedTheme.TextColor
                newNotification.BackgroundTransparency = 1
                newNotification.Title.TextTransparency = 1
                newNotification.Description.TextTransparency = 1
                newNotification.UIStroke.Transparency = 1
                newNotification.Shadow.ImageTransparency = 1
                newNotification.Size = UDim2.new(1, 0, 0, 800)
                newNotification.Icon.ImageTransparency = 1
                newNotification.Icon.BackgroundTransparency = 1

                task.wait()

                newNotification.Visible = true

                if data.Actions then
                    warn('Rayfield | Not seeing your actions in notifications?')
                    print(
[[Notification Actions are being sunset for now, keep up to date on when they're back in the discord. (sirius.menu/discord)]])
                end

                local bounds = {
                    newNotification.Title.TextBounds.Y,
                    newNotification.Description.TextBounds.Y,
                }

                newNotification.Size = UDim2.new(1, -60, 0, -Notifications:FindFirstChild('UIListLayout').Padding.Offset)
                newNotification.Icon.Size = UDim2.new(0, 32, 0, 32)
                newNotification.Icon.Position = UDim2.new(0, 20, 0.5, 0)

                TweenService:Create(newNotification, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                    Size = UDim2.new(1, 0, 0, math.max(bounds[1] + bounds[2] + 31, 60)),
                }):Play()
                task.wait(0.15)
                TweenService:Create(newNotification, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.45}):Play()
                TweenService:Create(newNotification.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
                task.wait(0.05)
                TweenService:Create(newNotification.Icon, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
                task.wait(0.05)
                TweenService:Create(newNotification.Description, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0.35}):Play()
                TweenService:Create(newNotification.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 0.95}):Play()
                TweenService:Create(newNotification.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0.82}):Play()

                local waitDuration = math.min(math.max((#newNotification.Description.Text * 0.1) + 2.5, 3), 10)

                task.wait(data.Duration or waitDuration)

                newNotification.Icon.Visible = false

                TweenService:Create(newNotification, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
                TweenService:Create(newNotification.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                TweenService:Create(newNotification.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
                TweenService:Create(newNotification.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                TweenService:Create(newNotification.Description, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                TweenService:Create(newNotification, TweenInfo.new(1, Enum.EasingStyle.Exponential), {
                    Size = UDim2.new(1, -90, 0, 0),
                }):Play()
                task.wait(1)
                TweenService:Create(newNotification, TweenInfo.new(1, Enum.EasingStyle.Exponential), {
                    Size = UDim2.new(1, -90, 0, -Notifications:FindFirstChild('UIListLayout').Padding.Offset),
                }):Play()

                newNotification.Visible = false

                newNotification:Destroy()
            end)
        end

        local openSearch = function()
            searchOpen = true
            Main.Search.BackgroundTransparency = 1
            Main.Search.Shadow.ImageTransparency = 1
            Main.Search.Input.TextTransparency = 1
            Main.Search.Search.ImageTransparency = 1
            Main.Search.UIStroke.Transparency = 1
            Main.Search.Size = UDim2.new(1, 0, 0, 80)
            Main.Search.Position = UDim2.new(0.5, 0, 0, 70)
            Main.Search.Input.Interactable = true
            Main.Search.Visible = true

            for _, tabbtn in ipairs(TabList:GetChildren())do
                if tabbtn.ClassName == 'Frame' and tabbtn.Name ~= 'Placeholder' then
                    tabbtn.Interact.Visible = false

                    TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
                    TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                    TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
                    TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                end
            end

            Main.Search.Input:CaptureFocus()
            TweenService:Create(Main.Search.Shadow, TweenInfo.new(0.05, Enum.EasingStyle.Quint), {ImageTransparency = 0.95}):Play()
            TweenService:Create(Main.Search, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {
                Position = UDim2.new(0.5, 0, 0, 57),
                BackgroundTransparency = 0.9,
            }):Play()
            TweenService:Create(Main.Search.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 0.8}):Play()
            TweenService:Create(Main.Search.Input, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0.2}):Play()
            TweenService:Create(Main.Search.Search, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0.5}):Play()
            TweenService:Create(Main.Search, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {
                Size = UDim2.new(1, -35, 0, 35),
            }):Play()
        end
        local closeSearch = function()
            searchOpen = false

            TweenService:Create(Main.Search, TweenInfo.new(0.35, Enum.EasingStyle.Quint), {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -55, 0, 30),
            }):Play()
            TweenService:Create(Main.Search.Search, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
            TweenService:Create(Main.Search.Shadow, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
            TweenService:Create(Main.Search.UIStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
            TweenService:Create(Main.Search.Input, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()

            for _, tabbtn in ipairs(TabList:GetChildren())do
                if tabbtn.ClassName == 'Frame' and tabbtn.Name ~= 'Placeholder' then
                    tabbtn.Interact.Visible = true

                    if tostring(Elements.UIPageLayout.CurrentPage) == tabbtn.Title.Text then
                        TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
                        TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
                        TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
                        TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                    else
                        TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.7}):Play()
                        TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0.2}):Play()
                        TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0.2}):Play()
                        TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 0.5}):Play()
                    end
                end
            end

            Main.Search.Input.Text = ''
            Main.Search.Input.Interactable = false
        end
        local Hide = function(notify)
            if MPrompt then
                MPrompt.Title.TextColor3 = Color3.fromRGB(255, 255, 255)
                MPrompt.Position = UDim2.new(0.5, 0, 0, -50)
                MPrompt.Size = UDim2.new(0, 40, 0, 10)
                MPrompt.BackgroundTransparency = 1
                MPrompt.Title.TextTransparency = 1
                MPrompt.Visible = true
            end

            task.spawn(closeSearch)

            Debounce = true

            if notify then
                if useMobilePrompt then
                    RayfieldLibrary:Notify({
                        Title = 'Interface Hidden',
                        Content = 
[[The interface has been hidden, you can unhide the interface by tapping 'Show'.]],
                        Duration = 7,
                        Image = 4400697855,
                    })
                else
                    RayfieldLibrary:Notify({
                        Title = 'Interface Hidden',
                        Content = string.format(
[[The interface has been hidden, you can unhide the interface by tapping %s.]], tostring(getSetting('General', 'rayfieldOpen'))),
                        Duration = 7,
                        Image = 4400697855,
                    })
                end
            end

            TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {
                Size = UDim2.new(0, 470, 0, 0),
            }):Play()
            TweenService:Create(Main.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {
                Size = UDim2.new(0, 470, 0, 45),
            }):Play()
            TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
            TweenService:Create(Main.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
            TweenService:Create(Main.Topbar.Divider, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
            TweenService:Create(Main.Topbar.CornerRepair, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
            TweenService:Create(Main.Topbar.Title, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
            TweenService:Create(Main.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
            TweenService:Create(Topbar.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
            TweenService:Create(dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()

            if useMobilePrompt and MPrompt then
                TweenService:Create(MPrompt, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {
                    Size = UDim2.new(0, 120, 0, 30),
                    Position = UDim2.new(0.5, 0, 0, 20),
                    BackgroundTransparency = 0.3,
                }):Play()
                TweenService:Create(MPrompt.Title, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0.3}):Play()
            end

            for _, TopbarButton in ipairs(Topbar:GetChildren())do
                if TopbarButton.ClassName == 'ImageButton' then
                    TweenService:Create(TopbarButton, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
                end
            end
            for _, tabbtn in ipairs(TabList:GetChildren())do
                if tabbtn.ClassName == 'Frame' and tabbtn.Name ~= 'Placeholder' then
                    TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
                    TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                    TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
                    TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                end
            end

            dragInteract.Visible = false

            for _, tab in ipairs(Elements:GetChildren())do
                if tab.Name ~= 'Template' and tab.ClassName == 'ScrollingFrame' and tab.Name ~= 'Placeholder' then
                    for _, element in ipairs(tab:GetChildren())do
                        if element.ClassName == 'Frame' then
                            if element.Name ~= 'SectionSpacing' and element.Name ~= 'Placeholder' then
                                if element.Name == 'SectionTitle' or element.Name == 'SearchTitle-fsefsefesfsefesfesfThanks' then
                                    TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                                elseif element.Name == 'Divider' then
                                    TweenService:Create(element.Divider, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
                                else
                                    TweenService:Create(element, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
                                    TweenService:Create(element.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                                    TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                                end

                                for _, child in ipairs(element:GetChildren())do
                                    if child.ClassName == 'Frame' or child.ClassName == 'TextLabel' or child.ClassName == 'TextBox' or child.ClassName == 'ImageButton' or child.ClassName == 'ImageLabel' then
                                        child.Visible = false
                                    end
                                end
                            end
                        end
                    end
                end
            end

            task.wait(0.5)

            Main.Visible = false
            Debounce = false
        end
        local Maximise = function()
            Debounce = true
            Topbar.ChangeSize.Image = 'rbxassetid://10137941941'

            TweenService:Create(Topbar.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
            TweenService:Create(Main.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 0.6}):Play()
            TweenService:Create(Topbar.CornerRepair, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
            TweenService:Create(Topbar.Divider, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
            TweenService:Create(dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0.7}):Play()
            TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {
                Size = useMobileSizing and UDim2.new(0, 500, 0, 275) or UDim2.new(0, 500, 0, 475),
            }):Play()
            TweenService:Create(Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {
                Size = UDim2.new(0, 500, 0, 45),
            }):Play()

            TabList.Visible = true

            task.wait(0.2)

            Elements.Visible = true

            for _, tab in ipairs(Elements:GetChildren())do
                if tab.Name ~= 'Template' and tab.ClassName == 'ScrollingFrame' and tab.Name ~= 'Placeholder' then
                    for _, element in ipairs(tab:GetChildren())do
                        if element.ClassName == 'Frame' then
                            if element.Name ~= 'SectionSpacing' and element.Name ~= 'Placeholder' then
                                if element.Name == 'SectionTitle' or element.Name == 'SearchTitle-fsefsefesfsefesfesfThanks' then
                                    TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0.4}):Play()
                                elseif element.Name == 'Divider' then
                                    TweenService:Create(element.Divider, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.85}):Play()
                                else
                                    TweenService:Create(element, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
                                    TweenService:Create(element.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                                    TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
                                end

                                for _, child in ipairs(element:GetChildren())do
                                    if child.ClassName == 'Frame' or child.ClassName == 'TextLabel' or child.ClassName == 'TextBox' or child.ClassName == 'ImageButton' or child.ClassName == 'ImageLabel' then
                                        child.Visible = true
                                    end
                                end
                            end
                        end
                    end
                end
            end

            task.wait(0.1)

            for _, tabbtn in ipairs(TabList:GetChildren())do
                if tabbtn.ClassName == 'Frame' and tabbtn.Name ~= 'Placeholder' then
                    if tostring(Elements.UIPageLayout.CurrentPage) == tabbtn.Title.Text then
                        TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
                        TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
                        TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
                        TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                    else
                        TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.7}):Play()
                        TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0.2}):Play()
                        TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0.2}):Play()
                        TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 0.5}):Play()
                    end
                end
            end

            task.wait(0.5)

            Debounce = false
        end
        local Unhide = function()
            Debounce = true
            Main.Position = UDim2.new(0.5, 0, 0.5, 0)
            Main.Visible = true

            TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {
                Size = useMobileSizing and UDim2.new(0, 500, 0, 275) or UDim2.new(0, 500, 0, 475),
            }):Play()
            TweenService:Create(Main.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {
                Size = UDim2.new(0, 500, 0, 45),
            }):Play()
            TweenService:Create(Main.Shadow.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.6}):Play()
            TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
            TweenService:Create(Main.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
            TweenService:Create(Main.Topbar.Divider, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
            TweenService:Create(Main.Topbar.CornerRepair, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
            TweenService:Create(Main.Topbar.Title, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()

            if MPrompt then
                TweenService:Create(MPrompt, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {
                    Size = UDim2.new(0, 40, 0, 10),
                    Position = UDim2.new(0.5, 0, 0, -50),
                    BackgroundTransparency = 1,
                }):Play()
                TweenService:Create(MPrompt.Title, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                task.spawn(function()
                    task.wait(0.5)

                    MPrompt.Visible = false
                end)
            end
            if Minimised then
                task.spawn(Maximise)
            end

            dragBar.Position = useMobileSizing and UDim2.new(0.5, 0, 0.5, dragOffsetMobile) or UDim2.new(0.5, 0, 0.5, dragOffset)
            dragInteract.Visible = true

            for _, TopbarButton in ipairs(Topbar:GetChildren())do
                if TopbarButton.ClassName == 'ImageButton' then
                    if TopbarButton.Name == 'Icon' then
                        TweenService:Create(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
                    else
                        TweenService:Create(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.8}):Play()
                    end
                end
            end
            for _, tabbtn in ipairs(TabList:GetChildren())do
                if tabbtn.ClassName == 'Frame' and tabbtn.Name ~= 'Placeholder' then
                    if tostring(Elements.UIPageLayout.CurrentPage) == tabbtn.Title.Text then
                        TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
                        TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
                        TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
                        TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                    else
                        TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.7}):Play()
                        TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0.2}):Play()
                        TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0.2}):Play()
                        TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 0.5}):Play()
                    end
                end
            end
            for _, tab in ipairs(Elements:GetChildren())do
                if tab.Name ~= 'Template' and tab.ClassName == 'ScrollingFrame' and tab.Name ~= 'Placeholder' then
                    for _, element in ipairs(tab:GetChildren())do
                        if element.ClassName == 'Frame' then
                            if element.Name ~= 'SectionSpacing' and element.Name ~= 'Placeholder' then
                                if element.Name == 'SectionTitle' or element.Name == 'SearchTitle-fsefsefesfsefesfesfThanks' then
                                    TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0.4}):Play()
                                elseif element.Name == 'Divider' then
                                    TweenService:Create(element.Divider, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.85}):Play()
                                else
                                    TweenService:Create(element, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
                                    TweenService:Create(element.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                                    TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
                                end

                                for _, child in ipairs(element:GetChildren())do
                                    if child.ClassName == 'Frame' or child.ClassName == 'TextLabel' or child.ClassName == 'TextBox' or child.ClassName == 'ImageButton' or child.ClassName == 'ImageLabel' then
                                        child.Visible = true
                                    end
                                end
                            end
                        end
                    end
                end
            end

            TweenService:Create(dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0.5}):Play()
            task.wait(0.5)

            Minimised = false
            Debounce = false
        end
        local Minimise = function()
            Debounce = true
            Topbar.ChangeSize.Image = 'rbxassetid://11036884234'
            Topbar.UIStroke.Color = SelectedTheme.ElementStroke

            task.spawn(closeSearch)

            for _, tabbtn in ipairs(TabList:GetChildren())do
                if tabbtn.ClassName == 'Frame' and tabbtn.Name ~= 'Placeholder' then
                    TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
                    TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
                    TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                    TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                end
            end
            for _, tab in ipairs(Elements:GetChildren())do
                if tab.Name ~= 'Template' and tab.ClassName == 'ScrollingFrame' and tab.Name ~= 'Placeholder' then
                    for _, element in ipairs(tab:GetChildren())do
                        if element.ClassName == 'Frame' then
                            if element.Name ~= 'SectionSpacing' and element.Name ~= 'Placeholder' then
                                if element.Name == 'SectionTitle' or element.Name == 'SearchTitle-fsefsefesfsefesfesfThanks' then
                                    TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                                elseif element.Name == 'Divider' then
                                    TweenService:Create(element.Divider, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
                                else
                                    TweenService:Create(element, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
                                    TweenService:Create(element.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                                    TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                                end

                                for _, child in ipairs(element:GetChildren())do
                                    if child.ClassName == 'Frame' or child.ClassName == 'TextLabel' or child.ClassName == 'TextBox' or child.ClassName == 'ImageButton' or child.ClassName == 'ImageLabel' then
                                        child.Visible = false
                                    end
                                end
                            end
                        end
                    end
                end
            end

            TweenService:Create(dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
            TweenService:Create(Topbar.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
            TweenService:Create(Main.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
            TweenService:Create(Topbar.CornerRepair, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
            TweenService:Create(Topbar.Divider, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
            TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {
                Size = UDim2.new(0, 495, 0, 45),
            }):Play()
            TweenService:Create(Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {
                Size = UDim2.new(0, 495, 0, 45),
            }):Play()
            task.wait(0.3)

            Elements.Visible = false
            TabList.Visible = false

            task.wait(0.2)

            Debounce = false
        end
        local saveSettings = function()
            local encoded
            local success, err = pcall(function()
                encoded = HttpService:JSONEncode(settingsTable)
            end)

            if success then
                if useStudio then
                    if script.Parent['get.val'] then
                        script.Parent['get.val'].Value = encoded
                    end
                end
                if writefile then
                    writefile(RayfieldFolder .. '/settings' .. ConfigurationExtension, encoded)
                end
            end
        end
        local updateSetting = function(category, setting, value)
            if not settingsInitialized then
                return
            end

            settingsTable[category][setting].Value = value
            overriddenSettings[string.format('%s.%s', tostring(category), tostring(setting))] = nil

            saveSettings()
        end
        local createSettings = function(window)
            if not (writefile and isfile and readfile and isfolder and makefolder) and not useStudio then
                if Topbar['Settings'] then
                    Topbar.Settings.Visible = false
                end

                Topbar['Search'].Position = UDim2.new(1, -75, 0.5, 0)

                warn(
[[Can't create settings as no file-saving functionality is available.]])

                return
            end

            local newTab = window:CreateTab('Rayfield Settings', 0, true)

            if TabList['Rayfield Settings'] then
                TabList['Rayfield Settings'].LayoutOrder = 1000
            end
            if Elements['Rayfield Settings'] then
                Elements['Rayfield Settings'].LayoutOrder = 1000
            end

            for categoryName, settingCategory in pairs(settingsTable)do
                newTab:CreateSection(categoryName)

                for settingName, setting in pairs(settingCategory)do
                    if setting.Type == 'input' then
                        setting.Element = newTab:CreateInput({
                            Name = setting.Name,
                            CurrentValue = setting.Value,
                            PlaceholderText = setting.Placeholder,
                            Ext = true,
                            RemoveTextAfterFocusLost = setting.ClearOnFocus,
                            Callback = function(Value)
                                updateSetting(categoryName, settingName, Value)
                            end,
                        })
                    elseif setting.Type == 'toggle' then
                        setting.Element = newTab:CreateToggle({
                            Name = setting.Name,
                            CurrentValue = setting.Value,
                            Ext = true,
                            Callback = function(Value)
                                updateSetting(categoryName, settingName, Value)
                            end,
                        })
                    elseif setting.Type == 'bind' then
                        setting.Element = newTab:CreateKeybind({
                            Name = setting.Name,
                            CurrentKeybind = setting.Value,
                            HoldToInteract = false,
                            Ext = true,
                            CallOnChange = true,
                            Callback = function(Value)
                                updateSetting(categoryName, settingName, Value)
                            end,
                        })
                    end
                end
            end

            settingsCreated = true

            loadSettings()
            saveSettings()
        end

        function RayfieldLibrary:CreateWindow(Settings)
            print('creating window')

            if Rayfield:FindFirstChild('Loading') then
                if getgenv and not getgenv().rayfieldCached then
                    Rayfield.Enabled = true
                    Rayfield.Loading.Visible = true

                    task.wait(1.4)

                    Rayfield.Loading.Visible = false
                end
            end
            if getgenv then
                getgenv().rayfieldCached = true
            end
            if not correctBuild and not Settings.DisableBuildWarnings then
                task.delay(3, function()
                    RayfieldLibrary:Notify({
                        Title = 'Build Mismatch',
                        Content = 
[[Rayfield may encounter issues as you are running an incompatible interface version (]] .. ((Rayfield:FindFirstChild('Build') and Rayfield.Build.Value) or 'No Build') .. 
[[).

This version of Rayfield is intended for interface build ]] .. InterfaceBuild .. '.\n\nTry rejoining and then run the script twice.',
                        Image = 4335487866,
                        Duration = 15,
                    })
                end)
            end
            if Settings.ToggleUIKeybind then
                local keybind = Settings.ToggleUIKeybind

                if type(keybind) == 'string' then
                    keybind = string.upper(keybind)

                    assert(pcall(function()
                        return Enum.KeyCode[keybind]
                    end), 'ToggleUIKeybind must be a valid KeyCode')
                    overrideSetting('General', 'rayfieldOpen', keybind)
                elseif typeof(keybind) == 'EnumItem' then
                    assert(keybind.EnumType == Enum.KeyCode, 'ToggleUIKeybind must be a KeyCode enum')
                    overrideSetting('General', 'rayfieldOpen', keybind.Name)
                else
                    error('ToggleUIKeybind must be a string or KeyCode enum')
                end
            end
            if isfolder and not isfolder(RayfieldFolder) then
                makefolder(RayfieldFolder)
            end
            if not requestsDisabled then
                sendReport('window_created', Settings.Name or 'Unknown')
            end

            local Passthrough = false

            Topbar.Title.Text = Settings.Name
            Main.Size = UDim2.new(0, 420, 0, 100)
            Main.Visible = true
            Main.BackgroundTransparency = 1

            if Main:FindFirstChild('Notice') then
                Main.Notice.Visible = false
            end

            Main.Shadow.Image.ImageTransparency = 1
            LoadingFrame.Title.TextTransparency = 1
            LoadingFrame.Subtitle.TextTransparency = 1

            if Settings.ShowText then
                MPrompt.Title.Text = 'Show ' .. Settings.ShowText
            end

            LoadingFrame.Version.TextTransparency = 1
            LoadingFrame.Title.Text = Settings.LoadingTitle or 'Rayfield'
            LoadingFrame.Subtitle.Text = Settings.LoadingSubtitle or 'Interface Suite'

            if Settings.LoadingTitle ~= 'Rayfield Interface Suite' then
                LoadingFrame.Version.Text = 'Rayfield UI'
            end
            if Settings.Icon and Settings.Icon ~= 0 and Topbar:FindFirstChild('Icon') then
                Topbar.Icon.Visible = true
                Topbar.Title.Position = UDim2.new(0, 47, 0.5, 0)

                if Settings.Icon then
                    if typeof(Settings.Icon) == 'string' and Icons then
                        local asset = getIcon(Settings.Icon)

                        Topbar.Icon.Image = 'rbxassetid://' .. asset.id
                        Topbar.Icon.ImageRectOffset = asset.imageRectOffset
                        Topbar.Icon.ImageRectSize = asset.imageRectSize
                    else
                        Topbar.Icon.Image = getAssetUri(Settings.Icon)
                    end
                else
                    Topbar.Icon.Image = 'rbxassetid://0'
                end
            end
            if dragBar then
                dragBar.Visible = false
                dragBarCosmetic.BackgroundTransparency = 1
                dragBar.Visible = true
            end
            if Settings.Theme then
                local success, result = pcall(ChangeTheme, Settings.Theme)

                if not success then
                    local success, result2 = pcall(ChangeTheme, 'Default')

                    if not success then
                        warn('CRITICAL ERROR - NO DEFAULT THEME')
                        print(result2)
                    end

                    warn('issue rendering theme. no theme on file')
                    print(result)
                end
            end

            Topbar.Visible = false
            Elements.Visible = false
            LoadingFrame.Visible = true

            if not Settings.DisableRayfieldPrompts then
                task.spawn(function()
                    while true do
                        task.wait(math.random(180, 600))
                        RayfieldLibrary:Notify({
                            Title = 'Rayfield Interface',
                            Content = 'Enjoying this UI library? Find it at sirius.menu/discord',
                            Duration = 7,
                            Image = 4370033185,
                        })
                    end
                end)
            end

            pcall(function()
                if not Settings.ConfigurationSaving.FileName then
                    Settings.ConfigurationSaving.FileName = tostring(game.PlaceId)
                end
                if Settings.ConfigurationSaving.Enabled == nil then
                    Settings.ConfigurationSaving.Enabled = false
                end

                CFileName = Settings.ConfigurationSaving.FileName
                ConfigurationFolder = Settings.ConfigurationSaving.FolderName or ConfigurationFolder
                CEnabled = Settings.ConfigurationSaving.Enabled

                if Settings.ConfigurationSaving.Enabled then
                    if not isfolder(ConfigurationFolder) then
                        makefolder(ConfigurationFolder)
                    end
                end
            end)
            makeDraggable(Main, Topbar, false, {dragOffset, dragOffsetMobile})

            if dragBar then
                dragBar.Position = useMobileSizing and UDim2.new(0.5, 0, 0.5, dragOffsetMobile) or UDim2.new(0.5, 0, 0.5, dragOffset)

                makeDraggable(Main, dragInteract, true, {dragOffset, dragOffsetMobile})
            end

            for _, TabButton in ipairs(TabList:GetChildren())do
                if TabButton.ClassName == 'Frame' and TabButton.Name ~= 'Placeholder' then
                    TabButton.BackgroundTransparency = 1
                    TabButton.Title.TextTransparency = 1
                    TabButton.Image.ImageTransparency = 1
                    TabButton.UIStroke.Transparency = 1
                end
            end

            if Settings.Discord and Settings.Discord.Enabled and not useStudio then
                if isfolder and not isfolder(RayfieldFolder .. '/Discord Invites') then
                    makefolder(RayfieldFolder .. '/Discord Invites')
                end
                if isfile and not isfile(RayfieldFolder .. '/Discord Invites' .. '/' .. Settings.Discord.Invite .. ConfigurationExtension) then
                    if requestFunc then
                        pcall(function()
                            requestFunc({
                                Url = 'http://127.0.0.1:6463/rpc?v=1',
                                Method = 'POST',
                                Headers = {
                                    ['Content-Type'] = 'application/json',
                                    Origin = 'https://discord.com',
                                },
                                Body = HttpService:JSONEncode({
                                    cmd = 'INVITE_BROWSER',
                                    nonce = HttpService:GenerateGUID(false),
                                    args = {
                                        code = Settings.Discord.Invite,
                                    },
                                }),
                            })
                        end)
                    end
                    if Settings.Discord.RememberJoins then
                        writefile(RayfieldFolder .. '/Discord Invites' .. '/' .. Settings.Discord.Invite .. ConfigurationExtension, 
[[Rayfield RememberJoins is true for this invite, this invite will not ask you to join again]])
                    end
                end
            end
            if Settings.KeySystem then
                if not Settings.KeySettings then
                    Passthrough = true

                    return
                end
                if isfolder and not isfolder(RayfieldFolder .. '/Key System') then
                    makefolder(RayfieldFolder .. '/Key System')
                end
                if typeof(Settings.KeySettings.Key) == 'string' then
                    Settings.KeySettings.Key = {
                        Settings.KeySettings.Key,
                    }
                end
                if Settings.KeySettings.GrabKeyFromSite then
                    for i, Key in ipairs(Settings.KeySettings.Key)do
                        local Success, Response = pcall(function()
                            Settings.KeySettings.Key[i] = tostring(game:HttpGet(Key):gsub('[\n\r]', ' '))
                            Settings.KeySettings.Key[i] = string.gsub(Settings.KeySettings.Key[i], ' ', '')
                        end)

                        if not Success then
                            print('Rayfield | ' .. Key .. ' Error ' .. tostring(Response))
                            warn(
[[Check docs.sirius.menu for help with Rayfield specific development.]])
                        end
                    end
                end
                if not Settings.KeySettings.FileName then
                    Settings.KeySettings.FileName = 'No file name specified'
                end
                if isfile and isfile(RayfieldFolder .. '/Key System' .. '/' .. Settings.KeySettings.FileName .. ConfigurationExtension) then
                    for _, MKey in ipairs(Settings.KeySettings.Key)do
                        if string.find(readfile(RayfieldFolder .. '/Key System' .. '/' .. Settings.KeySettings.FileName .. ConfigurationExtension), MKey) then
                            Passthrough = true
                        end
                    end
                end
                if not Passthrough then
                    local AttemptsRemaining = math.random(2, 5)

                    Rayfield.Enabled = false

                    local KeyUI = useStudio and script.Parent:FindFirstChild('Key') or game:GetObjects('rbxassetid://11380036235')[1]

                    KeyUI.Enabled = true

                    if gethui then
                        KeyUI.Parent = gethui()
                    elseif syn and syn.protect_gui then
                        syn.protect_gui(KeyUI)

                        KeyUI.Parent = CoreGui
                    elseif not useStudio and CoreGui:FindFirstChild('RobloxGui') then
                        KeyUI.Parent = CoreGui:FindFirstChild('RobloxGui')
                    elseif not useStudio then
                        KeyUI.Parent = CoreGui
                    end
                    if gethui then
                        for _, Interface in ipairs(gethui():GetChildren())do
                            if Interface.Name == KeyUI.Name and Interface ~= KeyUI then
                                Interface.Enabled = false
                                Interface.Name = 'KeyUI-Old'
                            end
                        end
                    elseif not useStudio then
                        for _, Interface in ipairs(CoreGui:GetChildren())do
                            if Interface.Name == KeyUI.Name and Interface ~= KeyUI then
                                Interface.Enabled = false
                                Interface.Name = 'KeyUI-Old'
                            end
                        end
                    end

                    local KeyMain = KeyUI.Main

                    KeyMain.Title.Text = Settings.KeySettings.Title or Settings.Name
                    KeyMain.Subtitle.Text = Settings.KeySettings.Subtitle or 'Key System'
                    KeyMain.NoteMessage.Text = Settings.KeySettings.Note or 'No instructions'
                    KeyMain.Size = UDim2.new(0, 467, 0, 175)
                    KeyMain.BackgroundTransparency = 1
                    KeyMain.Shadow.Image.ImageTransparency = 1
                    KeyMain.Title.TextTransparency = 1
                    KeyMain.Subtitle.TextTransparency = 1
                    KeyMain.KeyNote.TextTransparency = 1
                    KeyMain.Input.BackgroundTransparency = 1
                    KeyMain.Input.UIStroke.Transparency = 1
                    KeyMain.Input.InputBox.TextTransparency = 1
                    KeyMain.NoteTitle.TextTransparency = 1
                    KeyMain.NoteMessage.TextTransparency = 1
                    KeyMain.Hide.ImageTransparency = 1

                    TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
                    TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                        Size = UDim2.new(0, 500, 0, 187),
                    }):Play()
                    TweenService:Create(KeyMain.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 0.5}):Play()
                    task.wait(0.05)
                    TweenService:Create(KeyMain.Title, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
                    TweenService:Create(KeyMain.Subtitle, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
                    task.wait(0.05)
                    TweenService:Create(KeyMain.KeyNote, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
                    TweenService:Create(KeyMain.Input, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
                    TweenService:Create(KeyMain.Input.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                    TweenService:Create(KeyMain.Input.InputBox, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
                    task.wait(0.05)
                    TweenService:Create(KeyMain.NoteTitle, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
                    TweenService:Create(KeyMain.NoteMessage, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
                    task.wait(0.15)
                    TweenService:Create(KeyMain.Hide, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {ImageTransparency = 0.3}):Play()
                    KeyUI.Main.Input.InputBox.FocusLost:Connect(function()
                        if #KeyUI.Main.Input.InputBox.Text == 0 then
                            return
                        end

                        local KeyFound = false
                        local FoundKey = ''

                        for _, MKey in ipairs(Settings.KeySettings.Key)do
                            if KeyMain.Input.InputBox.Text == MKey then
                                KeyFound = true
                                FoundKey = MKey
                            end
                        end

                        if KeyFound then
                            TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
                            TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                Size = UDim2.new(0, 467, 0, 175),
                            }):Play()
                            TweenService:Create(KeyMain.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
                            TweenService:Create(KeyMain.Title, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                            TweenService:Create(KeyMain.Subtitle, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                            TweenService:Create(KeyMain.KeyNote, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                            TweenService:Create(KeyMain.Input, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
                            TweenService:Create(KeyMain.Input.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                            TweenService:Create(KeyMain.Input.InputBox, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                            TweenService:Create(KeyMain.NoteTitle, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                            TweenService:Create(KeyMain.NoteMessage, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                            TweenService:Create(KeyMain.Hide, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
                            task.wait(0.51)

                            Passthrough = true
                            KeyMain.Visible = false

                            if Settings.KeySettings.SaveKey then
                                if writefile then
                                    writefile(RayfieldFolder .. '/Key System' .. '/' .. Settings.KeySettings.FileName .. ConfigurationExtension, FoundKey)
                                end

                                RayfieldLibrary:Notify({
                                    Title = 'Key System',
                                    Content = 'The key for this script has been saved successfully.',
                                    Image = 3605522284,
                                })
                            end
                        else
                            if AttemptsRemaining == 0 then
                                TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
                                TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                    Size = UDim2.new(0, 467, 0, 175),
                                }):Play()
                                TweenService:Create(KeyMain.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
                                TweenService:Create(KeyMain.Title, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                                TweenService:Create(KeyMain.Subtitle, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                                TweenService:Create(KeyMain.KeyNote, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                                TweenService:Create(KeyMain.Input, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
                                TweenService:Create(KeyMain.Input.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                                TweenService:Create(KeyMain.Input.InputBox, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                                TweenService:Create(KeyMain.NoteTitle, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                                TweenService:Create(KeyMain.NoteMessage, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                                TweenService:Create(KeyMain.Hide, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
                                task.wait(0.45)
                                Players.LocalPlayer:Kick('No Attempts Remaining')
                                game:Shutdown()
                            end

                            KeyMain.Input.InputBox.Text = ''
                            AttemptsRemaining = AttemptsRemaining - 1

                            TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                Size = UDim2.new(0, 467, 0, 175),
                            }):Play()
                            TweenService:Create(KeyMain, TweenInfo.new(0.4, Enum.EasingStyle.Elastic), {
                                Position = UDim2.new(0.495, 0, 0.5, 0),
                            }):Play()
                            task.wait(0.1)
                            TweenService:Create(KeyMain, TweenInfo.new(0.4, Enum.EasingStyle.Elastic), {
                                Position = UDim2.new(0.505, 0, 0.5, 0),
                            }):Play()
                            task.wait(0.1)
                            TweenService:Create(KeyMain, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
                                Position = UDim2.new(0.5, 0, 0.5, 0),
                            }):Play()
                            TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                Size = UDim2.new(0, 500, 0, 187),
                            }):Play()
                        end
                    end)
                    KeyMain.Hide.MouseButton1Click:Connect(function()
                        TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
                        TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                            Size = UDim2.new(0, 467, 0, 175),
                        }):Play()
                        TweenService:Create(KeyMain.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
                        TweenService:Create(KeyMain.Title, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                        TweenService:Create(KeyMain.Subtitle, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                        TweenService:Create(KeyMain.KeyNote, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                        TweenService:Create(KeyMain.Input, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
                        TweenService:Create(KeyMain.Input.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                        TweenService:Create(KeyMain.Input.InputBox, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                        TweenService:Create(KeyMain.NoteTitle, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                        TweenService:Create(KeyMain.NoteMessage, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                        TweenService:Create(KeyMain.Hide, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
                        task.wait(0.51)
                        RayfieldLibrary:Destroy()
                        KeyUI:Destroy()
                    end)
                else
                    Passthrough = true
                end
            end
            if Settings.KeySystem then
                repeat
                    task.wait()
                until Passthrough
            end

            Notifications.Template.Visible = false
            Notifications.Visible = true
            Rayfield.Enabled = true

            task.wait(0.5)
            TweenService:Create(Main, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
            TweenService:Create(Main.Shadow.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.6}):Play()
            task.wait(0.1)
            TweenService:Create(LoadingFrame.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
            task.wait(0.05)
            TweenService:Create(LoadingFrame.Subtitle, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
            task.wait(0.05)
            TweenService:Create(LoadingFrame.Version, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()

            Elements.Template.LayoutOrder = 100000
            Elements.Template.Visible = false
            Elements.UIPageLayout.FillDirection = Enum.FillDirection.Horizontal
            TabList.Template.Visible = false

            local FirstTab = false
            local Window = {}

            function Window:CreateTab(Name, Image, Ext)
                local SDone = false
                local TabButton = TabList.Template:Clone()

                TabButton.Name = Name
                TabButton.Title.Text = Name
                TabButton.Parent = TabList
                TabButton.Title.TextWrapped = false
                TabButton.Size = UDim2.new(0, TabButton.Title.TextBounds.X + 30, 0, 30)

                if Image and Image ~= 0 then
                    if typeof(Image) == 'string' and Icons then
                        local asset = getIcon(Image)

                        TabButton.Image.Image = 'rbxassetid://' .. asset.id
                        TabButton.Image.ImageRectOffset = asset.imageRectOffset
                        TabButton.Image.ImageRectSize = asset.imageRectSize
                    else
                        TabButton.Image.Image = getAssetUri(Image)
                    end

                    TabButton.Title.AnchorPoint = Vector2.new(0, 0.5)
                    TabButton.Title.Position = UDim2.new(0, 37, 0.5, 0)
                    TabButton.Image.Visible = true
                    TabButton.Title.TextXAlignment = Enum.TextXAlignment.Left
                    TabButton.Size = UDim2.new(0, TabButton.Title.TextBounds.X + 52, 0, 30)
                end

                TabButton.BackgroundTransparency = 1
                TabButton.Title.TextTransparency = 1
                TabButton.Image.ImageTransparency = 1
                TabButton.UIStroke.Transparency = 1
                TabButton.Visible = not Ext or false

                local TabPage = Elements.Template:Clone()

                TabPage.Name = Name
                TabPage.Visible = true
                TabPage.LayoutOrder = #Elements:GetChildren() or Ext and 10000

                for _, TemplateElement in ipairs(TabPage:GetChildren())do
                    if TemplateElement.ClassName == 'Frame' and TemplateElement.Name ~= 'Placeholder' then
                        TemplateElement:Destroy()
                    end
                end

                TabPage.Parent = Elements

                if not FirstTab and not Ext then
                    Elements.UIPageLayout.Animated = false

                    Elements.UIPageLayout:JumpTo(TabPage)

                    Elements.UIPageLayout.Animated = true
                end

                TabButton.UIStroke.Color = SelectedTheme.TabStroke

                if Elements.UIPageLayout.CurrentPage == TabPage then
                    TabButton.BackgroundColor3 = SelectedTheme.TabBackgroundSelected
                    TabButton.Image.ImageColor3 = SelectedTheme.SelectedTabTextColor
                    TabButton.Title.TextColor3 = SelectedTheme.SelectedTabTextColor
                else
                    TabButton.BackgroundColor3 = SelectedTheme.TabBackground
                    TabButton.Image.ImageColor3 = SelectedTheme.TabTextColor
                    TabButton.Title.TextColor3 = SelectedTheme.TabTextColor
                end

                task.wait(0.1)

                if FirstTab or Ext then
                    TabButton.BackgroundColor3 = SelectedTheme.TabBackground
                    TabButton.Image.ImageColor3 = SelectedTheme.TabTextColor
                    TabButton.Title.TextColor3 = SelectedTheme.TabTextColor

                    TweenService:Create(TabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.7}):Play()
                    TweenService:Create(TabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0.2}):Play()
                    TweenService:Create(TabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.2}):Play()
                    TweenService:Create(TabButton.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0.5}):Play()
                elseif not Ext then
                    FirstTab = Name
                    TabButton.BackgroundColor3 = SelectedTheme.TabBackgroundSelected
                    TabButton.Image.ImageColor3 = SelectedTheme.SelectedTabTextColor
                    TabButton.Title.TextColor3 = SelectedTheme.SelectedTabTextColor

                    TweenService:Create(TabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
                    TweenService:Create(TabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
                    TweenService:Create(TabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
                end

                TabButton.Interact.MouseButton1Click:Connect(function()
                    if Minimised then
                        return
                    end

                    TweenService:Create(TabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
                    TweenService:Create(TabButton.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                    TweenService:Create(TabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
                    TweenService:Create(TabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
                    TweenService:Create(TabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {
                        BackgroundColor3 = SelectedTheme.TabBackgroundSelected,
                    }):Play()
                    TweenService:Create(TabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {
                        TextColor3 = SelectedTheme.SelectedTabTextColor,
                    }):Play()
                    TweenService:Create(TabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {
                        ImageColor3 = SelectedTheme.SelectedTabTextColor,
                    }):Play()

                    for _, OtherTabButton in ipairs(TabList:GetChildren())do
                        if OtherTabButton.Name ~= 'Template' and OtherTabButton.ClassName == 'Frame' and OtherTabButton ~= TabButton and OtherTabButton.Name ~= 'Placeholder' then
                            TweenService:Create(OtherTabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = SelectedTheme.TabBackground,
                            }):Play()
                            TweenService:Create(OtherTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {
                                TextColor3 = SelectedTheme.TabTextColor,
                            }):Play()
                            TweenService:Create(OtherTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {
                                ImageColor3 = SelectedTheme.TabTextColor,
                            }):Play()
                            TweenService:Create(OtherTabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.7}):Play()
                            TweenService:Create(OtherTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0.2}):Play()
                            TweenService:Create(OtherTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.2}):Play()
                            TweenService:Create(OtherTabButton.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0.5}):Play()
                        end
                    end

                    if Elements.UIPageLayout.CurrentPage ~= TabPage then
                        Elements.UIPageLayout:JumpTo(TabPage)
                    end
                end)

                local Tab = {}

                function Tab:CreateButton(ButtonSettings)
                    local ButtonValue = {}
                    local Button = Elements.Template.Button:Clone()

                    Button.Name = ButtonSettings.Name
                    Button.Title.Text = ButtonSettings.Name
                    Button.Visible = true
                    Button.Parent = TabPage
                    Button.BackgroundTransparency = 1
                    Button.UIStroke.Transparency = 1
                    Button.Title.TextTransparency = 1

                    TweenService:Create(Button, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
                    TweenService:Create(Button.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                    TweenService:Create(Button.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
                    Button.Interact.MouseButton1Click:Connect(function()
                        local Success, Response = pcall(ButtonSettings.Callback)

                        if rayfieldDestroyed then
                            return
                        end
                        if not Success then
                            TweenService:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = Color3.fromRGB(85, 0, 0),
                            }):Play()
                            TweenService:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                            TweenService:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()

                            Button.Title.Text = 'Callback Error'

                            print('Rayfield | ' .. ButtonSettings.Name .. ' Callback Error ' .. tostring(Response))
                            warn(
[[Check docs.sirius.menu for help with Rayfield specific development.]])
                            task.wait(0.5)

                            Button.Title.Text = ButtonSettings.Name

                            TweenService:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = SelectedTheme.ElementBackground,
                            }):Play()
                            TweenService:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 0.9}):Play()
                            TweenService:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                        else
                            if not ButtonSettings.Ext then
                                SaveConfiguration()
                            end

                            TweenService:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = SelectedTheme.ElementBackgroundHover,
                            }):Play()
                            TweenService:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                            TweenService:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                            task.wait(0.2)
                            TweenService:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = SelectedTheme.ElementBackground,
                            }):Play()
                            TweenService:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 0.9}):Play()
                            TweenService:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                        end
                    end)
                    Button.MouseEnter:Connect(function()
                        TweenService:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                            BackgroundColor3 = SelectedTheme.ElementBackgroundHover,
                        }):Play()
                        TweenService:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 0.7}):Play()
                    end)
                    Button.MouseLeave:Connect(function()
                        TweenService:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                            BackgroundColor3 = SelectedTheme.ElementBackground,
                        }):Play()
                        TweenService:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 0.9}):Play()
                    end)

                    function ButtonValue:Set(NewButton)
                        Button.Title.Text = NewButton
                        Button.Name = NewButton
                    end

                    return ButtonValue
                end
                function Tab:CreateColorPicker(ColorPickerSettings)
                    ColorPickerSettings.Type = 'ColorPicker'

                    local ColorPicker = Elements.Template.ColorPicker:Clone()
                    local Background = ColorPicker.CPBackground
                    local Display = Background.Display
                    local Main = Background.MainCP
                    local Slider = ColorPicker.ColorSlider

                    ColorPicker.ClipsDescendants = true
                    ColorPicker.Name = ColorPickerSettings.Name
                    ColorPicker.Title.Text = ColorPickerSettings.Name
                    ColorPicker.Visible = true
                    ColorPicker.Parent = TabPage
                    ColorPicker.Size = UDim2.new(1, -10, 0, 45)
                    Background.Size = UDim2.new(0, 39, 0, 22)
                    Display.BackgroundTransparency = 0
                    Main.MainPoint.ImageTransparency = 1
                    ColorPicker.Interact.Size = UDim2.new(1, 0, 1, 0)
                    ColorPicker.Interact.Position = UDim2.new(0.5, 0, 0.5, 0)
                    ColorPicker.RGB.Position = UDim2.new(0, 17, 0, 70)
                    ColorPicker.HexInput.Position = UDim2.new(0, 17, 0, 90)
                    Main.ImageTransparency = 1
                    Background.BackgroundTransparency = 1

                    for _, rgbinput in ipairs(ColorPicker.RGB:GetChildren())do
                        if rgbinput:IsA('Frame') then
                            rgbinput.BackgroundColor3 = SelectedTheme.InputBackground
                            rgbinput.UIStroke.Color = SelectedTheme.InputStroke
                        end
                    end

                    ColorPicker.HexInput.BackgroundColor3 = SelectedTheme.InputBackground
                    ColorPicker.HexInput.UIStroke.Color = SelectedTheme.InputStroke

                    local opened = false
                    local mouse = Players.LocalPlayer:GetMouse()

                    Main.Image = 'http://www.roblox.com/asset/?id=11415645739'

                    local mainDragging = false
                    local sliderDragging = false

                    ColorPicker.Interact.MouseButton1Down:Connect(function()
                        task.spawn(function()
                            TweenService:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = SelectedTheme.ElementBackgroundHover,
                            }):Play()
                            TweenService:Create(ColorPicker.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                            task.wait(0.2)
                            TweenService:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = SelectedTheme.ElementBackground,
                            }):Play()
                            TweenService:Create(ColorPicker.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                        end)

                        if not opened then
                            opened = true

                            TweenService:Create(Background, TweenInfo.new(0.45, Enum.EasingStyle.Exponential), {
                                Size = UDim2.new(0, 18, 0, 15),
                            }):Play()
                            task.wait(0.1)
                            TweenService:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                Size = UDim2.new(1, -10, 0, 120),
                            }):Play()
                            TweenService:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                Size = UDim2.new(0, 173, 0, 86),
                            }):Play()
                            TweenService:Create(Display, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
                            TweenService:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                Position = UDim2.new(0.289, 0, 0.5, 0),
                            }):Play()
                            TweenService:Create(ColorPicker.RGB, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {
                                Position = UDim2.new(0, 17, 0, 40),
                            }):Play()
                            TweenService:Create(ColorPicker.HexInput, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {
                                Position = UDim2.new(0, 17, 0, 73),
                            }):Play()
                            TweenService:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                Size = UDim2.new(0.574, 0, 1, 0),
                            }):Play()
                            TweenService:Create(Main.MainPoint, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
                            TweenService:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {
                                ImageTransparency = SelectedTheme ~= RayfieldLibrary.Theme.Default and 0.25 or 0.1,
                            }):Play()
                            TweenService:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
                        else
                            opened = false

                            TweenService:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                Size = UDim2.new(1, -10, 0, 45),
                            }):Play()
                            TweenService:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                Size = UDim2.new(0, 39, 0, 22),
                            }):Play()
                            TweenService:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                Size = UDim2.new(1, 0, 1, 0),
                            }):Play()
                            TweenService:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                Position = UDim2.new(0.5, 0, 0.5, 0),
                            }):Play()
                            TweenService:Create(ColorPicker.RGB, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                Position = UDim2.new(0, 17, 0, 70),
                            }):Play()
                            TweenService:Create(ColorPicker.HexInput, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {
                                Position = UDim2.new(0, 17, 0, 90),
                            }):Play()
                            TweenService:Create(Display, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
                            TweenService:Create(Main.MainPoint, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
                            TweenService:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
                            TweenService:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
                        end
                    end)
                    UserInputService.InputEnded:Connect(function(
                        input,
                        gameProcessed
                    )
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                            mainDragging = false
                            sliderDragging = false
                        end
                    end)
                    Main.MouseButton1Down:Connect(function()
                        if opened then
                            mainDragging = true
                        end
                    end)
                    Main.MainPoint.MouseButton1Down:Connect(function()
                        if opened then
                            mainDragging = true
                        end
                    end)
                    Slider.MouseButton1Down:Connect(function()
                        sliderDragging = true
                    end)
                    Slider.SliderPoint.MouseButton1Down:Connect(function()
                        sliderDragging = true
                    end)

                    local h, s, v = ColorPickerSettings.Color:ToHSV()
                    local color = Color3.fromHSV(h, s, v)
                    local hex = string.format('#%02X%02X%02X', color.R * 0xff, color.G * 0xff, color.B * 0xff)

                    ColorPicker.HexInput.InputBox.Text = hex

                    local setDisplay = function()
                        Main.MainPoint.Position = UDim2.new(s, -Main.MainPoint.AbsoluteSize.X / 2, 1 - v, 
-Main.MainPoint.AbsoluteSize.Y / 2)
                        Main.MainPoint.ImageColor3 = Color3.fromHSV(h, s, v)
                        Background.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                        Display.BackgroundColor3 = Color3.fromHSV(h, s, v)

                        local x = h * Slider.AbsoluteSize.X

                        Slider.SliderPoint.Position = UDim2.new(0, x - Slider.SliderPoint.AbsoluteSize.X / 2, 0.5, 0)
                        Slider.SliderPoint.ImageColor3 = Color3.fromHSV(h, 1, 1)

                        local color = Color3.fromHSV(h, s, v)
                        local r, g, b = math.floor((color.R * 255) + 0.5), math.floor((color.G * 255) + 0.5), math.floor((color.B * 255) + 0.5)

                        ColorPicker.RGB.RInput.InputBox.Text = tostring(r)
                        ColorPicker.RGB.GInput.InputBox.Text = tostring(g)
                        ColorPicker.RGB.BInput.InputBox.Text = tostring(b)
                        hex = string.format('#%02X%02X%02X', color.R * 0xff, color.G * 0xff, color.B * 0xff)
                        ColorPicker.HexInput.InputBox.Text = hex
                    end

                    setDisplay()
                    ColorPicker.HexInput.InputBox.FocusLost:Connect(function()
                        if not pcall(function()
                            local r, g, b = string.match(ColorPicker.HexInput.InputBox.Text, '^#?(%w%w)(%w%w)(%w%w)$')
                            local rgbColor = Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))

                            h, s, v = rgbColor:ToHSV()
                            hex = ColorPicker.HexInput.InputBox.Text

                            setDisplay()

                            ColorPickerSettings.Color = rgbColor
                        end) then
                            ColorPicker.HexInput.InputBox.Text = hex
                        end

                        pcall(function()
                            ColorPickerSettings.Callback(Color3.fromHSV(h, s, v))
                        end)

                        local r, g, b = math.floor((h * 255) + 0.5), math.floor((s * 255) + 0.5), math.floor((v * 255) + 0.5)

                        ColorPickerSettings.Color = Color3.fromRGB(r, g, b)

                        if not ColorPickerSettings.Ext then
                            SaveConfiguration()
                        end
                    end)

                    local rgbBoxes = function(box, toChange)
                        local value = tonumber(box.Text)
                        local color = Color3.fromHSV(h, s, v)
                        local oldR, oldG, oldB = math.floor((color.R * 255) + 0.5), math.floor((color.G * 255) + 0.5), math.floor((color.B * 255) + 0.5)
                        local save

                        if toChange == 'R' then
                            save = oldR
                            oldR = value
                        elseif toChange == 'G' then
                            save = oldG
                            oldG = value
                        else
                            save = oldB
                            oldB = value
                        end
                        if value then
                            value = math.clamp(value, 0, 255)
                            h, s, v = Color3.fromRGB(oldR, oldG, oldB):ToHSV()

                            setDisplay()
                        else
                            box.Text = tostring(save)
                        end

                        local r, g, b = math.floor((h * 255) + 0.5), math.floor((s * 255) + 0.5), math.floor((v * 255) + 0.5)

                        ColorPickerSettings.Color = Color3.fromRGB(r, g, b)

                        if not ColorPickerSettings.Ext then
                            SaveConfiguration()
                        end
                    end

                    ColorPicker.RGB.RInput.InputBox.FocusLost:connect(function()
                        rgbBoxes(ColorPicker.RGB.RInput.InputBox, 'R')
                        pcall(function()
                            ColorPickerSettings.Callback(Color3.fromHSV(h, s, v))
                        end)
                    end)
                    ColorPicker.RGB.GInput.InputBox.FocusLost:connect(function()
                        rgbBoxes(ColorPicker.RGB.GInput.InputBox, 'G')
                        pcall(function()
                            ColorPickerSettings.Callback(Color3.fromHSV(h, s, v))
                        end)
                    end)
                    ColorPicker.RGB.BInput.InputBox.FocusLost:connect(function()
                        rgbBoxes(ColorPicker.RGB.BInput.InputBox, 'B')
                        pcall(function()
                            ColorPickerSettings.Callback(Color3.fromHSV(h, s, v))
                        end)
                    end)
                    RunService.RenderStepped:connect(function()
                        if mainDragging then
                            local localX = math.clamp(mouse.X - Main.AbsolutePosition.X, 0, Main.AbsoluteSize.X)
                            local localY = math.clamp(mouse.Y - Main.AbsolutePosition.Y, 0, Main.AbsoluteSize.Y)

                            Main.MainPoint.Position = UDim2.new(0, localX - Main.MainPoint.AbsoluteSize.X / 2, 0, localY - Main.MainPoint.AbsoluteSize.Y / 2)
                            s = localX / Main.AbsoluteSize.X
                            v = 1 - (localY / Main.AbsoluteSize.Y)
                            Display.BackgroundColor3 = Color3.fromHSV(h, s, v)
                            Main.MainPoint.ImageColor3 = Color3.fromHSV(h, s, v)
                            Background.BackgroundColor3 = Color3.fromHSV(h, 1, 1)

                            local color = Color3.fromHSV(h, s, v)
                            local r, g, b = math.floor((color.R * 255) + 0.5), math.floor((color.G * 255) + 0.5), math.floor((color.B * 255) + 0.5)

                            ColorPicker.RGB.RInput.InputBox.Text = tostring(r)
                            ColorPicker.RGB.GInput.InputBox.Text = tostring(g)
                            ColorPicker.RGB.BInput.InputBox.Text = tostring(b)
                            ColorPicker.HexInput.InputBox.Text = string.format('#%02X%02X%02X', color.R * 0xff, color.G * 0xff, color.B * 0xff)

                            pcall(function()
                                ColorPickerSettings.Callback(Color3.fromHSV(h, s, v))
                            end)

                            ColorPickerSettings.Color = Color3.fromRGB(r, g, b)

                            if not ColorPickerSettings.Ext then
                                SaveConfiguration()
                            end
                        end
                        if sliderDragging then
                            local localX = math.clamp(mouse.X - Slider.AbsolutePosition.X, 0, Slider.AbsoluteSize.X)

                            h = localX / Slider.AbsoluteSize.X
                            Display.BackgroundColor3 = Color3.fromHSV(h, s, v)
                            Slider.SliderPoint.Position = UDim2.new(0, localX - Slider.SliderPoint.AbsoluteSize.X / 2, 0.5, 0)
                            Slider.SliderPoint.ImageColor3 = Color3.fromHSV(h, 1, 1)
                            Background.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                            Main.MainPoint.ImageColor3 = Color3.fromHSV(h, s, v)

                            local color = Color3.fromHSV(h, s, v)
                            local r, g, b = math.floor((color.R * 255) + 0.5), math.floor((color.G * 255) + 0.5), math.floor((color.B * 255) + 0.5)

                            ColorPicker.RGB.RInput.InputBox.Text = tostring(r)
                            ColorPicker.RGB.GInput.InputBox.Text = tostring(g)
                            ColorPicker.RGB.BInput.InputBox.Text = tostring(b)
                            ColorPicker.HexInput.InputBox.Text = string.format('#%02X%02X%02X', color.R * 0xff, color.G * 0xff, color.B * 0xff)

                            pcall(function()
                                ColorPickerSettings.Callback(Color3.fromHSV(h, s, v))
                            end)

                            ColorPickerSettings.Color = Color3.fromRGB(r, g, b)

                            if not ColorPickerSettings.Ext then
                                SaveConfiguration()
                            end
                        end
                    end)

                    if Settings.ConfigurationSaving then
                        if Settings.ConfigurationSaving.Enabled and ColorPickerSettings.Flag then
                            RayfieldLibrary.Flags[ColorPickerSettings.Flag] = ColorPickerSettings
                        end
                    end

                    function ColorPickerSettings:Set(RGBColor)
                        ColorPickerSettings.Color = RGBColor
                        h, s, v = ColorPickerSettings.Color:ToHSV()
                        color = Color3.fromHSV(h, s, v)

                        setDisplay()
                    end

                    ColorPicker.MouseEnter:Connect(function()
                        TweenService:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                            BackgroundColor3 = SelectedTheme.ElementBackgroundHover,
                        }):Play()
                    end)
                    ColorPicker.MouseLeave:Connect(function()
                        TweenService:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                            BackgroundColor3 = SelectedTheme.ElementBackground,
                        }):Play()
                    end)
                    Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function(
                    )
                        for _, rgbinput in ipairs(ColorPicker.RGB:GetChildren())do
                            if rgbinput:IsA('Frame') then
                                rgbinput.BackgroundColor3 = SelectedTheme.InputBackground
                                rgbinput.UIStroke.Color = SelectedTheme.InputStroke
                            end
                        end

                        ColorPicker.HexInput.BackgroundColor3 = SelectedTheme.InputBackground
                        ColorPicker.HexInput.UIStroke.Color = SelectedTheme.InputStroke
                    end)

                    return ColorPickerSettings
                end
                function Tab:CreateSection(SectionName)
                    local SectionValue = {}

                    if SDone then
                        local SectionSpace = Elements.Template.SectionSpacing:Clone()

                        SectionSpace.Visible = true
                        SectionSpace.Parent = TabPage
                    end

                    local Section = Elements.Template.SectionTitle:Clone()

                    Section.Title.Text = SectionName
                    Section.Visible = true
                    Section.Parent = TabPage
                    Section.Title.TextTransparency = 1

                    TweenService:Create(Section.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0.4}):Play()

                    function SectionValue:Set(NewSection)
                        Section.Title.Text = NewSection
                    end

                    SDone = true

                    return SectionValue
                end
                function Tab:CreateDivider()
                    local DividerValue = {}
                    local Divider = Elements.Template.Divider:Clone()

                    Divider.Visible = true
                    Divider.Parent = TabPage
                    Divider.Divider.BackgroundTransparency = 1

                    TweenService:Create(Divider.Divider, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.85}):Play()

                    function DividerValue:Set(Value)
                        Divider.Visible = Value
                    end

                    return DividerValue
                end
                function Tab:CreateLabel(LabelText, Icon, Color, IgnoreTheme)
                    local LabelValue = {}
                    local Label = Elements.Template.Label:Clone()

                    Label.Title.Text = LabelText
                    Label.Visible = true
                    Label.Parent = TabPage
                    Label.BackgroundColor3 = Color or SelectedTheme.SecondaryElementBackground
                    Label.UIStroke.Color = Color or SelectedTheme.SecondaryElementStroke

                    if Icon then
                        if typeof(Icon) == 'string' and Icons then
                            local asset = getIcon(Icon)

                            Label.Icon.Image = 'rbxassetid://' .. asset.id
                            Label.Icon.ImageRectOffset = asset.imageRectOffset
                            Label.Icon.ImageRectSize = asset.imageRectSize
                        else
                            Label.Icon.Image = getAssetUri(Icon)
                        end
                    else
                        Label.Icon.Image = 'rbxassetid://0'
                    end
                    if Icon and Label:FindFirstChild('Icon') then
                        Label.Title.Position = UDim2.new(0, 45, 0.5, 0)
                        Label.Title.Size = UDim2.new(1, -100, 0, 14)

                        if Icon then
                            if typeof(Icon) == 'string' and Icons then
                                local asset = getIcon(Icon)

                                Label.Icon.Image = 'rbxassetid://' .. asset.id
                                Label.Icon.ImageRectOffset = asset.imageRectOffset
                                Label.Icon.ImageRectSize = asset.imageRectSize
                            else
                                Label.Icon.Image = getAssetUri(Icon)
                            end
                        else
                            Label.Icon.Image = 'rbxassetid://0'
                        end

                        Label.Icon.Visible = true
                    end

                    Label.Icon.ImageTransparency = 1
                    Label.BackgroundTransparency = 1
                    Label.UIStroke.Transparency = 1
                    Label.Title.TextTransparency = 1

                    TweenService:Create(Label, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {
                        BackgroundTransparency = Color and 0.8 or 0,
                    }):Play()
                    TweenService:Create(Label.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {
                        Transparency = Color and 0.7 or 0,
                    }):Play()
                    TweenService:Create(Label.Icon, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.2}):Play()
                    TweenService:Create(Label.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {
                        TextTransparency = Color and 0.2 or 0,
                    }):Play()

                    function LabelValue:Set(NewLabel, Icon, Color)
                        Label.Title.Text = NewLabel

                        if Color then
                            Label.BackgroundColor3 = Color or SelectedTheme.SecondaryElementBackground
                            Label.UIStroke.Color = Color or SelectedTheme.SecondaryElementStroke
                        end
                        if Icon and Label:FindFirstChild('Icon') then
                            Label.Title.Position = UDim2.new(0, 45, 0.5, 0)
                            Label.Title.Size = UDim2.new(1, -100, 0, 14)

                            if Icon then
                                if typeof(Icon) == 'string' and Icons then
                                    local asset = getIcon(Icon)

                                    Label.Icon.Image = 'rbxassetid://' .. asset.id
                                    Label.Icon.ImageRectOffset = asset.imageRectOffset
                                    Label.Icon.ImageRectSize = asset.imageRectSize
                                else
                                    Label.Icon.Image = getAssetUri(Icon)
                                end
                            else
                                Label.Icon.Image = 'rbxassetid://0'
                            end

                            Label.Icon.Visible = true
                        end
                    end

                    Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function(
                    )
                        Label.BackgroundColor3 = IgnoreTheme and (Color or Label.BackgroundColor3) or SelectedTheme.SecondaryElementBackground
                        Label.UIStroke.Color = IgnoreTheme and (Color or Label.BackgroundColor3) or SelectedTheme.SecondaryElementStroke
                    end)

                    return LabelValue
                end
                function Tab:CreateParagraph(ParagraphSettings)
                    local ParagraphValue = {}
                    local Paragraph = Elements.Template.Paragraph:Clone()

                    Paragraph.Title.Text = ParagraphSettings.Title
                    Paragraph.Content.Text = ParagraphSettings.Content
                    Paragraph.Visible = true
                    Paragraph.Parent = TabPage
                    Paragraph.BackgroundTransparency = 1
                    Paragraph.UIStroke.Transparency = 1
                    Paragraph.Title.TextTransparency = 1
                    Paragraph.Content.TextTransparency = 1
                    Paragraph.BackgroundColor3 = SelectedTheme.SecondaryElementBackground
                    Paragraph.UIStroke.Color = SelectedTheme.SecondaryElementStroke

                    TweenService:Create(Paragraph, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
                    TweenService:Create(Paragraph.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                    TweenService:Create(Paragraph.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
                    TweenService:Create(Paragraph.Content, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()

                    function ParagraphValue:Set(NewParagraphSettings)
                        Paragraph.Title.Text = NewParagraphSettings.Title
                        Paragraph.Content.Text = NewParagraphSettings.Content
                    end

                    Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function(
                    )
                        Paragraph.BackgroundColor3 = SelectedTheme.SecondaryElementBackground
                        Paragraph.UIStroke.Color = SelectedTheme.SecondaryElementStroke
                    end)

                    return ParagraphValue
                end
                function Tab:CreateInput(InputSettings)
                    local Input = Elements.Template.Input:Clone()

                    Input.Name = InputSettings.Name
                    Input.Title.Text = InputSettings.Name
                    Input.Visible = true
                    Input.Parent = TabPage
                    Input.BackgroundTransparency = 1
                    Input.UIStroke.Transparency = 1
                    Input.Title.TextTransparency = 1
                    Input.InputFrame.InputBox.Text = InputSettings.CurrentValue or ''
                    Input.InputFrame.BackgroundColor3 = SelectedTheme.InputBackground
                    Input.InputFrame.UIStroke.Color = SelectedTheme.InputStroke

                    TweenService:Create(Input, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
                    TweenService:Create(Input.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                    TweenService:Create(Input.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()

                    Input.InputFrame.InputBox.PlaceholderText = InputSettings.PlaceholderText
                    Input.InputFrame.Size = UDim2.new(0, Input.InputFrame.InputBox.TextBounds.X + 24, 0, 30)

                    Input.InputFrame.InputBox.FocusLost:Connect(function()
                        local Success, Response = pcall(function()
                            InputSettings.Callback(Input.InputFrame.InputBox.Text)

                            InputSettings.CurrentValue = Input.InputFrame.InputBox.Text
                        end)

                        if not Success then
                            TweenService:Create(Input, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = Color3.fromRGB(85, 0, 0),
                            }):Play()
                            TweenService:Create(Input.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()

                            Input.Title.Text = 'Callback Error'

                            print('Rayfield | ' .. InputSettings.Name .. ' Callback Error ' .. tostring(Response))
                            warn(
[[Check docs.sirius.menu for help with Rayfield specific development.]])
                            task.wait(0.5)

                            Input.Title.Text = InputSettings.Name

                            TweenService:Create(Input, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = SelectedTheme.ElementBackground,
                            }):Play()
                            TweenService:Create(Input.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                        end
                        if InputSettings.RemoveTextAfterFocusLost then
                            Input.InputFrame.InputBox.Text = ''
                        end
                        if not InputSettings.Ext then
                            SaveConfiguration()
                        end
                    end)
                    Input.MouseEnter:Connect(function()
                        TweenService:Create(Input, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                            BackgroundColor3 = SelectedTheme.ElementBackgroundHover,
                        }):Play()
                    end)
                    Input.MouseLeave:Connect(function()
                        TweenService:Create(Input, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                            BackgroundColor3 = SelectedTheme.ElementBackground,
                        }):Play()
                    end)
                    Input.InputFrame.InputBox:GetPropertyChangedSignal('Text'):Connect(function(
                    )
                        TweenService:Create(Input.InputFrame, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                            Size = UDim2.new(0, Input.InputFrame.InputBox.TextBounds.X + 24, 0, 30),
                        }):Play()
                    end)

                    function InputSettings:Set(text)
                        Input.InputFrame.InputBox.Text = text
                        InputSettings.CurrentValue = text

                        pcall(function()
                            InputSettings.Callback(text)
                        end)

                        if not InputSettings.Ext then
                            SaveConfiguration()
                        end
                    end

                    if Settings.ConfigurationSaving then
                        if Settings.ConfigurationSaving.Enabled and InputSettings.Flag then
                            RayfieldLibrary.Flags[InputSettings.Flag] = InputSettings
                        end
                    end

                    Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function(
                    )
                        Input.InputFrame.BackgroundColor3 = SelectedTheme.InputBackground
                        Input.InputFrame.UIStroke.Color = SelectedTheme.InputStroke
                    end)

                    return InputSettings
                end
                function Tab:CreateDropdown(DropdownSettings)
                    local Dropdown = Elements.Template.Dropdown:Clone()

                    if string.find(DropdownSettings.Name, 'closed') then
                        Dropdown.Name = 'Dropdown'
                    else
                        Dropdown.Name = DropdownSettings.Name
                    end

                    Dropdown.Title.Text = DropdownSettings.Name
                    Dropdown.Visible = true
                    Dropdown.Parent = TabPage
                    Dropdown.List.Visible = false

                    if DropdownSettings.CurrentOption then
                        if type(DropdownSettings.CurrentOption) == 'string' then
                            DropdownSettings.CurrentOption = {
                                DropdownSettings.CurrentOption,
                            }
                        end
                        if not DropdownSettings.MultipleOptions and type(DropdownSettings.CurrentOption) == 'table' then
                            DropdownSettings.CurrentOption = {
                                DropdownSettings.CurrentOption[1],
                            }
                        end
                    else
                        DropdownSettings.CurrentOption = {}
                    end
                    if DropdownSettings.MultipleOptions then
                        if DropdownSettings.CurrentOption and type(DropdownSettings.CurrentOption) == 'table' then
                            if #DropdownSettings.CurrentOption == 1 then
                                Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
                            elseif #DropdownSettings.CurrentOption == 0 then
                                Dropdown.Selected.Text = 'None'
                            else
                                Dropdown.Selected.Text = 'Various'
                            end
                        else
                            DropdownSettings.CurrentOption = {}
                            Dropdown.Selected.Text = 'None'
                        end
                    else
                        Dropdown.Selected.Text = DropdownSettings.CurrentOption[1] or 'None'
                    end

                    Dropdown.Toggle.ImageColor3 = SelectedTheme.TextColor

                    TweenService:Create(Dropdown, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
                        BackgroundColor3 = SelectedTheme.ElementBackground,
                    }):Play()

                    Dropdown.BackgroundTransparency = 1
                    Dropdown.UIStroke.Transparency = 1
                    Dropdown.Title.TextTransparency = 1
                    Dropdown.Size = UDim2.new(1, -10, 0, 45)

                    TweenService:Create(Dropdown, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
                    TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                    TweenService:Create(Dropdown.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()

                    for _, ununusedoption in ipairs(Dropdown.List:GetChildren())do
                        if ununusedoption.ClassName == 'Frame' and ununusedoption.Name ~= 'Placeholder' then
                            ununusedoption:Destroy()
                        end
                    end

                    Dropdown.Toggle.Rotation = 180

                    Dropdown.Interact.MouseButton1Click:Connect(function()
                        TweenService:Create(Dropdown, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
                            BackgroundColor3 = SelectedTheme.ElementBackgroundHover,
                        }):Play()
                        TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                        task.wait(0.1)
                        TweenService:Create(Dropdown, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
                            BackgroundColor3 = SelectedTheme.ElementBackground,
                        }):Play()
                        TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()

                        if Debounce then
                            return
                        end
                        if Dropdown.List.Visible then
                            Debounce = true

                            TweenService:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {
                                Size = UDim2.new(1, -10, 0, 45),
                            }):Play()

                            for _, DropdownOpt in ipairs(Dropdown.List:GetChildren())do
                                if DropdownOpt.ClassName == 'Frame' and DropdownOpt.Name ~= 'Placeholder' then
                                    TweenService:Create(DropdownOpt, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
                                    TweenService:Create(DropdownOpt.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                                    TweenService:Create(DropdownOpt.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                                end
                            end

                            TweenService:Create(Dropdown.List, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ScrollBarImageTransparency = 1}):Play()
                            TweenService:Create(Dropdown.Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Rotation = 180}):Play()
                            task.wait(0.35)

                            Dropdown.List.Visible = false
                            Debounce = false
                        else
                            TweenService:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {
                                Size = UDim2.new(1, -10, 0, 180),
                            }):Play()

                            Dropdown.List.Visible = true

                            TweenService:Create(Dropdown.List, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ScrollBarImageTransparency = 0.7}):Play()
                            TweenService:Create(Dropdown.Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Rotation = 0}):Play()

                            for _, DropdownOpt in ipairs(Dropdown.List:GetChildren())do
                                if DropdownOpt.ClassName == 'Frame' and DropdownOpt.Name ~= 'Placeholder' then
                                    if DropdownOpt.Name ~= Dropdown.Selected.Text then
                                        TweenService:Create(DropdownOpt.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                                    end

                                    TweenService:Create(DropdownOpt, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
                                    TweenService:Create(DropdownOpt.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
                                end
                            end
                        end
                    end)
                    Dropdown.MouseEnter:Connect(function()
                        if not Dropdown.List.Visible then
                            TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = SelectedTheme.ElementBackgroundHover,
                            }):Play()
                        end
                    end)
                    Dropdown.MouseLeave:Connect(function()
                        TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                            BackgroundColor3 = SelectedTheme.ElementBackground,
                        }):Play()
                    end)

                    local SetDropdownOptions = function()
                        for _, Option in ipairs(DropdownSettings.Options)do
                            local DropdownOption = Elements.Template.Dropdown.List.Template:Clone()

                            DropdownOption.Name = Option
                            DropdownOption.Title.Text = Option
                            DropdownOption.Parent = Dropdown.List
                            DropdownOption.Visible = true
                            DropdownOption.BackgroundTransparency = 1
                            DropdownOption.UIStroke.Transparency = 1
                            DropdownOption.Title.TextTransparency = 1
                            DropdownOption.Interact.ZIndex = 50

                            DropdownOption.Interact.MouseButton1Click:Connect(function(
                            )
                                if not DropdownSettings.MultipleOptions and table.find(DropdownSettings.CurrentOption, Option) then
                                    return
                                end
                                if table.find(DropdownSettings.CurrentOption, Option) then
                                    table.remove(DropdownSettings.CurrentOption, table.find(DropdownSettings.CurrentOption, Option))

                                    if DropdownSettings.MultipleOptions then
                                        if #DropdownSettings.CurrentOption == 1 then
                                            Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
                                        elseif #DropdownSettings.CurrentOption == 0 then
                                            Dropdown.Selected.Text = 'None'
                                        else
                                            Dropdown.Selected.Text = 'Various'
                                        end
                                    else
                                        Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
                                    end
                                else
                                    if not DropdownSettings.MultipleOptions then
                                        table.clear(DropdownSettings.CurrentOption)
                                    end

                                    table.insert(DropdownSettings.CurrentOption, Option)

                                    if DropdownSettings.MultipleOptions then
                                        if #DropdownSettings.CurrentOption == 1 then
                                            Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
                                        elseif #DropdownSettings.CurrentOption == 0 then
                                            Dropdown.Selected.Text = 'None'
                                        else
                                            Dropdown.Selected.Text = 'Various'
                                        end
                                    else
                                        Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
                                    end

                                    TweenService:Create(DropdownOption.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                                    TweenService:Create(DropdownOption, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {
                                        BackgroundColor3 = SelectedTheme.DropdownSelected,
                                    }):Play()

                                    Debounce = true
                                end

                                local Success, Response = pcall(function()
                                    DropdownSettings.Callback(DropdownSettings.CurrentOption)
                                end)

                                if not Success then
                                    TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                        BackgroundColor3 = Color3.fromRGB(85, 0, 0),
                                    }):Play()
                                    TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()

                                    Dropdown.Title.Text = 'Callback Error'

                                    print('Rayfield | ' .. DropdownSettings.Name .. ' Callback Error ' .. tostring(Response))
                                    warn(
[[Check docs.sirius.menu for help with Rayfield specific development.]])
                                    task.wait(0.5)

                                    Dropdown.Title.Text = DropdownSettings.Name

                                    TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                        BackgroundColor3 = SelectedTheme.ElementBackground,
                                    }):Play()
                                    TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                                end

                                for _, droption in ipairs(Dropdown.List:GetChildren())do
                                    if droption.ClassName == 'Frame' and droption.Name ~= 'Placeholder' and not table.find(DropdownSettings.CurrentOption, droption.Name) then
                                        TweenService:Create(droption, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {
                                            BackgroundColor3 = SelectedTheme.DropdownUnselected,
                                        }):Play()
                                    end
                                end

                                if not DropdownSettings.MultipleOptions then
                                    task.wait(0.1)
                                    TweenService:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {
                                        Size = UDim2.new(1, -10, 0, 45),
                                    }):Play()

                                    for _, DropdownOpt in ipairs(Dropdown.List:GetChildren())do
                                        if DropdownOpt.ClassName == 'Frame' and DropdownOpt.Name ~= 'Placeholder' then
                                            TweenService:Create(DropdownOpt, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
                                            TweenService:Create(DropdownOpt.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                                            TweenService:Create(DropdownOpt.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                                        end
                                    end

                                    TweenService:Create(Dropdown.List, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ScrollBarImageTransparency = 1}):Play()
                                    TweenService:Create(Dropdown.Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Rotation = 180}):Play()
                                    task.wait(0.35)

                                    Dropdown.List.Visible = false
                                end

                                Debounce = false

                                if not DropdownSettings.Ext then
                                    SaveConfiguration()
                                end
                            end)
                            Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function(
                            )
                                DropdownOption.UIStroke.Color = SelectedTheme.ElementStroke
                            end)
                        end
                    end

                    SetDropdownOptions()

                    for _, droption in ipairs(Dropdown.List:GetChildren())do
                        if droption.ClassName == 'Frame' and droption.Name ~= 'Placeholder' then
                            if not table.find(DropdownSettings.CurrentOption, droption.Name) then
                                droption.BackgroundColor3 = SelectedTheme.DropdownUnselected
                            else
                                droption.BackgroundColor3 = SelectedTheme.DropdownSelected
                            end

                            Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function(
                            )
                                if not table.find(DropdownSettings.CurrentOption, droption.Name) then
                                    droption.BackgroundColor3 = SelectedTheme.DropdownUnselected
                                else
                                    droption.BackgroundColor3 = SelectedTheme.DropdownSelected
                                end
                            end)
                        end
                    end

                    function DropdownSettings:Set(NewOption)
                        DropdownSettings.CurrentOption = NewOption

                        if typeof(DropdownSettings.CurrentOption) == 'string' then
                            DropdownSettings.CurrentOption = {
                                DropdownSettings.CurrentOption,
                            }
                        end
                        if not DropdownSettings.MultipleOptions then
                            DropdownSettings.CurrentOption = {
                                DropdownSettings.CurrentOption[1],
                            }
                        end
                        if DropdownSettings.MultipleOptions then
                            if #DropdownSettings.CurrentOption == 1 then
                                Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
                            elseif #DropdownSettings.CurrentOption == 0 then
                                Dropdown.Selected.Text = 'None'
                            else
                                Dropdown.Selected.Text = 'Various'
                            end
                        else
                            Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
                        end

                        local Success, Response = pcall(function()
                            DropdownSettings.Callback(NewOption)
                        end)

                        if not Success then
                            TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = Color3.fromRGB(85, 0, 0),
                            }):Play()
                            TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()

                            Dropdown.Title.Text = 'Callback Error'

                            print('Rayfield | ' .. DropdownSettings.Name .. ' Callback Error ' .. tostring(Response))
                            warn(
[[Check docs.sirius.menu for help with Rayfield specific development.]])
                            task.wait(0.5)

                            Dropdown.Title.Text = DropdownSettings.Name

                            TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = SelectedTheme.ElementBackground,
                            }):Play()
                            TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                        end

                        for _, droption in ipairs(Dropdown.List:GetChildren())do
                            if droption.ClassName == 'Frame' and droption.Name ~= 'Placeholder' then
                                if not table.find(DropdownSettings.CurrentOption, droption.Name) then
                                    droption.BackgroundColor3 = SelectedTheme.DropdownUnselected
                                else
                                    droption.BackgroundColor3 = SelectedTheme.DropdownSelected
                                end
                            end
                        end
                    end
                    function DropdownSettings:Refresh(optionsTable)
                        DropdownSettings.Options = optionsTable

                        for _, option in Dropdown.List:GetChildren()do
                            if option.ClassName == 'Frame' and option.Name ~= 'Placeholder' then
                                option:Destroy()
                            end
                        end

                        SetDropdownOptions()
                    end

                    if Settings.ConfigurationSaving then
                        if Settings.ConfigurationSaving.Enabled and DropdownSettings.Flag then
                            RayfieldLibrary.Flags[DropdownSettings.Flag] = DropdownSettings
                        end
                    end

                    Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function(
                    )
                        Dropdown.Toggle.ImageColor3 = SelectedTheme.TextColor

                        TweenService:Create(Dropdown, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
                            BackgroundColor3 = SelectedTheme.ElementBackground,
                        }):Play()
                    end)

                    return DropdownSettings
                end
                function Tab:CreateKeybind(KeybindSettings)
                    local CheckingForKey = false
                    local Keybind = Elements.Template.Keybind:Clone()

                    Keybind.Name = KeybindSettings.Name
                    Keybind.Title.Text = KeybindSettings.Name
                    Keybind.Visible = true
                    Keybind.Parent = TabPage
                    Keybind.BackgroundTransparency = 1
                    Keybind.UIStroke.Transparency = 1
                    Keybind.Title.TextTransparency = 1
                    Keybind.KeybindFrame.BackgroundColor3 = SelectedTheme.InputBackground
                    Keybind.KeybindFrame.UIStroke.Color = SelectedTheme.InputStroke

                    TweenService:Create(Keybind, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
                    TweenService:Create(Keybind.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                    TweenService:Create(Keybind.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()

                    Keybind.KeybindFrame.KeybindBox.Text = KeybindSettings.CurrentKeybind
                    Keybind.KeybindFrame.Size = UDim2.new(0, Keybind.KeybindFrame.KeybindBox.TextBounds.X + 24, 0, 30)

                    Keybind.KeybindFrame.KeybindBox.Focused:Connect(function()
                        CheckingForKey = true
                        Keybind.KeybindFrame.KeybindBox.Text = ''
                    end)
                    Keybind.KeybindFrame.KeybindBox.FocusLost:Connect(function()
                        CheckingForKey = false

                        if Keybind.KeybindFrame.KeybindBox.Text == nil or Keybind.KeybindFrame.KeybindBox.Text == '' then
                            Keybind.KeybindFrame.KeybindBox.Text = KeybindSettings.CurrentKeybind

                            if not KeybindSettings.Ext then
                                SaveConfiguration()
                            end
                        end
                    end)
                    Keybind.MouseEnter:Connect(function()
                        TweenService:Create(Keybind, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                            BackgroundColor3 = SelectedTheme.ElementBackgroundHover,
                        }):Play()
                    end)
                    Keybind.MouseLeave:Connect(function()
                        TweenService:Create(Keybind, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                            BackgroundColor3 = SelectedTheme.ElementBackground,
                        }):Play()
                    end)
                    UserInputService.InputBegan:Connect(function(
                        input,
                        processed
                    )
                        if CheckingForKey then
                            if input.KeyCode ~= Enum.KeyCode.Unknown then
                                local SplitMessage = string.split(tostring(input.KeyCode), '.')
                                local NewKeyNoEnum = SplitMessage[3]

                                Keybind.KeybindFrame.KeybindBox.Text = tostring(NewKeyNoEnum)
                                KeybindSettings.CurrentKeybind = tostring(NewKeyNoEnum)

                                Keybind.KeybindFrame.KeybindBox:ReleaseFocus()

                                if not KeybindSettings.Ext then
                                    SaveConfiguration()
                                end
                                if KeybindSettings.CallOnChange then
                                    KeybindSettings.Callback(tostring(NewKeyNoEnum))
                                end
                            end
                        elseif not KeybindSettings.CallOnChange and KeybindSettings.CurrentKeybind ~= nil and (input.KeyCode == Enum.KeyCode[KeybindSettings.CurrentKeybind] and not processed) then
                            local Held = true
                            local Connection

                            Connection = input.Changed:Connect(function(prop)
                                if prop == 'UserInputState' then
                                    Connection:Disconnect()

                                    Held = false
                                end
                            end)

                            if not KeybindSettings.HoldToInteract then
                                local Success, Response = pcall(KeybindSettings.Callback)

                                if not Success then
                                    TweenService:Create(Keybind, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                        BackgroundColor3 = Color3.fromRGB(85, 0, 0),
                                    }):Play()
                                    TweenService:Create(Keybind.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()

                                    Keybind.Title.Text = 'Callback Error'

                                    print('Rayfield | ' .. KeybindSettings.Name .. ' Callback Error ' .. tostring(Response))
                                    warn(
[[Check docs.sirius.menu for help with Rayfield specific development.]])
                                    task.wait(0.5)

                                    Keybind.Title.Text = KeybindSettings.Name

                                    TweenService:Create(Keybind, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                        BackgroundColor3 = SelectedTheme.ElementBackground,
                                    }):Play()
                                    TweenService:Create(Keybind.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                                end
                            else
                                task.wait(0.25)

                                if Held then
                                    local Loop

                                    Loop = RunService.Stepped:Connect(function()
                                        if not Held then
                                            KeybindSettings.Callback(false)
                                            Loop:Disconnect()
                                        else
                                            KeybindSettings.Callback(true)
                                        end
                                    end)
                                end
                            end
                        end
                    end)
                    Keybind.KeybindFrame.KeybindBox:GetPropertyChangedSignal('Text'):Connect(function(
                    )
                        TweenService:Create(Keybind.KeybindFrame, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                            Size = UDim2.new(0, Keybind.KeybindFrame.KeybindBox.TextBounds.X + 24, 0, 30),
                        }):Play()
                    end)

                    function KeybindSettings:Set(NewKeybind)
                        Keybind.KeybindFrame.KeybindBox.Text = tostring(NewKeybind)
                        KeybindSettings.CurrentKeybind = tostring(NewKeybind)

                        Keybind.KeybindFrame.KeybindBox:ReleaseFocus()

                        if not KeybindSettings.Ext then
                            SaveConfiguration()
                        end
                        if KeybindSettings.CallOnChange then
                            KeybindSettings.Callback(tostring(NewKeybind))
                        end
                    end

                    if Settings.ConfigurationSaving then
                        if Settings.ConfigurationSaving.Enabled and KeybindSettings.Flag then
                            RayfieldLibrary.Flags[KeybindSettings.Flag] = KeybindSettings
                        end
                    end

                    Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function(
                    )
                        Keybind.KeybindFrame.BackgroundColor3 = SelectedTheme.InputBackground
                        Keybind.KeybindFrame.UIStroke.Color = SelectedTheme.InputStroke
                    end)

                    return KeybindSettings
                end
                function Tab:CreateToggle(ToggleSettings)
                    local Toggle = Elements.Template.Toggle:Clone()

                    Toggle.Name = ToggleSettings.Name
                    Toggle.Title.Text = ToggleSettings.Name
                    Toggle.Visible = true
                    Toggle.Parent = TabPage
                    Toggle.BackgroundTransparency = 1
                    Toggle.UIStroke.Transparency = 1
                    Toggle.Title.TextTransparency = 1
                    Toggle.Switch.BackgroundColor3 = SelectedTheme.ToggleBackground

                    if SelectedTheme ~= RayfieldLibrary.Theme.Default then
                        Toggle.Switch.Shadow.Visible = false
                    end

                    TweenService:Create(Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
                    TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                    TweenService:Create(Toggle.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()

                    if ToggleSettings.CurrentValue == true then
                        Toggle.Switch.Indicator.Position = UDim2.new(1, -20, 0.5, 0)
                        Toggle.Switch.Indicator.UIStroke.Color = SelectedTheme.ToggleEnabledStroke
                        Toggle.Switch.Indicator.BackgroundColor3 = SelectedTheme.ToggleEnabled
                        Toggle.Switch.UIStroke.Color = SelectedTheme.ToggleEnabledOuterStroke
                    else
                        Toggle.Switch.Indicator.Position = UDim2.new(1, -40, 0.5, 0)
                        Toggle.Switch.Indicator.UIStroke.Color = SelectedTheme.ToggleDisabledStroke
                        Toggle.Switch.Indicator.BackgroundColor3 = SelectedTheme.ToggleDisabled
                        Toggle.Switch.UIStroke.Color = SelectedTheme.ToggleDisabledOuterStroke
                    end

                    Toggle.MouseEnter:Connect(function()
                        TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                            BackgroundColor3 = SelectedTheme.ElementBackgroundHover,
                        }):Play()
                    end)
                    Toggle.MouseLeave:Connect(function()
                        TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                            BackgroundColor3 = SelectedTheme.ElementBackground,
                        }):Play()
                    end)
                    Toggle.Interact.MouseButton1Click:Connect(function()
                        if ToggleSettings.CurrentValue == true then
                            ToggleSettings.CurrentValue = false

                            TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = SelectedTheme.ElementBackgroundHover,
                            }):Play()
                            TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                            TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                                Position = UDim2.new(1, -40, 0.5, 0),
                            }):Play()
                            TweenService:Create(Toggle.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                                Color = SelectedTheme.ToggleDisabledStroke,
                            }):Play()
                            TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                                BackgroundColor3 = SelectedTheme.ToggleDisabled,
                            }):Play()
                            TweenService:Create(Toggle.Switch.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                                Color = SelectedTheme.ToggleDisabledOuterStroke,
                            }):Play()
                            TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = SelectedTheme.ElementBackground,
                            }):Play()
                            TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                        else
                            ToggleSettings.CurrentValue = true

                            TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = SelectedTheme.ElementBackgroundHover,
                            }):Play()
                            TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                            TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                                Position = UDim2.new(1, -20, 0.5, 0),
                            }):Play()
                            TweenService:Create(Toggle.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                                Color = SelectedTheme.ToggleEnabledStroke,
                            }):Play()
                            TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                                BackgroundColor3 = SelectedTheme.ToggleEnabled,
                            }):Play()
                            TweenService:Create(Toggle.Switch.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                                Color = SelectedTheme.ToggleEnabledOuterStroke,
                            }):Play()
                            TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = SelectedTheme.ElementBackground,
                            }):Play()
                            TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                        end

                        local Success, Response = pcall(function()
                            if debugX then
                                warn("Running toggle '" .. ToggleSettings.Name .. "' (Interact)")
                            end

                            ToggleSettings.Callback(ToggleSettings.CurrentValue)
                        end)

                        if not Success then
                            TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = Color3.fromRGB(85, 0, 0),
                            }):Play()
                            TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()

                            Toggle.Title.Text = 'Callback Error'

                            print('Rayfield | ' .. ToggleSettings.Name .. ' Callback Error ' .. tostring(Response))
                            warn(
[[Check docs.sirius.menu for help with Rayfield specific development.]])
                            task.wait(0.5)

                            Toggle.Title.Text = ToggleSettings.Name

                            TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = SelectedTheme.ElementBackground,
                            }):Play()
                            TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                        end
                        if not ToggleSettings.Ext then
                            SaveConfiguration()
                        end
                    end)

                    function ToggleSettings:Set(NewToggleValue)
                        if NewToggleValue == true then
                            ToggleSettings.CurrentValue = true

                            TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = SelectedTheme.ElementBackgroundHover,
                            }):Play()
                            TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                            TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                                Position = UDim2.new(1, -20, 0.5, 0),
                            }):Play()
                            TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                                Size = UDim2.new(0, 12, 0, 12),
                            }):Play()
                            TweenService:Create(Toggle.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                                Color = SelectedTheme.ToggleEnabledStroke,
                            }):Play()
                            TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                                BackgroundColor3 = SelectedTheme.ToggleEnabled,
                            }):Play()
                            TweenService:Create(Toggle.Switch.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                                Color = SelectedTheme.ToggleEnabledOuterStroke,
                            }):Play()
                            TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                                Size = UDim2.new(0, 17, 0, 17),
                            }):Play()
                            TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = SelectedTheme.ElementBackground,
                            }):Play()
                            TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                        else
                            ToggleSettings.CurrentValue = false

                            TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = SelectedTheme.ElementBackgroundHover,
                            }):Play()
                            TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                            TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                                Position = UDim2.new(1, -40, 0.5, 0),
                            }):Play()
                            TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                                Size = UDim2.new(0, 12, 0, 12),
                            }):Play()
                            TweenService:Create(Toggle.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                                Color = SelectedTheme.ToggleDisabledStroke,
                            }):Play()
                            TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                                BackgroundColor3 = SelectedTheme.ToggleDisabled,
                            }):Play()
                            TweenService:Create(Toggle.Switch.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                                Color = SelectedTheme.ToggleDisabledOuterStroke,
                            }):Play()
                            TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                                Size = UDim2.new(0, 17, 0, 17),
                            }):Play()
                            TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = SelectedTheme.ElementBackground,
                            }):Play()
                            TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                        end

                        local Success, Response = pcall(function()
                            if debugX then
                                warn("Running toggle '" .. ToggleSettings.Name .. "' (:Set)")
                            end

                            ToggleSettings.Callback(ToggleSettings.CurrentValue)
                        end)

                        if not Success then
                            TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = Color3.fromRGB(85, 0, 0),
                            }):Play()
                            TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()

                            Toggle.Title.Text = 'Callback Error'

                            print('Rayfield | ' .. ToggleSettings.Name .. ' Callback Error ' .. tostring(Response))
                            warn(
[[Check docs.sirius.menu for help with Rayfield specific development.]])
                            task.wait(0.5)

                            Toggle.Title.Text = ToggleSettings.Name

                            TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = SelectedTheme.ElementBackground,
                            }):Play()
                            TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                        end
                        if not ToggleSettings.Ext then
                            SaveConfiguration()
                        end
                    end

                    if not ToggleSettings.Ext then
                        if Settings.ConfigurationSaving then
                            if Settings.ConfigurationSaving.Enabled and ToggleSettings.Flag then
                                RayfieldLibrary.Flags[ToggleSettings.Flag] = ToggleSettings
                            end
                        end
                    end

                    Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function(
                    )
                        Toggle.Switch.BackgroundColor3 = SelectedTheme.ToggleBackground

                        if SelectedTheme ~= RayfieldLibrary.Theme.Default then
                            Toggle.Switch.Shadow.Visible = false
                        end

                        task.wait()

                        if not ToggleSettings.CurrentValue then
                            Toggle.Switch.Indicator.UIStroke.Color = SelectedTheme.ToggleDisabledStroke
                            Toggle.Switch.Indicator.BackgroundColor3 = SelectedTheme.ToggleDisabled
                            Toggle.Switch.UIStroke.Color = SelectedTheme.ToggleDisabledOuterStroke
                        else
                            Toggle.Switch.Indicator.UIStroke.Color = SelectedTheme.ToggleEnabledStroke
                            Toggle.Switch.Indicator.BackgroundColor3 = SelectedTheme.ToggleEnabled
                            Toggle.Switch.UIStroke.Color = SelectedTheme.ToggleEnabledOuterStroke
                        end
                    end)

                    return ToggleSettings
                end
                function Tab:CreateSlider(SliderSettings)
                    local SLDragging = false
                    local Slider = Elements.Template.Slider:Clone()

                    Slider.Name = SliderSettings.Name
                    Slider.Title.Text = SliderSettings.Name
                    Slider.Visible = true
                    Slider.Parent = TabPage
                    Slider.BackgroundTransparency = 1
                    Slider.UIStroke.Transparency = 1
                    Slider.Title.TextTransparency = 1

                    if SelectedTheme ~= RayfieldLibrary.Theme.Default then
                        Slider.Main.Shadow.Visible = false
                    end

                    Slider.Main.BackgroundColor3 = SelectedTheme.SliderBackground
                    Slider.Main.UIStroke.Color = SelectedTheme.SliderStroke
                    Slider.Main.Progress.UIStroke.Color = SelectedTheme.SliderStroke
                    Slider.Main.Progress.BackgroundColor3 = SelectedTheme.SliderProgress

                    TweenService:Create(Slider, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
                    TweenService:Create(Slider.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                    TweenService:Create(Slider.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()

                    Slider.Main.Progress.Size = UDim2.new(0, Slider.Main.AbsoluteSize.X * ((SliderSettings.CurrentValue + SliderSettings.Range[1]) / (SliderSettings.Range[2] - SliderSettings.Range[1])) > 5 and Slider.Main.AbsoluteSize.X * (SliderSettings.CurrentValue / (SliderSettings.Range[2] - SliderSettings.Range[1])) or 5, 1, 0)

                    if not SliderSettings.Suffix then
                        Slider.Main.Information.Text = tostring(SliderSettings.CurrentValue)
                    else
                        Slider.Main.Information.Text = tostring(SliderSettings.CurrentValue) .. ' ' .. SliderSettings.Suffix
                    end

                    Slider.MouseEnter:Connect(function()
                        TweenService:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                            BackgroundColor3 = SelectedTheme.ElementBackgroundHover,
                        }):Play()
                    end)
                    Slider.MouseLeave:Connect(function()
                        TweenService:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                            BackgroundColor3 = SelectedTheme.ElementBackground,
                        }):Play()
                    end)
                    Slider.Main.Interact.InputBegan:Connect(function(Input)
                        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                            TweenService:Create(Slider.Main.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
                            TweenService:Create(Slider.Main.Progress.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()

                            SLDragging = true
                        end
                    end)
                    Slider.Main.Interact.InputEnded:Connect(function(Input)
                        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                            TweenService:Create(Slider.Main.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0.4}):Play()
                            TweenService:Create(Slider.Main.Progress.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0.3}):Play()

                            SLDragging = false
                        end
                    end)
                    Slider.Main.Interact.MouseButton1Down:Connect(function(X)
                        local Current = Slider.Main.Progress.AbsolutePosition.X + Slider.Main.Progress.AbsoluteSize.X
                        local Start = Current
                        local Location = X
                        local Loop

                        Loop = RunService.Stepped:Connect(function()
                            if SLDragging then
                                Location = UserInputService:GetMouseLocation().X
                                Current = Current + 0.025 * (Location - Start)

                                if Location < Slider.Main.AbsolutePosition.X then
                                    Location = Slider.Main.AbsolutePosition.X
                                elseif Location > Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X then
                                    Location = Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X
                                end
                                if Current < Slider.Main.AbsolutePosition.X + 5 then
                                    Current = Slider.Main.AbsolutePosition.X + 5
                                elseif Current > Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X then
                                    Current = Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X
                                end
                                if Current <= Location and (Location - Start) < 0 or Current >= Location and (Location - Start) > 0 then
                                    Start = Location
                                end

                                TweenService:Create(Slider.Main.Progress, TweenInfo.new(0.45, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                                    Size = UDim2.new(0, Current - Slider.Main.AbsolutePosition.X, 1, 0),
                                }):Play()

                                local NewValue = SliderSettings.Range[1] + (Location - Slider.Main.AbsolutePosition.X) / Slider.Main.AbsoluteSize.X * (SliderSettings.Range[2] - SliderSettings.Range[1])

                                NewValue = math.floor(NewValue / SliderSettings.Increment + 0.5) * (SliderSettings.Increment * 10000000) / 10000000
                                NewValue = math.clamp(NewValue, SliderSettings.Range[1], SliderSettings.Range[2])

                                if not SliderSettings.Suffix then
                                    Slider.Main.Information.Text = tostring(NewValue)
                                else
                                    Slider.Main.Information.Text = tostring(NewValue) .. ' ' .. SliderSettings.Suffix
                                end
                                if SliderSettings.CurrentValue ~= NewValue then
                                    local Success, Response = pcall(function()
                                        SliderSettings.Callback(NewValue)
                                    end)

                                    if not Success then
                                        TweenService:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                            BackgroundColor3 = Color3.fromRGB(85, 0, 0),
                                        }):Play()
                                        TweenService:Create(Slider.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()

                                        Slider.Title.Text = 'Callback Error'

                                        print('Rayfield | ' .. SliderSettings.Name .. ' Callback Error ' .. tostring(Response))
                                        warn(
[[Check docs.sirius.menu for help with Rayfield specific development.]])
                                        task.wait(0.5)

                                        Slider.Title.Text = SliderSettings.Name

                                        TweenService:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                            BackgroundColor3 = SelectedTheme.ElementBackground,
                                        }):Play()
                                        TweenService:Create(Slider.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                                    end

                                    SliderSettings.CurrentValue = NewValue

                                    if not SliderSettings.Ext then
                                        SaveConfiguration()
                                    end
                                end
                            else
                                TweenService:Create(Slider.Main.Progress, TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                                    Size = UDim2.new(0, Location - Slider.Main.AbsolutePosition.X > 5 and Location - Slider.Main.AbsolutePosition.X or 5, 1, 0),
                                }):Play()
                                Loop:Disconnect()
                            end
                        end)
                    end)

                    function SliderSettings:Set(NewVal)
                        local NewVal = math.clamp(NewVal, SliderSettings.Range[1], SliderSettings.Range[2])

                        TweenService:Create(Slider.Main.Progress, TweenInfo.new(0.45, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                            Size = UDim2.new(0, Slider.Main.AbsoluteSize.X * ((NewVal + SliderSettings.Range[1]) / (SliderSettings.Range[2] - SliderSettings.Range[1])) > 5 and Slider.Main.AbsoluteSize.X * (NewVal / (SliderSettings.Range[2] - SliderSettings.Range[1])) or 5, 1, 0),
                        }):Play()

                        Slider.Main.Information.Text = tostring(NewVal) .. ' ' .. (SliderSettings.Suffix or '')

                        local Success, Response = pcall(function()
                            SliderSettings.Callback(NewVal)
                        end)

                        if not Success then
                            TweenService:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = Color3.fromRGB(85, 0, 0),
                            }):Play()
                            TweenService:Create(Slider.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()

                            Slider.Title.Text = 'Callback Error'

                            print('Rayfield | ' .. SliderSettings.Name .. ' Callback Error ' .. tostring(Response))
                            warn(
[[Check docs.sirius.menu for help with Rayfield specific development.]])
                            task.wait(0.5)

                            Slider.Title.Text = SliderSettings.Name

                            TweenService:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = SelectedTheme.ElementBackground,
                            }):Play()
                            TweenService:Create(Slider.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
                        end

                        SliderSettings.CurrentValue = NewVal

                        if not SliderSettings.Ext then
                            SaveConfiguration()
                        end
                    end

                    if Settings.ConfigurationSaving then
                        if Settings.ConfigurationSaving.Enabled and SliderSettings.Flag then
                            RayfieldLibrary.Flags[SliderSettings.Flag] = SliderSettings
                        end
                    end

                    Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function(
                    )
                        if SelectedTheme ~= RayfieldLibrary.Theme.Default then
                            Slider.Main.Shadow.Visible = false
                        end

                        Slider.Main.BackgroundColor3 = SelectedTheme.SliderBackground
                        Slider.Main.UIStroke.Color = SelectedTheme.SliderStroke
                        Slider.Main.Progress.UIStroke.Color = SelectedTheme.SliderStroke
                        Slider.Main.Progress.BackgroundColor3 = SelectedTheme.SliderProgress
                    end)

                    return SliderSettings
                end

                Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function(
                )
                    TabButton.UIStroke.Color = SelectedTheme.TabStroke

                    if Elements.UIPageLayout.CurrentPage == TabPage then
                        TabButton.BackgroundColor3 = SelectedTheme.TabBackgroundSelected
                        TabButton.Image.ImageColor3 = SelectedTheme.SelectedTabTextColor
                        TabButton.Title.TextColor3 = SelectedTheme.SelectedTabTextColor
                    else
                        TabButton.BackgroundColor3 = SelectedTheme.TabBackground
                        TabButton.Image.ImageColor3 = SelectedTheme.TabTextColor
                        TabButton.Title.TextColor3 = SelectedTheme.TabTextColor
                    end
                end)

                return Tab
            end

            Elements.Visible = true

            task.wait(1.1)
            TweenService:Create(Main, TweenInfo.new(0.7, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut), {
                Size = UDim2.new(0, 390, 0, 90),
            }):Play()
            task.wait(0.3)
            TweenService:Create(LoadingFrame.Title, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
            TweenService:Create(LoadingFrame.Subtitle, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
            TweenService:Create(LoadingFrame.Version, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
            task.wait(0.1)
            TweenService:Create(Main, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                Size = useMobileSizing and UDim2.new(0, 500, 0, 275) or UDim2.new(0, 500, 0, 475),
            }):Play()
            TweenService:Create(Main.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 0.6}):Play()

            Topbar.BackgroundTransparency = 1
            Topbar.Divider.Size = UDim2.new(0, 0, 0, 1)
            Topbar.Divider.BackgroundColor3 = SelectedTheme.ElementStroke
            Topbar.CornerRepair.BackgroundTransparency = 1
            Topbar.Title.TextTransparency = 1
            Topbar.Search.ImageTransparency = 1

            if Topbar:FindFirstChild('Settings') then
                Topbar.Settings.ImageTransparency = 1
            end

            Topbar.ChangeSize.ImageTransparency = 1
            Topbar.Hide.ImageTransparency = 1

            task.wait(0.5)

            Topbar.Visible = true

            TweenService:Create(Topbar, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
            TweenService:Create(Topbar.CornerRepair, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
            task.wait(0.1)
            TweenService:Create(Topbar.Divider, TweenInfo.new(1, Enum.EasingStyle.Exponential), {
                Size = UDim2.new(1, 0, 0, 1),
            }):Play()
            TweenService:Create(Topbar.Title, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
            task.wait(0.05)
            TweenService:Create(Topbar.Search, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {ImageTransparency = 0.8}):Play()
            task.wait(0.05)

            if Topbar:FindFirstChild('Settings') then
                TweenService:Create(Topbar.Settings, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {ImageTransparency = 0.8}):Play()
                task.wait(0.05)
            end

            TweenService:Create(Topbar.ChangeSize, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {ImageTransparency = 0.8}):Play()
            task.wait(0.05)
            TweenService:Create(Topbar.Hide, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {ImageTransparency = 0.8}):Play()
            task.wait(0.3)

            if dragBar then
                TweenService:Create(dragBarCosmetic, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.7}):Play()
            end

            function Window.ModifyTheme(NewTheme)
                local success = pcall(ChangeTheme, NewTheme)

                if not success then
                    RayfieldLibrary:Notify({
                        Title = 'Unable to Change Theme',
                        Content = 'We are unable find a theme on file.',
                        Image = 4400704299,
                    })
                else
                    RayfieldLibrary:Notify({
                        Title = 'Theme Changed',
                        Content = 'Successfully changed theme to ' .. (typeof(NewTheme) == 'string' and NewTheme or 'Custom Theme') .. '.',
                        Image = 4483362748,
                    })
                end
            end

            local success, result = pcall(function()
                createSettings(Window)
            end)

            if not success then
                warn('Rayfield had an issue creating settings.')
            end

            return Window
        end

        local setVisibility = function(visibility, notify)
            if Debounce then
                return
            end
            if visibility then
                Hidden = false

                Unhide()
            else
                Hidden = true

                Hide(notify)
            end
        end

        function RayfieldLibrary:SetVisibility(visibility)
            setVisibility(visibility, false)
        end
        function RayfieldLibrary:IsVisible()
            return not Hidden
        end

        local hideHotkeyConnection

        function RayfieldLibrary:Destroy()
            rayfieldDestroyed = true

            hideHotkeyConnection:Disconnect()
            Rayfield:Destroy()
        end

        Topbar.ChangeSize.MouseButton1Click:Connect(function()
            if Debounce then
                return
            end
            if Minimised then
                Minimised = false

                Maximise()
            else
                Minimised = true

                Minimise()
            end
        end)
        Main.Search.Input:GetPropertyChangedSignal('Text'):Connect(function()
            if #Main.Search.Input.Text > 0 then
                if not Elements.UIPageLayout.CurrentPage:FindFirstChild('SearchTitle-fsefsefesfsefesfesfThanks') then
                    local searchTitle = Elements.Template.SectionTitle:Clone()

                    searchTitle.Parent = Elements.UIPageLayout.CurrentPage
                    searchTitle.Name = 'SearchTitle-fsefsefesfsefesfesfThanks'
                    searchTitle.LayoutOrder = -100
                    searchTitle.Title.Text = "Results from '" .. Elements.UIPageLayout.CurrentPage.Name .. "'"
                    searchTitle.Visible = true
                end
            else
                local searchTitle = Elements.UIPageLayout.CurrentPage:FindFirstChild('SearchTitle-fsefsefesfsefesfesfThanks')

                if searchTitle then
                    searchTitle:Destroy()
                end
            end

            for _, element in ipairs(Elements.UIPageLayout.CurrentPage:GetChildren())do
                if element.ClassName ~= 'UIListLayout' and element.Name ~= 'Placeholder' and element.Name ~= 'SearchTitle-fsefsefesfsefesfesfThanks' then
                    if element.Name == 'SectionTitle' then
                        if #Main.Search.Input.Text == 0 then
                            element.Visible = true
                        else
                            element.Visible = false
                        end
                    else
                        if string.lower(element.Name):find(string.lower(Main.Search.Input.Text), 1, true) then
                            element.Visible = true
                        else
                            element.Visible = false
                        end
                    end
                end
            end
        end)
        Main.Search.Input.FocusLost:Connect(function(enterPressed)
            if #Main.Search.Input.Text == 0 and searchOpen then
                task.wait(0.12)
                closeSearch()
            end
        end)
        Topbar.Search.MouseButton1Click:Connect(function()
            task.spawn(function()
                if searchOpen then
                    closeSearch()
                else
                    openSearch()
                end
            end)
        end)

        if Topbar:FindFirstChild('Settings') then
            Topbar.Settings.MouseButton1Click:Connect(function()
                task.spawn(function()
                    for _, OtherTabButton in ipairs(TabList:GetChildren())do
                        if OtherTabButton.Name ~= 'Template' and OtherTabButton.ClassName == 'Frame' and OtherTabButton ~= TabButton and OtherTabButton.Name ~= 'Placeholder' then
                            TweenService:Create(OtherTabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {
                                BackgroundColor3 = SelectedTheme.TabBackground,
                            }):Play()
                            TweenService:Create(OtherTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {
                                TextColor3 = SelectedTheme.TabTextColor,
                            }):Play()
                            TweenService:Create(OtherTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {
                                ImageColor3 = SelectedTheme.TabTextColor,
                            }):Play()
                            TweenService:Create(OtherTabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.7}):Play()
                            TweenService:Create(OtherTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0.2}):Play()
                            TweenService:Create(OtherTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.2}):Play()
                            TweenService:Create(OtherTabButton.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0.5}):Play()
                        end
                    end

                    Elements.UIPageLayout:JumpTo(Elements['Rayfield Settings'])
                end)
            end)
        end

        Topbar.Hide.MouseButton1Click:Connect(function()
            setVisibility(Hidden, not useMobileSizing)
        end)

        hideHotkeyConnection = UserInputService.InputBegan:Connect(function(
            input,
            processed
        )
            if (input.KeyCode == Enum.KeyCode[getSetting('General', 'rayfieldOpen')]) and not processed then
                if Debounce then
                    return
                end
                if Hidden then
                    Hidden = false

                    Unhide()
                else
                    Hidden = true

                    Hide()
                end
            end
        end)

        if MPrompt then
            MPrompt.Interact.MouseButton1Click:Connect(function()
                if Debounce then
                    return
                end
                if Hidden then
                    Hidden = false

                    Unhide()
                end
            end)
        end

        for _, TopbarButton in ipairs(Topbar:GetChildren())do
            if TopbarButton.ClassName == 'ImageButton' and TopbarButton.Name ~= 'Icon' then
                TopbarButton.MouseEnter:Connect(function()
                    TweenService:Create(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
                end)
                TopbarButton.MouseLeave:Connect(function()
                    TweenService:Create(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.8}):Play()
                end)
            end
        end

        function RayfieldLibrary:LoadConfiguration()
            local config

            if debugX then
                warn('Loading Configuration')
            end
            if useStudio then
                config = 
[[{"Toggle1adwawd":true,"ColorPicker1awd":{"B":255,"G":255,"R":255},"Slider1dawd":100,"ColorPicfsefker1":{"B":255,"G":255,"R":255},"Slidefefsr1":80,"dawdawd":"","Input1":"hh","Keybind1":"B","Dropdown1":["Ocean"]}]]
            end
            if CEnabled then
                local notified
                local loaded
                local success, result = pcall(function()
                    if useStudio and config then
                        loaded = LoadConfiguration(config)

                        return
                    end
                    if isfile then
                        if isfile(ConfigurationFolder .. '/' .. CFileName .. ConfigurationExtension) then
                            loaded = LoadConfiguration(readfile(ConfigurationFolder .. '/' .. CFileName .. ConfigurationExtension))
                        end
                    else
                        notified = true

                        RayfieldLibrary:Notify({
                            Title = 'Rayfield Configurations',
                            Content = 
[[We couldn't enable Configuration Saving as you are not using software with filesystem support.]],
                            Image = 4384402990,
                        })
                    end
                end)

                if success and loaded and not notified then
                    RayfieldLibrary:Notify({
                        Title = 'Rayfield Configurations',
                        Content = 
[[The configuration file for this script has been loaded from a previous session.]],
                        Image = 4384403532,
                    })
                elseif not success and not notified then
                    warn('Rayfield Configurations Error | ' .. tostring(result))
                    RayfieldLibrary:Notify({
                        Title = 'Rayfield Configurations',
                        Content = 
[[We've encountered an issue loading your configuration correctly.

Check the Developer Console for more information.]],
                        Image = 4384402990,
                    })
                end
            end

            globalLoaded = true
        end

        if CEnabled and Main:FindFirstChild('Notice') then
            Main.Notice.BackgroundTransparency = 1
            Main.Notice.Title.TextTransparency = 1
            Main.Notice.Size = UDim2.new(0, 0, 0, 0)
            Main.Notice.Position = UDim2.new(0.5, 0, 0, -100)
            Main.Notice.Visible = true

            TweenService:Create(Main.Notice, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut), {
                Size = UDim2.new(0, 280, 0, 35),
                Position = UDim2.new(0.5, 0, 0, -50),
                BackgroundTransparency = 0.5,
            }):Play()
            TweenService:Create(Main.Notice.Title, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0.1}):Play()
        end

        task.delay(4, function()
            RayfieldLibrary.LoadConfiguration()

            if Main:FindFirstChild('Notice') and Main.Notice.Visible then
                TweenService:Create(Main.Notice, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut), {
                    Size = UDim2.new(0, 100, 0, 25),
                    Position = UDim2.new(0.5, 0, 0, -100),
                    BackgroundTransparency = 1,
                }):Play()
                TweenService:Create(Main.Notice.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                task.wait(0.5)

                Main.Notice.Visible = false
            end
        end)

        return RayfieldLibrary
    end
    function __DARKLUA_BUNDLE_MODULES.r()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local InventoryDB = Bypass('InventoryDB')
        local Clipboard = {}
        local localPlayer = Players.LocalPlayer
        local getPetInfoMega = function(title)
            local megaPets = {}
            local textPetList = ''

            for _, v in ClientData.get_data()[localPlayer.Name].inventory.pets do
                for _, v2 in InventoryDB.pets do
                    if v.id == v2.id and v.properties.mega_neon then
                        megaPets[title .. v2.name] = (megaPets[title .. v2.name] or 0) + 1
                    end
                end
            end
            for i, v in megaPets do
                textPetList = string.format('%s%s x%s\n', tostring(textPetList), tostring(i), tostring(v))
            end

            return textPetList
        end
        local getPetInfoNeon = function(title)
            local neonPets = {}
            local textPetList = ''

            for _, v in ClientData.get_data()[localPlayer.Name].inventory.pets do
                for _, v2 in InventoryDB.pets do
                    if v.id == v2.id and v.properties.neon then
                        neonPets[title .. v2.name] = (neonPets[title .. v2.name] or 0) + 1
                    end
                end
            end
            for i, v in neonPets do
                textPetList = string.format('%s%s x%s\n', tostring(textPetList), tostring(i), tostring(v))
            end

            return textPetList
        end
        local getPetInfoNormal = function(title)
            local normalPets = {}
            local textPetList = ''

            for _, v in pairs(ClientData.get_data()[localPlayer.Name].inventory.pets)do
                for _, v2 in InventoryDB.pets do
                    if v.id == v2.id and not v.properties.neon and not v.properties.mega_neon then
                        normalPets[title .. v2.name] = (normalPets[title .. v2.name] or 0) + 1
                    end
                end
            end
            for i, v in normalPets do
                textPetList = string.format('%s%s x%s\n', tostring(textPetList), tostring(i), tostring(v))
            end

            return textPetList
        end
        local getInventoryInfo = function(tab, tablePassOn)
            for _, v in pairs(ClientData.get_data()[localPlayer.Name].inventory[tab])do
                if v.id == 'practice_dog' then
                    continue
                end

                tablePassOn[v.id] = (tablePassOn[v.id] or 0) + 1
            end
        end
        local getTable = function(nameId, tablePassOn)
            local text = ''

            for i, v in tablePassOn do
                for _, v2 in InventoryDB[nameId]do
                    if i == tostring(v2.id) then
                        text = text .. '[' .. string.upper(nameId) .. '] ' .. v2.name .. ' x' .. v .. '\n'
                    end
                end
            end

            return text
        end
        local getAgeupPotionInfo = function()
            local count = 0

            for _, v in pairs(ClientData.get_data()[localPlayer.Name].inventory.food)do
                if v.id == 'pet_age_potion' then
                    count = count + 1
                end
            end

            return count
        end
        local addComma = function(amount)
            local formatted = amount
            local k

            while true do
                formatted, k = string.gsub(formatted, '^(-?%d+)(%d%d%d)', '%1,%2')

                if k == 0 then
                    break
                end
            end

            return formatted
        end
        local getBucksInfo = function()
            local text = ''
            local potions = getAgeupPotionInfo()
            local potionAmount = potions * 0.01
            local bucks = ClientData.get_data()[localPlayer.Name].money or 0

            text = text .. string.format('%s Age-up Potions + %s Bucks | Adopt me\n', tostring(potions), tostring(addComma(bucks)))

            local formatNumber = string.format('%.2f', potionAmount)

            text = text .. string.format('sell for $%s  %s\n\n', tostring(tostring(formatNumber)), tostring(localPlayer.Name))

            return text
        end

        function Clipboard.GetAllInventoryData()
            local inventoryData = ''
            local inventoryTables = {
                petsTable = {},
                petAccessoriesTable = {},
                strollersTable = {},
                foodTable = {},
                transportTable = {},
                toysTable = {},
                giftsTable = {},
            }

            getInventoryInfo('pets', inventoryTables.petsTable)
            getInventoryInfo('pet_accessories', inventoryTables.petAccessoriesTable)
            getInventoryInfo('strollers', inventoryTables.strollersTable)
            getInventoryInfo('food', inventoryTables.foodTable)
            getInventoryInfo('transport', inventoryTables.transportTable)
            getInventoryInfo('toys', inventoryTables.toysTable)
            getInventoryInfo('gifts', inventoryTables.giftsTable)

            inventoryData = inventoryData .. getBucksInfo()
            inventoryData = inventoryData .. getTable('pets', inventoryTables.petsTable)
            inventoryData = inventoryData .. getTable('pet_accessories', inventoryTables.petAccessoriesTable)
            inventoryData = inventoryData .. getTable('strollers', inventoryTables.strollersTable)
            inventoryData = inventoryData .. getTable('food', inventoryTables.foodTable)
            inventoryData = inventoryData .. getTable('transport', inventoryTables.transportTable)
            inventoryData = inventoryData .. getTable('toys', inventoryTables.toysTable)
            inventoryData = inventoryData .. getTable('gifts', inventoryTables.giftsTable)

            return inventoryData
        end
        function Clipboard.CopyDetailedPetInfo()
            local petDetailedList = ''

            petDetailedList = petDetailedList .. getBucksInfo()
            petDetailedList = petDetailedList .. getPetInfoMega('[MEGA NEON] ')
            petDetailedList = petDetailedList .. getPetInfoNeon('[NEON] ')
            petDetailedList = petDetailedList .. getPetInfoNormal('[Normal] ')

            return petDetailedList
        end
        function Clipboard.GetIdsFromDatabase(nameId)
            local data = ''
            local lines = 
[[

---------------------------------------------------------------
]]

            for catagoryName, catagoryTable in InventoryDB do
                if catagoryName ~= nameId then
                    continue
                end

                data = data .. lines
                data = data .. string.format('\n                    %s                    \n', tostring(string.upper(catagoryName)))
                data = data .. lines .. '\n'

                for id, _ in catagoryTable do
                    data = data .. string.format('%s\n', tostring(id))
                end
            end

            return data
        end

        return Clipboard
    end
    function __DARKLUA_BUNDLE_MODULES.s()
        local Players = cloneref(game:GetService('Players'))
        local Rayfield = __DARKLUA_BUNDLE_MODULES.load('q')
        local GetInventory = __DARKLUA_BUNDLE_MODULES.load('i')
        local Clipboard = __DARKLUA_BUNDLE_MODULES.load('r')
        local Fusion = __DARKLUA_BUNDLE_MODULES.load('h')
        local Trade = __DARKLUA_BUNDLE_MODULES.load('e')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('a')
        local BulkPotion = __DARKLUA_BUNDLE_MODULES.load('j')
        local self = {}
        local localPlayer = Players.LocalPlayer
        local cooldown = false
        local selectedPlayer
        local selectedAgeablePet
        local selectedAgeableNumber
        local TradeAllInventory
        local AllPetsToggle
        local LegendaryToggle
        local FullgrownToggle
        local MultipleChoiceToggle
        local AnyNeonToggle
        local TradeAllMegas
        local TradeAllNeons
        local LowTierToggle
        local RarityToggle
        local petsToggle1
        local petsToggle2
        local petRaritys = {
            'common',
            'uncommon',
            'rare',
            'ultra_rare',
            'legendary',
        }
        local petAges = {
            'Newborn/Reborn',
            'Junior/Twinkle',
            'Pre_Teen/Sparkle',
            'Teen/Flare',
            'Post_Teen/Sunshine',
            'Full_Grown/Luminous',
        }
        local petNeons = {
            'normal',
            'neon',
            'mega_neon',
        }
        local multipleOptionsTable = {
            ['rarity'] = {},
            ['ages'] = {},
            ['neons'] = {},
        }
        local setupRayfield = function()
            local Window = Rayfield:CreateWindow({
                Name = localPlayer.Name,
                Theme = 'Default',
                DisableRayfieldPrompts = true,
                DisableBuildWarnings = true,
                LoadingTitle = 'Rayfield Interface Suite',
                LoadingSubtitle = 'by Sirius',
                ConfigurationSaving = {
                    Enabled = false,
                    FolderName = nil,
                    FileName = 'Big Hub',
                },
                Discord = {
                    Enabled = false,
                    Invite = 'noinvitelink',
                    RememberJoins = true,
                },
                KeySystem = false,
                KeySettings = {
                    Title = 'Untitled',
                    Subtitle = 'Key System',
                    Note = 'No method of obtaining the key is provided',
                    FileName = 'Key',
                    SaveKey = false,
                    GrabKeyFromSite = false,
                    Key = {
                        'Hello',
                    },
                },
            })
            local MiscTab = Window:CreateTab('Misc', 4483362458)

            MiscTab:CreateSection('1 Click = ALL Neon/Mega')
            MiscTab:CreateButton({
                Name = 'Make Neons',
                Callback = function()
                    Fusion.MakeMega(false)
                end,
            })
            MiscTab:CreateButton({
                Name = 'Make Megas',
                Callback = function()
                    Fusion.MakeMega(true)
                end,
            })
            MiscTab:CreateDivider()
            MiscTab:CreateButton({
                Name = 'Get player inventory data',
                Callback = function()
                    setclipboard(Clipboard.GetAllInventoryData())
                end,
            })
            MiscTab:CreateButton({
                Name = 'Get player Detailed inventory data',
                Callback = function()
                    setclipboard(Clipboard.CopyDetailedPetInfo())
                end,
            })
            MiscTab:CreateDivider()
            MiscTab:CreateButton({
                Name = "Get pets database id's",
                Callback = function()
                    setclipboard(Clipboard.GetIdsFromDatabase('pets'))
                end,
            })
            MiscTab:CreateButton({
                Name = "Get gifts database id's",
                Callback = function()
                    setclipboard(Clipboard.GetIdsFromDatabase('gifts'))
                end,
            })
            MiscTab:CreateButton({
                Name = "Get pet_accessories (pet wear and wings) database id's",
                Callback = function()
                    setclipboard(Clipboard.GetIdsFromDatabase('pet_accessories'))
                end,
            })
            MiscTab:CreateButton({
                Name = "Get toys database id's",
                Callback = function()
                    setclipboard(Clipboard.GetIdsFromDatabase('toys'))
                end,
            })
            MiscTab:CreateButton({
                Name = "Get transport database id's",
                Callback = function()
                    setclipboard(Clipboard.GetIdsFromDatabase('transport'))
                end,
            })
            MiscTab:CreateButton({
                Name = "Get food database id's",
                Callback = function()
                    setclipboard(Clipboard.GetIdsFromDatabase('food'))
                end,
            })
            MiscTab:CreateButton({
                Name = "Get strollers database id's",
                Callback = function()
                    setclipboard(Clipboard.GetIdsFromDatabase('strollers'))
                end,
            })
            MiscTab:CreateButton({
                Name = "Get stickers database id's",
                Callback = function()
                    setclipboard(Clipboard.GetIdsFromDatabase('stickers'))
                end,
            })

            local TradeTab = Window:CreateTab('Auto Trade', 4483362458)

            TradeTab:CreateSection('only enable Auto Accept trade on alt getting the items')
            TradeTab:CreateToggle({
                Name = 'Auto accept trade windows',
                CurrentValue = false,
                Flag = 'Toggle1',
                Callback = function(Value)
                    getgenv().auto_accept_trade = Value

                    if getgenv().auto_accept_trade then
                        Rayfield:SetVisibility(false)
                        task.wait(1)
                    end

                    while getgenv().auto_accept_trade do
                        Trade.AutoAcceptTrade()
                        task.wait(1)
                    end
                end,
            })

            local playerDropdown = TradeTab:CreateDropdown({
                Name = 'Select a player',
                Options = {
                    '',
                },
                CurrentOption = {
                    '',
                },
                MultipleOptions = false,
                Flag = 'Dropdown1',
                Callback = function(Option)
                    selectedPlayer = Option[1]
                end,
            })

            TradeTab:CreateButton({
                Name = 'Refesh player list',
                Callback = function()
                    local playersTable = Utils.GetPlayersInGame()

                    playerDropdown:Refresh(playersTable)
                end,
            })
            TradeTab:CreateToggle({
                Name = 'Send player Trade',
                CurrentValue = false,
                Flag = 'Toggle1',
                Callback = function(Value)
                    getgenv().auto_trade_semi_auto = Value

                    while getgenv().auto_trade_semi_auto do
                        Trade.SendTradeRequest({selectedPlayer})
                        task.wait(1)
                    end
                end,
            })
            TradeTab:CreateToggle({
                Name = 'Semi-Auto Trade (manually choose items)',
                CurrentValue = false,
                Flag = 'Toggle1',
                Callback = function(Value)
                    getgenv().auto_trade_semi_auto = Value
                end,
            })

            TradeAllInventory = TradeTab:CreateToggle({
                Name = 'Auto Trade EVERYTHING',
                CurrentValue = false,
                Flag = 'Toggle1',
                Callback = function(Value)
                    getgenv().auto_trade_all_inventory = Value

                    while getgenv().auto_trade_all_inventory do
                        Trade.SendTradeRequest({selectedPlayer})
                        Trade.AllInventory('pets')
                        Trade.AllInventory('pet_accessories')
                        Trade.AllInventory('strollers')
                        Trade.AllInventory('food')
                        Trade.AllInventory('transport')
                        Trade.AllInventory('toys')
                        Trade.AllInventory('gifts')

                        local hasPets = Trade.AcceptNegotiationAndConfirm()

                        if not hasPets then
                            TradeAllInventory:Set(false)
                        end

                        task.wait()
                    end
                end,
            })
            AllPetsToggle = TradeTab:CreateToggle({
                Name = 'Auto Trade All Pets',
                CurrentValue = false,
                Flag = 'Toggle1',
                Callback = function(Value)
                    getgenv().auto_trade_all_pets = Value

                    while getgenv().auto_trade_all_pets do
                        Trade.SendTradeRequest({selectedPlayer})
                        Trade.AllPets()

                        local hasPets = Trade.AcceptNegotiationAndConfirm()

                        if not hasPets then
                            AllPetsToggle:Set(false)
                        end

                        task.wait()
                    end
                end,
            })
            AnyNeonToggle = TradeTab:CreateToggle({
                Name = 'FullGrown, Newborn to luminous Neons and Megas',
                CurrentValue = false,
                Flag = 'Toggle1',
                Callback = function(Value)
                    getgenv().auto_trade_fullgrown_neon_and_mega = Value

                    while getgenv().auto_trade_fullgrown_neon_and_mega do
                        Trade.SendTradeRequest({selectedPlayer})
                        Trade.FullgrownAndAnyNeonsAndMegas()

                        local hasPets = Trade.AcceptNegotiationAndConfirm()

                        if not hasPets then
                            AnyNeonToggle:Set(false)
                        end

                        task.wait()
                    end
                end,
            })
            LegendaryToggle = TradeTab:CreateToggle({
                Name = "Auto Trade Only Legendary's",
                CurrentValue = false,
                Flag = 'Toggle1',
                Callback = function(Value)
                    getgenv().auto_trade_Legendary = Value

                    while getgenv().auto_trade_Legendary do
                        Trade.SendTradeRequest({selectedPlayer})
                        Trade.AllPetsOfSameRarity('legendary')

                        local hasPets = Trade.AcceptNegotiationAndConfirm()

                        if not hasPets then
                            LegendaryToggle:Set(false)
                        end

                        task.wait()
                    end
                end,
            })
            FullgrownToggle = TradeTab:CreateToggle({
                Name = 'Auto Trade FullGrown, luminous Neons and Megas',
                CurrentValue = false,
                Flag = 'Toggle1',
                Callback = function(Value)
                    getgenv().auto_trade_fullgrown_neon_and_mega = Value

                    while getgenv().auto_trade_fullgrown_neon_and_mega do
                        Trade.SendTradeRequest({selectedPlayer})
                        Trade.Fullgrown()

                        local hasPets = Trade.AcceptNegotiationAndConfirm()

                        if not hasPets then
                            FullgrownToggle:Set(false)
                        end

                        task.wait()
                    end
                end,
            })
            TradeAllMegas = TradeTab:CreateToggle({
                Name = 'Auto Trade All Megas',
                CurrentValue = false,
                Flag = 'Toggle1',
                Callback = function(Value)
                    getgenv().auto_trade_all_neons = Value

                    while getgenv().auto_trade_all_neons do
                        Trade.SendTradeRequest({selectedPlayer})
                        Trade.AllNeons('mega_neon')

                        local hasPets = Trade.AcceptNegotiationAndConfirm()

                        if not hasPets then
                            TradeAllMegas:Set(false)
                        end

                        task.wait()
                    end
                end,
            })
            TradeAllNeons = TradeTab:CreateToggle({
                Name = 'Auto Trade All Neons',
                CurrentValue = false,
                Flag = 'Toggle1',
                Callback = function(Value)
                    getgenv().auto_trade_all_neons = Value

                    while getgenv().auto_trade_all_neons do
                        Trade.SendTradeRequest({selectedPlayer})
                        Trade.AllNeons('neon')

                        local hasPets = Trade.AcceptNegotiationAndConfirm()

                        if not hasPets then
                            TradeAllNeons:Set(false)
                        end

                        task.wait()
                    end
                end,
            })
            LowTierToggle = TradeTab:CreateToggle({
                Name = 'Auto Trade Common to Ultra-rare and Newborn to Post-Teen',
                CurrentValue = false,
                Flag = 'Toggle1',
                Callback = function(Value)
                    getgenv().auto_trade_lowtier_pets = Value

                    while getgenv().auto_trade_lowtier_pets do
                        if selectedPlayer then
                            Trade.SendTradeRequest({selectedPlayer})
                        end

                        Trade.LowTiers()

                        local hasPets = Trade.AcceptNegotiationAndConfirm()

                        if not hasPets then
                            LowTierToggle:Set(false)
                        end

                        task.wait()
                    end
                end,
            })
            RarityToggle = TradeTab:CreateToggle({
                Name = 'Auto Trade Legendary Newborn to Post-Teen',
                CurrentValue = false,
                Flag = 'Toggle1',
                Callback = function(Value)
                    getgenv().auto_trade_rarity_pets = Value

                    while getgenv().auto_trade_rarity_pets do
                        if selectedPlayer then
                            Trade.SendTradeRequest({selectedPlayer})
                        end

                        Trade.NewbornToPostteen('legendary')

                        local hasPets = Trade.AcceptNegotiationAndConfirm()

                        if not hasPets then
                            RarityToggle:Set(false)
                        end

                        task.wait()
                    end
                end,
            })
            petsToggle1 = TradeTab:CreateToggle({
                Name = 'Auto Trade Normal Fullgrown Only',
                CurrentValue = false,
                Flag = 'Toggle1',
                Callback = function(Value)
                    getgenv().autoTrading = Value

                    while getgenv().autoTrading do
                        if selectedPlayer then
                            Trade.SendTradeRequest({selectedPlayer})
                        end

                        Trade.NormalFullgrownOnly()

                        local hasPets = Trade.AcceptNegotiationAndConfirm()

                        if not hasPets then
                            petsToggle1:Set(false)
                        end

                        task.wait()
                    end
                end,
            })
            petsToggle2 = TradeTab:CreateToggle({
                Name = 'Auto Trade Normal Newborn to Postteen Only',
                CurrentValue = false,
                Flag = 'Toggle1',
                Callback = function(Value)
                    getgenv().autoTrading = Value

                    while getgenv().autoTrading do
                        if selectedPlayer then
                            Trade.SendTradeRequest({selectedPlayer})
                        end

                        Trade.NormalNewbornToPostteen()

                        local hasPets = Trade.AcceptNegotiationAndConfirm()

                        if not hasPets then
                            petsToggle2:Set(false)
                        end

                        task.wait()
                    end
                end,
            })

            TradeTab:CreateSection('Multiple Choice')

            local petRarityDropdown = TradeTab:CreateDropdown({
                Name = 'Select rarity(s)',
                Options = petRaritys,
                CurrentOption = {},
                MultipleOptions = true,
                Flag = 'Dropdown1',
                Callback = function(Options)
                    multipleOptionsTable['rarity'] = Options
                end,
            })
            local petAgeDropdown = TradeTab:CreateDropdown({
                Name = 'Select pet age(s)',
                Options = petAges,
                CurrentOption = {},
                MultipleOptions = true,
                Flag = 'Dropdown1',
                Callback = function(Options)
                    multipleOptionsTable['ages'] = Options
                end,
            })
            local petNeonDropdown = TradeTab:CreateDropdown({
                Name = 'Select pet normal or neon/mega',
                Options = petNeons,
                CurrentOption = {},
                MultipleOptions = true,
                Flag = 'Dropdown1',
                Callback = function(Options)
                    multipleOptionsTable['neons'] = Options
                end,
            })

            MultipleChoiceToggle = TradeTab:CreateToggle({
                Name = 'START trading multi-choice pets',
                CurrentValue = false,
                Flag = 'Toggle1',
                Callback = function(Value)
                    getgenv().auto_trade_multi_choice = Value

                    if getgenv().auto_trade_multi_choice then
                        if #multipleOptionsTable['rarity'] == 0 then
                            MultipleChoiceToggle:Set(false)

                            return Utils.PrintDebug('\u{1f6d1} didnt select any rarity')
                        end
                        if #multipleOptionsTable['ages'] == 0 then
                            MultipleChoiceToggle:Set(false)

                            return Utils.PrintDebug('\u{1f6d1} didnt select any ages')
                        end
                        if #multipleOptionsTable['neons'] == 0 then
                            MultipleChoiceToggle:Set(false)

                            return Utils.PrintDebug('\u{1f6d1} didnt select normal or neon or mega_neon')
                        end
                    end

                    while getgenv().auto_trade_multi_choice do
                        if not Trade.SendTradeRequest({selectedPlayer}) then
                            Utils.PrintDebug('\u{26a0}\u{fe0f} PLAYER YOU WERE TRADING LEFT GAME \u{26a0}\u{fe0f}')
                            MultipleChoiceToggle:Set(false)

                            return
                        end

                        Trade.MultipleOptions(multipleOptionsTable)

                        local hasPets = Trade.AcceptNegotiationAndConfirm()

                        if not hasPets then
                            MultipleChoiceToggle:Set(false)
                        end

                        task.wait()
                    end

                    petRarityDropdown:Set({
                        '',
                    })
                    petAgeDropdown:Set({
                        '',
                    })
                    petNeonDropdown:Set({
                        '',
                    })

                    return
                end,
            })

            TradeTab:CreateSection('Send Custom Pet, sends ALL ages of selected pet')

            local inventoryTabs = {
                'pets',
                'food',
                'strollers',
                'pet_accessories',
                'gifts',
                'transport',
                'toys',
                'stickers',
            }
            local dropdowns = {}
            local selectedItems = {}
            local toggles = {}

            for _, tabName in ipairs(inventoryTabs)do
                dropdowns[tabName] = TradeTab:CreateDropdown({
                    Name = string.format('Select a %s', tostring(tabName)),
                    Options = {
                        '',
                    },
                    CurrentOption = {
                        '',
                    },
                    MultipleOptions = false,
                    Flag = 'Dropdown1',
                    Callback = function(Option)
                        selectedItems[tabName] = Option[1] or ''
                    end,
                })

                TradeTab:CreateButton({
                    Name = string.format('Refresh %s list', tostring(tabName)),
                    Callback = function()
                        dropdowns[tabName]:Refresh(GetInventory.TabId(tabName))
                    end,
                })

                toggles[tabName] = TradeTab:CreateToggle({
                    Name = string.format('Auto Trade Selected %s', tostring(tabName)),
                    CurrentValue = false,
                    Flag = 'Toggle1',
                    Callback = function(Value)
                        getgenv().auto_trade_custom = Value

                        while getgenv().auto_trade_custom do
                            Trade.SendTradeRequest({selectedPlayer})
                            Trade.SelectTabAndTrade(tabName, selectedItems[tabName])

                            local hasPets = Trade.AcceptNegotiationAndConfirm()

                            if not hasPets then
                                toggles[tabName]:Set(false)
                                Rayfield:Notify({
                                    Title = tostring(tabName:upper()),
                                    Content = 'Finished trading',
                                })
                            end

                            task.wait()
                        end
                    end,
                })

                TradeTab:CreateSection(' ')
            end

            local ageUpPotionTab = Window:CreateTab('Age Up Potion', 4483362458)
            local petToAge = ageUpPotionTab:CreateDropdown({
                Name = 'Select pet to age',
                Options = {
                    '',
                },
                CurrentOption = {
                    '',
                },
                MultipleOptions = false,
                Flag = 'Dropdown1',
                Callback = function(Options)
                    selectedAgeablePet = Options[1]
                end,
            })

            ageUpPotionTab:CreateSlider({
                Name = 'How many to age up',
                Range = {1, 100},
                Increment = 1,
                Suffix = 'Mega Pets',
                CurrentValue = 100,
                Flag = 'Slider1',
                Callback = function(Value)
                    selectedAgeableNumber = Value
                end,
            })
            ageUpPotionTab:CreateButton({
                Name = 'Refresh pet list',
                Callback = function()
                    petToAge:Refresh(GetInventory.GetAgeablePets())
                end,
            })
            ageUpPotionTab:CreateDivider()
            ageUpPotionTab:CreateButton({
                Name = 'START aging pet',
                Callback = function()
                    if cooldown then
                        return
                    end

                    cooldown = true

                    localPlayer:SetAttribute('StopFarmingTemp', true)
                    BulkPotion.StartAgingPets({
                        {
                            NameId = selectedAgeablePet,
                            MaxAmount = selectedAgeableNumber,
                        },
                    })
                    task.wait(1)
                    localPlayer:SetAttribute('StopFarmingTemp', false)

                    cooldown = false
                end,
            })
        end

        function self.Init() end
        function self.Start()
            setupRayfield()
            Rayfield:SetVisibility(false)
        end

        return self
    end
    function __DARKLUA_BUNDLE_MODULES.t()
        local ReplicatedStorage = (cloneref(game:GetService('ReplicatedStorage')))
        local Workspace = cloneref(game:GetService('Workspace'))
        local Players = cloneref(game:GetService('Players'))
        local Ailment = {}
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = (Bypass('ClientData'))
        local RouterClient = (Bypass('RouterClient'))
        local MysteryAilmentClient = (require(ReplicatedStorage.new.modules.Ailments.ClientActions.MysteryAilmentClient))
        local MysteryHelper = (require(ReplicatedStorage.new.modules.Ailments.Helpers.MysteryHelper))
        local Utils = __DARKLUA_BUNDLE_MODULES.load('a')
        local GetInventory = __DARKLUA_BUNDLE_MODULES.load('i')
        local Teleport = __DARKLUA_BUNDLE_MODULES.load('f')
        local localPlayer = Players.LocalPlayer
        local doctorId = nil

        Ailment.whichPet = 1

        local retryCount = 0
        local MAX_RETRIES = 3
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

                    ReplicatedStorage.API['PetObjectAPI/CreatePetObject']:InvokeServer('__Enum_PetObjectCreatorType_2', {
                        ['pet_unique'] = ClientData.get('pet_char_wrappers')[Ailment.whichPet].pet_unique,
                        ['unique_id'] = v.unique,
                    })
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

            local playerData = ClientData.get_data()[localPlayer.Name]
            local petObject = playerData and playerData.pet_char_wrappers[1]
            local mysteryData = playerData and playerData.ailments_manager.ailments[petUnique][mysteryId]

            if not mysteryData then
                Utils.PrintDebug('Doesnt have mysteryData')

                return
            end

            for i, ailment in MysteryAilmentClient._get_ailment_slots(MysteryHelper.get_action(mysteryData), petObject)do
                Utils.PrintDebug(string.format('\u{2705} card: %s, ailment: %s \u{2705}', tostring(i), tostring(ailment)))
                ReplicatedStorage.API['AilmentsAPI/ChooseMysteryAilment']:FireServer(petUnique, 'mystery', i, ailment)

                break
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

                retryCount = retryCount + 1

                if retryCount >= MAX_RETRIES then
                    localPlayer:Kick('GOT STUCK')
                    game:Shutdown()
                end

                return false
            else
                retryCount = 0

                Utils.PrintDebug(string.format('\u{1f389} %s task finished \u{1f389}', tostring(ailment)))

                return true
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
                waitForTaskToFinish('toilet', petUnique)
            else
                Utils.PrintDebug('\u{26d4} NO toilet so skipping \u{26d4}')
            end
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
        function Ailment.HalloweenWalkAilment(petUnique)
            Utils.ReEquipPet(Ailment.whichPet)
            Utils.PrintDebug(string.format('\u{1f9ae} Doing walking task on %s \u{1f9ae}', tostring(Ailment.whichPet)))

            if not Utils.IsPetEquipped(Ailment.whichPet) then
                return
            end

            ReplicatedStorage.API['AdoptAPI/HoldBaby']:FireServer(ClientData.get('pet_char_wrappers')[Ailment.whichPet]['char'])
            waitForJumpingToFinish('wear_scare', petUnique)

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
                Utils.PrintDebug("\u{26a0}\u{fe0f} Doesn't have squeaky_bone so exiting \u{26a0}\u{fe0f}")

                return false
            end

            local count = 0

            repeat
                Utils.PrintDebug('\u{1f9b4} Throwing toy \u{1f9b4}')
                ReplicatedStorage.API:FindFirstChild('PetObjectAPI/CreatePetObject'):InvokeServer('__Enum_PetObjectCreatorType_1', {
                    ['reaction_name'] = 'ThrowToyReaction',
                    ['unique_id'] = toyId,
                })
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
        function Ailment.IceSkating(petUnique)
            Utils.PrintDebug(string.format('\u{26f8} Doing ice_skating on %s \u{26f8}', tostring(Ailment.whichPet)))
            Teleport.GingerbreadCollectionCircle()
            setfpscap(1)
            task.wait(2)
            Utils.ReEquipPet(Ailment.whichPet)
            waitForTaskToFinish('ice_skating', petUnique)
            setfpscap(getgenv().SETTINGS.SET_FPS or 2)
        end
        function Ailment.DanceAtDisco(petUnique)
            Utils.PrintDebug(string.format('\u{1f57a} Doing dance_at_the_disco on %s \u{1f57a}', tostring(Ailment.whichPet)))
            Teleport.SpinningDome()
            setfpscap(1)
            task.wait(2)
            Utils.ReEquipPet(Ailment.whichPet)
            waitForTaskToFinish('dance_at_the_disco', petUnique)
            setfpscap(getgenv().SETTINGS.SET_FPS or 2)
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
            task.spawn(function()
                ReplicatedStorage.API:FindFirstChild('HousingAPI/ActivateInteriorFurniture'):InvokeServer(key, 'Guitar', {
                    ['cframe'] = CFrame.new(-607, 35, -1641, -0, -0, -1, 0, 1, -0, 1, -0, -0),
                }, localPlayer.Character)
            end)
            waitForTaskToFinish('buccaneer_band', petUnique)
            getUpFromSitting()
        end
        function Ailment.Popcorn()
            Utils.PrintDebug('\u{1f37f} Doing popcorn task \u{1f37f}')

            for i = 1, 6 do
                RouterClient.get('HalloweenEventAPI/ClaimLilyPadCandy'):FireServer(i)
                print(string.format('Claimed lilypad candy %s', tostring(i)))
                task.wait(1)
            end
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
    function __DARKLUA_BUNDLE_MODULES.u()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local RouterClient = Bypass('RouterClient')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('a')
        local GetInventory = __DARKLUA_BUNDLE_MODULES.load('i')
        local Fusion = __DARKLUA_BUNDLE_MODULES.load('h')
        local FarmingPet = {}
        local localPlayer = Players.LocalPlayer
        local petToBuy = 'aztec_egg_2025_aztec_egg'
        local potionFarmPets = {
            '2d_kitty',
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
            local pets = ClientData.get('pet_char_wrappers')
            local equippedPet = pets and pets[1]

            if not equippedPet then
                if not Utils.Equip(getgenv().petCurrentlyFarming1, false) then
                    return false
                end
                if not Utils.WaitForPetToEquip() then
                    return false
                end
            end

            pets = ClientData.get('pet_char_wrappers')
            equippedPet = pets and pets[1]

            local petId = equippedPet and equippedPet.pet_id

            return petId ~= nil and table.find(potionFarmPets, petId) ~= nil
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
                if v.id == petToBuy and v.id ~= 'practice_dog' and v.properties.age ~= 6 and not v.properties.mega_neon then
                    RouterClient.get('ToolAPI/Equip'):InvokeServer(v.unique, {
                        ['use_sound_delay'] = true,
                    })

                    getgenv().petCurrentlyFarming1 = v.unique

                    return true
                end
            end

            local BuyEgg = RouterClient.get('ShopAPI/BuyItem'):InvokeServer('pets', petToBuy, {})

            if BuyEgg == 'too little money' then
                return false
            end

            return false
        end

        function FarmingPet.SetFarmingTable(pets)
            if typeof(pets) ~= 'table' then
                print('the pets is not a table')

                return
            end

            potionFarmPets = pets
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

                print('trying to see if 2d kitty')

                if GetInventory.CheckForPetAndEquip({
                    '2d_kitty',
                }, whichPet) then
                    print('FOUND 2d kitty', whichPet)

                    return
                end

                task.wait(1)
                Utils.PrintDebug(string.format('\u{1f414}\u{1f414} Getting pet to farm age up potion, %s \u{1f414}\u{1f414}', tostring(whichPet)))

                if GetInventory.CheckForPetAndEquip({
                    'starter_egg',
                }, whichPet) then
                    return
                end

                task.wait(1)
                Utils.PrintDebug(string.format('\u{1f414}\u{1f414} No starter egg found, trying dog or cat %s \u{1f414}\u{1f414}', tostring(whichPet)))

                if GetInventory.GetPetFriendship(potionFarmPets, whichPet) then
                    return
                end

                task.wait(1)
                Utils.PrintDebug(string.format('\u{1f414}\u{1f414} No friendship pet. checking if pet without friend exist %s \u{1f414}\u{1f414}', tostring(whichPet)))

                if GetInventory.CheckForPetAndEquip(potionFarmPets, whichPet) then
                    return
                end

                task.wait(1)

                if GetInventory.CheckForPetAndEquip({
                    'cracked_egg',
                }, whichPet) then
                    return
                end

                task.wait(1)
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
            end
            if getgenv().SETTINGS.PET_ONLY_PRIORITY then
                if GetInventory.PriorityPet(whichPet) then
                    return
                end
            end
            if GetInventory.GetNeonPet(whichPet) then
                return
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
            Utils.PrintDebug('Getting Task Board Pet')

            if not Utils.IsPetEquipped(whichPet) then
                FarmingPet.GetPetToFarm(whichPet)
            end

            for _, v in ClientData.get('quest_manager')['quests_cached']do
                if v['entry_name']:match('house_pets_2025_potion_drank') then
                    for _, food in ClientData.get_data()[localPlayer.Name].inventory.food do
                        if food['id'] == 'pet_grow_potion' then
                            Utils.PrintDebug('Found potion, using it')
                            Utils.CreatePetObject(food['unique'])

                            return true
                        end
                    end

                    if Utils.BucksAmount() >= 10000 then
                        Utils.PrintDebug('Buying grow potion')
                        RouterClient.get('ShopAPI/BuyItem'):InvokeServer('food', 'pet_grow_potion', {buy_count = 1})
                        task.wait(1)
                    end
                end
            end
            for _, v in ClientData.get('quest_manager')['quests_cached']do
                if v['entry_name']:match('house_pets_2025_small_hatch_egg') or v['entry_name']:match('house_pets_2025_medium_hatch_egg') then
                    Utils.PrintDebug('Buying Farming Egg')

                    if farmEgg() then
                        return true
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
    function __DARKLUA_BUNDLE_MODULES.v()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local Utils = __DARKLUA_BUNDLE_MODULES.load('a')
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local RouterClient = Bypass('RouterClient')
        local ClientData = Bypass('ClientData')
        local localPlayer = Players.LocalPlayer
        local PetRelease = {}
        local getPetRecyclerId = function()
            RouterClient.get('LocationAPI/SetLocation'):FireServer('Nursery')
            task.wait(1)

            for key, value in ClientData.get_data()[localPlayer.Name].house_interior.furniture do
                if value.id == 'pet_recycler' then
                    return key
                end
            end

            return nil
        end

        function PetRelease.Use(petUniques)
            local recyclerId = getPetRecyclerId()

            if not recyclerId then
                return
            end

            RouterClient.get('HousingAPI/ActivateInteriorFurniture'):InvokeServer(recyclerId, 'UseBlock', {
                action = 'use',
                uniques = petUniques,
            }, Utils.GetCharacter())
            Utils.PrintDebug('Added Pets To Release')
        end
        function PetRelease.Claim()
            local recyclerId = getPetRecyclerId()

            if not recyclerId then
                return
            end

            RouterClient.get('HousingAPI/ActivateInteriorFurniture'):InvokeServer(recyclerId, 'UseBlock', {
                action = 'claim',
            }, Utils.GetCharacter())
            Utils.PrintDebug('Claimed Eggs from Release pets')
        end

        return PetRelease
    end
    function __DARKLUA_BUNDLE_MODULES.w()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local RouterClient = Bypass('RouterClient')
        local CollisionsClient = Bypass('CollisionsClient')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('a')
        local Ailment = __DARKLUA_BUNDLE_MODULES.load('t')
        local Furniture = __DARKLUA_BUNDLE_MODULES.load('b')
        local Teleport = __DARKLUA_BUNDLE_MODULES.load('f')
        local GetInventory = __DARKLUA_BUNDLE_MODULES.load('i')
        local FarmingPet = __DARKLUA_BUNDLE_MODULES.load('u')
        local Fusion = __DARKLUA_BUNDLE_MODULES.load('h')
        local PetRelease = __DARKLUA_BUNDLE_MODULES.load('v')
        local modules = ReplicatedStorage:WaitForChild('new'):WaitForChild('modules')
        local DailiesNetService = (require(modules:WaitForChild('Dailies'):WaitForChild('DailiesNetService')))
        local self = {}
        local localPlayer = Players.LocalPlayer
        local jobId = game.JobId
        local baitboxCount = 0
        local strollerId = GetInventory.GetUniqueId('strollers', 'stroller-default')
        local tryToReleasePets = function()
            if getgenv().SETTINGS.ENABLE_RELEASE_PETS == false then
                return
            end

            local success, result = pcall(function()
                PetRelease.Claim()
                task.wait(1)
                PetRelease.Use(GetInventory.GetPetsToRelease())
            end)

            if not success then
                Utils.PrintDebug(string.format('tryToReleasePets errored: %s', tostring(result)))
            end
        end
        local tryFeedAgePotion = function()
            if localPlayer:GetAttribute('StopFarmingTemp') == true then
                return
            end
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
                    if Furniture.items.piano == 'nil' then
                        continue
                    end

                    Ailment.BabyBoredAilment(Furniture.items.piano)

                    return
                elseif key == 'sleepy' then
                    if Furniture.items.basiccrib == 'nil' then
                        continue
                    end

                    Ailment.BabySleepyAilment(Furniture.items.basiccrib)

                    return
                elseif key == 'dirty' then
                    if Furniture.items.stylishshower == 'nil' then
                        continue
                    end

                    Ailment.BabyDirtyAilment(Furniture.items.stylishshower)

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
                    if Furniture.items.piano == 'nil' then
                        continue
                    end

                    Ailment.BoredAilment(Furniture.items.piano, petUnique)

                    return true
                elseif key == 'sleepy' then
                    if Furniture.items.basiccrib == 'nil' then
                        continue
                    end

                    Ailment.SleepyAilment(Furniture.items.basiccrib, petUnique)

                    return true
                elseif key == 'dirty' then
                    if Furniture.items.stylishshower == 'nil' then
                        continue
                    end

                    Ailment.DirtyAilment(Furniture.items.stylishshower, petUnique)

                    return true
                elseif key == 'walk' then
                    Ailment.WalkAilment(petUnique)

                    return true
                elseif key == 'toilet' then
                    if Furniture.items.ailments_refresh_2024_litter_box == 'nil' then
                        continue
                    end

                    Ailment.ToiletAilment(Furniture.items.ailments_refresh_2024_litter_box, petUnique)

                    return true
                elseif key == 'ride' then
                    Ailment.RideAilment(strollerId, petUnique)

                    return true
                elseif key == 'play' then
                    if not Ailment.PlayAilment(key, petUnique) then
                        return false
                    end

                    return true
                elseif key == 'wear_scare' then
                    Ailment.HalloweenWalkAilment(petUnique)

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
            if game.JobId ~= jobId then
                getgenv().SETTINGS.ENABLE_AUTO_FARM = false

                Utils.PrintDebug(' \u{26d4} not same jobid so exiting \u{26d4}')
                task.wait(30)
                localPlayer:Kick('GOT STUCK')
                game:Shutdown()

                return
            end
            if localPlayer:GetAttribute('StopFarmingTemp') == true then
                local count = 0
                local COUNT_MAX = 300

                repeat
                    print('Stopping because its in minigame')

                    count = count + 30

                    task.wait(30)
                until localPlayer:GetAttribute('StopFarmingTemp') == false or count >= COUNT_MAX

                if Utils.IsMuleInGame(getgenv().SETTINGS.TRADE_COLLECTOR_NAME) then
                    repeat
                        print('Waiting for mule to leave game...')
                        task.wait(60)
                    until not Utils.IsMuleInGame(getgenv().SETTINGS.TRADE_COLLECTOR_NAME)
                elseif count >= COUNT_MAX then
                    localPlayer:Kick('GOT STUCK')
                    game:Shutdown()
                end
            end

            Utils.RemoveHandHeldItem()

            if getgenv().SETTINGS.HATCH_EGG_PRIORITY then
                FarmingPet.CheckIfEgg(1)
                task.wait(1)
            end
            if getgenv().SETTINGS.FOCUS_FARM_AGE_POTION then
                FarmingPet.GetPetToFarm(1)
            end

            Utils.WaitForHumanoidRootPart().Anchored = false

            if not completePetAilments(1) then
                task.wait()
                completeBabyAilments()
            end

            task.wait(1)

            if not getgenv().SETTINGS.FOCUS_FARM_AGE_POTION then
                FarmingPet.SwitchOutFullyGrown(1)
            end
            if baitboxCount > 180 then
                if localPlayer:GetAttribute('StopFarmingTemp') == false then
                    local baitUnique = Utils.FindBait()

                    Utils.PlaceBaitOrPickUp(Furniture.items.lures_2023_normal_lure, baitUnique)
                    task.wait(2)
                    Utils.PlaceBaitOrPickUp(Furniture.items.lures_2023_normal_lure, baitUnique)

                    baitboxCount = 0

                    tryToReleasePets()
                    Teleport.FarmingHome()
                end
            end

            tryFeedAgePotion()

            baitboxCount = baitboxCount + 5

            task.wait(5)
        end

        function self.Init()
            RouterClient.get('PayAPI/DisablePopups'):FireServer()
            RouterClient.get('WeatherAPI/WeatherUpdated').OnClientEvent:Connect(function(
                dayOrNight
            )
                task.wait(2)

                if dayOrNight == 'NIGHT' then
                    DailiesNetService.try_to_claim_daily_rewards('vanilla')
                    task.wait(1)
                    DailiesNetService.try_to_claim_tab_reward('vanilla')
                end
                if Utils.IsDayAndHour('Tuesday', 21) then
                    print('SWITCHED TO 2d_kitty BECAUSE ITS EVENT TIME')
                    localPlayer:SetAttribute('IsTuesdayEvent', true)
                    DailiesNetService.try_to_claim_daily_rewards('2d_tuesdays')
                    FarmingPet.SetFarmingTable({
                        '2d_kitty',
                    })

                    return
                end

                local potionFarmPets = {
                    '2d_kitty',
                    'dog',
                    'cat',
                    'starter_egg',
                    'cracked_egg',
                    'basic_egg_2022_ant',
                    'basic_egg_2022_mouse',
                }

                FarmingPet.SetFarmingTable(potionFarmPets)
                localPlayer:SetAttribute('IsTuesdayEvent', false)
            end)
        end
        function self.Start()
            RouterClient.get('HousingAPI/ClaimAllDeliveries'):FireServer()
            DailiesNetService.try_to_claim_daily_rewards('2d_tuesdays')

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
            tryToReleasePets()
            Utils.UnEquipAllPets()
            task.wait(2)
            FarmingPet.GetPetToFarm(1)
            task.wait(2)
            task.delay(30, function()
                local UpdateTextEvent = (ReplicatedStorage:WaitForChild('UpdateTextEvent'))

                while getgenv().SETTINGS.ENABLE_AUTO_FARM do
                    getgenv().lastTimeFarming = DateTime.now().UnixTimestamp

                    local success, result = pcall(function()
                        startAutoFarm()
                        UpdateTextEvent:Fire()
                    end)

                    if not success then
                        print(string.format('\u{26d4} AutoFarm Errored: %s \u{26d4}', tostring(result)))

                        return
                    end

                    task.wait(1)
                end
            end)
        end

        return self
    end
    function __DARKLUA_BUNDLE_MODULES.x()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local RouterClient = Bypass('RouterClient')
        local ClientData = Bypass('ClientData')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('a')
        local PetOffline = {}
        local localPlayer = Players.LocalPlayer

        function PetOffline.AddPet(petId)
            RouterClient.get('IdleProgressionAPI/AddPet'):FireServer(petId)
            Utils.PrintDebug('Added pet to offline farming: ' .. petId)
        end
        function PetOffline.RemovePet(petId)
            RouterClient.get('IdleProgressionAPI/RemovePet'):FireServer(petId)
        end
        function PetOffline.ClaimAllXP()
            RouterClient.get('IdleProgressionAPI/CommitAllProgression'):FireServer()
            Utils.PrintDebug('Claimed all XP')
        end
        function PetOffline.GetAmountOfPetsInPen()
            local count = 0

            for _, _ in ClientData.get_data()[localPlayer.Name].idle_progression_manager.active_pets do
                count = count + 1
            end

            return count
        end

        return PetOffline
    end
    function __DARKLUA_BUNDLE_MODULES.y()
        local ReplicatedStorage = game:GetService('ReplicatedStorage')
        local Players = game:GetService('Players')
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ClientData = Bypass('ClientData')
        local RouterClient = (Bypass('RouterClient'))
        local PetOffline = __DARKLUA_BUNDLE_MODULES.load('x')
        local GetInventory = __DARKLUA_BUNDLE_MODULES.load('i')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('a')
        local PetOfflineHandler = {}
        local localPlayer = Players.LocalPlayer
        local CurrentIdlePets = {}
        local updateCurrentIdlePets = function()
            table.clear(CurrentIdlePets)

            for key, value in ClientData.get_data()[localPlayer.Name].idle_progression_manager.active_pets do
                table.insert(CurrentIdlePets, key)
            end
        end
        local removeAllPets = function()
            for key, _ in ClientData.get_data()[localPlayer.Name].idle_progression_manager.active_pets do
                while true do
                    PetOffline.RemovePet(key)
                    task.wait(1)

                    if ClientData.get_data()[localPlayer.Name].idle_progression_manager.active_pets[key] == nil then
                        break
                    end
                end
            end
        end
        local addPet = function(petUniques)
            if #petUniques <= 0 then
                return
            end

            for _, unique in ipairs(petUniques)do
                if PetOffline.GetAmountOfPetsInPen() >= 4 then
                    return
                end

                local count = 0

                while true do
                    PetOffline.AddPet(unique)
                    task.wait(1)

                    if ClientData.get_data()[localPlayer.Name].idle_progression_manager.active_pets[unique] then
                        break
                    end

                    count = count + 1

                    if count >= 10 then
                        Utils.PrintDebug('Failed to add pet to idle farming: ' .. unique)

                        break
                    end
                end
            end
        end
        local addRarityPetsToPen = function(rarityName)
            local amount = PetOffline.GetAmountOfPetsInPen()
            local amountMissing = 4 - amount

            if amountMissing <= 0 then
                return true
            end

            print(string.format('AMOUNT MISSING: %s, %s', tostring(amountMissing), tostring(rarityName)))

            local petUniques = GetInventory.GetPetsRarityAndAgeForPen(rarityName)

            addPet(petUniques)
            task.wait(1)

            return false
        end
        local addPetEggsToPen = function()
            local amount = PetOffline.GetAmountOfPetsInPen()
            local amountMissing = 4 - amount

            if amountMissing <= 0 then
                return true
            end

            print(string.format('AMOUNT MISSING: %s, eggs', tostring(amountMissing)))

            local eggsList = GetInventory.GetPetEggs()
            local eggIndex = table.find(eggsList, 'pet_recycler_2025_crystal_egg')

            if eggIndex then
                table.remove(eggsList, eggIndex)
            end

            local petUniques = GetInventory.GetPetUniquesForPetPen(eggsList, amountMissing)

            addPet(petUniques)
            task.wait(1)

            return false
        end
        local addAllPetsToidleFarm = function(amountMissing)
            updateCurrentIdlePets()

            local petUniques = GetInventory.GetPetUniquesForPetPen(getgenv().SETTINGS.PETS_TO_AGE_IN_PEN, amountMissing)

            Utils.PrintDebug(string.format('how many pets ids ther is in table: %s', tostring(#petUniques)))
            addPet(petUniques)

            if addRarityPetsToPen('legendary') then
                return
            end
            if addRarityPetsToPen('ultra_rare') then
                return
            end
            if addRarityPetsToPen('rare') then
                return
            end
            if addRarityPetsToPen('uncommon') then
                return
            end
            if addRarityPetsToPen('common') then
                return
            end
            if addPetEggsToPen() then
                return
            end
        end

        function PetOfflineHandler.Init()
            if getgenv().SETTINGS.ENABLE_AUTO_FARM == false then
                return
            end

            RouterClient.get('DataAPI/DataChanged').OnClientEvent:Connect(function(
                playerName,
                dataType,
                data
            )
                if playerName ~= localPlayer.Name then
                    return
                end
                if dataType ~= 'idle_progression_manager' then
                    return
                end
                if not data then
                    return
                end
                if not data.age_up_pending then
                    return
                end

                Utils.PrintDebug('Age up pending, claiming all XP...')
                PetOffline.ClaimAllXP()
                task.wait(2)
                removeAllPets()

                local amount = PetOffline.GetAmountOfPetsInPen()
                local amountMissing = 4 - amount

                if amountMissing <= 0 then
                    return
                end

                Utils.PrintDebug(string.format('amount missing: %s so getting more', tostring(amountMissing)))
                addAllPetsToidleFarm(amountMissing)
            end)
        end
        function PetOfflineHandler.Start()
            if getgenv().SETTINGS.ENABLE_AUTO_FARM == false then
                return
            end

            PetOffline.ClaimAllXP()
            task.wait(2)
            removeAllPets()
            addAllPetsToidleFarm(4)
        end

        return PetOfflineHandler
    end
    function __DARKLUA_BUNDLE_MODULES.z()
        local Players = cloneref(game:GetService('Players'))
        local Utils = __DARKLUA_BUNDLE_MODULES.load('a')
        local StatsGuiClass = {}

        StatsGuiClass.__index = StatsGuiClass

        local localPlayer = Players.LocalPlayer
        local hud = localPlayer:WaitForChild('PlayerGui')

        Utils.PrintDebug(string.format('hud: %s', tostring(hud)))

        local otherGuis = {}
        local DEFAULT_COLOR = Color3.fromRGB(71, 70, 70)
        local setButtonUiSettings = function(buttonSettings)
            local button = Instance.new('TextButton')

            button.Name = buttonSettings.Name
            button.AnchorPoint = buttonSettings.AnchorPoint
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
            blackFrame.Visible = false
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
                button.Text = '\u{2705}'

                buttonSettings.Callback()
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

                self.TextLabel.Text = string.format('\u{1f36a} %s', tostring(formatted))
            elseif self.TextLabel.Name == 'CrystalEgg' then
                local formatted = Utils.FormatNumber(Utils.PetItemCount('pet_recycler_2025_crystal_egg'))

                self.TextLabel.Text = string.format('\u{1f95a} %s', tostring(formatted))
            elseif self.TextLabel.Name == 'GiantPanda' then
                local formatted = Utils.FormatNumber(Utils.PetItemCount('pet_recycler_2025_giant_panda'))

                self.TextLabel.Text = string.format('\u{1f43c} %s', tostring(formatted))
            elseif self.TextLabel.Name == 'Slot11' then
                local formatted = Utils.FormatNumber(Utils.PetItemCount('winter_2025_snowball_pug'))

                self.TextLabel.Text = string.format('\u{1f436} %s', tostring(formatted))
            elseif self.TextLabel.Name == 'Slot12' then
                local formatted = Utils.GetPugTamingProgress()

                self.TextLabel.Text = string.format('\u{1f9f6} %s%%', tostring(formatted))
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
                self.TextLabel.Text = string.format('\u{1f36a} %s', tostring(Utils.FormatNumber(amount)))
            end
        end

        return StatsGuiClass
    end
    function __DARKLUA_BUNDLE_MODULES.A()
        local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
        local Players = cloneref(game:GetService('Players'))
        local startTime = DateTime.now().UnixTimestamp
        local StatsGuiClass = __DARKLUA_BUNDLE_MODULES.load('z')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('a')
        local Clipboard = __DARKLUA_BUNDLE_MODULES.load('r')
        local self = {}
        local localPlayer = Players.LocalPlayer
        local HintApp = (localPlayer:WaitForChild('PlayerGui'):WaitForChild('HintApp'))
        local startPotionAmount
        local startTinyPotionAmount
        local startEventCurrencyAmount
        local potionsGained = 0
        local tinyPotionsGained = 0
        local bucksGained = 0
        local eventCurrencyGained = 0
        local UpdateTextEvent

        StatsGuiClass.Init()

        self.TempPotions = StatsGuiClass.new('TempPotions')
        self.TempTinyPotions = StatsGuiClass.new('TempTinyPotions')
        self.TempBucks = StatsGuiClass.new('TempBucks')
        self.TempEventCurrency = StatsGuiClass.new('TempEventCurrency')
        self.TotalPotions = StatsGuiClass.new('TotalPotions')
        self.TotalTinyPotions = StatsGuiClass.new('TotalTinyPotions')
        self.TotalBucks = StatsGuiClass.new('TotalBucks')
        self.TotalEventCurrency = StatsGuiClass.new('TotalEventCurrency')
        self.CrystalEgg = StatsGuiClass.new('CrystalEgg')
        self.GiantPanda = StatsGuiClass.new('GiantPanda')
        self.Slot11 = StatsGuiClass.new('Slot11')
        self.Slot12 = StatsGuiClass.new('Slot12')

        local updateAllStatsGui = function()
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
            self.CrystalEgg:UpdateTextForTotal()
            self.GiantPanda:UpdateTextForTotal()
            self.Slot11:UpdateTextForTotal()
            self.Slot12:UpdateTextForTotal()
        end

        function self.Init()
            UpdateTextEvent = Instance.new('BindableEvent')
            UpdateTextEvent.Name = 'UpdateTextEvent'
            UpdateTextEvent.Parent = ReplicatedStorage

            StatsGuiClass.CreateButton({
                Name = 'CopyDetailed',
                Text = '\u{1f4cb}',
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Callback = function()
                    setclipboard(Clipboard.CopyDetailedPetInfo())
                end,
            })

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
            task.spawn(function()
                while true do
                    StatsGuiClass.SetTimeLabelText(startTime)
                    task.wait(5)
                end
            end)
        end
        function self.Start()
            UpdateTextEvent:Fire()
        end

        return self
    end
    function __DARKLUA_BUNDLE_MODULES.B()
        return {
            '{29580925-384D-4CF6-810A-5B2FBEBE14EF}',
            '{AFFECD3D-9FCD-4822-BDF8-1B7F589620DD}',
            '{F8FAEF3D-A8EC-4FC6-B6DA-9900D9F01089}',
            '{53C81678-DDD1-410F-9476-0A1AFD17B22D}',
            '{96EB009D-84A2-464B-925E-41E269B5D7E4}',
            '{C61B5F35-B5E6-4DDE-B9CA-8C5CDE82D3F5}',
            '{FE0C85D8-2E11-46BA-BE97-9EC67E96ABB8}',
            '{487EE748-30B2-40A5-AEAC-2724E29C6C6D}',
            '{54E9E593-8C0E-4120-9637-83B0BA891573}',
            '{28F6FD49-55C2-4E45-88F3-E62344AEE010}',
            '{94D2643C-32DC-4D5F-9350-BA5BD54BCA23}',
            '{4B0E202F-743E-46C3-A538-CAAABE3D6A76}',
            '{0447C188-1620-4CE4-897D-E34CDBE3F30D}',
            '{374FCE6C-D73A-4E68-AA7F-8954D47A913E}',
            '{0F4D8710-8B26-4D9C-92EC-FFAB5CFEDA15}',
            '{D85AC2E0-131F-4316-B8CF-0CD0BFAC639D}',
            '{5926D161-4B98-4901-8A66-6178F21B616C}',
            '{1479F2D4-D712-4B53-8B24-546270239BE7}',
            '{45E5C75E-DB43-4196-9B2A-6A3C044C6095}',
            '{600EB06A-F13D-411D-BEB3-E04E93ED4276}',
            '{FD6318F0-8A5F-41CF-9B91-64EBBBCB3E98}',
            '{B0390D1A-AAFF-45F9-823E-9DBF1EE671DF}',
            '{D1B20364-78F5-4CCC-A510-E40A8D625D16}',
            '{F72AED52-624E-43BA-AF8E-7C3C311B93D7}',
            '{0836BB00-2107-49A6-8544-72FC3EECC742}',
            '{2883E3B9-AEB4-4577-A1E6-D75BD7D00042}',
            '{8B70133A-0EDA-439B-B41D-26B9EE5B824D}',
            '{5FD5BDBD-5847-4EFD-9DF1-0AB7B94A3548}',
            '{F72BD7C6-B22D-4E5C-AA9C-C0FE8F034E43}',
            '{B6510D79-459E-40A7-88A1-06EECF7DFEDD}',
            '{850FA732-1759-41FD-8D11-A966F663DC54}',
            '{A76214EC-C75E-4E91-B515-32CF008CA73F}',
            '{11496169-8138-4EB2-9883-9F0453297D84}',
            '{D356DB30-2CDC-48D8-AB28-F9E1C4C8E82D}',
            '{51E924AC-12DF-46F8-A77C-C2756C38AD3B}',
            '{A33B95DC-4636-4FB9-81E1-098C819359A8}',
            '{0DBD86AB-EDAD-4C5F-B64A-E879935418FD}',
            '{69372C32-4F4E-4786-B973-36405115DC84}',
            '{C4194D7B-54B5-4B35-B262-1B700143DB56}',
            '{1F5105D1-7F27-4C3F-88F8-DAB5AC6F80A7}',
            '{5A651C27-4680-40DB-968C-71B89B56F3D0}',
            '{B6709EA9-0B13-47F5-9022-524426FC2B20}',
            '{71CB1A2A-6433-496F-A75D-79B57EA2020D}',
            '{45912694-2CF8-4B46-9222-B4E052EC74FC}',
            '{A6C07949-FE1D-4C8A-9234-782981398813}',
            '{CC47FF49-48FD-444E-8F70-BFB36EB4E1DE}',
            '{6C05E92C-38EB-4033-B610-4503E5262FDF}',
            '{7A2585D3-0477-40CD-B6FF-BD781A3B5777}',
            '{248879AA-6B47-4BCF-AFC0-161C2EBFF6AD}',
            '{537FCB8D-0868-463D-B2A1-A85E3F9507A3}',
            '{8897445D-6138-4BD6-8DA1-1F02ECFE5898}',
            '{4112DDAB-4A73-4C16-A75C-DD260D6D0155}',
            '{65EF0557-0D8E-4B74-AFD8-FC5DB243EDB8}',
            '{39592C2B-0CC3-4BDD-9E64-00846F06C629}',
            '{14F3C7DB-D67E-4288-9D94-AB33653FD928}',
            '{DD193776-16EC-4550-B696-19E19CE313D4}',
            '{4FE802B6-9D8D-4CAA-B07A-775154792D1A}',
            '{87A78497-E137-47E5-AE8A-5E4C0F30D90A}',
            '{63E116B6-1955-4B06-B28F-3113E0760583}',
            '{08D592C6-8F94-435E-98CD-D038E23CF236}',
            '{F0B27251-FFE7-4A70-9077-80D73E10BD1E}',
            '{439925AF-0A96-40F3-8707-D5A65AA605AF}',
            '{381C38F4-4B07-4F2E-A12E-AF6328F96A54}',
            '{25DA2E1D-7191-4B7F-AB26-5EFECB267307}',
            '{154F7871-BCA0-4691-9210-AD6D76103119}',
            '{808A9B20-FA50-412A-9A5D-D728B1D355A9}',
            '{AE2F9B5B-589F-4A12-B4A5-0912FFE8C463}',
            '{04A431CF-78AD-4200-9B3E-8DA02A6DA347}',
            '{F0F44CAC-FF90-4B94-A996-5094CECF1531}',
            '{081D2B7B-79A6-4330-93EC-C36DF19BBC93}',
            '{24236D55-6152-4783-B736-9CAA56F6F655}',
            '{33430CD2-A47B-4987-ACEA-5EA4ABF9AAE0}',
            '{48BB1D7E-0B33-4171-A423-A911FE9A4972}',
            '{177D7587-F672-49D5-85D1-090AA2AAAB29}',
            '{1B7E9043-B129-4341-BDB9-FA83CE503F5C}',
            '{82B7AF91-D7FD-48D5-BEA1-A7048595647E}',
            '{1A218809-DBE4-4542-80B2-2B585D33CEC6}',
            '{449145AC-B3DC-4FDD-9C9F-5FFF5F2FA183}',
            '{4A3B540E-FC78-4095-AFDA-F560F263AD13}',
            '{8F6C3881-F732-42C9-936A-5852D3A194B4}',
            '{084B9A25-9B24-461B-8FEB-1A071D2800FB}',
            '{6F890B4D-2BB8-446F-A492-21C61EC7D36D}',
            '{9B4F9569-4463-47AB-B753-0DBF64B56883}',
            '{30189A3D-F6CE-4B86-A19C-C71E64541796}',
            '{2FAC02AF-1E80-4890-BC34-C5D8F22F12F2}',
            '{6147E9F3-8FDA-45AF-AF7B-96245CA32096}',
            '{AB788250-8C62-45AF-BE63-6493F5363116}',
            '{8743B7A9-257B-48DF-8DB0-0F4FD057A4B0}',
            '{3C929F9E-9C60-4844-B6A6-C5AB16B89030}',
            '{2FA1E614-9B22-495E-8543-A28A449662C0}',
            '{A5D4CB92-D091-41DF-A0F5-968778175398}',
            '{301B6795-D383-41BC-AB6C-6A4C4CAA8EDF}',
            '{5E5EAA7A-C7C4-4AB0-AB22-DBFD967098BF}',
            '{0217C4CB-EBE3-4EAD-BAA8-801D1DD0BD8F}',
            '{6DEDCEB2-62B4-4259-BDFF-A3FA56DF71A7}',
            '{93479D49-84B0-4410-B39D-D2553FFFFCF0}',
            '{93F23433-BA8C-49CF-B1A8-D8FDA736623A}',
            '{FCE711AB-1097-47DF-AFD5-E3D8BA0B4BA5}',
            '{65E06DD8-CCCB-4DFC-ADED-EC29B7890D53}',
            '{1E4A9A9E-F945-4A6A-A777-EA765AC9892D}',
            '{8BEADFD7-FB96-4F3D-A2A3-32FC758A60CE}',
            '{D194622B-F101-47D3-8974-7610FB3830AE}',
            '{40D33237-E99B-4BA3-A0BE-7AEE3AD7B607}',
            '{2EEF9B08-10D5-40A6-B563-94FF012868D9}',
            '{677BBA18-0BDA-4A19-92F9-8C8DF6A11E30}',
            '{5C9A79E8-A97B-4DD9-8B8B-7DAD80B541E0}',
            '{505165ED-12ED-4FC3-8E0B-DE786471F388}',
            '{D5EBC9DB-8E7A-45AD-BF8F-F93703B61F20}',
            '{137708F4-430A-4C0D-A63C-B75A59C5EB2E}',
            '{832B63F3-FBA5-4380-99DB-78CFB9F87D6F}',
            '{27AE43F6-30C5-477C-BD53-2511CD23C5CA}',
            '{FC8810F5-8C12-46AC-9260-12E9276199B2}',
            '{E774C005-3B66-4736-8E35-421710DB25FB}',
            '{A2CBBB92-06FB-4CB3-A81F-6926203BD34E}',
            '{DEB255CE-6405-43A3-81AD-DCAA8A0A707C}',
            '{B097C8D5-6034-42F2-ABE1-4CEFE35E76FB}',
            '{FD974ABC-023F-4238-BB26-EA963179D61F}',
            '{60E33537-47D5-4212-958D-307C17501331}',
            '{316F5213-D48B-4F4B-8AFB-D18E44ACDDCB}',
            '{B484E83E-396E-4ACA-828E-0E1121708E88}',
            '{C8380520-D52C-46F1-A257-ADA9BC410E79}',
            '{20619AAB-74D9-4F8D-AB89-62DB4130C6A9}',
            '{EB9C2171-5D89-43AB-BA09-2F6439BF805D}',
            '{F11CFC7D-3222-4856-AB81-532ADB118D34}',
            '{50BC1E72-EE91-4332-B707-B24E1622A214}',
            '{437F2FA1-230F-498F-9276-DE0EF87C3AE1}',
            '{21119F02-5EB6-4308-B15A-AE086F9605EC}',
            '{FB967ED2-445C-4B78-8576-5D99AB7AA4B9}',
            '{81E888FB-BEF4-4F79-AE22-C5F438EF0E4E}',
            '{E58BFD84-62BE-4A62-A2C8-5D088FB0E6BF}',
            '{85A9AEA7-5427-4144-AFC1-12DCE9D5ECB7}',
            '{9989159C-CF88-4D53-A30D-037A337969D3}',
            '{569DD3EB-30D5-4CDD-85B6-5AA6C886D51C}',
            '{D0A52723-FF4A-40E5-A6B7-16FC57BF9B9E}',
            '{3DE5F28B-8893-4BD0-B742-6096E9DDEDB6}',
            '{ED15A0DF-DEA5-4EE5-91D4-568CF3D13D20}',
            '{9E8B22FE-410D-4005-8610-B5BEE9058A01}',
            '{6DAB765F-B559-4BB5-B70B-C868947D1C56}',
            '{4F764D10-CC2B-447E-9876-DC9259316804}',
            '{CF994B67-FA40-453E-ADEA-859E4B2C48A3}',
            '{D07D63E3-184C-41E1-9664-4DD8E26237C6}',
            '{DD2C92B9-881C-4128-B11D-A92E8873472E}',
            '{51F28E59-3CEC-46F4-84C3-5D6FD3FBCCF1}',
            '{80612A9C-FDE0-4CEE-B5F8-8B7DE2E9DC39}',
            '{A6482191-3E6B-45E0-B1F6-5BE8600C0D46}',
            '{069AFA82-D910-45A2-AF24-7F33E0237182}',
            '{40475233-9A85-4BE4-B20F-4C7A2C04C67E}',
            '{CBE7FE13-7C12-4469-8F0E-B32E7B224B20}',
            '{57CF0C2B-CB8F-430A-AE09-6A271E46447D}',
            '{1CA3C55C-E6FF-4632-B023-4AFABBD3175F}',
            '{5F3EECB5-14F4-4481-BA0D-86EED34D4597}',
            '{058EE9BE-D9A9-4660-9729-60E2FF891783}',
            '{0FBAF510-CE97-44B5-B5EE-43B31B642530}',
            '{E8749084-B9C2-4C1C-8DCA-8DD601B57E99}',
            '{9A475EE6-2AA9-407F-96B8-AFD73C904E9C}',
            '{1F104AAC-B4CF-4B9E-8ACA-C72F3B7601D7}',
            '{82062F93-CB93-48AF-9DEB-AB5385F67173}',
            '{F6D9E4BE-9433-4563-A10A-9E3684407E20}',
            '{2BEB302F-EB22-4403-B2E7-F4239A306A9C}',
            '{E8AD7C9A-C60C-4DE2-A111-A3E8AD26B1D0}',
        }
    end
    function __DARKLUA_BUNDLE_MODULES.C()
        local ReplicatedStorage = game:GetService('ReplicatedStorage')
        local Players = game:GetService('Players')
        local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
        local ContentPacks = (ReplicatedStorage:WaitForChild('SharedModules'):WaitForChild('ContentPacks'))
        local IceSkating = (ContentPacks:WaitForChild('Winter2025'):WaitForChild('Game'):WaitForChild('IceSkating'))
        local SleighballClient = (require(ContentPacks.Winter2025.Minigames.SleighballClient))
        local StarCatchMinigameClient = (require(ContentPacks.Winter2025.Minigames.StarCatchMinigameClient))
        local IceSkatingNet = (require(IceSkating:WaitForChild('IceSkatingNet')))
        local ginerbreadIds = __DARKLUA_BUNDLE_MODULES.load('B')
        local GetInventory = __DARKLUA_BUNDLE_MODULES.load('i')
        local RouterClient = Bypass('RouterClient')
        local ClientData = Bypass('ClientData')
        local Utils = __DARKLUA_BUNDLE_MODULES.load('a')
        local localPlayer = Players.LocalPlayer
        local PlayerGui = (localPlayer:WaitForChild('PlayerGui'))
        local StaticMap = (workspace:WaitForChild('StaticMap'))
        local MinigameInGameApp = (PlayerGui:WaitForChild('MinigameInGameApp'))
        local Christmas2025Handler = {}
        local tryCollectGingerbread = function()
            for _, v in ipairs(ginerbreadIds)do
                IceSkatingNet.PickUpGingerbread:fire_server({
                    interior_name = 'MainMap!Christmas',
                    gingerbread_id = v,
                })
                task.wait(0.1)
            end

            IceSkatingNet.RedeemPendingGingerbread:fire_server()
        end
        local tryExchangeGingerbread = function()
            local usesLeft = ClientData.get_data()[localPlayer.Name].winter_2025_manager.exchange_kiosk_uses_left

            if usesLeft == 0 then
                return
            end
            if Utils.BucksAmount() < 50000 then
                return
            end

            RouterClient.get('WinterEventAPI/UseExchangeKiosk'):InvokeServer()
        end
        local startSleighball = function()
            while SleighballClient.instanced_minigame do
                local teamColor = SleighballClient.instanced_minigame.team
                local giftsById = SleighballClient.instanced_minigame.gifts_by_id
                local gameFolder = SleighballClient.instanced_minigame.game_folder

                if SleighballClient.instanced_minigame.scores[teamColor] >= 10 then
                    break
                end

                local giftRoot = giftsById and giftsById[1] and giftsById[1].instance and giftsById[1].instance:FindFirstChild('Root')

                if giftRoot then
                    Utils.WaitForHumanoidRootPart().CFrame = giftRoot.CFrame

                    task.wait(0.1)

                    Utils.WaitForHumanoidRootPart().Anchored = true
                end

                local teamGoalPart = gameFolder and gameFolder:FindFirstChild('Goals') and gameFolder.Goals:FindFirstChild(teamColor .. 'Goal')

                if teamGoalPart then
                    Utils.WaitForHumanoidRootPart().CFrame = gameFolder.Goals[teamColor .. 'Goal'].CFrame

                    task.wait(0.1)

                    Utils.WaitForHumanoidRootPart().Anchored = true
                end

                task.wait(0.2)

                Utils.WaitForHumanoidRootPart().Anchored = false
            end

            Utils.WaitForHumanoidRootPart().Anchored = true

            while SleighballClient.instanced_minigame do
                task.wait(10)
            end

            print('LEFT MINIGAME Sleighball')
        end
        local tryTamePug = function()
            local yarnBait = GetInventory.GetUniqueId('food', 'winter_2025_yarn_beanie_bait')

            if not yarnBait then
                Utils.PrintDebug('No yarn bait found in inventory')

                return
            end

            RouterClient.get('WinterEventAPI/ProgressTaming'):InvokeServer(true)
        end
        local startStarCatch = function()
            local minigameId = StarCatchMinigameClient.instanced_minigame.minigame_id

            while StarCatchMinigameClient.instanced_minigame do
                local ingameAppController = StarCatchMinigameClient.instanced_minigame.ingame_app_controller

                if ingameAppController and ingameAppController.right_value >= 40 then
                    break
                end

                for _, v in StarCatchMinigameClient.instanced_minigame.stars do
                    if not v.boppable then
                        continue
                    end

                    local args = {
                        minigameId,
                        'bop_star',
                        v.id,
                        workspace:GetServerTimeNow(),
                    }

                    RouterClient.get('MinigameAPI/MessageServer'):FireServer(unpack(args))
                    task.wait(0.1)
                end

                task.wait()
            end
        end

        function Christmas2025Handler.Init()
            print('Initializing Christmas2025Handler')
            MinigameInGameApp:GetPropertyChangedSignal('Enabled'):Connect(function(
            )
                if MinigameInGameApp.Enabled then
                    if not MinigameInGameApp:WaitForChild('Body', 10) then
                        return
                    end
                    if not MinigameInGameApp.Body:WaitForChild('Middle', 10) then
                        return
                    end
                    if not MinigameInGameApp.Body.Middle:WaitForChild('Container', 10) then
                        return
                    end
                    if not MinigameInGameApp.Body.Middle.Container:WaitForChild('TitleLabel', 10) then
                        return
                    end
                    if MinigameInGameApp.Body.Middle.Container.TitleLabel.Text:match('SLEIGHBALL') then
                        if localPlayer:GetAttribute('hasStartedFarming') == true then
                            localPlayer:SetAttribute('StopFarmingTemp', true)
                            task.wait(10)
                            startSleighball()
                        end
                    elseif MinigameInGameApp.Body.Middle.Container.TitleLabel.Text:match('STARRY BOUNCE') then
                        if localPlayer:GetAttribute('hasStartedFarming') == true then
                            localPlayer:SetAttribute('StopFarmingTemp', true)
                            task.wait(10)
                            startStarCatch()
                        end
                    end
                end
            end)
            StaticMap.sleighball_minigame_state.is_game_active:GetPropertyChangedSignal('Value'):Connect(function(
            )
                if StaticMap.sleighball_minigame_state.is_game_active.Value then
                    if getgenv().SETTINGS.ENABLE_AUTO_FARM == false then
                        return
                    end
                    if localPlayer:GetAttribute('IsTuesdayEvent') == true then
                        return
                    end
                    if localPlayer:GetAttribute('hasStartedFarming') == false then
                        return
                    end
                    if localPlayer:GetAttribute('StopFarmingTemp') == true then
                        return
                    end

                    localPlayer:SetAttribute('StopFarmingTemp', true)
                    Bypass('RouterClient').get('MinigameAPI/AttemptJoin'):FireServer('sleighball', true)
                end
            end)
            StaticMap.star_catch_minigame_state.is_game_active:GetPropertyChangedSignal('Value'):Connect(function(
            )
                if StaticMap.star_catch_minigame_state.is_game_active.Value then
                    if getgenv().SETTINGS.ENABLE_AUTO_FARM == false then
                        return
                    end
                    if localPlayer:GetAttribute('IsTuesdayEvent') == true then
                        return
                    end
                    if localPlayer:GetAttribute('hasStartedFarming') == false then
                        return
                    end
                    if localPlayer:GetAttribute('StopFarmingTemp') == true then
                        return
                    end

                    localPlayer:SetAttribute('StopFarmingTemp', true)
                    Bypass('RouterClient').get('MinigameAPI/AttemptJoin'):FireServer('star_catch', true)
                end
            end)
        end
        function Christmas2025Handler.Start()
            tryCollectGingerbread()
            tryTamePug()
            RouterClient.get('WeatherAPI/WeatherUpdated').OnClientEvent:Connect(function(
                dayOrNight
            )
                task.wait(2)

                if dayOrNight == 'DAY' then
                    tryCollectGingerbread()
                    tryExchangeGingerbread()
                    tryTamePug()
                end
            end)
        end

        return Christmas2025Handler
    end
end

setfpscap(2)
task.wait(10)

if not game:IsLoaded() then
    game.Loaded:Wait()
end

setfpscap(getgenv().SETTINGS.SET_FPS or 2)

if getgenv().loaded == true then
    print('SCRIPT ALREADY LOADED')

    return
end

getgenv().loaded = true

if game.PlaceId ~= 920587237 then
    return
end

setfpscap(getgenv().SETTINGS.SET_FPS or 2)

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local UserGameSettings = UserSettings():GetService('UserGameSettings')

UserGameSettings.GraphicsQualityLevel = 1
UserGameSettings.MasterVolume = 0

local Bypass = (require(ReplicatedStorage:WaitForChild('Fsys')).load)
local RouterClient = (Bypass('RouterClient'))
local localPlayer = Players.LocalPlayer
local NewsApp = (localPlayer:WaitForChild('PlayerGui'):WaitForChild('NewsApp'))

if not NewsApp.Enabled then
    repeat
        task.wait(5)
    until NewsApp.Enabled or localPlayer.Character
end

for i, v in debug.getupvalue(RouterClient.init, 7)do
    v.Name = i
end

getgenv().auto_accept_trade = false
getgenv().autoTrading = false
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
        TradeLicenseHandler = __DARKLUA_BUNDLE_MODULES.load('o'),
    },
    {
        WebhookHandler = __DARKLUA_BUNDLE_MODULES.load('p'),
    },
    {
        RayfieldHandler = __DARKLUA_BUNDLE_MODULES.load('s'),
    },
    {
        AutoFarmHandler = __DARKLUA_BUNDLE_MODULES.load('w'),
    },
    {
        PetOfflineHandler = __DARKLUA_BUNDLE_MODULES.load('y'),
    },
    {
        StatsGuiHandler = __DARKLUA_BUNDLE_MODULES.load('A'),
    },
    {
        Christmas2025Handler = __DARKLUA_BUNDLE_MODULES.load('C'),
    },
}

localPlayer:SetAttribute('hasStartedFarming', false)
print('----- INITIALIZING MODULES -----')

for index, _table in ipairs(files)do
    for moduleName, _ in _table do
        if files[index][moduleName].Init then
            print(string.format('INITIALIZING: %s', tostring(moduleName)))
            files[index][moduleName].Init()
        end
    end
end

print('----- STARTING MODULES -----')

for index, _table in ipairs(files)do
    for moduleName, _ in _table do
        if files[index][moduleName].Start then
            print(string.format('STARTING: %s', tostring(moduleName)))
            files[index][moduleName].Start()
        end
    end
end

localPlayer:SetAttribute('hasStartedFarming', true)
print('-------------------------')
print('\u{2705} ALL MODULES LOADED \u{2705}')
print('-------------------------')
