#!/usr/bin/env ruby

require 'open-uri'
require 'rubygems'
require 'json'
require 'yaml'
require 'nokogiri'

class Issue
  attr_accessor :title, :ids
  def initialize(title, ids)
    @title, @ids = title, ids
  end
end

class Github
  def initialize(config)
    @username = config["username"]
    @api_token = config["api_token"]
    @repository = config["repository"]
  end
  
  def open_issues
    github = open("https://github.com/api/v2/json/issues/list/#{@repository}/open",
      :http_basic_authentication=>["#{@username}/token", @api_token]) do |f|
      JSON.parse(f.read)
    end

    github["issues"].map do |issue|
      Issue.new(issue["title"], :github => issue["number"])
    end
  end
end

class Pivotal
  def initialize(config)
    @username = config["username"]
    @password = config["password"]
    @project = config["project"]
  end
  
  def open_issues
    x = Nokogiri::XML(open("https://www.pivotaltracker.com/services/v3/tokens/active",
      :http_basic_authentication => [@username, @password]))
    token = x.at('guid').inner_text

    x = Nokogiri::XML(open("https://www.pivotaltracker.com/services/v3/projects", "X-TrackerToken" => token))
    project_id = x.search('project').find {|p| p.at('name').inner_text == @project}.at('id').inner_text

    x = Nokogiri::XML(open("https://www.pivotaltracker.com/services/v3/projects/#{project_id}/stories", "X-TrackerToken" => token))

    x.search('story').map do |s|
      Issue.new(s.at('name').inner_text, :pivotal => s.at('id').inner_text)
    end
  end
end

config = open("configuration.yaml") do |f|
  YAML.load(f.read)
end

g = Github.new(config["github"])
p = Pivotal.new(config["pivotal"])

puts "GitHub issues:"
g.open_issues.each do |i|
  puts "id: #{i.ids[:github]}, title: #{i.title}"
end
puts "Pivotal Stories:"
p.open_issues.each do |i|
  puts "id: #{i.ids[:pivotal]}, title: #{i.title}"
end
