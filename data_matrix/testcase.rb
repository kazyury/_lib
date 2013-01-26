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

  # cell�I�u�W�F�N�g�̎Q��
  def test01_cell01
    cell1 = @dm.cell("A","1")
    
    # cell �ɂ� �A�h���X���ݒ肳��Ă���B
    assert_equal('A',cell1.row_addr)
    assert_equal('1',cell1.col_addr)

    # �����A�h���X�ɂ͓���Cell�I�u�W�F�N�g���ԋp�����B
    cell2 = @dm.cell("A","1")

    assert_equal(cell1.object_id, cell2.object_id)
  end

  # �Z���l�̏d�ˍ��킹����
  def test02_cell_set_value
    cell = @dm.cell("A","1")
    cell.value="HELLO"
    assert_equal('HELLO',cell.value)
  end
  
  # �Z���l�̏d�ˍ��킹�L��(���[�����w��)
  def test03_cell_set_value
    cell1 = @dm.cell("A","1")
    cell1.value="HELLO"
    cell2 = @dm.cell("A","1")
    assert_raise(DataMatrix::MergeRuleError){cell2.value="BYE"}
  end
  
  # �Z���l�̏d�ˍ��킹�L��(���[���w��)
  def test04_cell_set_value
    @dm.when_cell_merge{|old, new| new } # �㏑��

    cell1 = @dm.cell("A","1")
    cell1.value="HELLO"
    cell2 = @dm.cell("A","1")
    assert_nothing_raised(){cell2.value="BYE"}
    assert_equal('BYE',cell2.value)
  end

  # �Z���l�̏d�ˍ��킹�L��(���[���w��)
  def test05_cell_set_value
    @dm.when_cell_merge{|old, new| "#{old.downcase},#{new.downcase}" }

    @dm.cell("A","1").value="HELLO"

    cell2 = @dm.cell("A","1")
    cell2.value="BYE"

    assert_equal('hello,bye',cell2.value)
  end

  # csv�o��
  def test06_to_csv
    @dm.cell('A','1').value='Y'
    @dm.cell('B','2').value='Y'
    assert_equal(",1,2\nA,\"Y\",\nB,,\"Y\"\n",@dm.to_csv)
  end

  # �s��̌Œ艻(�s�ꗗ�̎擾)
  def test07_set_frame
    @dm.row_frame=["A","B"]
    assert_equal(["A","B"],@dm.row_items)
  end
  
  # �s��̌Œ艻(��ꗗ�̎擾)
  def test08_set_frame
    @dm.col_frame=["1","2"]
    assert_equal(["1","2"],@dm.col_items)
  end

  # �s��̌Œ艻(�Œ�s�ɑ΂��鐧��ᔽ�@���O����)
  def test09_set_frame
    @dm.row_frame=["A","B"]
    assert_raise(DataMatrix::FrameConstraintError){@dm.cell("C","1")}
  end

  # �s��̌Œ艻(�Œ��ɑ΂��鐧��ᔽ�@���O����)
  def test10_set_frame
    @dm.col_frame=["1","2"]
    assert_raise(DataMatrix::FrameConstraintError){@dm.cell("A","3")}
  end

  # �s��̌Œ艻(�Œ�s�ɑ΂��鐧��ᔽ�@���㐧��)
  def test11_set_frame
    @dm.cell("C","1")
    assert_raise(DataMatrix::FrameConstraintError){ @dm.row_frame=["A","B"] }
  end

  # �s��̌Œ艻(�Œ��ɑ΂��鐧��ᔽ�@���㐧��)
  def test12_set_frame
    @dm.cell("A","3")
    assert_raise(DataMatrix::FrameConstraintError){ @dm.col_frame=["1","2"] }
  end

  # �s��̌Œ艻(CSV�o�͎��̘g)
  def test13_set_frame
    @dm.cell('A','1').value='Y'
    @dm.cell('B','2').value='Y'
    @dm.row_frame=["A","B","C"]
    @dm.col_frame=["1","2","3"]
    assert_equal(",1,2,3\nA,\"Y\",,\nB,,\"Y\",\nC,,,\n",@dm.to_csv)
  end

  # �Z���l�Ƃ��ĔC�ӃI�u�W�F�N�g�����Ă�
  def test14_object_value
    dto = DTO.new('a')
    @dm.cell("A","1").value = dto
    assert_equal(dto.object_id, @dm.cell("A","1").value.object_id)
  end

  # �Z���l�Ƃ��ĔC�ӃI�u�W�F�N�g�����Ă�
  def test14_object_value
    dto = DTO.new('a')
    @dm.cell("A","1").value = dto
    assert_equal(dto.object_id, @dm.cell("A","1").value.object_id)
  end

  # �Z���l�̕\�����[���ύX(�f�t�H���g��to_s)
  def test15_cell_presentation
    dto = DTO.new('a')
    @dm.cell("A","1").value = dto
    @dm.when_format do |val|
      val.some_method
    end
    assert_equal(",1\nA,\"a,value\"\n",@dm.to_csv)
  end

  # �}�g���b�N�X�̌���(�Z���}�[�W�Ȃ�)
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

  # �}�g���b�N�X�̌���(�Z���}�[�W����)
  def test17_merge_matrix
    dm1 = DataMatrix.new
    dm1.cell("A","1").value = 'Y'
    dm1.cell("B","2").value = 'Y'

    dm2 = DataMatrix.new
    dm2.cell("C","3").value = 'Y'
    dm2.cell("A","1").value = '��'

    # �}�[�W���[�������͗�O
    assert_raise(DataMatrix::MergeRuleError){ dm1.merge(dm2) }
    
    dm1.when_cell_merge{|old, new| new } # �}�[�W���[�����㏑����ǉ�
    assert_nothing_raised{ dm1.merge(dm2) }

    assert_equal(%w(A B C),dm1.row_items)
    assert_equal(%w(1 2 3),dm1.col_items)
    assert_equal(",1,2,3\nA,\"��\",,\nB,,\"Y\",\nC,,,\"Y\"\n",dm1.to_csv)
  end

  # �}�g���b�N�X�̌���(�s��Œ萧�� ���g �s)
  def test18_merge_matrix
    dm1 = DataMatrix.new
    dm1.row_frame=%w(A B)
    dm1.cell("A","1").value = 'Y'
    dm1.cell("B","2").value = 'Y'

    dm2 = DataMatrix.new
    dm2.cell("C","3").value = 'Y'

    # �}�[�W���悤�Ƃ����dm1���̐���ᔽ
    assert_raise(DataMatrix::FrameConstraintError){ dm1.merge(dm2) }
  end

  # �}�g���b�N�X�̌���(�s��Œ萧�� ���� �s)
  def test19_merge_matrix
    dm1 = DataMatrix.new
    dm1.cell("A","1").value = 'Y'
    dm1.cell("B","2").value = 'Y'

    dm2 = DataMatrix.new
    dm2.row_frame=%w(A C)
    dm2.cell("C","3").value = 'Y'

    # �}�[�W���悤�Ƃ����dm2���̐���ᔽ
    assert_raise(DataMatrix::FrameConstraintError){ dm1.merge(dm2) }
  end

  # �}�g���b�N�X�̌���(�s��Œ萧�� ���g ��)
  def test20_merge_matrix
    dm1 = DataMatrix.new
    dm1.col_frame=%w(1 2)
    dm1.cell("A","1").value = 'Y'
    dm1.cell("B","2").value = 'Y'

    dm2 = DataMatrix.new
    dm2.cell("C","3").value = 'Y'

    # �}�[�W���悤�Ƃ����dm1���̐���ᔽ
    assert_raise(DataMatrix::FrameConstraintError){ dm1.merge(dm2) }
  end

  # �}�g���b�N�X�̌���(�s��Œ萧�� ���� ��)
  def test21_merge_matrix
    dm1 = DataMatrix.new
    dm1.cell("A","1").value = 'Y'
    dm1.cell("B","2").value = 'Y'

    dm2 = DataMatrix.new
    dm2.col_frame=%w(1 3)
    dm2.cell("C","3").value = 'Y'

    # �}�[�W���悤�Ƃ����dm2���̐���ᔽ
    assert_raise(DataMatrix::FrameConstraintError){ dm1.merge(dm2) }
  end
end

