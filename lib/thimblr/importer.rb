require 'open-uri'
require 'nokogiri'
require 'uri'

module Thimblr
  class Import
    
    def self.username(username)  
      begin
        # 15 posts is enough. It's also the maximum of posts per page
        xml = Nokogiri::XML(open("http://#{username}.tumblr.com/api/read?num=15"))
      rescue OpenURI::HTTPError
        raise "Username not found"
      end
      
      @blog = ImportedBlog.find_or_create_by_name(xml.search('tumblelog')[0]['name']) do |blog|
        blog.title = xml.search('tumblelog')[0]['title']
        blog.description = xml.search('tumblelog')[0].content
        # TODO remove (Google Analytics) <script> tags!?
      end
      
      import_posts(xml.search('posts post'))     
      import_pages(username)
    end # of self.username
    
    ######################
    protected
    ######################
    
    def self.import_posts(posts_to_import)
      posts_to_import.each do |post_to_import|        
        # This works, because post-ids are unique across all Tumblr blogs. However, this is not guaranteed forever.
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
          post.imported_blog  = @blog
          
          post.content = Hash.new

          # import all content, such as title, body etc.
          post_to_import.children.each do |child|
            post.content[child.name.to_sym] = child.content unless child.name == 'tag' or child.name == 'photo-url'
          end
          
          # special handling for tags and photo urls
          post.content[:tags] = post_to_import.search('tag').collect { |tag| tag.content }
          
          post_to_import.search('photo-url').each do |photo|
            post.content[:"photo_url_#{photo['max-width']}"] = photo.content
          end
          
        end
        
        # OPTIMIZE not sure yet, if I need these
        # post['Type'] = "Text" if post['Type'] == "Regular"
        # post['Type'] = "Chat" if post['Type'] == "Conversation"
      end
    end
    
    def self.import_pages(username)
      begin
        xml = Nokogiri::XML(open("http://#{username}.tumblr.com/api/pages"))
        
        # Only import pages. No redirects.
        pages_to_import = xml.search('pages page')
        
        pages_to_import.each do |page_to_import|      
          page = Page.find_or_create_by_url(page_to_import['url']) do |page|
            page.title           = page_to_import['title']
            page.link_title      = page_to_import['link-title']
            page.render_in_theme = page_to_import['render-in-theme']
            page.body            = page_to_import.content
            page.imported_blog   = @blog
          end    
        end
      rescue OpenURI::HTTPError
        # No Pages found. Didn't import anything.
      end
    end # of import_pages
    
  end # of class DBImport
end # of module Thimblr