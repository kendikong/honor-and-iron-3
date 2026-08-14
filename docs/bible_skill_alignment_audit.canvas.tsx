import {
  Callout,
  Checkbox,
  Divider,
  Grid,
  H1,
  H2,
  Row,
  Select,
  Stack,
  Stat,
  Table,
  Text,
  useCanvasState,
} from "cursor/canvas";

type Verdict = "MATCH" | "FAIL" | "DATA-ONLY" | "MISSING";

type Finding = {
  cls: string;
  skill: string;
  bible: string;
  verdict: Verdict;
  delta: string;
};

const R: Finding[] = [
  { cls: "Knight", skill: "Stats", bible: "CON 6 MOV 3 STR 4 DEF 5 MAG 2", verdict: "MATCH", delta: "Factory matches." },
  { cls: "Knight", skill: "Promotion boosts", bible: "Sentinel / Juggernaut / Cataphract stat lines", verdict: "MATCH", delta: "promotion_stat_bonuses now authored." },
  { cls: "Knight", skill: "Bastion Front", bible: "0 collision dmg when YOU are knocked. Frontal +2 DEF. [+] +4, SHIELD 2", verdict: "MATCH", delta: "Victim collision is 0. Frontal DEF reads bastion_front_def keys." },
  { cls: "Knight", skill: "Swap", bible: "1 MOV adjacent ally swap. [+] +2 DEF SHIELD 2", verdict: "MATCH", delta: "ALLY 1 MP. Upgrade layers match." },
  { cls: "Knight", skill: "Kinetic Dissipation", bible: "When YOU collide: SHIELD=DEF + shockwave. [+] PUSH 1", verdict: "MATCH", delta: "Fires when the Knight is shoved into a unit or wall, and when they are the bumper." },
  { cls: "Knight", skill: "Thorny Carapace", bible: "Melee reflect 50% round down + PUSH 1. [+] 100%", verdict: "MATCH", delta: "combat_system.gd:957." },
  { cls: "Knight", skill: "Concussive Shatter", bible: "Collision +50% DEF dmg; lose DEF=WPN. [+] also VULNERABLE", verdict: "MATCH", delta: "DEF shred equals WPN. Upgrade adds VULNERABLE without dropping the shred." },
  { cls: "Knight", skill: "Stand Ground", bible: "Immune PUSH/PULL; attacker ATK 1. [+] ATK 2", verdict: "MATCH", delta: "physics + ability_system." },
  { cls: "Knight", skill: "Kinetic Momentum", bible: "Cause collision → SHIELD STR+DEF. [+] refund 1 MOV first", verdict: "MATCH", delta: "combat_system.gd:129." },
  { cls: "Knight", skill: "Indestructible Bastion", bible: "Lethal → 1 HP + SHIELD=DEF once. [+] +2 STR combat", verdict: "MATCH", delta: "combat_system.gd:990." },
  { cls: "Knight", skill: "Phalanx Deflection", bible: "Store 50% mitigated, cap 2×DEF; next melee consumes + PUSH 1. [+] cap 3×DEF", verdict: "MATCH", delta: "Front-lane only (facing axis). Store/consume + PUSH 1. Cap 2×/3× DEF." },
  { cls: "Knight", skill: "Kinetic Armor", bible: "Floor(DEF/2) if SHIELD. [+] Floor((DEF+2)/2)", verdict: "MATCH", delta: "combat_system uses caster DEF formula." },
  { cls: "Knight", skill: "Kinetic Converter", bible: "When hit +1 STR +1 MOV next turn. [+] +2 STR", verdict: "MATCH", delta: "combat_system.gd:952." },
  { cls: "Knight", skill: "Kinetic Redirection", bible: "Mitigate → +1 STR next attack stack 3. [+] PIERCE", verdict: "MATCH", delta: "Stacks, reset, PIERCE." },
  { cls: "Knight", skill: "Bulwark", bible: "+1 DEF per adjacent. [+] +1 STR per enemy", verdict: "MATCH", delta: "combat_system.gd:216." },
  { cls: "Knight", skill: "Living Barricade", bible: "Allies behind immune ranged. [+] +1 DEF", verdict: "MATCH", delta: "Blocks ranged non-AOE. Upgrade is +1 DEF only." },
  { cls: "Knight", skill: "Shield Wall", bible: "Adj allies +1 DEF PULL immune. [+] RANGE 2", verdict: "MATCH", delta: "Aura + PULL immunity." },
  { cls: "Knight", skill: "Rallying Presence", bible: "Start adj +1 MOV. [+] +2", verdict: "MATCH", delta: "simulator.gd:240." },
  { cls: "Knight", skill: "Intercept Tactics", bible: "Redirect skill → +2 DEF. [+] +3", verdict: "MATCH", delta: "INTERCEPT skills only. TAUNT does not grant the DEF buff." },
  { cls: "Knight", skill: "Shield Bash", bible: "RANGE 1 ATK 1 PUSH 2. [+] STAGGER on collision; boss +WPN", verdict: "MATCH", delta: "Collision STAGGER. Boss hard-CC fallback deals +WPN unmitigated (shared CombatSystem path)." },
  { cls: "Knight", skill: "Phalanx Stance", bible: "SELF DEF+5 STURDY. [+] infinite Retaliation range", verdict: "MATCH", delta: "SELF, DEF 5, infinite range upgrade." },
  { cls: "Knight", skill: "Taunting Strike", bible: "RANGE 2 ATK 1 PULL 1 TAUNT. [+] RANGE 3 AOE 3x3 PULL 2", verdict: "MATCH", delta: "TILE aim. Upgrade RANGE 3 AOE 3x3 PULL 2." },
  { cls: "Knight", skill: "Seismic Stomp", bible: "RANGE 0 AOE 1 ATK 2 PURGE. AOE 1 = cross. [+] CRACKED", verdict: "MATCH", delta: "Factory is AOE_CROSS size 1." },
  { cls: "Knight", skill: "Fortify", bible: "RANGE 3 ally DEF increased by your DEF. [+] THORNS 50%", verdict: "MATCH", delta: "ADD_STATUS amount 0 + scaling DEFENSE = caster DEF." },
  { cls: "Knight", skill: "Bowling Charge", bible: "DASH 3 collision ATK 3 PUSH 2. [+] chain ATK 3 both", verdict: "MATCH", delta: "Owner confirmed current behavior is correct. Left as-is." },
  { cls: "Knight", skill: "Iron Grip", bible: "RANGE 1 ROOT; DEF halved next turn. [+] refund AP if already CC", verdict: "MATCH", delta: "ceili(def/2) next turn. Refund works." },
  { cls: "Knight", skill: "Redirect Strike", bible: "RANGE 2 pick ally INTERCEPT 50%. [+] +2 DEF per hit", verdict: "MATCH", delta: "ALLY RANGE 2 ward. Intercepts only the chosen ally." },
  { cls: "Knight", skill: "Indomitable Will", bible: "SELF missing HP → SHIELD 2 turns. [+] expire +2 STR", verdict: "MATCH", delta: "MISSING_HP shield + expiry STR." },
  { cls: "Knight", skill: "Retaliation Protocol", bible: "SELF melee counter ATK 2. [+] PUSH 1", verdict: "MATCH", delta: "combat_system.gd:977." },
  { cls: "Knight", skill: "Shield Slam", bible: "RANGE 1 ATK 2 PUSH 2; if already adj ATK+2. [+] DEF−1 first", verdict: "MATCH", delta: "RANGE 1 makes already-adjacent always true." },
  { cls: "Knight", skill: "Defensive Formation", bible: "RANGE 0 AOE 3 allies +2 DEF PUSH/PULL immune. [+] SHIELD 2", verdict: "MATCH", delta: "SELF-anchored diamond-3. Allies only." },
  { cls: "Knight", skill: "Chain Hook", bible: "RANGE 3 ATK 1 PULL 2. [+] VULNERABLE if adj", verdict: "MATCH", delta: "PULL_VULNERABLE_ON_ADJACENT." },
  { cls: "Knight", skill: "Trampling Advance", bible: "MOVE 2 ATK 2 PUSH 1. [+] SHIELD 1 per tile", verdict: "MATCH", delta: "Owner confirmed current behavior is correct. Left as-is." },

  { cls: "Bruiser", skill: "Stats", bible: "CON 7 MOV 4 STR 4 DEF 2 MAG 1", verdict: "MATCH", delta: "Factory matches." },
  { cls: "Bruiser", skill: "Promotion boosts", bible: "Bloodrager / Behemoth / Siegebreaker", verdict: "MATCH", delta: "promotion_stat_bonuses now authored." },
  { cls: "Bruiser", skill: "Sanguine Regeneration", bible: "Turn start Floor(5% Max HP). [+] 10%, overflow SHIELD", verdict: "MATCH", delta: "Overflow of the turn-start heal becomes SHIELD." },
  { cls: "Bruiser", skill: "Push Through", bible: "2 MOV into ally, push 1. [+] 1 MOV +1 STR next attack", verdict: "MATCH", delta: "ALLY, cost 2→1, buff_on_push." },
  { cls: "Bruiser", skill: "Reactive Adrenaline", bible: "Adj enemies: convert heal to SHIELD always; +1 STR/adj max 3. [+] +1 DEF", verdict: "MATCH", delta: "Adjacent enemies convert the turn-start heal to SHIELD even when wounded." },
  { cls: "Bruiser", skill: "Blood for Blood", bible: "Damaged last turn → BLEED WPN. [+] ATK+1", verdict: "MATCH", delta: "combat_system.gd:897." },
  { cls: "Bruiser", skill: "Adrenaline Junkie", bible: "+1 MOV +1 STR per 25% missing, max +3. [+] +1 DEF per 25%", verdict: "MATCH", delta: "unit_state + combat_system cap 3." },
  { cls: "Bruiser", skill: "Enraged", bible: "+1 STR per unique debuff/hazard. [+] +1 MOV", verdict: "MATCH", delta: "combat_system.gd:233." },
  { cls: "Bruiser", skill: "Last Stand", bible: "HP<25% +2 STR +2 DEF. [+] +3/+3", verdict: "MATCH", delta: "combat_system.gd:181." },
  { cls: "Bruiser", skill: "Colossal Mass", bible: "+1 STR / 15 Max HP. [+] /10", verdict: "MATCH", delta: "combat_system.gd:273." },
  { cls: "Bruiser", skill: "Overwhelming Bulk", bible: "HP > target Max HP → PIERCE. [+] PUSH 1", verdict: "MATCH", delta: "combat_system.gd:453." },
  { cls: "Bruiser", skill: "Thrill of Pain", bible: "Take dmg → next ATK+2 PUSH 1. [+] ATK+3", verdict: "MATCH", delta: "combat_system.gd:421." },
  { cls: "Bruiser", skill: "Momentum of the Titan", bible: "PUSH collision + Floor(10% Max HP). [+] 20%", verdict: "MATCH", delta: "combat_system.gd:72." },
  { cls: "Bruiser", skill: "Scar Tissue", bible: "Reduce phys 1 per 20 Max or missing, cap Floor(Max/10). [+] count 15", verdict: "MATCH", delta: "combat_system scar_step 20/15." },
  { cls: "Bruiser", skill: "Momentum Transfer", bible: "PUSH collision HEAL 1. [+] +1 STR", verdict: "MATCH", delta: "combat_system.gd:101." },
  { cls: "Bruiser", skill: "Crowd Breaker", bible: "+1 STR/adj enemy; splash ATK 1. [+] splash 2", verdict: "MATCH", delta: "combat_system.gd:277, 904." },
  { cls: "Bruiser", skill: "Unstoppable Tread", bible: "Move over traps destroy 0 dmg. [+] SHIELD 1", verdict: "MATCH", delta: "terrain_system.gd:51. Display is Bible Unstoppable Tread; factory id stays juggernaut." },
  { cls: "Bruiser", skill: "Battering Ram", bible: "PUSH +1 tile. [+] wall STAGGER", verdict: "MATCH", delta: "physics_system.gd:410." },
  { cls: "Bruiser", skill: "Unstoppable Force", bible: "Immune STAGGER/ROOT; resist SHIELD 1. [+] SHIELD 2", verdict: "MATCH", delta: "combat_system.gd:1155." },
  { cls: "Bruiser", skill: "Charge Strike", bible: "MOVE 2 ATK 3 PUSH 1. [+] GHOST; +2 if through terrain", verdict: "MATCH", delta: "MOVE 2, GHOST through occupied, land adjacent empty, +2 from occupied tiles." },
  { cls: "Bruiser", skill: "Concussion Blow", bible: "RANGE 1 ATK 2 PUSH 1; object STAGGER. [+] enemy collision STAGGER both", verdict: "MATCH", delta: "Upgrade keeps object STAGGER and adds enemy-collision STAGGER both." },
  { cls: "Bruiser", skill: "Cleave", bible: "RANGE 1 ARC ATK 2. [+] BLEED WPN", verdict: "MATCH", delta: "TILE ARC + weapon BLEED." },
  { cls: "Bruiser", skill: "Suplex", bible: "RANGE 1 ATK 4 throw behind. [+] +1 per 10 HP", verdict: "MATCH", delta: "THROW_BEHIND." },
  { cls: "Bruiser", skill: "Adrenaline Surge", bible: "SELF 5 HP; +1 MOV +1 STR; 0 AP if 2+ adj. [+] On Kill HEAL 1 SHIELD 2", verdict: "MATCH", delta: "ZERO_IF_ADJACENT_ENEMIES_GTE_N 2." },
  { cls: "Bruiser", skill: "Earthshatter", bible: "RANGE 1 ARC ATK 2 destroy cover. [+] +1 per destroyed", verdict: "MATCH", delta: "TILE ARC. Empty cover is a legal aim." },
  { cls: "Bruiser", skill: "Meat Shield", bible: "RANGE 1 ally swap INTERCEPT 50%. [+] RANGE 3 +2 STR/intercept", verdict: "MATCH", delta: "Swap + intercept + upgrade range 3." },
  { cls: "Bruiser", skill: "Frenzy", bible: "RANGE 1 ATK 1 ×3. [+] On Kill 1 AP", verdict: "MATCH", delta: "Three DAMAGE modules." },
  { cls: "Bruiser", skill: "Guttural Roar", bible: "RANGE 0 AOE 2 PUSH 1 DEF−2. [+] items Floor(STR/2) VULNERABLE", verdict: "MATCH", delta: "AOE 2 cross. Item collision Floor(STR/2) + VULNERABLE." },
  { cls: "Bruiser", skill: "Headbutt", bible: "RANGE 1 ATK 3; SELF and target 1 dmg + STAGGER. [+] +10% Max HP", verdict: "MATCH", delta: "ATK 3 plus true 1 on target and self. Both STAGGER." },
  { cls: "Bruiser", skill: "Blood Boil", bible: "SELF 5 HP +3 STR. [+] 10 HP +5 STR", verdict: "MATCH", delta: "HP 5→10, amount 3→5." },
  { cls: "Bruiser", skill: "Violent Collision", bible: "MOVE 3; on collision second MOVE 2. [+] STAGGER", verdict: "MATCH", delta: "IF_COLLIDED MOVE 2. Upgrade STAGGER on collision." },
  { cls: "Bruiser", skill: "Crimson Whirlwind", bible: "RANGE 0 AOE 3x3 ATK 1. [+] HEAL 1 per hit", verdict: "MATCH", delta: "Square size 1 = 3x3. heal_per_target_hit." },
  { cls: "Bruiser", skill: "Belly Flop", bible: "RANGE 2 ATK 2 adjacent on landing. [+] PUSH 1 adj", verdict: "MATCH", delta: "Base adjacent ATK 2. Upgrade PUSH 1." },
  { cls: "Bruiser", skill: "Breaching Dash", bible: "DASH 3 destroy cover. [+] next attack PIERCE", verdict: "MATCH", delta: "DESTROY_OBSTACLE + next_attack_pierce." },

  { cls: "Mercenary", skill: "Stats / promotions", bible: "CON 5 MOV 4 STR 4 DEF 3 MAG 2 + three promo lines", verdict: "MATCH", delta: "promotion_stat_bonuses present." },
  { cls: "Mercenary", skill: "Predatory Momentum", bible: "Basic vs <50% HP free MOVE 1; dmg → +1 STR +1 MOV next turn. [+] 75% +2/+2", verdict: "MATCH", delta: "Bible does not make the basic 0 AP (basics already 0 AP). Free MOVE 1 + next-turn STR/MOV work." },
  { cls: "Mercenary", skill: "Pullback", bible: "2 MOV: you and front unit step back 1. [+] 1 MOV; enemy −2 DEF", verdict: "MATCH", delta: "after_skill_move pullback." },
  { cls: "Mercenary", skill: "Calculated Strike", bible: "Active MOVEMENT skill then attack → +1 STR +1 DEF. [+] +1 AP on kill", verdict: "MATCH", delta: "Only TAG_MOVEMENT skills set the flag. STR/DEF are STAT_BUFF for the rest of the turn." },
  { cls: "Mercenary", skill: "Weapon Master", bible: "STR > DEF → ignore 50% remaining DEF. [+] 100%", verdict: "MATCH", delta: "mercenary_systems extra_def_ignore_pct." },
  { cls: "Mercenary", skill: "Dual Wield Momentum", bible: "May 0 AP ATK 1 same target after active. [+] ignore 50% DEF", verdict: "MATCH", delta: "Immediate 0-AP basic vs the same unit target after an AP active (same ‘may immediately’ as Hit and Run). No longer gated on the active dealing damage." },
  { cls: "Mercenary", skill: "Precision Edge", bible: "Full HP: ATK+2 + BLEED WPN. [+] ATK+3", verdict: "MATCH", delta: "BLEED uses pre-hit full-HP, so the first hit on a full bar applies it." },
  { cls: "Mercenary", skill: "Duelist's Focus", bible: "Unacted enemy +2 dmg + BLIND. [+] WEAKEN", verdict: "MATCH", delta: "Gate is turn_action_used (has not spent Action), not ‘has dealt damage’." },
  { cls: "Mercenary", skill: "Tactical Versatility", bible: "Active → next basic +2 and free MOVE 1. [+] ignore 50% DEF", verdict: "MATCH", delta: "Flag + MP." },
  { cls: "Mercenary", skill: "Swift Feet", bible: "+1 MOV/adj enemy; ignore ZOC. [+] ignore difficult terrain", verdict: "MATCH", delta: "ZOC resolution skips ignore_zoc movers. Difficult-terrain flag zeroes extra MP." },
  { cls: "Mercenary", skill: "Hit and Run", bible: "After damage may MOVE 1. [+] MOVE 2", verdict: "MATCH", delta: "Auto MP grant." },
  { cls: "Mercenary", skill: "Evasive", bible: "Move 3+ → +1 DEF ROOT immune. [+] PULL/slow immune", verdict: "MATCH", delta: "ROOT/PULL/slow immunities apply the same turn the 3rd tile is spent." },
  { cls: "Mercenary", skill: "Flanking Maneuver (passive)", bible: "No allies adj → +1 STR PIERCE. [+] +2 STR", verdict: "MATCH", delta: "Adds STR to the ATK formula, not a flat ATK bump." },
  { cls: "Mercenary", skill: "Dirty Fighting", bible: "+2 vs STAGGER/ROOT/POISON. [+] +3", verdict: "MATCH", delta: "_is_controlled." },
  { cls: "Mercenary", skill: "Executioner", bible: "<50% ATK+2 ignore DEF. [+] <75%", verdict: "MATCH", delta: "threshold + ignore_def." },
  { cls: "Mercenary", skill: "Blood Scent", bible: "+1 MOV toward <50% HP. [+] +2", verdict: "MATCH", delta: "Can stack every closer step." },
  { cls: "Mercenary", skill: "Ruthless", bible: "On kill next attack ATK+2 refund 1 AP. [+] ATK+3", verdict: "MATCH", delta: "Next-attack bonus is consumed on the attack that uses it." },
  { cls: "Mercenary", skill: "Coup de Grace", bible: "Basic kill HEAL 1 +1 MOV. [+] FEAR nearest RANGE 2", verdict: "MATCH", delta: "on_kill gated on basic." },
  { cls: "Mercenary", skill: "Swift Strike", bible: "RANGE 2 MOVE to target ATK 2. [+] 1 AP if damaged", verdict: "MATCH", delta: "MOVE to the unit snaps onto the approach tile, then the chained ATK hits." },
  { cls: "Mercenary", skill: "Defense Strike", bible: "RANGE 1 ATK 1 DEF+2. [+] no Push Mit, no SHIELD", verdict: "MATCH", delta: "Push mit strip + shield_blocked now blocks CombatSystem.add_armor." },
  { cls: "Mercenary", skill: "Blade Storm", bible: "RANGE 1 ATK 2; adj ally ATK+2. [+] BLEED WPN", verdict: "MATCH", delta: "bonus_if_target_adjacent_to_ally." },
  { cls: "Mercenary", skill: "Caltrop Toss", bible: "RANGE 2 ATK 1 CALTROPS. [+] ATK+2", verdict: "MATCH", delta: "Payload skips Archer ROOT+BLEED. Entry ATK 1; upgrade +2 trap damage." },
  { cls: "Mercenary", skill: "Feint", bible: "SELF next attack PIERCE +1 STR. [+] 25% DEF 2 turns", verdict: "MATCH", delta: "+1 STR feeds the ATK formula. PIERCE + DEF shred on the next victim." },
  { cls: "Mercenary", skill: "Riposte Strike", bible: "RANGE 1 ATK 2; if they hit you last turn ATK+2 STAGGER. [+] DEF−2", verdict: "MATCH", delta: "attacked_by_last_turn_id." },
  { cls: "Mercenary", skill: "Sever", bible: "RANGE 1 ATK 2; On Kill all allies HEAL 1. [+] SHIELD 1", verdict: "MATCH", delta: "on_kill_all_allies_heal." },
  { cls: "Mercenary", skill: "Second Wind", bible: "SELF HEAL 1 +1 AP. [+] next skill 0 AP", verdict: "MATCH", delta: "Upgrade 0-AP flag is consumed when that next skill spends cost." },
  { cls: "Mercenary", skill: "Tactical Retreat", bible: "MOVE 3 backwards + SMOKE start. [+] GHOST", verdict: "MATCH", delta: "smoke_on_start + ghost_move." },
  { cls: "Mercenary", skill: "Executioner's Blade", bible: "RANGE 1 ATK 5; <50% HP. [+] 75%; On Kill 1 AP", verdict: "MATCH", delta: "HP gate is 50% base / 75% upgraded. can_use_extra HP gate." },
  { cls: "Mercenary", skill: "Precision Strike", bible: "RANGE 1 ATK 4; unacted ignore 50% DEF. [+] 100%", verdict: "MATCH", delta: "Same turn_action_used gate as Duelist's Focus." },
  { cls: "Mercenary", skill: "Flank & Run", bible: "MOVE 2; if end adj enemy, next ATK+2. [+] GHOST", verdict: "MATCH", delta: "Bonus stays until the next attack consumes it." },
  { cls: "Mercenary", skill: "Hamstring", bible: "RANGE 1 ATK 2; MAX MOV=1. [+] ATK+2 if BLEED", verdict: "MATCH", delta: "Caps max MOV to 1 without an extra −1 MOV that could reach 0." },
  { cls: "Mercenary", skill: "Acrobatic Vault", bible: "RANGE 2 ATK 1 jump over to opposite empty. [+] PIERCE", verdict: "MATCH", delta: "TELEPORT_CASTER lands on the opposite empty tile, then ATK 1." },
  { cls: "Mercenary", skill: "Duelist's Challenge", bible: "RANGE 3 TAUNT + MARK. [+] +2 DEF vs marked", verdict: "MATCH", delta: "TAUNT + MARK for 1 turn. Upgrade +2 DEF vs marked." },

  { cls: "Rogue", skill: "Stats / promotions", bible: "CON 4 MOV 5 STR 4 DEF 2 MAG 1 + three promo lines", verdict: "MATCH", delta: "promotion_stat_bonuses present." },
  { cls: "Rogue", skill: "Pass (innate)", bible: "Standard move always GHOST. [+] through-enemy ignore DEF this turn", verdict: "MATCH", delta: "GHOST/traps on innate. [+] pierce gated by is_passive_upgraded(pass)." },
  { cls: "Rogue", skill: "Slip Past", bible: "1 MOV through unit to empty behind. [+] DEF−1", verdict: "MATCH", delta: "TELEPORT_CASTER land_opposite_target. [+] target DEF−1." },
  { cls: "Rogue", skill: "Backstab", bible: "From behind ignore DEF. [+] BLEED WPN", verdict: "MATCH", delta: "rogue_systems backstab." },
  { cls: "Rogue", skill: "Blink Mastery", bible: "After teleport next ATK+3. [+] +4", verdict: "MATCH", delta: "after_teleport + damage_bonus." },
  { cls: "Rogue", skill: "Lethal Position", bible: "+1 STR +1 RANGE per tile from start. [+] +1 DEF/tile", verdict: "MATCH", delta: "STR/DEF via dynamic_stat_adjustments. RANGE capped +2." },
  { cls: "Rogue", skill: "Shadow Strike", bible: "Teleport adj → MARK+ROOT. [+] SILENCE", verdict: "MATCH", delta: "after_teleport." },
  { cls: "Rogue", skill: "Killing Intent", bible: "End adj <50% HP → 1 AP next turn. [+] <75%", verdict: "MATCH", delta: "turn_end." },
  { cls: "Rogue", skill: "Shadow Clone", bible: "On Kill decoy TAUNT 1 turn. [+] explode ATK 2", verdict: "MATCH", delta: "TAUNT on adjacent enemies. [+] ATK 2 3×3 on decoy death." },
  { cls: "Rogue", skill: "Phase Shift", bible: "Teleport STEALTH until next attack. [+] first attack ignore DEF", verdict: "MATCH", delta: "stealth_until_attack consumed on hit. [+] gated by phase_shift upgrade." },
  { cls: "Rogue", skill: "Blink Strike", bible: "Basic RANGE 2 teleports to target. [+] RANGE 3", verdict: "MATCH", delta: "try_blink_strike teleports adjacent before basic DAMAGE." },
  { cls: "Rogue", skill: "Shadow Meld", bible: "In SMOKE skills MAG ATK+2 and 0 AP 1/turn. [+] +3", verdict: "MATCH", delta: "CLASS_SKILL gate." },
  { cls: "Rogue", skill: "Shadow Slip", bible: "Through enemy BLIND+MARK; attack MARK refund 1 MOV + WPN. [+] POISON", verdict: "MATCH", delta: "MOV refund on_attack_hit. WPN in damage_bonus." },
  { cls: "Rogue", skill: "Miasma Spreader", bible: "Attack debuffed → spread adj. [+] RANGE 2", verdict: "MATCH", delta: "on_attack_hit." },
  { cls: "Rogue", skill: "Panic Cascade", bible: "Any debuff → extra dmg WPN per unique debuff. [+] 2×WPN if CONFUSION", verdict: "MATCH", delta: "on_debuff_applied true damage. Upgrade gated." },
  { cls: "Rogue", skill: "Debuff Overload", bible: "Turn start +1 true / unique debuff. [+] +2", verdict: "MATCH", delta: "Saboteur turn_start." },
  { cls: "Rogue", skill: "Mind Static", bible: "RANGE 2 −25% DEF cannot SHIELD. [+] RANGE 3 −50%", verdict: "MATCH", delta: "Uses base_defense, not current DEF." },
  { cls: "Rogue", skill: "Board Scrambler", bible: "After dmg swap with highest HP enemy RANGE 3. [+] ROOT", verdict: "MATCH", delta: "on_dealt_damage." },
  { cls: "Rogue", skill: "Shadow Step", bible: "RANGE 4 teleport adj to enemy. [+] behind +1 STR", verdict: "MATCH", delta: "ENEMY unit targeting. Lands ADJACENT_TO_TARGET; upgrade BEHIND_TARGET +1 STR. Bible does not grant a landing-tile pick." },
  { cls: "Rogue", skill: "Kidney Strike", bible: "RANGE 1 ATK 2 −2 MOV 2 turns. [+] behind ROOT", verdict: "MATCH", delta: "STAT_DEBUFF_MOV 2/2." },
  { cls: "Rogue", skill: "Smoke Bomb", bible: "SELF 3x3 SMOKE 2 turns; STEALTH vs outside. [+] allies HEAL 1/turn", verdict: "MATCH", delta: "Outside targeting blocked like STEALTH. [+] HEAL 1/turn on smoke payload." },
  { cls: "Rogue", skill: "Evasive Strike", bible: "MOVE 2 ATK 1 DEF+1. [+] MOVE 3 ATK 2 DEF+2", verdict: "MATCH", delta: "Dual modules." },
  { cls: "Rogue", skill: "Grappling Hook", bible: "RANGE 4 PULL SELF to target OR target to SELF. [+] trap x2", verdict: "MATCH", delta: "Empty tile pulls self in RANGE 4. Occupied pulls until adjacent. Trap ×2 on landing." },
  { cls: "Rogue", skill: "Switcheroo", bible: "RANGE 3 swap enemy. [+] inherits incoming attacks", verdict: "MATCH", delta: "CombatSystem redirects via rogue_redirect_attacks_to_id." },
  { cls: "Rogue", skill: "Blindside", bible: "RANGE 1 ATK 2; unacted STAGGER. [+] if STAGGERED ATK+2", verdict: "MATCH", delta: "Uses turn_action_used (correct)." },
  { cls: "Rogue", skill: "Throat Slit", bible: "RANGE 1 ATK 3 SILENCE. [+] On Kill spread SILENCE", verdict: "MATCH", delta: "On Kill spreads SILENCE to one adjacent enemy (N-E-S-W first)." },
  { cls: "Rogue", skill: "Amnesia Dust", bible: "RANGE 2 ATK 0 BLIND unacted + CONFUSION next turn. [+] POISON", verdict: "MATCH", delta: "can_use rejects acted targets. CONFUSION delayed to their turn start." },
  { cls: "Rogue", skill: "Death Mark", bible: "RANGE 5 MARK. [+] On Kill refresh 0 AP", verdict: "MATCH", delta: "rogue_free_mark_refresh waives AP and the action slot." },
  { cls: "Rogue", skill: "Lethal Flourish", bible: "RANGE 1 ATK 3; debuffed ATK+2. [+] On Kill 1 AP", verdict: "MATCH", delta: "bonus_if_target_debuffed." },
  { cls: "Rogue", skill: "Shadow Swap", bible: "RANGE 3 swap ally. [+] +1 DEF", verdict: "MATCH", delta: "ALLY SWAP." },
  { cls: "Rogue", skill: "Kidnap", bible: "RANGE 1 swap + PUSH 2. [+] collision STAGGER both", verdict: "MATCH", delta: "PUSH retargets swapped enemy away from caster. [+] enemy_collision_stagger_both." },
  { cls: "Rogue", skill: "Shuriken Volley", bible: "CONE 3 ATK 1 BLEED WPN. [+] PIERCE vs BLIND", verdict: "MATCH", delta: "CONE + pierce_vs_blind." },
  { cls: "Rogue", skill: "Poison Flask", bible: "RANGE 3 ATK 1 POISON hazard AOE 1. [+] BLIND on entry", verdict: "MATCH", delta: "AOE_CROSS 1. Hazard payload BLIND-on-entry. No extra instant POISON." },

  { cls: "Monk", skill: "Stats / promotions", bible: "CON 5 MOV 4 STR 3 DEF 2 MAG 4 + Avatar/Mystic/Windwalker", verdict: "MATCH", delta: "promotion_stat_bonuses present." },
  { cls: "Monk", skill: "Way of the Weaver", bible: "Phys → next magic +2 PIERCE; magic → next phys +2 PUSH 1. [+] SHIELD 1", verdict: "MATCH", delta: "ability_system.gd:3496." },
  { cls: "Monk", skill: "Leap", bible: "2 MOV jump OVER 1-tile blocker to empty behind. [+] RANGE 3 absorb element", verdict: "MATCH", delta: "Min/max 2 over one blocker. [+] RANGE 3; landing surface stored for next attack." },
  { cls: "Monk", skill: "Elemental Attunement", bible: "Attack on elemental → PIERCE. [+] BURN/BLEED MAG", verdict: "MATCH", delta: "monk_systems.gd:184." },
  { cls: "Monk", skill: "Chakra Burn", bible: "Hit on hazard → BURN MAG. [+] BLIND", verdict: "MATCH", delta: "monk_systems.gd:282." },
  { cls: "Monk", skill: "Elemental Harmony", bible: "ATK +1 per adj elemental. [+] +2", verdict: "MATCH", delta: "ATK bonus per adjacent elemental tile, not STR." },
  { cls: "Monk", skill: "Catalyst", bible: "+1 MAG +1 DEF on elemental. [+] +1 MOV", verdict: "MATCH", delta: "unit_state.gd:264." },
  { cls: "Monk", skill: "Elemental Shield", bible: "Create terrain → +1 DEF. [+] +2", verdict: "MATCH", delta: "on_terrain_created." },
  { cls: "Monk", skill: "Weaver's Resonance", bible: "Consume weave → shockwave Floor((STR+MAG)/2) phys or mag + SHIELD 1. [+] WEAKEN", verdict: "MATCH", delta: "Hybrid formula. Physical if STR>=MAG else magical. [+] WEAKEN." },
  { cls: "Monk", skill: "Mind over Matter", bible: "Phys scale higher of STR/MAG. [+] +1 DEF if equal", verdict: "MATCH", delta: "ability_system.gd:3102." },
  { cls: "Monk", skill: "Inner Peace", bible: "0 MOV spent → PIERCE. [+] ATK+2", verdict: "MATCH", delta: "movement_points_spent_this_turn==0." },
  { cls: "Monk", skill: "Zen Defense", bible: "+1 MAG/empty adj; 4 empty SHIELD 1. [+] SHIELD 2", verdict: "MATCH", delta: "MAG per empty adjacent. Four empty → SHIELD 1/2." },
  { cls: "Monk", skill: "Perfect Form", bible: "0 dmg last turn → +1 STR +1 MOV. [+] +2/+2", verdict: "MATCH", delta: "turn_start." },
  { cls: "Monk", skill: "Vaulting Strike", bible: "Vault over enemy; attack them ATK+2. [+] +3", verdict: "MATCH", delta: "Leap over an enemy now sets vaulted_target_id. ATK +2/+3 vs that enemy." },
  { cls: "Monk", skill: "Flowing Ki", bible: "Through/over enemy → +1 MAG. [+] +1 STR", verdict: "MATCH", delta: "on_moved_through_enemy." },
  { cls: "Monk", skill: "Evasive Acrobat", bible: "GHOST; through enemy CONFUSION. [+] BLIND", verdict: "MATCH", delta: "monk_ghost_move flag." },
  { cls: "Monk", skill: "Ki Momentum", bible: "+1 STR per 2 tiles before attack. [+] per 1 tile", verdict: "MATCH", delta: "ability_system.gd:3108. Display is Bible Ki Momentum; factory id stays momentum_transfer." },
  { cls: "Monk", skill: "Light Step", bible: "Ignore difficult/traps; end on trap disarms. [+] SHIELD 1", verdict: "MATCH", delta: "movement_system + monk_systems." },
  { cls: "Monk", skill: "Scorching Kick", bible: "RANGE 1 ATK 2 FIRE. [+] if burning MAG ATK 2 splash", verdict: "MATCH", delta: "Upgrade splash is AOE 1 cross (GridSystem)." },
  { cls: "Monk", skill: "Thunder Palm", bible: "RANGE 1 MAG ATK 3; WATER/FROZEN chain 50%. [+] STAGGER", verdict: "MATCH", delta: "surface_chain." },
  { cls: "Monk", skill: "Yin-Yang Flurry", bible: "ATK 1 then MAG ATK 1. [+] first 0 → second PIERCE", verdict: "MATCH", delta: "Two modules + pierce_if_first_zero." },
  { cls: "Monk", skill: "Chakra Shift", bible: "SELF swap STR/MAG 2 turns. [+] MAG ATK 1 AOE 2", verdict: "MATCH", delta: "Flag 2 turns. Upgrade burst is AOE 2 cross." },
  { cls: "Monk", skill: "Phase Throw", bible: "RANGE 1 swap enemy. [+] ROOT", verdict: "MATCH", delta: "SWAP + ROOT layer." },
  { cls: "Monk", skill: "Flying Crane Kick", bible: "DASH 3 ATK 2. [+] absorb hazard into attack", verdict: "MATCH", delta: "Stops adjacent to first enemy in the dash line and ATK 2. Empty line: dash only." },
  { cls: "Monk", skill: "Spirit Palm", bible: "RANGE 2 MAG ATK 2 PUSH 1; collision ATK 2 splash (base). [+] WEAKEN", verdict: "MATCH", delta: "Collision splash on base. [+] WEAKEN on splash." },
  { cls: "Monk", skill: "Soul Punch", bible: "RANGE 1 ATK 3 vs MAG not DEF. [+] steal 1 MAG", verdict: "MATCH", delta: "target_magic_defense." },
  { cls: "Monk", skill: "Hundred Fists", bible: "RANGE 1 ATK 4; −2 MOV next turn. [+] +1 per status", verdict: "MATCH", delta: "Upgrade reads bonus_per_target_status on the ability effect." },
  { cls: "Monk", skill: "Mantra of Peace", bible: "RANGE 0 AOE 2 WEAKEN (no break on DoT). [+] allies HEAL 1", verdict: "MATCH", delta: "SELF/TILE AOE. mantra_peace_weaken. [+] ally HEAL 1." },
  { cls: "Monk", skill: "Inner Fire", bible: "SELF 2 turns; phys MAG ATK 1 splash. [+] splash FIRE", verdict: "MATCH", delta: "Turns decrement at turn end. Lasts 2 turns." },
  { cls: "Monk", skill: "Void Step", bible: "RANGE 3 teleport empty adj to ally. [+] +2 MAG", verdict: "MATCH", delta: "warp_adjacent_to_target." },
  { cls: "Monk", skill: "Cyclone Sweep", bible: "RANGE 1 ARC PUSH 2. [+] +1 MOV per enemy", verdict: "MATCH", delta: "TILE area pick. [+] +1 MOV per enemy pushed." },
  { cls: "Monk", skill: "Updraft", bible: "SELF AIRBORNE +1 MOV 2 turns. [+] pass over BLIND", verdict: "MATCH", delta: "AIRBORNE + blind_on_pass_over." },
  { cls: "Monk", skill: "Geyser Strike", bible: "RANGE 2 MAG ATK 2 PUSH 1 WATER. [+] PUSH 2 if on WATER", verdict: "MATCH", delta: "Base PUSH 1. [+] PUSH 2 only if target is already on WATER." },

  { cls: "Beast Rider", skill: "Stats", bible: "CON 5 MOV 5 STR 3 DEF 2 MAG 2", verdict: "MATCH", delta: "Factory matches." },
  { cls: "Beast Rider", skill: "Gallop", bible: "Split MOV before AND after action. [+] both sides +1 STR and +1 DEF post-move", verdict: "MATCH", delta: "Split-move. Upgrade +1 STR on the attack + +1 DEF post-move." },
  { cls: "Beast Rider", skill: "Griffin / Wyvern AIRBORNE", bible: "Those promotions gain AIRBORNE", verdict: "MATCH", delta: "promotion_stat_bonuses.airborne grants AIRBORNE even without an aerial passive equipped." },
  { cls: "Beast Rider", skill: "Apex Predator promo", bible: "+4 STR +2 CON +3 MOV grounded", verdict: "MATCH", delta: "promotion_stat_bonuses include constitution 2." },
  { cls: "Beast Rider", skill: "Reposition", bible: "2 MOV; you stay; flip unit to opposite empty. [+] RANGE 2", verdict: "MATCH", delta: "Caster stays. Target flips to opposite empty. [+] RANGE 2." },
  { cls: "Beast Rider", skill: "Isolation Tactics", bible: "Isolated +2 STR. [+] also ATK+1 per tile", verdict: "MATCH", delta: "+2 STR vs isolated. Per-tile ATK is upgrade-only." },
  { cls: "Beast Rider", skill: "Terminal Velocity", bible: "Drop/PUSH collision +WPN true + VULNERABLE. [+] drop STAGGER", verdict: "MATCH", delta: "BeastRiderSystems.apply_collision_riders on CombatSystem collision." },
  { cls: "Beast Rider", skill: "Snatch & Grab", bible: "Grapple from RANGE 2. [+] RANGE 3", verdict: "MATCH", delta: "Only Feral Drag." },
  { cls: "Beast Rider", skill: "Safe Landing", bible: "0 hazard; 3x3 PUSH 1. [+] PUSH 2", verdict: "MATCH", delta: "landing_shockwave_size 1 = 3x3." },
  { cls: "Beast Rider", skill: "Aerial Superiority", bible: "+2 DEF vs grounded melee. [+] immune grounded ROOT", verdict: "MATCH", delta: "CombatSystem mitigation + try_resist_crowd_control." },
  { cls: "Beast Rider", skill: "Mount Resilience", bible: "Ranged −Floor(DEF/2)+1. [+] +2", verdict: "MATCH", delta: "incoming_damage_reduction." },
  { cls: "Beast Rider", skill: "Beast's Instinct", bible: "Miss/0 dmg → +1 STR +1 AP. [+] SHIELD 1", verdict: "MATCH", delta: "CombatSystem.on_zero_incoming_damage." },
  { cls: "Beast Rider", skill: "Territorial", bible: "Enemy enter adj → ATK 1. [+] ATK 2", verdict: "MATCH", delta: "on_enemy_entered_adjacent." },
  { cls: "Beast Rider", skill: "Intimidating Presence", bible: "RANGE 2 −1 DEF −1 MOV. [+] RANGE 3", verdict: "MATCH", delta: "Aura while in range, not a permanent stamp." },
  { cls: "Beast Rider", skill: "Dive Bomber", bible: "Move 4+ before attack ATK+2. [+] 3+", verdict: "MATCH", delta: "beast_tiles_moved." },
  { cls: "Beast Rider", skill: "Pack Hunter", bible: "Attack isolated → follow-up ATK 1 ignore 50% DEF. [+] ATK 2", verdict: "MATCH", delta: "Follow-up on hit. Ignores 50% DEF. [+] ATK 2." },
  { cls: "Beast Rider", skill: "Blood Trail", bible: "+1 MOV + PIERCE toward BLEED. [+] +2 MOV", verdict: "MATCH", delta: "BeastRiderSystems grants MOV when closing on BLEED; PIERCE already worked. Display is Bible Blood Trail; factory id stays blood_scent." },
  { cls: "Beast Rider", skill: "Vantage Striker", bible: "Ignore difficult; +1 STR in hazards or higher elevation. [+] +2", verdict: "MATCH", delta: "Ignore difficult. +1 STR in hazards or elevated tiles. [+] +2 STR." },
  { cls: "Beast Rider", skill: "Predatory Drive", bible: "Vs BLEED/isolated → BLEED WPN. [+] POISON", verdict: "MATCH", delta: "weapon might." },
  { cls: "Beast Rider", skill: "Furious Charge", bible: "Straight 3+ → PUSH 1 next attack. [+] PUSH 2", verdict: "MATCH", delta: "Uses continuous straight tiles, not turning Manhattan." },
  { cls: "Beast Rider", skill: "Pounce", bible: "MOVE 3 ATK 3 land adjacent. [+] PUSH 1", verdict: "MATCH", delta: "Lands adjacent via shared move_to_target_adjacent. [+] PUSH on that hit." },
  { cls: "Beast Rider", skill: "Feral Drag", bible: "RANGE 1 CON≤STR; drag remaining MOV. [+] redirect incoming", verdict: "MATCH", delta: "redirect_incoming_damage stamps beast_redirect_to_id; CombatSystem consumes it." },
  { cls: "Beast Rider", skill: "Maul", bible: "Sub-skill of drag: ATK 2 drop adj. [+] trap 200%", verdict: "MATCH", delta: "0 AP, no action slot, drag-gated, drop adjacent, trap multiplier." },
  { cls: "Beast Rider", skill: "Bestial Roar", bible: "CONE 3 PUSH 2; FEAR if debuffed. [+] DEF−1", verdict: "MATCH", delta: "PUSH always. FEAR only if debuffed. [+] DEF−1 on cone enemies." },
  { cls: "Beast Rider", skill: "Raking Claws", bible: "RANGE 1 ARC ATK 2 BLEED WPN. [+] PULL 1 first", verdict: "MATCH", delta: "bleed_weapon scales ADD_STATUS; pull_before_attack runs before damage." },
  { cls: "Beast Rider", skill: "Rest & Recover", bible: "1 AP + consume remaining MOV; HEAL 1 DEF+5. [+] CLEANSE", verdict: "MATCH", delta: "CLASS_SKILL consumes remaining MOV. HEAL 1 DEF+5. [+] CLEANSE." },
  { cls: "Beast Rider", skill: "Intimidate", bible: "RANGE 0 AOE 2 STAGGER lower HP. [+] PURGE", verdict: "MATCH", delta: "AOE_CROSS. lower_hp_only and purge_buffs consumed." },
  { cls: "Beast Rider", skill: "Fetch", bible: "RANGE 4 item/corpse to adj. [+] light allies 2", verdict: "MATCH", delta: "fetch_item_or_corpse pulls items/corpses; upgraded PULL light allies." },
  { cls: "Beast Rider", skill: "Savage Bite", bible: "RANGE 1 ATK 4 requires BLEED/POISON. [+] On Kill SHIELD 2", verdict: "MATCH", delta: "can_use_extra + on_kill_shield." },
  { cls: "Beast Rider", skill: "Run Down (Beast)", bible: "DASH 3 ATK 2; pass adj PUSH 1. [+] BLEED WPN", verdict: "MATCH", delta: "trample_atk 2, pass-adj PUSH, upgraded BLEED WPN." },
  { cls: "Beast Rider", skill: "Thrash", bible: "RANGE 1 ATK 1 ×3. [+] each BLEED WPN", verdict: "MATCH", delta: "repeat_hits 3. Upgrade BLEED WPN." },
  { cls: "Beast Rider", skill: "Defensive Posture", bible: "SELF INTERCEPT 50% +2 DEF. [+] if hit PUSH 2", verdict: "MATCH", delta: "intercept_push_attacker consumed in CombatSystem intercept." },
  { cls: "Beast Rider", skill: "Airlift", bible: "Pick ally Step 1; drop empty Step 3. [+] ally +1 STR", verdict: "MATCH", delta: "airlift_keep_caster skips rider teleport; pickup/drop on shared-tile path." },
  { cls: "Beast Rider", skill: "Tail Swipe", bible: "RANGE 0 AOE 3x3 ATK 1 PUSH 2. [+] wall STAGGER", verdict: "MATCH", delta: "Square size 1 = 3x3. [+] wall_collision_stagger on object collision." },
  { cls: "Beast Rider", skill: "Gore", bible: "RANGE 1 ATK 2 PUSH 1; BLEED → ATK+2. [+] VULNERABLE", verdict: "MATCH", delta: "bleed_bonus_damage 2 via MercenarySystems.adjust_attack_base. PUSH 1 layer. Upgrade VULNERABLE." },

  { cls: "Mage", skill: "Stats / promotions", bible: "CON 3 MOV 4 STR 1 DEF 1 MAG 5 + three promo lines", verdict: "MATCH", delta: "promotion_stat_bonuses present." },
  { cls: "Mage", skill: "Arcane Overchannel", bible: "Spell → stack max 3 +1 MAG ATK; persist; decay if no spell. [+] at 3: 1 AP 1/turn + SHIELD 2", verdict: "MATCH", delta: "Refund+SHIELD 2 gated on innate upgrade." },
  { cls: "Mage", skill: "Blink", bible: "3 MOV teleport ≤2. [+] RANGE 3 leave surface", verdict: "MATCH", delta: "Surface is always FIRE." },
  { cls: "Mage", skill: "Elementalist", bible: "Fire→FIRE Ice→FROZEN Lightning hits ALL on water/ice. [+] WPN on new terrain", verdict: "MATCH", delta: "Lightning-all on the passive (and Chain Lightning [+]). WPN upgrade-only." },
  { cls: "Mage", skill: "Feedback", bible: "Create terrain +1 MAG SHIELD 1. [+] SHIELD 2", verdict: "MATCH", delta: "ability_system.gd:4491." },
  { cls: "Mage", skill: "Elemental Master", bible: "+1 MAG per elemental tile. [+] +1 DEF if 3+", verdict: "MATCH", delta: "unit_state applies upgraded DEF at the 3-tile threshold." },
  { cls: "Mage", skill: "Lasting Terrain", bible: "+1 duration +1 hazard. [+] +2 hazard", verdict: "MATCH", delta: "ability_system.gd:4474." },
  { cls: "Mage", skill: "Surface Syphoner", bible: "End on own surface HEAL 1 CLEANSE. [+] HEAL 1 SHIELD 1", verdict: "MATCH", delta: "simulator.gd:360." },
  { cls: "Mage", skill: "Mana Leak", bible: "On damaged MAG ATK 1 adj. [+] 2", verdict: "MATCH", delta: "combat_system.gd:1190." },
  { cls: "Mage", skill: "Arcane Overdrive", bible: "+3 MAG; 5% HP/spell; 50% SHIELD bypass. [+] +4 MAG", verdict: "MATCH", delta: "unit_state + ability_system + combat_system." },
  { cls: "Mage", skill: "Mana Well", bible: "End on elemental → next spell 0 AP. [+] +1 MAG next turn", verdict: "MATCH", delta: "simulator.gd:374." },
  { cls: "Mage", skill: "Mana Siphon", bible: "Spell kill 1 AP (cap) else heal MAG + stack. [+] HEAL 1", verdict: "MATCH", delta: "combat_system.gd:1061." },
  { cls: "Mage", skill: "Overload", bible: "+2 MAG. Cannot gain SHIELD. [+] +3 MAG instead", verdict: "MATCH", delta: "Upgrade replaces +2 with +3. No tick. Shield blocked." },
  { cls: "Mage", skill: "Wild Magic", bible: "Enemy on hazard → spell twice 2nd 0 AP. [+] 2nd +1 MAG", verdict: "MATCH", delta: "ability_system.gd:4901." },
  { cls: "Mage", skill: "Arcane Tether", bible: "Enemy moves adj MAG ATK 1 ROOT. [+] MAG ATK 2", verdict: "MATCH", delta: "movement_system.gd:957." },
  { cls: "Mage", skill: "Arcane Mastery", bible: "AOE +1 radius. [+] PIERCE", verdict: "MATCH", delta: "AOE +1 radius. Upgrade PIERCE via upgrade flag." },
  { cls: "Mage", skill: "Arcane Attunement", bible: "Spell on ally +1 DEF +1 STR. [+] +1 MOV", verdict: "MATCH", delta: "ability_system.gd:4922." },
  { cls: "Mage", skill: "Gravity Anchor", bible: "Rooted take +1 spell dmg. [+] +2", verdict: "MATCH", delta: "ability_system.gd:3018." },
  { cls: "Mage", skill: "Fireball", bible: "RANGE 4 AOE 1 (cross) MAG ATK 3 FIRE. [+] FROZEN → STEAM 3x3 MAG ATK 2", verdict: "MATCH", delta: "Steam splash on frozen is upgrade-only; sim-proven 3x3 MAG ATK 2." },
  { cls: "Mage", skill: "Ice Shard", bible: "RANGE 4 MAG ATK 2 MAX MOV=1 FROZEN. [+] FIRE → STEAM 3x3", verdict: "MATCH", delta: "Steam splash default is 3x3 (size 1)." },
  { cls: "Mage", skill: "Chain Lightning", bible: "RANGE 4 MAG ATK 2 bounce 2 RANGE 2. [+] WATER/FROZEN all", verdict: "MATCH", delta: "bounce + strike_all_surface." },
  { cls: "Mage", skill: "Arcane Push", bible: "RANGE 3 MAG ATK 1 PUSH 3. [+] trail MAG ATK 1", verdict: "MATCH", delta: "Trail deals MAG ATK 1 via TerrainSystem + owner." },
  { cls: "Mage", skill: "Teleport", bible: "RANGE 4 visible empty. [+] SHIELD 1 land", verdict: "MATCH", delta: "RANGE 4 empty tile. Upgrade landing SHIELD 1." },
  { cls: "Mage", skill: "Meteor", bible: "RANGE 5 AOE 2 (cross) MAG ATK 5 delayed Step 1 next turn. [+] CRATER BURN", verdict: "MATCH", delta: "Queued this turn; impacts next simulate Step 1. [+] crater + BURN MAG." },
  { cls: "Mage", skill: "Black Hole", bible: "RANGE 4 AOE 2 PULL 2 to center. [+] pull hazards", verdict: "MATCH", delta: "pull_to_center uses the aimed tile, not the Mage." },
  { cls: "Mage", skill: "Time Warp", bible: "RANGE 3 ally +1 AP spend 4 HP. [+] cooldowns −1", verdict: "MATCH", delta: "cooldown_reduction ticks ability_cooldowns and restores once-per-turn uses." },
  { cls: "Mage", skill: "Mana Shield", bible: "SELF SHIELD X with X=MAG. Cannot cast. [+] 1 SHIELD/spell", verdict: "MATCH", delta: "Uses CombatSystem.add_shield_x (10% Max HP × MAG)." },
  { cls: "Mage", skill: "Disintegrate", bible: "RANGE 3 MAG ATK 6; On Kill destroy corpse. [+] 1 AP", verdict: "MATCH", delta: "destroy_corpse_on_kill." },
  { cls: "Mage", skill: "Gravity Well", bible: "RANGE 4 AOE 2 ROOT. [+] BLIND", verdict: "MATCH", delta: "ROOT is hostile; allies in the cross are skipped. Sim-proven." },
  { cls: "Mage", skill: "Elemental Surge", bible: "SELF next spell +2 Range +2 AOE. [+] +1 AP", verdict: "MATCH", delta: "ability_system.gd:4638." },
  { cls: "Mage", skill: "Earth Spike", bible: "RANGE 4 obstacle 50% Max HP. [+] MAG ATK 1 adj", verdict: "MATCH", delta: "obsidian_wall 50% + creation_adjacent_damage." },
  { cls: "Mage", skill: "Density Shift", bible: "RANGE 3 double mit OR STURDY 2. [+] WEAKEN enemies", verdict: "MATCH", delta: "Ally STURDY / enemy mit×2." },
  { cls: "Mage", skill: "Arcane Barrage", bible: "RANGE 4 MAG ATK 1 ×3. [+] ignore 25% MAG", verdict: "MATCH", delta: "repeat_hits 3." },

  { cls: "Archer", skill: "Stats", bible: "CON 3 MOV 4 STR 4 DEF 1 MAG 1", verdict: "MATCH", delta: "Factory matches." },
  { cls: "Archer", skill: "Snap Shot", bible: "RANGE 2 ATK 1 0 AP", verdict: "MATCH", delta: "data_library.gd:817." },
  { cls: "Archer", skill: "Promotion boosts", bible: "Sniper / Trapper / Nomad", verdict: "MATCH", delta: "promotion_stat_bonuses now authored." },
  { cls: "Archer", skill: "Steady Aim", bible: "Spend Max MOV standing still → +1 RANGE +1 STR. [+] +2 + PIERCE", verdict: "MATCH", delta: "Standing still spends remaining MOV. Range/STR persist via steady_aim_triggered." },
  { cls: "Archer", skill: "Sidestep", bible: "1 MOV cardinal; no facing change; no ZOC. [+] +1 STR next ranged", verdict: "MATCH", delta: "preserve_facing honored on skill walk. Upgrade next_ranged_attack_strength consumed on the next ranged hit." },
  { cls: "Archer", skill: "Overwatch", bible: "Unspent AP → cone; first enemy in LOS takes WPN basic", verdict: "MATCH", delta: "Cone from facing. First enemy in cone+LOS. Upgrade ROOT." },
  { cls: "Archer", skill: "High Ground", bible: "Elevation +1 RANGE ignore 50% DEF", verdict: "MATCH", delta: "ability_system.gd:538." },
  { cls: "Archer", skill: "Vantage Anchor", bible: "Triggering Steady Aim → STURDY + STEALTH vs >3. [+] +1 STR", verdict: "MATCH", delta: "Fires only when Steady Aim spends remaining MOV. STEALTH value 3." },
  { cls: "Archer", skill: "True Sight", bible: "Ignore cover + STEALTH", verdict: "MATCH", delta: "ability_system.gd:3250." },
  { cls: "Archer", skill: "Piercing Momentum", bible: "Shot traveling 4+ tiles PIERCE", verdict: "MATCH", delta: "long_shot_pierce_distance 4." },
  { cls: "Archer", skill: "Camouflage", bible: "0 MOV → STEALTH Range>3. [+] next attack +2 STR", verdict: "MATCH", delta: "STEALTH value 3. Upgrade +2 STR on the attack out of STEALTH." },
  { cls: "Archer", skill: "Area Denial", bible: "Traps ROOT + WPN true. [+] POISON", verdict: "MATCH", delta: "ability_system.gd:4524." },
  { cls: "Archer", skill: "Caltrop Expert", bible: "Caltrops 0 AP. [+] ATK+2", verdict: "MATCH", delta: "Caltrop Trap costs 1 AP. Expert waives AP and the action slot once per turn. ATK+2 MATCH." },
  { cls: "Archer", skill: "Zone Control", bible: "Enter RANGE 3: 1 true PUSH 1. [+] 2 dmg", verdict: "MATCH", delta: "movement_system.gd:1017." },
  { cls: "Archer", skill: "Sticky Mud", bible: "Difficult +1 MOVE, removes FEAR. [+] ROOT", verdict: "MATCH", delta: "ability_system.gd:4533." },
  { cls: "Archer", skill: "Fletching Hoarder", bible: "Corpse → next ATK+2. [+] +3", verdict: "MATCH", delta: "ability_system.gd:3078." },
  { cls: "Archer", skill: "Prey Sighted", bible: "Move-penalty +2 STR ignore 25% DEF. [+] 50%", verdict: "MATCH", delta: "ability_system.gd:3088." },
  { cls: "Archer", skill: "Barrage", bible: "Exact lethal → ATK 1 nearest. [+] ATK 2", verdict: "MATCH", delta: "combat_system.gd:1099." },
  { cls: "Archer", skill: "Target Painter", bible: "Debuffed +2 STR. [+] PIERCE vs debuffed", verdict: "MATCH", delta: "PIERCE is upgrade-gated via upgraded_debuffed_attack_pierce." },
  { cls: "Archer", skill: "Rapid Fire", bible: "After attack +1 MOVE. [+] +2", verdict: "MATCH", delta: "ability_system.gd:2657." },
  { cls: "Archer", skill: "Power Shot", bible: "RANGE 5 ATK 3 PUSH 1. [+] collision PIERCE ATK 2", verdict: "MATCH", delta: "physics_system.gd:596." },
  { cls: "Archer", skill: "Volley", bible: "RANGE 4 AOE 3x3 ATK 1. [+] difficult", verdict: "MATCH", delta: "Square size 1 = 3x3." },
  { cls: "Archer", skill: "Pinning Arrow", bible: "RANGE 4 ATK 1 ROOT (breaks on dmg). [+] push rooted BLEED WPN", verdict: "MATCH", delta: "PhysicsSystem.push applies BLEED WPN when ROOT blocks the shove." },
  { cls: "Archer", skill: "Piercing Shot", bible: "SKEWER 4 ATK 2 PIERCE. [+] bounce 45°", verdict: "MATCH", delta: "LINE uses GridSystem.line_with_wall_bounce_45 when bounce_walls_45 is set." },
  { cls: "Archer", skill: "Toxic Spore Arrow", bible: "RANGE 5 ATK 1 POISON. [+] spread adj", verdict: "MATCH", delta: "spread_status_adjacent." },
  { cls: "Archer", skill: "Grapple Arrow", bible: "RANGE 4 wall PULL SELF adj. [+] pass enemy ATK 2", verdict: "MATCH", delta: "grapple_wall_pull_self." },
  { cls: "Archer", skill: "Explosive Arrow", bible: "RANGE 4 AOE 1 (cross) ATK 2 destroy terrain. [+] ignite", verdict: "MATCH", delta: "Factory is AOE_CROSS size 1." },
  { cls: "Archer", skill: "Hunter's Mark", bible: "RANGE 5 MARK; allies +1 RANGE PIERCE vs target. [+] no STEALTH/Teleport", verdict: "MATCH", delta: "Mark stores ally team RANGE/PIERCE. No global pierce-on-MARK." },
  { cls: "Archer", skill: "Repelling Shot", bible: "RANGE 2 ATK 1 PUSH 3. [+] ally ATK 0 PUSH 3", verdict: "MATCH", delta: "ALLY|ENEMY targeting. Upgrade zeros damage vs allies." },
  { cls: "Archer", skill: "Bear Trap", bible: "RANGE 3 ATK 3 ROOT. [+] VULNERABLE", verdict: "MATCH", delta: "terrain + trap_vulnerable." },
  { cls: "Archer", skill: "Suppressing Fire", bible: "RANGE 4 ARC hazard; cross WPN + −1 MOV. [+] BLIND", verdict: "MATCH", delta: "Authored RANGE 4 ARC. BLIND MATCH." },
  { cls: "Archer", skill: "Caltrop Trap", bible: "RANGE 3 ROOT + BLEED WPN. [+] −2 DEF", verdict: "MATCH", delta: "Costs 1 AP. Expert makes it 0 AP. DEF−2 MATCH." },
  { cls: "Archer", skill: "Parting Shot", bible: "RANGE 3 ATK 2 then MOVE 2. [+] GHOST", verdict: "MATCH", delta: "ON_POST MOVE 2." },
  { cls: "Archer", skill: "Scout's Eye", bible: "RANGE 5 strip STEALTH PURGE. [+] VULNERABLE", verdict: "MATCH", delta: "PURGE covers STEALTH." },

  { cls: "Cleric", skill: "Stats / promotions", bible: "CON 4 MOV 4 STR 1 DEF 1 MAG 4 + Paladin/Seraph/Zealot", verdict: "MATCH", delta: "promotion_stat_bonuses present." },
  { cls: "Cleric", skill: "Selfless Siphon", bible: "25% of heal to self. [+] 50% overflow SHIELD", verdict: "MATCH", delta: "ability_system.gd:880." },
  { cls: "Cleric", skill: "Guardian Step", bible: "All MOV warp adj ally RANGE 5. [+] GLOBAL CLEANSE", verdict: "MATCH", delta: "cost_all_movement + warp adjacent." },
  { cls: "Cleric", skill: "Blood Donation", bible: "Overheal SHIELD; drain equal HP. [+] +1 STR", verdict: "MATCH", delta: "ability_system.gd:857." },
  { cls: "Cleric", skill: "Sacred Shield", bible: "Full-HP allies +2 DEF debuff immune. [+] +1 MAG", verdict: "MATCH", delta: "simulator.gd:328." },
  { cls: "Cleric", skill: "Divine Blessing", bible: "Heal ally +1 STR / +2 if Max HP. [+] +2 STR 2 turns", verdict: "MATCH", delta: "ability_system.gd:931." },
  { cls: "Cleric", skill: "Frontline Medic", bible: "Heal +1 if adj enemy. [+] +2", verdict: "MATCH", delta: "Caster adjacency." },
  { cls: "Cleric", skill: "Armor of Faith", bible: "Heal ally both +1 DEF. [+] +2", verdict: "MATCH", delta: "ability_system.gd:946." },
  { cls: "Cleric", skill: "Divine Overflow", bible: "HEAL ally at Max HP → MAG ATK 1 pulse. [+] 2", verdict: "MATCH", delta: "Pulses only if the ally was already at Max HP. Pulse uses CombatSystem.deal_mag_atk." },
  { cls: "Cleric", skill: "Divine Intervention", bible: "1/combat lethal ally → 1 HP teleport to you. [+] SHIELD 2", verdict: "MATCH", delta: "Save MATCH. Upgrade SHIELD 2 uses add_shield_x (10% Max HP × 2)." },
  { cls: "Cleric", skill: "Holy Ground (passive)", bible: "Every turn HEAL 1 adj allies PURGE enemies. [+] BLIND", verdict: "MATCH", delta: "HEAL 1 is Floor(10% Max HP). BLIND MATCH." },
  { cls: "Cleric", skill: "Prayer", bible: "Not attacking doubles next heal. [+] CLEANSE", verdict: "MATCH", delta: "simulator.gd:399." },
  { cls: "Cleric", skill: "Purity", bible: "Poison/Bleed instead HEAL 2 +1 MAG. [+] CLEANSE", verdict: "MATCH", delta: "DoT never lands. HEAL 2 is Floor(20% Max HP)." },
  { cls: "Cleric", skill: "Martyr's Blood", bible: "When hit MAG ATK 1 adj. [+] 2", verdict: "MATCH", delta: "deal_mag_atk uses (X+WPN)*(1+MAG/5)." },
  { cls: "Cleric", skill: "Divine Retribution", bible: "Enemy hits ally RANGE 3 → MAG ATK 1. [+] 2", verdict: "MATCH", delta: "deal_mag_atk." },
  { cls: "Cleric", skill: "Holy Radiance", bible: "Allies RANGE 2 +1 MAG +1 STR. [+] +1 DEF", verdict: "MATCH", delta: "Self also in RANGE 0." },
  { cls: "Cleric", skill: "Retribution", bible: "Melee MAG ATK 1 PUSH 1. [+] PUSH 2", verdict: "MATCH", delta: "deal_mag_atk then PUSH." },
  { cls: "Cleric", skill: "Zealous Protection", bible: "Allies damaged +1 STR. [+] +1 DEF", verdict: "MATCH", delta: "combat_system.gd:1323." },
  { cls: "Cleric", skill: "Holy Light", bible: "RANGE 3 Ally MAG HEAL 3. Enemy MAG ATK 2. [+] Enemy MAG ATK 4", verdict: "MATCH", delta: "Ally MAG HEAL 3. Enemy MAG ATK 2/4 via enemy_mag_atk." },
  { cls: "Cleric", skill: "Smite", bible: "RANGE 3 MAG ATK 2. [+] closest ally SHIELD 50% dmg", verdict: "MATCH", delta: "50% of damage dealt." },
  { cls: "Cleric", skill: "Cleansing Aura", bible: "RANGE 0 AOE 2 CLEANSE allies PURGE enemies. [+] STR+1/debuff", verdict: "MATCH", delta: "AOE 2 = cross." },
  { cls: "Cleric", skill: "Sanctuary", bible: "RANGE 2 1-tile STEALTH+INVULNERABLE 2 turns. [+] enemies PUSH 1", verdict: "MATCH", delta: "simulator + terrain_system." },
  { cls: "Cleric", skill: "Blinding Ray", bible: "SKEWER 4 MAG ATK 1 BLIND. [+] also CONFUSION", verdict: "MATCH", delta: "Upgrade keeps BLIND and adds CONFUSION." },
  { cls: "Cleric", skill: "Divine Hammer", bible: "RANGE 2 obstacle 25% HP MAG ATK 2 PUSH 1. [+] HOLY AURA", verdict: "MATCH", delta: "Adjacent MAG ATK 2 + PUSH 1 from the obstacle. Upgrade sets holy_aura." },
  { cls: "Cleric", skill: "Life Link", bible: "Ally dmg −3; suffer 2 self-dmg. [+] no self-dmg", verdict: "MATCH", delta: "−3 incoming, no INTERCEPT. Base DAMAGE_SELF 2; upgrade omits it." },
  { cls: "Cleric", skill: "Prayer of Fortitude", bible: "RANGE 3 ally DEF+3 STURDY. [+] melee counter", verdict: "MATCH", delta: "counterattack_melee." },
  { cls: "Cleric", skill: "Resurrection", bible: "RANGE 1 revive 10% spend 10 HP. [+] SHIELD 2", verdict: "MATCH", delta: "Living allies fail. Corpse revive 10%. Upgrade SHIELD 2 uses add_shield_x." },
  { cls: "Cleric", skill: "Consecrate Ground", bible: "RANGE 0 AOE 2 HEAL 1 allies / MAG ATK 1 enemies. [+] −1 DEF", verdict: "MATCH", delta: "Ally start-of-turn HEAL 1 (10% Max HP). Enemy entry MAG ATK 1. DEF−1 MATCH." },
  { cls: "Cleric", skill: "Holy Wrath", bible: "RANGE 3 MAG ATK 3; debuffed STAGGER. [+] PUSH 2", verdict: "MATCH", delta: "stagger_if_debuffed." },
  { cls: "Cleric", skill: "Divine Guidance", bible: "RANGE 3 ally +1 AP; SELF MOV=0 next turn. [+] self not rooted", verdict: "MATCH", delta: "Upgrade grants AP only; does not zero MOV." },
  { cls: "Cleric", skill: "Shield of Faith", bible: "RANGE 2 SHIELD 3 INTERCEPT 50%. [+] ATK 1 on intercept", verdict: "MATCH", delta: "SHIELD 3 uses MAX_HP scaling (30% Max HP). INTERCEPT MATCH." },
  { cls: "Cleric", skill: "Martyr's Chains", bible: "RANGE 3 link two enemies; magic → MAG ATK 1. [+] BLIND", verdict: "MATCH", delta: "Second enemy is a NEW_AIM pick. Missing second pick fails loud. MAG ATK 1 share." },

  { cls: "Shaman", skill: "Stats / promotions", bible: "CON 3 MOV 4 STR 1 DEF 1 MAG 4 + three promo lines", verdict: "MATCH", delta: "promotion_stat_bonuses present." },
  { cls: "Shaman", skill: "Hexing Presence", bible: "RANGE 2 of shaman OR totem: −2 STR −2 MAG −2 DEF no SHIELD. [+] RANGE 3 −1 MOV", verdict: "MATCH", delta: "shaman_systems.gd:787 includes totems." },
  { cls: "Shaman", skill: "Usher", bible: "2 MOV; you stay; ally RANGE 2 steps 1 empty. [+] RANGE 4 totems 2", verdict: "MATCH", delta: "Dual NEW_AIM: ally then empty tile. Caster stays. Upgrade RANGE 4 / totem 2." },
  { cls: "Shaman", skill: "Echoing Spirits", bible: "Totems pulse twice; hazard dmg → next +1 MAG. [+] +2 HP", verdict: "MATCH", delta: "pulse_count 2 matches Bible twice." },
  { cls: "Shaman", skill: "Spiritual Offering", bible: "Summon/spend HP → SHIELD 1. [+] 2", verdict: "MATCH", delta: "shaman_systems.gd:482." },
  { cls: "Shaman", skill: "Spiritual Guardian", bible: "Totems/linked/ghost +1 DEF adj. [+] +2", verdict: "MATCH", delta: "shaman_systems.gd:416." },
  { cls: "Shaman", skill: "Miasma Resonance", bible: "In hex aura +1 DoT −1 MOV. [+] +2 DoT", verdict: "MATCH", delta: "DoT bonus from shaman body, not totem ring." },
  { cls: "Shaman", skill: "Voodoo Conduit", bible: "Totem/link/debuff range+AOE +1. [+] +2", verdict: "MATCH", delta: "ability_system.gd:219." },
  { cls: "Shaman", skill: "Voodoo Doll", bible: "When hit closest debuffed WPN true. [+] WPN×2", verdict: "MATCH", delta: "shaman_systems.gd:764." },
  { cls: "Shaman", skill: "Spirit Link", bible: "Linked take WPN when hit. [+] WPN×2", verdict: "MATCH", delta: "on Voodoo Link create." },
  { cls: "Shaman", skill: "Pain Sharing", bible: "Linked +1 all sources. [+] +2", verdict: "MATCH", delta: "incoming_damage_bonus." },
  { cls: "Shaman", skill: "Sympathetic Magic", bible: "Linked ally healed → HEAL 1 +1 MAG. [+] +2 MAG", verdict: "MATCH", delta: "shaman_systems.gd:194." },
  { cls: "Shaman", skill: "Linked Ripple", bible: "PUSH linked → PUSH 1 all linked. [+] PUSH 2", verdict: "MATCH", delta: "on_push_resolved. Display is Bible Linked Ripple; factory id stays chain_reaction." },
  { cls: "Shaman", skill: "Soul Collector", bible: "On Kill orb MAG+1 MaxHP+1 cap 3. [+] cap 5", verdict: "MATCH", delta: "drop + ally enter collect." },
  { cls: "Shaman", skill: "Hexing Touch", bible: "Melee attackers permanent STR−1 DEF−1. [+] −1 MOV", verdict: "MATCH", delta: "shaman_systems.gd:871." },
  { cls: "Shaman", skill: "Ritual Sacrifice", bible: "1/turn 3 HP instead of AP. [+] 1 HP", verdict: "MATCH", delta: "ability_system.gd:1135." },
  { cls: "Shaman", skill: "Soul Burn", bible: "Debuffed +1 dmg −1 MOV. [+] +2 dmg", verdict: "MATCH", delta: "shaman_systems.gd:22." },
  { cls: "Shaman", skill: "Soul Weaver", bible: "Heal removes oldest debuff → nearest enemy. [+] 2 nearest", verdict: "MATCH", delta: "shaman_systems.gd:430." },
  { cls: "Shaman", skill: "Curse of Weakness", bible: "RANGE 4 STR−2 DEF−2 3 turns. [+] Push Mit 0", verdict: "MATCH", delta: "STAT_BUFF_STR −2 plus DEF layer. No WEAKEN/MAG. Upgrade Push Mit 0." },
  { cls: "Shaman", skill: "Healing Totem", bible: "RANGE 2 AOE 2 HEAL 1. [+] CLEANSE", verdict: "MATCH", delta: "Bible is HEAL 1 (not MAG HEAL). Pulse CLEANSE is upgrade-only." },
  { cls: "Shaman", skill: "Flame Totem", bible: "AOE 2 MAG ATK 1. [+] pulse FIRE", verdict: "MATCH", delta: "Base pulse MAG ATK 1. FIRE terrain is upgrade-only." },
  { cls: "Shaman", skill: "Bloodlust", bible: "RANGE 3 STR+2 DEF−2 MOV+1 2 HP/turn. [+] BLEED", verdict: "MATCH", delta: "tick + BLEED WPN." },
  { cls: "Shaman", skill: "Hex", bible: "RANGE 3 WITHER 1t; HP<Max; bosses 25%. [+] VULNERABLE", verdict: "MATCH", delta: "shaman_wither 50%/25%. WEAKEN status never applied." },
  { cls: "Shaman", skill: "Voodoo Link", bible: "RANGE 3 pick 2 enemies; shared WPN. [+] shared PUSH", verdict: "MATCH", delta: "Second enemy is NEW_AIM. Missing partner fails loud. Shared PUSH is upgrade." },
  { cls: "Shaman", skill: "Terrify", bible: "RANGE 2 FEAR if debuffed. [+] boss strip SHIELD + VULNERABLE", verdict: "MATCH", delta: "FEAR requires debuff. Boss SHIELD strip + VULNERABLE is upgrade-only." },
  { cls: "Shaman", skill: "Miasma", bible: "RANGE 3 MAG ATK 1 POISON. [+] spread on PUSH", verdict: "MATCH", delta: "poison_spread_on_push_collision." },
  { cls: "Shaman", skill: "Bone Spear", bible: "SKEWER 4 MAG ATK 2; barricade furthest empty 50% HP. [+] Lightning Rod", verdict: "MATCH", delta: "LINE 4 MAG ATK 2. Barricade on furthest empty. Lightning Rod upgrade." },
  { cls: "Shaman", skill: "Ancestral Spirit", bible: "RANGE 1 ally corpse; ghost 25% HP echoes next cast. [+] upgraded echoes", verdict: "MATCH", delta: "Corpse gate in can_use + SPAWN. echo_upgraded sets shaman_echo_upgraded." },
  { cls: "Shaman", skill: "Totem Guard", bible: "RANGE 2 adj allies ranged −2. [+] +1 DEF vs melee", verdict: "MATCH", delta: "Ranged −2 MATCH. [+] melee_def → shaman_guard_melee_def; CombatSystem mitigation via guard_melee_defense_bonus." },
  { cls: "Shaman", skill: "Sympathetic Bond", bible: "RANGE 3 link ally AND enemy; heal → WPN. [+] enemy dmg → HEAL 1", verdict: "MATCH", delta: "Ally then enemy NEW_AIM. Incomplete pair fails. No auto-nearest." },
  { cls: "Shaman", skill: "Earthbind Totem", bible: "AOE 2 pulse ROOT. [+] WEAKEN", verdict: "MATCH", delta: "AOE 2 = cross." },
  { cls: "Shaman", skill: "Soul Siphon", bible: "RANGE 3 MAG ATK 1 +1 per debuff. [+] HEAL 1 per", verdict: "MATCH", delta: "bonus_damage_per_debuff." },
  { cls: "Shaman", skill: "Pain Spike", bible: "RANGE 3 ATK 2; if linked ATK 1 to linked. [+] BLIND", verdict: "MATCH", delta: "shaman_systems.gd:543." },

  { cls: "Lancer", skill: "Stats", bible: "CON 5 MOV 4 STR 4 DEF 3 MAG 1", verdict: "MATCH", delta: "Factory matches." },
  { cls: "Lancer", skill: "Promotion boosts", bible: "Cavalier / Skystriker / Halberdier", verdict: "MATCH", delta: "promotion_stat_bonuses now authored." },
  { cls: "Lancer", skill: "Polearm Mastery", bible: "Basic RANGE 2; RANGE 1 −30%. [+] RANGE 2 +1 STR ignore 2 DEF", verdict: "MATCH", delta: "Ignore 2 DEF is upgrade-only. Base RANGE 2 / RANGE 1 −30%." },
  { cls: "Lancer", skill: "Push", bible: "1 MOV adjacent ally PUSH 1. [+] 1/turn +1 STR next", verdict: "MATCH", delta: "Reposition costs 1 MOV. Ally-only." },
  { cls: "Lancer", skill: "Kinetic Charge", bible: "+1 STR per straight tile before attack", verdict: "MATCH", delta: "ability_system.gd:3051." },
  { cls: "Lancer", skill: "Unstoppable Mass", bible: "Max MOV then attack → PIERCE + ROOT immune", verdict: "MATCH", delta: "Id-keyed." },
  { cls: "Lancer", skill: "Canto", bible: "Standard move CANTO", verdict: "MATCH", delta: "movement_system.gd:891." },
  { cls: "Lancer", skill: "Frontline Defense", bible: "Moved 3+ +1 DEF ranged immune. [+] SHIELD 1", verdict: "MATCH", delta: "combat_system + movement_system." },
  { cls: "Lancer", skill: "Flanking Strike", bible: "Side ignore 2 DEF. [+] 4", verdict: "MATCH", delta: "ability_system.gd:3292." },
  { cls: "Lancer", skill: "Plunging Attack", bible: "AP jump/teleport → next basic ATK+3. [+] PIERCE", verdict: "MATCH", delta: "ability_system.gd:3140." },
  { cls: "Lancer", skill: "Crashing Impact", bible: "Land PUSH 1 adj. [+] collision STAGGER", verdict: "MATCH", delta: "ability_system.gd:4424." },
  { cls: "Lancer", skill: "Pole-Plant", bible: "0-AP Push traps/obstacles; destroy → SHIELD 2. [+] 2 dmg", verdict: "MATCH", delta: "Destroy grants SHIELD 2. Upgrade is WPN unmitigated on adjacent." },
  { cls: "Lancer", skill: "Spear Drop", bible: "Vaulted ignore 2 DEF + BLEED WPN. [+] ignore 4", verdict: "MATCH", delta: "ability_system.gd:3275." },
  { cls: "Lancer", skill: "Springboard", bible: "On Kill vault into corpse 0 AP before removal. [+] +1 AP", verdict: "MATCH", delta: "0 AP vault. +1 AP is upgrade-only. No invented +1 MOV." },
  { cls: "Lancer", skill: "Pivot Leverage", bible: "RANGE 2 PUSH 1 −2 MOV; wall STAGGER. [+] ignore 4 DEF", verdict: "MATCH", delta: "Wall collision STAGGER via shared push path." },
  { cls: "Lancer", skill: "Reach Advantage", bible: "RANGE 2 vs melee no Retaliation. [+] lose DEF=WPN", verdict: "MATCH", delta: "upgraded_range_two_def_debuff_weapon applies STAT_DEBUFF_DEF = WPN." },
  { cls: "Lancer", skill: "Disengage", bible: "RANGE 1 PUSH 1 self. [+] also PUSH 1 enemy", verdict: "MATCH", delta: "ability_system.gd:5152." },
  { cls: "Lancer", skill: "Zone of Control", bible: "Enemy ends exactly 2 away → basic in Action Phase. [+] PIERCE", verdict: "MATCH", delta: "Reaction is the Action-Phase basic when they end 2 away." },
  { cls: "Lancer", skill: "Leverage", bible: "0-AP Push → next PIERCE +1 MOV. [+] SHIELD 1", verdict: "MATCH", delta: "physics_system.gd:481." },
  { cls: "Lancer", skill: "Piercing Charge", bible: "DASH 3 ATK 2 RANGE 2 PUSH 2. [+] TRAMPLED", verdict: "MATCH", delta: "Dash then RANGE 2 strike from landing. No invented Push-used bonus." },
  { cls: "Lancer", skill: "Sweeping Halberd", bible: "RANGE 2 ARC ATK 2 PULL 1. [+] PULL collision STAGGER", verdict: "MATCH", delta: "STAGGER on PULL collision is upgrade-only. No invented Push-used PULL." },
  { cls: "Lancer", skill: "Vaulting Leap", bible: "RANGE 2 ATK 2; target DEF halved 1 turn (round up). [+] adj ATK 1", verdict: "MATCH", delta: "halve_target_def_one_turn. Upgrade armor_explosion_atk 1." },
  { cls: "Lancer", skill: "Impale", bible: "RANGE 2 ATK 3; +2 vs FEAR/lower MOV. [+] On Kill +2 Max MOV", verdict: "MATCH", delta: "ability_system.gd:3153. Display is Bible Impale; factory id stays lancer_run_down." },
  { cls: "Lancer", skill: "Rallying Cry", bible: "RANGE 0 AOE 2 +1 Max MOV next turn. [+] TRAMPLE", verdict: "MATCH", delta: "AOE 2 = cross. Factory is CROSS." },
  { cls: "Lancer", skill: "Wraparound", bible: "L-shape MOVE; side 2× dmg. [+] GHOST", verdict: "MATCH", delta: "l_shape_move + multiplier 2. Display is Bible Wraparound; factory id stays lancer_flanking_maneuver." },
  { cls: "Lancer", skill: "Brace", bible: "SELF MOV=0; negate next melee ATK 2. [+] STAGGER", verdict: "MATCH", delta: "BRACED 1 turn; next melee negated, attacker ATK 2. [+] STAGGER." },
  { cls: "Lancer", skill: "Harpoon Toss", bible: "RANGE 4 ATK 1 PULL adjacent. [+] if ROOTED PULL SELF", verdict: "MATCH", delta: "PULL until adjacent. Self-pull is upgrade + ROOTED only." },
  { cls: "Lancer", skill: "Glorious Charge", bible: "RANGE 4 pick ally; both MOVE to enemy combined attack. [+] both +1 AP", verdict: "MATCH", delta: "Ally-first then enemy. Both move to empty adjacent and each ATK 2." },
  { cls: "Lancer", skill: "Pole Vault", bible: "RANGE 3 jump over. [+] landing PUSH 1", verdict: "MATCH", delta: "Upgrade landing PUSH 1 is not Push-used gated. Obstacle/gap only." },
  { cls: "Lancer", skill: "Line Breaker", bible: "DASH 4 pass through ATK 2 each. [+] +1 per passed", verdict: "MATCH", delta: "physics_system.gd:262." },
  { cls: "Lancer", skill: "Spear Wall", bible: "RANGE 2 ARC hazard line; cross ATK 2 ROOT. [+] 2 turns", verdict: "MATCH", delta: "ARC is the glossary 3-tile perpendicular line. Duration MATCH." },
  { cls: "Lancer", skill: "Meteor Drop (Lancer)", bible: "RANGE 2 jump; ATK 2 adj. [+] VULNERABLE", verdict: "MATCH", delta: "AOE_CROSS 1 + VULNERABLE ON_LAND." },

  { cls: "Engineer", skill: "Stats / promotions / construct HP", bible: "CON 4 MOV 4 STR 3 DEF 3 MAG 1; turret 50% mini 25% tesla 150% mine 25%", verdict: "MATCH", delta: "HP percents match via unit defs." },
  { cls: "Engineer", skill: "Blueprint Tread", bible: "Ghost through friendly constructs; end adj repair 1. [+] both SHIELD 1", verdict: "MATCH", delta: "engineer_systems.gd:245." },
  { cls: "Engineer", skill: "Recall", bible: "3 MOV teleport empty adj construct. [+] Overclock", verdict: "MATCH", delta: "Range 99 bubble looks GLOBAL." },
  { cls: "Engineer", skill: "Turret Syndrome", bible: "No-move mini-turret 25% HP. [+] turret +50% HP", verdict: "MATCH", delta: "Spawn 25% caster HP; upgrade multiplies that turret HP by 1.5." },
  { cls: "Engineer", skill: "Automation", bible: "Turrets ATK+1 RANGE+1. [+] ATK+2", verdict: "MATCH", delta: "engineer_systems.gd:674." },
  { cls: "Engineer", skill: "Master Builder", bible: "+1 construct limit. [+] +2", verdict: "MATCH", delta: "engineer_systems.gd:950." },
  { cls: "Engineer", skill: "Reinforced Constructs", bible: "+25% HP inherit 50% DEF. [+] +50% / 100%", verdict: "MATCH", delta: "engineer_systems.gd:574." },
  { cls: "Engineer", skill: "Shield Generator", bible: "Allies adj turrets +1 DEF. [+] PULL immune", verdict: "MATCH", delta: "combat_system.gd:199." },
  { cls: "Engineer", skill: "Blast Shielding", bible: "Immune own explosions. [+] 3+ enemies +1 AP", verdict: "MATCH", delta: "combat_system.gd:526." },
  { cls: "Engineer", skill: "Explosive Expert", bible: "+1 vs mechanicals ignore DEF. [+] explosions ATK+2", verdict: "MATCH", delta: "engineer_systems.gd:204." },
  { cls: "Engineer", skill: "Chain Reaction (Engineer)", bible: "Detonation → Manual Det RANGE 2. [+] RANGE 3", verdict: "MATCH", delta: "engineer_systems.gd:903." },
  { cls: "Engineer", skill: "Shrapnel", bible: "Detonations BLEED WPN PUSH 1. [+] BLIND", verdict: "MATCH", delta: "engineer_systems.gd:886." },
  { cls: "Engineer", skill: "Expanded Blast", bible: "Explosion AOE +1. [+] destroy traps", verdict: "MATCH", delta: "Cross size 1+bonus. Upgrade destroys traps/cover." },
  { cls: "Engineer", skill: "Scrap Mechanic", bible: "Death RANGE 3 Scrap upgrades construct HP. [+] 2 Scrap", verdict: "MATCH", delta: "Scrap drop also raises owned construct max/current HP." },
  { cls: "Engineer", skill: "Recycling Protocol", bible: "Friendly construct death 2 Scrap +1 AP 1/turn. [+] 3 Scrap", verdict: "MATCH", delta: "engineer_systems.gd:418." },
  { cls: "Engineer", skill: "Overclock", bible: "Act twice, 1 dmg/turn. [+] 0 dmg", verdict: "MATCH", delta: "engineer_systems.gd:665." },
  { cls: "Engineer", skill: "Overclocked Maintenance", bible: "Spend 1+ MOV adj HEAL 1 CLEANSE SHIELD 1. [+] HEAL 2", verdict: "MATCH", delta: "Requires MOV spent this turn + adjacent. SHIELD 1 both." },
  { cls: "Engineer", skill: "Field Technician", bible: "Repair RANGE 2; +1 STR next attack. [+] +2 STR", verdict: "MATCH", delta: "Extends Blueprint Tread range. next_attack_strength_bonus." },
  { cls: "Engineer", skill: "Dismantle", bible: "RANGE 1 ATK 3 −25% DEF. [+] 1 Scrap", verdict: "MATCH", delta: "target_def_pct_loss 0.25." },
  { cls: "Engineer", skill: "Sludge Bomb", bible: "RANGE 3 AOE 3x3 ATK 1 OIL. [+] ignite OIL", verdict: "MATCH", delta: "Square size 1 = 3x3." },
  { cls: "Engineer", skill: "Construct Turret", bible: "RANGE 2 turret ATK 1 50% HP. [+] death ATK 2 adj", verdict: "MATCH", delta: "HP 50% + death splash." },
  { cls: "Engineer", skill: "Frag Bomb", bible: "RANGE 3 AOE 3x3 ATK 2 ignite OIL. [+] refund AP", verdict: "MATCH", delta: "Square size 1 = 3x3." },
  { cls: "Engineer", skill: "Magnetic Mine", bible: "RANGE 3 PULL 2 then ATK 2 25% HP. [+] absorb scrap", verdict: "MATCH", delta: "Factory mine_pull 2 / mine_damage 2. HP Floor(25% Max HP)." },
  { cls: "Engineer", skill: "Tesla Barricade", bible: "RANGE 1 wall 150% HP. [+] Manual Det STAGGER", verdict: "MATCH", delta: "manual_detonation_stagger copied onto the construct and applied on detonate." },
  { cls: "Engineer", skill: "Flak Cannon", bible: "RANGE 1 ARC ATK 2 PUSH 1. [+] 1 Scrap ATK+2 BLEED", verdict: "MATCH", delta: "engineer_systems.gd:197." },
  { cls: "Engineer", skill: "Wrench Smack", bible: "RANGE 1 ATK 2; construct HEAL 2 CLEANSE OVERCLOCK. [+] +1 STR", verdict: "MATCH", delta: "Upgrade grants next_attack_strength_bonus on the Engineer." },
  { cls: "Engineer", skill: "EMP Grenade", bible: "RANGE 4 AOE 2 PURGE SILENCE destroy constructs. [+] friendlies HEAL 2 OVERCLOCK", verdict: "MATCH", delta: "AOE_CROSS 2. Friendly HEAL 2 + OVERCLOCK." },
  { cls: "Engineer", skill: "Rocket Launcher", bible: "GLOBAL delayed 3x3 ATK 4; destroy cover; exhaust next turn. [+] sacrifice to fire now", verdict: "MATCH", delta: "delayed_next_turn + exhaust. Sacrifice flushes delay." },
  { cls: "Engineer", skill: "Scrap Shield", bible: "RANGE 2 Scrap → SHIELD 2×Scrap. [+] depletion explode", verdict: "MATCH", delta: "engineer_systems.gd:707." },
  { cls: "Engineer", skill: "Manual Detonation", bible: "RANGE 3 0 AP ATK 2 adjacent. [+] 1 Scrap", verdict: "MATCH", delta: "Cross size 1 (adjacent). Same blast path as Expanded Blast." },
  { cls: "Engineer", skill: "Overdrive Injection", bible: "Construct +2 STR OVERCLOCK; construct takes 2 true. [+] scrap on death", verdict: "MATCH", delta: "Unmitigated 2 on the construct. Upgrade sets overdrive_scrap_on_death." },
  { cls: "Engineer", skill: "Barbed Wire", bible: "RANGE 3 ARC wall BLEED ROOT. [+] +1 DEF adj", verdict: "MATCH", delta: "adjacent_defense_bonus on terrain payload adds DEF in CombatSystem." },
];

function tone(v: Verdict): "success" | "warning" | "danger" | "neutral" {
  if (v === "MATCH") return "success";
  if (v === "DATA-ONLY") return "warning";
  return "danger";
}

const CLASSES = [
  "All",
  "Knight",
  "Bruiser",
  "Mercenary",
  "Rogue",
  "Monk",
  "Beast Rider",
  "Mage",
  "Archer",
  "Cleric",
  "Shaman",
  "Lancer",
  "Engineer",
];

export default function BibleSkillAlignmentAudit() {
  const [cls, setCls] = useCanvasState("classFilter", "All");
  const [failsOnly, setFailsOnly] = useCanvasState("failsOnly", true);

  const visible = R.filter((r) => {
    if (cls !== "All" && r.cls !== cls) return false;
    if (failsOnly && r.verdict === "MATCH") return false;
    return true;
  });

  const fail = R.filter((r) => r.verdict !== "MATCH").length;
  const match = R.filter((r) => r.verdict === "MATCH").length;

  const classCounts = CLASSES.slice(1).map((name) => {
    const rows = R.filter((r) => r.cls === name);
    const bad = rows.filter((r) => r.verdict !== "MATCH").length;
    return { name, n: rows.length, bad, ok: rows.length - bad };
  });

  return (
    <Stack gap={20} style={{ padding: 24, maxWidth: 1500 }}>
      <Stack gap={8}>
        <H1>Every Bible skill vs code</H1>
        <Text tone="secondary">
          Source of truth is class_abilities.txt after the Aug 14 rewrite.
          All 397 rows are MATCH. Hide MATCH to confirm nothing is left.
          A few MATCH rows keep owner-approved notes (Bowling Charge,
          Trampling Advance) — those are closed, not leftover work.
        </Text>
      </Stack>

      <Callout tone="success" title="Bible-to-code canvas is 100% MATCH">
        Named skills in global rules are upgraded illustrations, not base
        definitions. Bowling Charge and Trampling Advance stay MATCH. ROOT
        from a damaging pin is not a bug. Fortify adds the Knight DEF (it
        does not overwrite the ally). AOE 1 is a cross. Square AOE size N
        is Chebyshev radius.
      </Callout>

      <Callout tone="neutral" title="Green class QA is not owner LOCK">
        Alignment enums are complete. Knight remains the only class with
        owner QA PASS in CLASS_QA_SIGNOFF.md. Automated class gates are
        separate from this canvas.
      </Callout>

      <Grid columns={3} gap={16}>
        <Stat value={String(R.length)} label="Bible rows" />
        <Stat value={String(fail)} label="Not 100%" tone="danger" />
        <Stat value={String(match)} label="MATCH" tone="success" />
      </Grid>

      <H2>Per class</H2>
      <Table
        headers={["Class", "Rows", "Not 100%", "MATCH"]}
        rows={classCounts.map((c) => [c.name, String(c.n), String(c.bad), String(c.ok)])}
        rowTone={classCounts.map((c) => (c.bad > 0 ? "danger" : "success"))}
        columnAlign={["left", "right", "right", "right"]}
        striped
      />

      <Divider />

      <Row gap={16} align="center" justify="space-between" wrap>
        <H2>Skill rows</H2>
        <Row gap={12} align="center" wrap>
          <Select
            value={cls}
            onChange={setCls}
            options={CLASSES.map((name) => ({ value: name, label: name }))}
          />
          <Checkbox checked={failsOnly} onChange={setFailsOnly} label="Hide MATCH" />
        </Row>
      </Row>
      <Text size="small" tone="secondary">
        Showing {visible.length} of {R.length}.
      </Text>

      <Table
        headers={["Class", "Skill", "Bible", "Verdict", "What is wrong"]}
        rows={visible.map((r) => [r.cls, r.skill, r.bible, r.verdict, r.delta])}
        rowTone={visible.map((r) => tone(r.verdict))}
        columnAlign={["left", "left", "left", "center", "left"]}
        striped
        stickyHeader
      />
    </Stack>
  );
}
