$: << File.dirname(__FILE__) unless $:.include? File.dirname(__FILE__)

require 'pdf/reader'
require 'pry'
require 'sinatra'
require 'rack'
require 'slim'
require 'linguo'
require 'fileutils'
require 'sinatra/static_assets'

require 'image_handler'
require 'models/connect_remote_mysql'
require 'models/picture'

Sinatra::Application.reset!
use Rack::Reloader
use Rack::Static, :urls => ["/images"], :root => "public"
set :slim, :pretty => true
register Sinatra::StaticAssets

get '/' do
=begin
  @files = ['Audi+A4L+B8_cn.pdf', 'Audi+A5_cn.pdf', 
    'Audi+A6L+C7_cn.pdf', 'Audi+A6l+C7+MMI_cn.pdf', 'Audi+A8+D4_cn.pdf',
    'Audi+MMI+Navigation+plus+mit+RSE(D4)_cn.pdf', 'Audi+Q5_cn.pdf', 
    'Audi+Q7_cn.pdf']
=end
  @files = ['Audi+A4L+B8_cn.pdf','Audi+A8+D4_cn.pdf']
  file = @files[params[:file].to_i]
  base_path = './public/images/'
  path = "#{file.split('.')[0]}.htm"
  handler = ImageHandler.new(base_path, path)
  handler.run
  @images = handler.page_image((params[:page] || 1).to_i-1)
  @pic_paths = @images.map do |image|
    path = File.join("./public/images", image)
    file = File.new(path)
    md5 = Digest::MD5.hexdigest(file.read)
    picture = Picture.find_by_md5(md5)
    unless picture
      picture = Picture.create(:caption => image, :image => file, :md5 => md5)
    else
      picture.image = file
      picture.save
    end
    picture.image_url
  end
  slim :images
end

