class PokemonStatsService
  def initialize
    @cache_expiry = 1.hour
  end

  def fetch_and_calculate_stats(month, format)
    view_model = PokemonStatsViewModel.new(month: month, format: format)
    
    # Try to get from cache first
    cached_data = Rails.cache.read(view_model.cache_key)
    if cached_data
      view_model.pokemon_data = cached_data[:pokemon_data]
      view_model.usage_charts_data = cached_data[:usage_charts_data]
      view_model.pokemon_list = cached_data[:pokemon_list]
      return view_model
    end

    # Fetch raw data from Smogon
    raw_data = SmogonDataService.fetch_chaos_data(month, format)
    return view_model if raw_data.empty? || !raw_data['data']

    # Process and store the data
    view_model.pokemon_data = raw_data['data']
    
    # Calculate derived data
    calculation_service = PokemonStatsCalculationService.new(view_model)
    charts_data = calculation_service.calculate_usage_charts
    view_model.usage_charts_data = charts_data.chart_data
    
    # Generate pokemon list
    view_model.pokemon_list = generate_pokemon_list(view_model)

    # Cache the processed data
    cache_data = {
      pokemon_data: view_model.pokemon_data,
      usage_charts_data: view_model.usage_charts_data,
      pokemon_list: view_model.pokemon_list
    }
    Rails.cache.write(view_model.cache_key, cache_data, expires_in: @cache_expiry)

    view_model
  end

  def fetch_pokemon_details(month, format, pokemon_name)
    # First get the base stats data
    stats_view_model = fetch_and_calculate_stats(month, format)
    return nil if stats_view_model.empty? || !stats_view_model.pokemon_data[pokemon_name]

    # Check cache for detailed calculations
    details_view_model = PokemonDetailsViewModel.new(
      name: pokemon_name,
      month: month,
      format: format
    )

    cached_details = Rails.cache.read(details_view_model.cache_key)
    return cached_details if cached_details

    # Calculate detailed stats
    calculation_service = PokemonStatsCalculationService.new(stats_view_model)
    details = calculation_service.calculate_pokemon_details(pokemon_name)

    # Cache the detailed calculations
    Rails.cache.write(details_view_model.cache_key, details, expires_in: @cache_expiry) if details

    details
  end

  def fetch_months
    cached_months = Rails.cache.read('pokemon_months')
    return cached_months if cached_months

    months = SmogonDataService.fetch_months
    Rails.cache.write('pokemon_months', months, expires_in: 6.hours)
    months
  end

  def fetch_formats(month)
    cache_key = "pokemon_formats_#{month}"
    cached_formats = Rails.cache.read(cache_key)
    return cached_formats if cached_formats

    formats = SmogonDataService.fetch_formats(month)
    Rails.cache.write(cache_key, formats, expires_in: 6.hours)
    formats
  end

  private

  def generate_pokemon_list(view_model)
    view_model.pokemon_data
              .select { |_, data| data['usage'] }
              .sort_by { |_, data| -data['usage'] }
              .map do |name, data|
                {
                  name: name,
                  usage_percentage: (data['usage'] * 100).round(2),
                  is_restricted: view_model.restricted_pokemon_names.include?(name)
                }
              end
  end
end
