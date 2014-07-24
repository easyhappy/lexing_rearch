require 'pdf/reader'
require 'pry'
require 'sinatra'
require 'rack'
require 'slim'

module PDF
  class Reader
    class Page
      def text_receiver
        receiver = PageTextReceiver.new
        walk(receiver)
        receiver
      end
    end
  end
end

class Page
  attr_accessor :page_number, :page_title, :lines

  def initialize(page_number)
    page_number = page_number
    @lines = []
  end

  def << page_line
    @lines << page_line
  end
end

class PageLine
  attr_accessor :columns, :begin_position, :end_position, :height
  def initialize char
    @columns = []
    @begin_position = char.x
    @height         = char.y
  end

  def <=> other
  end

  def << content
    @columns << content
  end
end

class ContentColumn
  attr_accessor :font_size, :width, :text
  def initialize(char)
    @text = char.text
    @font_size = char.font_size
    @width     = char.width
  end

  def << text
    @text += text
  end
end

class PdfAnalyzer
  attr_accessor :file_name, :current_page
  
  def initialize(file_name)
  	@file_name = file_name
  	@pdf_reader = PDF::Reader.new(file_name)
  	@total_number = @pdf_reader.page_count
  end

  def analyzer_page page
    receiver = page.text_receiver
    @characters = receiver.instance_variable_get :@characters

    @current_page = Page.new(page.number)
    @characters.each do |char|
      if @current_page.lines.empty?
        #如果还不存在page_lines
        new_page_line char
        next
      end
      
      page_line = @current_page.lines.last
      if page_line.height == char.y
        column = page_line.columns.last
        if column.font_size == char.font_size
          column << char.text
        else
          column = ContentColumn.new(char)
          page_line << column
        end
        next       
      end
      @current_page.lines.last.end_position = char.x
      new_page_line char
    end
  end

  def new_page_line char
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

analyzer = PdfAnalyzer.new('demo_1.pdf')

Sinatra::Application.reset!
use Rack::Reloader
get '/' do
  page_number = params[:page] || 2
  analyzer.analyzer_page_with_number page_number.to_i
  analyzer.current_page
  slim :index
end