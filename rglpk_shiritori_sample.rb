#!/usr/bin/env ruby -Ku
# -*- coding: utf-8 -*-

require File.dirname(__FILE__) + "/rglpk_shiritori"

# Usage: ruby solve_shiritori.rb [1行に1単語が書かれたファイル]
shsolve = ShiritoriSolver.new(ARGF.readlines.map{|x| x.gsub(/[\x00-\x1F]/, " ").gsub("^","＾").gsub("$","＄").strip }.delete_if{|x| x.empty?})
res = shsolve.extract_result

puts <<TXT
Number of words used in the longest shiritori: #{shsolve.path.size}
Number of input words: #{shsolve.words.size}

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
