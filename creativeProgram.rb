require 'yaml'

# The `require 'yaml'` statement loads the YAML library, which allows the program to parse YAML files.
# YAML is used here to load game configuration data from an external file.

# Define a class for game configuration using a DSL
class GameConfig
    def initialize
        @settings = {}
    end

    # `method_missing` is a Ruby metaprogramming feature that intercepts calls to undefined methods.
    # Here, it dynamically handles setting and getting configuration values.
    def method_missing(name, *args)
        if name.to_s.end_with?('=')
            # If the method ends with '=', treat it as a setter and store the value in the @settings hash.
            @settings[name.to_s.chomp('=').to_sym] = args.first
        else
            # Otherwise, treat it as a getter and return the value from the @settings hash.
            @settings[name]
        end
    end

    # `respond_to_missing?` is used to make `method_missing` compatible with `respond_to?`.
    # It ensures that the object behaves as if it has the dynamically defined methods.
    def respond_to_missing?(name, include_private = false)
        true
    end

    def settings
        @settings
    end
end

# Load game configuration from YAML file
config_file = '/Users/benvieten/Documents/csci324/creativeProgram/config.yml'
yaml_config = YAML.load_file(config_file)['game']
# `YAML.load_file` reads the YAML file and parses it into a Ruby hash.
# The `['game']` key accesses the specific section of the YAML file.

# Define game settings using the loaded configuration
$config = GameConfig.new
# `$config` is a global variable, which is accessible throughout the program.
# Global variables are prefixed with `$` in Ruby.

$config.starting_health = yaml_config['starting_health']
$config.starting_gold = yaml_config['starting_gold']
$config.treasure_items = yaml_config['treasure_items']
$config.enemy_types = yaml_config['enemy_types']
$config.ally_types = yaml_config['ally_types']
$config.store_items = yaml_config['store_items']

# Define a class for rooms
class Room
    attr_accessor :description, :directions, :unique_events, :boss
    # `attr_accessor` automatically creates getter and setter methods for the specified attributes.

    def initialize(description, directions = {}, unique_events = [], boss = nil)
        @description = description
        @directions = directions # A hash mapping directions (e.g., "north") to other Room objects.
        @unique_events = unique_events # An array of unique event methods for this room.
        @boss = boss # A hash containing boss details (name, health, reward).
    end

    def display
        puts "\n#{@description}"
        puts "You can go in the following directions:"
        @directions.each_key { |direction| puts "- #{direction.capitalize}" }
        # `each_key` iterates over the keys of the `@directions` hash.
        # `capitalize` converts the first letter of the string to uppercase.
    end
end

# Define a module for game utilities
module InventoryUtils
    # Modules in Ruby are used to group related methods and can be included in classes or used as namespaces.
    def self.use_item(player, item)
        # `case` is a Ruby control structure similar to `switch` in other languages.
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
        when "Small Boat"
            puts "You used the Small Boat. It will help you cross rivers without penalty."
        when "Royal Secrets"
            puts "You used the Royal Secrets. They may unlock hidden events later."
        else
            puts "You can't use that item right now."
        end
        player.inventory.delete(item) # Remove the item after use
    end
end

module GameUtils
    def self.clear_screen
        system('clear') || system('cls')
    end

    def self.pause
        puts "\nPress Enter to continue..."
        gets
    end
end

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
        puts "#{target.name} takes #{damage} damage over #{turns} turns!"
        target.dot_effect = { damage: damage, turns: turns }
    end

    def self.process_damage_over_time(target)
        if target.dot_effect && target.dot_effect[:turns] > 0
            damage = target.dot_effect[:damage]
            target.health -= damage
            target.dot_effect[:turns] -= 1
            puts "#{target.name} suffers #{damage} damage from a damage-over-time effect! #{target.dot_effect[:turns]} turns remaining."
        end
    end
end

class Player
    attr_accessor :dot_effect

    [:name, :health, :inventory, :damage_bonus, :health_bonus, :gold, :level, :experience].each do |attr|
        define_method(attr) do
            instance_variable_get("@#{attr}")
        end

        define_method("#{attr}=") do |value|
            instance_variable_set("@#{attr}", value)
        end
    end

    def initialize(name)
        @name = name
        @health = $config.starting_health
        @inventory = ["healing potion"] # Start with a healing potion
        @damage_bonus = 5 # Start with a small damage bonus
        @health_bonus = 0
        @gold = $config.starting_gold
        @dot_effect = nil # Initialize damage-over-time effect
        @level = 1 # Start at level 1
        @experience = 0 # Start with 0 experience
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
    end

    def gain_experience(amount)
        @experience += amount
        puts "You gained #{amount} experience points!"
        if @experience >= experience_to_level_up
            level_up
        end
    end

    def level_up
        @level += 1
        @experience = 0
        @health += 20 # Increase health on level up
        @damage_bonus += 5 # Increase damage bonus on level up
        puts "Congratulations! You leveled up to Level #{@level}!"
        puts "Your health increased by 20, and your damage bonus increased by 5."
    end

    def experience_to_level_up
        100 * @level # Example: 100 XP for level 1, 200 XP for level 2, etc.
    end

    # New method to apply ally bonuses
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

    def initialize(type, health, damage, ability, description = "")
        @type = type
        @health = health + rand(5..15) # Add variability to health
        @damage = damage + rand(2..5) # Add variability to damage
        @ability = ability
        @description = description
        @dot_effect = nil # Initialize damage-over-time effect
    end
end

class Game
    def initialize
        @player = nil
        @current_room = nil
        @rooms = {}
    end

    def start
        GameUtils.clear_screen
        puts "Welcome to the Adventure Game!"

        # Prompt for a valid name
        player_name = ""
        loop do
            print "Enter your name: "
            player_name = gets.chomp.strip
            # `chomp` removes the trailing newline from user input.
            # `strip` removes leading and trailing whitespace.
            if player_name.empty?
                puts "Name cannot be empty. Please enter a valid name."
            else
                break
            end
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
            { name: "Forest Guardian", health: 50, reward: "Enchanted Bow" }
        )
        @rooms[:cave] = Room.new(
            "You are in a dark cave. The air is damp and cold.",
            { "south" => :forest, "west" => :mountain },
            [:find_crystals, :hear_echoes],
            { name: "Cave Troll", health: 70, reward: "Crystal Shield" }
        )
        @rooms[:river] = Room.new(
            "You are by a rushing river. The water sparkles in the sunlight.",
            { "west" => :forest, "north" => :village },
            [:catch_fish, :find_boat],
            { name: "River Serpent", health: 60, reward: "Serpent Fang Dagger" }
        )
        @rooms[:mountain] = Room.new(
            "You are on a steep mountain. The view is breathtaking.",
            { "east" => :cave, "north" => :peak },
            [:find_eagle_nest, :trigger_rockslide],
            { name: "Mountain Dragon", health: 100, reward: "Dragon Scale Armor" }
        )
        @rooms[:village] = Room.new(
            "You are in a small village. The villagers greet you warmly.",
            { "south" => :river, "east" => :castle },
            [:visit_blacksmith, :talk_to_elder],
            { name: "Corrupted Elder", health: 80, reward: "Elder's Staff" }
        )
        @rooms[:castle] = Room.new(
            "You are in a grand castle. The walls are adorned with ancient tapestries.",
            { "west" => :village, "north" => :throne_room },
            [:find_treasure_chest, :meet_royal_guard],
            { name: "Dark Knight", health: 120, reward: "Shadow Blade" }
        )
        @rooms[:peak] = Room.new(
            "You are at the mountain's peak. The air is thin, and the view is stunning.",
            { "south" => :mountain },
            [:find_ancient_relic, :encounter_lightning_storm],
            { name: "Sky Titan", health: 150, reward: "Thunder Hammer" }
        )
        @rooms[:throne_room] = Room.new(
            "You are in the throne room. A sense of dread fills the air.",
            { "south" => :castle },
            [:find_royal_secrets, :activate_trap],
            { name: "King of Shadows", health: 200, reward: "Crown of Power" }
        )

        # Set the starting room
        @current_room = @rooms[:forest]
    end

    def explore_room
        loop do
            puts "Debug: Entering explore_room loop" # Debugging output
            GameUtils.clear_screen
            @current_room.display
            puts "\nOptions:"
            puts "- Type a direction to explore (e.g., 'north', 'east')."
            puts "- Type 'status' to check your current status."
            puts "- Type 'inventory' to check your inventory and use items."
            print "\nWhat would you like to do? "

            input = gets.chomp.downcase
            if input == "status"
                GameUtils.clear_screen
                @player.display_status
                GameUtils.pause
            elsif input == "inventory"
                check_inventory
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
            input = gets.chomp.downcase
            if input == "back"
                return
            elsif input == "help"
                display_item_help
            elsif @player.inventory.include?(input.capitalize)
                InventoryUtils.use_item(@player, input.capitalize)
            else
                puts "You don't have that item!"
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
            else
                puts "- #{item}: No description available."
            end
        end
        GameUtils.pause
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
        enemy = Enemy.new(
            enemy_data["name"],
            enemy_data["health"],
            enemy_data["damage"],
            enemy_data["ability"],
            enemy_data["description"]
        )

        puts "You encountered an enemy: #{enemy.type}!"
        puts "#{enemy.description}"
        puts "#{enemy.type} has #{enemy.health} health and can use the ability: #{enemy.ability}."
        GameUtils.pause

        # Combat logic remains unchanged
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
                    if enemy.ability == "Stone Skin"
                        damage_to_enemy = CombatUtils.apply_damage_reduction(damage_to_enemy, 50)
                    end
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
                            InventoryUtils.use_item(@player, item)
                            break
                        else
                            puts "You don't have that item!"
                        end
                    end
                elsif action == "3"
                    puts "Your inventory: #{@player.inventory.join(', ')}"
                    puts "Health: #{@player.health}, Damage Bonus: #{@player.damage_bonus}"
                    GameUtils.pause
                else
                    puts "Invalid action. Please choose a valid option."
                end
            end

            if enemy.health <= 0
                puts "You defeated the #{enemy.type}!"
                puts "You gain some experience and loot!"

                # Grant experience points
                experience_gained = case enemy.type
                                    when "goblin", "bandit" then 50
                                    when "orc", "troll" then 100
                                    else 150
                                    end
                @player.gain_experience(experience_gained)

                # Gold drop
                gold_dropped = case enemy.type
                               when "goblin", "bandit" then rand(10..20)
                               when "orc", "troll" then rand(20..40)
                               else rand(40..60)
                               end
                @player.gold += gold_dropped
                puts "The #{enemy.type} dropped #{gold_dropped} gold!"

                # Item drop (30% chance)
                if rand < 0.3
                    item_dropped = $config.treasure_items.sample
                    @player.inventory << item_dropped
                    puts "The #{enemy.type} dropped an item: #{item_dropped}!"
                end

                GameUtils.pause
                break
            end

            puts "\nThe #{enemy.type}'s turn!"
            damage_to_player = CombatUtils.calculate_damage(enemy.damage, 0)
            case enemy.ability
            when "Burn"
                CombatUtils.apply_damage_over_time(@player, rand(5..10), 3)
            when "Freeze"
                @player.damage_bonus -= 2
                puts "The #{enemy.type} freezes you, reducing your damage!"
            end

            @player.health -= damage_to_player
            puts "The #{enemy.type} attacks you and deals #{damage_to_player} damage!"
            puts "You have #{[0, @player.health].max} health remaining."

            if @player.health <= 0
                puts "You were defeated by the #{enemy.type}!"
                GameUtils.pause
                exit
            end
        end
    end

    def find_ally
        puts "\nYou encounter a potential ally!"
        ally = $config.ally_types.sample
        puts "You found an ally: #{ally}!"
        print "Would you like this ally to join your party? (yes/no): "
        response = gets.chomp.downcase
        if response == "yes"
            @player.apply_ally_bonus(ally)
            puts "#{ally} has joined your party!"
        else
            puts "You decided not to let #{ally} join your party."
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
    end

    def random_event
        # Check if the current room has unique events
        if @current_room.unique_events.any? && rand < 0.3 # 30% chance for a unique event
            # Trigger a unique event from the current room
            unique_event = @current_room.unique_events.sample
            send(unique_event) # Dynamically calls the unique event method
        else
            # Trigger a general random event if no unique event occurs
            case rand(1..4)
            when 1
                find_treasure
            when 2
                encounter_enemy
            when 3
                find_ally
            when 4
                discover_mystery
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
        GameUtils.pause
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

    # Cave unique events
    def find_crystals
        puts "You find glowing crystals embedded in the cave walls."
        @player.inventory << "Glowing Crystals"
        puts "You added 'Glowing Crystals' to your inventory."
        GameUtils.pause
    end

    def hear_echoes
        puts "You hear strange echoes in the cave. They seem to guide you to a hidden treasure."
        @player.inventory << "Echoing Gem"
        puts "You added 'Echoing Gem' to your inventory."
        GameUtils.pause

    end

    # River unique events
    def catch_fish
        puts "You catch a fish from the river. It looks delicious."
        @player.inventory << "Fresh Fish"
        puts "You added 'Fresh Fish' to your inventory."
        GameUtils.pause
    end

    def find_boat
        puts "You find an abandoned boat by the riverbank. It might be useful later."
        @player.inventory << "Small Boat"
        puts "You added 'Small Boat' to your inventory."
        GameUtils.pause
    end
end

# Start the game
game = Game.new
game.start