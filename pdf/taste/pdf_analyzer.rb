require './page_analyzer'
require 'yaml'
require 'pry'

class PdfAnalyzer
  def initialize(file_name)
    @file_name = file_name
    load_configs
  end

  def load_configs
    @all_config = YAML::load(File.open('pdf_config.yml'))
    @file_config = @all_config[@file_name] || @all_config['default']
  end

  def run
    fetch_pdf_catalogs
  end

  def fetch_pdf_catalogs
    @file_config[:]
  end
end

analyzer = PdfAnalyzer.new 'Audi+A4L+B8_cn.pdf'
