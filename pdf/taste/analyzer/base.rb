module Analyzer
  module Base
    def strict_same_line? h1, h2, abs=5
      (h1-h2).abs < abs
    end

    def is_degist? text
      /^[0-9]+$/.match text
    end

    def is_catalog_line? text
      text.include?('..')
    end

    def get_degist text
      (/[0-9]+/.match text)[0]
    end
  end
end