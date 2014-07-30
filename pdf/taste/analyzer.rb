require 'pdf/reader'
require 'pry'
require 'sinatra'
require 'rack'
require 'slim'
require 'linguo'
require 'fileutils'
require './image_test'
require 'sinatra/static_assets'

module PDF
  class Reader
    class Page
      def text_receiver
        receiver = PageTextReceiver.new
        walk(receiver)
        receiver
      end
      
      def width
        @attributes[:MediaBox][2] - @attributes[:MediaBox][0]
      end

      def height
        @attributes[:MediaBox][3] - @attributes[:MediaBox][1]
      end
    end
  end
end

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
        puts @children_page_positions
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

class PageLine
  attr_accessor :columns, :begin_position, :end_position, :height, :type, :line_types, :scope_index, :char_indexes

  def initialize char, char_index
    @columns = []
    @begin_position = char.x
    @height         = char.y
    @end_position   = char.x
    @type = :text
    @line_types = Set.new
    #scope_index 是为table服务的
    @scope_index = []
    @char_indexes = Set.new char_index
  end

  def <=> other
  end

  def << content
    @columns << content
  end
end

class ImageLine
  attr_accessor :path, :type
  def initialize path
    @path = path
    @type = :image
  end
end

class ContentColumn
  attr_accessor :font_size, :width, :text, :last_position, :type, :begin_position, :height
  def initialize(char)
    @text = char.text
    @font_size = char.font_size
    @width     = char.width
    @last_position = char.x
    @begin_position = char.x
    @height = char.y
  end

  def << char
    if is_English_or_digest_char?(char.text) == 0 and (char.x - @last_position) > 1.5*char.width
      @text += "  #{char.text}"
    else
      @text += char.text
    end
    @last_position = char.x
  end

  def is_English_or_digest_char?(text)
    text =~ /[A-Za-z0-9]/
  end

  def to_s
    "字体： #{text}  , begin: #{begin_position}    , end: #{last_position}"
    [text, begin_position, last_position, font_size, height].to_s
  end
end

class PdfAnalyzer
  attr_accessor :file_name, :current_pages, :current_page, :max_width, :pdf_reader
  
  def initialize(file_name)
  	@file_name = file_name
  	@pdf_reader = PDF::Reader.new(file_name)
  	@total_number = @pdf_reader.page_count
    @current_pages = []
    @max_width = -1
  end

  def analyzer_page page
    receiver = page.text_receiver
    @current_pages  <<  generate_new_page(page)

    @characters = receiver.instance_variable_get :@characters
    @analyze_count = 1
    @current_page = @current_pages[@analyze_count-1]
    analyzer_characters @characters
    
    #第二次 解析characters， 目的去掉 第一次 带来的误差

    new_characters = sort_characters @characters

    @current_pages  <<  generate_new_page(page)
    @analyze_count = 2
    @current_page = @current_pages[@analyze_count-1]
    analyzer_characters new_characters

    analyze_page_type @current_pages.last
  end

  def analyze_page_type page
    analyze_page_for_table_type page
  end

  def analyze_page_for_table_type page
    table_line = []
    standard_table_line = []
    is_table = false
    page.lines.each_with_index do |line, index|
      if table_line.empty?
        table_line << [[index, line.columns.size], [index, line.columns.size]]
        next
      end
      if line.columns.size == table_line.last[0][1]
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
      binding.pry
    end

    return unless is_table

    table_index = standard_table_line.first[0]
    table_head  = page.lines[table_index]
    page.lines[(table_index+1)..-1].each do |line|
      if same_rank?(line.columns.first.begin_position, table_head.columns.first.begin_position) and same_rank?(line.columns.last.begin_position, table_head.columns.last.begin_position)
        line.line_types <<     :table_body
        line.line_types.delete :table_head
      else
        if line.line_types.include?(:table_head)
          line.line_types.delete :table_head
          line.line_types.add :repeat_table_head
          table_head = line
        else
          break
        end
      end  
    end
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

    new_characters.map do |char_hash|
      char_hash.sort.reverse.map(&:last)
    end.flatten
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
        page_line = PageLine.new(char)
        column = ContentColumn.new(char)
        page_line << column
        @current_page << page_line
      end
    end
  end

  def new_page_line char, char_index
    set_page_type
    lines = find_and_same_height_lines(char)
    unless lines.empty?
      insert_char_to_lines char, lines, char_index
      return
    end

    page_line = PageLine.new(char, char_index)
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
      if /^图  [0-9]/.match line.columns.first.text
        positions << index 
      end
    end
    count = 0 
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
  analyzer = PdfAnalyzer.new('demo_1.pdf')
  page_number = params[:page] || 2
  analyzer.analyzer_page_with_number page_number.to_i - 1
  @images = analyzer.analyzer_image_with_number page_number.to_i
  analyzer.merge_images_and_text @images
  @first_page = analyzer.current_pages.first
  @current_page = analyzer.current_page
  @characters = analyzer.instance_variable_get :@characters
  #@characters = []
  @analyzer = analyzer
  @origin_text = analyzer.pdf_reader.page(page_number.to_i).text
  #binding.pry
  slim :index
end