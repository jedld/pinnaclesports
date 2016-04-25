require 'pinnaclesports'
require 'byebug'

client = Pinnaclesports::Client.new('client_id', 'password')

puts client.sports

puts client.leagues(1)

puts client.odds(1)
