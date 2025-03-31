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
        when "healing potion"
            player.health += 20
            puts "You used a healing potion and restored 20 health."
        when "silver sword"
            puts "You wield the silver sword, ready to deal extra damage."
        when "gold coin"
            puts "You admire the gold coin, but it doesn't seem to have any immediate use."
        when "magic scroll"
            player.health += 10
            puts "You read the magic scroll and feel a surge of power."
        else
            puts "You can't use that item right now."
        end
        player.inventory.delete(item)
        # `delete` removes the specified item from the player's inventory.
    end
end

module GameUtils
    def self.clear_screen
        system('clear') || system('cls')
        # `system` executes a shell command. Here, it clears the terminal screen.
        # `||` ensures compatibility with different operating systems (e.g., Unix and Windows).
    end

    def self.pause
        puts "\nPress Enter to continue..."
        gets
        # `gets` waits for user input, effectively pausing the program.
    end
end

module CombatUtils
    def self.calculate_damage(base, bonus)
        rand(base..(base + bonus))
        # `rand(base..(base + bonus))` generates a random number within the specified range.
    end
end

class Player
    # Dynamically define getter and setter methods for multiple attributes using `define_method`.
    [:name, :health, :inventory, :damage_bonus, :health_bonus, :gold].each do |attr|
        define_method(attr) do
            instance_variable_get("@#{attr}")
            # `instance_variable_get` retrieves the value of an instance variable by name.
        end

        define_method("#{attr}=") do |value|
            instance_variable_set("@#{attr}", value)
            # `instance_variable_set` sets the value of an instance variable by name.
        end
    end

    def initialize(name)
        @name = name
        @health = $config.starting_health
        @inventory = []
        @damage_bonus = 0
        @health_bonus = 0
        @gold = $config.starting_gold
    end

    def display_status
        puts "\n#{@name}'s Status:"
        puts "Health: #{@health}"
        puts "Inventory: #{@inventory.join(', ')}"
        # `join(', ')` converts an array into a string, with elements separated by commas.
        puts "Damage Bonus: #{@damage_bonus}"
        puts "Health Bonus: #{@health_bonus}"
        puts "Gold: #{@gold}"
    end
end

class Enemy
    attr_accessor :type, :health

    def initialize(type, health)
        @type = type
        @health = health
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
        # The `Room` constructor is used to define the room's description, directions, unique events, and boss.
    end

    def explore_room
        loop do
            GameUtils.clear_screen
            @current_room.display
            puts "\nOptions:"
            puts "- Type a direction to explore (e.g., 'north', 'east')."
            puts "- Type 'status' to check your current status."
            print "\nWhat would you like to do? "

            input = gets.chomp.downcase
            # `downcase` converts the input to lowercase for case-insensitive comparison.

            if input == "status"
                GameUtils.clear_screen
                @player.display_status
                GameUtils.pause
            elsif @current_room.directions.key?(input)
                @current_room = @rooms[@current_room.directions[input]]
                random_event
            else
                puts "Invalid input. Please try again."
                GameUtils.pause
            end
        end
    end
end