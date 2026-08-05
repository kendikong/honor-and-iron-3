import re

files = [
    'core/factory/classes/knight_factory.gd',
    'core/factory/classes/bruiser_factory.gd',
    'core/systems/ability_system.gd'
]

for file in files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Replace assignment: obj.modifiers["key"] = value -> obj.key = value
    # Handle int values (e.g. 1 -> true if it should be bool, but we'll just keep the value and ensure AbilityModule handles it or type it properly)
    content = re.sub(r'\.modifiers\["([^"]+)"\]\s*=\s*(.+)', r'.\1 = \2', content)
    
    # Replace access: obj.modifiers.has("key") -> hasattr is not GDScript, but we can just use the value directly if it's 0/false by default
    # Wait, in GDScript, eff.modifiers.has("zero_ap_adjacent_enemies") was used.
    # We can replace it with eff.zero_ap_adjacent_enemies > 0
    
    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)
