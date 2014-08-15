require 'carrierwave'
require 'carrierwave/orm/activerecord'
require 'carrierwave-qiniu'
require 'config/initializers/carrierwave'
require 'uploaders/image_uploader'

class Picture < ActiveRecord::Base
  mount_uploader :image, ImageUploader
end
