# A parser for tumblr themes
#
#
# TODO
# ====
# * Add a logger so errors with the parse can be displayed
# * Likes
# * More blocks
# * Auto summary? Description tag stripping?

require 'yaml'
require 'cgi'
require 'time'

module Thimblr
  class Parser
    BackCompatibility = {"Type" => { "Regular"      => "Text",
                                     "Conversation" => "Chat" }
    }
                        
    Defaults = {
      'PostsPerPage'       => 10,
      'AskLabel'           => "Ask me anything",
      'SubmissionsEnabled' => true,
      'TwitterUsername'    => "tumblr",
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
      
      @constants = Hash.new
      @constants['TwitterUsername'] = Defaults['TwitterUsername']
      @constants['RSS']             = '/thimblr/rss'
      @constants['Favicon']         = '/favicon.ico'
      @constants['AskLabel']        = Defaults['AskLabel']
      
      @constants['PortraitURL-16']  = Defaults['PortraitURL-16']
      @constants['PortraitURL-24']  = Defaults['PortraitURL-24']
      @constants['PortraitURL-30']  = Defaults['PortraitURL-30']
      @constants['PortraitURL-40']  = Defaults['PortraitURL-40']
      @constants['PortraitURL-48']  = Defaults['PortraitURL-48']
      @constants['PortraitURL-64']  = Defaults['PortraitURL-64']
      @constants['PortraitURL-96']  = Defaults['PortraitURL-96']
      @constants['PortraitURL-128'] = Defaults['PortraitURL-128']
      
      @blocks = { # These are the defaults
        'Twitter'            => true,
        'Description'        => true,
        'Pagination'         => (@posts.length > Defaults['PostsPerPage']),
        'SubmissionsEnabled' => Defaults['SubmissionsEnabled'],
        'AskEnabled'         => true,
        'HasPages'           => (@pages.length > 0 rescue false),
        'Following'          => (@following.length > 0 rescue false),
        'Followed'           => (@followed.length > 0 rescue false),
        'More'               => true
      }
    end
    
    def initialize(theme_code, blog_name = "demo", settings = {})
      blog = ImportedBlog.find_by_name(blog_name)
      template = YAML::load(open("config/demo.yml"))
      @apid = 0
      @posts = ArrayIO.new(template['Posts'])
      @pages = template['Pages']
      
      load_default_data
      
      @constants['Title'] = blog.title
      @constants['Description'] = blog.description
      @constants['MetaDescription'] = CGI.escapeHTML(blog.description)
      
      @blocks['Description'] = false if blog.description.blank?
      
      set_theme(theme_code)
    end
  
    def set_theme(theme_html)
      @theme = theme_html
      # Changes for Thimblr
      @theme.gsub!(/href="\//,"href=\"/thimblr/")
      
      # Get the meta constants
      @theme.scan(/(<meta.*?name="(\w+):(.+?)".*?\/>)/).each do |meta|
        value = (meta[0].scan(/content="(.+?)"/)[0] || [])[0]
        if meta[1] == "if"
          @blocks[meta[2].gsub(/(?:\ |^)\w/) {|s| s.strip.upcase}] = (value == 1)
        else
          @constants[meta[1..-1].join(":")] = value
          @blocks[meta[2]+"Image"] = true if meta[1] == "image"
        end
      end
    end
  
    # Renders a tumblr page from the stored template
    def render_posts(page = 1)
      blocks = @blocks
      constants = @constants
      constants['TotalPages'] = (@posts.length / Defaults['PostsPerPage'].to_i).ceil
      blocks['PreviousPage'] = page > 1
      blocks['NextPage'] = page < constants['TotalPages']
      blocks['Posts'] = true
      blocks['IndexPage'] = true
      constants['NextPage'] = page + 1
      constants['CurrentPage'] = page
      constants['PreviousPage'] = page - 1
    
      # ffw thru posts array if required
      @posts.seek((page - 1) * Defaults['PostsPerPage'].to_i)
      parse(@theme,blocks,constants)
    end
  
    # Renders an individual post
    def render_permalink(postid)
      postid = postid.to_i
      blocks = @blocks
      constants = @constants
      @posts.delete_if do |post|
        post['PostId'] != postid
      end
      raise "Post Not Found" if @posts.length != 1
      
      blocks['Posts'] = true
      blocks['PostTitle'] = true
      blocks['PostSummary'] = true
      blocks['PermalinkPage'] = true
      blocks['PermalinkPagination'] = (@posts.length > 1)
      blocks['PreviousPost'] = (postid < @posts.length)
      blocks['NextPost'] = (postid > 0)
      constants['PreviousPost'] = "/thimblr/post/#{postid - 1}"
      constants['NextPost'] = "/thimblr/post/#{postid + 1}"
    
      # Generate a post summary if a title isn't present
      parse(@theme,blocks,constants)
    end
  
    # Renders the search page from the query
    def render_search(query)
      @searchresults = []
      blocks = @blocks
      constants = @constants
      blocks['NoSearchResults'] = (@searchresults.length == 0)
      blocks['SearchResults'] = !blocks['NoSearchResults'] # Is this a supported tag?
      blocks['SearchPage'] = true
      constants['SearchQuery'] = query
      constants['URLSafeSearchQuery'] = CGI.escape(query)
      constants['SearchResultCount'] = @searchresults.length
    
      parse(@theme,blocks,constants)
    end
  
    # Renders a special page
    def render_page(pageid)
      blocks = @blocks
      constants = @constants
      blocks['Pages'] = true
    
      parse(@theme,blocks,constants)
    end
  
    private
    def parse(string,blocks = {},constants = {})
      blocks = blocks.dup
      constants = constants.dup
      blocks.merge! constants['}blocks'] if !constants['}blocks'].nil?
      string.gsub(/\{block:([\w:]+)\}(.*?)\{\/block:\1\}|\{([\w\-:]+)\}/m) do |match| # TODO:add not block to the second term
        if $2 # block
          blockname = $1
          content = $2
          
          # Back Compatibility
          blockname = BackCompatibility['Type'][blockname] if !BackCompatibility['Type'][blockname].nil?
        
          inv = false
          case blockname
          when /^IfNot(.*)$/
            inv = true
            blockname = $1
          when /^If(.*)$/
            blockname = $1
          when 'Posts'
            if @blocks['Posts']
              lastday = nil
              posts = []
              Defaults['PostsPerPage'].times do |n|
                unless (post = @posts.advance).nil?
                  post['}blocks'] = {}
                  post['}blocks']['Date'] = true # Always render Date on Post pages
                  thisday = Time.at(post['Timestamp'])
                  post['}blocks']['NewDayDate'] = thisday.strftime("%Y-%m-%d") != lastday
                  post['}blocks']['SameDayDate'] = !post['}blocks']['NewDayDate']
                
                  lastday = thisday.strftime("%Y-%m-%d")
                  post['DayOfMonth'] = thisday.day
                  post['DayOfMonthWithZero'] = thisday.strftime("%d")
                  post['DayOfWeek'] = thisday.strftime("%A")
                  post['ShortDayOfWeek'] = thisday.strftime("%a")
                  post['DayOfWeekNumber'] = thisday.strftime("%w").to_i + 1
                  ordinals = ['st','nd','rd']
                  post['DayOfMonthSuffix'] = ([11,12].include? thisday.day) ? "th" : ordinals[thisday.day % 10 - 1]
                  post['DayOfYear'] = thisday.strftime("%j")
                  post['WeekOfYear'] = thisday.strftime("%W")
                  post['Month'] = thisday.strftime("%B")
                  post['ShortMonth'] = thisday.strftime("%b")
                  post['MonthNumber'] = thisday.month
                  post['MonthNumberWithZero'] = thisday.strftime("%w")
                  post['Year'] = thisday.strftime("%Y")
                  post['ShortYear'] = thisday.strftime("%y")
                  post['CapitalAmPm'] = thisday.strftime("%p")
                  post['AmPm'] = post['CapitalAmPm'].downcase
                  post['12Hour'] = thisday.strftime("%I").sub(/^0/,"")
                  post['24Hour'] = thisday.hour
                  post['12HourWithZero'] = thisday.strftime("%I")
                  post['24HourWithZero'] = thisday.strftime("%H")
                  post['Minutes'] = thisday.strftime("%M")
                  post['Seconds'] = thisday.strftime("%S")
                  post['Beats'] = (thisday.usec / 1000).round
                  post['TimeAgo'] = thisday.ago
                
                  post['Permalink'] = "http://127.0.0.1:4567/thimblr/post/#{post['PostId']}/" # TODO: Port number
                  post['ShortURL'] = post['Permalink'] # No need for a real short URL
                  post['TagsAsClasses'] = (constants['Tags'] || []).collect{ |tag| tag.gsub(/[^a-z]/i,"_").downcase }.join(" ")
                  post['}numberonpage'] = n + 1 # use a } at the begining so the theme can't access it
                
                  # Group Posts
                  if !post['GroupPostMember'].nil?
                    poster = nil
                    @groupmembers.each do |groupmember|
                      p groupmember
                      if groupmember['Name'] == post['GroupPostMemberName']
                        poster = Hash[*groupmember.to_a.collect {|key,value| ["PostAuthor#{key}",value] }.flatten]
                        break
                      end
                    end
                    p poster
                    if poster.nil?
                      # Add to log, GroupMemberPost not found in datafile
                    else
                      post.merge! poster
                    end
                  end
                
                  post['Title'] ||= "" # This prevents the site's title being used when it shouldn't be
                
                  case post['Type']
                  when 'Photo'
                    post['PhotoAlt'] = CGI.escapeHTML(post['Caption'])
                    if !post['LinkURL'].nil?
                      post['LinkOpenTag'] = "<a href=\"#{post['LinkURL']}\">"
                      post['LinkCloseTag'] = "</a>"
                    end
                  when 'Audio'
                    post['AudioPlayerBlack'] = audio_player(post['AudioFile'],"black")
                    post['AudioPlayerGrey'] = audio_player(post['AudioFile'],"grey")
                    post['AudioPlayerWhite'] = audio_player(post['AudioFile'],"white")
                    post['AudioPlayer'] = audio_player(post['AudioFile'])
                    post['}blocks']['ExternalAudio'] = !(post['AudioFile'] =~/^http:\/\/(?:www\.)?tumblr\.com/)
                    post['AudioFile'] = nil # We don't want this tag to be parsed if it happens to be in there
                    post['}blocks']['Artist'] = !post['Artist'].empty?
                    post['}blocks']['Album'] = !post['Album'].empty?
                    post['}blocks']['TrackName'] = !post['TrackName'].empty?
                  end
                
                  posts << post
                end
              end
            end
          # Post details
          when 'Title'
            blocks['Title'] = !constants['Title'].empty?
          when /^Post(?:[1-9]|1[0-5])$/
            blocks["Post#{$1}"] = true if constants['}numberonpage'] == $1
          when 'Odd'
            blocks["Post#{$1}"] = constants['}numberonpage'] % 2
          when 'Even'
            blocks["Post#{$1}"] = !(constants['}numberonpage'] % 2)
          # Reblogs
          when 'RebloggedFrom'
            if !constants['Reblog'].nil?
              blocks['RebloggedFrom'] = true
              constants.merge! constants['Reblog']
              constants.merge! constants['Root'] if !constants['Root'].nil?
            end
          # Photo Posts
          when 'HighRes'
            blocks['HighRes'] = !constants['HiRes'].empty?
          when 'Caption'
            blocks['Caption'] = !constants['Caption'].empty?
          when 'SearchPage'
            posts = @searchresults if blocks['SearchPage']
          # Quote Posts
          when 'Source'
            blocks['Source'] = !constants['Source'].empty?
          when 'Description'
            if !constants['Type'].nil?
              blocks['Description'] = !constants['Description'].empty?
            end
          # Chat Posts
          when 'Lines'
            alt = {true => 'odd',false => 'even'}
            iseven = false
            posts = constants['Lines'].collect do |line|
              parts = line.to_a[0]
              {"Line" => parts[1],"Label" => parts[0],"Alt" => alt[iseven = !iseven]}
            end
            constants['Lines'] = nil
            blocks['Lines'] = true
          when 'Label'
            blocks['Label'] = !constants['Label'].empty?
          # TODO: Notes
          # Tags
          when 'HasTags'
            if constants['Tags'].length > 0
              blocks['HasTags'] = true
            end
          when 'Tags'
            posts = constants['Tags'].collect do |tag|
              {"Tag" => tag,"URLSafeTag" => tag.gsub(/[^a-zA-Z]/,"_").downcase,"TagURL" => "/thimblr/tagged/#{CGI.escape(tag)}","ChronoTagURL" => "/thimblr/tagged/#{CGI.escape(tag)}"} # TODO: ChronoTagURL
            end
            blocks['Tags'] = posts.length > 0
            constants['Tags'] = nil
          # Groups
          when 'GroupMembers'
            if !constants['GroupMembers'].nil?
              blocks['GroupMembers'] = true
            end
          when 'GroupMember'
            posts = constants['GroupMembers'].collect do |groupmember|
              Hash[*groupmember.collect{ |key,value| ["GroupMember#{key}",value] }.flatten]
            end
            blocks['GroupMember'] = posts.length > 0
            constants['GroupMembers'] = nil
          # TODO: Day Pages
          # TODO: Tag Pages
          end
        
          # Process away!
          (posts || [constants]).collect do |consts|
            if (blocks[blockname] ^ inv) or consts['Type'] == blockname
              parse(content,blocks,(constants.merge consts))
            end
          end.join
        else
          constants[$3]
        end
      end
    end
  
    def audio_player(audiofile,colour = "") # Colour is one of 'black', 'white' or 'grey'
      case colour
      when "black"
        colour = "_black"
      when "grey"
        colour = ""
        audiofile += "&color=E4E4E4"
      when "white"
        colour = ""
        audiofile += "&color=FFFFFF"
      else
        colour = ""
      end
      @apid += 1
      return <<-END
        <script type="text/javascript" language="javascript" src="http://assets.tumblr.com/javascript/tumblelog.js?16"></script><span id="audio_player_#{@apid}">[<a href="http://www.adobe.com/shockwave/download/download.cgi?P1_Prod_Version=ShockwaveFlash" target="_blank">Flash 9</a> is required to listen to audio.]</span><script type="text/javascript">replaceIfFlash(9,"audio_player_#{@apid}",'<div class="audio_player"><embed type="application/x-shockwave-flash" src="/audio_player#{colour}.swf?audio_file=#{audiofile}" height="27" width="207" quality="best"></embed></div>')</script>
      END
    
    end
  end

  class ArrayIO < Array
    # Returns the currently selected item and advances the pointer
    def advance
      @position = @position + 1 rescue 1
      self[@position - 1]
    end
  
    # Returns the currently selected item and moves the pointer back one
    def retreat
      @position = @position - 1 rescue -1
      self[@position + 1]
    end
  
    def seek(n)
      self[@position = n]
    end
  
    def tell
      @position
    end
  end
  
  class Time < Time
    def ago
      "some time ago"
    end
  end
end

class NilClass
  def empty?
    true
  end
end

=begin
t = Thimblr::Parser.new("demo")
t.set_theme(open("themes/101.html").read)


puts t.render_posts
=end