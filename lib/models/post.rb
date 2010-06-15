class Post < ActiveRecord::Base
  attr_accessible :postid, :url, :url_with_slug,
                  :post_type, :date_gmt, :date,
                  :unix_timestamp, :format, :reblog_key,
                  :slug, :audio_plays, :width, :height
                  
  serialize :content, Hash
  
  belongs_to :imported_blog
  
  default_scope :order => "date DESC"
end