module Analyzer
  module Base
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
  end
end