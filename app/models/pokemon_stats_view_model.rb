class PokemonStatsViewModel
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :month, :string
  attribute :format, :string
  attribute :pokemon_data, default: {}
  attribute :usage_charts_data, default: {}
  attribute :pokemon_list, default: []
  attribute :restricted_pokemon, default: []
  
  validates :month, presence: true
  validates :format, presence: true

  def initialize(attributes = {})
    super
    load_restricted_pokemon if restricted_pokemon.empty?
  end

  def cache_key
    "pokemon_stats_#{month}_#{format}"
  end

  def empty?
    pokemon_data.empty?
  end

  def pokemon_names
    pokemon_data.keys.select { |name| pokemon_data[name]['usage'] }
                   .sort_by { |name| -pokemon_data[name]['usage'] }
  end

  def restricted_pokemon_names
    @restricted_pokemon_names ||= Set.new(restricted_pokemon)
  end

  def regular_pokemon
    pokemon_names.reject { |name| restricted_pokemon_names.include?(name) }
  end

  def restricted_pokemon_in_data
    pokemon_names.select { |name| restricted_pokemon_names.include?(name) }
  end

  private

  def load_restricted_pokemon
    begin
      restricted_path = Rails.root.join('public', 'restricted_pokemon.json')
      self.restricted_pokemon = JSON.parse(File.read(restricted_path))
    rescue => e
      Rails.logger.warn "Could not load restricted Pokemon: #{e.message}"
      self.restricted_pokemon = []
    end
  end
end
