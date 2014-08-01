$: << File.dirname(__FILE__) unless $:.include? File.dirname(__FILE__)

require 'yaml'
require 'pry'
require 'fileutils'
require 'active_support/all'

require 'page_analyzer'
require 'analyzer/pdf_catalog'
require 'analyzer/catalog_node'

class PdfAnalyzer
  include Analyzer::PdfCatalog
  def initialize(file_name)
    @file_name = file_name
    load_configs
  end

  def load_configs
    @all_configs= YAML::load(File.open('pdf_config.yml')).symbolize_keys!
    @file_configs = (@all_configs[@file_name.to_sym] || @all_configs[:default]).symbolize_keys!
  end

  def run
    analyze_pdf_catalogs
  end

  def analyze_pdf_catalogs
    @main_catalogs = []
    page_numbers = @file_configs[:catatlog_pages]
    page_numbers.each do |number|
      page = analyze_one_page(number)
      page.lines.each do |line|
        next if is_noise_page_head? line
        next if is_page_title? line
        next if is_noise_page_footer? line
        case line.columns.first.font_size
        when @file_configs[:catalog_1_size]
          create_catalog_1_node line
        when @file_configs[:catalog_2_size]
          create_catalog_2_node line 
        when @file_configs[:catalog_3_size]
          create_catalog_3_node line
        end
      end
    end
  end

  def is_noise_page_head? line
    strict_same_line? line.height, @file_configs[:noise_head_height], 3
  end

  def is_noise_page_footer? line
    strict_same_line? line.height, @file_configs[:noise_footer_height], 3
  end

  def is_page_title? line
    strict_same_line? line.height, @file_configs[:page_title_height]
  end

  def analyze_one_page number
    #过多的解析同一个pdf， 会导致这个pdf文件损坏， 所以每次都copy一个新的pdf
    FileUtils.cp("../test/#{@file_name}", 'demo_1.pdf')
    page_analyzer = PageAnalyzer.new('demo_1.pdf')

    page_analyzer.analyzer_page_with_number number.to_i - 1
    images = page_analyzer.analyzer_image_with_number number.to_i
    page_analyzer.merge_images_and_text images
    page_analyzer.analyze_page_type page_analyzer.current_pages.last
    page_analyzer.current_pages.last
  end
end

analyzer = PdfAnalyzer.new 'Audi+A4L+B8_cn.pdf'
analyzer.run
