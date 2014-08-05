class PageLine
  attr_accessor :columns, :begin_position, :end_position, :height, :type, :line_types, :scope_index, :char_indexes, :children_page_number

  def initialize char, char_index, children_page_number=0
    @columns = []
    @begin_position = char.x
    @height         = char.y
    @end_position   = char.x
    @type = :text
    @line_types = Set.new
    #scope_index 是为table服务的
    @scope_index = []
    @char_indexes = Set.new [char_index]
    @children_page_number = children_page_number
  end

  def <=> other
  end

  def << content
    @columns << content
  end

  def copy_attributes_without_columns line
    self.instance_variables.each do |variable|
      next if variable == :@columns
      self.instance_variable_set variable, line.instance_variable_get(variable)
    end
  end

  def line_text
    columns.map(&:text).join("  ")
  end
end