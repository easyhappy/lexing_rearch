class CarMake < ActiveRecord::Base
  validates :name, presence: true
  has_many :car_lines
end