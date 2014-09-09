class Page
  attr_accessor :page_number, :page_title, :lines, :page_types, :children_page_count, :origin_page, :children_page_positions
  def initialize(page)
    @origin_page = page
    @page_number = page.number
    @lines = []
    @page_types = Set.new
  end

  def << page_line
    @lines << page_line
  end

  def is_catalog?
    @page_types.include?(:catalog)
  end

  def is_goto_table?
    @page_types.include?(:goto_table)
  end

  def width
    origin_page.width
  end

  def height
    origin_page.height
  end

  def analyze_children_page_count force=false
    return analyze_children_page_count_for_catalog_page if @page_types.include?(:catalog) and force
    positions = self.lines.map(&:begin_position).map(&:to_i)
    if positions.max - positions.min > 200
      @children_page_count = 2
    else
      @children_page_count = 1
    end
  end

  def analyze_children_page_count_for_catalog_page
    position_indexes = []
    last_height = -1
    lines.each_with_index do |line, index|
      if position_indexes.empty?
        position_indexes << [index, index]
        last_height = line.height
        next
      end
      if line.height > last_height
        position_indexes.last[1] = index - 1
        position_indexes << [index, index]
        last_height = line.height
        next
      end
      position_indexes.last[1] = index
      last_height = line.height
    end

    @children_page_positions = []
    total_count = 0
    position_indexes.each_with_index do |positions, index|
      flag = false
      x = 0
      lines[positions[0]..positions[1]].each do |line|
        line.columns.each do |column|
          if column.text.include?('.........')
            x +=1
            flag = true
            unless @children_page_positions[total_count]
              @children_page_positions[total_count] = [line.begin_position, line.end_position]
            end
            number_line = find_catalog_page_number line

            if line.end_position + 200 < number_line.end_position
              number_line = line 
            end
            #binding.pry if x >= 10

            #number_line = line
            if @children_page_positions[total_count]
              if @children_page_positions[total_count][0] > number_line.begin_position
                @children_page_positions[total_count][0] = number_line.begin_position
              end
              if @children_page_positions[total_count][1] < number_line.end_position
                @children_page_positions[total_count][1] = number_line.end_position
              end
            end
          end
        end
      end
      total_count += 1 if flag
    end
    return @children_page_positions.size
  end

  def find_catalog_page_number current_line
    return current_line if /^-/.match(current_line.columns.first.text)
    self.lines.each_with_index do |line, index|
      #puts line.height.to_s + "---" + line.columns.first.text + '---' + line.begin_position.to_s  + '---' + line.end_position.to_s
      if strict_same_line?(line.height, current_line.height)
        #puts @children_page_positions
        if line.begin_position >= current_line.end_position and line.columns.size == 1 and /^[0-9]*$/.match(line.columns[-1].text)
          return line
        end
        if line.columns.size == 3 and line.columns.first.text == 'A' and /^[0-9]*$/.match(line.columns[1].text)
          if /^[0-9]*$/.match(line.columns[-1].text) and line.columns.last.begin_position > current_line.end_position
            return line
          end
        end
      end
    end
    current_line
  end

  def strict_same_line? h1, h2
    (h1-h2).abs < 5
  end
end