class_name Monsters
## Monster definitions for Standard Mode — 10 types + 1 boss

# Floor ranges: which floors each monster can appear on
# HP scales with floor: base_hp + (floor - 1) * hp_per_floor

static func get_all() -> Dictionary:
  return {
    # ── Floor 1-3 (Easy) ──
    "mushroom": {
      "name": "蘑菇怪", "name_en": "Mushroom",
      "base_hp": 28, "hp_per_floor": 4, "floors": [1, 3],
      "sprite": "res://assets/img/monsters/mushroom_idle.png",
      "attack_sprite": "res://assets/img/monsters/mushroom_attack.png",
      "hit_sprite": "res://assets/img/monsters/mushroom_hit.png",
      "death_sprite": "res://assets/img/monsters/mushroom_death.png",
      "fallen_sprite": "res://assets/img/monsters/mushroom_fallen.png",
      "scale_h": 300.0,
    },
    "ghost_rat": {
      "name": "幽灵鼠", "name_en": "Ghost Rat",
      "base_hp": 24, "hp_per_floor": 3, "floors": [1, 3],
      "sprite": "res://assets/img/monsters/ghost_rat_idle.png",
      "attack_sprite": "res://assets/img/monsters/ghost_rat_attack.png",
      "hit_sprite": "res://assets/img/monsters/ghost_rat_hit.png",
      "death_sprite": "res://assets/img/monsters/ghost_rat_death.png",
      "fallen_sprite": "res://assets/img/monsters/ghost_rat_fallen.png",
      "scale_h": 260.0,
    },
    # ── Floor 2-5 (Medium-Easy) ──
    "skeleton": {
      "name": "骷髅兵", "name_en": "Skeleton",
      "base_hp": 32, "hp_per_floor": 5, "floors": [2, 5],
      "sprite": "res://assets/img/monsters/skeleton_idle.png",
      "attack_sprite": "res://assets/img/monsters/skeleton_attack.png",
      "hit_sprite": "res://assets/img/monsters/skeleton_hit.png",
      "death_sprite": "res://assets/img/monsters/skeleton_death.png",
      "fallen_sprite": "res://assets/img/monsters/skeleton_fallen.png",
      "scale_h": 340.0,
    },
    "poison_spider": {
      "name": "毒蛛", "name_en": "Poison Spider",
      "base_hp": 30, "hp_per_floor": 4, "floors": [2, 5],
      "sprite": "res://assets/img/monsters/poison_spider_idle.png",
      "attack_sprite": "res://assets/img/monsters/poison_spider_attack.png",
      "hit_sprite": "res://assets/img/monsters/poison_spider_hit.png",
      "death_sprite": "res://assets/img/monsters/poison_spider_death.png",
      "fallen_sprite": "res://assets/img/monsters/poison_spider_fallen.png",
      "scale_h": 280.0,
    },
    # ── Floor 3-6 (Medium) ──
    "shadow_rogue": {
      "name": "暗影刺客", "name_en": "Shadow Rogue",
      "base_hp": 38, "hp_per_floor": 6, "floors": [3, 6],
      "sprite": "res://assets/img/monsters/shadow_rogue_idle.png",
      "attack_sprite": "res://assets/img/monsters/shadow_rogue_attack.png",
      "hit_sprite": "res://assets/img/monsters/shadow_rogue_hit.png",
      "death_sprite": "res://assets/img/monsters/shadow_rogue_death.png",
      "fallen_sprite": "res://assets/img/monsters/shadow_rogue_fallen.png",
      "scale_h": 360.0,
    },
    "gargoyle": {
      "name": "石像鬼", "name_en": "Gargoyle",
      "base_hp": 44, "hp_per_floor": 6, "floors": [3, 6],
      "sprite": "res://assets/img/monsters/gargoyle_idle.png",
      "attack_sprite": "res://assets/img/monsters/gargoyle_attack.png",
      "hit_sprite": "res://assets/img/monsters/gargoyle_hit.png",
      "death_sprite": "res://assets/img/monsters/gargoyle_death.png",
      "fallen_sprite": "res://assets/img/monsters/gargoyle_fallen.png",
      "scale_h": 340.0,
    },
    # ── Floor 5-8 (Hard) ──
    "fire_mage": {
      "name": "火焰法师", "name_en": "Fire Mage",
      "base_hp": 48, "hp_per_floor": 7, "floors": [5, 8],
      "sprite": "res://assets/img/monsters/fire_mage_idle.png",
      "attack_sprite": "res://assets/img/monsters/fire_mage_attack.png",
      "hit_sprite": "res://assets/img/monsters/fire_mage_hit.png",
      "death_sprite": "res://assets/img/monsters/fire_mage_death.png",
      "fallen_sprite": "res://assets/img/monsters/fire_mage_fallen.png",
      "scale_h": 360.0,
    },
    "frost_giant": {
      "name": "冰霜巨人", "name_en": "Frost Giant",
      "base_hp": 56, "hp_per_floor": 8, "floors": [5, 8],
      "sprite": "res://assets/img/monsters/frost_giant_idle.png",
      "attack_sprite": "res://assets/img/monsters/frost_giant_attack.png",
      "hit_sprite": "res://assets/img/monsters/frost_giant_hit.png",
      "death_sprite": "res://assets/img/monsters/frost_giant_death.png",
      "fallen_sprite": "res://assets/img/monsters/frost_giant_fallen.png",
      "scale_h": 400.0,
    },
    # ── Floor 7-9 (Very Hard) ──
    "death_knight": {
      "name": "死灵骑士", "name_en": "Death Knight",
      "base_hp": 64, "hp_per_floor": 9, "floors": [7, 9],
      "sprite": "res://assets/img/monsters/death_knight_idle.png",
      "attack_sprite": "res://assets/img/monsters/death_knight_attack.png",
      "hit_sprite": "res://assets/img/monsters/death_knight_hit.png",
      "death_sprite": "res://assets/img/monsters/death_knight_death.png",
      "fallen_sprite": "res://assets/img/monsters/death_knight_fallen.png",
      "scale_h": 380.0,
    },
    # ── Floor 10 (Boss) ──
    "ancient_dragon": {
      "name": "远古巨龙", "name_en": "Ancient Dragon",
      "base_hp": 200, "hp_per_floor": 0, "floors": [10, 10],
      "sprite": "res://assets/img/monsters/ancient_dragon_idle.png",
      "attack_sprite": "res://assets/img/monsters/ancient_dragon_attack.png",
      "hit_sprite": "res://assets/img/monsters/ancient_dragon_hit.png",
      "death_sprite": "res://assets/img/monsters/ancient_dragon_death.png",
      "fallen_sprite": "res://assets/img/monsters/ancient_dragon_fallen.png",
      "scale_h": 450.0,
      "is_boss": true,
    },
  }

static func get_hp(monster_id: String, floor_num: int) -> int:
  var m: Dictionary = get_all()[monster_id]
  return m["base_hp"] + (floor_num - 1) * m["hp_per_floor"]

static func get_monsters_for_floor(floor_num: int) -> Array:
  ## Returns array of monster IDs valid for this floor
  var result: Array = []
  for mid in get_all():
    var m: Dictionary = get_all()[mid]
    if floor_num >= m["floors"][0] and floor_num <= m["floors"][1]:
      result.append(mid)
  return result

static func get_enemy_count_for_floor(floor_num: int) -> int:
  ## Returns number of enemies (1-2). Multi-monster = ~20-40% of battles.
  if floor_num <= 2:
    return 1
  elif floor_num <= 4:
    return 2 if randi() % 5 == 0 else 1  # 20%
  elif floor_num <= 6:
    return [1, 1, 2][randi() % 3]  # 33%
  elif floor_num <= 8:
    return [1, 2][randi() % 2]  # 50%
  elif floor_num == 10:
    return 1  # Boss is always solo
  return [1, 2, 2][randi() % 3]  # Floor 9: 66%
