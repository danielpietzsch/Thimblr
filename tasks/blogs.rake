namespace :blog do

  desc "Removes data of a blog and all its posts and pages"
  task :destroy do
    # TODO warnings, error handling. Don't delete demo data!!!
    blog = Blog.find_by_name(ENV['username'])
    blog.destroy
    puts "Blog '#{ENV['username']}' deleted!"
  end

end