require 'base'
require 'models/picture'

class PageParagraph
  attr_accessor :current_page, :line_indexes, :type, :file_configs
  include Analyzer::Base

  CHANGE_HASH = {
    '提示' => '|![PDF5](http://pdf-image.qiniudn.com/uploads%2F7591f933980f08842ac98f9b00083c5a77ec3689.png)提示|',
    '警告' => '|![PDF2](http://pdf-image.qiniudn.com/uploads%2Ff26c6d59bf221a1937b45d7f85a5d8a09761f385.png)警告|',
    '小心' => '|![PDF3](http://pdf-image.qiniudn.com/uploads%2Fdee41f7fb4a72fbefd79dd1019039c85f4e227f4.png)小心|',
    '环境保护指南' => '|![PDF4](http://pdf-image.qiniudn.com/uploads%2Fbf1d656bc4b9f15a1695b7b71e789d98ecba1755.png)环境保护指南|'
  }

  def initialize page, begin_index, type, file_configs
    @current_page = page
    @line_indexes = [begin_index]
    @type = type
    @file_configs = file_configs
  end

  def << index
    @line_indexes << index
  end

  def to_s
    @line_indexes.map do |index|
      line = @current_page.lines[index]
      line.type == :image ? line.path : line.line_text
    end.join("\n") + "\n"
  end

  def analyzer_lines_with_markdown_format
    case @type
    when :table
      return analyzer_table_lines
    when :image
      return analyze_image_lines
    when :common
      return analyzer_common_lines
    end
  end

  private

  def analyzer_common_lines
    if @line_indexes.size == 1
      line =  @current_page.lines[@line_indexes[0]]
      if is_catalog_destription? line
        return  "<small>#{line.line_text}</small>\n"
      end

      #识别加粗 语句
      if is_bold_font? line
        return "**#{line.line_text}**\n"
      end
    end
    @line_indexes.map {|index| get_format_text @current_page.lines[index].line_text }.join('') + "\n"
  end

  def analyzer_table_lines
    lines = []
    line = @current_page.lines[@line_indexes[0]]
    header = CHANGE_HASH[line.line_text] || "|#{line.line_text}|"
    lines << [header, '| :--- |']

    bodys = merge_page_table_lines @line_indexes[1..-1]
    lines += bodys.map{|text| "|#{text}|"}
    lines.join("\n") + "\n"
  end

  def merge_page_table_lines indexes
    #将多行合并成 一行
    new_lines = ['']
    max_end_position = indexes.map{|index| @current_page.lines[index].end_position }.max

    indexes.each do |index|
      line = @current_page.lines[index]
      if is_end_lines? line and !same_rank?(max_end_position, line.end_position, line.columns.last.font_size)
        new_lines.last << line.line_text
        new_lines << ''
      elsif /^–/.match line.line_text
        new_lines << line.line_text
      else
        new_lines.last << line.line_text
      end
    end
    new_lines.map {|line| line unless line == ''}.compact
  end

  def analyze_image_lines
    line = @current_page.lines[@line_indexes[0]]
    pic_name = line.path.split('.')[0]
    file = File.new(File.join("./public/images/", line.path))
    md5  = Digest::MD5.hexdigest(file.read)
    picture = Picture.find_by_md5(md5)
    path = line.path
    if picture
      if @file_configs[:pic_force_save]
        picture.image = file
        picture.save
        path = picture.image_url
      end
    else
      if @file_configs[:pic_save]
         p = Picture.create(:caption => pic_name, :image => file, :md5 => md5)
        path = p.image_url
      end
    end
    pic_info = "![#{pic_name}](#{path})\n"
    [pic_info, @current_page.lines[@line_indexes[1]]].join("\n") + "\n"
  end

end