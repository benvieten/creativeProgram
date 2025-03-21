require 'yaml'

# Define a class for game configuration using a DSL
class GameConfig
    def initialize
        @settings = {}
    end

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

# Load game configuration from YAML file
config_file = '/Users/benvieten/Documents/csci324/creativeProgram/config.yml'
yaml_config = YAML.load_file(config_file)['game']

# Define game settings using the loaded configuration
$config = GameConfig.new
$config.starting_health = yaml_config['starting_health']
$config.starting_gold = yaml_config['starting_gold']
$config.treasure_items = yaml_config['treasure_items']
$config.enemy_types = yaml_config['enemy_types']
$config.ally_types = yaml_config['ally_types']
$config.store_items = yaml_config['store_items']

# Define a module for game utilities
module InventoryUtils
    def self.use_item(player, item)
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
        when "shield"
            puts "You equip the shield, ready to block incoming attacks."
        when "ruby gem"
            puts "You admire the ruby gem, feeling its magical aura."
        when "enchanted amulet"
            player.health += 15
            puts "You wear the enchanted amulet, feeling its protective power."
        when "dragon scale"
            player.damage_bonus += 20
            puts "You use the dragon scale, feeling its immense power."
        when "phoenix feather"
            player.health += 50
            puts "You use the phoenix feather, feeling its rejuvenating power."
        when "elixir of life"
            player.health += 100
            puts "You drink the elixir of life, feeling its life-giving power."
        else
            puts "You can't use that item right now."
        end
        player.inventory.delete(item)
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
    def self.calculate_damage(base, bonus)
        rand(base..(base + bonus))
    end
end

class Player
    [:name, :health, :inventory, :damage_bonus, :health_bonus, :gold].each do |attr|
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
        @inventory = []
        @damage_bonus = 0
        @health_bonus = 0
        @gold = $config.starting_gold
    end

    def display_status
        puts "\n#{@name}'s Status:"
        puts "Health: #{@health}"
        puts "Inventory: #{@inventory.join(', ')}"
        puts "Damage Bonus: #{@damage_bonus}"
        puts "Health Bonus: #{@health_bonus}"
        puts "Gold: #{@gold}"
    end

    def display_health
        puts "Health: #{@health}"
    end

    def use_item
        if @inventory.empty?
            puts "Your inventory is empty."
            return
        end

        puts "Choose an item to use:"
        @inventory.each_with_index do |item, index|
            puts "#{index + 1}. #{item}"
        end
        print "Enter the number of the item: "
        choice = gets.chomp.to_i

        if choice.between?(1, @inventory.size)
            item = @inventory[choice - 1]
            InventoryUtils.use_item(self, item)
        else
            puts "Invalid choice."
        end
    end

    def apply_ally_bonus(ally)
        case ally
        when "a wandering knight"
            @damage_bonus += 5
            puts "The wandering knight increases your damage by 5."
        when "a wise mage"
            @health_bonus += 20
            puts "The wise mage increases your health by 20."
        when "a skilled archer"
            @damage_bonus += 10
            puts "The skilled archer increases your damage by 10."
        when "Shrouded figure"
            @health -= 30
            puts "The shrouded figure was evil! He cast a spell on you and decreased your health by 30!"
        when "a friendly merchant"
            @gold += 10
            puts "The friendly merchant gives you 10 gold coins."
        when "a brave warrior"
            @damage_bonus += 15
            puts "The brave warrior increases your damage by 15."
        end
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
    end

    def start
        GameUtils.clear_screen
        puts "Welcome to the Adventure Game!"
        print "Enter your name: "
        player_name = gets.chomp
        @player = Player.new(player_name)
        GameUtils.clear_screen
        puts "Hello, #{@player.name}! Your adventure begins now."
        GameUtils.pause
        main_menu
    end

    def main_menu
        loop do
            GameUtils.clear_screen
            puts "Main Menu"
            puts "1. Explore"
            puts "2. Check Status"
            puts "3. Visit Store"
            puts "4. Exit"
            print "Choose an option: "
            choice = gets.chomp.to_i

            case choice
            when 1
                explore
            when 2
                @player.display_status
                GameUtils.pause
            when 3
                visit_store
            when 4
                puts "Thank you for playing!"
                break
            else
                puts "Invalid choice. Please try again."
                GameUtils.pause
            end
        end
    end

    def explore
        GameUtils.clear_screen
        puts "You venture into the unknown..."
        encounter = rand(1..6)

        case encounter
        when 1
            find_treasure
        when 2
            encounter_enemy
        when 3
            find_ally
        when 4
            discover_mystery
        when 5
            encounter_trap
        when 6
            find_secret_passage
        end

        @player.display_health

        if @player.health <= 0
            end_game
        else
            GameUtils.pause
        end
    end

    def find_treasure
        treasure = $config.treasure_items.sample
        if treasure == "gold coin"
            gold_reward = rand(2..5)
            @player.gold += gold_reward
            puts "You found #{gold_reward} #{treasure}s!"
        else
            @player.inventory << treasure
            puts "You found a #{treasure}!"
        end
    end

    def encounter_enemy
        enemy_type = $config.enemy_types.sample
        enemy_health = @player.health / 2
        enemy = Enemy.new(enemy_type, enemy_health)

        puts "You encounter a #{enemy.type} with #{enemy.health} health!"
        loop do
            puts "1. Fight"
            puts "2. Run"
            puts "3. Use Item"
            print "Choose an option: "
            choice = gets.chomp.to_i

            case choice
            when 1
                player_damage = CombatUtils.calculate_damage(10, @player.damage_bonus)
                enemy.health -= player_damage
                puts "You deal #{player_damage} damage to the #{enemy.type}."
                break if enemy.health <= 0

                enemy_damage = rand(5..15)
                @player.health -= enemy_damage
                puts "The #{enemy.type} attacks you and deals #{enemy_damage} damage."
                if enemy.type == "troll" && rand(1..4) == 1
                    gold_stolen = rand(1..@player.gold)
                    @player.gold -= gold_stolen
                    puts "The troll stole #{gold_stolen} gold coins from you!"
                elsif enemy.type == "dark wizard" && rand(1..3) == 1
                    health_stolen = rand(5..10)
                    @player.health -= health_stolen
                    enemy.health += health_stolen
                    puts "The dark wizard casts a spell and steals #{health_stolen} health from you!"
                elsif enemy.type == "giant spider" && rand(1..3) == 1
                    poison_damage = rand(5..10)
                    @player.health -= poison_damage
                    puts "The giant spider bites you and deals #{poison_damage} poison damage!"
                end
                break if @player.health <= 0
            when 2
                escape_damage = rand(1..10)
                @player.health -= escape_damage
                puts "You manage to escape, but you take #{escape_damage} damage in the process."
                break if @player.health <= 0
            when 3
                @player.use_item
            else
                invalid_choice_damage = rand(10..30)
                @player.health -= invalid_choice_damage
                puts "Invalid choice. The #{enemy.type} attacks you while you hesitate and you take #{invalid_choice_damage} damage."
                break if @player.health <= 0
            end

            @player.display_health

            if @player.health <= 0
                puts "You have been defeated. Game Over."
                exit
            elsif enemy.health <= 0
                gold_reward = rand(1..5)
                @player.gold += gold_reward
                puts "You have defeated the #{enemy.type} and earned #{gold_reward} gold coins!"
            end
        end
    end

    def find_ally
        ally = $config.ally_types.sample
        puts "You find #{ally} who offers to join you on your adventure."
        puts "1. Accept"
        puts "2. Decline"
        print "Choose an option: "
        choice = gets.chomp.to_i

        case choice
        when 1
            puts "#{ally} joins your party and helps you on your journey."
            @player.apply_ally_bonus(ally)
        when 2
            puts "You politely decline and continue on your way."
        else
            puts "Invalid choice. The ally leaves while you hesitate."
        end

        @player.display_health
    end

    def discover_mystery
        mystery = ["an ancient ruin", "a hidden cave", "a mysterious artifact", "a magical portal", "a strange monument"].sample
        puts "You discover #{mystery}."
        puts "1. Investigate"
        puts "2. Ignore"
        print "Choose an option: "
        choice = gets.chomp.to_i

        case choice
        when 1
            puts "You investigate and find something valuable!"
            find_treasure
        when 2
            puts "You decide to ignore it and continue on your way."
        else
            puts "Invalid choice. You miss the opportunity while you hesitate."
        end

        @player.display_health
    end

    def encounter_trap
        trap_damage = rand(10..30)
        @player.health -= trap_damage
        puts "You triggered a trap and took #{trap_damage} damage!"

        @player.display_health
    end

    def find_secret_passage
        puts "You find a secret passage that leads to a hidden treasure!"
        find_treasure

        @player.display_health
    end

    def visit_store
        GameUtils.clear_screen
        puts "Welcome to the Store!"
        puts "You have #{@player.gold} gold coins."
        puts "Items available for purchase:"
        store_items = $config.store_items
        store_items.each_with_index do |(item, price), index|
            puts "#{index + 1}. #{item.capitalize} - #{price} gold coins"
        end
        print "Enter the number of the item you want to buy: "
        choice = gets.chomp.to_i

        if choice.between?(1, store_items.size)
            item = store_items.keys[choice - 1]
            price = store_items[item]
            if @player.gold >= price
                @player.gold -= price
                @player.inventory << item
                puts "You bought a #{item} for #{price} gold coins."
            else
                puts "You don't have enough gold coins to buy that item."
            end
        else
            puts "Invalid choice."
        end

        @player.display_status
        GameUtils.pause
    end

    def end_game
        if @player.health > 0
            puts "Congratulations! You have completed the adventure."
        else
            puts "You have been defeated. Game Over."
        end
    end
end

# Start the game
game = Game.new
game.start