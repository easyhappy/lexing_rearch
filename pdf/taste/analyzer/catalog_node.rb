module Analyzer
  class CatalogNode
    attr_accessor :name, :number, :children, :parent, :lines, :is_writed
    def initialize name, number=-1
      @name = name.strip
      @number = number.to_i
      @children = []
      @lines = []
      @parent = nil
      @is_writed = false
    end

    def << line
      @lines << line
    end

    def absolute_names
      parents = [name]
      p = parent
      while p
        parents << p.name
        p = p.parent
      end
      parents.reverse.join('|--|')
    end

    def is_level
      parents = [name]
      p = parent
      while p
        parents << p.name
        p = p.parent
      end
      parents.size
    end
  end
end