#!ruby -Ks
require 'test/unit'
require 'data_matrix'

class TestDataMatrix < Test::Unit::TestCase
  # for Object value test case.
  class DTO
    def initialize(key)
      @key=key
      @value='value'
    end
    def some_method
      "#{@key},#{@value}"
    end
  end

  def setup
    @dm = DataMatrix.new
  end

  # cellオブジェクトの参照
  def test01_cell01
    cell1 = @dm.cell("A","1")
    
    # cell には アドレスが設定されている。
    assert_equal('A',cell1.row_addr)
    assert_equal('1',cell1.col_addr)

    # 同じアドレスには同じCellオブジェクトが返却される。
    cell2 = @dm.cell("A","1")

    assert_equal(cell1.object_id, cell2.object_id)
  end

  # セル値の重ね合わせ無し
  def test02_cell_set_value
    cell = @dm.cell("A","1")
    cell.value="HELLO"
    assert_equal('HELLO',cell.value)
  end
  
  # セル値の重ね合わせ有り(ルール未指定)
  def test03_cell_set_value
    cell1 = @dm.cell("A","1")
    cell1.value="HELLO"
    cell2 = @dm.cell("A","1")
    assert_raise(DataMatrix::MergeRuleError){cell2.value="BYE"}
  end
  
  # セル値の重ね合わせ有り(ルール指定)
  def test04_cell_set_value
    @dm.when_cell_merge{|old, new| new } # 上書き

    cell1 = @dm.cell("A","1")
    cell1.value="HELLO"
    cell2 = @dm.cell("A","1")
    assert_nothing_raised(){cell2.value="BYE"}
    assert_equal('BYE',cell2.value)
  end

  # セル値の重ね合わせ有り(ルール指定)
  def test05_cell_set_value
    @dm.when_cell_merge{|old, new| "#{old.downcase},#{new.downcase}" }

    @dm.cell("A","1").value="HELLO"

    cell2 = @dm.cell("A","1")
    cell2.value="BYE"

    assert_equal('hello,bye',cell2.value)
  end

  # csv出力
  def test06_to_csv
    @dm.cell('A','1').value='Y'
    @dm.cell('B','2').value='Y'
    assert_equal(",1,2\nA,\"Y\",\nB,,\"Y\"\n",@dm.to_csv)
  end

  # 行列の固定化(行一覧の取得)
  def test07_set_frame
    @dm.row_frame=["A","B"]
    assert_equal(["A","B"],@dm.row_items)
  end
  
  # 行列の固定化(列一覧の取得)
  def test08_set_frame
    @dm.col_frame=["1","2"]
    assert_equal(["1","2"],@dm.col_items)
  end

  # 行列の固定化(固定行に対する制約違反　事前制約)
  def test09_set_frame
    @dm.row_frame=["A","B"]
    assert_raise(DataMatrix::FrameConstraintError){@dm.cell("C","1")}
  end

  # 行列の固定化(固定列に対する制約違反　事前制約)
  def test10_set_frame
    @dm.col_frame=["1","2"]
    assert_raise(DataMatrix::FrameConstraintError){@dm.cell("A","3")}
  end

  # 行列の固定化(固定行に対する制約違反　事後制約)
  def test11_set_frame
    @dm.cell("C","1")
    assert_raise(DataMatrix::FrameConstraintError){ @dm.row_frame=["A","B"] }
  end

  # 行列の固定化(固定列に対する制約違反　事後制約)
  def test12_set_frame
    @dm.cell("A","3")
    assert_raise(DataMatrix::FrameConstraintError){ @dm.col_frame=["1","2"] }
  end

  # 行列の固定化(CSV出力時の枠)
  def test13_set_frame
    @dm.cell('A','1').value='Y'
    @dm.cell('B','2').value='Y'
    @dm.row_frame=["A","B","C"]
    @dm.col_frame=["1","2","3"]
    assert_equal(",1,2,3\nA,\"Y\",,\nB,,\"Y\",\nC,,,\n",@dm.to_csv)
  end

  # セル値として任意オブジェクトを持てる
  def test14_object_value
    dto = DTO.new('a')
    @dm.cell("A","1").value = dto
    assert_equal(dto.object_id, @dm.cell("A","1").value.object_id)
  end

  # セル値として任意オブジェクトを持てる
  def test14_object_value
    dto = DTO.new('a')
    @dm.cell("A","1").value = dto
    assert_equal(dto.object_id, @dm.cell("A","1").value.object_id)
  end

  # セル値の表現ルール変更(デフォルトはto_s)
  def test15_cell_presentation
    dto = DTO.new('a')
    @dm.cell("A","1").value = dto
    @dm.when_format do |val|
      val.some_method
    end
    assert_equal(",1\nA,\"a,value\"\n",@dm.to_csv)
  end

  # マトリックスの結合(セルマージなし)
  def test16_merge_matrix
    dm1 = DataMatrix.new
    dm1.cell("A","1").value = 'Y'
    dm1.cell("B","2").value = 'Y'

    dm2 = DataMatrix.new
    dm2.cell("C","3").value = 'Y'
    dm2.cell("D","4").value = 'Y'

    dm1.merge(dm2)
    assert_equal(%w(A B C D),dm1.row_items)
    assert_equal(%w(1 2 3 4),dm1.col_items)
    assert_equal(",1,2,3,4\nA,\"Y\",,,\nB,,\"Y\",,\nC,,,\"Y\",\nD,,,,\"Y\"\n",dm1.to_csv)
  end

  # マトリックスの結合(セルマージあり)
  def test17_merge_matrix
    dm1 = DataMatrix.new
    dm1.cell("A","1").value = 'Y'
    dm1.cell("B","2").value = 'Y'

    dm2 = DataMatrix.new
    dm2.cell("C","3").value = 'Y'
    dm2.cell("A","1").value = '○'

    # マージルール無しは例外
    assert_raise(DataMatrix::MergeRuleError){ dm1.merge(dm2) }
    
    dm1.when_cell_merge{|old, new| new } # マージルール＝上書きを追加
    assert_nothing_raised{ dm1.merge(dm2) }

    assert_equal(%w(A B C),dm1.row_items)
    assert_equal(%w(1 2 3),dm1.col_items)
    assert_equal(",1,2,3\nA,\"○\",,\nB,,\"Y\",\nC,,,\"Y\"\n",dm1.to_csv)
  end

  # マトリックスの結合(行列固定制約 自身 行)
  def test18_merge_matrix
    dm1 = DataMatrix.new
    dm1.row_frame=%w(A B)
    dm1.cell("A","1").value = 'Y'
    dm1.cell("B","2").value = 'Y'

    dm2 = DataMatrix.new
    dm2.cell("C","3").value = 'Y'

    # マージしようとするとdm1側の制約違反
    assert_raise(DataMatrix::FrameConstraintError){ dm1.merge(dm2) }
  end

  # マトリックスの結合(行列固定制約 相手 行)
  def test19_merge_matrix
    dm1 = DataMatrix.new
    dm1.cell("A","1").value = 'Y'
    dm1.cell("B","2").value = 'Y'

    dm2 = DataMatrix.new
    dm2.row_frame=%w(A C)
    dm2.cell("C","3").value = 'Y'

    # マージしようとするとdm2側の制約違反
    assert_raise(DataMatrix::FrameConstraintError){ dm1.merge(dm2) }
  end

  # マトリックスの結合(行列固定制約 自身 列)
  def test20_merge_matrix
    dm1 = DataMatrix.new
    dm1.col_frame=%w(1 2)
    dm1.cell("A","1").value = 'Y'
    dm1.cell("B","2").value = 'Y'

    dm2 = DataMatrix.new
    dm2.cell("C","3").value = 'Y'

    # マージしようとするとdm1側の制約違反
    assert_raise(DataMatrix::FrameConstraintError){ dm1.merge(dm2) }
  end

  # マトリックスの結合(行列固定制約 相手 列)
  def test21_merge_matrix
    dm1 = DataMatrix.new
    dm1.cell("A","1").value = 'Y'
    dm1.cell("B","2").value = 'Y'

    dm2 = DataMatrix.new
    dm2.col_frame=%w(1 3)
    dm2.cell("C","3").value = 'Y'

    # マージしようとするとdm2側の制約違反
    assert_raise(DataMatrix::FrameConstraintError){ dm1.merge(dm2) }
  end
end

