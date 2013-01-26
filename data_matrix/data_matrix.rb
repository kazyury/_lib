#!ruby -Ks

#= DataMatrix
#  データのマトリックス表を簡易なAPIで作成するユーティリティ
#== how to use(sample)
#    require 'data_matrix'                         # DataMatrixを使用する準備
#    dm = DataMatrix.new                           # 
#
#    dm.when_cell_merge{|old,new| old }            # 同一セルが存在するときのマージルール＝旧値を使用
#    File.foreach('global_export.txt') do |line|   # 
#      ns,gbl =line.chomp.split(' ')               #
#      dm.cell(gbl,ns).value='○'                  # DataMatrixのセル(gbl,ns)の値に○を設定
#    end                                           # 既に同一のセルに値が設定されている場合にはwhen_cell_mergeが適用される。
#                                                  #
#    print dm.to_csv                               # DataMatrixをCSV形式で出力
class DataMatrix
  # マージルール例外クラス
  class MergeRuleError < RuntimeError; end
  # 行列制約違反例外クラス
  class FrameConstraintError < RuntimeError; end

  # セルを表現するクラス
  class Cell
    def initialize(row, col)
      # セル行アドレス(Stringを想定)
      @row_addr = row 
      # セル列アドレス(Stringを想定)
      @col_addr = col 
      # セル値(任意のObjectを想定)
      @value = nil    
      #:nodoc: セル値の重ねあわせ時ルール
      @merge_rule = nil 
    end
    attr_reader :row_addr, :col_addr, :value

    def inspect()
      "[#{row_addr},#{col_addr}]=[#{value}] with [#{@merge_rule}]"
    end

    # セル値を設定する。
    # セル値が既に設定されている場合には、merge_ruleに基づいて処理される。
    # ==== Args
    # val :: セルの値(任意のObject).デフォルトでto_sでformatされるので、必要に応じてDataMatrix#when_formatを利用。
    def value=(val)
      if @value
        @value = @merge_rule.call(@value, val)
      else
        @value = val
      end
    end

    def merge_rule(b)
      @merge_rule = b
    end
  end

  # 初期化処理
  # セル配列の内部表現と各種ルール類の初期値を設定する。
  def initialize
    @cells=[]
    @row_frame=nil  # 固定の行アドレス
    @col_frame=nil  # 固定の列アドレス
    # マージルール. デフォルトはMergeRuleErrorの送出
    @merge_rule = Proc.new{|old,new| raise MergeRuleError.new("Merge rule is not set. use DataMatrix#when_cell_merge().")}
    # フォーマットルール. デフォルトはto_s
    @format_rule = Proc.new{|value| value.to_s}
  end
  attr_reader :cells

  # Cellへの参照を返す。
  # 指定されたアドレスのCellが存在しない場合には、新規Cellを返却する。
  # ただし行列が固定化されている場合、その範囲内にアドレスがなければ例外を送出。
  # ==== Args
  # row_addr :: Cellの行位置(Stringを想定している。)
  # col_addr :: Cellの列位置(Stringを想定している。)
  def cell(row_addr, col_addr)
    check_frame_constraint(row_addr, col_addr)

    a_cell = find_cell(row_addr, col_addr)
    unless a_cell
      a_cell = Cell.new(row_addr, col_addr)
      @cells.push a_cell
    end
    # merge_ruleを適用
    a_cell.merge_rule(@merge_rule)
    a_cell
  end


  # 行アドレスの一覧を返却する。
  # 行アドレスが固定されているときにはその値を返却する。
  def row_items
    if @row_frame
      return @row_frame
    else
      @cells.map{|c| c.row_addr}.sort.uniq
    end
  end
  
  # 列アドレスの一覧を返却する。
  # 列アドレスが固定されているときにはその値を返却する。
  def col_items
    if @col_frame
      return @col_frame
    else
      @cells.map{|c| c.col_addr}.sort.uniq
    end
  end

  # 行アドレスを固定する。
  # 範囲外のセルが既に設定されている場合には例外を送出する。
  # ==== Args
  # row_frame :: 行アイテム一覧の配列(Array)
  def row_frame=(row_frame)
    @row_frame = row_frame.sort.uniq
    if err = @cells.find{|c| ! @row_frame.include?(c.row_addr) }
      raise FrameConstraintError.new("Cannot set frame due to cell[#{err.row_addr},#{err.col_addr}]")
    end
  end
  
  # 列アドレスを固定する。
  # 範囲外のセルが既に設定されている場合には例外を送出する。
  # ==== Args
  # col_frame :: 列アイテム一覧の配列(Array)
  def col_frame=(col_frame)
    @col_frame = col_frame.sort.uniq
    if err = @cells.find{|c| ! @col_frame.include?(c.col_addr) }
      raise FrameConstraintError.new("Cannot set frame due to cell[#{err.row_addr},#{err.col_addr}]")
    end
  end

  # 同一アドレスのセルが存在する場合に、値の上書きを試行した際のルールをブロックで登録する。
  # ブロック引数は2つであり、第一引数には既に設定されているvalueを、第二引数には新たに設定しようとしているvalueが設定される。
  # ==== Args
  # &b :: マージルールブロック
  def when_cell_merge(&b)
    raise unless block_given?
    @merge_rule = b
  end

  # セル値をCSVなどに表現する際の表現ルールをブロックで登録する。
  # ブロック引数は1つであり、セル値に格納されているオブジェクトが渡される。
  # ==== Args
  # &b :: フォーマットルールブロック
  def when_format(&b)
    raise unless block_given?
    @format_rule = b
  end

  
  # マトリックスをマージする。
  # マージする際に、行列の重複がある場合にはマージルールが適用される。
  # 行列制約がある場合には、その制約が適用される。(自身の制約＋相手の制約)
  # ==== Args
  # other :: 別のDataMatrixオブジェクト
  def merge(other)

    # 自Cellが相手方の行列制約に抵触しないか?
    @cells.each{|c|other.check_frame_constraint(c.row_addr, c.col_addr)}

    other.cells.each do |c|
      # 相手Cellが自身の行列制約に抵触しないか？
      check_frame_constraint(c.row_addr, c.col_addr)

      if a_cell = find_cell(c.row_addr, c.col_addr)
        a_cell.merge_rule(@merge_rule)
        a_cell.value=c.value
      else
        c.merge_rule(@merge_rule)
        @cells.push c
      end
    end
  end


  # csv形式の文字列で返却する。
  # セル値が設定されている場合には必ず""で括られる。
  # セル値に"が含まれる場合には""でescapeされる。
  # TODO セル値にCR+LFが含まれる場合には、LFに置換される。(\rを除去)
  def to_csv
    row_item_list = self.row_items()
    col_item_list = self.col_items()

    # ヘッダ行
    csv =","+col_item_list.join(',')+"\n"

    # データ行
    row_item_list.each do |rowidx|
      csv +="#{rowidx},"
      col_item_list.each do |colidx|
        a_cell = find_cell(rowidx, colidx)
        if a_cell
          # セルの表現ルールを適用し、CSV用の加工を行う。
          value = @format_rule.call(a_cell.value)
          value.gsub!(/"/,'"""')
          value.tr!("\r",'') # TODO:windowsでのCR削除はこれでOK?
          csv +='"'+value+'",'
        else
          csv +=','
        end
      end
      csv = csv[0..-2]+"\n" # 行末の , を除去して改行
    end
    csv
  end


  # 行列制約のチェック
  # @cellsに追加する際にはこのメソッドを呼ぶ必要がある。
  # ==== Args
  # row_addr :: 行アドレス
  protected
  def check_frame_constraint(row_addr, col_addr)
    raise FrameConstraintError.new("#{row_addr} is not included in row_frame") if @row_frame && !@row_frame.include?(row_addr)
    raise FrameConstraintError.new("#{col_addr} is not included in col_frame") if @col_frame && !@col_frame.include?(col_addr)
  end


  private
  # セルを発見する。
  def find_cell(row_addr, col_addr)
    @cells.find{|x| x.row_addr == row_addr && x.col_addr == col_addr}
  end


end
