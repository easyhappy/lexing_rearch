class ContentColumn
  attr_accessor :font_size, :width, :text, :last_position, :type, :begin_position, :height
  def initialize(char)
    @text = char.text
    @font_size = char.font_size
    @width     = char.width
    @last_position = char.x
    @begin_position = char.x
    @height = char.y
  end

  def << char
    if is_English_or_digest_char?(char.text) == 0 and (char.x - @last_position) > 1.5*char.width
      @text += " #{char.text}"
    else
      @text += char.text
    end
    @last_position = char.x
  end

  def is_English_or_digest_char?(text)
    text =~ /[A-Za-z0-9]/
  end

  def to_s
    "字体： #{text}  , begin: #{begin_position}    , end: #{last_position}"
    [text, begin_position, last_position, font_size, height].to_s
  end
end