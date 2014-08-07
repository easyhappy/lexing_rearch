module Analyzer
  module Base
    def strict_same_line? h1, h2, abs=5
      (h1-h2).abs < abs
    end

    def is_degist? text
      /^[0-9]+$/.match text
    end

    def is_catalog_line? text
      text.include?('..') or text.include?('…')
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
  end
end