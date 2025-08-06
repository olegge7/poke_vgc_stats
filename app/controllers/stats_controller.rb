class StatsController < ApplicationController
  before_action :initialize_service

  def index
    # Main UI, handled by view
  end

  def months
    months = @pokemon_stats_service.fetch_months
    render json: months
  end

  def formats
    month = params[:month]
    if month.blank?
      render json: []
      return
    end

    formats = @pokemon_stats_service.fetch_formats(month)
    render json: formats
  end

  def data
    month = params[:month]
    format = params[:format]

    if month.blank? || format.blank?
      render json: { error: "Missing month or format" }, status: 400
      return
    end

    begin
      view_model = @pokemon_stats_service.fetch_and_calculate_stats(month, format)

      if view_model.empty?
        render json: { error: "No data found for the specified month and format" }, status: 404
        return
      end

      response_data = {
        data: view_model.pokemon_data,
        usage_charts: view_model.usage_charts_data,
        pokemon_list: view_model.pokemon_list
      }

      render json: response_data
    rescue => e
      Rails.logger.error "Error fetching data: #{e.message}"
      render json: { error: "Failed to fetch data" }, status: 500
    end
  end

  def pokemon_details
    month = params[:month]
    format = params[:format]
    name = params[:name]

    if month.blank? || format.blank? || name.blank?
      render json: { error: "Missing month, format, or name" }, status: 400
      return
    end

    begin
      details = @pokemon_stats_service.fetch_pokemon_details(month, format, name)

      if details.nil?
        render json: { error: "Pokémon not found in data" }, status: 404
        return
      end

      render json: {
        items: details.items,
        moves: details.moves,
        abilities: details.abilities,
        natures: details.natures,
        speed_distribution: details.speed_distribution,
        attack_distribution: details.attack_distribution,
        defense_distribution: details.defense_distribution,
        sp_atk_distribution: details.sp_atk_distribution,
        sp_def_distribution: details.sp_def_distribution,
        hp_distribution: details.hp_distribution
      }
    rescue => e
      Rails.logger.error "Error fetching Pokemon details: #{e.message}"
      render json: { error: "Failed to fetch Pokemon details" }, status: 500
    end
  end

  private

  def initialize_service
    @pokemon_stats_service = PokemonStatsService.new
  end
end
