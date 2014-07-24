require 'pdf/reader'
require 'pry'

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
  attr_accessor :contents, :begin_position, :end_position, :height

  def <=> other
  end
end

class PdfAnalyzer
  attr_accessor :file_name
  
  def initialize(file_name)
  	@file_name = file_name
  	@pdf_reader = PDF::Reader.new(file_name)
  	@total_number = @pdf_reader.page_count
  end

  def analyzer_page page
    receiver = page.text_receiver
    @characters = receiver.instance_variable_get :@characters

    self_page = Page.new(page.number)
    page_line = nil
    @characters.each do |char|
      unless page_line
        page_line = PageLine.new
        self_page << page_line
        binding.pry
        page_line.begin_position = char
      else

      end
    end
  end

  def run
  	@pdf_reader.pages[2...-1].each do |page|
      analyzer_page page
      exit
  	end
  end
end

analyzer = PdfAnalyzer.new('demo_1.pdf')
analyzer.run