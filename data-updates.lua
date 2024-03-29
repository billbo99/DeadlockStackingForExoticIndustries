if not settings.startup["deadlock-enable-beltboxes"] or not settings.startup["deadlock-enable-beltboxes"].value then
    return
end

local debug = false

local rusty_locale = require "__rusty-locale__.locale"
local rusty_icons = require "__rusty-locale__.icons"
local rusty_recipes = require "__rusty-locale__.recipes"
local rusty_prototypes = require "__rusty-locale__.prototypes"

local Items = require("migrations.items").items
local tech_by_product = {}

local default_beltbox = "basic-transport-belt-beltbox"
if not data.raw.recipe[default_beltbox] then
    default_beltbox = "deadlock-stacking-1"
end

local function starts_with(str, start)
    return str:sub(1, #start) == start
end

local function dedup_list(data)
    local tmp = {}
    local res = {}
    for k, v in pairs(data) do
        tmp[v] = true
    end
    for k, _ in pairs(tmp) do
        table.insert(res, k)
    end
    return res
end

local function process_result(items, result)
    if result then
        table.insert(items, { name = result, type = "item" })
    end
end

local function process_results(items, results)
    if results then
        for _, item in pairs(results) do
            if item.name or item[1] then
                table.insert(items, { name = item.name or item[1], type = item.type or "item" })
            end
        end
    end
end

local function get_items_made_by_recipe(recipe)
    local items = {}
    process_result(items, recipe.result)
    process_results(items, recipe.results)

    if recipe.normal then
        process_result(items, recipe.normal.result)
        process_results(items, recipe.normal.results)
    end
    if recipe.expensive then
        process_result(items, recipe.expensive.result)
        process_results(items, recipe.expensive.results)
    end
    return dedup_list(items)
end

local function walk_technology()
    for _, tech in pairs(data.raw.technology) do
        if debug then
            log("walk_technology .. " .. tech.name)
        end
        if tech.effects then
            for _, effect in pairs(tech.effects) do
                if effect.type and effect.type == "unlock-recipe" and effect.recipe and data.raw.recipe[effect.recipe] then
                    local recipe = data.raw.recipe[effect.recipe]
                    local items = get_items_made_by_recipe(recipe)
                    for _, item in pairs(items) do
                        if not tech_by_product[item.name] then
                            tech_by_product[item.name] = { type = item.type, tech = {} }
                        end
                        if tech.name == default_beltbox or starts_with(tech.name, "deadlock-stacking-") then
                            -- skipping beltbox technology
                        else
                            table.insert(tech_by_product[item.name].tech, tech.name)
                        end
                    end
                end
            end
        end
    end
end

local function walk_resources()
    for _, resource in pairs(data.raw.resource) do
        if debug then
            log("walk_resources .. " .. resource.name)
        end
        if resource.minable then
            if resource.minable.result then
                if not tech_by_product[resource.minable.result] then
                    tech_by_product[resource.minable.result] = { type = resource.minable.result.type or "item", tech = {} }
                end
                table.insert(tech_by_product[resource.minable.result].tech, default_beltbox)
            elseif resource.minable.results then
                for _, result in pairs(resource.minable.results) do
                    if result.type == "item" then
                        if not tech_by_product[result.name] then
                            tech_by_product[result.name] = { type = result.type, tech = {} }
                            table.insert(tech_by_product[result.name].tech, default_beltbox)
                        end
                    end
                end
            else
                log("hmm2 .. " .. recipe.name)
            end
        end
    end
end

local function walk_recipes()
    for _, recipe in pairs(data.raw.recipe) do
        if debug then
            log("walk_recipes .. " .. recipe.name .. " .. " .. tostring(recipe.enabled))
        end
        if recipe.enabled and recipe.enabled ~= "false" and recipe.hidden ~= "true" and recipe.hidden ~= true then
            local main_product = rusty_recipes.get_main_product(recipe)
            if main_product then
                if not tech_by_product[main_product.name] then
                    tech_by_product[main_product.name] = { type = main_product.type, tech = {} }
                    table.insert(tech_by_product[main_product.name].tech, default_beltbox)
                end
            else
                log("hmm1 .. " .. recipe.name)
            end
        end
    end

    -- for name, _ in pairs(tech_by_product) do
    --     if #tech_by_product[name].tech == 0 and starts_with(name, "deadlock-stack-") == false then
    --         table.insert(tech_by_product[name].tech, default_beltbox)
    --     end
    -- end
end

local function add_item_to_tech(name, tech)
    local recipes = {}
    for _, effect in pairs(data.raw.technology[tech].effects) do
        if effect.type == "unlock-recipe" then
            recipes[effect.recipe] = true
        end
    end
    if not recipes[string.format("deadlock-stacks-stack-%s", name)] then
        table.insert(data.raw.technology[tech].effects, { type = "unlock-recipe", recipe = string.format("deadlock-stacks-stack-%s", name) })
    end
    if not recipes[string.format("deadlock-stacks-unstack-%s", name)] then
        table.insert(data.raw.technology[tech].effects, { type = "unlock-recipe", recipe = string.format("deadlock-stacks-unstack-%s", name) })
    end
end

local function add_loader_beltbox()
    deadlock.add_tier(
        {
            transport_belt = "ei_neo-belt",
            colour = { r = 225, g = 25, b = 225 }, -- purple
            -- colour = {r = 10, g = 225, b = 25},  -- green
            underground_belt = "ei_neo-underground-belt",
            splitter = "ei_neo-splitter",
            technology = "ei_neo-logistics",
            order = "d",
            loader_ingredients = {
                { type = "fluid", name = "ei_liquid-nitrogen",            amount = 40 },
                { type = "item",  name = "express-transport-belt-loader", amount = 2 },
                { type = "item",  name = "ei_neodym-plate",               amount = 10 },
                { type = "item",  name = "ei_steel-mechanical-parts",     amount = 10 },
            },
            loader_category = "crafting-with-fluid",
            beltbox_ingredients = {
                { type = "fluid", name = "ei_liquid-nitrogen",             amount = 40 },
                { type = "item",  name = "express-transport-belt-beltbox", amount = 2 },
                { type = "item",  name = "ei_neodym-plate",                amount = 10 },
                { type = "item",  name = "ei_steel-mechanical-parts",      amount = 10 },
            },
            beltbox_technology = "deadlock-stacking-4"
        }
    )
end

local function main()
    --Add stacking recipes
    for name, item in pairs(Items) do
        local icon = item.icon or nil
        local icon_size = item.icon_size or nil
        local techs = {}
        local item_type = "item"

        if item.tech == "DEFAULT" then
            item.tech = default_beltbox
        end

        if tech_by_product[name] then
            temp_techs = dedup_list(tech_by_product[name].tech)
            item_type = tech_by_product[name].type or "item"
            if item.tech ~= "" then
                table.insert(techs, item.tech)
            end
            for _, tech in pairs(temp_techs) do
                table.insert(techs, tech)
            end
        else
            techs = { item.tech }
        end

        if item.type then
            item_type = item.type
        end

        if data.raw[item_type] and data.raw[item_type][name] and data.raw.technology[techs[1]] then
            if data.raw.item["deadlock-stack-" .. name] then
                add_item_to_tech(name, techs[1])
            else
                deadlock.add_stack(name, icon, techs[1], icon_size, item_type)
                if #techs > 1 then
                    for i = 2, #techs do
                        add_item_to_tech(name, techs[i])
                    end
                end
            end
        else
            log("not found ... data.raw[" .. item_type .. "][" .. name .. "]")
        end
    end
end

walk_technology()
walk_resources()
walk_recipes()
add_loader_beltbox()
main()

-- multiply a number with a unit (kJ, kW etc) at the end
local function multiply_number_unit(property, mult)
    local value, unit
    value = string.match(property, "%d+")
    if string.match(property, "%d+%.%d+") then -- catch floats
        value = string.match(property, "%d+%.%d+")
    end
    unit = string.match(property, "%a+")
    if unit == nil then
        return value * mult
    else
        return ((value * mult) .. unit)
    end
end

-- fix any fuel values
local deadlock_stack_size = settings.startup["deadlock-stack-size"].value
for item, item_table in pairs(data.raw.item) do
    if starts_with(item, "deadlock-stack-") then
        if debug then
            log(serpent.block(recipe_table))
        end
        local parent = data.raw.item[string.sub(item, 16)]
        if parent and parent.fuel_value then
            item_table.fuel_value = multiply_number_unit(parent.fuel_value, deadlock_stack_size)
            item_table.fuel_category = parent.fuel_category
            item_table.fuel_acceleration_multiplier = parent.fuel_acceleration_multiplier
            item_table.fuel_top_speed_multiplier = parent.fuel_top_speed_multiplier
            item_table.fuel_emissions_multiplier = parent.fuel_emissions_multiplier

            if parent.burnt_result and data.raw.item["deadlock-stack-" .. parent.burnt_result] then
                item_table.burnt_result = "deadlock-stack-" .. parent.burnt_result
            end
        end
    end
end

for recipe, recipe_table in pairs(data.raw.recipe) do
    if starts_with(recipe, "deadlock-stacks-stack-") or starts_with(recipe, "deadlock-stacks-unstack-") then
        if recipe_table.icons then
            local parent, last_icon
            if starts_with(recipe, "deadlock-stacks-stack-") then
                local x = rusty_prototypes.find_by_name(string.sub(recipe_table.result, 16))
                parent = x.item or x.module or x.tool or nil
                last_icon = { icon = "__deadlock-beltboxes-loaders__/graphics/icons/square/arrow-u-64.png", icon_size = 64, scale = 0.25 }
            else
                local x = rusty_prototypes.find_by_name(recipe_table.result)
                parent = x.item or x.module or x.tool or nil
                last_icon = { icon = "__deadlock-beltboxes-loaders__/graphics/icons/square/arrow-d-64.png", icon_size = 64, scale = 0.25 }
            end
            if parent and parent.icon then
                if string.find(parent.icon, "__bob") then
                    if not string.find(recipe_table.icons[1].icon, "blank.png") then
                        local icons = { { icon = "__deadlock-beltboxes-loaders__/graphics/icons/square/blank.png", icon_size = 32, scale = 1 } }
                        table.insert(icons, { icon = parent.icon, icon_size = parent.icon_size, scale = 0.85 / (parent.icon_size / 32), shift = { 0, 3 } })
                        table.insert(icons, { icon = parent.icon, icon_size = parent.icon_size, scale = 0.85 / (parent.icon_size / 32), shift = { 0, 0 } })
                        table.insert(icons, { icon = parent.icon, icon_size = parent.icon_size, scale = 0.85 / (parent.icon_size / 32), shift = { 0, -3 } })
                        table.insert(icons, last_icon)
                        recipe_table.icons = icons

                        if starts_with(recipe, "deadlock-stacks-stack-") then
                            local stacked_icon = data.raw.item[recipe_table.result]
                            icons = { { icon = "__deadlock-beltboxes-loaders__/graphics/icons/square/blank.png", icon_size = 32, scale = 1 } }
                            table.insert(icons, { icon = parent.icon, icon_size = parent.icon_size, scale = 0.85 / (parent.icon_size / 32), shift = { 0, 3 } })
                            table.insert(icons, { icon = parent.icon, icon_size = parent.icon_size, scale = 0.85 / (parent.icon_size / 32), shift = { 0, 0 } })
                            table.insert(icons, { icon = parent.icon, icon_size = parent.icon_size, scale = 0.85 / (parent.icon_size / 32), shift = { 0, -3 } })

                            stacked_icon.icons = icons
                        end
                    end
                end
            end
        end
    end
end
