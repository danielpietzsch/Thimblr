require 'rubygems'
require 'sinatra'
require 'active_record'
require 'thimblr/parser_new'
require 'models/blog'
require 'models/post'
require 'models/page'
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

  # Downloads feed data from a tumblr site
  get %r{/import/([a-zA-Z0-9-]+)} do |username|
    begin
      Thimblr::Import.username(username)
    rescue Exception => e
      halt 404, e.message
    end
    "Imported as '#{username}'"
  end

  post '/preview' do
    parser = Thimblr::ParserNew.new(params[:theme_code])
    parser.render_index
  end

end