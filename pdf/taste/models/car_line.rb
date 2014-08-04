class CarLine < ActiveRecord::Base
  validates :name, presence: true
  validates :annum, presence: true

  belongs_to :car_make
  has_many :car_models
  has_many :sections
end