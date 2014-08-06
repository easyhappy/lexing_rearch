#coding: utf-8
$: << File.dirname(__FILE__) unless $:.include? File.dirname(__FILE__)

require 'yaml'
require 'pry'
require 'fileutils'
require 'active_support/all'

require 'page_analyzer'
require 'analyzer/pdf_catalog'
require 'analyzer/catalog_node'
require 'analyzer/markdown'
require 'active_record'
require 'mysql2'
require 'redcarpet'

class PdfAnalyzer
  include Analyzer::PdfCatalog
  include Analyzer::Markdown
  def initialize(file_name)
    @file_name = file_name
    load_configs
    #过多的解析同一个pdf， 会导致这个pdf文件损坏， 所以每次都copy一个新的pdf
    FileUtils.cp("../test/#{@file_name}", 'demo.pdf')
  end

  def load_configs
    @all_configs= YAML::load(File.open('config/config.yml')).symbolize_keys!
    @file_configs = (@all_configs[@file_name.to_sym] || @all_configs[:default]).symbolize_keys!
  end

  def run
    analyze_pdf_catalogs
    analyze_pdf_content_by_catalogs
  end

  def analyze_pdf_content_by_catalogs
    begin_number = @file_configs[:content_begin_page]
    @current_2_catalog_index = 0
    @current_3_node          = nil
    @current_4_node          = nil
    #begin_number = 147
    @total_number = 15
    (begin_number..@total_number).each do |number|
      page = analyze_one_page number
      page_title = find_page_title page
      page.lines.each_with_index do |line, index|
        next if is_page_head? line
        next if is_page_title? line
        next if is_page_footer? line
        next if is_page_right_bar? line
        next if content_is_title? line
        next if set_current_3_node line
        next if set_current_4_node line
        unless @current_3_node
          @current_3_node = all_second_level_nodes[@current_2_catalog_index].children.first
        end

        #binding.pry if index >= 11
        add_line_to_node @current_4_node || @current_3_node, line, page, @file_configs
      end
      puts "number is completed : #{number}"
      #binding.pry
    end

    output_to_markdown_file @main_catalogs, @file_name, @file_configs
  end

  def find_page_title page
    if page.page_title
      title = page.page_title
    else
      page.lines.each do |line|
        title = line.line_text and break if is_page_title? line
      end
    end
    all_second_level_nodes.each_with_index do |node, index|
      next if @current_2_catalog_index > index
      if title.include?(node.name)
        @current_2_catalog_index = index
        @current_2_catalog = all_second_level_nodes[@current_2_catalog_index]
        return node.name
      end
    end
  end

  def analyze_pdf_catalogs
    @main_catalogs = []
    page_numbers = @file_configs[:catatlog_pages]
    page_numbers.each do |number|
      page = analyze_one_page(number)
      page.lines.each do |line|
        next if is_page_head? line
        next if is_page_title? line
        next if is_page_footer? line
        analyze_pdf_catalogs_for_A4 line if file_is_A4?
        analyze_pdf_catalogs_for_A6 line if file_is_A6?
      end
    end
  end

  def analyze_pdf_catalogs_for_A6 line
    #Audi+A6L+C7_cn.pdf的 目录解析规则
    splits = line.line_text.split('…')
    name = splits[0].strip
    if same_rank? line.begin_position, @file_configs[:first_children_begin]
      if @file_configs[:first_level_catalogs].include? name and !@main_catalogs.map(&:name).include? name
        @main_catalogs << create_catalog_1_node(line)
      else
        create_catalog_2_node(line)
      end
      return
    elsif same_rank? line.begin_position, @file_configs[:second_children_begin]
      if @file_configs[:first_level_catalogs].include? name and !@main_catalogs.map(&:name).include? name
        @main_catalogs << create_catalog_1_node(line)
      else
        create_catalog_2_node(line)
      end
      return
    end
    if same_rank?(line.begin_position, @file_configs[:first_children_begin], 10) \
        or same_rank?(line.begin_position, @file_configs[:second_children_begin], 10)
      create_catalog_3_node line
    end
    #create_catalog_3_node line
  end

  def file_is_A6?
    @file_name == 'Audi+A6L+C7_cn.pdf'
  end

  def analyze_pdf_catalogs_for_A4 line
    #Audi+A4L+B8_cn.pdf的 目录解析规则
    case line.columns.first.font_size
    when @file_configs[:catalog_1_size]
      @main_catalogs << create_catalog_1_node(line)
    when @file_configs[:catalog_2_size]
      create_catalog_2_node line 
    when @file_configs[:catalog_3_size]
      create_catalog_3_node line
    end
  end

  def file_is_A4?
    @file_name == 'Audi+A4L+B8_cn.pdf'
  end

  def is_page_head? line
    return false if line.type == :image
    strict_same_line? line.height, @file_configs[:noise_head_height], 3
  end

  def is_page_right_bar? line
    return false if line.type == :image
    same_rank? line.begin_position, @file_configs[:noise_right_side_begin]
  end

  def content_is_title? line
    return false if line.type == :image
    return true if line.columns.first.font_size == @file_configs[:page_title_size] and line.line_text.include?(@current_2_catalog.name)
  end

  def set_current_3_node line
    return false if line.type == :image
    all_second_level_nodes[@current_2_catalog_index].children.each do |node|
      if line.columns.first.font_size == @file_configs[:catalog_3_content_size] and line.line_text.include?(node.name)
        @current_3_node = node
        @current_4_node = nil
        return true
      end
    end
    return false
  end

  def set_current_4_node line
    return false if line.type == :image
    if line.columns.size == 1 and line.columns.first.font_size == 9 \
          and (! @file_configs[:not_fourth_nodes].include? line.line_text) \
          and (! line.line_text.include?('。'))
      return false if @current_4_node and @current_4_node.lines.empty?
      @current_4_node = Analyzer::CatalogNode.new(line.line_text, -1)
      @current_3_node.children << @current_4_node
      @current_4_node.parent = @current_3_node
      return true
    end
    return false
  end

  def is_page_footer? line
    return false if line.type == :image
    strict_same_line? line.height, @file_configs[:noise_footer_height], 3
  end

  def is_page_title? line
    return false if line.type == :image
    strict_same_line? line.height, @file_configs[:page_title_height]
  end

  def analyze_one_page number
    
    page_analyzer = PageAnalyzer.new('demo.pdf')
    @total_number = page_analyzer.total_number

    page_analyzer.analyzer_page_with_number number.to_i - 1
    images = page_analyzer.analyzer_image_with_number number.to_i
    page_analyzer.merge_images_and_text images
    page_analyzer.analyze_page_type page_analyzer.current_pages.last
    page_analyzer.current_pages.last
  end
end

files = ['Audi+A4L+B8_cn.pdf', 'Audi+A6L+C7_cn.pdf']
analyzer = PdfAnalyzer.new files[1]
analyzer.run
