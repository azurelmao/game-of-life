require "colorize"

module GameOfLife::Log
  extend self

  def info(message)
    time = Time.utc
    puts "[".colorize(:dark_gray).to_s +
         "#{time.hour}".rjust(2, '0') +
         ":".colorize(:light_gray).to_s +
         "#{time.minute}".rjust(2, '0') +
         ":".colorize(:light_gray).to_s +
         "#{time.second}".rjust(2, '0') +
         "]".colorize(:dark_gray).to_s +
         " " +
         "info".colorize(:green).bold.to_s +
         " " +
         ">".colorize(:dark_gray).to_s +
         " #{message}"
  end

  def debug(message)
    time = Time.utc
    puts "[".colorize(:dark_gray).to_s +
         "#{time.hour}".rjust(2, '0') +
         ":".colorize(:light_gray).to_s +
         "#{time.minute}".rjust(2, '0') +
         ":".colorize(:light_gray).to_s +
         "#{time.second}".rjust(2, '0') +
         "]".colorize(:dark_gray).to_s +
         " " +
         "debug".colorize(:cyan).bold.to_s +
         " " +
         ">".colorize(:dark_gray).to_s +
         " #{message}"
  end

  def error(message)
    time = Time.utc
    puts "[".colorize(:dark_gray).to_s +
         "#{time.hour}".rjust(2, '0') +
         ":".colorize(:light_gray).to_s +
         "#{time.minute}".rjust(2, '0') +
         ":".colorize(:light_gray).to_s +
         "#{time.second}".rjust(2, '0') +
         "]".colorize(:dark_gray).to_s +
         " " +
         "error".colorize(:red).bold.to_s +
         " " +
         ">".colorize(:dark_gray).to_s +
         " #{message}"
  end
end
