class ImportedBlog < ActiveRecord::Base
  attr_accessible :title, :description, :name
  
  has_many :posts, :dependent => :destroy
  has_many :pages, :dependent => :destroy
end