rglpk_shiritori

Finding the longest shiritori with rglpk (GLPK for Ruby)

# Find the longest shiritori for the words in cpp.txt
# (UTF-8 is assumed)
## * For he usage of Japanese, see Japanese explanation below. 
$ ruby rglpk_shiritori_sample.rb cpp.txt

rglpkで最長しりとりを見つける

# cpp.txtにある単語で最長しりとりを見つける
# (ファイルはUTF-8を想定)
# 日本語はひらがなないしカタカナで指定（混合は不可）。
# 濁点半濁点は除去される。小さい文字は大きくする。
$ ruby rglpk_shiritori_sample.rb cpp.txt
