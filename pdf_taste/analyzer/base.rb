module Analyzer
  module Base
    SPECAIL_SUB = {
      'A' => '![hong_a](http://pdf-image.qiniudn.com/uploads%2Fa2f1874ddb9041a35de0531ef9474194a0d791ad.png)',
      'B' => '![hong_b](http://pdf-image.qiniudn.com/uploads%2Fca789954c1e637f4a205a8bcf27676e7eb675a97.png)',
      'C' => '![hong_c](http://pdf-image.qiniudn.com/uploads%2F274da2988f210e87026700809dd03a081a7eddd1.png)',
      'D' => '![hong_d](http://pdf-image.qiniudn.com/uploads%2F37fa5a34ef3353b151195949841fe7ac829f2539.png)',
      'E' => '![hong_e](http://pdf-image.qiniudn.com/uploads%2F64471920740a4ad7feab706b7fec37faeee4781b.png)'
    }
    def strict_same_line? h1, h2, abs=5
      (h1-h2).abs < abs
    end

    def get_current_line index
      line = @current_page.lines[index]
      line = remove_noise_right_bar_data line
    end

    def is_degist? text
      /^[0-9]+$/.match text
    end

    def is_catalog_line? text
      text.include?('..') or text.include?('…') or text.include?('；')
    end

    def get_degist text
      if is_degist? text
        (/[0-9]+/.match text)[0]
      else
        -1
      end
    end

    def same_rank? x1, x2, abs=3
      (x1-x2).abs < abs
    end

    def text_include_special_symbol? text
      #特殊符号
      ['，', '…', '√', '[0-9]+页', '\*', '：', '–', '！', '-', '^请'].each do |symbol|
        return true if /#{symbol}/.match text
      end
      return false
    end

    def is_special_4_level_node? line
      ["SET  （设置）按钮", "自动运行模式  AUTO", "打开/关闭制冷设备  AC  （空调自动运行）"].include? line.line_text
    end

    def is_same_garagraph? h1, h2
      ((h1-h2).abs+0.5).to_i == @file_configs[:same_garagraph_distance]
    end

    def is_end_lines? line
      line_text = line.line_text
      !!(/。$/.match line_text or /！$/.match line_text)  
    end

    def is_end_paragraph? line
      size = line.columns.first.font_size*5
      return unless is_end_lines?(line) 
      if line.begin_position > @file_configs[:first_children_end]
        return true if line.end_position < @file_configs[:second_children_end] - size
      end
      return true if line.end_position < @file_configs[:first_children_end] - size
      return false
    end

    def is_pic_desctription? line
      /^图[0-9]+/.match line.line_text.gsub(' ', '') and not is_end_lines? line
    end

    def is_catalog_destription? line
      line.columns.size == 1 and /^适用于/.match line.to_s and line.columns.first.font_size == @file_configs[:catalog_destription_size]
    end

    def is_bold_font? line
      max_size = line.columns.map(&:font_size).max
      max_size  == @file_configs[:bold_font_size] and (! is_end_lines? line)
    end

    def get_format_text text
      if is_catalog_line? text
        begin
          text = get_catalog_info_for_minus(text.split('…')[0])
        rescue Exception => e 
        end
      end

      if /^–/.match text
        text = text.sub('–', '- ')
      end

      text = text.gsub("*", "\\*")
      
      if /[0-9]+页/.match text.gsub(' ', '')
        text = text.gsub(/[0-9]+页/, '').strip
      end

      if /\*+图 [0-9]+/.match text
        text = text.gsub "图 ", "=>图"
      end

      if /^图 [0-9]+/.match text
        text = text.gsub "图 ", "图"
      end

      text = get_format_text_for_A6 text 
      text
    end

    def get_format_text_for_A6 text
      SPECAIL_SUB.each do |key, value|
        if text.include?("  #{key}") or text.include?("#{key}  ")
          text = text.gsub("  #{key}", "#{key}")
          text = text.gsub("#{key}  ", "#{key}")
          text = text.gsub("#{key}", value)
        end
      end
      text
    end

    def get_catalog_info_for_minus text
      #-转向信号灯和远光灯............... 将 - 号 后面添加一个空格
      origin_text = text
      begin
        minuses.each do |t|
          text = text.split('..').first.sub(t, '- ')
        end
      rescue Exception => e
        text = origin_text
      end
      return text
    end
  end
end