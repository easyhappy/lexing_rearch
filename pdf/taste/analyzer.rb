require 'pdf/reader'
require 'pry'
require 'sinatra'
require 'rack'
require 'slim'
require 'linguo'
require 'fileutils'

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
  attr_accessor :page_number, :page_title, :lines, :page_types, :children_page_count, :origin_page
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

  def analyze_children_page_count
    positions = self.lines.map(&:begin_position).map(&:to_i)
    if positions.max - positions.min > 200
      @children_page_count = 2
    else
      @children_page_count = 1
    end
  end
end

class PageLine
  attr_accessor :columns, :begin_position, :end_position, :height

  def initialize char
    @columns = []
    @begin_position = char.x
    @height         = char.y
    @end_position   = char.x
  end

  def <=> other
  end

  def << content
    @columns << content
  end
end

class ContentColumn
  attr_accessor :font_size, :width, :text, :last_position, :type, :begin_position
  def initialize(char)
    @text = char.text
    @font_size = char.font_size
    @width     = char.width
    @last_position = char.x
    @begin_position = char.x
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
end

class PdfAnalyzer
  attr_accessor :file_name, :current_pages, :current_page
  
  def initialize(file_name)
  	@file_name = file_name
  	@pdf_reader = PDF::Reader.new(file_name)
  	@total_number = @pdf_reader.page_count
    @current_pages = []
  end

  def analyzer_page page
    receiver = page.text_receiver
    @current_pages  <<  generate_new_page(page)
    
    @characters = receiver.instance_variable_get :@characters
    @analyze_count = 1
    @current_page = @current_pages[@analyze_count-1]
    analyzer_characters @characters
    
    #第二次 解析character， 目的去掉 第一次 带来的误差
    new_characters = sort_characters @characters

    @current_pages  <<  generate_new_page(page)
    @analyze_count = 2
    @current_page = @current_pages[@analyze_count-1]
    analyzer_characters new_characters
  end

  def sort_characters characters
    #按照characters的纵坐标优先， 横坐标次之的方式进行 排序
    children_page_count = @current_pages.first.analyze_children_page_count
    new_characters = children_page_count.times.map{|index| {} }
    middle_width = @current_pages.first.width/@current_pages.first.analyze_children_page_count
    @characters.each do |char|
      children_page_number = char.x/middle_width
      position = -1
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
    characters.each do |char|
      if char.x > 850 and char.y > 460
        #认为是标题
        @current_page.page_title = @current_page.page_title.to_s + char.text
        next
      end

      if @current_page.lines.empty?
        #如果还不存在page_lines
        new_page_line char
        next
      end
      
      page_line = @current_page.lines.last
      if same_line? page_line.height, char.y and page_line.end_position < char.x
        column = page_line.columns.last
        if column.font_size == char.font_size
          column << char
        else
          column = ContentColumn.new(char)
          page_line << column
        end
        page_line.begin_position = char.x if page_line.begin_position > char.x 
        page_line.end_position   = char.x if page_line.end_position < char.x
        next       
      end
      new_page_line char
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

  def insert_char_to_lines char, lines
    page_count = @current_page.analyze_children_page_count
    middle_width = @current_page.width/page_count

    lines.each_with_index do |line, line_index|
      line.columns.each_with_index do |column, index|
        if char.x < column.begin_position
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

  def new_page_line char
    set_page_type
    lines = find_and_same_height_lines(char)
    unless lines.empty?
      insert_char_to_lines char, lines
      return
    end

    page_line = PageLine.new(char)
    column = ContentColumn.new(char)
    page_line << column
    @current_page << page_line
  end

  def save_current_page
  end

  def run
  	@pdf_reader.pages[2...-1].each do |page|
      analyzer_page page
  	end
  end

  def analyzer_page_with_number number
    analyzer_page @pdf_reader.pages[number]
  end
end



Sinatra::Application.reset!
use Rack::Reloader
set :slim, :pretty => true

get '/' do
  FileUtils.cp('../test/demo_1.pdf', 'demo_1.pdf')
  analyzer = PdfAnalyzer.new('demo_1.pdf')
  page_number = params[:page] || 2
  analyzer.analyzer_page_with_number page_number.to_i - 1
  @current_page = analyzer.current_page
  @characters = analyzer.instance_variable_get :@characters
  @characters = []
  slim :index
end