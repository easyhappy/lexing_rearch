module Analyzer
  module ParagraphHelper
    def output_last_paragraph
      #Todo
      return unless @current_garagprah
      (@current_4_node || @current_3_node) << @current_garagprah.analyzer_lines_with_markdown_format
      @current_garagprah = nil
    end

    def fetch_paragraph_from_page line
      #解析 提示、警告、环境指南等 段落
      if @file_configs[:status].include? line.line_text
        analyze_table_paragraph
        return
      end

      #识别图片信息
      if line.type == :image
        analyze_image_paragraph
        return
      end

      #根据行间距 识别 一个普通 段落。
      if !@current_garaprah
        analyze_common_paragraph
        return
      end
    end

    private
    def analyze_table_paragraph
      output_last_paragraph
      @current_garagprah = PageParagraph.new @current_page, @current_index, :table, @file_configs
      @current_index += 1
      @current_garagprah << @current_index
      line = get_current_line @current_index
      while true
        next_line = get_current_line @current_index+1
        break unless next_line
        if is_page_right_bar? next_line
          @current_index += 1
          next
        end
        if is_same_garagraph? line.height, next_line.height
          line = next_line
          @current_index += 1
          @current_garagprah << @current_index
          next
        end
        break
      end
      output_last_paragraph
    end

    def analyze_image_paragraph
      output_last_paragraph
      @current_garagprah = PageParagraph.new @current_page, @current_index, :image, @file_configs
      @current_index += 1
      line = get_current_line @current_index
      
      if is_pic_desctription? line
        @current_garagprah << @current_index
      end
      output_last_paragraph
    end

    def analyze_common_paragraph
      output_last_paragraph
      @current_garagprah = PageParagraph.new @current_page, @current_index, :common, @file_configs
      current_line = @current_page.lines[@current_index]
      while true
        next_line = get_current_line @current_index+1
        break if is_end_paragraph? current_line
        break unless next_line
        break if next_line.type == :image
        if is_same_garagraph? next_line.height, current_line.height
          @current_index += 1
          @current_garagprah << @current_index

          current_line = next_line
          next_line = get_current_line @current_index+1
        else
          break
        end
      end
      output_last_paragraph
    end
  end
end