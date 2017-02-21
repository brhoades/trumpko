#!/usr/bin/env ruby
require 'rufus-scheduler'
require 'htmlentities'

require_relative './environment.rb'

include Markov::Models

options = {}
logger = Logger.new("trumpko.log", "daily")

OptionParser.new do |opts|
  opts.banner = "Usage: tweeter.rb [options]"

  opts.on("-d", "--dry-run", "Run without tweeting.") do |v|
    logger.info("Launching in dry-run mode.")
    options[:dry] = v
  end

  opts.on("-m", "--monitor", "Monitor timeline for new tweets and tweet as needed.") do |v|
    logger.info("Launching in monitoring mode.")
    options[:monitor] = v
  end
end.parse!

def delete_source(logger, text)
  logger.warn("Deleting source \"#{text}\".")
  src = Source.where(text: text).first
  if src
    Chain.where(source: src).map { |c| c.delete if c }
    src.delete
  else
    logger.warn("No source to delete.")
  end
end

def check_tweets(logger, options)
  # Look to see if anyone we follow (Trump) has made a new tweet
  # Reverse the list so we post them in the correct order if we're out of date.
  $twitter_client.home_timeline.reverse.each do |tweet|
    begin
      next if Source.where(text: tweet.text).size > 0
      next if tweet.user.screen_name != "realDonaldTrump"
      logger.info("New tweet detected: \"#{tweet.text}\".")

      src = Markov::Storage::Storage.store(tweet.text)
      Markov::Storage::Storage.process(src)
      logger.info("Stored and processed new tweet with ID: #{src.id}. Created #{Chain.where(source: src).size} chains.")

      # Choose a random word and chain off of it (later: chose a good random word)
      word = nil
      tries = 0
      tries_threshold = 100
      loop do
        tries += 1
        logger.debug("Throwing out word \"#{word.text}\"") if word
        word = Chain.where(source: src).sample.word
        break if word.text !~ /^[[:punct:]]+$/ and word.text.size > 3 and Chain.where(word: word).size > 1
        break if tries > tries_threshold
      end
      logger.info("Source word chosen: \"#{word.text}\"")

      if tries > tries_threshold
        logger.error("Tries to select a word have exceeded the threshold (#{tries_threshold}). Skipping this tweet.")
        break
      end

      gen = nil
      tries = 0
      score_threshold = 0.8
      size_threshold = 140
      tries_threshold = 100
      loop do
        if tries > tries_threshold
          logger.error("Tries for sentence generations have exceeded threshold (#{tries_threshold}). Raising an exception so we can try our luck later.")
          raise Exception
        end
        tries += 1
        gen = Markov::Generate::Generate.new(8)
        sentence = gen.chain(word.text)

        score = Markov::Evaluate::Evaluate.eval(sentence)
        if score <= score_threshold
          logger.debug("Throwing out sentence: \"#{gen.to_s}\".")
          logger.debug("Score does not meet threshold: #{score} <= #{score_threshold}")
          next
        end

        size = gen.to_s.size
        if size > 140
          logger.debug("Throwing out sentence: \"#{gen.to_s}\".")
          logger.debug("Size does not meet threshold: #{size} > #{size_threshold}")
          next
        end

        logger.info("Sentence passed. Score: #{score}")
        break
      end

      # parse htmlentities
      coder = HTMLEntities.new
      generated = coder.decode(gen.to_s)

      logger.info("Selected generated sentence: #{generated}")

      if not options.has_key?(:dry)
        $twitter_client.update(generated)
        logger.info("Tweeted sentence.")

        sleep 60 # Avoid sending too many requests
      else
        logger.info("Did not tweet sentence.")
        sleep 5  # Not a full delay.
      end
    rescue SystemExit, Interrupt
      raise
    rescue Exception => e
      logger.error(e)
      logger.error("Error, deleting source tweet.")
      delete_source(logger, tweet.text)

      sleep 60 if not options.has_key?(:dry)
    ensure
      if options.has_key? :dry
        logger.info("(DRY) Deleting source...")
        delete_source(logger, tweet.text)
      end
    end
  end
end


scheduler = Rufus::Scheduler.new

if options.has_key? :monitor
  logger.info("Checking tweets every 15 minutes. First time is now.")
  check_tweets(logger, options)

  scheduler.every '15m' do
    logger.info("It's been 15 minutes, checking tweets...")
    check_tweets(logger, options)
  end
else
  logger.info("Checking tweets once.")
  check_tweets(logger, options)
end

scheduler.join
