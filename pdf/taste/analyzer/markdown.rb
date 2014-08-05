require 'active_record'
require 'mysql2'
require 'models/car_line'
require 'models/car_make'
require 'models/car_model'
require 'models/section'
#require 'uploaders/image_uploader'
#require 'models/picture'
#require 'config/initializers/carrierwave'

module Analyzer
  module Markdown
    def output_to_markdown_file main_catalogs, file_name, configs
      ActiveRecord::Base.establish_connection(
        :adapter  => "mysql2",
        :host     => "localhost",
        :username => "root",
        :password => "",
        :database => "wheel_development"
      )
      find_car_line configs
      binding.pry
      @markdown_file = File.new(file_name.split('.pdf')[0] + '.md', 'w')
      main_catalogs[1..-1].each do |catalog|
        output_leaf_nodes catalog, configs
      end
    end

    def output_leaf_nodes catalog, configs
      if catalog.children.empty?
        output_lines_to_db catalog, configs 
        output_catalog_to_db catalog, configs
        output_to_db catalog, configs
        output_to_file catalog, configs
        return
      end

      catalog.children.each do |node|
        output_catalog_to_db catalog, configs
        output_leaf_nodes  node, configs
      end
    end

    def add_line_to_node node, line, page
      if line.type == :image
        node << "\n"
        node << "此处有图片: #{line.path}"
        return
      end
      if page.page_types.include?(:catalog)
        if /^A/.match line.line_text
          node << "\n"
          node << get_catalog_info(line)
          return
        elsif /^-/.match line.line_text
          node << get_catalog_info_for_minus(line)
          return
        elsif /\.\./.match line.line_text
          node << line.line_text.split('..')[0]
          return
        end
      end
      node << "\n"
      node << line.line_text
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

    def get_catalog_info_for_minus line
      #-转向信号灯和远光灯............... 将 - 号 后面添加一个空格
      line.line_text.split('..').first.sub('-', '- ')
    end

    def output_catalog_to_db catalog, configs
      return unless configs[:save_db]
      unless catalog.parent
        Section.find_or_create_by :title => catalog.name, :car_line => @car_line
      else
        parent = Section.find_or_create_by :title => catalog.parent.name, :car_line => @car_line
        Section.find_or_create_by :title => catalog.name, :parent => parent
      end
    end

    def output_to_file catalog, configs
      return if catalog.lines.empty?
      @markdown_file.write find_catalog_names(catalog) + "\n"
      catalog.lines.each do |line|
        @markdown_file.write("\n") and next if line == :new_line
        @markdown_file.write(line + "\n")
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
      cs = find_catalog_history catalog
    end

    def output_lines_to_db catalog, configs
      return unless configs[:save_db]
      return if catalog.lines.empty?
      parent = Section.find_or_create_by :title => catalog.parent.name, :car_line => @car_line
      section = Section.find_or_create_by :title => catalog.name, :parent => parent
      section.description = catalog.lines.join("\n")
      section.save
    end

    def find_car_line configs
      @car_make = CarMake.find_by_name configs[:car_make]
      @car_line = CarLine.find_or_create_by :name => configs[:car_line], :annum => configs[:year], :car_make => @car_make
    end
  end
end