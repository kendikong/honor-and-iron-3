import sys, re

def replace_in_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    # Replace (effect|eff|module|mod).type with .primary_type
    content = re.sub(r'\b(effect|eff|module|mod)\.type\b', r'\1.primary_type', content)
    
    # Fix the missing explicit types (type inference bugs)
    content = content.replace('var base_amt := effect.amount', 'var base_amt: int = effect.amount')
    content = content.replace('var amount := base_amt', 'var amount: int = base_amt')
    content = content.replace('var heal_amount := effect.amount', 'var heal_amount: int = effect.amount')
    
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

replace_in_file('core/systems/ability_system.gd')
print("Fixed ability_system.gd!")