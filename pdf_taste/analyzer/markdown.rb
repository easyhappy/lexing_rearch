
require 'models/car_line'
require 'models/car_make'
require 'models/car_model'
require 'models/section'
require 'models/picture'

module Analyzer
  module Markdown
    def output_to_markdown_file main_catalogs, file_name, configs
      find_car_line configs
      @markdown_file = File.new(file_name.split('.pdf')[0] + '.md', 'w')
      main_catalogs[1..-1].each do |catalog|
        output_leaf_nodes catalog, configs
      end

      #return unless file_is_A6?
      @catalogs_file = File.new(file_name.split('.pdf')[0] + '_catalogs.txt', 'w')
      main_catalogs.each do |catalog|
        output_catalog_to_file catalog
      end
    end

    def output_leaf_nodes catalog, configs
      if catalog.children.empty?
        output_catalog_to_db catalog, configs
        output_lines_to_db catalog, configs 
        #output_to_db catalog, configs
        output_to_file catalog, configs
        return
      end

      catalog.children.each do |node|
        output_catalog_to_db catalog, configs
        output_lines_to_db catalog, configs 
        output_leaf_nodes node, configs
      end
    end

    private
    def get_catalog_info line
      text = []
      line.columns[1..-1].each do |col|
        if is_catalog_line? col.text
          text << col.text.split('..').first
          break
        end
        text << col.text
      end
      text.join(' ').strip
    end

    def is_begin_with_minus? line
      minuses.each do |t|
        return true if /^#{t}/.match line.line_text
      end
      return false
    end

    def minuses
      ['-', '–', '–']
    end

    def output_catalog_to_db catalog, configs
      return unless configs[:save_db]
      return unless catalog.is_writed
      unless catalog.parent
        @first_level = Section.find_or_create_by :title => catalog.name, :car_line => @car_line, :parent_id => nil
      else
        case catalog.is_level
        when 2
          @second_level = Section.find_or_create_by :title => catalog.name, :parent => @first_level, :car_line => @car_line
        when 3
          @third_level = Section.find_or_create_by :title => catalog.name, :parent => @second_level, :car_line => @car_line
        when 4
          @thirth_level = Section.find_or_create_by :title => catalog.name, :parent => @third_level, :car_line => @car_line
        end
      end
    end

    def output_to_file catalog, configs
      return if catalog.lines.empty?
      return unless catalog.is_writed
      @markdown_file.write find_catalog_names(catalog) + "\n"
      catalog.lines.each_with_index do |line, index|
        if index == 0 and line.gsub(' ', '') == catalog.name.gsub(' ', '')
          next
        end
        if line.is_a? PageParagraph
          @markdown_file.write(line.to_s)
        else
          @markdown_file.write(line)
        end
        @markdown_file.write("\n")
      end
      
      @markdown_file.write('-'*60 + "\n")
    end

    def find_catalog_names catalog
      names = [catalog.name]
      p = catalog.parent
      while p
        names << p.name
        p = p.parent
      end
      names.reverse.join('/')
    end

    def find_catalog_history catalog
      cs = [catalog]
      p = catalog.parent
      while p
        cs << p
        p = p.parent
      end
      cs.reverse
    end

    def output_to_db catalog, configs
      return unless configs[:save_db]
      return unless catalog.is_writed
      cs = find_catalog_history catalog
    end

    def output_lines_to_db catalog, configs
      return unless configs[:save_db]
      return unless catalog.is_writed
      return if catalog.lines.empty?

      case catalog.is_level
      when 3
        section = Section.find_by :title => catalog.name, :parent => @second_level, :car_line => @car_line
      when 4
        section = Section.find_by :title => catalog.name, :parent => @third_level, :car_line => @car_line
      end
      section.description = catalog.lines.join("\n")
      section.save
    end

    def find_car_line configs
      @car_make = CarMake.find_by_name configs[:car_make]
      @car_line = CarLine.find_or_create_by :name => configs[:car_line], :annum => configs[:year], :car_make => @car_make
    end

    def output_catalog_to_file catalog
      if catalog.children.empty?
        return unless catalog.is_writed
        @catalogs_file.write "#{catalog.absolute_names}\n"
      end

      catalog.children.each do |child|
        output_catalog_to_file child
      end
    end
  end
end