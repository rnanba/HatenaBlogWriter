# coding: utf-8
# HBW::Client
# coding: utf-8

require 'atomutil'
require 'yaml'
require 'digest/sha1'
require_relative './HatenaBlogWriter.rb'

Encoding.default_external = Encoding::UTF_8

module HBW
  class FeedLoader
    def initialize
      config = YAML.load_file("config.yml")
      id = config['id']
      blog_domain = config['blog_domain']
      @service_uri = "https://blog.hatena.ne.jp/#{id}/#{blog_domain}/atom"
      auth = Atompub::Auth::Wsse.new(username: id, password: config['api_key'])
      @client = Atompub::Client.new(auth: auth)
    end

    def each_feed
      service = @client.get_service(@service_uri)
      feed_uri = service.workspace.collection.href
      while feed_uri != nil do
        # puts "feed_uri: " + feed_uri
        feed = @client.get_feed(feed_uri)
        feed_uri = nil
        feed.links.each { |link|
          if link.rel == 'next' then
            feed_uri = link.href
            break
          end
        }
        yield feed
      end
    end
  end
end
