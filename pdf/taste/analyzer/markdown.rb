module Analyzer
  module Markdown
    def output_to_markdown_file main_catalogs
      binding.pry
    end

    def add_line_to_node node, line, page
      if line.type == :image
        node << :new_line
        node << "此处有图片: #{line.path}"
        return
      end
      if page.page_types.include?(:catalog)
        if /^A/.match line.line_text
          node << :new_line
          node << get_catalog_info(line)
          return
        elsif /^-/.match line.line_text
          node << get_catalog_info_for_minus(line)
          return
        end
      end
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
  end
end