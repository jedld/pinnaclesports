require "pinnaclesports/version"
require 'httparty'
require 'nokogiri'
require 'digest'
require 'base64'

module Pinnaclesports
  class Client
    FEED_URL = 'http://xml.pinnaclesports.com/pinnacleFeed.aspx'.freeze
    API_URL_v2 = 'https://api.pinnaclesports.com/v2/'.freeze
    API_URL_v1 = 'https://api.pinnaclesports.com/v1/'.freeze

    def initialize(username, password, options = {})
      @username = username
      @password = password
    end

    def currencies
      JSON.parse(send_request_v2('currencies'))
    end

    def sports
      JSON.parse(send_request_v2('sports'))
    end

    def leagues(sport_id)
      JSON.parse(send_request_v2('leagues', sportid: sport_id))
    end

    def odds(sport_id, options = {})
      params = { sportid: sport_id }

      params[:leagueIds] = options[:league_ids].join(',')  if options[:league_ids]
      params[:since] if options[:since]

      response = send_request_v1('odds', params)
      JSON.parse(response)
    end

    def self.pinnacle_feed
      events = []
      response = HTTParty.get(FEED_URL)
      xml_doc  = Nokogiri::XML(response.body)
      events_xml = xml_doc.css('events event')
      events_xml.each do |node|
        event_hash = { game_number: node.css('gamenumber').first.content,
                       sports_type: node.css('sporttype').first.content }
        participants_array = []
        periods_array = []

        node.css('periods period').each do |periods|
          period_hash = {
            number: periods.css('period_number').first.content,
            description: periods.css('period_description').first.content,
            datetime: periods.css('periodcutoff_datetimeGMT').first.content
          }

          if periods.css('spread').first
            period_hash[:spread] = {
              visiting: periods.css('spread spread_visiting').first.content,
              adjust_visiting: periods.css('spread_adjust_visiting').first.content,
              home: periods.css('spread_home').first.content,
              adjust_home: periods.css('spread_adjust_home').first.content
            }
          end
          periods_array << period_hash
        end

        node.css('participants').each do |participant|
          participants_array << {
            contestant_number: participant.css('contestantnum').first.content,
            name: participant.css('participant_name').first.content,
            rot_number: participant.css('rotnum').first.content,
          }
        end
        events << event_hash.merge(participants: participants_array,
                                   periods: periods_array)
      end

      events
    end

    private

    def send_request_v2(resource, params = {})
      headers = {
        'Authorization' => "Basic #{Base64.encode64("#{@username}:#{@password}")}"
      }

      response = HTTParty.get(API_URL_v2 + resource, query: params, headers: headers)
      response.body
    end

    def send_request_v1(resource, params = {})
      headers = {
        'Authorization' => "Basic #{Base64.encode64("#{@username}:#{@password}")}"
      }

      response = HTTParty.get(API_URL_v1 + resource, query: params, headers: headers)
      response.body
    end
  end
end
