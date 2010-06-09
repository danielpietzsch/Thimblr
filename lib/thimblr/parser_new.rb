
require 'yaml'
require 'cgi'
require 'time'

module Thimblr
  class ParserNew
    BackCompatibility = {"Type" => { "Regular"      => "Text",
                                     "Conversation" => "Chat" }
    }
                        
    Defaults = {
      'PostsPerPage'       => 10,
      'AskLabel'           => "Ask me anything",
      'SubmissionsEnabled' => true,
      'TwitterUsername'    => "tumblr",
      'RSS'                => '/rss',
      'Favicon'            => 'http://assets.tumblr.com/images/default_avatar_16.gif',
      'PortraitURL-16'     => "http://30.media.tumblr.com/avatar_013241641371_16.png",
      'PortraitURL-24'     => "http://30.media.tumblr.com/avatar_013241641371_24.png",
      'PortraitURL-30'     => "http://30.media.tumblr.com/avatar_013241641371_30.png",
      'PortraitURL-40'     => "http://30.media.tumblr.com/avatar_013241641371_40.png",
      'PortraitURL-48'     => "http://30.media.tumblr.com/avatar_013241641371_48.png",
      'PortraitURL-64'     => "http://30.media.tumblr.com/avatar_013241641371_64.png",
      'PortraitURL-96'     => "http://30.media.tumblr.com/avatar_013241641371_96.png",
      'PortraitURL-128'    => "http://30.media.tumblr.com/avatar_013241641371_128.png"

    }
    
    # loads default data, no matter what the sample data is.
    # this gives data from imported blogs some more stuff, since an un-authenticated API call doesn't reveal all data
    def load_default_data
      @following    = YAML::load(open("config/following.yml"))
      @followed     = YAML::load(open("config/followed.yml"))
      @groupmembers = YAML::load(open("config/groupmembers.yml"))
    end
    
    def initialize(theme_code, blog_name = "demo")
      blog = ImportedBlog.find_by_name(blog_name)
      template = YAML::load(open("config/demo.yml"))
  
      @posts = blog.posts
      
      load_default_data
      
      @theme = theme_code
    end
    
    def render_index
      return @theme
    end
    
  end # of class
end # of module