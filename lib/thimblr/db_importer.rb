require 'open-uri'
require 'nokogiri'
require 'yaml'
require 'uri'

module Thimblr
  class DBImport
    def self.username(username)
      
      begin
        # 15 posts is enough. It's also the maximum of posts on the first page
        xml = Nokogiri::XML(open("http://#{username}.tumblr.com/api/read?num=15"))
      rescue OpenURI::HTTPError
        raise "Username not found"
      end
      
      blog = ImportedBlog.find_or_create_by_name(xml.search('tumblelog')[0]['name']) do |blog|
        blog.title = xml.search('tumblelog')[0]['title']
        blog.description = xml.search('tumblelog')[0].content
        # TODO remove (Google Analytics) <script> tags
      end
      
      posts_to_import = xml.search('posts post')
      
      posts_to_import.each do |post_to_import|        
        post = Post.find_or_create_by_postid(post_to_import['id']) do |post|
          post.url            = post_to_import['url']
          post.url_with_slug  = post_to_import['url-with-slug']
          post.post_type      = post_to_import['type'].capitalize
          post.date_gmt       = post_to_import['date-gmt']
          post.date           = post_to_import['date']
          post.unix_timestamp = post_to_import['unix-timestamp']
          post.format         = post_to_import['format']
          post.reblog_key     = post_to_import['reblog-key']
          post.slug           = post_to_import['slug']
          post.audio_plays    = post_to_import['audio-plays'] # audio posts only
          post.width          = post_to_import['width'] # photo posts only
          post.height         = post_to_import['height'] # photo posts only
          post.imported_blog  = blog
          
          # FIXME importing tags needs to be fixed
          # FIXME photo urls
          post.content = Hash.new          
          post_to_import.children.each do |child|
            post.content[child.name.to_sym] = child.content
          end
        end
        
        # 'Tags' => post_to_import.search('tag').collect{ |tag| tag.content }    
        # post['Type'] = "Text" if post['Type'] == "Regular"
        # post['Type'] = "Chat" if post['Type'] == "Conversation"
    
        # post.store('Title', post_to_import.search("#{post_to_import['type']}-title")[0].content) rescue nil
        # post.store('Caption',post_to_import.search("#{post_to_import['type']}-caption")[0].content) rescue nil
        # post.store('LinkURL',post_to_import.search("#{post_to_import['type']}-link-url")[0].content) rescue nil
        # post.store('Source',post_to_import.search("#{post_to_import['type']}-source")[0].content) rescue nil
    
        # case post['Type']
        # when "Photo"
        #   post_to_import.search('photo-url').each do |photo|
        #     post["PhotoURL-#{photo['max-width']}"] = photo.content
        #   end
        # when "Link"
        #   begin
        #     post['Name'] = post_to_import.search("link-text")[0].content
        #   rescue
        #   end
        # when "Video"
        #   post['Player'] = post_to_import.search("video-player")[0].content
        # when "Text"
        #   post['Body'] = post_to_import.search("regular-body")[0].content
        # end
      end
      
      # Pages
      # begin
      #   xml = Nokogiri::XML(open("http://#{username}.tumblr.com/api/pages"))
      #   data['Pages'] = []
      #   
      #   xml.search('pages').children.each do |re|
      #     case re.name
      #     when "redirect"
      #       data['Pages'].push({
      #         "Label" => re['link-title'],
      #         "URL"   => re['redirect-to']
      #       })
      #     when "page"
      #       data['Pages'].push({
      #         "Label"   => re['link-title'],
      #         "URL"     => URI.split(re['url'])[5],
      #         "Title"   => re['title'],
      #         "InTheme" => (re['render-in-theme'] == "true"),
      #         "Body"    => re.content
      #       })
      #     end
      #   end
      #   # Do pages
      # rescue OpenURI::HTTPError
      #   # No pages
      # end
    end
  end
end