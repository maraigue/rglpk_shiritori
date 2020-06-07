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

  class ProblemBuilder
    def ProblemBuilder.parse_range(range)
      if !range[0]
        if !range[1]
          raise ArgumentError, "Both bounds of a variable or a constraint must not be nil"
        else
          # LowerBound = -infinity
          [Rglpk::GLP_UP, 0, range[1]]
        end
      else
        if !range[1]
          # UpperBound = +infinity
          [Rglpk::GLP_LO, range[0], 0]
        else
          if range[0] == range[1]
            [Rglpk::GLP_FX, range[0], range[1]]
          else
            [Rglpk::GLP_DB, range[0], range[1]]
          end
        end
      end
    end

    # rglpkをそのまま使うには、何列目が何の変数なのか自分で把握しておかないとならないが、
    # これを任意の名前で管理できるようにする
    def initialize(options)
      @options = options
      @constraints = {} # @constraints[constraint_name] = [lower_bound_of_value, upper_bound_of_value]
      @variables = {} # @variables[variable_name] = [lower_bound_of_value, upper_bound_of_value]
      @coefficients = Hash.new{ |h, k| h[k] = {} } # @coefficients[constraint_name][variable_name] = coefficient_of_constraint
      @objective = {} # @objective[variable_name] = coefficient_of_objective
    end
    attr_reader :options, :constraints, :variables, :coefficients, :objective

    def build
      # Rglpk::Problem のオプションを設定
      @problem = Rglpk::Problem.new
      @options.each_pair do |key, val|
        if key !~ /\A[_A-Za-z][_0-9A-Za-z]*(\.[_A-Za-z][_0-9A-Za-z]*)*\z/
          raise ArgumentError, "Invalid option name: #{key}"
        end

        key_list = key.split(".")
        pos = @problem
        key_list.each_with_index do |key, i|
          if i == key_list.size - 1
            pos.__send__("#{key}=", val)
          else
            pos = pos.__send__(key)
          end
        end
      end

      constraint_names = @constraints.keys
      variable_names = @variables.keys

      # 変数を用意
      cols = @problem.add_cols(variable_names.size)
      variable_names.each_with_index do |var, j|
        cols[j].name = var
        bounds = ProblemBuilder.parse_range(@variables[var])
        cols[j].set_bounds(*bounds)
        if bounds[1].kind_of?(Integer) and bounds[2].kind_of?(Integer)
          cols[j].kind = Rglpk::GLP_IV
        else
          cols[j].kind = Rglpk::GLP_CV
        end
      end

      # 制約を用意
      rows = @problem.add_rows(constraint_names.size)
      constraint_names.each_with_index do |con, i|
        rows[i].name = con
        rows[i].set_bounds(*ProblemBuilder.parse_range(@constraints[con]))
      end

      # 最適化したい問題の係数を設定
      @objective.each_key do |var|
        unless @variables.include?(var)
          raise RuntimeError, "Objective function contains an undefined variable #{var.inspect}"
        end
      end
      @problem.obj.coefs = variable_names.map{ |var| @objective.fetch(var){ 0 } }

      # 係数を用意
      @coefficients.each_pair do |con, row|
        unless @constraints.include?(con)
          raise RuntimeError, "Coefficients contain an undefined constraint #{con.inspect}"
        end
        row.each_key do |var|
          unless @variables.include?(var)
            raise RuntimeError, "Coefficients contain an undefined variable #{var.inspect}"
          end
        end
      end

      mat = []
      constraint_names.each do |con|
        variable_names.each do |var|
          mat << @coefficients.fetch(con).fetch(var, 0)
        end
      end
      @problem.set_matrix(mat)

      @problem
    end
  end

  class OptimalEdges
    GLP_CONSTANTS = Hash[*(Rglpk.constants.map{ |c| [Rglpk.const_get(c), c] }.flatten(1))]

    # ダミー起点から辿ることのできる連結成分を取得する
    # 返り値は[辺集合, 頂点集合]。辺集合は名前、頂点集合は番号。
    # ※頂点集合は番号で見るとダミー起点とダミー終点が重複しているのが気になるが、
    #   この問題の場合、ダミー起点とダミー終点は必ずともに連結成分に含まれるので問題ない
    def retrieve_connected_edges_and_nodes(nodes, rglpk_problem)
      visited = Set.new
      stack = ["^"] # ダミー起点のみが入った状態
      result_edges = Multiset.new
      nodes_end = nodes + ["$"]
      
      until stack.empty?
        n = stack.pop
        next if visited.include?(n)
        visited << n
        
        nodes_end.each do |m|
          col = nil
          begin
            col = rglpk_problem.cols["edge_#{n}#{m}"]
          rescue ArgumentError
            # If no edge is found
            next
          end
          appearances = col.mip_val
          if appearances > 0
            stack << m
            
            result_edges.add("#{n}#{m}", appearances)
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
      pb = ProblemBuilder.new("name" => "shiritori", "obj.dir" => Rglpk::GLP_MAX)
      
      # 制約式の名称および、制約式が取れる値の条件を入力。
      # 初期状態では制約式の数は(sh_prob.nodes.size)+2。あとで増えていく

      sh_prob.nodes.each do |n|
        # ダミー以外の文字については入次数＝出次数
        pb.constraints["degree_#{n}"] = [0, 0]
      end
      pb.constraints["degree_^"] = [1, 1] # ダミー起点文字からの出次数は1
      pb.constraints["degree_$"] = [-1, -1] # ダミー終点文字への入次数は1
      
      # 変数（辺）の名称および、変数が取れる値の条件を入力
      # coefficientsは、出次数 - 入次数で計算
      sh_prob.nodes.each do |n|
        pb.variables["edge_^#{n}"] = [0, 1]
        pb.coefficients["degree_^"]["edge_^#{n}"] = 1
        pb.coefficients["degree_#{n}"]["edge_^#{n}"] = -1

        pb.variables["edge_#{n}$"] = [0, 1]
        pb.coefficients["degree_#{n}"]["edge_#{n}$"] = 1
        pb.coefficients["degree_$"]["edge_#{n}$"] = -1
      end

      sh_prob.links.each_pair do |link, words|
        pb.variables["edge_#{link}"] = [0, words.size]
        if link[0] != link[1]
          pb.coefficients["degree_#{link[0]}"]["edge_#{link}"] = 1
          pb.coefficients["degree_#{link[1]}"]["edge_#{link}"] = -1
        else
          pb.coefficients["degree_#{link[0]}"]["edge_#{link}"] = 0
          pb.coefficients["degree_#{link[1]}"]["edge_#{link}"] = 0
        end

        pb.objective["edge_#{link}"] = 1 # 何を最大化したいか示す係数
        # 今回の場合は、全変数の総和なので、1.0を並べたものを与える。
      end
      
      # ---------- 最長経路が確定するまでループ
      k = 0
      @best = []
      while true
        STDERR.puts "k == #{k}"
        rglpk_problem = pb.build

        # まずは線形計画問題/整数計画問題を解く
        code = rglpk_problem.simplex
        if code != 0
          STDERR.puts "Unexpected Error: Simplex solver ended with the code #{GLP_CONSTANTS[code]}."
          break
        end
          
        len = rglpk_problem.obj.get
          
        code = rglpk_problem.mip
        if code != 0
          STDERR.puts "Unexpected Error: MIP solver ended with the code #{GLP_CONSTANTS[code]}."
          break
        end
          
        len = rglpk_problem.obj.mip - sh_prob.words.size * k
          
STDERR.puts "Current upper bound of length: #{len}"
        # 結果として得られた経路が連結か？
        connected_edges, connected_nodes = retrieve_connected_edges_and_nodes(sh_prob.nodes, rglpk_problem)
        
        # ----- 使った辺がすべて連結なら、そこで終了
        if len == connected_edges.size - 2 # ダミー始点やダミー終点も含んでいるため、2つ減らさないとならない。
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
STDERR.puts "Current best length (picking up only connected): #{@best.size - 2}"
        
        # 変数「今回連結だった頂点の集合と、それ以外の集合の間を結ぶような辺を使ったこと」を追加する
        # これが一つも利用されなかった場合、スコアが強制的に引き下げられる（全単語数分だけ引かれる）
        pb.variables["connected_#{k}"] = [0, 1]
        pb.constraints["set_connected_#{k}"] = [0, nil]
        sh_prob.links.each_key do |link|
          if xor(connected_nodes.include?(link[0]), connected_nodes.include?(link[1]))
            pb.coefficients["set_connected_#{k}"]["edge_#{link}"] = 1
          end
        end
        pb.coefficients["set_connected_#{k}"]["connected_#{k}"] = -1
        pb.objective["connected_#{k}"] = sh_prob.words.size

        k += 1
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
