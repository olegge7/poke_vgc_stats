require 'nokogiri'
require 'open-uri'
require 'httparty'

class StatsController < ApplicationController
  def index
    # Main UI, handled by view
  end

  def months
    doc = Nokogiri::HTML(URI.open("https://www.smogon.com/stats/"))
    months = doc.css('a').map { |a| a.text.gsub('/', '') }.select { |m| m =~ /\d{4}-\d{2}/ }
    render json: months
  end

  def formats
    month = params[:month]
    if month.blank?
      render json: []
      return
    end
    url = "https://www.smogon.com/stats/#{month}/chaos/"
    doc = Nokogiri::HTML(URI.open(url))
    formats = doc.css('a').map(&:text).select { |f| f.include?('vgc') && f.include?('bo3') && f.end_with?('.json') }
    render json: formats
  end

  def data
    month = params[:month]
    format = params[:format]
    if month.blank? || format.blank?
      render json: { error: 'Missing month or format' }, status: 400
      return
    end
    url = "https://www.smogon.com/stats/#{month}/chaos/#{format}"
    response = HTTParty.get(url)
    if response.code == 200
      render json: response.parsed_response
    else
      render json: { error: 'Failed to fetch data' }, status: 500
    end
  end
end
