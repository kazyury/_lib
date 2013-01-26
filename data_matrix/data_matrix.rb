#!ruby -Ks

#= DataMatrix
#  �f�[�^�̃}�g���b�N�X�\���ȈՂ�API�ō쐬���郆�[�e�B���e�B
#== how to use(sample)
#    require 'data_matrix'                         # DataMatrix���g�p���鏀��
#    dm = DataMatrix.new                           # 
#
#    dm.when_cell_merge{|old,new| old }            # ����Z�������݂���Ƃ��̃}�[�W���[�������l���g�p
#    File.foreach('global_export.txt') do |line|   # 
#      ns,gbl =line.chomp.split(' ')               #
#      dm.cell(gbl,ns).value='��'                  # DataMatrix�̃Z��(gbl,ns)�̒l�Ɂ���ݒ�
#    end                                           # ���ɓ���̃Z���ɒl���ݒ肳��Ă���ꍇ�ɂ�when_cell_merge���K�p�����B
#                                                  #
#    print dm.to_csv                               # DataMatrix��CSV�`���ŏo��
class DataMatrix
  # �}�[�W���[����O�N���X
  class MergeRuleError < RuntimeError; end
  # �s�񐧖�ᔽ��O�N���X
  class FrameConstraintError < RuntimeError; end

  # �Z����\������N���X
  class Cell
    def initialize(row, col)
      # �Z���s�A�h���X(String��z��)
      @row_addr = row 
      # �Z����A�h���X(String��z��)
      @col_addr = col 
      # �Z���l(�C�ӂ�Object��z��)
      @value = nil    
      #:nodoc: �Z���l�̏d�˂��킹�����[��
      @merge_rule = nil 
    end
    attr_reader :row_addr, :col_addr, :value

    def inspect()
      "[#{row_addr},#{col_addr}]=[#{value}] with [#{@merge_rule}]"
    end

    # �Z���l��ݒ肷��B
    # �Z���l�����ɐݒ肳��Ă���ꍇ�ɂ́Amerge_rule�Ɋ�Â��ď��������B
    # ==== Args
    # val :: �Z���̒l(�C�ӂ�Object).�f�t�H���g��to_s��format�����̂ŁA�K�v�ɉ�����DataMatrix#when_format�𗘗p�B
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

  # ����������
  # �Z���z��̓����\���Ɗe�탋�[���ނ̏����l��ݒ肷��B
  def initialize
    @cells=[]
    @row_frame=nil  # �Œ�̍s�A�h���X
    @col_frame=nil  # �Œ�̗�A�h���X
    # �}�[�W���[��. �f�t�H���g��MergeRuleError�̑��o
    @merge_rule = Proc.new{|old,new| raise MergeRuleError.new("Merge rule is not set. use DataMatrix#when_cell_merge().")}
    # �t�H�[�}�b�g���[��. �f�t�H���g��to_s
    @format_rule = Proc.new{|value| value.to_s}
  end
  attr_reader :cells

  # Cell�ւ̎Q�Ƃ�Ԃ��B
  # �w�肳�ꂽ�A�h���X��Cell�����݂��Ȃ��ꍇ�ɂ́A�V�KCell��ԋp����B
  # �������s�񂪌Œ艻����Ă���ꍇ�A���͈͓̔��ɃA�h���X���Ȃ���Η�O�𑗏o�B
  # ==== Args
  # row_addr :: Cell�̍s�ʒu(String��z�肵�Ă���B)
  # col_addr :: Cell�̗�ʒu(String��z�肵�Ă���B)
  def cell(row_addr, col_addr)
    check_frame_constraint(row_addr, col_addr)

    a_cell = find_cell(row_addr, col_addr)
    unless a_cell
      a_cell = Cell.new(row_addr, col_addr)
      @cells.push a_cell
    end
    # merge_rule��K�p
    a_cell.merge_rule(@merge_rule)
    a_cell
  end


  # �s�A�h���X�̈ꗗ��ԋp����B
  # �s�A�h���X���Œ肳��Ă���Ƃ��ɂ͂��̒l��ԋp����B
  def row_items
    if @row_frame
      return @row_frame
    else
      @cells.map{|c| c.row_addr}.sort.uniq
    end
  end
  
  # ��A�h���X�̈ꗗ��ԋp����B
  # ��A�h���X���Œ肳��Ă���Ƃ��ɂ͂��̒l��ԋp����B
  def col_items
    if @col_frame
      return @col_frame
    else
      @cells.map{|c| c.col_addr}.sort.uniq
    end
  end

  # �s�A�h���X���Œ肷��B
  # �͈͊O�̃Z�������ɐݒ肳��Ă���ꍇ�ɂ͗�O�𑗏o����B
  # ==== Args
  # row_frame :: �s�A�C�e���ꗗ�̔z��(Array)
  def row_frame=(row_frame)
    @row_frame = row_frame.sort.uniq
    if err = @cells.find{|c| ! @row_frame.include?(c.row_addr) }
      raise FrameConstraintError.new("Cannot set frame due to cell[#{err.row_addr},#{err.col_addr}]")
    end
  end
  
  # ��A�h���X���Œ肷��B
  # �͈͊O�̃Z�������ɐݒ肳��Ă���ꍇ�ɂ͗�O�𑗏o����B
  # ==== Args
  # col_frame :: ��A�C�e���ꗗ�̔z��(Array)
  def col_frame=(col_frame)
    @col_frame = col_frame.sort.uniq
    if err = @cells.find{|c| ! @col_frame.include?(c.col_addr) }
      raise FrameConstraintError.new("Cannot set frame due to cell[#{err.row_addr},#{err.col_addr}]")
    end
  end

  # ����A�h���X�̃Z�������݂���ꍇ�ɁA�l�̏㏑�������s�����ۂ̃��[�����u���b�N�œo�^����B
  # �u���b�N������2�ł���A�������ɂ͊��ɐݒ肳��Ă���value���A�������ɂ͐V���ɐݒ肵�悤�Ƃ��Ă���value���ݒ肳���B
  # ==== Args
  # &b :: �}�[�W���[���u���b�N
  def when_cell_merge(&b)
    raise unless block_given?
    @merge_rule = b
  end

  # �Z���l��CSV�Ȃǂɕ\������ۂ̕\�����[�����u���b�N�œo�^����B
  # �u���b�N������1�ł���A�Z���l�Ɋi�[����Ă���I�u�W�F�N�g���n�����B
  # ==== Args
  # &b :: �t�H�[�}�b�g���[���u���b�N
  def when_format(&b)
    raise unless block_given?
    @format_rule = b
  end

  
  # �}�g���b�N�X���}�[�W����B
  # �}�[�W����ۂɁA�s��̏d��������ꍇ�ɂ̓}�[�W���[�����K�p�����B
  # �s�񐧖񂪂���ꍇ�ɂ́A���̐��񂪓K�p�����B(���g�̐���{����̐���)
  # ==== Args
  # other :: �ʂ�DataMatrix�I�u�W�F�N�g
  def merge(other)

    # ��Cell��������̍s�񐧖�ɒ�G���Ȃ���?
    @cells.each{|c|other.check_frame_constraint(c.row_addr, c.col_addr)}

    other.cells.each do |c|
      # ����Cell�����g�̍s�񐧖�ɒ�G���Ȃ����H
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


  # csv�`���̕�����ŕԋp����B
  # �Z���l���ݒ肳��Ă���ꍇ�ɂ͕K��""�Ŋ�����B
  # �Z���l��"���܂܂��ꍇ�ɂ�""��escape�����B
  # TODO �Z���l��CR+LF���܂܂��ꍇ�ɂ́ALF�ɒu�������B(\r������)
  def to_csv
    row_item_list = self.row_items()
    col_item_list = self.col_items()

    # �w�b�_�s
    csv =","+col_item_list.join(',')+"\n"

    # �f�[�^�s
    row_item_list.each do |rowidx|
      csv +="#{rowidx},"
      col_item_list.each do |colidx|
        a_cell = find_cell(rowidx, colidx)
        if a_cell
          # �Z���̕\�����[����K�p���ACSV�p�̉��H���s���B
          value = @format_rule.call(a_cell.value)
          value.gsub!(/"/,'"""')
          value.tr!("\r",'') # TODO:windows�ł�CR�폜�͂����OK?
          csv +='"'+value+'",'
        else
          csv +=','
        end
      end
      csv = csv[0..-2]+"\n" # �s���� , ���������ĉ��s
    end
    csv
  end


  # �s�񐧖�̃`�F�b�N
  # @cells�ɒǉ�����ۂɂ͂��̃��\�b�h���ĂԕK�v������B
  # ==== Args
  # row_addr :: �s�A�h���X
  protected
  def check_frame_constraint(row_addr, col_addr)
    raise FrameConstraintError.new("#{row_addr} is not included in row_frame") if @row_frame && !@row_frame.include?(row_addr)
    raise FrameConstraintError.new("#{col_addr} is not included in col_frame") if @col_frame && !@col_frame.include?(col_addr)
  end


  private
  # �Z���𔭌�����B
  def find_cell(row_addr, col_addr)
    @cells.find{|x| x.row_addr == row_addr && x.col_addr == col_addr}
  end


end
