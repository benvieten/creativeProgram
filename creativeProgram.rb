require 'yaml'

# Load the YAML library to handle configuration files.
# YAML is used to store game settings in an external file.

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

  def self.pause
    puts "\nPress Enter to continue..."
    gets
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
  def initialize
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
        GameUtils.pause
        exit
      end
    end
  end

  def start
    GameUtils.clear_screen
    puts "Welcome to the Adventure Game!"

    player_name = ""
    loop do
      print "Enter your name: "
      player_name = gets.chomp.strip
      puts "Name cannot be empty. Please enter a valid name." if player_name.empty?
      break unless player_name.empty?
    end

    @player = Player.new(player_name)
    setup_rooms
    GameUtils.clear_screen
    puts "Hello, #{@player.name}! Your adventure begins now."
    GameUtils.pause
    explore_room
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
      GameUtils.clear_screen
      @current_room.display
      puts "\nOptions:"
      puts "- Type a direction to explore (e.g., 'north', 'east')."
      puts "- Type 'status' to check your current status."
      puts "- Type 'inventory' to check your inventory and use items."
      puts "- Type 'explore' to explore a sub-area."
      puts "- Type 'boss' to enter the boss area." if @current_room.boss_sub_area
      print "\nWhat would you like to do? "

      input = gets.chomp.downcase
      if input == "status"
        GameUtils.clear_screen
        @player.display_status
        GameUtils.pause
      elsif input == "inventory"
        check_inventory
      elsif input == "explore"
        if @current_room.sub_areas.empty?
          puts "There are no sub-areas to explore here."
          GameUtils.pause
        else
          puts "Sub-areas available: #{@current_room.sub_areas.join(', ')}"
          print "Enter the name of the sub-area you want to explore: "
          sub_area = gets.chomp
          if @current_room.sub_areas.map(&:downcase).include?(sub_area.downcase)
            explore_sub_area(sub_area)
          else
            puts "That sub-area does not exist."
            GameUtils.pause
          end
        end
      elsif input == "boss" && @current_room.boss_sub_area
        explore_boss_area
      elsif input == "north" && @current_room == @rooms[:river] && !@rooms[:river].directions.key?("north")
        puts "You cannot go north until you fix the boat on the riverbank."
        GameUtils.pause
      elsif @current_room.directions.key?(input)
        @current_room = @rooms[@current_room.directions[input]]
        random_event
      else
        puts "You can't go that way."
        GameUtils.pause
      end
    end
  end

  def check_inventory
    if @player.inventory.empty?
      puts "Your inventory is empty!"
    else
      puts "Your inventory: #{@player.inventory.join(', ')}"
      print "Enter the name of the item you want to use, type 'help' to see item descriptions, or type 'back' to return: "
      input = gets.chomp.strip
      if input.downcase == "back"
        # do nothing extra
      elsif input.downcase == "help"
        display_item_help
      else
        item = @player.inventory.find { |i| i.downcase == input.downcase }
        if item
          InventoryUtils.use_item(@player, item)
        else
          puts "You don't have that item!"
        end
      end
    end
    GameUtils.pause
  end

  def display_item_help
    puts "\nItem Descriptions:"
    @player.inventory.each do |item|
      case item
      when "Healing Potion"
        puts "- Healing Potion: Restores 20 health when used."
      when "Fresh Fish"
        puts "- Fresh Fish: Restores 15 health when eaten."
      when "Medicinal Herbs"
        puts "- Medicinal Herbs: Restores 10 health when used."
      when "Golden Feather"
        puts "- Golden Feather: Restores 15 health and glows faintly."
      when "Ancient Relic"
        puts "- Ancient Relic: Permanently increases health by 20 and damage bonus by 10."
      when "Hunter's Supplies"
        puts "- Hunter's Supplies: Increases your damage bonus by 5."
      when "Glowing Crystals"
        puts "- Glowing Crystals: Increases your health by 15."
      when "Echoing Gem"
        puts "- Echoing Gem: Increases your damage bonus by 10."
      when "Small Boat"
        puts "- Small Boat: Allows you to cross rivers without penalty."
      when "Royal Secrets"
        puts "- Royal Secrets: May unlock hidden events later."
      when "Silver Sword"
        puts "- Silver Sword: Increases your damage bonus by 10."
      when "Magic Scroll"
        puts "- Magic Scroll: Casts a powerful spell to deal 30 damage to an enemy."
      when "Ruby Gem"
        puts "- Ruby Gem: Increases gold earned from battles by 20%."
      when "Enchanted Amulet"
        puts "- Enchanted Amulet: Reduces damage taken by 5."
      when "Phoenix Feather"
        puts "- Phoenix Feather: Revives you with 50% health upon defeat."
      when "Elixir of Life"
        puts "- Elixir of Life: Permanently increases health by 10."
      else
        puts "- #{item}: No description available."
      end
    end
  end

  def find_treasure
    puts "\nYou stumble upon a hidden treasure!"
    treasure = $config.treasure_items.sample
    @player.inventory << treasure
    puts "You found a treasure: #{treasure}!"
    GameUtils.pause
  end

  def encounter_enemy
    puts "\nYou hear a rustling sound... An enemy appears!"
    enemy_data = $config.enemy_types.sample
    if enemy_data.nil? || !enemy_data.is_a?(Hash) || enemy_data.values.any?(&:nil?)
      puts "Error: Invalid enemy data. Skipping encounter."
      GameUtils.pause
      return
    end

    enemy = Enemy.new(
      enemy_data["name"] || "Unknown",
      enemy_data["health"] || 10,
      enemy_data["damage"] || 5,
      enemy_data["ability"] || "None",
      enemy_data["description"] || "No description available."
    )

    puts "You encountered an enemy: #{enemy.type}!"
    puts "#{enemy.description}"
    puts "#{enemy.type} has #{enemy.health} health and can use the ability: #{enemy.ability}."
    
    while enemy.health > 0 && @player.health > 0
      CombatUtils.process_damage_over_time(@player)
      CombatUtils.process_damage_over_time(enemy)

      loop do
        puts "\nYour turn!"
        puts "Options:"
        puts "1. Attack"
        puts "2. Use an item"
        puts "3. Check inventory (does not waste a turn)"
        print "Choose an action (1, 2, or 3): "
        action = gets.chomp

        if action == "1"
          damage_to_enemy = CombatUtils.calculate_damage(10, @player.damage_bonus)
          damage_to_enemy ||= 0
          damage_to_enemy = CombatUtils.apply_damage_reduction(damage_to_enemy, 50) if enemy.ability == "Stone Skin"
          enemy.health -= damage_to_enemy
          puts "You attack the #{enemy.type} and deal #{damage_to_enemy} damage!"
          puts "#{enemy.type} has #{[enemy.health, 0].max} health remaining."
          break
        elsif action == "2"
          if @player.inventory.empty?
            puts "You have no items in your inventory!"
          else
            puts "Your inventory: #{@player.inventory.join(', ')}"
            print "Enter the name of the item you want to use: "
            item = gets.chomp
            if @player.inventory.include?(item)
              InventoryUtils.use_item(@player, item, enemy)
              break
            else
              puts "You don't have that item!"
            end
          end
        elsif action == "3"
          puts "Your inventory: #{@player.inventory.join(', ')}"
          puts "Health: #{@player.health}, Damage Bonus: #{@player.damage_bonus}"
        else
          puts "Invalid action. Please choose a valid option."
        end
      end

      check_loss

      if enemy.health <= 0
        puts "You defeated the #{enemy.type}!"
        puts "You gain some experience and loot!"
        experience_gained = case enemy.type
                            when "goblin", "bandit" then 50
                            when "orc", "troll" then 100
                            else 150
                            end
        @player.gain_experience(experience_gained)
        gold_dropped = case enemy.type
                       when "goblin", "bandit" then rand(10..20)
                       when "orc", "troll" then rand(20..40)
                       else rand(40..60)
                       end
        @player.gold += gold_dropped
        puts "The #{enemy.type} dropped #{gold_dropped} gold!"
        if rand < 0.3
          item_dropped = $config.treasure_items.sample
          @player.inventory << item_dropped
          puts "The #{enemy.type} dropped an item: #{item_dropped}!"
        end
        GameUtils.pause
        return
      end

      puts "\nThe #{enemy.type}'s turn!"
      damage_to_player = CombatUtils.calculate_damage(enemy.damage, 0)
      @player.health -= damage_to_player
      puts "The #{enemy.type} attacks you and deals #{damage_to_player} damage!"
      puts "You have #{[0, @player.health].max} health remaining."

      check_loss
    end
    GameUtils.pause
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
    GameUtils.pause
  end

  def discover_mystery
    puts "\nYou stumble upon something mysterious!"
    puts "You discovered a mysterious object. It glows faintly but does nothing... for now."
    GameUtils.pause
  end

  def encounter_trap
    damage = rand(10..30)
    @player.health -= damage
    puts "You triggered a trap and lost #{damage} health!"
    check_loss
    GameUtils.pause
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
    puts "You find an eagle's nest with a shiny object inside."
    @player.inventory << "Golden Feather"
    puts "You added 'Golden Feather' to your inventory."
    GameUtils.pause
  end

  def trigger_rockslide
    puts "You accidentally trigger a rockslide! You barely escape but lose some health."
    damage = rand(10..20)
    @player.health -= damage
    puts "You lost #{damage} health."
    check_loss
    GameUtils.pause
  end

  # Village unique events
  def visit_blacksmith
    puts "You visit the blacksmith, who offers to upgrade your weapon."
    @player.damage_bonus += 5
    puts "Your damage bonus increased by 5."
    GameUtils.pause
  end

  def talk_to_elder
    puts "You talk to the village elder, who shares ancient wisdom with you."
    @player.health_bonus += 10
    puts "Your health bonus increased by 10."
    GameUtils.pause
  end

  # Castle unique events
  def find_treasure_chest
    puts "You find a hidden treasure chest filled with gold and jewels."
    @player.gold += 50
    puts "You gained 50 gold!"
    GameUtils.pause
  end

  def meet_royal_guard
    puts "You meet a royal guard who challenges you to a duel."
    encounter_enemy
  end

  # Peak unique events
  def find_ancient_relic
    puts "You discover an ancient relic that radiates power."
    @player.inventory << "Ancient Relic"
    puts "You added 'Ancient Relic' to your inventory."
    GameUtils.pause
  end

  def encounter_lightning_storm
    puts "A sudden lightning storm strikes! You take damage but feel energized."
    damage = rand(15..30)
    @player.health -= damage
    @player.damage_bonus += 5
    puts "You lost #{damage} health but gained 5 damage bonus."
    check_loss
    GameUtils.pause
  end

  # Throne Room unique events
  def find_royal_secrets
    puts "You uncover royal secrets hidden in the throne room."
    @player.inventory << "Royal Secrets"
    puts "You added 'Royal Secrets' to your inventory."
    GameUtils.pause
  end

  def activate_trap
    puts "You accidentally activate a trap! Poisonous gas fills the room."
    damage = rand(20..40)
    @player.health -= damage
    puts "You lost #{damage} health!"
    check_loss
    GameUtils.pause
  end

  # Forest unique events
  def find_herbs
    puts "You find some medicinal herbs growing in the forest."
    @player.inventory << "Medicinal Herbs"
    puts "You added 'Medicinal Herbs' to your inventory."
    GameUtils.pause
  end

  def meet_hunter
    puts "You meet a hunter who offers to share some of his supplies."
    @player.inventory << "Hunter's Supplies"
    puts "You added 'Hunter's Supplies' to your inventory."
    GameUtils.pause
  end

  def hear_echoes
    puts "You hear strange echoes in the cave. They seem to guide you to a hidden treasure."
    @player.inventory << "Echoing Gem"
    puts "You added 'Echoing Gem' to your inventory."
    GameUtils.pause
  end

  def find_crystals
    puts "You discover a cluster of glowing crystals in the cave."
    @player.inventory << "Glowing Crystals"
    puts "You added 'Glowing Crystals' to your inventory."
    GameUtils.pause
  end

  # River unique events
  def catch_fish
    puts "You catch a fish from the river. It looks delicious."
    @player.inventory << "Fresh Fish"
    puts "You added 'Fresh Fish' to your inventory."
    GameUtils.pause
  end

  def explore_sub_area(sub_area)
    case sub_area.downcase
    when "store"
      store
    when "village square"
      puts "You explore the village square and meet friendly villagers."
      @player.gold += 10
      puts "The villagers give you 10 gold as a gift!"
    when "riverbank"
      if @player.inventory.include?("Repair Kit")
        puts "You find a broken boat at the riverbank."
        puts "Using the Repair Kit, you fix the boat and can now cross the river!"
        @rooms[:river].directions["north"] = :village
        @player.inventory.delete("Repair Kit")
        puts "The Repair Kit has been used up."
      else
        puts "You find a broken boat at the riverbank, but you need a Repair Kit to fix it."
      end
    when "clearing"
      puts "You explore the clearing and find a hidden chest."
      @player.inventory << "Healing Potion"
      puts "You added 'Healing Potion' to your inventory."
    when "dense thicket"
      puts "You push through the dense thicket and encounter a wild boar!"
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
    GameUtils.pause
  end

  def explore_boss_area
    if @current_room.boss.nil?
      puts "There is no boss in this area."
      GameUtils.pause
      return
    end

    boss = @current_room.boss
    puts "\nWARNING: You are about to enter the boss area: #{boss[:name]}!"
    puts "This will be a difficult battle. Make sure you are prepared."
    print "Do you want to enter? (yes/no): "
    input = gets.chomp.downcase

    if input == "yes"
      puts "\nYou enter the boss area and prepare for battle!"
      encounter_boss(boss)
    else
      puts "You decide not to enter the boss area for now."
    end
  end

  def encounter_boss(boss)
    puts "\nYou face the boss: #{boss[:name]}!"
    puts "#{boss[:name]} has #{boss[:health]} health."
    enemy = Enemy.new(boss[:name], boss[:health], 15, "Special Attack", "The boss looms over you with immense power.")
    
    while enemy.health > 0 && @player.health > 0
      CombatUtils.process_damage_over_time(@player)
      CombatUtils.process_damage_over_time(enemy)

      loop do
        puts "\nYour turn!"
        puts "Options:"
        puts "1. Attack"
        puts "2. Use an item"
        puts "3. Check inventory (does not waste a turn)"
        print "Choose an action (1, 2, or 3): "
        action = gets.chomp

        if action == "1"
          damage_to_enemy = CombatUtils.calculate_damage(10, @player.damage_bonus)
          damage_to_enemy ||= 0
          enemy.health -= damage_to_enemy
          puts "You attack the #{enemy.type} and deal #{damage_to_enemy} damage!"
          puts "#{enemy.type} has #{[enemy.health, 0].max} health remaining."
          break
        elsif action == "2"
          if @player.inventory.empty?
            puts "You have no items in your inventory!"
          else
            puts "Your inventory: #{@player.inventory.join(', ')}"
            print "Enter the name of the item you want to use: "
            item = gets.chomp
            if @player.inventory.include?(item)
              InventoryUtils.use_item(@player, item, enemy)
              break
            else
              puts "You don't have that item!"
            end
          end
        elsif action == "3"
          puts "Your inventory: #{@player.inventory.join(', ')}"
          puts "Health: #{@player.health}, Damage Bonus: #{@player.damage_bonus}"
        else
          puts "Invalid action. Please choose a valid option."
        end
      end

      check_loss

      if enemy.health <= 0
        puts "You defeated the boss: #{enemy.type}!"
        puts "You gain the reward: #{boss[:reward]}!"
        @player.inventory << boss[:reward]
        GameUtils.pause
        return
      end

      puts "\nThe #{enemy.type}'s turn!"
      damage_to_player = CombatUtils.calculate_damage(enemy.damage, 0)
      @player.health -= damage_to_player
      puts "The #{enemy.type} attacks you and deals #{damage_to_player} damage!"
      puts "You have #{[0, @player.health].max} health remaining."

      check_loss
    end
    GameUtils.pause
  end

  def solve_puzzle(puzzle)
    if puzzle[:question].nil? || puzzle[:options].nil? || !puzzle[:options].is_a?(Array)
      puts "Error: The puzzle data is incomplete or invalid. Skipping this puzzle."
      GameUtils.pause
      return
    end

    puts "\nPuzzle: #{puzzle[:question]}"
    puzzle[:options].each_with_index do |option, index|
      puts "#{index + 1}. #{option}"
    end

    print "Enter the number of your answer: "
    answer = gets.chomp.to_i

    if puzzle[:correct_answer] == answer
      puts "\nCorrect! #{puzzle[:reward_message]}"
      case puzzle[:reward_type]
      when :item
        @player.inventory << puzzle[:reward]
        puts "You received: #{puzzle[:reward]}!"
      when :gold
        @player.gold += puzzle[:reward]
        puts "You received #{puzzle[:reward]} gold!"
      when :stat
        @player.health += puzzle[:reward][:health] if puzzle[:reward][:health]
        @player.damage_bonus += puzzle[:reward][:damage_bonus] if puzzle[:reward][:damage_bonus]
        puts "Your stats have been improved!"
      end
    else
      puts "\nIncorrect! #{puzzle[:penalty_message]}"
      case puzzle[:penalty_type]
      when :health
        @player.health -= puzzle[:penalty]
        puts "You lost #{puzzle[:penalty]} health!"
      when :gold
        @player.gold -= puzzle[:penalty]
        @player.gold = 0 if @player.gold < 0
        puts "You lost #{puzzle[:penalty]} gold!"
      when :item
        if @player.inventory.include?(puzzle[:penalty])
          @player.inventory.delete(puzzle[:penalty])
          puts "You lost the item: #{puzzle[:penalty]}!"
        else
          puts "You had no items to lose."
        end
      end
    end
    check_loss
    GameUtils.pause
  end

  def store
    GameUtils.clear_screen
    puts "Welcome to the store! Here are the items available for purchase:"
    store_items = {
      "Medicinal Herbs" => 10,
      "Healing Potion" => 20,
      "Hunter's Supplies" => 15,
      "Golden Feather" => 50
    }

    store_items.each_with_index do |(item, price), index|
      puts "#{index + 1}. #{item} - #{price} gold"
    end
    puts "5. Exit the store"

    loop do
      print "\nEnter the number of the item you want to buy (or type '5' to exit): "
      choice = gets.chomp.to_i

      if choice == 5
        puts "Thank you for visiting the store!"
        break
      elsif choice.between?(1, store_items.size)
        item, price = store_items.to_a[choice - 1]
        if @player.gold >= price
          @player.gold -= price
          @player.inventory << item
          puts "You purchased #{item} for #{price} gold. Remaining gold: #{@player.gold}."
        else
          puts "You don't have enough gold to buy #{item}."
        end
      else
        puts "Invalid choice. Please select a valid option."
      end
    end
    GameUtils.pause
  end
end

# Start the game
game = Game.new
game.start
