#!/usr/bin/env ruby -Ku
# -*- coding: utf-8 -*-

# 論文：
# http://auemath.aichi-edu.ac.jp/~ykhashi/semi/2010note/08_issey_final.pdf

require "set"
require "multiset"
require "rglpk"

class Object
  def deep_dup
    Marshal.load(Marshal.dump(self))
  end
end

module ShiritoriStatus
  # しりとりの問題を表すクラス
  class Problem
    # 濁点・半濁点や大文字・小文字
    REG = {
      "が"=>"か",
      "ぎ"=>"き",
      "ぐ"=>"く",
      "げ"=>"け",
      "ご"=>"こ",
      "ざ"=>"さ",
      "じ"=>"し",
      "ず"=>"す",
      "ぜ"=>"せ",
      "ぞ"=>"そ",
      "だ"=>"た",
      "ぢ"=>"ち",
      "づ"=>"つ",
      "で"=>"て",
      "ど"=>"と",
      "ば"=>"は",
      "び"=>"ひ",
      "ぶ"=>"ふ",
      "べ"=>"へ",
      "ぼ"=>"ほ",
      "ぱ"=>"は",
      "ぴ"=>"ひ",
      "ぷ"=>"ふ",
      "ぺ"=>"へ",
      "ぽ"=>"ほ",
      "ぁ"=>"あ",
      "ぃ"=>"い",
      "ぅ"=>"う",
      "ぇ"=>"え",
      "ぉ"=>"お",
      "ゃ"=>"や",
      "ゅ"=>"ゆ",
      "ょ"=>"よ",
      "っ"=>"つ",
      "ガ"=>"カ",
      "ギ"=>"キ",
      "グ"=>"ク",
      "ゲ"=>"ケ",
      "ゴ"=>"コ",
      "ザ"=>"サ",
      "ジ"=>"シ",
      "ズ"=>"ス",
      "ゼ"=>"セ",
      "ゾ"=>"ソ",
      "ダ"=>"タ",
      "ヂ"=>"チ",
      "ヅ"=>"ツ",
      "デ"=>"テ",
      "ド"=>"ト",
      "バ"=>"ハ",
      "ビ"=>"ヒ",
      "ブ"=>"フ",
      "ベ"=>"ヘ",
      "ボ"=>"ホ",
      "パ"=>"ハ",
      "ピ"=>"ヒ",
      "プ"=>"フ",
      "ペ"=>"ヘ",
      "ポ"=>"ホ",
      "ァ"=>"ア",
      "ィ"=>"イ",
      "ゥ"=>"ウ",
      "ェ"=>"エ",
      "ォ"=>"オ",
      "ャ"=>"ヤ",
      "ュ"=>"ユ",
      "ョ"=>"ヨ",
      "ッ"=>"ツ",
    }

    def reg(ch)
      ch = ch.downcase
      REG.fetch(ch) rescue ch
    end

    # 文字を頂点、有向辺を与えられた単語（先頭文字を起点、末尾文字を終点とする辺）とする
    # グラフを考え、単語集合から頂点集合および辺集合を得る
    # links: 与えられた単語一覧を、先頭文字と末尾文字の組で分類する
    # キーは先頭文字と末尾文字を並べたもの、値は単語を配列に格納したもの
    # {"AZ" => ["ATZ", "ABCZ", "AAZZ"], ...}
    def create_links_and_nodes(words)
      links = Hash.new{ |hash, key| hash[key] = [] }
      nodes_tmp = Set.new
      
      words.each do |w|
        r0 = reg(w[0])
        r1 = reg(w[-1])
        r1 = reg(w[-2]) if r1 == "ー"
        
        links[r0+r1] << w
        nodes_tmp << r0
        nodes_tmp << r1
      end
      
      [links, nodes_tmp.to_a.sort]
    end
    private :create_links_and_nodes

    def initialize(words)
      # ---------- 単語集合からグラフ情報を得る
      @words = words
      @links, @nodes = create_links_and_nodes(words)
    end
    attr_reader :links, :nodes, :words
  end

  class OptimalEdges
    GLP_CONSTANTS = Hash[*(Rglpk.constants.map{ |c| [Rglpk.const_get(c), c] }.flatten(1))]

    # 連結成分を取得する
    # 返り値は[辺集合, 頂点集合]。辺集合は名前、頂点集合は番号。
    # ※頂点集合は番号で見るとダミー起点とダミー終点が重複しているのが気になるが、
    #   この問題の場合、ダミー起点とダミー終点は必ずともに連結成分に含まれるので問題ない
    def retrieve_connected_edges_and_nodes(nodes, nodes_begin, nodes_end, cols)
      visited = Set.new
      stack = [nodes.size]
      result_edges = Multiset.new
      
      until stack.empty?
        n = stack.pop
        next if visited.include?(n)
        visited << n # 番号で見るとダミー起点とダミー終点が重複しているのが気になるが、
                    # ダミー終点からの移動は考慮する必要がないので問題なし
        
        nodes_end.each_index do |j|
          if cols[n * nodes_end.size + j].mip_val > 0
            stack << j
            
            result_edges.add(nodes_begin[n]+nodes_end[j], cols[n * nodes_end.size + j].mip_val)
          end
        end
      end
      [result_edges, visited]
    end
    private :retrieve_connected_edges_and_nodes

    def xor(a, b)
      (!!a)^(!!b)
    end
    
    def initialize(sh_prob)
      nodes_begin = sh_prob.nodes + ["^"] # 起点となれる文字（現れる全文字＋ダミー起点文字）
      nodes_end = sh_prob.nodes + ["$"]   # 終点となれる文字（現れる全文字＋ダミー終点文字）

      # ---------- 対応する整数計画問題のオブジェクトを生成する
      problem = Rglpk::Problem.new
      problem.name = "shiritori"
      problem.obj.dir = Rglpk::GLP_MAX
      
      # 制約式の名称および、制約式が取れる値の条件を入力。
      # 初期状態では制約式の数は(sh_prob.nodes.size)+2。あとで増えていく
      rows = problem.add_rows(sh_prob.nodes.size + 2)
      sh_prob.nodes.each_with_index do |n, i|
        rows[i].name = "C_#{n}" # ダミー以外の文字については入次数＝出次数
        rows[i].set_bounds(Rglpk::GLP_FX, 0.0, 0.0)
      end
      rows[sh_prob.nodes.size].name = "C_^" # ダミー起点文字からの出次数は1
      rows[sh_prob.nodes.size].set_bounds(Rglpk::GLP_FX, 1.0, 1.0)
      rows[sh_prob.nodes.size+1].name = "C_$" # ダミー終点文字への入次数は1
      rows[sh_prob.nodes.size+1].set_bounds(Rglpk::GLP_FX, 1.0, 1.0)
      
      # 変数（辺）の名称および、変数が取れる値の条件を入力。
      # 変数の数は(nodes_begin.size * nodes_end.size)で固定。
      # 起点がi、終点がjである辺は、cols[i * nodes_end.size + j] で表す。
      cols = problem.add_cols(nodes_begin.size * nodes_end.size)
      
      i = 0
      nodes_begin.each do |nb|
        nodes_end.each do |ne|
          cols[i].name = "x_#{nb},#{ne}"
          if nb == '^' || ne == '$'
            cols[i].set_bounds(Rglpk::GLP_DB, 0.0, 1.0)
          else
            if sh_prob.links["#{nb}#{ne}"].empty?
              cols[i].set_bounds(Rglpk::GLP_FX, 0.0, 0.0)
            else
              cols[i].set_bounds(Rglpk::GLP_DB, 0.0, sh_prob.links["#{nb}#{ne}"].size.to_f)
            end
          end
          cols[i].kind = Rglpk::GLP_IV
          
          i += 1
        end
      end
      
      # 何を最大化したいか示す係数。
      # 今回の場合は、全変数の総和なので、1.0を並べたものを与える。
      problem.obj.coefs = [1.0] * (nodes_begin.size * nodes_end.size)
      
      # 制約式と変数を結ぶ行列。
      mat = []
      # (1. ダミー以外の文字については、入次数＝出次数)
      sh_prob.nodes.each_with_index do |n, q|
        nodes_begin.each_with_index do |nb, i|
          nodes_end.each_with_index do |ne, j|
            if i == q && j != q
              mat << 1
            elsif i != q && j == q
              mat << -1
            else
              mat << 0
            end
          end
        end
      end
      # (2. ダミー起点文字からの出次数は1)
      nodes_begin.each_with_index do |nb, i|
        nodes_end.each_with_index do |ne, j|
          mat << (i == sh_prob.nodes.size ? 1 : 0)
        end
      end
      # (3. ダミー終点文字への入次数は1)
      nodes_begin.each_with_index do |nb, i|
        nodes_end.each_with_index do |ne, j|
          mat << (j == sh_prob.nodes.size ? 1 : 0)
        end
      end
      
      problem.set_matrix(mat)
      
      # ---------- 最長経路が確定するまでループ
      k = 0
      @best = []
      while true
        # まずは線形計画問題/整数計画問題を解く
        code = problem.simplex
        if code != 0
          STDERR.puts "Unexpected Error: Simplex solver ended with the code #{GLP_CONSTANTS[code]}."
          break
        end
          
        len = problem.obj.get
          
        code = problem.mip
        if code != 0
          STDERR.puts "Unexpected Error: MIP solver ended with the code #{GLP_CONSTANTS[code]}."
          break
        end
          
        len = problem.obj.mip
          
STDERR.puts "Current upper bound of length: #{len}"
        # 結果として得られた経路が連結か？
        connected_edges, connected_nodes = retrieve_connected_edges_and_nodes(sh_prob.nodes, nodes_begin, nodes_end, cols)
          
        # ----- 使った辺がすべて連結なら、そこで終了
        if len == connected_edges.size
          @best = connected_edges if connected_edges.size > @best.size
          break
        end
          
        # ----- 連結でない場合、
        if len < @best.size
          # もし今回「可能性あり」と判断された（連結ではないかもしれない）
          # 辺を集めても前回の結果に及ばない場合は打ち切り
          # （繰り返すたびに制約は増える＝結果がよくなることはない）
          break
        end
          
        # 今回連結と判断された辺が暫定1位か判定
        @best = connected_edges if connected_edges.size > @best.size
STDERR.puts "Current best length: #{@best.size}"
        
        # 制約「今回連結だった頂点の集合と、それ以外の集合の間で、少なくとも1つの辺がある」
        # を追加する
        row = problem.add_row
        row.name = "C_{k=#{k}"
        row.set_bounds(Rglpk::GLP_LO, 1.0, 0.0)
        
        nodes_begin.each_with_index do |nb, i|
          nodes_end.each_with_index do |ne, j|
            if i != nodes.size && j != nodes.size && xor(connected_nodes.include?(i), connected_nodes.include?(j))
              mat << 1
            else
              mat << 0
            end
          end
        end
        
        problem.set_matrix(mat)
        
        k += 1
STDERR.puts "k == #{k}"
      end
    end
    attr_reader :best
  end

  class OptimalPath
    def initialize(opt_edge)
      # ---------- 具体的に最長経路を出力
      best_nodes = opt_edge.best.each_item.map{ |e| e.chars.to_a }.flatten.uniq
      best_edges = opt_edge.best.deep_dup

      # 閉路を長さ1のものから順次抽出
      cycles = []
      cycle_size = 1
      while true
        # ループを抜ける条件：どの頂点についても出次数が1以下
        flag_loop_remains = false
        outdegs = Hash.new{ |hash, key| hash[key] = 0 }
        best_edges.each do |e|
          outdegs[e[0]] += 1
          if outdegs[e[0]] > 1
            flag_loop_remains = true
            break
          end
        end
        break unless flag_loop_remains
        
        # 長さcycle_sizeの閉路を見つける
        best_nodes.each do |n|
          stack = [[n]]
          found = false
          
          until stack.empty?
            s = stack.pop
            if s.size == cycle_size + 1
              if s[-1] == s[0]
                result = s.each_cons(2).map{ |x| x[0]+x[1] }
                result_ms = Multiset.new(result)
                if result_ms.subset?(best_edges)
                  best_edges.subtract!(result_ms)
                  cycles << result
                  found = true
                end
              end
              next
            end
            
            best_edges.each_item do |v|
              if v[0] == s[-1] && (s.size == cycle_size ? v[1] == s[0] : !(s.include?(v[1])) )
                stack << (s + [v[1]])
              end
            end
          end
          
          redo if found
        end
        
        cycle_size += 1
      end
      
      # 残ったbest_edgesを並び替え、適宜cyclesを繋ぐ
      @cycles = cycles.deep_dup
      
      @path = []
      @noncycle_path = []
      queue = []
      w = "*^" # * is dummy
      while true
        if queue.empty?
          break if best_edges.empty?
          # 進める
          w = best_edges.find{ |x| x[0] == w[1] }
          raise "Unexpected error" unless w
          best_edges.delete(w)
          @noncycle_path << w
        else
          w = queue.shift # assumes w[0] == w_old[1]
        end
        
        @path << w
        break if w[1] == "$"
        
        # 当該文字の閉路があれば入れる
        matching_cycles, cycles = cycles.partition{ |x| x.first[0] == w[1] }
        matching_cycles.reverse.each{ |x| queue = x + queue }
      end
      
      #assert(best_edges.empty?)
      #assert(cycles.empty?)
      
      @path.pop
      @path.shift
      @noncycle_path.pop
      @noncycle_path.shift
    end
    attr_reader :cycles, :noncycle_path, :path
    # @cyclesは閉路集合、@noncycle_pathは閉路を抜き取った残りの経路、@pathは全経路
  end
end

class ShiritoriSolver
  def initialize(words)
    @sh_prob = ShiritoriStatus::Problem.new(words)
    @opt_edge = ShiritoriStatus::OptimalEdges.new(@sh_prob)
    @opt_path = ShiritoriStatus::OptimalPath.new(@opt_edge)
  end

  def words
    @sh_prob.words
  end
  
  def links
    @sh_prob.links
  end
  
  def nodes
    @sh_prob.nodes
  end

  def optimal_edges
    @opt_edge.best
  end

  def cycles
    @opt_path.cycles
  end
  
  def noncycle_path
    @opt_path.noncycle_path
  end
  
  def path
    @opt_path.path
  end
  
  # 最終的な経路を表すクラス
  # @pathsは以下のいずれかを要素とする配列の配列
  # （1つの経路を表すのに配列が必要で、それが複数なのでさらに配列が必要）
  # - 単語が一つに決まっている場合
  #   "Word"
  # - "Word1", "Word2", ... から適当に1つ選んで使えばよい場合
  #   {:option => ["Word1", "Word2", ...], :dup => 1}: 
  # - "Word1", "Word2", ... から3つ選んで使えばよい場合
  #   （他の箇所にも同一の選択肢があり、それらは互いに異なるものを選ばないとならない）
  #   {:option => ["Word1", "Word2", ...], :dup => 3, :key => "AZ" :note => NUM}
  # @notesは、上記の最後の場合を表す注で、以下の形式のハッシュからなる配列
  #   {:begin => CHAR1, :end => CHAR2, :words => ["Word1", "Word2", ...], :count => 3}
  class Result
    def initialize(paths, notes)
      @paths = paths
      @notes = notes
    end
    attr_reader :paths, :notes
    
    def path_str(index, delimiter = " -> ", notemark = "*")
      if index < 0 || index >= @paths.size
        raise IndexError
      end
      
      path = @paths[index]
      
      path.map{ |x|
        if x.kind_of?(String)
          x
        else
          if x[:dup] == 1
            "(#{x[:option].join('|')})"
          else
            "#{notemark}#{x[:note]+1}:#{x[:key][0]}-#{x[:key][1]}"
          end
        end
      }.join(delimiter)
    end
    
    def note_str(index, formatter = lambda{|wlist, count| "#{count} of #{wlist.join('/')}"}, notemark = "*")
      "#{notemark}#{index+1}: #{formatter.call(@notes[index][:words], @notes[index][:count])}"
    end
    
    def to_s(formatter = lambda{|wlist, count| "#{count} of #{wlist.join('/')}"}, delimiter = " -> ", notemark = "*")
      @paths.each_index.map{ |i| path_str(i, delimiter, notemark) }.join("") + "\n" + @notes.each_index.map{ |i| note_str(i, formatter, notemark) }.join("\n")
    end
  end
  
  def ShiritoriSolver.extract(sh_prob, sh_path)
    result_count = Multiset.new(sh_path.path)
    used_count = Hash.new{ |hash, key| hash[key] = 0 }
    note_number = -1
    note_list = Hash.new{ |hash, key| note_number += 1; hash[key] = note_number }

    paths = []
    notes = []
    
    paths << []
    sh_path.path.each_with_index do |r, i|
      if result_count.count(r) == 1
        if sh_prob.links[r].size == 1
          paths.last << sh_prob.links[r][0]
        else
          paths.last << {:option => sh_prob.links[r], :dup => 1}
        end
      elsif result_count.count(r) == sh_prob.links[r].size
        paths.last << sh_prob.links[r][used_count[r]]
        used_count[r] += 1
      else
        paths.last << {:option => sh_prob.links[r], :dup => result_count.count(r), :key => r, :note => note_list[r]}
      end
    end
    
    note_list.keys.sort_by{ |r| note_list[r] }.each do |r|
      notes << {:begin => r[0], :end => r[1], :words => sh_prob.links[r], :count => result_count.count(r)}
    end
    
    Result.new(paths, notes)
  end
  
  def extract_result(result = @opt_path)
    ShiritoriSolver.extract(@sh_prob, result)
  end
end
