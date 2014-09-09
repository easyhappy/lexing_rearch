class Section < ActiveRecord::Base
  belongs_to :car_line
  belongs_to :parent, :class_name => "Section", :foreign_key => "parent_id"
  has_many :children, :class_name => "Section", :foreign_key => "parent_id"

  before_save :set_level,        :if => Proc.new {|section| section.level.nil? or section.parent_id_changed?}
  before_save :set_car_line_id,  :if => Proc.new {|section| section.car_line_id.nil? or section.parent_id_changed?}
  before_save :set_ancestor_ids, :if => Proc.new {|section| section.ancestor_ids.nil? or section.parent_id_changed?}
  before_save :compile_markdown, :if => Proc.new { |section| section.description }

  def ancestors
    ancestor_ids.nil? ? [] : Section.where(id: ancestor_ids.split(','))
  end

  private
  def set_level
    if self.parent_id
      self.level = parent.level + 1
    else
      self.level = 0
    end
  end

  def set_car_line_id
    if self.parent_id
      self.car_line_id = parent.car_line_id
    end
  end

  def set_ancestor_ids
    section = self
    ids = []
    while section.parent_id
      ids << section.parent_id
      section = section.parent
    end
    self.ancestor_ids = ids.reverse.join(',')
  end

  def compile_markdown
    options = {
      autolink: true,
      space_after_headers: true,
      fenced_code_blocks: true,
      no_intra_emphasis: true,
      hard_wrap: true,
      strikethrough: true
    }
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML,options)
    self.compiled = markdown.render(self.description)
  end
end
