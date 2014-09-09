# encoding: utf-8
require 'carrierwave-qiniu'
require 'carrierwave'
require 'config/initializers/carrierwave'

class ImageUploader < CarrierWave::Uploader::Base

  # Choose what kind of storage to use for this uploader:
  storage :qiniu

  self.qiniu_bucket = "pdf-image"
  self.qiniu_bucket_domain = "pdf-image.qiniudn.com"

  # Override the directory where uploaded files will be stored.
  # This is a sensible default for uploaders that are meant to be mounted:
  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  def filename
    var = :"@#{mounted_as}_filename"
    model.instance_variable_set(var, "#{secure_token}.#{file.extension.downcase}") if original_filename
  end

  protected
  def secure_token
    Digest::SHA1.hexdigest("#{model.id}-#{Time.now.to_i}")
  end

end
