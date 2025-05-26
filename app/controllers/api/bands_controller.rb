require 'net/http'
require 'cgi'
require 'uri'
require 'json'
require 'erb'
class Api::BandsController < ApplicationController
    def index
      city = params[:city]
      if city.blank?
        render json: { error: 'City is required' }, status: :bad_request
        return
      end
      area_id = fetch_area_id(city)
      bands = fetch_bands(area_id)
      render json: bands
    end

    private

    def fetch_area_id(city)
      url = URI("https://musicbrainz.org/ws/2/area/?query=#{ERB::Util.url_encode(city)}&fmt=json")

        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true

        request = Net::HTTP::Get.new(url)
        request['User-Agent'] = "MusicBandsApp/1.0 (shivamstech595@gmail.com)"

        res = http.request(request)

        if res.is_a?(Net::HTTPSuccess)
          data = JSON.parse(res.body)
          return data['areas']&.first&.dig('id')
        else
          puts "HTTP Error: #{res.code} #{res.message}"
          return nil
        end
    end

    def fetch_bands(area_id)
      return [] unless area_id
      url = URI("https://musicbrainz.org/ws/2/artist?area=#{area_id}&fmt=json&limit=100")
      
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true

      request = Net::HTTP::Get.new(url)
      request['User-Agent'] = "MusicBandsApp/1.0 (shivamstech595@gmail.com)"

      res = http.request(request)
      data = JSON.parse(res.body)

      ten_years_ago = Date.today.year - 10

      (data['artists'] || []).select do |artist|
        artist['type'] == 'Group' &&
        artist['life-span'] &&
        artist['life-span']['begin'] &&
        artist['life-span']['begin'].to_i >= ten_years_ago
      end.map do |artist|
        {
          name: artist['name'],
          location: artist['area'] ? artist['area']['name'] : 'Unknown',
          begin_date: artist['life-span']['begin']
        }
      end.first(50)

    end
  end