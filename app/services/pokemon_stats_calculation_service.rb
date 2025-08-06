class PokemonStatsCalculationService
  def initialize(view_model)
    @view_model = view_model
    @pokedex = load_pokedex
  end

  def calculate_usage_charts
    return UsageChartsViewModel.new unless @view_model.pokemon_data.any?

    pokemon_entries = @view_model.pokemon_data
                                 .select { |_, data| data["usage"] }
                                 .map { |name, data| { name: name, usage: data["usage"] } }

    regular_pokemon = pokemon_entries.reject { |entry| @view_model.restricted_pokemon_names.include?(entry[:name]) }
    restricted_pokemon = pokemon_entries.select { |entry| @view_model.restricted_pokemon_names.include?(entry[:name]) }

    top_regular = regular_pokemon.sort_by { |entry| -entry[:usage] }
                                .first(12)
                                .map { |entry| format_usage_entry(entry) }

    top_restricted = restricted_pokemon.sort_by { |entry| -entry[:usage] }
                                      .first(8)
                                      .map { |entry| format_usage_entry(entry) }

    restricted_pairs = calculate_restricted_pairs

    UsageChartsViewModel.new(
      top_regular_pokemon: top_regular,
      top_restricted_pokemon: top_restricted,
      restricted_pairs: restricted_pairs
    )
  end

  def calculate_pokemon_details(pokemon_name)
    return nil unless @view_model.pokemon_data[pokemon_name]

    poke_data = @view_model.pokemon_data[pokemon_name]
    base_stats = get_base_stats(pokemon_name)

    details = PokemonDetailsViewModel.new(
      name: pokemon_name,
      month: @view_model.month,
      format: @view_model.format,
      usage_percentage: poke_data["usage"] ? (poke_data["usage"] * 100).round(2) : 0,
      raw_count: poke_data["Raw count"] || 0,
      base_stats: base_stats
    )

    # Calculate overview data
    details.items = calculate_items(poke_data)
    details.moves = calculate_moves(poke_data)
    details.abilities = calculate_abilities(poke_data)
    details.natures = calculate_natures(poke_data)

    # Calculate stat distributions
    if base_stats.any?
      details.hp_distribution = calculate_hp_distribution(poke_data, base_stats)
      details.attack_distribution = calculate_attack_distribution(poke_data, base_stats)
      details.defense_distribution = calculate_defense_distribution(poke_data, base_stats)
      details.sp_atk_distribution = calculate_sp_atk_distribution(poke_data, base_stats)
      details.sp_def_distribution = calculate_sp_def_distribution(poke_data, base_stats)
      details.speed_distribution = calculate_speed_distribution(poke_data, base_stats)
    end

    details
  end

  private

  def format_usage_entry(entry)
    {
      name: entry[:name],
      usage_percentage: (entry[:usage] * 100).round(2)
    }
  end

  def calculate_restricted_pairs
    return [] unless @view_model.pokemon_data.any?

    pair_counts = Hash.new(0)
    total_teams = 0

    @view_model.pokemon_data.each do |pokemon_name, poke_data|
      next unless poke_data["Teammates"]
      next unless @view_model.restricted_pokemon_names.include?(pokemon_name)

      poke_data["Teammates"].each do |teammate, count|
        next unless @view_model.restricted_pokemon_names.include?(teammate)

        pair = [ pokemon_name, teammate ].sort.join(" + ")
        pair_counts[pair] += count
        total_teams += count
      end
    end

    return [] if total_teams == 0

    pair_counts.sort_by { |_, count| -count }
               .first(8)
               .map do |pair, count|
                 {
                   pair_name: pair,
                   usage_percentage: ((count.to_f / total_teams) * 100).round(2)
                 }
               end
  end

  def calculate_items(poke_data)
    return [] unless poke_data["Items"]

    total_items = poke_data["Items"].values.sum
    return [] if total_items == 0

    poke_data["Items"].sort_by { |_, count| -count }
             .first(10)
             .map do |item, count|
               pct = ((count.to_f / total_items) * 100).round(2)
               next if pct == 0
               [ item, "#{pct}%" ]
             end
             .compact
  end

  def calculate_moves(poke_data)
    return [] unless poke_data["Moves"]

    total_moves = poke_data["Moves"].values.sum
    return [] if total_moves == 0

    poke_data["Moves"].sort_by { |_, count| -count }
             .first(10)
             .map do |move, count|
               pct = ((count.to_f / total_moves) * 400).round(2)
               next if pct == 0
               [ move, "#{pct}%" ]
             end
             .compact
  end

  def calculate_abilities(poke_data)
    return [] unless poke_data["Abilities"]

    total_abilities = poke_data["Abilities"].values.sum
    return [] if total_abilities == 0

    poke_data["Abilities"].sort_by { |_, count| -count }
             .map do |ability, count|
               pct = ((count.to_f / total_abilities) * 100).round(2)
               next if pct == 0
               [ ability, "#{pct}%" ]
             end
             .compact
  end

  def calculate_natures(poke_data)
    return [] unless poke_data["Spreads"]

    nature_totals = Hash.new(0)
    nature_spreads = Hash.new { |h, k| h[k] = Hash.new(0) }

    poke_data["Spreads"].each do |spread, count|
      parts = spread.split(":")
      nature = parts[0]
      nature_totals[nature] += count
      nature_spreads[nature][spread] += count
    end

    total_spreads = poke_data["Spreads"].values.sum
    return [] if total_spreads == 0

    nature_totals.sort_by { |_, count| -count }
                 .map do |nature, count|
                   pct = ((count.to_f / total_spreads) * 100).round(2)
                   next if pct == 0

                   spreads_for_nature = nature_spreads[nature].sort_by { |_, spread_count| -spread_count }
                   common_spreads = spreads_for_nature.first(5)
                                                     .map do |spread, spread_count|
                                                       evs = spread.split(":")[1]
                                                       spread_pct = ((spread_count.to_f / count) * 100).round(2)
                                                       next if spread_pct == 0
                                                       "#{evs} (#{spread_pct}%)"
                                                     end
                                                     .compact
                                                     .join("<br>")

                   [ nature, "#{pct}%", common_spreads ]
                 end
                 .compact
  end

  def calculate_speed_distribution(poke_data, base_stats)
    calculate_stat_distribution(poke_data, base_stats, "spe", 5)
  end

  def calculate_attack_distribution(poke_data, base_stats)
    calculate_stat_distribution(poke_data, base_stats, "atk", 1)
  end

  def calculate_defense_distribution(poke_data, base_stats)
    calculate_stat_distribution(poke_data, base_stats, "def", 2)
  end

  def calculate_sp_atk_distribution(poke_data, base_stats)
    calculate_stat_distribution(poke_data, base_stats, "spa", 3)
  end

  def calculate_sp_def_distribution(poke_data, base_stats)
    calculate_stat_distribution(poke_data, base_stats, "spd", 4)
  end

  def calculate_hp_distribution(poke_data, base_stats)
    return [] unless base_stats["hp"] && poke_data["Spreads"]

    base_hp = base_stats["hp"]
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

    format_stat_distribution(hp_counts)
  end

  def calculate_stat_distribution(poke_data, base_stats, stat_key, ev_index)
    return [] unless base_stats[stat_key] && poke_data["Spreads"]

    base_stat = base_stats[stat_key]
    stat_counts = Hash.new(0)

    nature_modifiers = get_nature_modifiers(stat_key)

    poke_data["Spreads"].each do |spread, count|
      parts = spread.split(":")
      next unless parts.length == 2

      nature = parts[0]
      stats = parts[1].split("/").map(&:to_i)
      stat_ev = stats[ev_index]

      nature_multiplier = nature_modifiers[:up].include?(nature) ? 1.1 :
                         nature_modifiers[:down].include?(nature) ? 0.9 : 1.0

      iv = 31
      iv = 0 if nature_modifiers[:down].include?(nature) && stat_ev == 0

      calculated_stat = (((((2 * base_stat + iv + (stat_ev / 4)) * 50) / 100) + 5) * nature_multiplier).floor
      stat_counts[calculated_stat] += count
    end

    format_stat_distribution(stat_counts)
  end

  def format_stat_distribution(stat_counts)
    total = stat_counts.values.sum
    return [] if total == 0

    stat_counts.keys.sort.map do |stat_value|
      pct = ((stat_counts[stat_value].to_f / total) * 100).round(2)
      next if pct == 0
      [ stat_value.to_s, "#{pct}%" ]
    end.compact
  end

  def get_nature_modifiers(stat_key)
    case stat_key
    when "spe"
      { up: %w[Timid Hasty Jolly Naive], down: %w[Brave Relaxed Quiet Sassy] }
    when "atk"
      { up: %w[Lonely Adamant Naughty Brave], down: %w[Bold Modest Calm Timid] }
    when "def"
      { up: %w[Bold Impish Lax Relaxed], down: %w[Lonely Mild Gentle Hasty] }
    when "spa"
      { up: %w[Modest Mild Rash Quiet], down: %w[Adamant Impish Careful Jolly] }
    when "spd"
      { up: %w[Calm Gentle Careful Sassy], down: %w[Naughty Lax Rash Naive] }
    else
      { up: [], down: [] }
    end
  end

  def get_base_stats(pokemon_name)
    return {} unless @pokedex

    stats = @pokedex[pokemon_name]&.dig("baseStats") ||
            @pokedex[normalize_name(pokemon_name)]&.dig("baseStats")

    stats || {}
  end

  def normalize_name(name)
    name.downcase.gsub(/[^a-z0-9]/, "")
  end

  def load_pokedex
    pokedex_path = Rails.root.join("public", "pokedex.json")
    JSON.parse(File.read(pokedex_path))
  rescue => e
    Rails.logger.warn "Could not load Pokedex: #{e.message}"
    {}
  end
end
