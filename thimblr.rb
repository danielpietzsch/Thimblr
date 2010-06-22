require 'rubygems'
require 'sinatra'
require 'active_record'
require 'thimblr/parser'
require 'models/blog'
require 'models/post'
require 'models/page'

# class Thimblr::Application < Sinatra::Base

configure :production do
  
  dbconfig = YAML.load(File.read('config/database.yml'))
  ActiveRecord::Base.establish_connection dbconfig['production']
  ActiveRecord::Base.logger = Logger.new(STDOUT)
  
  begin
     ActiveRecord::Schema.define do
       create_table :blogs do |t|
         t.string :title
         t.text :description
         t.string :name
         t.timestamps
       end
       
       create_table :posts do |t|
         t.string :url, :url_with_slug, :post_type
         t.datetime :date_gmt, :date
         t.string :unix_timestamp, :format, :reblog_key, :slug
         t.integer :width, :height, :audio_plays
         t.string :postid
         t.text :content
         t.references :blog
         t.timestamps
       end
       
       create_table :pages do |t|
         t.string :url, :title, :link_title
         t.boolean :render_in_theme
         t.text :body
         t.references :blog
         t.timestamps
       end
     end
     rescue ActiveRecord::StatementInvalid
       puts "DB schema already exists. Not creating again."
     end
end
  
  # configure do |s|
    # set :root, File.dirname(__FILE__)
    # Dir.chdir root
    # set :config, File.join(root,'config')
    # 
    # # enable :sessions
    # # set :bind, '127.0.0.1'
    # 
    # 
    # # Database connection #################
    # 
    # dbconfig = YAML.load(File.read('config/database.yml'))
    # ActiveRecord::Base.establish_connection dbconfig['development']
    # 
    # ActiveRecord::Base.logger = Logger.new(STDOUT)

    #######################################
    
    # begin
    #    ActiveRecord::Schema.define do
    #      create_table :blogs do |t|
    #        t.string :title
    #        t.text :description
    #        t.string :name
    #        t.timestamps
    #      end
    #      
    #      create_table :posts do |t|
    #        t.string :url, :url_with_slug, :post_type
    #        t.datetime :date_gmt, :date
    #        t.string :unix_timestamp, :format, :reblog_key, :slug
    #        t.integer :width, :height, :audio_plays
    #        t.string :postid
    #        t.text :content
    #        t.references :blog
    #        t.timestamps
    #      end
    #      
    #      create_table :pages do |t|
    #        t.string :url, :title, :link_title
    #        t.boolean :render_in_theme
    #        t.text :body
    #        t.references :blog
    #        t.timestamps
    #      end
    #    end
    #    rescue ActiveRecord::StatementInvalid
    #      puts "DB schema already exists. Not creating again."
    #    end
    
  # end
  
  get '/' do
    redirect 'index.html'
  end
  
  get '/env' do
    content_type 'text/plain'
    ENV.inspect
  end

  post '/preview' do
    # TODO add error handling when no theme_code supplied or doesn't seem to be a tumblr theme
    params[:username].blank? ? username = 'demo' : username = params[:username] 
    
    parser = Thimblr::Parser.new(params[:theme_code], username)
    parser.render_index
  end

#end