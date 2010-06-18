class Page < ActiveRecord::Base
  attr_accessible :url, :title, :link_title, :render_in_theme, :body
  
  belongs_to :blog
end