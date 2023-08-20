require "./patches/**"
require "./game_of_life/**"

module GameOfLife
  VERSION = "0.1"

  Log.info("Client started!")
  client = Client.new
  client.start
  Log.info("Client stopped!")
end
