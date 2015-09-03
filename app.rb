require 'sinatra'
require 'sinatra/reloader' if development?
require 'dalli'
require 'fileutils'
require 'capybara-webkit'
require 'rmagick'

CACHE_MAX_AGE = 30 * 60 # 30mins

def cache
  @cache ||= Dalli::Client.new('127.0.0.1:11211')
end

def get_ytenki(code)
  code = code.gsub('-','/')
  path = "http://weather.yahoo.co.jp/weather/jp/#{code}.html"
  b = Capybara::Webkit::Driver.new('web_capture').browser
  b.visit(path)
  fname = "/tmp/weather#{$$}.png"
  b.render(fname, 1024, 650)
  blob = Magick::ImageList.new(fname).crop(25, 302, 642, 710).to_blob
  FileUtils.remove(fname)
  return blob
end

def valid_citycode?(t)
  t =~ /\d{2}\-\d{4}/
end

def valid_format?(f)
  %w(jpg).include?(f)
end

error 403 do
  "Access forbidden\n"
end

error 404 do
  "Not Found\n"
end

get '/' do
  haml :index
end

get '/d/:citycode.jpg' do
  citycode = params[:citycode]
  return 404 unless valid_citycode?(citycode)

  fname = "#{citycode}.jpg"
  img = cache.get(fname)
  unless img
    img = get_ytenki(citycode)
    cache.set(fname, img, CACHE_MAX_AGE)
  end

  cache_control :public, max_age: CACHE_MAX_AGE
  content_type 'image/jpeg'
  img
end

get '/purge/:citycode.jpg' do
  citycode = params[:citycode]
  return 404 unless valid_citycode?(citycode)

  fname = "#{citycode}.jpg"
  cache.delete(fname)

  'OK'
end
