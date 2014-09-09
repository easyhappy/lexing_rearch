$: << File.dirname(__FILE__) unless $:.include? File.dirname(__FILE__)

require 'pry'
require 'sinatra'
require 'rack'
require 'slim'
require 'linguo'
require 'fileutils'
require 'sinatra/static_assets'
require 'page_helpers/page_handler'
require 'page_helpers/image_handler'

Sinatra::Application.reset!
use Rack::Reloader
use Rack::Static, :urls => ["/images"], :root => "public"
set :slim, :pretty => true
register Sinatra::StaticAssets

get '/' do

  @files = ['Audi+A6L+C7_cn.pdf', 'Audi+A4L+B8_cn.pdf', 'Audi+A5_cn.pdf', 'Audi+A6l+C7+MMI_cn.pdf', 'Audi+A8+D4_cn.pdf',
    'Audi+MMI+Navigation+plus+mit+RSE(D4)_cn.pdf', 'Audi+Q5_cn.pdf', 
    'Audi+Q7_cn.pdf']
  file = @files[(params[:file].to_i | 0)]
  
  #每次都copy的问题是 防止多次解析这个pdf， 造成pdf 损坏!!
  FileUtils.cp("../data/#{file}", 'demo.pdf')
  
  analyzer = PageAnalyzer.new('demo.pdf')
  
  page_number = params[:page] || 2
  analyzer.analyzer_page_with_number page_number.to_i - 1
  
  #解析图片
  @file_path = file.split('.')[0]
  @base_path = "../data/#{@file_path}"
  path = "#{@file_path}.htm"
  image_handler = ImageHandler.new(@base_path, path)
  image_handler.run
  images = image_handler.page_image page_number.to_i - 1
  analyzer.merge_images_and_text images

  @first_page = analyzer.current_pages.first
  @current_page = analyzer.current_page
  @characters = analyzer.instance_variable_get :@characters

  #@characters = []
  @analyzer = analyzer
  @origin_text = analyzer.pdf_reader.page(page_number.to_i).text

  slim :index
end

