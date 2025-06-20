require 'nokogiri'
require 'open-uri'
require 'httparty'
require 'json'

class StatsController < ApplicationController
  def index
    # Main UI, handled by view
  end

  def months
    doc = Nokogiri::HTML(URI.open("https://www.smogon.com/stats/"))
    months = doc.css('a').map { |a| a.text.gsub('/', '') }.select { |m| m =~ /\d{4}-\d{2}/ && m >= '2023-10' }
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

  def pokemon_details
    month = params[:month]
    format = params[:format]
    name = params[:name]
    if month.blank? || format.blank? || name.blank?
      render json: { error: 'Missing month, format, or name' }, status: 400
      return
    end
    # Fetch Smogon data for the month/format
    url = "https://www.smogon.com/stats/#{month}/chaos/#{format}"
    response = HTTParty.get(url)
    if response.code != 200
      render json: { error: 'Failed to fetch data' }, status: 500
      return
    end
    data = response.parsed_response["data"] || {}
    # Use the display name as-is for lookup (matches Smogon data keys)
    poke_data = data[name]
    if poke_data.nil?
      render json: { error: 'Pokémon not found in data' }, status: 404
      return
    end
    total = poke_data["Raw count"] || 1
    # Items
    items = []
    if poke_data["Items"]
      total_items = poke_data["Items"].values.sum
      poke_data["Items"].sort_by { |_, v| -v }.first(10).each do |item, count|
        pct = total_items > 0 ? ((count.to_f / total_items) * 100).round(2) : 0
        next if pct == 0 || pct.nan?
        items << [item, "#{pct}%"]
      end
    end
    # Moves
    moves = []
    if poke_data["Moves"]
      total_moves = poke_data["Moves"].values.sum
      poke_data["Moves"].sort_by { |_, v| -v }.first(10).each do |move, count|
        pct = total_moves > 0 ? ((count.to_f / total_moves) * 400).round(2) : 0
        next if pct == 0 || pct.nan?
        moves << [move, "#{pct}%"]
      end
    end
    # Abilities
    abilities = []
    if poke_data["Abilities"]
      total_abilities = poke_data["Abilities"].values.sum
      poke_data["Abilities"].sort_by { |_, v| -v }.each do |ability, count|
        pct = total_abilities > 0 ? ((count.to_f / total_abilities) * 100).round(2) : 0
        next if pct == 0 || pct.nan?
        abilities << [ability, "#{pct}%"]
      end
    end
    # Natures
    natures = []
    if poke_data["Spreads"]
      nature_totals = Hash.new(0)
      nature_spreads = Hash.new { |h, k| h[k] = Hash.new(0) }
      poke_data["Spreads"].each do |spread, count|
        parts = spread.split(":")
        nature = parts[0]
        nature_totals[nature] += count
        nature_spreads[nature][spread] += count
      end
      total_spreads = poke_data["Spreads"].values.sum
      nature_totals.sort_by { |_, v| -v }.each do |nature, count|
        pct = total_spreads > 0 ? ((count.to_f / total_spreads) * 100).round(2) : 0
        next if pct == 0 || pct.nan?
        # Common spreads for this nature
        spreads_for_nature = nature_spreads[nature].sort_by { |_, v| -v }
        common_spreads = spreads_for_nature.first(5).map do |spread, spread_count|
          evs = spread.split(":")[1]
          spread_pct = count > 0 ? ((spread_count.to_f / count) * 100).round(2) : 0
          next if spread_pct == 0 || spread_pct.nan?
          "#{evs} (#{spread_pct}%)"
        end.compact.join('<br>')
        natures << [nature, "#{pct}%", common_spreads]
      end
    end
    # Speed distribution
    speed_distribution = []
    begin
      pokedex_path = Rails.root.join('public', 'pokedex.json')
      pokedex = JSON.parse(File.read(pokedex_path))
      base_stats = pokedex[name] && pokedex[name]["baseStats"]
      if !base_stats
        norm_name = name.downcase.gsub(/[^a-z0-9]/, '')
        base_stats = pokedex[norm_name] && pokedex[norm_name]["baseStats"]
      end
      base_speed = base_stats && base_stats["spe"]
      if base_speed && poke_data["Spreads"]
        speed_up = %w[Timid Hasty Jolly Naive]
        speed_down = %w[Brave Relaxed Quiet Sassy]
        speed_counts = Hash.new(0)
        poke_data["Spreads"].each do |spread, count|
          parts = spread.split(":")
          next unless parts.length == 2
          nature = parts[0]
          stats = parts[1].split("/").map(&:to_i)
          speed_ev = stats[5]
          nature_multiplier = 1.0
          nature_multiplier = 1.1 if speed_up.include?(nature)
          nature_multiplier = 0.9 if speed_down.include?(nature)
          iv = 31
          iv = 0 if speed_down.include?(nature) && speed_ev == 0
          speed = (((((2 * base_speed + iv + (speed_ev / 4)) * 50) / 100) + 5) * nature_multiplier).floor
          speed_counts[speed] += count
        end
        total_speed = speed_counts.values.sum
        speed_counts.keys.sort.each do |spd|
          pct = total_speed > 0 ? ((speed_counts[spd].to_f / total_speed) * 100).round(2) : 0
          next if pct == 0 || pct.nan?
          speed_distribution << [spd.to_s, "#{pct}%"]
        end
      end
    rescue => e
      speed_distribution = []
    end
    render json: {
      items: items,
      moves: moves,
      abilities: abilities,
      natures: natures,
      speed_distribution: speed_distribution
    }
  end
end
