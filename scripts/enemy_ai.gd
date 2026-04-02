extends RefCounted
## res://scripts/enemy_ai.gd — Enemy AI patterns for all enemy types

var enemy_type: String = ""
var turn_count: int = 0
var mode: int = 0  # For mode shifts

func _init(type: String = "") -> void:
  enemy_type = type

func get_next_action(entity: Node2D) -> Dictionary:
  turn_count += 1
  match enemy_type:
    # ── Original 4 ──
    "slime": return _slime_action(entity)
    "cultist": return _cultist_action(entity)
    "jaw_worm": return _jaw_worm_action(entity)
    "guardian": return _guardian_action(entity)
    # ── Standard Mode 10 ──
    "mushroom": return _mushroom_action(entity)
    "ghost_rat": return _ghost_rat_action(entity)
    "skeleton": return _skeleton_action(entity)
    "poison_spider": return _poison_spider_action(entity)
    "shadow_rogue": return _shadow_rogue_action(entity)
    "gargoyle": return _gargoyle_action(entity)
    "fire_mage": return _fire_mage_action(entity)
    "frost_giant": return _frost_giant_action(entity)
    "death_knight": return _death_knight_action(entity)
    "ancient_dragon": return _ancient_dragon_action(entity)
  return {"type": "attack", "value": 5, "intent": "attack"}

# ── Original enemies ──

func _slime_action(_entity: Node2D) -> Dictionary:
  if turn_count % 2 == 1:
    return {"type": "attack", "value": 4, "times": 2, "intent": "attack", "desc": "攻击 2x4"}
  else:
    return {"type": "attack", "value": 8, "times": 1, "intent": "attack", "desc": "攻击 8"}

func _cultist_action(_entity: Node2D) -> Dictionary:
  if turn_count == 1:
    return {"type": "buff", "status": "strength", "value": 3, "intent": "buff", "desc": "获得3力量"}
  else:
    return {"type": "attack", "value": 6, "times": 1, "intent": "attack", "desc": "攻击 6"}

func _jaw_worm_action(_entity: Node2D) -> Dictionary:
  if turn_count % 3 == 1:
    return {"type": "attack", "value": 11, "times": 1, "intent": "attack", "desc": "攻击 11"}
  elif turn_count % 3 == 2:
    return {"type": "block", "value": 6, "intent": "defend", "desc": "获得6格挡"}
  else:
    return {"type": "attack_block", "damage": 7, "block_val": 5, "intent": "attack", "desc": "攻击7 格挡5"}

func _guardian_action(_entity: Node2D) -> Dictionary:
  if mode == 0:
    if turn_count % 3 == 0:
      mode = 1
      return {"type": "mode_shift", "block_val": 9, "intent": "defend", "desc": "防御模式 格挡9"}
    else:
      return {"type": "attack", "value": 10, "times": 1, "intent": "attack", "desc": "攻击 10"}
  else:
    mode = 0
    return {"type": "attack_debuff", "value": 8, "status": "vulnerable", "stacks": 1, "intent": "debuff", "desc": "攻击8 易伤1"}

# ── Standard Mode monsters ──

func _mushroom_action(_entity: Node2D) -> Dictionary:
  ## Mushroom: alternates between spore cloud (vulnerable) and attack
  if turn_count % 3 == 1:
    return {"type": "debuff_only", "status": "vulnerable", "stacks": 2, "intent": "debuff", "desc": "释放孢子 易伤2"}
  else:
    return {"type": "attack", "value": 7, "times": 1, "intent": "attack", "desc": "攻击 7"}

func _ghost_rat_action(_entity: Node2D) -> Dictionary:
  ## Ghost Rat: fast multi-hit, sometimes dodges
  if turn_count % 3 == 0:
    return {"type": "block", "value": 8, "intent": "defend", "desc": "闪避 格挡8"}
  else:
    return {"type": "attack", "value": 3, "times": 3, "intent": "attack", "desc": "攻击 3x3"}

func _skeleton_action(_entity: Node2D) -> Dictionary:
  ## Skeleton: straightforward attacker, occasional block
  match turn_count % 4:
    1: return {"type": "attack", "value": 9, "times": 1, "intent": "attack", "desc": "攻击 9"}
    2: return {"type": "attack", "value": 6, "times": 2, "intent": "attack", "desc": "攻击 6x2"}
    3: return {"type": "attack_block", "damage": 5, "block_val": 5, "intent": "attack", "desc": "攻击5 格挡5"}
    _: return {"type": "attack", "value": 12, "times": 1, "intent": "attack", "desc": "重击 12"}

func _poison_spider_action(_entity: Node2D) -> Dictionary:
  ## Poison Spider: applies poison and attacks
  if turn_count % 2 == 1:
    return {"type": "attack_debuff", "value": 5, "status": "poison", "stacks": 4, "intent": "debuff", "desc": "毒咬 5伤 中毒4"}
  else:
    return {"type": "attack", "value": 8, "times": 1, "intent": "attack", "desc": "攻击 8"}

func _shadow_rogue_action(_entity: Node2D) -> Dictionary:
  ## Shadow Rogue: high burst damage, sometimes buffs
  match turn_count % 3:
    1: return {"type": "buff", "status": "strength", "value": 2, "intent": "buff", "desc": "磨刀 力量+2"}
    2: return {"type": "attack", "value": 14, "times": 1, "intent": "attack", "desc": "暗杀 14"}
    _: return {"type": "attack", "value": 5, "times": 3, "intent": "attack", "desc": "连刺 5x3"}

func _gargoyle_action(_entity: Node2D) -> Dictionary:
  ## Gargoyle: high block, counter-attacks
  if turn_count % 2 == 1:
    return {"type": "block", "value": 14, "intent": "defend", "desc": "石化防御 格挡14"}
  else:
    return {"type": "attack", "value": 12, "times": 1, "intent": "attack", "desc": "石爪 12"}

func _fire_mage_action(_entity: Node2D) -> Dictionary:
  ## Fire Mage: AOE attacks, buffs self
  match turn_count % 4:
    1: return {"type": "buff", "status": "strength", "value": 3, "intent": "buff", "desc": "聚火 力量+3"}
    2: return {"type": "attack", "value": 10, "times": 1, "intent": "attack", "desc": "火球 10"}
    3: return {"type": "attack", "value": 6, "times": 2, "intent": "attack", "desc": "火雨 6x2"}
    _: return {"type": "attack_debuff", "value": 8, "status": "weak", "stacks": 2, "intent": "debuff", "desc": "灼烧 8伤 虚弱2"}

func _frost_giant_action(_entity: Node2D) -> Dictionary:
  ## Frost Giant: heavy hits, applies weak
  match turn_count % 3:
    1: return {"type": "attack", "value": 16, "times": 1, "intent": "attack", "desc": "冰锤 16"}
    2: return {"type": "attack_debuff", "value": 10, "status": "weak", "stacks": 2, "intent": "debuff", "desc": "寒气 10伤 虚弱2"}
    _: return {"type": "attack_block", "damage": 8, "block_val": 10, "intent": "attack", "desc": "攻击8 格挡10"}

func _death_knight_action(_entity: Node2D) -> Dictionary:
  ## Death Knight: strength ramp + life steal attacks
  match turn_count % 4:
    1: return {"type": "buff", "status": "strength", "value": 4, "intent": "buff", "desc": "暗黑祝福 力量+4"}
    2: return {"type": "attack", "value": 15, "times": 1, "intent": "attack", "desc": "死亡斩 15"}
    3: return {"type": "attack_block", "damage": 10, "block_val": 8, "intent": "attack", "desc": "攻击10 格挡8"}
    _: return {"type": "attack", "value": 8, "times": 2, "intent": "attack", "desc": "双斩 8x2"}

func _ancient_dragon_action(_entity: Node2D) -> Dictionary:
  ## Ancient Dragon (Boss): multi-phase, very dangerous
  match turn_count % 5:
    1: return {"type": "buff", "status": "strength", "value": 5, "intent": "buff", "desc": "龙威 力量+5"}
    2: return {"type": "attack", "value": 20, "times": 1, "intent": "attack", "desc": "龙爪 20"}
    3: return {"type": "attack", "value": 8, "times": 3, "intent": "attack", "desc": "龙息 8x3"}
    4: return {"type": "attack_debuff", "value": 15, "status": "vulnerable", "stacks": 2, "intent": "debuff", "desc": "尾扫 15伤 易伤2"}
    _: return {"type": "attack_block", "damage": 12, "block_val": 15, "intent": "attack", "desc": "攻击12 格挡15"}

func get_intent_icon(intent: String) -> String:
  match intent:
    "attack": return "res://assets/img/ui_icons/attack_intent.png"
    "defend": return "res://assets/img/ui_icons/defend_intent.png"
    "buff": return "res://assets/img/ui_icons/buff_intent.png"
    "debuff": return "res://assets/img/ui_icons/debuff_intent.png"
  return "res://assets/img/ui_icons/attack_intent.png"
