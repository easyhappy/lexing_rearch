$: << File.dirname(__FILE__) unless $:.include? File.dirname(__FILE__)

require 'yaml'
require 'pry'
require 'fileutils'
require 'active_support/all'

require 'page_analyzer'

class PdfAnalyzer
  def initialize(file_name)
    @file_name = file_name
    load_configs
    
    #每次copy的原因是： 过多的解析同一个pdf， 会导致这个pdf文件损坏， 所以每次都copy一个新的pdf
    FileUtils.cp("../test/#{@file_name}", 'demo_1.pdf')
    @page_analyzer = PageAnalyzer.new('demo_1.pdf')
  end

  def load_configs
    @all_configs= YAML::load(File.open('pdf_config.yml')).symbolize_keys!
    @file_configs = (@all_configs[@file_name.to_sym] || @all_configs[:default]).symbolize_keys!
  end

  def run
    fetch_pdf_catalogs
  end

  def fetch_pdf_catalogs
    @catalogs = {}
    page_numbers = @file_configs[:catatlog_pages]
    pages = []
    page_numbers.each do |number|
      pages << analyze_one_page(number)
    end
  end

  def is_noise_page_head? line
    return false if @file_configs[:noise_page_head]
    @file_configs[:noise_page_head].gsub(' ', '') == line.line_text.gsub(' ', '')
  end

  def analyze_one_page number
    @page_analyzer.analyzer_page_with_number number.to_i - 1
    images = @page_analyzer.analyzer_image_with_number number.to_i
    @page_analyzer.merge_images_and_text images
    @page_analyzer.analyze_page_type @page_analyzer.current_pages.last
    @page_analyzer.current_pages.last
  end
end

analyzer = PdfAnalyzer.new 'Audi+A4L+B8_cn.pdf'
analyzer.run
