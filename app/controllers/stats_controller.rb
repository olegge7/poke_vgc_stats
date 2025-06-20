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
    attack_distribution = []
    defense_distribution = []
    sp_atk_distribution = []
    sp_def_distribution = []
    hp_distribution = []
    begin
      pokedex_path = Rails.root.join('public', 'pokedex.json')
      pokedex = JSON.parse(File.read(pokedex_path))
      base_stats = pokedex[name] && pokedex[name]["baseStats"]
      if !base_stats
        norm_name = name.downcase.gsub(/[^a-z0-9]/, '')
        base_stats = pokedex[norm_name] && pokedex[norm_name]["baseStats"]
      end
      base_speed = base_stats && base_stats["spe"]
      base_atk = base_stats && base_stats["atk"]
      base_def = base_stats && base_stats["def"]
      base_spa = base_stats && base_stats["spa"]
      base_spd = base_stats && base_stats["spd"]
      base_hp = base_stats && base_stats["hp"]
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
      # Attack distribution
      if base_atk && poke_data["Spreads"]
        atk_up = %w[Lonely Adamant Naughty Brave]
        atk_down = %w[Bold Modest Calm Timid]
        atk_counts = Hash.new(0)
        poke_data["Spreads"].each do |spread, count|
          parts = spread.split(":")
          next unless parts.length == 2
          nature = parts[0]
          stats = parts[1].split("/").map(&:to_i)
          atk_ev = stats[1]
          nature_multiplier = 1.0
          nature_multiplier = 1.1 if atk_up.include?(nature)
          nature_multiplier = 0.9 if atk_down.include?(nature)
          iv = 31
          iv = 0 if atk_down.include?(nature) && atk_ev == 0
          atk = (((((2 * base_atk + iv + (atk_ev / 4)) * 50) / 100) + 5) * nature_multiplier).floor
          atk_counts[atk] += count
        end
        total_atk = atk_counts.values.sum
        atk_counts.keys.sort.each do |atk|
          pct = total_atk > 0 ? ((atk_counts[atk].to_f / total_atk) * 100).round(2) : 0
          next if pct == 0 || pct.nan?
          attack_distribution << [atk.to_s, "#{pct}%"]
        end
      end
      # Defense distribution
      if base_def && poke_data["Spreads"]
        def_up = %w[Bold Impish Lax Relaxed]
        def_down = %w[Lonely Mild Gentle Hasty]
        def_counts = Hash.new(0)
        poke_data["Spreads"].each do |spread, count|
          parts = spread.split(":")
          next unless parts.length == 2
          nature = parts[0]
          stats = parts[1].split("/").map(&:to_i)
          def_ev = stats[2]
          nature_multiplier = 1.0
          nature_multiplier = 1.1 if def_up.include?(nature)
          nature_multiplier = 0.9 if def_down.include?(nature)
          iv = 31
          iv = 0 if def_down.include?(nature) && def_ev == 0
          defense = (((((2 * base_def + iv + (def_ev / 4)) * 50) / 100) + 5) * nature_multiplier).floor
          def_counts[defense] += count
        end
        total_def = def_counts.values.sum
        def_counts.keys.sort.each do |def_val|
          pct = total_def > 0 ? ((def_counts[def_val].to_f / total_def) * 100).round(2) : 0
          next if pct == 0 || pct.nan?
          defense_distribution << [def_val.to_s, "#{pct}%"]
        end
      end
      # Sp. Atk distribution
      if base_spa && poke_data["Spreads"]
        spa_up = %w[Modest Mild Rash Quiet]
        spa_down = %w[Adamant Impish Careful Jolly]
        spa_counts = Hash.new(0)
        poke_data["Spreads"].each do |spread, count|
          parts = spread.split(":")
          next unless parts.length == 2
          nature = parts[0]
          stats = parts[1].split("/").map(&:to_i)
          spa_ev = stats[3]
          nature_multiplier = 1.0
          nature_multiplier = 1.1 if spa_up.include?(nature)
          nature_multiplier = 0.9 if spa_down.include?(nature)
          iv = 31
          iv = 0 if spa_down.include?(nature) && spa_ev == 0
          spa = (((((2 * base_spa + iv + (spa_ev / 4)) * 50) / 100) + 5) * nature_multiplier).floor
          spa_counts[spa] += count
        end
        total_spa = spa_counts.values.sum
        spa_counts.keys.sort.each do |spa_val|
          pct = total_spa > 0 ? ((spa_counts[spa_val].to_f / total_spa) * 100).round(2) : 0
          next if pct == 0 || pct.nan?
          sp_atk_distribution << [spa_val.to_s, "#{pct}%"]
        end
      end
      # Sp. Def distribution
      if base_spd && poke_data["Spreads"]
        spd_up = %w[Calm Gentle Careful Sassy]
        spd_down = %w[Naughty Lax Rash Naive]
        spd_counts = Hash.new(0)
        poke_data["Spreads"].each do |spread, count|
          parts = spread.split(":")
          next unless parts.length == 2
          nature = parts[0]
          stats = parts[1].split("/").map(&:to_i)
          spd_ev = stats[4]
          nature_multiplier = 1.0
          nature_multiplier = 1.1 if spd_up.include?(nature)
          nature_multiplier = 0.9 if spd_down.include?(nature)
          iv = 31
          iv = 0 if spd_down.include?(nature) && spd_ev == 0
          spd = (((((2 * base_spd + iv + (spd_ev / 4)) * 50) / 100) + 5) * nature_multiplier).floor
          spd_counts[spd] += count
        end
        total_spd = spd_counts.values.sum
        spd_counts.keys.sort.each do |spd_val|
          pct = total_spd > 0 ? ((spd_counts[spd_val].to_f / total_spd) * 100).round(2) : 0
          next if pct == 0 || pct.nan?
          sp_def_distribution << [spd_val.to_s, "#{pct}%"]
        end
      end
      # HP distribution
      if base_hp && poke_data["Spreads"]
        hp_counts = Hash.new(0)
        poke_data["Spreads"].each do |spread, count|
          parts = spread.split(":")
          next unless parts.length == 2
          stats = parts[1].split("/").map(&:to_i)
          hp_ev = stats[0]
          iv = 31
          hp = (((2 * base_hp + iv + (hp_ev / 4)) * 50) / 100).floor + 60
          hp_counts[hp] += count
        end
        total_hp = hp_counts.values.sum
        hp_counts.keys.sort.each do |hp_val|
          pct = total_hp > 0 ? ((hp_counts[hp_val].to_f / total_hp) * 100).round(2) : 0
          next if pct == 0 || pct.nan?
          hp_distribution << [hp_val.to_s, "#{pct}%"]
        end
      end
    rescue => e
      speed_distribution = []
      attack_distribution = []
      defense_distribution = []
      sp_atk_distribution = []
      sp_def_distribution = []
      hp_distribution = []
    end
    render json: {
      items: items,
      moves: moves,
      abilities: abilities,
      natures: natures,
      speed_distribution: speed_distribution,
      attack_distribution: attack_distribution,
      defense_distribution: defense_distribution,
      sp_atk_distribution: sp_atk_distribution,
      sp_def_distribution: sp_def_distribution,
      hp_distribution: hp_distribution
    }
  end
end
