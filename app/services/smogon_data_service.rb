require 'nokogiri'
require 'open-uri'

class SmogonDataService
  include HTTParty
  base_uri 'https://www.smogon.com/stats'

  class << self
    def fetch_months
      doc = Nokogiri::HTML(URI.open("https://www.smogon.com/stats/"))
      months = doc.css('a').map { |a| a.text.gsub('/', '') }
                  .select { |m| m =~ /\d{4}-\d{2}/ && m >= '2023-10' }
      months
    rescue => e
      Rails.logger.error "Failed to fetch months: #{e.message}"
      []
    end

    def fetch_formats(month)
      return [] if month.blank?
      
      url = "https://www.smogon.com/stats/#{month}/chaos/"
      doc = Nokogiri::HTML(URI.open(url))
      formats = doc.css('a').map(&:text)
                   .select { |f| f.include?('vgc') && f.include?('bo3') && f.end_with?('.json') }
      formats
    rescue => e
      Rails.logger.error "Failed to fetch formats for #{month}: #{e.message}"
      []
    end

    def fetch_chaos_data(month, format)
      return {} if month.blank? || format.blank?
      
      url = "/#{month}/chaos/#{format}"
      response = get(url)
      
      if response.success?
        response.parsed_response
      else
        Rails.logger.error "Failed to fetch chaos data: #{response.code} - #{response.message}"
        {}
      end
    rescue => e
      Rails.logger.error "Failed to fetch chaos data for #{month}/#{format}: #{e.message}"
      {}
    end
  end
end
