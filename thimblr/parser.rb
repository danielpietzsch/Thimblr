require 'yaml'
require 'rubygems'
require 'nokogiri'
require 'active_support'

# OPTIMIZE use options hashes for improved readability
# Refactor a lot!

  class Parser                    
    Defaults = {
      'PostsPerPage'       => 10,
      'AskLabel'           => "Ask me anything",
      'SubmissionsEnabled' => true,
      'TwitterUsername'    => "tumblr",
      'RSS'                => '/rss',
      'CopyrightYears'     => '2009 - ' + Date.today.year.to_s,
      'Favicon'            => 'http://assets.tumblr.com/images/default_avatar_16.gif',
      'PortraitURL-16'     => "http://assets.tumblr.com/images/default_avatar_16.gif",
      'PortraitURL-24'     => "http://assets.tumblr.com/images/default_avatar_24.gif",
      'PortraitURL-30'     => "http://assets.tumblr.com/images/default_avatar_30.gif",
      'PortraitURL-40'     => "http://assets.tumblr.com/images/default_avatar_40.gif",
      'PortraitURL-48'     => "http://assets.tumblr.com/images/default_avatar_48.gif",
      'PortraitURL-64'     => "http://assets.tumblr.com/images/default_avatar_64.gif",
      'PortraitURL-96'     => "http://assets.tumblr.com/images/default_avatar_96.gif",
      'PortraitURL-128'    => "http://assets.tumblr.com/images/default_avatar_128.gif"
    }
    
    PostTypes = ["Text", "Regular", "Photo", "Photoset", "Quote", "Link", "Chat", "Conversation", "Audio", "Video", "Answer"]
    
    # loads default data, no matter what the sample data is.
    # this gives data from imported blogs some more stuff, since an un-authenticated API call doesn't reveal all data
    def load_default_data
      @following    = YAML::load(open("config/following.yml"))
      @followed     = YAML::load(open("config/followed.yml"))
      @groupmembers = YAML::load(open("config/groupmembers.yml"))
    end
    
    def initialize(theme_code, blog_name = "demo")
      @blog = Blog.find_or_import_by_name(blog_name)
      
      load_default_data
      
      @theme = ThemeSnippet.new(theme_code)
      # @theme = theme_code
      
      @apid = 0 # TODO rename
    end
    
    def render_index
      parse_meta_options
      
      @theme.render_block("IndexPage")
      @theme.render_block("More")
      
      render_posts unless @blog.posts.blank?
      
      # This is important to be rendered AFTER render_posts,
      # because of some ambigious variables (like Description or Title f.e.)
      @theme.replace_variable "Title", @blog.title
      
      if @blog.description.present?
        @theme.render_block "Description"
        @theme.replace_variable "Description", @blog.description
        @theme.replace_variable "MetaDescription", @blog.description.gsub(/\<\/?[^\>]*\>/, "")
      else
        @theme.strip_block "Description"
      end
        
        
      # Pages
      page_template = ThemeSnippet.new(fetch_content_of_block("Pages"))
      
      if @blog.pages.present? and page_template.present?
        all_pages = ThemeSnippet.new
      
        @blog.pages.each do |page|
          temp = page_template.dup
        
          temp.replace_variable "URL", page.url
          temp.replace_variable "Label", page.link_title
        
          all_pages += temp
        end
      
        @theme.render_block("HasPages", all_pages)
      else
        @theme.strip_block "HasPages"
      end
        
        
      
      #pagination
      @theme.replace_variable("CurrentPage", "1")
      @theme.replace_variable("NextPage", "/page/2")
      @theme.replace_variable("TotalPages", "100")
      
      @theme.render_block("Pagination")
      @theme.render_block("NextPage")
      @theme.strip_block("PreviousPage")
      
      render_following unless @following.blank?
      
      @theme.replace_variable "CopyrightYears", Defaults['CopyrightYears']
      @theme.replace_variable "RSS", Defaults['RSS']
      @theme.replace_variable "Favicon", Defaults['Favicon']
      @theme.replace_variable "PortraitURL-16", Defaults['PortraitURL-16']
      @theme.replace_variable "PortraitURL-24", Defaults['PortraitURL-24']
      @theme.replace_variable "PortraitURL-30", Defaults['PortraitURL-30']
      @theme.replace_variable "PortraitURL-40", Defaults['PortraitURL-40']
      @theme.replace_variable "PortraitURL-48", Defaults['PortraitURL-48']
      @theme.replace_variable "PortraitURL-64", Defaults['PortraitURL-64']
      @theme.replace_variable "PortraitURL-96", Defaults['PortraitURL-96']
      @theme.replace_variable "PortraitURL-128", Defaults['PortraitURL-128']
      
      disable_unsupported_stuff
      
      @theme.render_block "SearchForm"
      
      @theme.strip_block "PermalinkPage"
      @theme.strip_block "Permalink" # Seems to be an old version of PermalinkPage!?!
      @theme.strip_block "PostTitle"
      @theme.strip_block "PostSummary"
      
      # cleanup stuff
      @theme.gsub!(/\{block:([A-Za-z][A-Za-z0-9]*)\}((.|\s)*?)\{\/block:([A-Za-z][A-Za-z0-9]*)\}/i, '')
      
      # cleanup variables
      @theme.gsub!(/\{([A-Za-z][A-Za-z0-9\-]*)\}/i, '')
      
      #cleanup rest
      @theme.gsub!(/\{\/*?([A-Za-z][A-Za-z0-9\-:]*)\}/i, '')

      return @theme
    end
    
    
    def render_posts
      posts_template = ThemeSnippet.new(fetch_content_of_block("Posts"))
    
      #stores all rendered posts, concatenated together
      all_rendered_posts = ThemeSnippet.new
      template = ThemeSnippet.new
      
      @blog.posts.each do |post|
        template = posts_template.dup
        
        case post.post_type
        when 'Regular', 'Text'
          
          only_render_block_for_post_type(post.post_type, template) # TODO Regular or Text
          
          if post.content[:'regular-title'].nil?
            template.strip_block "Title"
          else
            template.render_block "Title", nil
            template.replace_variable "Title", post.content[:'regular-title']
          end
          
          template.replace_variable "Body", post.content[:'regular-body']
          
        when 'Photo'
          
          only_render_block_for_post_type("Photo", template)
          
          template.replace_variable "PhotoURL-500", post.content[:photo_url_500]
          template.replace_variable "PhotoURL-400", post.content[:photo_url_400]
          template.replace_variable "PhotoURL-250", post.content[:photo_url_250]
          template.replace_variable "PhotoURL-100", post.content[:photo_url_100]
          template.replace_variable "PhotoURL-75sq", post.content[:photo_url_75]
          template.replace_variable "PhotoURL-HighRes", post.content[:photo_url_1280]
          
          if post.content[:'photo-link-url'].nil?
            template.strip_variable "LinkOpenTag"
            template.strip_variable "LinkCloseTag"
            template.strip_variable "LinkURL"
          else
            template.replace_variable "LinkOpenTag", "<a href='post.content[:'photo-link-url']'>"
            template.replace_variable "LinkCloseTag", '</a>'
            template.replace_variable "LinkURL", post.content[:'photo-link-url']
          end
          
          if post.content[:'photo-caption'].nil?
            template.strip_block "Caption"
            template.strip_variable "PhotoAlt"
          else
            template.render_block "Caption", nil
            template.replace_variable "Caption", post.content[:'photo-caption']
            # OPTIMIZE wrap regex in meaningful method name!?
            template.replace_variable "PhotoAlt", post.content[:'photo-caption'].gsub(/\<\/?[^\>]*\>/, "")
          end
          
          if post.content[:photo_url_1280].present? and post.content[:photo_url_1280] != post.content[:photo_url_500]
            template.render_block "HighRes", nil
          else
            template.strip_block "HighRes"
          end
          
        # TODO render photoset posts
        when 'Photoset'
          
          only_render_block_for_post_type("Photoset")
          
        when 'Quote'
          
          only_render_block_for_post_type("Quote", template)
          
          template.replace_variable "Quote", post.content[:"quote-text"]
          template.replace_variable "Length", "medium" # TODO use 'real' values
          
          if post.content[:'quote-source'].present?
            template.render_block "Source", nil
            template.replace_variable "Source", post.content[:'quote-source']
          else
            template.strip_block "Source"
          end
          
        when 'Link'
          
          only_render_block_for_post_type("Link", template)
          
          template.replace_variable "URL", post.content[:'link-url']
          template.replace_variable "Name", post.content[:'link-text'] || post.content[:'link-url']
          template.replace_variable "Target", "target=\"_blank\""
          
          if post.content[:'link-description'].present?
            template.render_block "Description", nil
            template.replace_variable "Description", post.content[:'link-description']
          else
            template.strip_block "Description"
          end
          
        #TODO render chat posts 
        when 'Chat', 'Conversation'
          
          only_render_block_for_post_type(post.post_type, template)
          
          if post.content[:'conversation-title'].present?
            template.render_block "Title", nil
            template.replace_variable "Title", post.content[:'conversation-title']
          else
            template.strip_block "Title"
          end
          

          line_template = ThemeSnippet.new(fetch_content_of_block("Lines"))

          # stores the concatenated result of all the rendered following_templates
          all_lines = ThemeSnippet.new

          post.content[:lines].each_with_index do |line, i|
            temp = line_template.dup
            
            if line[:label].present?
              temp.render_block "Label", nil
              temp.replace_variable "Label", line[:label]
              temp.replace_variable "Name", line[:name]
            else
              temp.strip_block "Label"
            end
        
            temp.replace_variable "Line", line[:line]
            temp.replace_variable "Alt", i % 2 == 0 ? 'even' : 'odd'

            all_lines += temp
          end

          template.render_block "Lines", all_lines
          
        when 'Audio'
          
          only_render_block_for_post_type("Audio", template)
          
          if post.content[:'audio-caption'].present?
            template.render_block "Caption", nil
            template.replace_variable "Caption", post.content[:'audio-caption']
          else
            template.strip_block "Caption"
          end
          
          template.replace_variable "AudioPlayer", post.content[:'audio-player']
          template.replace_variable "AudioPlayerWhite", post.content[:'audio-player']
          template.replace_variable "AudioPlayerGrey", post.content[:'audio-player']
          template.replace_variable "AudioPlayerBlack", post.content[:'audio-player']
          
          # TODO {RawAudioUrl}
          
          template.replace_variable "PlayCount", post.audio_plays.to_s
          # see http://rubyforge.org/snippet/detail.php?type=snippet&id=8
          template.replace_variable "FormattedPlayCount", post.audio_plays.to_s.gsub(/(\d)(?=\d{3}+(?:\.|$))(\d{3}\..*)?/,'\1,\2')
          # OPTIMIZE make proper pluralization
          template.replace_variable "PlayCountWithLabel", post.audio_plays.to_s.gsub(/(\d)(?=\d{3}+(?:\.|$))(\d{3}\..*)?/,'\1,\2') + " plays"
          
          template.strip_block "ExternalAudio" # TODO find out how to render this properly
          
          # TODO find out how to read ID3 tags and render this properly
          template.strip_block "AlbumArt"
          template.strip_block "Artist"
          template.strip_block "Album"
          template.strip_block "TrackName"
          
        when 'Video'
          
          only_render_block_for_post_type "Video", template
          
          if post.content[:'video-caption'].present?
            template.render_block "Caption", nil
            template.replace_variable "Caption", post.content[:'video-caption']
          else
            template.strip_block "Caption"
          end
          
          # TODO fix the sizes
          template.replace_variable "Video-500", post.content[:'video-player']
          template.replace_variable "Video-400", post.content[:'video-player']
          template.replace_variable "Video-250", post.content[:'video-player']
          
        when 'Answer'
          
          only_render_block_for_post_type "Answer", template
        
          template.replace_variable "Question", post.content[:question]
          template.replace_variable "Answer", post.content[:answer]
          template.replace_variable "Asker", "Anonymous"
          
          template.replace_variable "AskerPortraitUrl-16", 'http://assets.tumblr.com/images/default_avatar_16.gif'
          template.replace_variable "AskerPortraitUrl-24", 'http://assets.tumblr.com/images/default_avatar_24.gif'
          template.replace_variable "AskerPortraitUrl-30", 'http://assets.tumblr.com/images/default_avatar_30.gif'
          template.replace_variable "AskerPortraitUrl-40", 'http://assets.tumblr.com/images/default_avatar_40.gif'
          template.replace_variable "AskerPortraitUrl-48", 'http://assets.tumblr.com/images/default_avatar_48.gif'
          template.replace_variable "AskerPortraitUrl-64", 'http://assets.tumblr.com/images/default_avatar_64.gif'
          template.replace_variable "AskerPortraitUrl-96", 'http://assets.tumblr.com/images/default_avatar_96.gif'
          template.replace_variable "AskerPortraitUrl-128", 'http://assets.tumblr.com/images/default_avatar_128.gif'
        
        end # of case
        
        # stuff for all post types
        template.replace_variable "Permalink", post.url_with_slug
        template.replace_variable "ShortURL", "http://tumblr.com/xpv5qtavm"
        template.replace_variable "PostID", post.postid
        
        # Dates http://www.tumblr.com/docs/en/custom_themes#dates
        template.render_block "Date", nil
        template.replace_variable "DayOfMonth", post.date.day.to_s
        template.replace_variable "DayOfMonthWithZero", post.date.strftime("%d")
        template.replace_variable "DayOfWeek", post.date.strftime("%A")
        template.replace_variable "ShortDayOfWeek", post.date.strftime("%a")
        template.replace_variable "DayOfWeekNumber", (post.date.strftime("%w").to_i + 1).to_s
        template.replace_variable "DayOfMonthSuffix", "th" #FIXME fix day suffix
        template.replace_variable "DayOfYear", post.date.strftime("%j")
        template.replace_variable "WeekOfYear", post.date.strftime("%W")
        template.replace_variable "Month", post.date.strftime("%B")
        template.replace_variable "ShortMonth", post.date.strftime("%b")
        template.replace_variable "MonthNumber", post.date.month.to_s
        template.replace_variable "MonthNumberWithZero", post.date.strftime("%w")
        template.replace_variable "Year", post.date.strftime("%w")
        template.replace_variable "ShortYear", post.date.strftime("%y")
        template.replace_variable "CapitalAmPm", post.date.strftime("%p")
        template.replace_variable "AmPm", post.date.strftime("%p").downcase
        template.replace_variable "12Hour", post.date.strftime("%I").sub(/^0/,"")
        template.replace_variable "24Hour", post.date.hour.to_s
        template.replace_variable "12HourWithZero", post.date.strftime("%I")
        template.replace_variable "24HourWithZero", post.date.strftime("%H")
        template.replace_variable "Minutes", post.date.strftime("%M")
        template.replace_variable "Seconds", post.date.strftime("%S")
        template.replace_variable "Beats", ((post.date.usec / 1000).round).to_s
        template.replace_variable "TimeAgo", "some time ago"
        template.replace_variable "Timestamp", post.unix_timestamp
        
        # Tags
        tag_template = ThemeSnippet.new(fetch_content_of_block("Tags"))
        
        if post.content[:tags].present? and tag_template.present?
          template.render_block "HasTags", nil

          # stores the concatenated result of all the rendered following_templates
          all_tags = ThemeSnippet.new

          post.content[:tags].each do |tag|
            temp = tag_template.dup
            temp.replace_variable "Tag", tag
            temp.replace_variable "URLSafeTag", tag.underscore
            temp.replace_variable "TagURL", "/tagged/#{tag}"
            temp.replace_variable "TagURLChrono", "/tagged/#{tag}"

            all_tags += temp
          end

          template.render_block "Tags", all_tags
        else
          template.strip_block "HasTags"
        end

        all_rendered_posts += template
      end
      
      @theme.render_block "Posts", all_rendered_posts
    end
    
    
    # pass in a post_type and the posts template ({block:Posts})
    # will render the block of the post_type and remove all others
    def only_render_block_for_post_type(post_type, posts_template)
      if post_type == 'Text' and !block_exists?(post_type, posts_template)
        if block_exists?('Regular', posts_template)
          post_type = 'Regular'
        end
      elsif post_type == 'Regular' and !block_exists?(post_type, posts_template)
        if block_exists?('Text', posts_template)
          post_type = 'Text'
        end
      end
      
      if post_type == 'Chat' and !block_exists?(post_type, posts_template)
        if block_exists?('Conversation', posts_template)
          post_type = 'Conversation'
        end
      elsif post_type == 'Conversation' and !block_exists?(post_type, posts_template)
        if block_exists?('Chat', posts_template)
          post_type = 'Chat'
        end
      end
      
      types_to_remove = PostTypes.reject { |type| type == post_type }
      
      types_to_remove.each { |type| posts_template.strip_block(type) }
      
      posts_template.render_block post_type, nil
    end
    
    
    def block_exists?(block_name, string = @theme)
      if string.match(block_regex_pattern_for(block_name))
        true
      else
        false
      end
    end
    
    
    # stuff that is currently unsupported by thimblr
    # This also serves as a TODO list
    def disable_unsupported_stuff
      @theme.strip_block "Likes"
      @theme.strip_block "SearchPage"
      @theme.replace_variable "SearchQuery", ""
      @theme.replace_variable "URLSafeSearchQuery", ""
      @theme.replace_variable "SearchResultCount", ""
      @theme.strip_block "NoSearchResults"
      @theme.strip_block "Twitter"
      @theme.strip_block "TagPage"
      @theme.strip_block "DayPage"
      @theme.strip_block "DayPagination"
      @theme.strip_block "PreviousDayPage"
      @theme.strip_block "NextDayPage"
      @theme.strip_block "PostNotes"
      @theme.strip_block "NoteCount"
      @theme.strip_block "GroupMembers"
      @theme.strip_block "GroupMember"
      @theme.strip_block "RebloggedFrom"
      @theme.strip_block "Reblog"
      @theme.render_block "NotReblog" # OPTIMIZE currently only enabled because testing with Redux theme
      @theme.strip_block "FromMobile"
      @theme.strip_block "FromBookmarklet"
    end
    
    # renders blocks 'Following' and 'Followed'
    # How it works:
    # 1. Fetch contents of the block 'Followed' and store it as a template for each followed blog
    # 2. For each followed blog, replace the variables of the template with the appropriate replacement
    # 3. Concatenate the rendered code of each followed blog into a string
    # 4. Render block 'Followed' and replace original contents with the concatenated string
    # 5. Render block 'Following' 
    def render_following
      following_template = fetch_content_of_block("Followed")
      
      if following_template.present?
        # stores the concatenated result of all the rendered following_templates
        rendered_followed = String.new
      
        # FIXME use replace_variable
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
      
        @theme.render_block "Followed", rendered_followed
        @theme.render_block "Following"
      end
    end
    
    # returns the contents of the provided block
    def fetch_content_of_block(block_name)
      @theme.match(block_regex_pattern_for(block_name))
      block_content = $2 #@theme.match(block_regex_pattern_for(block_name))[2]
    end
    
    # The regular expression to match a block and its contents
    # matchdata $2 will be the content of the block
    def block_regex_pattern_for(block_name)  
      Regexp.new(/\{block:(#{block_name})\}((.|\s)*?)\{\/block:(#{block_name})\}/i)
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
          @theme.replace_variable(element['name'], element['content'])
        end
        
        # Handling Booleans: http://www.tumblr.com/docs/en/custom_themes#booleans
        if element['name'].include? 'if:'
          if element['content'] == "1"
            # converts something like "if:Show People I Follow" to "IfShowPeopleIFollow"
            @theme.render_block(element['name'].titlecase.gsub(/\W/, ''))
            # converts something like "if:Show People I Follow" to "IfNotShowPeopleIFollow"
            @theme.strip_block(element['name'].titlecase.gsub(':', 'Not').gsub(/\W/, ''))
          else
            @theme.strip_block(element['name'].titlecase.gsub(/\W/, ''))
            @theme.render_block(element['name'].titlecase.gsub(':', 'Not').gsub(/\W/, ''))
          end
        end
        
        # Handling custom text: http://www.tumblr.com/docs/en/custom_themes#custom-text
        if element['name'].include? 'text:'
          if element['content'].present?
            @theme.replace_variable(element['name'], element['content'])
            # converts something like "text:Flickr Username" to "IfFlickrUsername"
            @theme.render_block(element['name'].gsub('text', 'if').titlecase.gsub(/\W/, ''))
          else
            @theme.strip_block(element['name'].gsub('text', 'if').titlecase.gsub(/\W/, ''))
          end
        end
        
        # Handling custom images: http://www.tumblr.com/docs/en/custom_themes#custom-images
        if element['name'].include? 'image:'
          if element['content'].present?
            @theme.replace_variable(element['name'], element['content'])
            # converts something like "image:Header" Username" to "IfHeaderImage"
            @theme.render_block(element['name'].gsub('image', 'if').titlecase.gsub(/\W/, '') + "Image")
            # converts something like "image:Header" Username" to "IfNotHeaderImage"
            @theme.strip_block(element['name'].gsub('image', 'if').titlecase.gsub(':', 'Not').gsub(/\W/, '') + "Image")
          else
            @theme.strip_block(element['name'].gsub('image', 'if').titlecase.gsub(/\W/, '') + "Image")
            @theme.render_block(element['name'].gsub('image', 'if').titlecase.gsub(':', 'Not').gsub(/\W/, '') + "Image")
          end
        end
      end # of meta_elements each
      
      # Removing {CustomCSS}
      @theme.strip_variable("CustomCSS")
    end # of method generate_meta
    
    
    
  end # of class