require 'rubygems'
require 'rake'
require 'rake/gempackagetask'
require 'active_record'
require "#{File.dirname(__FILE__)}/lib/models/blog"
require "#{File.dirname(__FILE__)}/lib/models/post"
require "#{File.dirname(__FILE__)}/lib/models/page"

name = "Thimblr"
version = File.exist?('VERSION') ? File.read('VERSION') : ""

Dir["#{File.dirname(__FILE__)}/lib/tasks/**/*.rake"].sort.each { |ext| load ext }

ActiveRecord::Base.establish_connection(
  :adapter => "postgresql",
  :database => "thimblr",
  :encoding => "UTF8",
  :username => "developer",
  :password => "password",
  :host => "localhost",
  :port => "5432"
)

ActiveRecord::Base.logger = Logger.new(STDOUT)

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = name
    gem.version = version
    gem.summary = %Q{Helper for Tumblr theme editors}
    gem.description = %Q{A webserver built to help you test tumblr themes as you edit them}
    gem.email = "jphastings@gmail.com"
    gem.homepage = "http://github.com/jphastings/Thimblr"
    gem.author = "JP Hastings-Spital"
    gem.add_dependency "sinatra",'>= 1.0'
    gem.add_dependency "launchy"
    gem.add_dependency "nokogiri"
    gem.files = FileList['lib/**/*','themes/*','config/*','views/*','public/**/**/*']
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :test => :check_dependencies

task :default => :install

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "#{name} #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end