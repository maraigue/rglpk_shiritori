rglpk_shiritori

Finding the longest shiritori with rglpk (GLPK for Ruby)

[INSTALLATION]

See https://github.com/wtaysom/rglpk .
Note that GLPK of the specified version is required.

[USAGE]

$ ruby rglpk_shiritori_sample.rb cpp.txt

# Find the longest shiritori for the words in cpp.txt
# (UTF-8 is assumed)
# * For he usage of Japanese, see Japanese explanation below. 

rglpkで最長しりとりを見つける

[インストール]

https://github.com/wtaysom/rglpk をご覧ください（英語）。
GLPKは指定されたバージョンのものが必要です。

[利用方法]

$ ruby rglpk_shiritori_sample.rb cpp.txt

# cpp.txtにある単語で最長しりとりを見つける
# (ファイルはUTF-8を想定)
# 日本語はひらがなないしカタカナで指定（混合は不可）。
# 濁点半濁点は除去される。小さい文字は大きくする。
