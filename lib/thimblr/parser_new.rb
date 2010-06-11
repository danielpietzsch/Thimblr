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
      parse_meta_options
      
      render_block("IndexPage")
      render_block("More")
      
      #pagination
      render_variable("CurrentPage", "1")
      render_variable("NextPage", "/page/2")
      render_variable("TotalPages", "100")
      
      render_block("Pagination")
      render_block("NextPage")
      strip_block("PreviousPage")
      
      render_following

      return @theme
    end
    
    # renders blocks 'Following' and 'Followed'
    def render_following
      #following
      unless @following.blank?
        following_template = fetch_content_of_block("Followed")
        
        # stores the concatenated result of all the rendered following_templates
        rendered_followed = String.new
        
        @following.each do |blog|
          rendered_template = following_template.dup
          rendered_template.sub!(/\{FollowedName\}/i, blog['Name'])
          rendered_template.sub!(/\{FollowedTitle\}/i, blog['Title'])
          rendered_template.sub!(/\{FollowedURL\}/i, blog['URL'])
          rendered_template.sub!(/\{FollowedPortraitURL-16\}/i, blog['PortraitURL-16'])
          rendered_template.sub!(/\{FollowedPortraitURL-24\}/i, blog['PortraitURL-24'])
          rendered_template.sub!(/\{FollowedPortraitURL-30\}/i, blog['PortraitURL-30'])
          rendered_template.sub!(/\{FollowedPortraitURL-40\}/i, blog['PortraitURL-40'])
          rendered_template.sub!(/\{FollowedPortraitURL-48\}/i, blog['PortraitURL-48'])
          rendered_template.sub!(/\{FollowedPortraitURL-64\}/i, blog['PortraitURL-64'])
          rendered_template.sub!(/\{FollowedPortraitURL-96\}/i, blog['PortraitURL-96'])
          rendered_template.sub!(/\{FollowedPortraitURL-128\}/i, blog['PortraitURL-128'])
          
          rendered_followed += rendered_template
        end
        
        render_block("Followed", rendered_followed)
        render_block("Following")
      end
    end
    
    # returns the contents of the provided block
    def fetch_content_of_block(block_name)
      block_content = @theme.match(block_regex_pattern_for(block_name))[2]
    end
    
    # Scans the whole theme and replaces a variable with the replacement provided
    def render_variable(var_name, replacement)
      print "Replacing variable {#{var_name}}..."
      if @theme.gsub!(/\{#{var_name}\}/i, replacement)
        puts "with '#{replacement}'"
      else
        puts "no match found!"
      end
      
      #TODO handle variable transformations
    end
    
    # The regular expression to match a block and its contents
    def block_regex_pattern_for(block_name)  
      Regexp.new(/\{block:(#{block_name})\}((.|\s)*?)\{\/block:(#{block_name})\}/)
    end
    
    # looks for the block named 'block_name'
    # and replaces the whole block with just the content of the block or a provided replacement for this content
    def render_block(block_name, replacement = nil)
      print "Rendering block {block:#{block_name}}..."
      if @theme.gsub!(block_regex_pattern_for(block_name)) { |match| replacement || $2 }
        puts "found and replaced!"
      else
        puts "no match found!"
      end
    end
    
    # removes a whole block
    def strip_block(block_name)
      print "Stripping block {block:#{block_name}}..."
      if @theme.gsub!(block_regex_pattern_for(block_name), '')
        puts "removed!"
      else
        puts "no match found!"
      end
    end
    
    # handles <meta> tags Appearance Options
    # OPTIMIZE check whether in some cases sub is sufficient (instead of gsub)
    # OPTIMIZE maybe put every option type (color, font, boolean etc.) in a separate method
    def parse_meta_options
      doc = Nokogiri::HTML.parse(@theme)
      meta_elements = doc.search('meta')
      
      meta_elements.each do |element|
        break if element['name'].blank?
        
        # handling custom colors and fonts: http://www.tumblr.com/docs/en/custom_themes#appearance-options
        if element['name'].present? and element['content'].present? and (element['name'].include? 'color' or element['name'].include? 'font')
          render_variable(element['name'], element['content'])
        end
        
        # Handling Booleans: http://www.tumblr.com/docs/en/custom_themes#booleans
        if element['name'].include? 'if:'
          if element['content'] == "1"
            # converts something like "if:Show People I Follow" to "IfShowPeopleIFollow"
            render_block(element['name'].titlecase.gsub(/\W/, ''))
            # converts something like "if:Show People I Follow" to "IfNotShowPeopleIFollow"
            strip_block(element['name'].titlecase.gsub(':', 'Not').gsub(/\W/, ''))
          else
            strip_block(element['name'].titlecase.gsub(/\W/, ''))
            render_block(element['name'].titlecase.gsub(':', 'Not').gsub(/\W/, ''))
          end
        end
        
        # Handling custom text: http://www.tumblr.com/docs/en/custom_themes#custom-text
        if element['name'].include? 'text:'
          if element['content'].present?
            render_variable(element['name'], element['content'])
            # converts something like "text:Flickr Username" to "IfFlickrUsername"
            render_block(element['name'].gsub('text', 'if').titlecase.gsub(/\W/, ''))
          else
            strip_block(element['name'].gsub('text', 'if').titlecase.gsub(/\W/, ''))
          end
        end
        
        # Handling custom images: http://www.tumblr.com/docs/en/custom_themes#custom-images
        if element['name'].include? 'image:'
          if element['content'].present?
            render_variable(element['name'], element['content'])
            # converts something like "image:Header" Username" to "IfHeaderImage"
            render_block(element['name'].gsub('image', 'if').titlecase.gsub(/\W/, '') + "Image")
            # converts something like "image:Header" Username" to "IfNotHeaderImage"
            strip_block(element['name'].gsub('image', 'if').titlecase.gsub(':', 'Not').gsub(/\W/, '') + "Image")
          else
            strip_block(element['name'].gsub('image', 'if').titlecase.gsub(/\W/, '') + "Image")
            render_block(element['name'].gsub('image', 'if').titlecase.gsub(':', 'Not').gsub(/\W/, '') + "Image")
          end
        end
      end # of meta_elements each
      
      # Removing {CustomCSS}
      render_variable("CustomCSS", '')
    end # of method generate_meta
    
  end # of class
end # of module