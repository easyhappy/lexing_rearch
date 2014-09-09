#coding: utf-8
require 'pry'
require 'nokogiri'
class ImageColumn
  attr_accessor :path , :top, :left
  def initialize path, top, left
    @path = path
    @top  = top
    @left = left
  end
end

class ImageHandler
  def initialize base_path, file_name
    @file_name = File.join(base_path, file_name)
    @base_path = base_path
  end

  def run
    @images = {}
    page_number = 0
    @images[0] = []
    File.open @file_name do |file|
      while line=file.gets
        if line.include?("><img")
          doc = Nokogiri::HTML(line)
          #获取div top 和left值
          styles = Hash[doc.css('div')[0].attributes['style'].value.split(';').map do |l| l.split(':').map(&:strip) end]
          top    = styles["top"].sub('px', '').to_i
          left   = styles['left'].sub('px', '').to_i
          width  = styles['width'].sub('px', '').to_i
          if width < 30
            next
          end
          image  = doc.css('div img')[0].attributes['src'].value
          @images[page_number] << (ImageColumn.new image, top, left)  
        end
        if line.include?("<hr size= 2 width= 784 noshade></hr>")
          page_number += 1
          @images[page_number] = []
        end
      end
    end
  end

  def page_image page_number
    imgs = @images[page_number]
    return imgs.map(&:path) if imgs.size <= 1
    new_imgs = {}
    imgs.each do |item|
      left = item.left
      new_imgs[left] ||= []
      new_imgs[left] << item
    end
    new_imgs.each do |key, value|
      new_imgs[key] = value.sort {|a, b| a.top <=> b.top}
    end
    paths = new_imgs.sort.map(&:last).flatten.map(&:path)
  end
end