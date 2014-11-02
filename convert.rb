#!/usr/bin/env ruby
#-*- coding:utf-8 -*-

# @file convert.rb
# @author Long Changjin <admin@longchangjin.cn>
# @date 2014-10-31

require "nokogiri"
require "uri"
require "date"
require "erb"
require "yaml"

if ARGV.length < 1
  puts "Usage: #{__FILE__} <filename>"
  exit 1
end

filename = ARGV[0]

PostTemp = ERB.new File.read('post.erb')
PageTemp = ERB.new File.read('page.erb')
Conf = YAML::load_file 'config.yml'

Dir.mkdir(Conf['post_output']) unless Dir.exists?(Conf['post_output'])
Dir.mkdir(Conf['page_output']) unless Dir.exists?(Conf['page_output'])

wordpress = Nokogiri::XML.parse File.read(filename)


def render item
  if item["wp:post_type"] == "post"
    result = PostTemp.result binding unless item.nil?
    filename = File.join(
      Conf['post_output'],
      "%s-%s-%s.markdown" % [item['wp:post_date_gmt'].split[0], item['wp:post_id'], item['title']]
    )
  else
    item['permalink'] = URI.parse(item['link']).path
    item['permalink'] += '/' unless item['permalink'].end_with? '/'
    result = PageTemp.result binding unless item.nil?
    filename = File.join(
      Conf['page_output'],
      "%s.markdown" % [item['title']]
    )
  end
  puts "save #{filename}"
  File.write filename, result
end

def basic_info root_node
  title = root_node.xpath('rss/channel/title').text
  puts "title: #{title}"

  link = root_node.xpath('rss/channel/link').text
  puts "link: #{link}"

  description = root_node.xpath('rss/channel/description').text
  puts "description: #{description}"
  {title: title, link: link, description: description}
end

def author_info root_node
  authors = []
  root_node.xpath('rss/channel/wp:author').each do |a|
    authors.push({
      id: a.xpath('wp:author_id').text,
      username: a.xpath('wp:author_login').text,
      email: a.xpath('wp:author_email').text,
      name: a.xpath('wp:author_display_name').text
    })
  end
  puts authors
end

def category_info root_node
  categories = []
  root_node.xpath('rss/channel/wp:category').each do |c|
    categories.push({
      id: c.xpath('wp:term_id').text,
      nicename: URI::decode(c.xpath('wp:category_nicename').text),
      name: c.xpath('wp:cat_name').text,
      parent: URI::decode(c.xpath('wp:category_parent').text)
    })
  end
  puts categories
end

def tag_info root_node
  tags = []
  root_node.xpath('rss/channel/wp:tag').each do |t|
    tags.push({
      id: t.xpath('wp:term_id').text,
      name: t.xpath('wp:tag_name').text,
      tag_slug: URI::decode(t.xpath('wp:tag_slug').text)
    })
  end
  puts tags
end

def item_info root_node
  items = {}
  root_node.xpath("rss/channel/item[wp:status = 'publish']").each do |t|
    elem_names = [
      "title", "link", "pubDate", "dc:creator", "guid", "description",
      "content:encoded", "excerpt:encoded", "wp:post_id", "wp:post_date",
      "wp:post_date_gmt", "wp:comment_status", "wp:ping_status",
      "wp:post_name", "wp:status", "wp:post_parent",
      "wp:menu_order", "wp:post_type", "wp:post_password", "wp:is_sticky"
    ]
    item = {}
    elem_names.each do |name|
      item[name] = t.xpath(name).text
    end
    item["category"] = []
    item["tag"] = []
    t.xpath("category").each do |node|
      if node.attribute('domain').value == "category"
        item["category"].push node.text
      else
        item["tag"].push node.text
      end
    end
    item["wp:postmeta"] = []
    t.xpath("wp:postmeta").each do |node|
      meta = {}
      meta["wp:meta_key"] = node.xpath("wp:meta_key").text
      meta["wp:meta_value"] = node.xpath("wp:meta_value").text
      item["wp:postmeta"].push meta
    end
    items[item["wp:post_id"]] = item
  end
  items
end

BASE_URL = basic_info(wordpress)['link']

puts "=" * 15

#author_info wordpress
#puts "=" * 15

#category_info wordpress
#puts "=" * 15

#tag_info wordpress
#puts "=" * 15

item_info(wordpress).each do |id, item|
  render item
end
