require 'active_record'
require 'mysql2'
require 'net/ssh/gateway'
=begin
#admin.wheel365.com
gateway = Net::SSH::Gateway.new(
 '121.201.8.251',
'deploy', :password => "?le123xing?")
port = gateway.open('127.0.0.1', 3306, 3307)

ActiveRecord::Base.establish_connection(
  :adapter  => "mysql2",
  :host     => "127.0.0.1",
  :username => "root",
  :password => "admin",
  :database => "wheel_production",
  :port     => port
)
=end
#local database
ActiveRecord::Base.establish_connection(
  :adapter  => "mysql2",
  :host     => "127.0.0.1",
  :username => "root",
  :password => "",
  :database => "wheel_development",
  :port     => 3306
)