#!ruby -Ks

require 'data_matrix'

dm = DataMatrix.new
File.foreach('global_export.txt') do |line|
  ns,gbl =line.chomp.split(' ')
  dm.cell(gbl,ns).value='Åõ'
end

print dm.to_csv
