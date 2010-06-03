class ImportedBlog < ActiveRecord::Base
  attr_accessible :title, :description
  
  has_many :posts
end