$: << File.dirname(__FILE__) unless $:.include? File.dirname(__FILE__)

require 'pdf/reader'
require 'pry'
require 'sinatra'
require 'rack'
require 'slim'
require 'linguo'
require 'fileutils'
require 'sinatra/static_assets'

require 'image_analyzer'
require 'page_helpers/page_extension'
require 'page_helpers/page'
require 'page_helpers/page_line'
require 'page_helpers/image_line'
require 'page_helpers/content_column'

class PageAnalyzer
  attr_accessor :file_name, :current_pages, :current_page, :max_width, :pdf_reader, :current_children_page_number, :total_number
  
  def initialize(file_name)
  	@file_name = file_name
  	@pdf_reader = PDF::Reader.new(file_name)
  	@total_number = @pdf_reader.page_count
    @current_pages = []
    @max_width = -1
    @current_children_page_number = 1
  end

  def analyzer_page page
    @origin_page = page
    receiver = page.text_receiver
    @current_pages  <<  generate_new_page(page)

    @characters = receiver.instance_variable_get :@characters
    @analyze_count = 1
    @current_page = @current_pages[@analyze_count-1]
    analyzer_characters @characters
    
    #第二次 解析characters， 目的去掉 第一次 带来的误差

    @new_characters = sort_characters @characters

    @current_pages  <<  generate_new_page(page)
    @analyze_count = 2
    @current_page = @current_pages[@analyze_count-1]
    analyzer_characters @new_characters
  end

  def analyze_page_type page
    begin
      analyze_page_for_table_type page
    rescue Exception => e
      #puts e
    end
  end

  def analyze_page_for_table_type page
    goto_number = 0 # '=>'  符号出现的次数
    page.lines.each do |line|
      goto_number += 1 if text_is_goto_one_page? line.line_text
    end
    
    if goto_number > 5
      #认为 这个包含 表格, 默认这种表格 每行的td的个数是3个。
      page.page_types << :goto_table
      analyze_goto_table page
      return
    end

    analyze_page_for_common_table page
  end

  def analyze_page_for_common_table page
    table_line = []
    standard_table_line = []
    is_table = false
    page.lines.each_with_index do |line, index|
      next if line.type == :image
      next if line.columns.size == 1
      if table_line.empty?
        table_line << [[index, line.columns.size], [index, line.columns.size]]
        next
      end

      if line.columns.size == table_line.last[1][1]
        table_line.last[1] = [index, line.columns.size]
        next
      end

      table_line << [[index, line.columns.size], [index, line.columns.size]]
    end
    table_line.each do |bl|
      begin_index = bl[0][0]
      end_index   = bl[1][0]
      next if bl[0][0] == bl[1][0] or bl[0][1] < 3
      flag = true
      bl[0][1].times.each do |offset_index|
        begin_positions = []
        page.lines[begin_index..end_index].each do |line|
          begin_positions << line.columns[offset_index].begin_position
        end
        flag = false unless (strict_same_line? begin_positions[0], begin_positions[-1]) and (strict_same_line? begin_positions.max, begin_positions.min)
      end

      if flag
        page.lines[begin_index..end_index].each_with_index do |line, index|
          if index == 0
            line.line_types << :table_head
            standard_table_line << [begin_index, end_index]
            line.scope_index = [begin_index, end_index]
          else
            line.line_types << :table_body
          end
          is_table = true
        end
      end
    end

    return unless is_table

    table_index = standard_table_line.first[0]
    table_head = first_table_head = page.lines[table_index]
    page.lines[(table_index+1)..-1].each_with_index do |line, part_table_index|
      if same_rank?(line.columns.first.begin_position, table_head.columns.first.begin_position) \
            and same_rank?(line.columns.last.begin_position, table_head.columns.last.begin_position) \
            and line.columns.size ==  table_head.columns.size
        line.line_types <<     :table_body
        line.line_types.delete :table_head
        first_table_head.scope_index[1] = table_index + 1 + part_table_index
        next
      end
      if line.line_types.include?(:table_head)
        line.line_types.delete :table_head
        line.line_types <<     :table_body
        line.line_types.add :repeat_table_head
        table_head = line
        first_table_head.scope_index[1] = table_index + 1 + part_table_index
        next
      end
      if line.columns.size != table_head.columns.size
        #尝试解析重新解析 chares
        chars = []
        line.char_indexes.each do |char_index|
          chars << @new_characters[char_index]
        end
        begin_positions = table_head.columns.map(&:begin_position)

        position_index = 1
        chars.sort_by(&:x)
        if text_is_goto_one_page?(page.lines[table_index+1].columns.last.text) and text_is_goto_one_page? line.columns.last.text
          #重新生成columns
          columns = []
          chars.each do |char|
            if columns.empty?
              column = ContentColumn.new(char)
              columns << column
              next
            end

            if position_index == begin_positions.size or char.x.to_i < begin_positions[position_index].to_i
              columns.last << char
              next
            end
            column = ContentColumn.new(char)
            columns << column
            position_index += 1
          end
          line.line_types << :table_body
          line.columns = columns
          first_table_head.scope_index[1] = table_index + 1 + part_table_index
          next
        end
      end
      break
    end
  end

  def analyze_goto_table page
    #flag '=>第 x页'
    #1、找到每个子页面 有flag 的 lines
    # table_indexes 的组成 {chilren_page_number: []}
    #

    table_indexes = {}
    page.lines.each_with_index do |line, index|
      if text_is_goto_one_page? line.line_text
        page_number = line.children_page_number
        table_indexes[page_number] ||= []
        table_indexes[page_number] << index
      end
    end
    table_indexes.each do |page_number, line_indexes|
      analyze_goto_table_for_children_page page, line_indexes
    end
  end

  def analyze_goto_table_for_children_page page, line_indexes
    #获取每个td的平均起始横坐标
    #重新组合每行的td 内容
    begin_positions = []

    line_indexes.each do |line_index|
      columns = page.lines[line_index].columns
      next if columns.size != 3
      begin_positions << columns.map(&:begin_position)
    end
    
    average_positions = []
    begin_positions.first.size.times.each do |index| 
      average_positions <<  begin_positions.map{|item| item[index]}.inject(:+)/begin_positions.size
    end

    begin_index, end_index = line_indexes.first, line_indexes.last
    if text_is_goto_table_head? page.lines[begin_index-1].line_text

      begin_index = begin_index - 1
    end
    page.lines[begin_index..end_index].each_with_index do |line, index|
      #重新生成columns
      if index == 0
        line.line_types << :table_head
      else
        line.line_types << :table_body
      end

      line.scope_index = [begin_index, end_index]
      chars = []

      line.char_indexes.each do |char_index|
        chars << @new_characters[char_index]
      end

      char_columns = [[], [], []]
      chars.each do |char|
        average_positions[1..-1].each_with_index do |begin_position, average_index|
          if char.x + char.width < begin_position
            char_columns[average_index] << char
            break
          elsif average_index == average_positions.size - 2
            char_columns.last << char
            break
          end
        end
      end

      line_columns = []
      char_columns.each_with_index do |cs, index|
        new_cs = sort_chars_by_y_and_x cs

        new_cs.each do |char|
          unless line_columns[index]
            line_columns << ContentColumn.new(char)
          else
            line_columns.last << char
          end
        end
        line.columns = line_columns
      end
    end
  end

  def sort_chars_by_y_and_x chars
    #对一个chars 按照纵坐标优先、横坐标次之 进行排序
    new_chars_hash = {}
    chars.each do |char|
      same_height = nil
      
      new_chars_hash.keys.each do |key|
        same_height = key and next if strict_same_line? key, char.y
      end

      if same_height
        new_chars_hash[same_height] << char
      else
        new_chars_hash[char.y] = [char]
      end
    end

    new_chars_hash.each do |key, char_list|
      new_chars_hash[key] = char_list.sort_by(&:x)
    end

    new_chars_hash.sort.reverse.map(&:last).flatten
  end

  def text_is_goto_one_page? text
    /⇒第[0-9]+页/.match text.gsub(' ', '') and not /。/.match(text)
  end

  def text_is_goto_table_head? text
    /按钮说明页/.match text.gsub(' ', '')
  end

  def sort_characters characters
    #按照characters的纵坐标优先， 横坐标次之的方式进行 排序
    current_page = @current_pages.first
    children_page_count = @current_pages.first.analyze_children_page_count true
    new_characters = children_page_count.times.map{|index| {} }
    max_width = [@current_pages.first.width, @max_width].max
    middle_width = max_width/children_page_count
    @characters.each do |char|
      children_page_number = 0

      if current_page.is_catalog?
        positions = current_page.children_page_positions 
        positions.each_with_index do |p, index|
          break if index == positions.size - 1
          if char.x < (positions[index+1][0] + positions[index][1])/2
            children_page_number = index
            break
          end
          children_page_number = index + 1

        end
        #puts char.text + "------" + children_page_number.to_s + "----" + char.x.to_s
      else
        children_page_number = char.x < middle_width ? 0 : 1
      end
      chars = new_characters[children_page_number]
      height = char.y
      
      same_height = nil
      
      chars.keys.each do |key|
        same_height = key and next if strict_same_line? key, height
      end
      if same_height
        chars[same_height] << char
      else
        chars[height] = [char]
      end
    end

    new_characters.each do |char_hash|
      char_hash.each do |key, char_list|
        char_hash[key] = char_list.sort_by(&:x)
      end
    end 

    new_chars = new_characters.map do |char_hash|
      char_hash.sort.reverse.map(&:last)
    end.flatten
    set_char_belongs_to_which_children_page new_characters.map(&:values).map(&:flatten).map(&:size), new_chars
    new_chars
  end

  def set_char_belongs_to_which_children_page children_page_counts, new_chars 
    @children_page_number_scope = []
    children_page_counts.each_with_index do |count, index|
      sum = children_page_counts[0..index].inject(:+)
      @children_page_number_scope << [sum, index]
    end
  end

  def generate_new_page page
    if @current_pages.empty?
      return Page.new(page)
    end
    current_page = Page.new(page)
  end

  def analyzer_characters characters
    characters.each_with_index do |char, char_index|
      if char.x > @max_width
        @max_width = char.x
      end
      if char.x > 850 and char.y > 460
        #认为是标题
        @current_page.page_title = @current_page.page_title.to_s + char.text
        next
      end

      if @current_page.lines.empty?
        #如果还不存在page_lines
        new_page_line char, char_index
        next
      end
      
      page_line = @current_page.lines.last
      if same_line? page_line.height, char.y and page_line.end_position < char.x
        column = page_line.columns.last
        if column.font_size == char.font_size and column.last_position + char.width*6 > char.x
          column << char
        else
          column = ContentColumn.new(char)
          page_line << column
        end
        page_line.begin_position = char.x if page_line.begin_position > char.x 
        page_line.end_position   = char.x if page_line.end_position < char.x
        page_line.char_indexes   << char_index
        next       
      end
      new_page_line char, char_index
    end
  end

  def same_line? h1, h2
    (h1 - h2).abs < 8
  end

  def strict_same_line? h1, h2
    (h1-h2).abs < 6.5
  end

  def same_rank? w1, w2
    (w1 - w2).abs < 16
  end

  def set_page_type
    return if @current_page.lines.empty?
    @current_page.lines.last.columns.each do |column|
      @current_page.page_types.add :catalog if column.text.include?('............')
    end
  end

  def merge_page_lines
    merge_catalog_page_lines if @current_page.page_types.include?(:catalog)
  end

  def merge_catalog_page_lines
  end

  def find_and_same_height_lines char
    return [] if @current_page.lines.empty?
    
    lines = []
    return lines if char.text.bytesize == 3 and char.text != '，'
    return [] if char.text == '-'
    #return lines if same_rank?(@current_page.lines.last.begin_position, char.x)
    page_count = @current_page.analyze_children_page_count
    middle_width = @current_page.width/page_count
    @current_page.lines.each do |line|
      lines << line if same_line?(line.height, char.y) and line.begin_position/middle_width == char.x/middle_width
    end
    lines
  end

  def insert_char_to_lines char, lines, char_index
    page_count = @current_page.analyze_children_page_count
    middle_width = @current_page.width/page_count

    lines.each_with_index do |line, line_index|
      line.columns.each_with_index do |column, index|
        if char.x < column.begin_position
          line.char_indexes << char_index
          if index > 0 and line.columns[index-1].font_size == char.font_size
            line.columns[index-1] << char
          else
            line.columns.insert(index, ContentColumn.new(char))
          end
          return
        end
      end
      #binding.pry  if line_index ==1 
      if char.x < middle_width
        line.char_indexes << char_index
        if line.columns.last.font_size == char.font_size
          line.columns.last << char
        else
          line << ContentColumn.new(char)
        end
        return
      end
      
      last_position = line.columns.last.last_position
      begin_position = line.begin_position
      if char.x > middle_width and char.x > last_position and last_position > middle_width
        line.char_indexes << char_index
        if line.columns.last.font_size == char.font_size
          line.columns.last << char
        else
          line << ContentColumn.new(char)
        end
        return
      end

      if char.x > middle_width and lines.size == 1
        @current_children_page_number = get_char_belongs_to_which_chilren_page char_index
        page_line = PageLine.new(char, char_index, @current_children_page_number)
        column = ContentColumn.new(char)
        page_line << column
        @current_page << page_line
      end
    end
  end

  def get_char_belongs_to_which_chilren_page char_index
    return -1 unless self.instance_variables.include?(:@children_page_number_scope)
    @children_page_number_scope.each_with_index do |number_scope|
      return number_scope[1] + 1 if char_index < number_scope[0]
    end
  end

  def new_page_line char, char_index
    set_page_type
    lines = find_and_same_height_lines(char)
    unless lines.empty?
      insert_char_to_lines char, lines, char_index
      return
    end
    @current_children_page_number = get_char_belongs_to_which_chilren_page char_index
    page_line = PageLine.new(char, char_index, @current_children_page_number)
    column = ContentColumn.new(char)
    page_line << column
    @current_page << page_line
  end

  def run
  	@pdf_reader.pages[2...-1].each do |page|
      analyzer_page page
  	end
  end

  def analyzer_page_with_number number
    analyzer_page @pdf_reader.pages[number]
  end

  def analyzer_image_with_number number
    extractor = ExtractImages::Extractor.new 0
    extractor.page @pdf_reader.page(number)
    extractor.filenames
  end

  def merge_images_and_text images
    return if images.empty?
    positions = []
    current_page.lines.each_with_index do |line, index|
      if /^图[0-9]/.match line.columns.first.text.gsub(' ', '')
        positions << index 
      end
    end
    count = 0 
    return if positions.size != images.size 
    positions.each_with_index do |position, index|
      current_page.lines.insert position + count ,  ImageLine.new(images[index])
      count += 1
    end
  end
end



Sinatra::Application.reset!
use Rack::Reloader
use Rack::Static, :urls => ["/images"], :root => "public"
set :slim, :pretty => true
register Sinatra::StaticAssets

get '/' do

  @files = ['Audi+A4L+B8_cn.pdf', 'Audi+A5_cn.pdf', 
    'Audi+A6L+C7_cn.pdf', 'Audi+A6l+C7+MMI_cn.pdf', 'Audi+A8+D4_cn.pdf',
    'Audi+MMI+Navigation+plus+mit+RSE(D4)_cn.pdf', 'Audi+Q5_cn.pdf', 
    'Audi+Q7_cn.pdf']
  FileUtils.cp("../test/#{@files[(params[:file].to_i | 0)]}", 'demo_1.pdf')
  analyzer = PageAnalyzer.new('demo_1.pdf')
  page_number = params[:page] || 2
  analyzer.analyzer_page_with_number page_number.to_i - 1
  @images = analyzer.analyzer_image_with_number page_number.to_i
  analyzer.merge_images_and_text @images
  analyzer.analyze_page_type analyzer.current_pages.last
  @first_page = analyzer.current_pages.first
  @current_page = analyzer.current_page
  @characters = analyzer.instance_variable_get :@characters
  #@characters = []
  @analyzer = analyzer
  @origin_text = analyzer.pdf_reader.page(page_number.to_i).text
  #binding.pry
  slim :index
end