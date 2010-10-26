# -*- encoding:utf-8 -*-
require "google-search"
require "nokogiri"

module Google
  class Search
    def self.url_encode string
      string.to_s.gsub(/([^ a-zA-Z0-9_.-]+)/) {
        '%' + $1.unpack('H*')[0].scan(/../).join('%').upcase
      }.tr(' ', '+')
    end
  end
end

module TwitterSearch
  BASE_URLS = {
    :twitter => "http://twitter.com/",
    :twilog  => "http://twilog.org/"
  }

  class InterfaceError < RuntimeError ; end
  class SearchError < RuntimeError ; end
  class ParseError < RuntimeError ; end

  module Interface
    require "net/http"
    def get(uri)
      Net::HTTP.get_response(URI.parse(uri))
    rescue => e
      #raise InterfaceError, "#{e.message}\n\n#{e.backtrace}"
    end
  end

  class User
    include Interface
    attr_reader :users

    def initialize(query, size=10)
      @users = user_search(query, size)
    end

    def user_search(query, size)
      search = googling_twitter(query)

      users, cnt, limit = {}, 0, 10
      limit.times do
        search_results = cnt.zero? ? search.response : search.next.response
        search_results.each do |res|
          if res.title =~ /\son\sTwitter/ && !users[(title=res.title.sub($&,''))]
            users[title] = res.uri
            cnt += 1
          end
          return users if cnt >= size
        end
      end
      users
    end
  
    def user_profiles
      threads, result_hash = [], {}
      @users.each do |result|
        threads << Thread.new(result) do |name, uri|
          next unless url = get(uri)
          if block_given?
            yield name, parse_profile(url)
          else
            result_hash[name] = parse_profile(url)
          end
        end
      end
      threads.each { |th| th.join }
      result_hash
    end

    private
    def googling_twitter(query)
      Google::Search::Web.new do |s|
        query += " site:#{BASE_URLS[:twitter]}"
        s.query = query
      end
    rescue => e
      raise SearchError, "#{e.message}\n\n#{e.backtrace}"
    end

    def parse_profile(response)
      profile_css = "div#profile li"
      profile = {}
      case response
      when Net::HTTPSuccess
        parsed_body = Nokogiri::HTML(response.body)
        parsed_body.css(profile_css).each do |node|
          profile_tree = node.children.last
          if v = profile_tree.attributes['class']
            key = v.value.to_sym
          else
            next #irregular case
          end
          profile[key] =
            key == :url ? profile_tree.attributes['href'].value : profile_tree.text
        end
      end
      profile
    rescue => e
      raise ParseError, "#{e.message}\n\n#{e.backtrace}"
    end
  end

  class Twilog
    include Interface
    def initialize(user)
      @user = user
    end
  
    def search(query)
      query = query.split(" ") if query.respond_to?(:split)
      query.map! { |q| URI.escape q }
      uri = "#{BASE_URLS[:twilog]}/tweets.cgi?id=#{@user}&word=#{query.join("+")}"
      parse_twilog( get(uri) )
    end

    private
    def parse_twilog(response)
      date_css = 'div.tl-tweets' 
      tweet_css = 'div.tl-tweet'
      tweets = []
      case response
      when Net::HTTPSuccess
        parsed_body = Nokogiri::HTML(response.body)
        parsed_body.css(date_css).each do |node|
          date = date_format(node.attributes['id'].value)
          node.css(tweet_css).each do |tw|
            text, time = tw.text.split("\nposted at ")
            tweets << [text, DateTime.parse("#{date} #{time}")]
          end
        end
      end
      tweets
    rescue => e
      raise ParseError, "#{e.message}\n\n#{e.backtrace}"
    end

    def date_format(s)
      # ex.d100923 => 2010/09/23
      s.gsub(/\d\d/, '/\0').sub(/^d\//, '20')
    end
  end
end

module Termtter::Client
  register_command(
    :name => :search_user,
    :aliases => [:su, :user_search],
    :help => ['search_user,su,user_search QUERY', 'Twitter User Search from profile alike'],
    :exec => lambda do |query|
      opts = {:size => 10, :verbose => false}
      query.gsub!(/(-l)\s*(\d+)/) { opts[:size] = $2.to_i; '' }
      query.gsub!(/-v/) { opts[:verbose] = true; ''}
      public_storage[:uris].clear

      pf = TwitterSearch::User.new(query, opts[:size])
      unless opts[:verbose]
        pf.users.each_with_index do |(name, uri), i|
          print "<green>#{i+1}:#{name}</green> => #{uri}\n".termcolor
          public_storage[:uris] << uri
        end
      else
        pf.user_profiles.each_with_index do |(name, profile), i|
          puts "<green>#{i+1}:#{name}</green>".termcolor
          print profile.delete_if{|k,v| k == :fn}.
                map { |k, v| "  <red>#{k}</red> => #{v}" }.join("\n").termcolor + "\n"
          public_storage[:uris] << profile[:url]
        end
      end
      opts[:size].times { |n| register_alias("#{n+1}", "uo #{n}") }
    end
  )

  # TODO: 1) view next page result, 2) highlight query word in result, 3) open uri
  register_command(
    :name => :search_twilog,
    :aliases => [:st, :twilog],
    :help => ['search_twilog,st,twilog QUERY [from:USERNAME]', 'Twitter Search through Twilog'],
    :exec => lambda do |query|
      query, user = query.split("from:")
      user = config.user_name unless user
      result = TwitterSearch::Twilog.new(user).search(query)
      result.each_with_index do |(text, datetime), i|
        puts " <white>#{i+1}:</white><green>#{CGI.escapeHTML(text)}</green>".termcolor +
             " <white>(#{datetime.strftime("%Y/%m/%d %H:%M:%S")})</white>".termcolor
      end
    end
  )
end

# search_user:
# fuzzy search for Twitter users
# usage: search_user termtter -l30 (find top 30 termtterer)
#        search_user ruby -v (find ruby lovers in vebose mode)
# to open urls on list, use uri-open all or just hit a number
#
# search_twilog:
# search Twitter log with Twilog(http://twilog.org/)
# usage: search_twilog vim ruby (find 'YOUR' tweets about 'vim + ruby')
#        search_twilog macbook from:stevejobs (find Steve's tweets about 'macbook')
#
# require google-search, nokogiri library and uri-open plugin
# more info => hp12c http://d.hatena.ne.jp/keyesberry/20100610/p1
