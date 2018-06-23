#!/usr/bin/env ruby

# Wow, looks like there are still jobs for Cobol

require 'csv'
require 'mechanize'
require 'optparse'
require 'paint'

# implement commandline options
options = {:keyword => nil, :where => nil, :listed => nil}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{Paint['seek.rb [options]', :red, :white]}"

  opts.on('-k', '--keyword keyword', 'Keywords to search') do |keyword|
    options[:keyword] = keyword
  end

  opts.on('-w', '--where where', 'Suburb, city or region') do |where|
    options[:where] = where
  end

  opts.on('-l', '--listed listed', 'Listed time in days
                                      any (default)
                                      1
                                      3
                                      7
                                      14
                                      30') do |listed|
    options[:listed] = listed
  end

  opts.on('-h', '--help', 'Displays help') do
    puts opts
    exit
  end
end

parser.parse!

if options[:keyword].nil?
  print 'Enter keywords: '
  options[:keyword] = STDIN.gets.chomp
end
if options[:where].nil?
  print 'Enter suburb, city or region: '
  options[:where] = STDIN.gets.chomp
end
if options[:listed].nil?
  print 'Listed time in days: '
  options[:listed] = STDIN.gets.chomp
end

agent = Mechanize.new
agent.user_agent_alias = 'Windows Chrome'
site = 'https://www.seek.com.au/jobs'
page = agent.get(site, [['keywords', options[:keyword]],
                        ['where', options[:where]],
                        ['daterange', options[:listed]]])

# form = page.form_with :name => 'SearchBar'
# form.field_with(:name => 'keywords').value = options[:keyword]
# form.field_with(:name => 'where').value = options[:where]
# page = agent.submit(form)

def extract(link, site)
  [link.text.strip, site + link.attributes['href'].value]
end
results = []
results << ['Title', 'URL', 'Advertiser', 'Location', 'Listing Date', 'Short Description']

loop do
  # for each page # html = page.body
  jobs = page.search('article')
  jobs.each do |job|
    title, url = extract(job.css('a')[0], site)
    a_name, a_url = extract(job.css('a')[1], site)
    location, l_url = extract(job.css('a')[2], site)

    listing_date = job.xpath("descendant::span[@data-automation='jobListingDate']/text()")
    short_description = job.xpath("descendant::span[@data-automation='jobShortDescription']//text()")

    results << [title, url, a_name, location, listing_date, short_description]
  end

  if link = page.link_with(:text => 'Next') # As long as there is still a next page link
    page = link.click
  else # If no link left, then break out of loop
    break
  end
end

if results.size > 1
  location = options[:where].tr(' ', '-')
  CSV.open("jobs/#{options[:keyword].tr(' ', '-')}#{'-' + location unless location.empty?}#{'-daterange-' + options[:listed] unless options[:listed].empty?}.csv", 'w+') do |csv_file|
    results.each do |row|
      csv_file << row
    end
  end
  puts "#{results.size - 1} jobs found"
end
