require './page_analyzer'
require 'yaml'
require 'pry'

class PdfAnalyzer
  def initialze(file_name)
    @filename = filename
    load_configs
  end

  def load_configs
    @configs = YAML::load(File.open('pdf_config.yml'))
    binding.pry
  end

  def run
    fetch_pdf_catalogs
  end

  def fetch_pdf_catalogs

  end
end

analyzer = PdfAnalyzer.new 'Audi+A4L+B8_cn.pdf'
