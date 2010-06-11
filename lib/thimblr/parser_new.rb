require 'yaml'
require 'cgi'
require 'time'
require 'rubygems'
require 'nokogiri'
require 'active_support'

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
      generate_meta
      return @theme
    end
    
    # The regular expression to match a block and its contents
    def block_regex_pattern_for(block_name)      
      Regexp.new(/\{block:(#{block_name})\}((.|\s)*?)\{\/block:(#{block_name})\}/)
    end
    
    # looks for the block named 'block_name' and replaces the whole block with just the content of the block
    def render_block(block_name)
      print "Rendering block {block:#{block_name}}..."
      if @theme.gsub!(block_regex_pattern_for(block_name)) { |match| $2 }
        puts "found and replaced!"
      else
        puts "no match found!"
      end
    end
    
    # removes a whole block
    def strip_block(block_name)
      print "Stripping block {block:#{block_name}}..."
      if @theme.gsub!(block_regex_pattern_for(block_name), '')
        puts "found and replaced!"
      else
        puts "no match found!"
      end
    end
    
    
    def generate_meta
      doc = Nokogiri::HTML.parse(@theme)
      meta_elements = doc.search('meta')
      
      meta_elements.each do |element|
        if element['name'].present? and element['content'].present?
          # handling custom colors and fonts: http://www.tumblr.com/docs/en/custom_themes#appearance-options
          if element['name'].include? 'color' or element['name'].include? 'font'
            render_variable(element['name'], element['content'])
          end
          
          # Handling Booleans: http://www.tumblr.com/docs/en/custom_themes#booleans
          if element['name'].include? 'if:'
            if element['content'] == "1"
              render_block(element['name'].titlecase.gsub(/\W/, '')) # converts something like "if:Show People I Follow" to "IfShowPeopleIFollow"
              strip_block(element['name'].titlecase.gsub(':', 'Not').gsub(/\W/, '')) # converts something like "if:Show People I Follow" to "IfNotShowPeopleIFollow"
            else
              strip_block(element['name'].titlecase.gsub(/\W/, ''))
              render_block(element['name'].titlecase.gsub(':', 'Not').gsub(/\W/, ''))
            end
          end
        end        
      end # of meta_elements each
    end # of method generate_meta
    
    # Scans the whole theme and replaces a variable with the replacement provided
    def render_variable(var_name, replacement)
      @theme.gsub!(/\{#{var_name}\}/i, replacement)
      #TODO handle variable transformations
    end
    
  end # of class
end # of module