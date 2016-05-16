require "pinnaclesports/version"
require 'httparty'
require 'nokogiri'
require 'digest'
require 'base64'

module Pinnaclesports
  class OddsFormat
    DECIMAL = 'decimal'
    AMERICAN = 'american'
  end

  class Client
    FEED_URL = 'http://xml.pinnaclesports.com/pinnacleFeed.aspx'.freeze
    API_URL_v2 = 'https://api.pinnaclesports.com/v2/'.freeze
    API_URL_v1 = 'https://api.pinnaclesports.com/v1/'.freeze

    def initialize(username, password, options = {})
      @username = username
      @password = password
      @odds_format = options[:odds_format] || 'DECIMAL'
    end

    def balance
      JSON.parse(send_request_v1('client/balance').body)
    end

    def line(sport_id, league_id, event_id, period_number, bet_type, selection, handicap = nil)
      params = {
        sportId: sport_id,
        leagueId: league_id,
        eventId: event_id,
        periodNumber: period_number,
        betType: bet_type,
        oddsFormat: @odds_format,
      }

      if ['MONEYLINE', 'SPREAD', 'TEAM_TOTAL_POINTS'].include?(bet_type)
        params.merge!(team: selection)
      elsif ['TOTAL_POINTS', 'TEAM_TOTAL_POINTS'].include?(bet_type)
        params.merge!(side: selection)
      end

      if ['SPREAD', 'TEAM_TOTAL_POINTS', 'TOTAL_POINTS'].include? bet_type
        params.merge!(handicap: handicap)
      end

      send_request_v1('line', params)
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

    def settled_fixtures(sport_id, options = {})
      query('fixtures/settled', sport_id, options)
    end

    def odds(sport_id, options = {})
      query('odds', sport_id, options)
    end

    def place_bet(request_id, sport_id, event_id, period_number, line_id, bettype, side, wager, options = {})
      params = {
        uniqueRequestId: request_id,
        acceptBetterLine: 'TRUE',
        customerReference: options[:customer_reference],
        oddsFormat: @odds_format,
        stake: wager,
        winRiskStake: options[:win_risk_type] || 'RISK',
        sportId: sport_id,
        eventId: event_id,
        periodNumber: period_number,
        betType: bettype,
        lineId: line_id,
      }

      if ['MONEYLINE', 'SPREAD', 'TEAM_TOTAL_POINTS'].include?(bettype)
        params.merge!(team: side)
      elsif ['TOTAL_POINTS', 'TEAM_TOTAL_POINTS'].incude?(bettype)
        params.merge!(side: side)
      end

      HTTParty.post(API_URL_v1 + 'bets/place', body: params.to_json, :headers => { 'Content-Type' => 'application/json', 'Authorization' => "Basic #{Base64.encode64("#{@username}:#{@password}")}" })
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
        params[:oddsFormat] = options[:odds_format] ? options[:odds_format] : @odds_format

        response = send_request_v1(resource, params)
        JSON.parse(response.body)
      rescue JSON::ParserError => e
        puts e
      end
    end

    def send_request_v2(resource, params = {})
      response = HTTParty.get(API_URL_v2 + resource, query: params, headers: headers)
      response.body
    end

    def send_request_v1(resource, params = {})
      HTTParty.get(API_URL_v1 + resource, query: params, headers: headers)
    end

    def headers
      {
        'Authorization' => "Basic #{Base64.encode64("#{@username}:#{@password}")}"
      }
    end
  end
end
