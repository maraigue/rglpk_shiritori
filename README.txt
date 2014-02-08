rglpk_shiritori

Finding the longest shiritori with rglpk (GLPK for Ruby)

[REFERENCE]

The program is an implementation of the algorithm by Issei Sato.
http://auemath.aichi-edu.ac.jp/~ykhashi/semi/2010note/08_issey_final.pdf (in Japanese)

[INSTALLATION]

See https://github.com/wtaysom/rglpk .
Note that GLPK of the specified version is required.

[USAGE]

$ ruby rglpk_shiritori_sample.rb cpp.txt

# Find the longest shiritori for the words in cpp.txt
# (UTF-8 is assumed)
# * For he usage of Japanese, see Japanese explanation below. 

rglpkで最長しりとりを見つける

[参照]

このプログラムは、佐藤一生氏によるアルゴリズムを実装したものです。
http://auemath.aichi-edu.ac.jp/~ykhashi/semi/2010note/08_issey_final.pdf (in Japanese)

[インストール]

https://github.com/wtaysom/rglpk をご覧ください（英語）。
GLPKは指定されたバージョンのものが必要です。

[利用方法]

$ ruby rglpk_shiritori_sample.rb cpp.txt

# cpp.txtにある単語で最長しりとりを見つける
# (ファイルはUTF-8を想定)
# 日本語はひらがなないしカタカナで指定（混合は不可）。
# 濁点半濁点は除去される。小さい文字は大きくする。
