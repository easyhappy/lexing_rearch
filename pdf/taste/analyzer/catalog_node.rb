module Analyzer
  class CatalogNode
    attr_accessor :name, :number, :children, :parent
    def initialize name, number
      @name = name.strip
      @number = number.to_i
      @children = []
      @parent = nil
    end
  end
end