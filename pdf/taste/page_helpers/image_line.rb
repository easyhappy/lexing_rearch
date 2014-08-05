class ImageLine
  attr_accessor :path, :type
  def initialize path
    @path = path
    @type = :image
  end

  def line_text
    ''
  end
end