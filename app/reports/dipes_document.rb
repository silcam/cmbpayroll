class DipesDocument < Fixy::Document

  @xresults

  def initialize(results)
    @xresults = results
  end


  def build
    count = 1
    @xresults.body.each do |row|
      append_record DipesRecord.new(count, row)
      count += 1
    end
  end

end
