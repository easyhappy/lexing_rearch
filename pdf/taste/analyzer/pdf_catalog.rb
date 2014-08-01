$: << File.dirname(__FILE__) unless $:.include? File.dirname(__FILE__)

require 'base'
require 'catalog_node'

module Analyzer
  module PdfCatalog
    include Analyzer::Base
    def create_catalog_1_node line
      if get_catalog_name_and_number line
        @main_catalogs << CatalogNode.new(*@name_and_number)
      end
    end

    def create_catalog_2_node line
      if get_catalog_name_and_number line
        node = CatalogNode.new(*@name_and_number)
        parent_node = @main_catalogs.last
        parent_node.children << node
        node.parent = parent_node
      end
    end

    def create_catalog_3_node line
      if get_catalog_name_and_number line
        node = CatalogNode.new(*@name_and_number)
        parent_node = @main_catalogs.last.children.last
        parent_node.children << node
        node.parent = parent_node
      end
    end

    def get_catalog_name_and_number line
      @name_and_number = nil
      if is_catalog_line? line.line_text
        splits = line.line_text.split('..')
        name = @part_name ? @part_name + splits[0] : splits[0]
        
        number = get_degist(line.columns.last.text)
        @name_and_number = [name, number]
        
        @part_name = nil
      elsif is_degist?(line.columns.last.text)
        if line.columns.size == 2
          @name_and_number = line.columns.map(&:text)
        end
      else
        @part_name = line.line_text
      end
      return @name_and_number
    end
  end
end