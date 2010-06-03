class Post < ActiveRecord::Base
  attr_accessible :postid, :url, :url_with_slug, :post_type, :date_gmt
  belongs_to :imported_blog
end