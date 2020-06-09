    -- Script for a tripmine that, when hacked, can be "recycled" (reused) by the player.

	-- while we are still planning on using the tripmines for a competition, the model will remain internal. We will publicly release the model later.
    local mineIcon = "models/props/choreo_office/gnome.vmdl"--"models/wrist_pocket/wrist_pocket_tripmine_icon.vmdl"
    local healthPenIcon = "models/wrist_pocket/wrist_pocket_health_pen_icon.vmdl"
    local trashIcon = "models/props/interior_deco/interior_cup_mug_001.vmdl"

    function Precache(Context)
        PrecacheModel(mineIcon, Context) -- Precaches the tripmine wrist pocket icon
        PrecacheModel(trashIcon, Context)
    end

    function Activate() -- Called when the script is loaded
        --Initiate()
        print("Reuseable Mines activated")
        ListenToGameEvent("player_stored_item_in_itemholder", ItemIn, itemTable)
        ListenToGameEvent("player_removed_item_from_itemholder", ItemOut, itemTable)
        ListenToGameEvent("tripmine_hacked", ConvertIntoWeapon, nil) --we may need this later
    end

    local tripMineTable = {
        origin = "0 0 0",
        angles = "0 0 0",
        enabled = "1",
        StartActivated = "0",
        StartAttached = "0",
        PreventTripping = "0",
        HackDifficultyName = "First",
        CanDepositInItemHolder = "1",
    }

    function ConvertIntoWeapon()
        local tripMineEnt = Entities:FindByClassnameNearest("item_hlvr_weapon_tripmine", Entities:GetLocalPlayer():GetHMDAvatar():GetAbsOrigin(), 100)
        if tripMineEnt == nil then 
            print("ConvertIntoWeapon triggered but no mine to convert found?")
            return 
        end
        thisEntity:SetThink(function() return DelayKill(tripMineEnt) end, "Kill" , 3.5)
    end

    function DelayKill(tripMineEnt)
        local tPos = tripMineEnt:GetOrigin()
        local tAng = tripMineEnt:GetAnglesAsVector()
        tripMineEnt:Destroy() 
        local itemMineNew = SpawnEntityFromTableSynchronous("item_hlvr_weapon_tripmine", tripMineTable) -- Spawns a new tripmine in the position of the original
        itemMineNew:SetAngles(tAng.x, tAng.y, tAng.z)
        itemMineNew:SetOrigin(tPos)
        DeleteAperture(itemMineNew)
        return nil
    end

    -- WRIST POCKET MANAGEMENT --
    local itemClass = ""
    local itemHand = 2 --2 means no hand
    local itemEnt = nil

    local storedItem = {
        hand0 = "",
        icon0 = "",
        index0 = 0,
        hand1 = "",
        icon1 = "",
        index1 = 0
    }

    function ItemIn(itemTable)
        itemClass = itemTable.item
        thisEntity:SetThink(ItemSearcher, "Search", 0.1)
    end

    function ItemSearcher()
        if inited == false then Initiate() end
        SearchWrists()
        if itemHand > 1 then
            return
        end
        if itemClass == "prop_physics" and storedItem["icon" .. itemHand] == healthPenIcon then -- we know its a custom prop
            itemEnt:SetModel(trashIcon)
            itemEnt:SetRenderColor(255, 94, 19)
            itemEnt:SetRenderAlpha(120)
        elseif itemClass == "item_hlvr_weapon_tripmine" then
            if itemEnt ~= nil then 
                print("MINE")
                itemEnt:SetModel(mineIcon)
            end
        else
            storedItem["hand" .. itemHand] = itemClass -- item is typical prop  just store class
        end
        return nil
    end

    local i = 0

    function SearchWrists()
        local Player = Entities:GetLocalPlayer()
        i = 0
        itemHand = 2 --assume we don't find a match
        while i <= 1 do --loop through both hands if they exist
            local hand = Player:GetHMDAvatar():GetVRHand(i)
            if hand == nil then -- hand/controller is not valid
            else
                if SearchChildren(hand) == 2 then
                    itemHand = i
                    return
                end
            end
            i = i + 1 
        end
        return
    end

    function SearchChildren(parent)
        local children = parent:GetChildren()
        local idx = 1
            for idx, child in pairs(children) do
                if child:GetClassname() == "baseanimating" then
                    if child:GetEntityIndex() == storedItem["index".. i]  then --we can assume the entity has not be changed
                        return 1
                    else
                        storedItem["hand" .. i] = itemClass
                        storedItem["icon" .. i] = child:GetModelName()
                        storedItem["index" .. i] = child:GetEntityIndex()
                        itemEnt = child -- pass child to outer scope for later use
                        return 2
                    end
                end
            end
        storedItem["hand" .. i] = "" --we never found a child matching that class set hand as empty
        storedItem["icon" .. i] = ""
        storedItem["index" .. i] = 0
        itemEnt = nil
        return 3
    end

    function ItemOut(ItemTable)
        --add small delay to updating wrists
        player:SetThink(LogEmpty, "Out" , 0.1)
    end

    function LogEmpty()
        itemClass = "NA"--setting the search string to something that'll never be matched we just want to set empty hands to ""
        SearchWrists() 
    end

    function VectorToString(Vec)
        --Create Angles for a prop for transfer
        local x = tostring(Vec.x)
        local y = tostring(Vec.y)
        local z = tostring(Vec.z)
        return x .. " " .. y .. " " .. z
    end

    function DeleteAperture(refEnt)
        local children = refEnt:GetChildren()
        print("CHILDREN")
        for idx , child in pairs(children) do
            print(idx .. " NAME = " .. child:GetName())
            print(idx .." CLASS = " .. child:GetClassname())
            print(idx .." MODEL = " .. child:GetModelName())
            print(idx .." LOC POS = " .. tostring(child:GetLocalOrigin())) 
            print(idx .." LOC ANG = " .. tostring(child:GetLocalAngles())) 
        end
        local j = 1
        while j == 1 do
            local mineAperture = Entities:FindByClassnameNearest("hlvr_tripmine_hacking_aperture", refEnt:GetAbsOrigin(), 30)
            if  mineAperture  ~= nil then 
                mineAperture:RemoveSelf()
                print("mine destroyed")
            else 
                j = 2
            end
        end

        local apT =
        {
            origin = "0 0 0",
            angles = "0 0 0",
            scales = "1 1 1",
            targetname = "tripmine_aperture",
            model = "models/weapons/vr_tripmine/tripmine_aperture.vmdl",
            PerformanceMode = "PM_NORMAL",
            DefaultAnim = "tripmine_hacking_close_idle"
        }
        local  apProp = SpawnEntityFromTableSynchronous("prop_physics", apT)
        apProp:SetParent(refEnt, "")
        apProp:SetLocalOrigin(Vector(0, 0,0))
        apProp:SetLocalAngles(0, 0, 0)
    end
