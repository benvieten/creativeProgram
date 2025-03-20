# creativeProgram.rb

# Welcome to the Text-Based Adventure Game!
# This game will showcase many of Ruby's unique features such as classes, modules, and more.

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
            puts "You read the magic scroll and feel a surge of power."
            player.health += 10
        when "shield"
            puts "You equip the shield, ready to block incoming attacks."
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

# Define a class for the Player
class Player
    attr_accessor :name, :health, :inventory, :damage_bonus, :health_bonus

    def initialize(name)
        @name = name
        @health = 100
        @inventory = []
        @damage_bonus = 0
        @health_bonus = 0
    end

    def display_status
        puts "\n#{@name}'s Status:"
        puts "Health: #{@health}"
        puts "Inventory: #{@inventory.join(', ')}"
        puts "Damage Bonus: #{@damage_bonus}"
        puts "Health Bonus: #{@health_bonus}"
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
        end
    end
end

# Define a class for the Enemy
class Enemy
    attr_accessor :type, :health

    def initialize(type, health)
        @type = type
        @health = health
    end
end

# Define a class for the Game
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
            puts "3. Exit"
            print "Choose an option: "
            choice = gets.chomp.to_i

            case choice
            when 1
                explore
            when 2
                @player.display_status
                GameUtils.pause
            when 3
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
        encounter = rand(1..5)

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
            nothing_happens
        end

        GameUtils.pause
    end

    def find_treasure
        treasure = ["gold coin", "silver sword", "healing potion"].sample
        puts "You found a #{treasure}!"
        @player.inventory << treasure
    end

    def encounter_enemy
        enemy_types = ["wild beast", "goblin", "troll"]
        enemy_type = enemy_types.sample
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
                player_damage = rand(10..30) + @player.damage_bonus
                enemy.health -= player_damage
                puts "You deal #{player_damage} damage to the #{enemy.type}."
                break if enemy.health <= 0

                enemy_damage = rand(5..15)
                @player.health -= enemy_damage
                puts "The #{enemy.type} attacks you and deals #{enemy_damage} damage."
                break if @player.health <= 0
            when 2
                escape_damage = rand(5..15)
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

            if @player.health <= 0
                puts "You have been defeated. Game Over."
                exit
            elsif enemy.health <= 0
                puts "You have defeated the #{enemy.type}!"
            end
        end
    end

    def find_ally
        ally = ["a wandering knight", "a wise mage", "a skilled archer"].sample
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
    end

    def discover_mystery
        mystery = ["an ancient ruin", "a hidden cave", "a mysterious artifact"].sample
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
    end

    def nothing_happens
        puts "Nothing interesting happens. You continue on your way."
    end
end

# Start the game
game = Game.new
game.start