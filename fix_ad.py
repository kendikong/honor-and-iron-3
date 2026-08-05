import sys, re

def update_ability_data(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Remove effects and upgraded_effects exports
    content = re.sub(r'## Ordered list of effects.*?@export var effects: Array\[EffectData\] = \[\]\n\n', '', content, flags=re.DOTALL)
    content = re.sub(r'## Effects applied to the target.*?@export var upgraded_effects: Array\[EffectData\] = \[\]\n\n', '', content, flags=re.DOTALL)
    
    # Update finalize_modular to do nothing, or we can just remove it
    content = re.sub(r'## Infer modules from flat effects.*?\tAbilityModuleBridge\.finalize_ability\(self\)\n', 'func finalize_modular() -> void:\n\tpass\n', content, flags=re.DOTALL)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

update_ability_data('data/definitions/ability_data.gd')
print("ability_data.gd updated.")