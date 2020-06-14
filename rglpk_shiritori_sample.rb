#!/usr/bin/env ruby -Ku
# -*- coding: utf-8 -*-

require File.dirname(__FILE__) + "/rglpk_shiritori"

# Usage: ruby rglpk_shiritori_sample.rb [1行に1単語が書かれたファイル] ...
if ARGV.empty?
  STDERR.puts "Usage: shiritori_sample [FILE1] ([FILE2] ...)"
  exit
end

shsolve = ShiritoriSolver.new(*ARGV.map{ |fname| IO.readlines(fname).map{|x| x.gsub(/[\x00-\x1F]/, " ").gsub("^","＾").gsub("$","＄").strip }.delete_if{|x| x.empty?} })

shsolve.extract_result.each_with_index do |res, i|
  puts <<TXT
============================================================
Words file: #{ARGV[i]}
Number of words used in the longest shiritori: #{shsolve.path(i).size}
Number of input words: #{shsolve.words(i).size}

The longest shiritori:
#{res.path_str(0)}
TXT

  unless res.notes.empty?
    puts <<TXT

Note:
TXT

    for i in 0...(res.notes.size)
      puts res.note_str(i, lambda{|wlist, count| "Choose #{count} words from #{wlist.join('/')}"})
    end
  end
end

if ARGV.size > 1
  puts "============================================================"
  puts "Common uses of words: #{shsolve.optimal_common_links.size}"

  (0...ARGV.size).each do |i|
    ((i+1)...ARGV.size).each do |j|
      path1 = Multiset.new(shsolve.path(i))
      path2 = Multiset.new(shsolve.path(j))
      diff1 = (path1 - path2).to_a.sort
      diff2 = (path2 - path1).to_a.sort

      puts "============================================================"
      puts "Difference between words files #{i} and #{j}"
      puts ""
      puts "Words only in problem #{i} (size #{diff1.size}):"
      p(diff1)
      puts ""
      puts "Words only in problem #{j} (size #{diff2.size}):"
      p(diff2)
    end
  end
end

puts "============================================================"
