require_relative './environment.rb'

# Get the most recent
# puts $twitter_client.user_timeline("realDonaldTrump")
# $twitter_client.user("realDonaldTrump")


# Load the archive files...

tweets = []

Dir["source/*.json"].each do |json_file|
  tweets += JSON.load(IO.read(json_file))
end

tweets.each do |tweet|
  next if tweet["is_retweet"]

  if Markov::Models::Source.where(text: tweet["text"]).size == 0
    puts "Adding: \"#{tweet["text"]}\""
    Markov::Storage::Storage.store(tweet["text"])
  else
    puts "Skipping: \"#{tweet["text"]}\""
  end
end

puts "PROCESSING: "
Markov::Models::Source.all.each do |source|
  # Assume not processed
  if Markov::Models::Chain.where(source: source).size == 0
    Markov::Storage::Storage.process(source)
    print "."
  else
    print "S"
  end
end
