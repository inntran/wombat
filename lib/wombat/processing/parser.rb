#coding: utf-8
require 'wombat/property/locators/factory'
require 'wombat/processing/node_selector'
require 'mechanize'
require 'restclient'
GOOGLE_BOT_UA = "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"

module Nokogiri
  module XML
    class Document
      attr_accessor :headers
    end
  end
end

module Wombat
  module Processing
    module Parser
      attr_accessor :mechanize, :context, :response_code, :page

      def initialize
        # http://stackoverflow.com/questions/6918277/ruby-mechanize-web-scraper-library-returns-file-instead-of-page
        @mechanize = Mechanize.new { |a|
          a.post_connect_hooks << lambda { |_,_,response,_|
            if response.content_type.nil? || response.content_type.empty?
              response.content_type = 'text/html'
            end
          }
        }
        @mechanize.user_agent = GOOGLE_BOT_UA
        @mechanize.set_proxy(*Wombat.proxy_args) if Wombat.proxy_args
      end

      def parse(metadata)
        @context = parser_for metadata

        Wombat::Property::Locators::Factory.locator_for(metadata).locate(@context, @mechanize)
      end

      private
      def parser_for(metadata)
        url = "#{metadata[:base_url]}#{metadata[:path]}"
        page = nil
        parser = nil
        begin
          @page = metadata[:page]

          if metadata[:document_format] == :html
            @page = @mechanize.get(url,{},nil,{"X-Forwarded-For" => "66.249.64.139"}) unless @page
            parser = @page.parser
            parser.headers = @page.header
          else
            @page = RestClient.get(url, headers:{user_agent: "User-Agent: Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)", :"X-Forwarded-For" => "66.249.64.139"}) unless @page
            parser = Nokogiri::XML @page
            parser.headers = @page.headers
          end
          @response_code = @page.code.to_i if @page.respond_to? :code
          parser
        rescue
          if $!.respond_to? :http_code
            @response_code = $!.http_code.to_i
          elsif $!.respond_to? :response_code
            @response_code = $!.response_code.to_i
          end
          raise $!
        end
      end
    end
  end
end
