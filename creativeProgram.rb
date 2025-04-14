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
end

# Define a module for inventory-related utilities.
module InventoryUtils

  #Define item contexts
  ITEM_CONTEXTS = {
    "Healing Potion" => :any,
    "Fresh Fish" => :any,
    "Medicinal Herbs" => :any,
    "Golden Feather" => :any,
    "Ancient Relic" => :any,
    "Hunter's Supplies" => :any,
    "Glowing Crystals" => :any,
    "Echoing Gem" => :any,
    "Magic Scroll" => :combat,
    "Silver Sword" => :combat,
    "Ruby Gem" => :any,
    "Enchanted Amulet" => :any,
    "Phoenix Feather" => :any,
    "Elixir of Life" => :any,
  }
  # Return a compact, display-friendly version of the inventory
  def self.compact_inventory(inventory)
    inventory.map do |item|
      case item
      when String
        item
      when Array
        "#{item[0]} x#{item[1]}"
      when Hash
        item[:name] + (item[:permanent] ? " (permanent)" : "")
      else
        item.to_s
      end
    end
  end

    # Find an item in the inventory and return its index and normalized name
  def self.find_item(player, name)
    player.inventory.each_with_index do |item, i|
      case item
      when String
        return [i, item] if item.downcase == name.downcase
      when Array
        return [i, item[0]] if item[0].downcase == name.downcase
      when Hash
        return [i, item[:name]] if item[:name].downcase == name.downcase
      end
    end
    [nil, nil]
  end
  
    # Decrease count or remove item from inventory after use
  def self.consume_item(player, name)
    index, item_name = find_item(player, name)
    return false unless index
  
    item = player.inventory[index]
    case item
    when String
      player.inventory.delete_at(index)
    when Array
      if item[1] > 1
        player.inventory[index][1] -= 1
      else
        player.inventory.delete_at(index)
      end
    when Hash
      player.inventory.delete_at(index) unless item[:permanent]
    end
    true
  end


  def self.use_item(player, item, enemy = nil, context = :map)
    lines = []
    context_rule = ITEM_CONTEXTS[item] || :any
    if context_rule != :any && context_rule != context
      lines << "You can't use #{item} right now."
      return lines
    end
    case item
    when /^Healing Potion$/i
      if player.health >= ($config.starting_health + player.health_bonus)
        lines << "You are already at full health. You can't use a Healing Potion right now."
        return lines
      elsif player.health + 20 > ($config.starting_health + player.health_bonus)
        player.health = ($config.starting_health + player.health_bonus)
        lines << "You used a Healing Potion and restored #{($config.starting_health + player.health_bonus) - player.health} health."
      else
        player.health += 20
        lines << "You used a Healing Potion and restored 20 health."
      end
    when /^Fresh Fish$/i
      if player.health >= ($config.starting_health + player.health_bonus)
        lines << "You are already at full health. You can't use Fresh Fish right now."
        return lines
      elsif player.health + 15 > ($config.starting_health + player.health_bonus)
        player.health = ($config.starting_health + player.health_bonus)
        lines << "You used Fresh Fish and restored #{($config.starting_health + player.health_bonus) - player.health} health."
      else
        player.health += 15
        lines << "You ate Fresh Fish and restored 15 health."
      end
    when /^Medicinal Herbs$/i
      if player.health >= ($config.starting_health + player.health_bonus)
        lines << "You are already at full health. You can't use Medicinal Herbs right now."
        return lines
      elsif player.health + 10 > ($config.starting_health + player.health_bonus)
        player.health = ($config.starting_health + player.health_bonus)
        lines << "You used Medicinal Herbs and restored #{($config.starting_health + player.health_bonus) - player.health} health."
      else
        player.health += 10
        lines << "You used Medicinal Herbs and restored 10 health."
      end
    when /^Golden Feather$/i
      if player.health >= ($config.starting_health + player.health_bonus)
        lines << "You are already at full health. You can't use Golden Feather right now."
        return lines
      elsif player.health + 15 > ($config.starting_health + player.health_bonus)
        player.health = ($config.starting_health + player.health_bonus)
        lines << "You used Golden Feather and restored #{($config.starting_health + player.health_bonus) - player.health} health."
      else
        player.health += 15
        lines << "You used Golden Feather and restored 15 health."
      end
    when /^Ancient Relic$/i
      player.health += 20
      player.health_bonus += 20
      player.damage_bonus += 10
      lines << "The Ancient Relic radiates power, permanently increasing your health by 20 and damage bonus by 10."
    when /^Hunter's Supplies$/i
      player.damage_bonus += 5
      lines << "You used Hunter's Supplies and increased your damage bonus by 5."
    when /^Glowing Crystals$/i
      if player.health >= ($config.starting_health + player.health_bonus)
        lines << "You are already at full health. You can't use Glowing Crystals right now."
        return lines
      elsif player.health + 15 > ($config.starting_health + player.health_bonus)
        player.health = ($config.starting_health + player.health_bonus)
        lines << "You used Glowing Crystals and restored #{($config.starting_health + player.health_bonus) - player.health} health."
      else
        player.health += 15
        lines << "You used Glowing Crystals and restored 15 health."
      end
    when /^Echoing Gem$/i
      player.damage_bonus += 10
      lines << "You used Echoing Gem and increased your damage bonus by 10."
    when /^Magic Scroll$/i
      damage = 30
      enemy.health -= damage
      lines << "You used the Magic Scroll and dealt #{damage} damage to #{enemy.type}!"
    when /^Silver Sword$/i
      damage = 20
      enemy.health -= damage
      lines << "You used the Silver Sword and dealt #{damage} damage to #{enemy.type}!"
    when /^Ruby Gem$/i
      player.gold += (player.gold * 0.2).to_i
      lines << "The Ruby Gem glows, increasing your current gold earnings by 20%."
    when "Enchanted Amulet"
      player.health_bonus += 5
      lines << "The Enchanted Amulet protects you, reducing damage taken by 5."
    when /^Phoenix Feather$/i
      lines << "The Phoenix Feather cannot be used manually. It will activate automatically upon defeat."
      return lines
    when /^Elixir of Life$/i
      player.health_bonus += 10
      player.health += 10
      lines << "You drank the Elixir of Life, permanently increasing your health by 10."
    else
      lines << "You can't use that item right now."
    end
    consume_item(player, item)
    return lines
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
    critical_hit = rand < critical_chance
    if critical_hit
      damage = (damage * critical_multiplier).to_i
    end
    damage
  end

  def self.apply_damage_reduction(damage, reduction_percentage)
    reduced_damage = (damage * (1 - reduction_percentage / 100.0)).to_i
    return "Damage reduced by #{reduction_percentage}%! Final damage: #{reduced_damage}.", reduced_damage
  end

  def self.apply_damage_over_time(target, damage, turns)
    if target.dot_effect
      current_damage = target.dot_effect[:damage]
      current_turns = target.dot_effect[:turns]
      if damage > current_damage || turns > current_turns
        target.dot_effect = { damage: damage, turns: turns }
      end
    else
      target.dot_effect = { damage: damage, turns: turns }
    end
  end

  def self.process_damage_over_time(target)
    if target.dot_effect && target.dot_effect[:turns] > 0
      damage = target.dot_effect[:damage]
      target.health -= damage
      target.dot_effect[:turns] -= 1
    elsif target.dot_effect && target.dot_effect[:turns] <= 0
      target.dot_effect = nil
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

  def level_up(amount)
    @experience += amount
    if @experience >= experience_to_level_up
      @level += 1
      @experience = 0
      @health += 20
      @damage_bonus += 5
      return true
    end
    
  end

  def experience_to_level_up
    100 * @level
  end

  #TODO : add actual functionality to other allies than Brave Warrior
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
      #puts "The brave warrior increases your damage by 15."
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
        @tui.draw_main(["The Phoenix Feather activates and revives you with #{@player.health} health!"])
        @tui.pause
      else
        @tui.draw_main(["Your health has dropped below 0. You lose!"])
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

  def add_to_inventory(item)
    existing = @player.inventory.find do |i|
      i.is_a?(Array) && i[0] == item
    end
  
    if existing
      existing[1] += 1
    else
      @player.inventory << [item, 1]
    end
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
      input = correct_input(input, @current_room.directions.keys + ["status", "inventory", "explore", "boss", "save", "quit"])
  
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
        check_inventory()
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
    # Normalize input
    input = input.strip.downcase

    # Define regex patterns for common commands
    direction_regex = /^(go|move|walk)\s+(north|south|east|west)$/i
    use_item_regex = /^(use|consume|activate)\s+(.+)$/i

    # Match input against regex patterns
    if input.match?(direction_regex)
      direction = input.match(direction_regex)[2]
      return direction if valid_options.include?(direction)
    elsif input.match?(use_item_regex)
      item = input.match(use_item_regex)[2]
      return item if valid_options.include?(item)
    end

    # Fuzzy matching for typos
    closest_match = valid_options.min_by { |option| Levenshtein.distance(input, option) }
    distance = Levenshtein.distance(input, closest_match)

    if distance <= 2
      if distance > 0
        confirm = @tui.prompt("Did you mean '#{closest_match}'? (yes/no)").downcase
        return confirm == "yes" ? closest_match : nil
      else
        return closest_match
      end
    else
      @tui.prompt "Input not recognized. Please try again."
      return nil
    end
  end

  def check_inventory(enemies = nil, context = :map)
    if @player.inventory.empty?
      @tui.draw_main(["Your inventory is empty!"])
      @tui.pause
      return
    end
  
    loop do
      lines = []
      lines << "Your Inventory:"
      lines += InventoryUtils.compact_inventory(@player.inventory).map.with_index { |item, i| "#{i + 1}. #{item}" }
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
        item = InventoryUtils.find_item(@player, input)[1]
        if item
          @tui.draw_main(InventoryUtils.use_item(@player, item, enemies, context))
          @tui.pause
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
    treasure = $config.treasure_items.sample
    add_to_inventory(treasure)
    @tui.draw_main(["You stumble upon a hidden treasure!",
      "You found a treasure: #{treasure}!"
    ])
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
    input = @tui.prompt("Choose your action: ")
    loop do
  
      case input
      when "1"
        damage, critical_hit = CombatUtils.calculate_damage(10, @player.damage_bonus)
        damage_statement, damage = CombatUtils.apply_damage_reduction(damage, 50) if enemy.ability == "Stone Skin"
        enemy.health -= damage
        lines = [
          "🗡️  Your Turn",
          "You attack the #{enemy.type}!",
          "You dealt #{damage} damage."
        ]
        lines << damage_statement if enemy.ability == "Stone Skin"
        @tui.draw_main(lines)
        @tui.pause
        break
      when "2"
        if @player.inventory.empty?
          input = @tui.prompt("You have no items to use, choose another action: ")
        else
          item = @tui.prompt("Enter item name to use:")
          if @player.inventory.include?(item)
            @tui.draw_main(InventoryUtils.use_item(@player, item, enemy, :combat))
            @tui.pause
            break
          else
            input = @tui.prompt("You don't have that item, choose your action: ")
          end
        end
      when "3"
        if @player.inventory.empty?
          input = @tui.prompt("You have no items to use, choose another action: ")
        else
          check_inventory(enemy, :combat)
          break
        end
      else
        input = @tui.prompt("Invalid choice. Choose 1, 2, or 3: ")
      end
    end
  
    CombatUtils.process_damage_over_time(enemy)
  end

  def enemy_turn(enemy)
    CombatUtils.process_damage_over_time(@player)
    lines = []
    lines << "💀 Enemy's Turn"

    if rand < 0.3 && enemy.ability.downcase != "none" # 30% chance to use ability
      
      case enemy.ability.downcase
      when "quick strike"
        damage = CombatUtils.calculate_damage(enemy.damage + 5, 0)
        @player.health -= damage
        lines << "#{enemy.type} uses Quick Strike!"
        lines << "You take #{damage} damage quickly."

      when "berserk"
        damage = CombatUtils.calculate_damage(enemy.damage * 2, 0)
        @player.health -= damage
        lines << "#{enemy.type} goes Berserk!"
        lines << "You take #{damage} massive damage."

      when "regeneration"
        heal_amount = rand(10..20)
        enemy.health += heal_amount
        lines << "#{enemy.type} uses Regeneration!"
        lines << "It heals #{heal_amount} health."

      when "steal gold"
        stolen_gold = [@player.gold, rand(5..15)].min
        @player.gold -= stolen_gold
        lines << "#{enemy.type} uses Steal Gold!"
        lines << "It steals #{stolen_gold} gold from you."

      when "magic blast"
        damage = CombatUtils.calculate_damage(enemy.damage, 0)
        @player.health -= damage
        lines << "#{enemy.type} casts Magic Blast!"
        lines << "You take #{damage} direct damage, ignoring armor."

      when "pack tactics"
        bonus_damage = 5  # Example bonus for pack tactics
        damage = CombatUtils.calculate_damage(enemy.damage + bonus_damage, 0)
        @player.health -= damage
        lines << "#{enemy.type} uses Pack Tactics!"
        lines << "You take #{damage} damage with a bonus from its pack."

      when "stone skin"
        original_damage_bonus = @player.damage_bonus
        @player.damage_bonus = (@player.damage_bonus / 2).to_i
        lines << "#{enemy.type} uses Stone Skin!"
        lines << "Your damage is halved for the next turn."

        # Restore the player's damage bonus after one turn
        CombatUtils.process_damage_over_time(@player) # Simulate the turn passing
        @player.damage_bonus = original_damage_bonus

      when "critical strike"
        if rand < 0.3  # 30% chance for critical hit
          damage = CombatUtils.calculate_damage(enemy.damage * 2, 0)
          lines << "#{enemy.type} uses Critical Strike!"
          lines << "You take #{damage} critical damage."
        else
          damage = CombatUtils.calculate_damage(enemy.damage, 0)
          lines << "#{enemy.type} attacks you!"
          lines << "You take #{damage} damage."
        end
        @player.health -= damage

      when "burn"
        damage = CombatUtils.calculate_damage(enemy.damage, 0)
        @player.health -= damage
        CombatUtils.apply_damage_over_time(@player, 5, 3)
        lines << "#{enemy.type} uses Burn!"
        lines << "You take #{damage} damage and applies burn damage over time."

      when "freeze"
        damage = CombatUtils.calculate_damage(enemy.damage, 0)
        @player.health -= damage
        @player.damage_bonus = [@player.damage_bonus - 5, 0].max
        lines << "#{enemy.type} uses Freeze!"
        lines << "You take #{damage} damage and it reduces your damage bonus by 5 for a few turns."

      else
        damage = CombatUtils.calculate_damage(enemy.damage, 0)
        @player.health -= damage
        lines << "#{enemy.type} attacks you!"
        lines << "You take #{damage} damage."
      end
    else
      # Default attack if the ability is not used
      damage = CombatUtils.calculate_damage(enemy.damage, 0)
      @player.health -= damage
      lines << "#{enemy.type} attacks you!"
      lines << "You take #{damage} damage."
    end

    @tui.draw_main(lines)
    @tui.pause
  end

  def reward_player_for_victory(enemy)
    lines = ["You defeated the #{enemy.type}!"]
  
    exp = case enemy.type.downcase
          when "goblin", "bandit" then 50
          when "orc", "troll" then 100
          else 150
          end
    
    lines << "You gained #{exp} XP."
    if @player.level_up(exp)
      lines << "Congratulations! You leveled up to Level #{@level}!"
      lines <<  "Your health increased by 20, and your damage bonus increased by 5."
    end
    

  
    gold = case enemy.type.downcase
           when "goblin", "bandit" then rand(10..20)
           when "orc", "troll" then rand(20..40)
           else rand(40..60)
           end
  
    @player.gold += gold
    lines << "You found #{gold} gold."
  
    if rand < 0.3
      item = $config.treasure_items.sample
      add_to_inventory(item)
      lines << "The #{enemy.type} dropped: #{item}"
    end
  
    @tui.draw_main(lines)
    @tui.draw_sidebar(@player)
    @tui.pause
  end








  

  def find_ally
    @tui.draw_main([
      "You encounter a potential ally!",
      "You found an ally: a brave warrior!"
    ])
  
    if @player.allies.include?("a brave warrior")
      @tui.draw_main(["You already have this ally in your party. They cannot join again."])
    else
      response = @tui.prompt("Would you like this ally to join your party? (yes/no): ").downcase
      if response == "yes"
        @player.apply_ally_bonus("a brave warrior")
        @player.allies << "a brave warrior"
        @tui.draw_main(["a brave warrior has joined your party!", 
          "The brave warrior increases your damage by 15."
        ])
      else
        @tui.draw_main(["You decided not to let a brave warrior join your party."])
      end
    end
  
    @tui.pause
  end

  def discover_mystery
    @tui.draw_main(["You stumble upon something mysterious!",
    "You discovered a mysterious object. It glows faintly but does nothing... for now."
    ])
    @tui.pause
  end

  def encounter_trap
    damage = rand(10..30)
    @player.health -= damage
    @tui.draw_main(["You triggered a trap and lost #{damage} health!"])
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
    add_to_inventory("Golden Feather")
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
    add_to_inventory("Ancient Relic")
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
    add_to_inventory("Royal Secrets")
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
    add_to_inventory("Medicinal Herbs")
    @tui.pause
  end

  def meet_hunter
    @tui.draw_main([
      "You meet a hunter who offers to share some of his supplies.",
      "You added 'Hunter's Supplies' to your inventory."
    ])
    add_to_inventory("Hunter's Supplies")
    @tui.pause
  end

  def hear_echoes
    @tui.draw_main([
      "You hear strange echoes in the cave.",
      "They seem to guide you to a hidden treasure.",
      "You added 'Echoing Gem' to your inventory."
    ])
    add_to_inventory("Echoing Gem")
    @tui.pause
  end

  def find_crystals
    
    @tui.draw_main([
      "You discover a cluster of glowing crystals in the cave.",
      "You added 'Glowing Crystals' to your inventory."
    ])
    add_to_inventory("Glowing Crystals")
    @tui.pause
  end

  # River unique events
  def catch_fish
    @tui.draw_main([
      "You catch a fish from the river. It looks delicious.",
      "You added 'Fresh Fish' to your inventory."
    ])
    add_to_inventory("Fresh Fish")
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
      add_to_inventory("Healing Potion")
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
        @tui.draw_main(["There are no puzzles available in this sub-area."])
        @tui.pause
      else
        puzzle = puzzles.sample
        solve_puzzle(puzzle.transform_keys(&:to_sym))
        return
      end
    else
      @tui.draw_main(["There is nothing interesting in this sub-area."])
      @tui.pause
    end
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
      add_to_inventory(boss[:reward])
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
        add_to_inventory(puzzle[:reward])
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
          add_to_inventory(item)
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
      @main_win.box("|", "-") # Add a border around the main window
      text_lines.each_with_index do |line, i|
        wrapped_lines = wrap_text(line.to_s, Curses.cols - 4) # Leave room for padding
        wrapped_lines.each_with_index do |wrapped_line, j|
          @main_win.setpos(i + j + 1, 2) # Add padding
          @main_win.addstr(wrapped_line)
        end
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
    
      InventoryUtils.compact_inventory(player.inventory).first(5).each_with_index do |item, i|
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
      @main_win.clrtoeol
      @main_win.addstr("Error: #{message}")
      @main_win.refresh
    end

    def pause
      @main_win.setpos(Curses.lines - 2, 2)
      @main_win.clrtoeol
      @main_win.addstr("Press Enter to continue...")
      @main_win.refresh
      @main_win.getstr
    end

    private

    # Helper method to wrap text to fit within a given width
    def wrap_text(text, width)
      text.scan(/.{1,#{width}}(?:\s+|$)|\S+/)
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
