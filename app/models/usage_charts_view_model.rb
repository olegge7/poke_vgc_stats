class UsageChartsViewModel
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :top_regular_pokemon, default: []
  attribute :top_restricted_pokemon, default: []
  attribute :restricted_pairs, default: []
  
  def initialize(attributes = {})
    super
  end

  def has_regular_pokemon?
    top_regular_pokemon.any?
  end

  def has_restricted_pokemon?
    top_restricted_pokemon.any?
  end

  def has_restricted_pairs?
    restricted_pairs.any?
  end

  def chart_data
    {
      regular: format_chart_data(top_regular_pokemon),
      restricted: format_chart_data(top_restricted_pokemon),
      pairs: format_pairs_data(restricted_pairs)
    }
  end

  private

  def format_chart_data(pokemon_data)
    {
      labels: pokemon_data.map { |data| data[:name] },
      values: pokemon_data.map { |data| data[:usage_percentage] }
    }
  end

  def format_pairs_data(pairs_data)
    {
      labels: pairs_data.map { |data| data[:pair_name] },
      values: pairs_data.map { |data| data[:usage_percentage] }
    }
  end
end
