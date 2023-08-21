require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'tilt/erubis'

root = File.expand_path('..', __FILE__)

get '/' do
  @files = Dir.glob("#{root}/data/*").map do |path|
    File.basename(path)
  end
  erb :index
end
