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
$config.boss_drops = yaml_config['boss_drops'] # Load boss drops into the global config
$config.unique_items = yaml_config['unique_items']
$config.items = yaml_config['items']

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

    # Normalize the item name
    item_name = item.is_a?(Array) ? item[0] : item

    case item_name
    when /^Healing Potion$/i
      healed = player.heal(20)
      if healed == 0
        lines << "You are already at full health. You can't use a Healing Potion right now."
        return lines
      else
        lines << "You used a Healing Potion and restored #{healed} health."
      end
    when /^Fresh Fish$/i
      healed = player.heal(15)
      if healed == 0
        lines << "You are already at full health. You can't use Fresh Fish right now."
        return lines
      else
        lines << "You used Fresh Fish and restored #{healed} health."
      end
    when /^Medicinal Herbs$/i
      healed = player.heal(10)
      if healed == 0
        lines << "You are already at full health. You can't use Medicinal Herbs right now."
        return lines
      else
        lines << "You used Medicinal Herbs and restored #{healed} health."
      end
    when /^Golden Feather$/i
      healed = player.heal(15)
      if healed == 0 
        lines << "You are already at full health. You can't use Golden Feather right now."
        return lines
      else
        lines << "You used Golden Feather and restored #{healed} health."
      end
    when /^Ancient Relic$/i
      player.health += 20
      healed = player.heal(20)
      player.damage_bonus += 10
      lines << "The Ancient Relic radiates power, permanently increasing your health by #{healed} and damage bonus by 10."
    when /^Hunter's Supplies$/i
      player.damage_bonus += 5
      lines << "You used Hunter's Supplies and increased your damage bonus by 5."
    when /^Glowing Crystals$/i
      healed = player.heal(15)
      if healed == 0
        lines << "You are already at full health. You can't use Glowing Crystals right now."
        return lines
      else
        lines << "You used Glowing Crystals and restored #{healed} health."
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
      healed = player.heal(10)
      lines << "You drank the Elixir of Life, permanently increasing your health by #{healed}."
    else
      lines << "You can't use that item right now."
    end
    consume_item(player, item_name)
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
  attr_accessor :dot_effect, :allies, :boat_fixed

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
      dot_effect: @dot_effect,
      boat_fixed: @boat_fixed
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
    player.boat_fixed = data[:boat_fixed]
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
    @boat_fixed = false
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
  def apply_ally_bonus(ally, tui)
    case ally
    when "a wandering knight"
      @damage_bonus += 5
      BlockUtils.wrap_event(tui) do 
        [
        "The wandering knight sharpens your blade with expert technique.",
        "Your damage bonus increases by 5."
        ]
      end
    when "a wise mage"
      @health_bonus += 20
      healed = heal(20)
      BlockUtils.wrap_event(tui) do 
        [
        "The wise mage casts a powerful warding spell.",
        "Your max health increases by 20, and you heal #{healed} health."
        ]
      end
    when "a skilled archer"
      @damage_bonus += 10
      BlockUtils.wrap_event(tui) do 
        [
        "The skilled archer joins you, providing precision fire.",
        "Your damage bonus increases by 10."
        ]
      end
    when "a friendly merchant"
      @gold += 50
      BlockUtils.wrap_event(tui) do 
        [
        "The friendly merchant shares some of their earnings with you.",
        "You receive 50 gold."
        ]
      end
    when "a brave warrior"
      @damage_bonus += 15
      BlockUtils.wrap_event(tui) do 
        [
        "The brave warrior joins your ranks!",
        "The brave warrior increases your damage by 15."
        ]
      end
    else
      BlockUtils.wrap_event(tui) do 
        [
        "This ally doesn't provide any specific bonus yet."
        ]
      end
    end
  end

  def clamp_health
    @health = [@health, 0].max
  end

  def max_health
    $config.starting_health + health_bonus
  end

  def heal(amount)
    if health >= max_health
      0
    else
      healed = [amount, max_health - health].min
      self.health += healed
      healed
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
    if @player.health <= 0
      @player.clamp_health
      if InventoryUtils.find_item(@player, "Phoenix Feather")[1]
        InventoryUtils.consume_item(@player, "Phoenix Feather")
        @player.health = ($config.starting_health + @player.health_bonus) / 2
        BlockUtils.wrap_event(@tui) do 
          ["The Phoenix Feather activates and revives you with #{@player.health} health!"]
        end
      else
        BlockUtils.wrap_event(@tui) do 
          ["Your health has dropped below 0. You lose!"]
        end
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
          if @player.progress_flags[:river_repaired]
            @rooms[:river].directions["north"] = :village
          end
          BlockUtils.wrap_event(@tui) do 
            ["✅ Game loaded successfully!"]
          end
        else
          BlockUtils.wrap_event(@tui) do 
            [" Failed to load game."]
          end
          start  # Restart flow if load fails
        return
        end
      else
        BlockUtils.wrap_event(@tui) do 
          [" No saved game found. Starting a new game."]
        end
        get_player_name

      end
    else
      get_player_name
    end
    BlockUtils.wrap_event(@tui) do 
      ["Hello, #{@player.name}! Your adventure begins now."]
    end
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
      lines << "Options: direction / status / inventory / explore / boss / map / save / quit"
  
      @tui.draw_main(lines)
      @tui.draw_sidebar(@player)
      input = @tui.prompt("What would you like to do? ").downcase
      input = correct_input(input, @current_room.directions.keys + ["status", "inventory", "explore", "map", "boss", "save", "quit"])
  
      case input
      when "status"
        BlockUtils.wrap_event(@tui) do 
          [
          "#{@player.name}'s Status:",
          "Level: #{@player.level}",
          "Experience: #{@player.experience}/#{@player.experience_to_level_up}",
          "Health: #{@player.health}",
          "Damage Bonus: #{@player.damage_bonus}",
          "Gold: #{@player.gold}",
          "Inventory: #{InventoryUtils.compact_inventory(@player.inventory).join(', ')}",
          "Allies: #{@player.allies.join(', ')}"
          ]
        end
      when "inventory"
        check_inventory()
      when "explore"
        if @current_room.sub_areas.empty?
          BlockUtils.wrap_event(@tui) do 
            ["There are no sub-areas to explore here."]
          end
        else
          input = @tui.prompt("Enter sub-area to explore (#{@current_room.sub_areas.join(', ')}): ")
          input = correct_input(input, @current_room.sub_areas)
          if input && @current_room.sub_areas.map(&:downcase).include?(input.downcase)
            explore_sub_area(input)
          else
            BlockUtils.wrap_event(@tui) do 
              ["That sub-area does not exist."]
            end
          end
        end
      when "map"
        @tui.draw_map(@rooms.key(@current_room), @rooms[:river].directions.key?("north"))
        @tui.pause
      when "save"
        SaveSystem.save(@player, @rooms.key(@current_room))
        BlockUtils.wrap_event(@tui) do 
          ["✅ Game saved!"]
        end
      when "quit"
        
        BlockUtils.prompt_loop(@tui, "Do you want to save before quitting? (yes/no): ", valid: ["yes", "no"]) do |response|
          if response == "yes"
            SaveSystem.save(@player, @rooms.key(@current_room))
            BlockUtils.wrap_event(@tui) do 
              ["💾 Game saved."]
            end
          end
          BlockUtils.wrap_event(@tui) do 
             ["👋 Goodbye!"]
          end
          exit
        end
        exit
      when "boss"
        explore_boss_area if @current_room.boss_sub_area
      when *(@current_room.directions.keys)
        # Progression checks for specific areas
        if input == "north" && @current_room == @rooms[:river] && !@rooms[:river].directions.key?("north")
          BlockUtils.wrap_event(@tui) do 
            ["You cannot go north until you fix the boat on the riverbank."]
          end
        elsif input == "north" && @current_room == @rooms[:mountain] && !@rooms[:mountain].directions.key?("north")
          if InventoryUtils.find_item(@player, "Dragon Scale Armor")[1]
            BlockUtils.wrap_event(@tui) do 
              [
              "Wearing the Dragon Scale Armor, you feel protected from the harsh conditions.",
              "You can now proceed north to the mountain peak!"
              ]
            end
            @rooms[:mountain].directions["north"] = :peak
          else
            BlockUtils.wrap_event(@tui) do 
              ["You cannot go north until you defeat the Mountain Dragon and obtain the Dragon Scale Armor."]
            end
            next
          end
        elsif input == "east" && @current_room == @rooms[:village] && !@player.inventory.include?("Upgraded Weapon")
          BlockUtils.wrap_event(@tui) do 
            ["You cannot go east until you visit the blacksmith and upgrade your weapon."]
          end
        elsif input == "north" && @current_room == @rooms[:castle] && !@player.inventory.include?("Shadow Blade")
          BlockUtils.wrap_event(@tui) do 
            ["You cannot go north until you defeat the Dark Knight and obtain the Shadow Blade."]
          end
        else
          @current_room = @rooms[@current_room.directions[input]]
          random_event
        end
      else
        BlockUtils.wrap_event(@tui) do 
          ["You can't go that way."]
        end
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
      BlockUtils.wrap_event(@tui) do 
        ["Your inventory is empty!"]
      end
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
          BlockUtils.wrap_event(@tui) do 
            InventoryUtils.use_item(@player, item, enemies, context)
          end
        else
          BlockUtils.wrap_event(@tui) do 
            ["You don't have that item."]
          end
        end
      end
    end
  end

  def display_item_help
    lines = ["Item Descriptions:"]
    @player.inventory.each do |item|
      # Extract the item name if it's an array, otherwise use the item directly
      item_name = item.is_a?(Array) ? item[0] : item

      # Fetch description from the YAML configuration
      if $config.items.key?(item_name)
        desc = $config.items[item_name]['description']
      elsif $config.boss_drops.key?(item_name)
        desc = $config.boss_drops[item_name]['description']
      elsif $config.unique_items&.any? { |unique_item| unique_item['name'] == item_name }
        unique_item = $config.unique_items.find { |unique_item| unique_item['name'] == item_name }
        desc = unique_item['effect']
      else
        desc = "No description available."
      end

      lines << "- #{item_name}: #{desc}"
    end
    BlockUtils.wrap_event(@tui) do 
      lines
    end
    @tui.draw_sidebar(@player)
  end

  def find_treasure
    if $config.treasure_items.nil? || !$config.treasure_items.any?
      BlockUtils.wrap_event(@tui) do 
        ["Error: No treasure items configured."]
      end
      return
    end
    treasure = $config.treasure_items.sample
    add_to_inventory(treasure)
    BlockUtils.wrap_event(@tui) do 
      [
      "You stumble upon a hidden treasure!",
      "You found a treasure: #{treasure}!"
      ]
    end
  end





  def encounter_enemy
    enemy_data = $config.enemy_types
    if enemy_data.nil? || !enemy_data.sample.is_a?(Hash)
      BlockUtils.wrap_event(@tui) do 
        ["Error: Invalid enemy data."]
      end
      return
    end
    enemy_data = $config.enemy_types.sample

    enemy = Enemy.new(
      enemy_data["name"] || "Unknown",
      enemy_data["health"] || 10,
      enemy_data["damage"] || 5,
      enemy_data["ability"] || "None",
      enemy_data["description"] || "No description."
    )
  
    loop do
      BlockUtils.combat_round(@tui) do
        draw_combat_ui(enemy)
        player_turn(enemy)
      end
      break if enemy.health <= 0
  
      enemy_turn(enemy)
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
        BlockUtils.wrap_event(@tui) do
          lines
        end
        break
      when "2"
        if @player.inventory.empty?
          input = @tui.prompt("You have no items to use, choose another action: ")
        else
          item = @tui.prompt("Enter item name to use:")
          if InventoryUtils.find_item(@player, item)[1]
            BlockUtils.wrap_event(@tui) do
              InventoryUtils.use_item(@player, item, enemy, :combat)
            end
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

    BlockUtils.wrap_event(@tui) do 
      lines
    end
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
      lines << "Congratulations! You leveled up to Level #{@player.level}!"
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
  
    BlockUtils.wrap_event(@tui) do 
      lines
    end
    @tui.draw_sidebar(@player)
  end

  def find_ally
    possible_allies = $config.ally_types
    new_ally = (possible_allies - @player.allies).sample
  
    if new_ally.nil?
      BlockUtils.wrap_event(@tui) do 
        ["You’ve already recruited all available allies."]
      end
      return
    end
  
    BlockUtils.wrap_event(@tui) do 
      [
      "You encounter a potential ally!",
      "You found an ally: #{new_ally}!"
      ]
    end
  
    response = @tui.prompt("Would you like this ally to join your party? (yes/no): ").downcase
    if response == "yes"
      @player.allies << new_ally
      @player.apply_ally_bonus(new_ally, @tui)
    else
      BlockUtils.wrap_event(@tui) do 
        ["You decided not to let #{new_ally} join your party."]
      end
    end
  end

  def discover_mystery
    BlockUtils.wrap_event(@tui) do 
      [
      "You stumble upon something mysterious!",
      "You discovered a mysterious object. It glows faintly but does nothing... for now."
      ]
    end
  end

  def encounter_trap
    damage = rand(10..30)
    @player.health -= damage
    BlockUtils.wrap_event(@tui) do 
      ["You triggered a trap and lost #{damage} health!"]
    end
    check_loss
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
    BlockUtils.wrap_event(@tui) do 
      [
      "You find an eagle's nest with a shiny object inside.",
      "You added 'Golden Feather' to your inventory."
      ]
    end
    add_to_inventory("Golden Feather")
  end

  def trigger_rockslide
    damage = rand(10..20)
    BlockUtils.wrap_event(@tui) do 
      [
      "You accidentally trigger a rockslide! You barely escape but lose some health.",
      "You lost #{damage} health."
      ]
    end
    @player.health -= damage
    check_loss
  end

  # Village unique events
  def visit_blacksmith
    BlockUtils.wrap_event(@tui) do 
      [
      "You visit the blacksmith, who offers to upgrade your weapon.", 
      "Your damage bonus increased by 5."
      ]
    end
    @player.damage_bonus += 5
  end

  def talk_to_elder
    BlockUtils.wrap_event(@tui) do 
      [
      "You talk to the village elder, who shares ancient wisdom with you.", 
      "Your health bonus increased by 10."
      ]
    end
    @player.health_bonus += 10
  end

  # Castle unique events
  def find_treasure_chest
    BlockUtils.wrap_event(@tui) do 
      [
      "You find a hidden treasure chest filled with gold and jewels.",
      "You gained 50 gold!"
      ]
    end
    @player.gold += 50 
  end

  def meet_royal_guard
    BlockUtils.wrap_event(@tui) do 
      [
      "You meet a royal guard who challenges you to a duel."
      ]
    end
    encounter_enemy
  end

  # Peak unique events
  def find_ancient_relic
    BlockUtils.wrap_event(@tui) do 
      [
      "You discover an ancient relic that radiates power.",
      "You added 'Ancient Relic' to your inventory."
      ]
    end
    add_to_inventory("Ancient Relic")
  end

  def encounter_lightning_storm
    damage = rand(15..30)
    BlockUtils.wrap_event(@tui) do 
      [
      "A sudden lightning storm strikes! You take damage but feel energized.",
      "You lost #{damage} health but gained 5 damage bonus."
      ]
    end
    @player.health -= damage
    @player.damage_bonus += 5
    check_loss
  end

  # Throne Room unique events
  def find_royal_secrets
    BlockUtils.wrap_event(@tui) do 
      [
      "You uncover royal secrets hidden in the throne room.",
      "You added 'Royal Secrets' to your inventory."
      ]
    end
    add_to_inventory("Royal Secrets")
  end

  def activate_trap
    damage = rand(20..40)
    BlockUtils.wrap_event(@tui) do 
      [
      "You accidentally activate a trap! Poisonous gas fills the room.",
      "You lost #{damage} health!"
      ]
    end
    @player.health -= damage
    check_loss
  end

  # Forest unique events
  def find_herbs
    BlockUtils.wrap_event(@tui) do 
      [
      "You find some medicinal herbs growing in the forest.",
      "You added 'Medicinal Herbs' to your inventory."
      ]
    end
    add_to_inventory("Medicinal Herbs")
  end

  def meet_hunter
    BlockUtils.wrap_event(@tui) do 
      [
      "You meet a hunter who offers to share some of his supplies.",
      "You added 'Hunter's Supplies' to your inventory."
      ]
    end
    add_to_inventory("Hunter's Supplies")
  end

  def hear_echoes
    BlockUtils.wrap_event(@tui) do 
      [
      "You hear strange echoes in the cave.",
      "They seem to guide you to a hidden treasure.",
      "You added 'Echoing Gem' to your inventory."
      ]
    end
    add_to_inventory("Echoing Gem")
  end

  def find_crystals
    
    BlockUtils.wrap_event(@tui) do 
      [
      "You discover a cluster of glowing crystals in the cave.",
      "You added 'Glowing Crystals' to your inventory."
      ]
    end
    add_to_inventory("Glowing Crystals")
  end

  # River unique events
  def catch_fish
    BlockUtils.wrap_event(@tui) do 
      [
      "You catch a fish from the river. It looks delicious.",
      "You added 'Fresh Fish' to your inventory."
      ]
    end
    add_to_inventory("Fresh Fish")
  end

  def explore_sub_area(sub_area)
    case sub_area.downcase
    when "store"
      store
    when "village square"
      BlockUtils.wrap_event(@tui) do 
        [
        "You explore the village square and meet friendly villagers.",
        "The villagers give you 10 gold as a gift!"
        ]
      end
      @player.gold += 10
    when "riverbank"
      if InventoryUtils.find_item(@player, "Repair Kit")[1]
        BlockUtils.wrap_event(@tui) do 
          [
          "You find a broken boat at the riverbank.",
          "Using the Repair Kit, you fix the boat!",
          "The Repair Kit has been used up."
          ]
        end
        InventoryUtils.consume_item(@player, "Repair Kit")
        @rooms[:river].directions["north"] = :village
        @player.boat_fixed = true
    
        response = @tui.prompt("Do you want to travel north across the river? (yes/no): ").downcase
        if response == "yes"
          @current_room = @rooms[:village]
          BlockUtils.wrap_event(@tui) do 
            [
            "You travel north across the river and arrive at the village."
            ]
          end
          random_event
        else
          BlockUtils.wrap_event(@tui) do 
            [
            "You decide to stay at the riverbank for now."
            ]
          end
        end
      else
        BlockUtils.wrap_event(@tui) do 
          [
          "You find a broken boat at the riverbank, but you need a Repair Kit to fix it."
          ]
        end
      end    
    when "clearing"
      BlockUtils.wrap_event(@tui) do 
        [
        "You explore the clearing and find a hidden chest.",
        "You added 'Healing Potion' to your inventory."
        ]
      end
      add_to_inventory("Healing Potion")
    when "dense thicket"
      BlockUtils.wrap_event(@tui) do 
        [
        "You push through the dense thicket and encounter an enemy!"
        ]
      end
      encounter_enemy
      return
    when "hidden grove", "crystal chamber", "echoing hall", "castle library", "peak shrine"
      puzzles = $config.puzzles[sub_area.downcase.gsub(" ", "_")]
      if puzzles.nil? || puzzles.empty?
        BlockUtils.wrap_event(@tui) do 
          ["There are no puzzles available in this sub-area."]
        end
      else
        puzzle = puzzles.sample
        solve_puzzle(puzzle.transform_keys(&:to_sym))
        return
      end
    else
      BlockUtils.wrap_event(@tui) do 
        ["There is nothing interesting in this sub-area."]
      end
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
      BlockUtils.wrap_event(@tui) do 
        ["You decide not to enter the boss area for now."]
      end
    end
  end

  def encounter_boss(boss)

    enemy = Enemy.new(boss[:name], boss[:health], 15, "Special Attack", "The boss looms over you with immense power.")
    BlockUtils.wrap_event(@tui) do 
      [
      "The wind howls as you enter...",
      "A shadow looms... it's #{boss[:name]}!",
      "#{boss[:name]}: #{enemy.description}"
      ]
    end

    loop do
      BlockUtils.combat_round(@tui) do
        draw_combat_ui(enemy)
        player_turn(enemy)
        check_loss
      end
      break if enemy.health <= 0
  
      enemy_turn(enemy)
      check_loss
  
    end
  
    if enemy.health <= 0
      add_to_inventory(boss[:reward])
      BlockUtils.wrap_event(@tui) do 
        [
        "🏆 You defeated the boss: #{enemy.type}!",
        "You gained the reward: #{boss[:reward]}!"
        ]
      end
    end
  end

  def solve_puzzle(puzzle)
    if puzzle[:question].nil? || puzzle[:options].nil? || !puzzle[:options].is_a?(Array)
      BlockUtils.wrap_event(@tui) do 
        ["  Error: Invalid puzzle data. Skipping puzzle."]
      end
      return
    end
  
    lines = []
    lines << "🧠 Puzzle Challenge!"
    lines << "-" * 40
  
    # Split the question into multiple lines if it contains newline characters
    puzzle[:question].split("\n").each { |line| lines << line }
    lines << ""
  
    puzzle[:options].each_with_index do |option, index|
      lines << "#{index + 1}. #{option}"
    end
  
    lines << ""
    lines << "Choose the correct answer (1-#{puzzle[:options].size})"
  
    BlockUtils.wrap_event(@tui) do 
      lines
    end
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
        if reward[:health]
          healed = @player.heal(reward[:health])
          reward_text << "You healed #{healed} health." if healed > 0
        end
        @player.damage_bonus += reward[:damage_bonus] if reward[:damage_bonus]
        reward_text << "Your stats have improved!"
      end
  
      BlockUtils.wrap_event(@tui) do 
        reward_text
      end
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
      BlockUtils.wrap_event(@tui) do 
        penalty_text
      end
    end
  
    # Add a pause after displaying the result
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
      lines << "Welcome to the Store!"
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
        BlockUtils.wrap_event(@tui) do 
          ["Thank you for visiting the store!"]
        end
        break
      elsif choice.between?(1, store_items.size)
        item, price = store_items.to_a[choice - 1]
        if @player.gold >= price
          @player.gold -= price
          add_to_inventory(item)
          BlockUtils.wrap_event(@tui) do 
            [
            "✅ You purchased #{item} for #{price} gold.",
            "Remaining gold: #{@player.gold}."
            ]
          end
        else
          BlockUtils.wrap_event(@tui) do 
            [
            "❌ You don't have enough gold for #{item}!",
            "You have #{@player.gold}, but need #{price}."
            ]
          end
        end
      else
        BlockUtils.wrap_event(@tui) do 
          ["Invalid choice. Please enter a number between 1 and #{store_items.size + 1}."]
        end
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
      @side_win = Curses::Window.new(Curses.lines, 30, 0, Curses.cols - 30)
    end

    def close
      Curses.close_screen
    end

    def draw_main(text_lines)
      @main_win.clear
      @main_win.box("|", "-")
      text_lines.each_with_index do |line, i|
        wrapped_lines = wrap_text(line.to_s, Curses.cols - 4)
        wrapped_lines.each_with_index do |wrapped_line, j|
          @main_win.setpos(i + j + 1, 2)
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

    def draw_map(current_room_key, show_village_path)
      row_0 = "|======= You are currently at the #{current_room_key} =======|"
      row_1 = "          [Peak]"
      row_2 = "            |"
      row_3 = "        [Mountain] -- [Cave]"
      row_4 = "                        |"
      row_5 = "                     [Forest] -- [River]"
    
      if show_village_path
        row_1 += "                           [Throne Room]"
        row_2 += "                                   |"
        row_3 += "    [Village] -- [Castle]"
        row_4 += "           |"
      end
    
      lines = [row_0, row_1, row_2, row_3, row_4, row_5]
    
      names = {
        peak:         "[Peak]",
        mountain:     "[Mountain]",
        cave:         "[Cave]",
        forest:       "[Forest]",
        river:        "[River]",
        village:      "[Village]",
        castle:       "[Castle]",
        throne_room:  "[Throne Room]"
      }
    
      current_label = names[current_room_key]

      lines.map! do |line|
        case current_label
        when "[Peak]"
          line.gsub("[Peak]", "⭐[You]")
        when "[Mountain]"
          line.gsub("[Mountain]", " ⭐[You]")
        when "[Cave]"
          line.gsub("[Cave]", "⭐[You]")
        when "[Forest]"
          line.gsub("[Forest]", " ⭐[You] ")
        when "[River]"
          line.gsub("[River]", "⭐[You] ")
        when "[Village]"
          line.gsub("[Village]", " ⭐[You]  ")
        when "[Castle]"
          line.gsub("[Castle]", " ⭐[You] ")
        when "[Throne Room]"
          line.gsub("[Throne Room]", "   ⭐[You]    ")
        else
          line
        end
      end
    
      lines << ""
      lines << "⭐[You] = You Are Here"
      draw_main(lines)
    end


    def prompt(message = ">> ")
      Curses.echo
      @main_win.setpos(Curses.lines - 2, 2)
      @main_win.clrtoeol
      @main_win.addstr(message)
      @main_win.refresh
      input = @main_win.getstr.strip
      Curses.noecho
      yield(input) if block_given?
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

    def wrap_text(text, width)
      text.scan(/.{1,#{width}}(?:\s+|$)|\S+/)
    end
  end
end

# Utility to simplify event flow with drawing and pausing, used to make blocking easier
module BlockUtils
  def self.wrap_event(tui)
    lines = yield
    tui.draw_main(lines)
    tui.pause
  end

  def self.combat_round(tui)
    yield if block_given?
  end

  def self.prompt_loop(tui, message, valid: nil, error: "Invalid input.", &block)
    loop do
      input = tui.prompt(message).strip.downcase
      if valid.nil? || valid.include?(input)
        return yield(input)
      else
        tui.draw_main([error])
        tui.pause
      end
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
