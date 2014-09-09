class CarModel < ActiveRecord::Base
  validates :name, presence: true
  belongs_to :car_line
end
