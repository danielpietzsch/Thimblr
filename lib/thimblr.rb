require 'rubygems'
require 'sinatra'
# require 'json'
# require 'digest/md5'
# require 'pathname'
require 'active_record'
require 'thimblr/parser'
# require 'thimblr/db_parser'
require 'thimblr/db_importer'
require 'models/imported_blog'
require 'models/post'
require 'models/page'
# require 'rbconfig'
require 'fileutils'

# Database connection and configuration #################

ActiveRecord::Base.establish_connection(
  :adapter => "postgresql",
  :database => "thimblr",
  :encoding => "UTF8",
  :username => "developer",
  :password => "password",
  :host => "localhost",
  :port => "5432"
)

ActiveRecord::Base.logger = Logger.new(STDOUT)

##########################################################

class Thimblr::Application < Sinatra::Base
  
  configure do |s|
    set :root, File.join(File.dirname(__FILE__),"..")
    Dir.chdir root
    set :config, File.join(root,'config')
    
    enable :sessions
    set :bind, '127.0.0.1'
  end

  helpers do
    def get_relative(path)
      Pathname.new(path).relative_path_from(Pathname.new(File.expand_path(settings.root))).to_s
    end
  end
  
  get '/' do
    erb :index
  end

  post '/preview' do
    parser = Thimblr::Parser.new(params[:theme_code])
    parser.render_posts
  end

end