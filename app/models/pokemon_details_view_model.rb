class PokemonDetailsViewModel
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :month, :string
  attribute :format, :string
  attribute :usage_percentage, :float
  attribute :raw_count, :integer
  
  # Overview data
  attribute :items, default: []
  attribute :moves, default: []
  attribute :abilities, default: []
  attribute :natures, default: []
  
  # Stat distributions
  attribute :hp_distribution, default: []
  attribute :attack_distribution, default: []
  attribute :defense_distribution, default: []
  attribute :sp_atk_distribution, default: []
  attribute :sp_def_distribution, default: []
  attribute :speed_distribution, default: []
  
  # Base stats for calculations
  attribute :base_stats, default: {}
  
  validates :name, presence: true
  validates :month, presence: true
  validates :format, presence: true

  def cache_key
    "pokemon_details_#{name}_#{month}_#{format}"
  end

  def has_stat_distributions?
    [hp_distribution, attack_distribution, defense_distribution,
     sp_atk_distribution, sp_def_distribution, speed_distribution].any?(&:present?)
  end

  def has_overview_data?
    [items, moves, abilities, natures].any?(&:present?)
  end

  def restricted?
    @restricted ||= begin
      restricted_path = Rails.root.join('public', 'restricted_pokemon.json')
      restricted_list = JSON.parse(File.read(restricted_path))
      restricted_list.include?(name)
    rescue
      false
    end
  end
end
