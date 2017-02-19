require 'rubygems'
require 'bundler/setup'

require 'markov_speech'
require 'twitter'
require 'yaml'


conf = YAML.load_file("config.yml")

$twitter_client = Twitter::REST::Client.new do |config|
  config.consumer_key        = conf["consumer_key"]
  config.consumer_secret     = conf["consumer_secret"]
  config.access_token        = conf["access_token"]
  config.access_token_secret = conf["access_token_secret"]
end
