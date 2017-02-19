#!/usr/bin/env ruby
require_relative './environment.rb'

include Markov::Models

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: tweeter.rb [options]"

  opts.on("-d", "--dry-run", "Run without tweeting.") do |v|
    options[:dry] = v
  end
end.parse!

def delete_source(text)
  src = Source.where(text: text).first
  if src
    Chain.where(source: src).map { |c| c.delete if c }
    src.delete
  end
end

# Look to see if anyone we follow (Trump) has made a new tweet
# Reverse the list so we post them in the correct order if we're out of date.
$twitter_client.home_timeline.reverse.each do |tweet|
  begin
    next if Source.where(text: tweet.text).size > 0
    next if tweet.user.screen_name != "realDonaldTrump"

    src = Markov::Storage::Storage.store(tweet.text)
    Markov::Storage::Storage.process(src)

    # Choose a random word and chain off of it (later: chose a good random word)
    word = nil
    loop do
      word = Chain.where(source: src).sample.word
      break if word.text !~ /[[:punct:]]/ and word.text.size > 3 and Chain.where(word: word).size > 1
    end
    puts "SOURCE: #{word.text}"

    gen = nil
    loop do
        gen = Markov::Generate::Generate.new(8)
        sentence = gen.chain(word.text)
        break if Markov::Evaluate::Evaluate.eval(sentence) > 0.2 and gen.to_s.size < 140
    end

    puts "GENERATED: #{gen.to_s}"
    if not options.has_key?(:dry)
      $twitter_client.update(gen.to_s)
      puts "TWEETED"
    else
      puts "DID NOT TWEET"
    end
    sleep 5 # Don't spam
  rescue Exception => e
    puts "Deleting source..."
    delete_source(tweet.text)

    puts "WOULD Error: #{e}"
    sleep 5
  ensure
    if options.has_key? :dry
      puts "Deleting source..."
      delete_source(tweet.text)
    end
  end
end
