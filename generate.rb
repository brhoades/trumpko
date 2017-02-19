#!/usr/bin/env ruby
require_relative './environment.rb'
if ARGV.size != 1
  puts("Need 1 args")
  exit 0
end
puts "#{ARGV[0]}"

gen = Markov::Generate::Generate.new(8)
sentence = gen.chain(ARGV[0])

while Markov::Evaluate::Evaluate.eval(sentence) < 0.1
  gen = Markov::Generate::Generate.new(8)
  sentence = gen.chain(ARGV[0])
end

puts gen.to_s
