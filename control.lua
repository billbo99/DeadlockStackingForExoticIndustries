local function starts_with(str, start)
    return str:sub(1, #start) == start
end

local function OnConfigurationChanged(e)
    -- e.mod_changes
    -- e.mod_startup_settings_changed
    -- e.migration_applied
    log("on_configuration_changed")
    if e.mod_startup_settings_changed or e.mod_changes["DeadlockStackingForExoticIndustries"] then

        for _, force in pairs(game.forces) do
            local recipes = force.recipes
            for _, tech in pairs(force.technologies) do
                for _, effect in pairs(tech.effects) do
                    if tech.researched and effect.type == "unlock-recipe" and (starts_with(effect.recipe, "deadlock") or starts_with(effect.recipe, "StackedRecipe")) then
                        recipes[effect.recipe].enabled = true
                        recipes[effect.recipe].reload()
                    end
                end
            end
        end

    end
end

script.on_configuration_changed(OnConfigurationChanged)
