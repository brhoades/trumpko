require_relative 'environment'

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

  # if Markov::Source.where(text: tweet["text"]).size == 0
    MarkovSpeech::Storage.store(tweet["text"])
  # end

  markov_speech.store
end
