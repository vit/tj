#\ -p 9000

app_path = ::File.expand_path(::File.dirname __FILE__)
include_path = ::File.expand_path( ::File.join(app_path, '/../../') )
$:.unshift include_path, app_path

require 'templatejuggler'

views_path = ::File.join(app_path, 'views')
lm = ::TJ.new( ::TJ::SimpleLoader.new( views_path ) )

map '/' do
	run lambda { |env| [
		200, {'Content-Type' => 'text/html'}, [ lm.render('/index') ]
	] }
end

puts "See: http://localhost:9000/"

