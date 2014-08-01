require './page_analyzer'
require 'yaml'
require 'pry'

class PdfAnalyzer
  def initialize(file_name)
    @file_name = file_name
    load_configs
  end

  def load_configs
    @all_configs = YAML::load(File.open('pdf_config.yml'))
    @file_configs = @all_configs[@file_name] || @all_configs['default']
  end

  def run
    fetch_pdf_catalogs
  end

  def fetch_pdf_catalogs

  end
end

analyzer = PdfAnalyzer.new 'Audi+A4L+B8_cn.pdf'
