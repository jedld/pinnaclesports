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
      JSON.parse(send_request_v2('sports'))['sports']
    end

    def leagues(sport_id)
      JSON.parse(send_request_v2('leagues', sportid: sport_id))['leagues']
    end

    def fixtures(sport_id, options = {})
      query('fixtures', sport_id, options)
    end

    def odds(sport_id, options = {})
      query('odds', sport_id, options)
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

    def query(resource, sport_id, options = {})
      response = nil
      begin
        params = { sportid: sport_id }

        if options[:league_ids]
          options[:league_ids] = options[:league_ids].is_a?(Array) ? options[:league_ids] : [options[:league_ids]]
          params[:leagueIds] = options[:league_ids].join(',')
        end

        params[:since] = options[:since] if options[:since]
        params[:oddsFormat] = options[:odds_format] ? options[:odds_format] : 'DECIMAL'

        response = send_request_v1(resource, params)
        JSON.parse(response.body)
      rescue JSON::ParserError => e
      end
    end

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

      HTTParty.get(API_URL_v1 + resource, query: params, headers: headers)
    end
  end
end
