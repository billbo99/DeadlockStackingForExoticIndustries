local vanilla_items = {
    'iron-ore',
    'copper-ore',
    'iron-gear-wheel',
    'iron-stick',
}

for _, name in pairs(vanilla_items) do
    deadlock.destroy_stack(name)
end
