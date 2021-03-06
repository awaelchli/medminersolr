require 'json'
require 'open-uri'
require 'ruby-progressbar'
require_relative 'Downloader'
require_relative 'ArticleGetter'
require_relative 'PeopleGetter'
Thread.abort_on_exception=true

SETUP_FILE = Rails.root + "lib/resources/setup.sql"
#JSON - intersection of "Medizin" and "Mann" resp. "Frau" to filter out people later on
MEN_URL = "http://tools.wmflabs.org/catscan2/quick_intersection.php?lang=de&project=wikipedia&cats=Medizin%0D%0AMann&ns=0&depth=12&max=30000&start=0&format=json&redirects=&callback="
WOMEN_URL = "http://tools.wmflabs.org/catscan2/quick_intersection.php?lang=de&project=wikipedia&cats=Medizin%0D%0AFrau&ns=0&depth=12&max=30000&start=0&format=json&redirects=&callback=" 
#JSON - source of all articles in the category "Medizin"
ARTICLE_SOURCE = "http://tools.wmflabs.org/catscan2/quick_intersection.php?lang=de&project=wikipedia&cats=Medizin&ns=0&depth=-1&max=100000&start=0&format=json&redirects=&callback="
# Number of downloaders that will be run.
THREAD_NUMBER = 50

namespace :wiki do  
  
  desc "Downloads all pages from the category 'Medizin' from the German Wikipedia"
  task :download  => :environment do
    
    start = Time.now
    articles = download_article_data
    totalLength = articles.length
    
    #multiple instances of Downloader are run in separate threads, allowing a faster download speed. every downloader gets a subarray of the array containing the article data
    downloaders = []
    i = 0
    while i < THREAD_NUMBER
      client = connect_to_database
      downloaders << Downloader.new(client, articles[(totalLength/THREAD_NUMBER)*i+i..(totalLength/THREAD_NUMBER)*(i+1)+i], "Downloader#{i+1}")
      i+=1
    end
    
    threads = []
    downloaders.each do |d|
        threads << Thread.new{d.startDownload}
    end
    print "Running #{downloaders.count} downloaders on #{totalLength.to_i} entries...\n"
    pct = 0
    pBar = ProgressBar.create(:title => " Downloading articles: ", :total => totalLength, :format => '%t %p%% |%B| %a')
    sum = 0
    while sum < totalLength
      sum = 0
      downloaders.each do |d|
        sum += d.c
      end
      pBar.progress=sum
      sleep 1
    end
    pBar.finish
    
    finish = Time.now
    t = finish-start
    mm, ss = t.divmod(60)          
    hh, mm = mm.divmod(60)          
    print "Done! Downloaded #{sum} of #{totalLength}. Time elapsed: %d hours, %d minutes and %d seconds\n" % [hh, mm, ss]
  end
  
  desc "Removes pages about people in the database"
  task :remove_people  => :environment do
    
    client = connect_to_database
    
    result = download_people_data
    deleteIDs = result.to_json.gsub('[', "(").gsub(']', ")")
    print "Removing articles about people... Deleting #{result.size} articles\n" 
    client.query("DELETE FROM page WHERE page_id IN #{deleteIDs};")
    client.query("DELETE FROM text WHERE page_id IN #{deleteIDs};")
    
  end
  
  task :update => [:download, :remove_people]
  
  #returns a mysql client. if no database with the specified name exists, one is created.
  def connect_to_database
    config = Rails.configuration.database_configuration
    host = config[Rails.env]["host"]
    dbname = config[Rails.env]["database"]
    username = config[Rails.env]["username"]
    password = config[Rails.env]["password"]
    
    client = Mysql2::Client.new(:host => host, :username => username, :password => password, :flags => Mysql2::Client::MULTI_STATEMENTS)
    
    if client.query("SHOW DATABASES LIKE '#{dbname}'").count == 0
      print "Database '#{dbname}' not found, creating..."
      client.query("CREATE DATABASE #{dbname}")
      print "\n" + File.open(SETUP_FILE,"r").read
      client.select_db(dbname)
      client.query(File.open(SETUP_FILE,"r").read)
    end
    
    finalClient = Mysql2::Client.new(:host => host, :username => username, :password => password, :database => dbname)
    
    return finalClient
    
  end
  
  #creates a json file with article data if none exists
  def download_article_data
    print "Getting list of articles...\n"
    ArticleGetter.new([ARTICLE_SOURCE]).result
  end
  
  #creates a json file containing the IDs of articles about people if none exists
  def download_people_data
    print "Getting IDs of articles about people...\n"
    PeopleGetter.new([MEN_URL, WOMEN_URL]).result
  end
  
end