require 'yaml'
require 'levenshtein'
require 'curses'

# Load the YAML library to handle configuration files.
# YAML is used to store game settings in an external file.

# Define a module to handle saving and loading game data.
# This module uses YAML to serialize and deserialize game state

# Define a module for the save system.
module SaveSystem
  FILE_NAME = "savegame.yml"

  def self.save(player, current_room_key)
    data = {
      player: player.to_hash_player,
      current_room: current_room_key
    }
    File.write(FILE_NAME, YAML.dump(data))
    true
  end

  def self.load(rooms)
    return nil unless File.exist?(FILE_NAME)
    data = YAML.load_file(FILE_NAME)

    player = Player.from_hash_player(data[:player])
    current_room = rooms[data[:current_room].to_sym]

    { player: player, current_room: current_room }
  end

  def self.exists?
    File.exist?(FILE_NAME)
  end
end


# Define a class to manage game configuration using a dynamic approach.
class GameConfig
  def initialize
    @settings = {}
  end

  # Use Ruby's `method_missing` to dynamically handle undefined methods.
  def method_missing(name, *args)
    if name.to_s.end_with?('=')
      @settings[name.to_s.chomp('=').to_sym] = args.first
    else
      @settings[name]
    end
  end

  def respond_to_missing?(name, include_private = false)
    true
  end

  def settings
    @settings
  end
end

# Dynamically resolve the path to the configuration file
config_file = File.expand_path('config.yml', __dir__)
unless File.exist?(config_file)
  puts "Error: Configuration file not found at #{config_file}"
  exit
end

# Load the YAML configuration
yaml_config = YAML.load_file(config_file)

# Populate the configuration object with values from the YAML file
$config = GameConfig.new
$config.starting_health = yaml_config['game']['starting_health']
$config.starting_gold = yaml_config['game']['starting_gold']
$config.treasure_items = yaml_config['game']['treasure_items']
$config.enemy_types = yaml_config['game']['enemy_types']
$config.ally_types = yaml_config['game']['ally_types']
$config.store_items = yaml_config['game']['store_items']
$config.puzzles = yaml_config['puzzles'] # Load puzzles into the global config

# Define a class to represent rooms in the game.
class Room
  attr_accessor :description, :directions, :unique_events, :boss, :sub_areas, :boss_sub_area

  def initialize(description, directions = {}, unique_events = [], boss = nil, sub_areas = [], boss_sub_area = nil)
    @description = description
    @directions = directions
    @unique_events = unique_events
    @boss = boss
    @sub_areas = sub_areas
    @boss_sub_area = boss_sub_area
  end

  def display
    puts "\n#{@description}"
    puts "You can go in the following directions:"
    @directions.each_key { |direction| puts "- #{direction.capitalize}" }
    puts "Sub-areas to explore:"
    @sub_areas.each { |sub_area| puts "- #{sub_area.capitalize}" }
    puts "- #{boss_sub_area.capitalize} (Boss Area)" if @boss_sub_area
  end
end

# Define a module for inventory-related utilities.
module InventoryUtils
  def self.use_item(player, item, enemy = nil)
    case item
    when "Healing Potion"
      player.health += 20
      puts "You used a Healing Potion and restored 20 health."
    when "Fresh Fish"
      player.health += 15
      puts "You ate Fresh Fish and restored 15 health."
    when "Medicinal Herbs"
      player.health += 10
      puts "You used Medicinal Herbs and restored 10 health."
    when "Golden Feather"
      player.health += 15
      puts "The Golden Feather glows, restoring 15 health."
    when "Ancient Relic"
      player.health += 20
      player.damage_bonus += 10
      puts "The Ancient Relic radiates power, permanently increasing your health by 20 and damage bonus by 10."
    when "Hunter's Supplies"
      player.damage_bonus += 5
      puts "You used Hunter's Supplies and increased your damage bonus by 5."
    when "Glowing Crystals"
      player.health += 15
      puts "You used Glowing Crystals and increased your health by 15."
    when "Echoing Gem"
      player.damage_bonus += 10
      puts "You used Echoing Gem and increased your damage bonus by 10."
    when "Magic Scroll"
      if enemy
        damage = 30
        enemy.health -= damage
        puts "You used the Magic Scroll and dealt #{damage} damage to #{enemy.type}!"
      else
        puts "There is no enemy to use the Magic Scroll on."
      end
    when "Silver Sword"
      if enemy
        damage = 20
        enemy.health -= damage
        puts "You used the Silver Sword and dealt #{damage} damage to #{enemy.type}!"
      else
        puts "There is no enemy to use the Silver Sword on."
      end
    when "Ruby Gem"
      player.gold += (player.gold * 0.2).to_i
      puts "The Ruby Gem glows, increasing your current gold earnings by 20%."
    when "Enchanted Amulet"
      player.health_bonus += 5
      puts "The Enchanted Amulet protects you, reducing damage taken by 5."
    when "Phoenix Feather"
      puts "The Phoenix Feather cannot be used manually. It will activate automatically upon defeat."
    when "Elixir of Life"
      player.health_bonus += 10
      puts "You drank the Elixir of Life, permanently increasing your health by 10."
    else
      puts "You can't use that item right now."
    end

    player.inventory.delete(item) unless item == "Phoenix Feather"
  end
end

# Define a module for general game utilities.
module GameUtils
  def self.clear_screen
    system('clear') || system('cls')
  end

  def self.pause(tui)
    tui.pause
  end
end

# Define a module for combat-related utilities.
module CombatUtils
  def self.calculate_damage(base, bonus, critical_chance = 0.15, critical_multiplier = 1.5)
    damage = rand(base..(base + bonus))
    if rand < critical_chance
      damage = (damage * critical_multiplier).to_i
      puts "Critical hit! Damage is multiplied by #{critical_multiplier}!"
    end
    damage
  end

  def self.apply_damage_reduction(damage, reduction_percentage)
    reduced_damage = (damage * (1 - reduction_percentage / 100.0)).to_i
    puts "Damage reduced by #{reduction_percentage}%! Final damage: #{reduced_damage}."
    reduced_damage
  end

  def self.apply_damage_over_time(target, damage, turns)
    if target.dot_effect
      current_damage = target.dot_effect[:damage]
      current_turns = target.dot_effect[:turns]
      if damage > current_damage || turns > current_turns
        puts "#{target.name} already has a DoT effect, but the new effect is stronger or lasts longer. Replacing the current effect."
        target.dot_effect = { damage: damage, turns: turns }
      else
        puts "#{target.name} already has a DoT effect. The new effect is weaker or shorter and will not replace the current one."
      end
    else
      puts "#{target.name} takes #{damage} damage over #{turns} turns!"
      target.dot_effect = { damage: damage, turns: turns }
    end
  end

  def self.process_damage_over_time(target)
    if target.dot_effect && target.dot_effect[:turns] > 0
      damage = target.dot_effect[:damage]
      target.health -= damage
      target.dot_effect[:turns] -= 1
      puts "#{target.name} suffers #{damage} damage from a damage-over-time effect! #{target.dot_effect[:turns]} turns remaining."
    elsif target.dot_effect && target.dot_effect[:turns] <= 0
      target.dot_effect = nil
      puts "#{target.name} is no longer affected by a damage-over-time effect."
    end
  end
end

class Player
  attr_accessor :dot_effect, :allies

  [:name, :health, :inventory, :damage_bonus, :health_bonus, :gold, :level, :experience].each do |attr|
    define_method(attr) { instance_variable_get("@#{attr}") }
    define_method("#{attr}=") { |value| instance_variable_set("@#{attr}", value) }
  end

  def to_hash_player
    {
      name: @name,
      health: @health,
      inventory: @inventory,
      damage_bonus: @damage_bonus,
      health_bonus: @health_bonus,
      gold: @gold,
      level: @level,
      experience: @experience,
      allies: @allies,
      dot_effect: @dot_effect
    }
  end
  
  def self.from_hash_player(data)
    player = Player.new(data[:name])
    player.health = data[:health]
    player.inventory = data[:inventory]
    player.damage_bonus = data[:damage_bonus]
    player.health_bonus = data[:health_bonus]
    player.gold = data[:gold]
    player.level = data[:level]
    player.experience = data[:experience]
    player.allies = data[:allies]
    player.dot_effect = data[:dot_effect]
    player
  end

  def initialize(name)
    @name = name
    @health = $config.starting_health
    @inventory = []
    @damage_bonus = 5
    @health_bonus = 0
    @gold = $config.starting_gold
    @dot_effect = nil
    @level = 1
    @experience = 0
    @allies = []
  end

  def display_status
    puts "\n#{@name}'s Status:"
    puts "Level: #{@level}"
    puts "Experience: #{@experience}/#{experience_to_level_up}"
    puts "Health: #{@health}"
    puts "Inventory: #{@inventory.join(', ')}"
    puts "Damage Bonus: #{@damage_bonus}"
    puts "Health Bonus: #{@health_bonus}"
    puts "Gold: #{@gold}"
    puts "Allies: #{@allies.join(', ')}"
  end

  def gain_experience(amount)
    @experience += amount
    puts "You gained #{amount} experience points!"
    level_up if @experience >= experience_to_level_up
  end

  def level_up
    @level += 1
    @experience = 0
    @health += 20
    @damage_bonus += 5
    puts "Congratulations! You leveled up to Level #{@level}!"
    puts "Your health increased by 20, and your damage bonus increased by 5."
  end

  def experience_to_level_up
    100 * @level
  end

  def apply_ally_bonus(ally)
    case ally
    when "a wandering knight"
      @damage_bonus += 5
      puts "The wandering knight increases your damage by 5."
    when "a wise mage"
      @health += 20
      puts "The wise mage increases your health by 20."
    when "a skilled archer"
      @damage_bonus += 10
      puts "The skilled archer increases your damage by 10."
    when "a friendly merchant"
      @gold += 50
      puts "The friendly merchant gives you 50 gold."
    when "a brave warrior"
      @damage_bonus += 15
      puts "The brave warrior increases your damage by 15."
    else
      puts "This ally doesn't provide any specific bonus."
    end
  end
end

class Enemy
  attr_accessor :type, :health, :damage, :ability, :description, :dot_effect

  def initialize(type = "Unknown", health = 10, damage = 5, ability = "None", description = "")
    @type = type
    @health = health + rand(5..15)
    @damage = damage + rand(2..5)
    @ability = ability
    @description = description
    @dot_effect = nil
  end
end

class Game
  def initialize(tui)
    @tui = tui
    @player = nil
    @current_room = nil
    @rooms = {}
  end

  # Central loss check – if health is below 0, try to use Phoenix Feather; if not, the game ends.
  def check_loss
    if @player.health < 0
      if @player.inventory.include?("Phoenix Feather")
        @player.inventory.delete("Phoenix Feather")
        @player.health = ($config.starting_health + @player.health_bonus) / 2
        puts "The Phoenix Feather activates and revives you with #{@player.health} health!"
      else
        puts "Your health has dropped below 0. You lose!"
        @tui.pause
        exit
      end
    end
  end

  def start
    @tui.draw_main([
      "📜 Welcome to the Adventure Game!",
      "1. New Game",
      "2. Load Game"
    ])
    choice = @tui.prompt("Choose 1 or 2: ")
    setup_rooms
    if choice == "2"
      if SaveSystem.exists?
        result = SaveSystem.load(@rooms)
        if result
          @player = result[:player]
          @current_room = result[:current_room]
          @tui.draw_main(["✅ Game loaded successfully!"])
          @tui.pause
        else
          @tui.draw_main(["⚠️ Failed to load game."])
          @tui.pause
          start  # Restart flow if load fails
        return
        end
      else
        @tui.draw_main(["⚠️ No saved game found. Starting a new game."])
        @tui.pause
        get_player_name

      end
    else
      get_player_name
    end
    @tui.draw_main(["Hello, #{@player.name}! Your adventure begins now."])
    @tui.pause
    explore_room
  end

  def get_player_name
    @tui.draw_main(["📜 Welcome to the Adventure Game!"])
    player_name = ""
    loop do
      player_name = @tui.prompt("Enter your name: ")
      break unless player_name.strip.empty?
      @tui.draw_main(["Name cannot be empty."])
    end
    @player = Player.new(player_name)
    @current_room = @rooms[:forest]
  end

  def setup_rooms
    @rooms[:forest] = Room.new(
      "You are in a dense forest. The trees tower above you.",
      { "north" => :cave, "east" => :river },
      [:find_herbs, :meet_hunter],
      { name: "Forest Guardian", health: 50, reward: "Enchanted Bow" },
      ["clearing", "dense thicket", "hidden grove"],
      "forest shrine"
    )
    @rooms[:cave] = Room.new(
      "You are in a dark cave. The air is damp and cold.",
      { "south" => :forest, "west" => :mountain },
      [:find_crystals, :hear_echoes],
      { name: "Cave Troll", health: 70, reward: "Crystal Shield" },
      ["crystal chamber", "echoing hall"],
      "troll's lair"
    )
    @rooms[:river] = Room.new(
      "You are by a rushing river. The water sparkles in the sunlight.",
      { "west" => :forest },
      [:catch_fish],
      { name: "River Serpent", health: 60, reward: "Repair Kit" },
      ["riverbank"],
      "serpent's den"
    )
    @rooms[:mountain] = Room.new(
      "You are on a steep mountain. The view is breathtaking.",
      { "east" => :cave, "north" => :peak },
      [:find_eagle_nest, :trigger_rockslide],
      { name: "Mountain Dragon", health: 100, reward: "Dragon Scale Armor" },
      ["mountain trail"],
      "dragon's peak"
    )
    @rooms[:village] = Room.new(
      "You are in a small village. The villagers greet you warmly.",
      { "south" => :river, "east" => :castle },
      [:visit_blacksmith, :talk_to_elder],
      { name: "Corrupted Elder", health: 80, reward: "Elder's Staff" },
      ["village square", "store"],
      "elder's sanctum"
    )
    @rooms[:castle] = Room.new(
      "You are in a grand castle. The walls are adorned with ancient tapestries.",
      { "west" => :village, "north" => :throne_room },
      [:find_treasure_chest, :meet_royal_guard],
      { name: "Dark Knight", health: 120, reward: "Shadow Blade" },
      ["castle library"],
      "knight's hall"
    )
    @rooms[:peak] = Room.new(
      "You are at the mountain's peak. The air is thin, and the view is stunning.",
      { "south" => :mountain },
      [:find_ancient_relic, :encounter_lightning_storm],
      { name: "Sky Titan", health: 150, reward: "Thunder Hammer" },
      ["peak shrine"],
      "titan's altar"
    )
    @rooms[:throne_room] = Room.new(
      "You are in the throne room. A sense of dread fills the air.",
      { "south" => :castle },
      [:find_royal_secrets, :activate_trap],
      { name: "King of Shadows", health: 200, reward: "Crown of Power" },
      ["royal chamber"],
      "shadow throne"
    )

    @current_room = @rooms[:forest]
  end

  def explore_room
    loop do
      lines = []
      lines << @current_room.description
      lines << ""
      lines << "You can go in the following directions:"
      @current_room.directions.keys.each { |d| lines << "- #{d.capitalize}" }
      lines << ""
      lines << "Sub-areas to explore:"
      @current_room.sub_areas.each { |sub| lines << "- #{sub.capitalize}" }
      lines << "- #{@current_room.boss_sub_area.capitalize} (Boss Area)" if @current_room.boss_sub_area
      lines << ""
      lines << "Options: direction / status / inventory / explore / boss / save / quit"
  
      @tui.draw_main(lines)
      @tui.draw_sidebar(@player)
      input = @tui.prompt("What would you like to do? ").downcase
      input = correct_input(input, @current_room.directions.keys + ["status", "inventory", "explore", "boss"])
  
      case input
      when "status"
        @tui.draw_main([
          "#{@player.name}'s Status:",
          "Level: #{@player.level}",
          "Experience: #{@player.experience}/#{@player.experience_to_level_up}",
          "Health: #{@player.health}",
          "Damage Bonus: #{@player.damage_bonus}",
          "Gold: #{@player.gold}",
          "Inventory: #{@player.inventory.join(', ')}",
          "Allies: #{@player.allies.join(', ')}"
        ])
        @tui.pause
      when "inventory"
        check_inventory
      when "explore"
        if @current_room.sub_areas.empty?
          @tui.draw_main(["There are no sub-areas to explore here."])
          @tui.pause
        else
          input = @tui.prompt("Enter sub-area to explore (#{@current_room.sub_areas.join(', ')}): ")
          input = correct_input(input, @current_room.sub_areas)
          if @current_room.sub_areas.map(&:downcase).include?(input.downcase)
            explore_sub_area(input)
          else
            @tui.draw_main(["That sub-area does not exist."])
            @tui.pause
          end
        end
      when "save"
        SaveSystem.save(@player, @rooms.key(@current_room))
        @tui.draw_main(["✅ Game saved!"])
        @tui.pause
      when "quit"
        answer = @tui.prompt("Do you want to save before quitting? (yes/no): ").downcase
        if answer == "yes"
          SaveSystem.save(@player, @rooms.key(@current_room))
          @tui.draw_main(["💾 Game saved."])
        end
        @tui.draw_main(["👋 Goodbye!"])
        @tui.pause
        exit
      when "boss"
        explore_boss_area if @current_room.boss_sub_area
      when *(@current_room.directions.keys)
        if input == "north" && @current_room == @rooms[:river] && !@rooms[:river].directions.key?("north")
          @tui.draw_main(["You cannot go north until you fix the boat on the riverbank."])
          @tui.pause
        else
          @current_room = @rooms[@current_room.directions[input]]
          random_event
        end
      else
        @tui.draw_main(["You can't go that way."])
        @tui.pause
      end
    end
  end

  def correct_input(input, valid_options)
    closest_match = valid_options.min_by { |option| Levenshtein.distance(input, option) }
    distance = Levenshtein.distance(input, closest_match)

    if distance <= 2
        puts "Did you mean '#{closest_match}'? (Assuming yes)" if distance > 0 # Add to ask for confirmation if not exact match
        return closest_match
    else
        return input
    end
  end

  def check_inventory
    if @player.inventory.empty?
      @tui.draw_main(["Your inventory is empty!"])
      @tui.pause
      return
    end
  
    loop do
      lines = []
      lines << "Your Inventory:"
      lines += @player.inventory.map.with_index { |item, i| "#{i + 1}. #{item}" }
      lines << ""
      lines << "Type the name of an item to use it."
      lines << "Type 'help' for item descriptions, or 'back' to return."
  
      @tui.draw_main(lines)
      @tui.draw_sidebar(@player)
      input = @tui.prompt("Use item, help, or back: ").downcase.strip
  
      if input == "back"
        break
      elsif input == "help"
        display_item_help
      else
        item = @player.inventory.find { |i| i.downcase == input.downcase }
        if item
          InventoryUtils.use_item(@player, item)
        else
          @tui.draw_main(["You don't have that item."])
          @tui.pause
        end
      end
    end
  end

  def display_item_help
    lines = ["Item Descriptions:"]
    @player.inventory.each do |item|
      desc = case item
             when "Healing Potion"     then "Restores 20 health."
             when "Fresh Fish"         then "Restores 15 health."
             when "Medicinal Herbs"    then "Restores 10 health."
             when "Golden Feather"     then "Restores 15 health."
             when "Ancient Relic"      then "Permanently increases health by 20 and damage bonus by 10."
             when "Hunter's Supplies"  then "Increases damage bonus by 5."
             when "Glowing Crystals"   then "Increases health by 15."
             when "Echoing Gem"        then "Increases damage bonus by 10."
             when "Small Boat"         then "Allows river crossing."
             when "Royal Secrets"      then "Might unlock events."
             when "Silver Sword"       then "Deals 20 damage to enemies."
             when "Magic Scroll"       then "Deals 30 magic damage to enemies."
             when "Ruby Gem"           then "Increases gold by 20%."
             when "Enchanted Amulet"   then "Reduces damage taken by 5."
             when "Phoenix Feather"    then "Revives you when defeated."
             when "Elixir of Life"     then "Permanently increases health by 10."
             else "No description available."
             end
      lines << "- #{item}: #{desc}"
    end
    @tui.draw_main(lines)
    @tui.draw_sidebar(@player)
    @tui.pause
  end

  def find_treasure
    puts "\nYou stumble upon a hidden treasure!"
    treasure = $config.treasure_items.sample
    @player.inventory << treasure
    puts "You found a treasure: #{treasure}!"
    @tui.pause
  end





  def encounter_enemy
    enemy_data = $config.enemy_types.sample
  
    if enemy_data.nil? || !enemy_data.is_a?(Hash)
      @tui.draw_main(["Error: Invalid enemy data."])
      @tui.pause
      return
    end
  
    enemy = Enemy.new(
      enemy_data["name"] || "Unknown",
      enemy_data["health"] || 10,
      enemy_data["damage"] || 5,
      enemy_data["ability"] || "None",
      enemy_data["description"] || "No description."
    )
  
    loop do
      draw_combat_ui(enemy)
      player_turn(enemy)
      break if enemy.health <= 0
  
      check_loss
      enemy_turn(enemy)
      break if @player.health <= 0
  
      check_loss
    end
  
    if enemy.health <= 0
      reward_player_for_victory(enemy)
    end
  end
  
  def draw_combat_ui(enemy)
    lines = []
    lines << "⚔️  === Boss Battle Begins ===" if enemy.health > 150
    lines << "⚔️  === Combat Begins ===" if enemy.health <= 150
    lines << ""
    lines << "💀 Enemy: #{enemy.type}"
    lines << "   HP: #{[0, enemy.health].max}"
    lines << "   Ability: #{enemy.ability}"
    lines << "-" * 40
    lines << "🧝 You: #{@player.name}"
    lines << "   HP: #{@player.health}"
    lines << "   Damage Bonus: #{@player.damage_bonus}"
    lines << "   Gold: #{@player.gold}"
    lines << "-" * 40
    lines << "🎮 Your Options:"
    lines << "1. Attack"
    lines << "2. Use Item"
    lines << "3. Inventory"
    @tui.draw_main(lines)
    @tui.draw_sidebar(@player)
  end

  def player_turn(enemy)
    loop do
      input = @tui.prompt("Choose your action: ")
  
      case input
      when "1"
        damage = CombatUtils.calculate_damage(10, @player.damage_bonus)
        damage = CombatUtils.apply_damage_reduction(damage, 50) if enemy.ability == "Stone Skin"
        enemy.health -= damage
        @tui.draw_main([
          "🗡️  Your Turn",
          "You attack the #{enemy.type}!",
          "You dealt #{damage} damage."
        ])
        @tui.pause
        break
      when "2"
        if @player.inventory.empty?
          @tui.draw_main(["You have no items to use."])
          @tui.pause
        else
          item = @tui.prompt("Enter item name to use:")
          if @player.inventory.include?(item)
            InventoryUtils.use_item(@player, item, enemy)
            @tui.pause
            break
          else
            @tui.draw_main(["You don't have that item."])
            @tui.pause
          end
        end
      when "3"
        check_inventory
      else
        @tui.draw_main(["Invalid choice. Choose 1, 2, or 3."])
        @tui.pause
      end
    end
  
    CombatUtils.process_damage_over_time(enemy)
  end

  def enemy_turn(enemy)
    CombatUtils.process_damage_over_time(@player)

    if rand < 0.3 && enemy.ability.downcase != "none" # 30% chance to use ability
      case enemy.ability.downcase
      when "quick strike"
        damage = CombatUtils.calculate_damage(enemy.damage + 5, 0)
        @player.health -= damage
        puts "#{enemy.type} uses Quick Strike! It deals #{damage} damage quickly."

      when "berserk"
        damage = CombatUtils.calculate_damage(enemy.damage * 2, 0)
        @player.health -= damage
        puts "#{enemy.type} goes Berserk! It deals #{damage} massive damage."

      when "regeneration"
        heal_amount = rand(10..20)
        enemy.health += heal_amount
        puts "#{enemy.type} uses Regeneration! It heals #{heal_amount} health."

      when "steal gold"
        stolen_gold = [@player.gold, rand(5..15)].min
        @player.gold -= stolen_gold
        puts "#{enemy.type} uses Steal Gold! It steals #{stolen_gold} gold from you."

      when "magic blast"
        damage = CombatUtils.calculate_damage(enemy.damage, 0)
        @player.health -= damage
        puts "#{enemy.type} casts Magic Blast! It deals #{damage} direct damage, ignoring armor."

      when "pack tactics"
        bonus_damage = 5  # Example bonus for pack tactics
        damage = CombatUtils.calculate_damage(enemy.damage + bonus_damage, 0)
        @player.health -= damage
        puts "#{enemy.type} uses Pack Tactics! It deals #{damage} damage with a bonus from its pack."

      when "stone skin"
        enemy.damage_reduction = 50
        puts "#{enemy.type} uses Stone Skin! It reduces incoming damage by 50% for the next turn."

      when "critical strike"
        if rand < 0.3  # 30% chance for critical hit
          damage = CombatUtils.calculate_damage(enemy.damage * 2, 0)
          puts "#{enemy.type} uses Critical Strike! It deals #{damage} critical damage."
        else
          damage = CombatUtils.calculate_damage(enemy.damage, 0)
          puts "#{enemy.type} attacks normally and deals #{damage} damage."
        end
        @player.health -= damage

      when "burn"
        damage = CombatUtils.calculate_damage(enemy.damage, 0)
        @player.health -= damage
        CombatUtils.apply_damage_over_time(@player, 5, 3)
        puts "#{enemy.type} uses Burn! It deals #{damage} damage and applies burn damage over time."

      when "freeze"
        damage = CombatUtils.calculate_damage(enemy.damage, 0)
        @player.health -= damage
        @player.damage_bonus = [@player.damage_bonus - 5, 0].max
        puts "#{enemy.type} uses Freeze! It deals #{damage} damage and reduces your damage bonus by 5 for a few turns."

      else
        damage = CombatUtils.calculate_damage(enemy.damage, 0)
        @player.health -= damage
        puts "#{enemy.type} attacks you! It deals #{damage} damage."
      end
    else
      # Default attack if the ability is not used
      damage = CombatUtils.calculate_damage(enemy.damage, 0)
      @player.health -= damage
      puts "#{enemy.type} attacks you! It deals #{damage} damage."
    end

    @tui.draw_main([
      "💀 #{enemy.type}'s Turn",
      "The #{enemy.type} strikes you!",
      "You took #{damage} damage!"
    ])
    @tui.pause
  end

  def reward_player_for_victory(enemy)
    lines = ["You defeated the #{enemy.type}!"]
  
    exp = case enemy.type.downcase
          when "goblin", "bandit" then 50
          when "orc", "troll" then 100
          else 150
          end
  
    @player.gain_experience(exp)
    lines << "You gained #{exp} XP."
  
    gold = case enemy.type.downcase
           when "goblin", "bandit" then rand(10..20)
           when "orc", "troll" then rand(20..40)
           else rand(40..60)
           end
  
    @player.gold += gold
    lines << "You found #{gold} gold."
  
    if rand < 0.3
      item = $config.treasure_items.sample
      @player.inventory << item
      lines << "The #{enemy.type} dropped: #{item}"
    end
  
    @tui.draw_main(lines)
    @tui.draw_sidebar(@player)
    @tui.pause
  end








  

  def find_ally
    puts "\nYou encounter a potential ally!"
    ally = $config.ally_types.sample
    puts "You found an ally: #{ally}!"

    if @player.allies.include?(ally)
      puts "You already have this ally in your party. They cannot join again."
    else
      print "Would you like this ally to join your party? (yes/no): "
      response = gets.chomp.downcase
      if response == "yes"
        @player.apply_ally_bonus(ally)
        @player.allies << ally
        puts "#{ally} has joined your party!"
      else
        puts "You decided not to let #{ally} join your party."
      end
    end
    @tui.pause
  end

  def discover_mystery
    puts "\nYou stumble upon something mysterious!"
    puts "You discovered a mysterious object. It glows faintly but does nothing... for now."
    @tui.pause
  end

  def encounter_trap
    damage = rand(10..30)
    @player.health -= damage
    puts "You triggered a trap and lost #{damage} health!"
    check_loss
    @tui.pause
  end

  def random_event
    if @current_room.unique_events.any? && rand < 0.3
      unique_event = @current_room.unique_events.sample
      send(unique_event)
    else
      case rand(1..4)
      when 1 then find_treasure
      when 2 then encounter_enemy
      when 3 then find_ally
      when 4 then discover_mystery
      end
    end
  end

  # Mountain unique events
  def find_eagle_nest
    @tui.draw_main([
      "You find an eagle's nest with a shiny object inside.",
      "You added 'Golden Feather' to your inventory."
    ])
    @player.inventory << "Golden Feather"
    @tui.pause
  end

  def trigger_rockslide
    damage = rand(10..20)
    @tui.draw_main([
      "You accidentally trigger a rockslide! You barely escape but lose some health.",
      "You lost #{damage} health."
    ])
    @player.health -= damage
    check_loss
    @tui.pause
  end

  # Village unique events
  def visit_blacksmith
    @tui.draw_main([
      "You visit the blacksmith, who offers to upgrade your weapon.", 
      "Your damage bonus increased by 5."
    ])
    @player.damage_bonus += 5
    @tui.pause
  end

  def talk_to_elder
    @tui.draw_main([
      "You talk to the village elder, who shares ancient wisdom with you.", 
      "Your health bonus increased by 10."
    ])
    @player.health_bonus += 10
    @tui.pause
  end

  # Castle unique events
  def find_treasure_chest
    @tui.draw_main([
      "You find a hidden treasure chest filled with gold and jewels.",
      "You gained 50 gold!"
    ])
    @player.gold += 50 
    @tui.pause
  end

  def meet_royal_guard
    @tui.draw_main([
      "You meet a royal guard who challenges you to a duel."
    ])
    encounter_enemy
  end

  # Peak unique events
  def find_ancient_relic
    @tui.draw_main([
      "You discover an ancient relic that radiates power.",
      "You added 'Ancient Relic' to your inventory."
    ])
    @player.inventory << "Ancient Relic"
    @tui.pause
  end

  def encounter_lightning_storm
    damage = rand(15..30)
    @tui.draw_main([
      "A sudden lightning storm strikes! You take damage but feel energized.",
      "You lost #{damage} health but gained 5 damage bonus."
    ])
    @player.health -= damage
    @player.damage_bonus += 5
    check_loss
    @tui.pause
  end

  # Throne Room unique events
  def find_royal_secrets
    @tui.draw_main([
      "You uncover royal secrets hidden in the throne room.",
      "You added 'Royal Secrets' to your inventory."
    ])
    @player.inventory << "Royal Secrets"
    @tui.pause
  end

  def activate_trap
    damage = rand(20..40)
    @tui.draw_main([
      "You accidentally activate a trap! Poisonous gas fills the room.",
      "You lost #{damage} health!"
    ])
    @player.health -= damage
    check_loss
    @tui.pause
  end

  # Forest unique events
  def find_herbs
    @tui.draw_main([
      "You find some medicinal herbs growing in the forest.",
      "You added 'Medicinal Herbs' to your inventory."
    ])
    @player.inventory << "Medicinal Herbs"
    @tui.pause
  end

  def meet_hunter
    @tui.draw_main([
      "You meet a hunter who offers to share some of his supplies.",
      "You added 'Hunter's Supplies' to your inventory."
    ])
    @player.inventory << "Hunter's Supplies"
    @tui.pause
  end

  def hear_echoes
    @tui.draw_main([
      "You hear strange echoes in the cave.",
      "They seem to guide you to a hidden treasure.",
      "You added 'Echoing Gem' to your inventory."
    ])
    @player.inventory << "Echoing Gem"
    @tui.pause
  end

  def find_crystals
    
    @tui.draw_main([
      "You discover a cluster of glowing crystals in the cave.",
      "You added 'Glowing Crystals' to your inventory."
    ])
    @player.inventory << "Glowing Crystals"
    @tui.pause
  end

  # River unique events
  def catch_fish
    @tui.draw_main([
      "You catch a fish from the river. It looks delicious.",
      "You added 'Fresh Fish' to your inventory."
    ])
    @player.inventory << "Fresh Fish"
    @tui.pause
  end

  def explore_sub_area(sub_area)
    case sub_area.downcase
    when "store"
      store
    when "village square"
      @tui.draw_main([
        "You explore the village square and meet friendly villagers.",
        "The villagers give you 10 gold as a gift!"
      ])
      @player.gold += 10
      @tui.pause
    when "riverbank"
      if @player.inventory.include?("Repair Kit")
        @tui.draw_main([
          "You find a broken boat at the riverbank.",
          "Using the Repair Kit, you fix the boat and can now cross the river!",
          "The Repair Kit has been used up."
        ])
        @rooms[:river].directions["north"] = :village
        @player.inventory.delete("Repair Kit")
      else
        @tui.draw_main([
          "You find a broken boat at the riverbank, but you need a Repair Kit to fix it."
        ])
      end
      @tui.pause
    when "clearing"
      @tui.draw_main([
        "You explore the clearing and find a hidden chest.",
        "You added 'Healing Potion' to your inventory."
      ])
      @player.inventory << "Healing Potion"
      @tui.pause
    when "dense thicket"
      @tui.draw_main([
        "You push through the dense thicket and encounter an enemy!"
      ])
      @tui.pause
      encounter_enemy
      return  # encounter_enemy already pauses
    when "hidden grove", "crystal chamber", "echoing hall", "castle library", "peak shrine"
      puzzles = $config.puzzles[sub_area.downcase.gsub(" ", "_")]
      if puzzles.nil? || puzzles.empty?
        puts "There are no puzzles available in this sub-area."
      else
        puzzle = puzzles.sample
        solve_puzzle(puzzle.transform_keys(&:to_sym))
        return
      end
    else
      puts "There is nothing interesting in this sub-area."
    end
    @tui.pause
  end

  def explore_boss_area
    return unless @current_room.boss
  
    boss = @current_room.boss
    lines = [
      "WARNING: You are about to enter the boss area: #{boss[:name]}!",
      "This will be a difficult battle. Make sure you are prepared."
    ]
    @tui.draw_main(lines)
    @tui.draw_sidebar(@player)
    response = @tui.prompt("Do you want to enter? (yes/no): ").downcase
  
    if response == "yes"
      encounter_boss(boss)
    else
      @tui.draw_main(["You decide not to enter the boss area for now."])
      @tui.pause
    end
  end

  def encounter_boss(boss)

    enemy = Enemy.new(boss[:name], boss[:health], 15, "Special Attack", "The boss looms over you with immense power.")
    @tui.draw_main([
      "The wind howls as you enter...",
      "A shadow looms... it's #{boss[:name]}!",
      "#{boss[:name]}: #{enemy.description}"
    ])
    @tui.pause

    loop do
      draw_combat_ui(enemy)
      player_turn(enemy)
      break if enemy.health <= 0
  
      check_loss
      enemy_turn(enemy)
      break if @player.health <= 0
  
      check_loss
    end
  
    if enemy.health <= 0
      @player.inventory << boss[:reward]
      @tui.draw_main([
        "🏆 You defeated the boss: #{enemy.type}!",
        "You gained the reward: #{boss[:reward]}!"
      ])
      @tui.pause
    end
  end

  def solve_puzzle(puzzle)
    if puzzle[:question].nil? || puzzle[:options].nil? || !puzzle[:options].is_a?(Array)
      @tui.draw_main(["⚠️  Error: Invalid puzzle data. Skipping puzzle."])
      @tui.pause
      return
    end
  
    lines = []
    lines << "🧠 Puzzle Challenge!"
    lines << "-" * 40
    lines << puzzle[:question]
    lines << ""
  
    puzzle[:options].each_with_index do |option, index|
      lines << "#{index + 1}. #{option}"
    end
  
    lines << ""
    lines << "Choose the correct answer (1-#{puzzle[:options].size})"
  
    @tui.draw_main(lines)
    @tui.draw_sidebar(@player)
    input = @tui.prompt("Your answer: ")
  
    choice = input.to_i
    correct = puzzle[:correct_answer]
  
    if choice == correct
      reward_text = ["✅ Correct! #{puzzle[:reward_message]}"]
  
      case puzzle[:reward_type]
      when :item
        @player.inventory << puzzle[:reward]
        reward_text << "You received: #{puzzle[:reward]}"
      when :gold
        @player.gold += puzzle[:reward]
        reward_text << "You received #{puzzle[:reward]} gold!"
      when :stat
        reward = puzzle[:reward]
        @player.health += reward[:health] if reward[:health]
        @player.damage_bonus += reward[:damage_bonus] if reward[:damage_bonus]
        reward_text << "Your stats have improved!"
      end
  
      @tui.draw_main(reward_text)
    else
      penalty_text = ["❌ Incorrect! #{puzzle[:penalty_message]}"]
  
      case puzzle[:penalty_type]
      when :health
        @player.health -= puzzle[:penalty]
        penalty_text << "You lost #{puzzle[:penalty]} health."
      when :gold
        @player.gold -= puzzle[:penalty]
        @player.gold = 0 if @player.gold < 0
        penalty_text << "You lost #{puzzle[:penalty]} gold."
      when :item
        if @player.inventory.include?(puzzle[:penalty])
          @player.inventory.delete(puzzle[:penalty])
          penalty_text << "You lost the item: #{puzzle[:penalty]}"
        else
          penalty_text << "No item to lose."
        end
      end
  
      check_loss
      @tui.draw_main(penalty_text)
    end
  
    @tui.pause
  end

  def store
    store_items = {
      "Medicinal Herbs" => 10,
      "Healing Potion" => 20,
      "Hunter's Supplies" => 15,
      "Golden Feather" => 50
    }
  
    loop do
      lines = []
      lines << "🛒 Welcome to the Store!"
      lines << "You have #{@player.gold} gold."
      lines << ""
      store_items.each_with_index do |(item, price), index|
        lines << "#{index + 1}. #{item} - #{price} gold"
      end
      lines << "#{store_items.size + 1}. Exit Store"
      lines << ""
      lines << "Enter the number of the item to buy."
  
      @tui.draw_main(lines)
      @tui.draw_sidebar(@player)
      input = @tui.prompt("Your choice: ").strip
  
      choice = input.to_i
  
      if choice == store_items.size + 1
        @tui.draw_main(["Thank you for visiting the store!"])
        @tui.pause
        break
      elsif choice.between?(1, store_items.size)
        item, price = store_items.to_a[choice - 1]
        if @player.gold >= price
          @player.gold -= price
          @player.inventory << item
          @tui.draw_main([
            "✅ You purchased #{item} for #{price} gold.",
            "Remaining gold: #{@player.gold}."
          ])
          @tui.pause
        else
          @tui.draw_main([
            "❌ You don't have enough gold for #{item}!",
            "You have #{@player.gold}, but need #{price}."
          ])
          @tui.pause
        end
      else
        @tui.draw_main(["Invalid choice. Please enter a number between 1 and #{store_items.size + 1}."])
        @tui.pause
      end
    end
  end
end

module TUI
  class TUIManager
    def initialize
      Curses.init_screen
      Curses.cbreak
      Curses.noecho
      Curses.stdscr.keypad(true)
      @main_win = Curses.stdscr
      @side_win = Curses::Window.new(Curses.lines, 30, 0, Curses.cols - 30)  # height, width, y, x
    end

    def close
      Curses.close_screen
    end

    def draw_main(text_lines)
      @main_win.clear
      text_lines.each_with_index do |line, i|
        @main_win.setpos(i + 1, 2)
        @main_win.addstr(line.to_s[0, Curses.cols - 32]) # leave room for sidebar
      end
      @main_win.refresh
    end

    def draw_sidebar(player)
      @side_win.clear
      @side_win.box("|", "-")
      @side_win.setpos(1, 2)
      @side_win.addstr("📊 Player Stats")
    
      stats = [
        "Name: #{player.name}",
        "Level: #{player.level}",
        "XP: #{player.experience}/#{player.experience_to_level_up}",
        "HP: #{player.health}",
        "Gold: #{player.gold}",
        "Dmg Bonus: #{player.damage_bonus}",
        "Inventory:"
      ]
    
      stats.each_with_index do |line, idx|
        @side_win.setpos(3 + idx, 2)
        @side_win.addstr(line)
      end
    
      player.inventory.first(5).each_with_index do |item, i|
        @side_win.setpos(10 + i, 4)
        @side_win.addstr("- #{item}")
      end
    
      @side_win.refresh
    end

    def prompt(message = ">> ")
      Curses.echo                # Turn echo *on*
      @main_win.setpos(Curses.lines - 2, 2)
      @main_win.clrtoeol
      @main_win.addstr(message)
      @main_win.refresh
      input = @main_win.getstr.strip
      Curses.noecho              # Turn echo *off* again afterward
      input
    end

    def error_message(message)
      @main_win.setpos(Curses.lines - 2, 2)
      @main_win.addstr("Error: #{message}")
      @main_win.refresh
    end

    def pause
      @main_win.setpos(Curses.lines - 2, 2)
      @main_win.addstr("Press Enter to continue...")
      @main_win.refresh
      @main_win.getstr
    end


  end
end

# Start the game
tui = TUI::TUIManager.new
begin
  game = Game.new(tui)
  game.start
ensure
  tui.close
end
