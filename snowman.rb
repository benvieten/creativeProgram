require 'ruby2d'
# This line sets the title and dimensions of the window
set title: "Snowman", width: 400, height: 500
set title: "Snowman", width: 400, height: 500

# Selects a word at random from the dictionary file
def select_word
  filename = "dictionary.txt"
  lexicon = File.open(filename)
  words = lexicon.readlines
  lexicon.close
  game_word = words.sample.chomp
  game_word
end

# Initializes the game
def init
  @guess_limit = 6
  @game_word = select_word
  @guessed_letters = []
  @incorrect_guesses = []
end

# Determines win conditions and displays the result
def game_over?
  if @guess_limit.zero?
    puts "You lose!"
    puts "The word was: #{@game_word}"
    true
  elsif @game_word.chars.all? { |char| @guessed_letters.include?(char) || char == " " }
    puts "You win!"
    true
  else
    false
  end
end

# Displays the word with correct guesses filled in
def display_word
  @game_word.each_char do |char|
    if @guessed_letters.include?(char) || char == " "
      print char
    else
      print "_"
    end
  end
  puts
end

# Displays the incorrect guesses and lists them in alphabetical order
def display_incorrect_guesses
  print "Incorrect guesses: "
  @incorrect_guesses.sort.each { |guess| print guess + ", " }
  puts
end

# Draws the snowman based on the number of incorrect guesses
def draw_snowman
  case @incorrect_guesses.size
  when 1
    Circle.new(x: 200, y: 400, radius: 50, color: 'white')
  when 2
    Circle.new(x: 200, y: 300, radius: 40, color: 'white')
  when 3
    Circle.new(x: 200, y: 220, radius: 30, color: 'white')
  when 4
    Rectangle.new(x: 180, y: 150, width: 40, height: 20, color: 'black')
  when 5
    Line.new(x1: 160, y1: 300, x2: 120, y2: 250, width: 5, color: 'white')
  when 6
    Line.new(x1: 240, y1: 300, x2: 280, y2: 250, width: 5, color: 'white')
  end
end

# Plays the game
def play_game
  init
  puts "Welcome to Snowman! You have #{@guess_limit} guesses to guess the word."
  puts "Here is your word: "
  display_word

  until game_over?
    puts "Please guess a letter or punctuation: "
    guess = gets.chomp.downcase

    if @guessed_letters.include?(guess)
      puts "You already guessed that letter!"
      next
    end

    @guessed_letters.push(guess)
# Handles valid guesses
    if @game_word.include?(guess)
      puts "Correct!"
    elsif guess.length > 1
      puts "You can only guess one letter at a time!"
    elsif guess.length < 1
      puts "You must guess a letter!"
    elsif !guess.match?(/[a-z\-']/)
      puts "That is not a valid guess!"
    else
      @incorrect_guesses.push(guess)
      puts "Incorrect!"
      @guess_limit -= 1
      puts "You have #{@guess_limit} guesses left."
      draw_snowman

    end

    display_incorrect_guesses
    display_word
  end
end
update do
end

play_game

Window.show
