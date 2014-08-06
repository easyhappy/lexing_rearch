module Analyzer
  class CatalogNode
    attr_accessor :name, :number, :children, :parent, :lines
    def initialize name, number=-1
      @name = name.strip
      @number = number.to_i
      @children = []
      @lines = []
      @parent = nil
    end

    def << line
      @lines << line
    end
  end
end