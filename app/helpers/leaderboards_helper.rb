module LeaderboardsHelper
  LEADERBOARD_TABS = {
    "elo" => {
      icon: "chart-no-axes-combined",
      fallback: "trending-up",
      ranking_method: :ranked_elo,
      empty_key: "elo",
      columns: %i[position player role matches elo last_change],
      col_widths: %w[7% 33% 18% 12% 15% 15%]
    },
    "goals" => {
      icon: "target",
      fallback: "circle-dot",
      ranking_method: :ranked_top_scorers,
      empty_key: "goals",
      columns: %i[position player role matches goals goals_per_match],
      col_widths: %w[7% 33% 18% 12% 15% 15%]
    },
    "assists" => {
      icon: "handshake",
      fallback: "share-2",
      ranking_method: :ranked_top_assistants,
      empty_key: "assists",
      columns: %i[position player role matches assists assists_per_match],
      col_widths: %w[7% 33% 18% 12% 15% 15%]
    },
    "goals_assists" => {
      icon: "chart-bar",
      fallback: "chart-no-axes-combined",
      ranking_method: :ranked_goals_assists,
      empty_key: "goals_assists",
      columns: %i[position player role matches goals_assists goals_assists_per_match],
      col_widths: %w[7% 33% 18% 12% 15% 15%]
    },
    "mvp" => {
      icon: "star",
      fallback: "award",
      ranking_method: :ranked_top_mvp,
      empty_key: "mvp",
      columns: %i[position player role matches mvp_votes],
      col_widths: %w[7% 38% 20% 15% 20%]
    },
    "def" => {
      icon: "shield-check",
      fallback: "shield",
      ranking_method: :ranked_top_def,
      empty_key: "def",
      columns: %i[position player role matches def_votes],
      col_widths: %w[7% 38% 20% 15% 20%]
    },
    "record" => {
      icon: "trophy",
      fallback: "badge-check",
      ranking_method: :ranked_record,
      empty_key: "record",
      columns: %i[position player role matches wins draws losses win_rate goal_difference],
      col_widths: %w[6% 26% 14% 9% 8% 8% 8% 10% 11%]
    }
  }.freeze
  NUMERIC_COLUMNS = %i[matches elo last_change goals goals_per_match assists assists_per_match goals_assists goals_assists_per_match mvp_votes def_votes wins draws losses win_rate goal_difference].freeze

  def leaderboard_tabs
    LEADERBOARD_TABS
  end

  def leaderboard_tab_config(active_tab)
    leaderboard_tabs.fetch(active_tab) { leaderboard_tabs.fetch("elo") }
  end

  def leaderboard_ranked_entries(leaderboards, active_tab)
    return [] if leaderboards.blank?

    leaderboards.public_send(leaderboard_tab_config(active_tab).fetch(:ranking_method))
  end

  def leaderboard_numeric_column?(column)
    NUMERIC_COLUMNS.include?(column)
  end

  def leaderboard_summary_cards(leaderboards)
    [
      summary_card("elo_leader", "trending-up", "chart-no-axes-combined", leaderboards&.ranked_elo&.first, :elo),
      summary_card("top_scorer", "target", "circle-dot", leaderboards&.ranked_top_scorers&.first, :goals),
      summary_card("top_assistant", "handshake", "share-2", leaderboards&.ranked_top_assistants&.first, :assists),
      summary_card("season_mvp", "star", "award", leaderboards&.ranked_top_mvp&.first, :mvp_votes_count),
      summary_card("best_def", "shield-check", "shield", leaderboards&.ranked_top_def&.first, :def_votes_count)
    ]
  end

  def leaderboard_cell_value(player_stat, column, ranked_entry)
    case column
    when :position
      ranked_entry.rank
    when :player
      player_stat.player.name
    when :role
      role_label(player_stat.player.role_code)
    when :matches
      player_stat.matches_played_count.to_i
    when :elo
      player_stat.elo || "-"
    when :last_change
      leaderboard_delta_tag(player_stat.last_elo_delta_value)
    when :goals
      player_stat.goals
    when :goals_per_match
      leaderboard_rate_value(player_stat.goals_per_match_value, player_stat.matches_played_count)
    when :assists
      player_stat.assists
    when :assists_per_match
      leaderboard_rate_value(player_stat.assists_per_match_value, player_stat.matches_played_count)
    when :goals_assists
      player_stat.goals.to_i + player_stat.assists.to_i
    when :goals_assists_per_match
      leaderboard_rate_value(player_stat.goals_assists_per_match_value, player_stat.matches_played_count)
    when :mvp_votes
      player_stat.mvp_votes_count
    when :def_votes
      player_stat.def_votes_count
    when :wins
      player_stat.wins_count.to_i
    when :draws
      player_stat.draws_count.to_i
    when :losses
      player_stat.losses_count.to_i
    when :win_rate
      leaderboard_win_rate(player_stat.win_rate_value, player_stat.matches_played_count)
    when :goal_difference
      leaderboard_signed_number(player_stat.goal_difference_value.to_i)
    end
  end

  def leaderboard_player_initials(player)
    player.name.split.map { |part| part.first }.join.first(2).upcase
  end

  def leaderboard_delta_tag(value)
    delta = value.to_i if value.present?
    return tag.span("—", class: "leaderboards-delta leaderboards-delta--muted") if delta.blank? || delta.zero?

    css_class = delta.positive? ? "leaderboards-delta--positive" : "leaderboards-delta--negative"
    icon = delta.positive? ? "trending-up" : "trending-down"

    tag.span(class: "leaderboards-delta #{css_class}") do
      safe_join([
        safe_lucide_icon(icon, fallback: "chart-no-axes-combined", class_name: "leaderboards-delta__icon"),
        tag.span(leaderboard_signed_number(delta))
      ])
    end
  end

  def leaderboard_rank_badge(rank)
    rank = rank.to_i
    classes = [ "leaderboards-rank" ]
    return tag.span(rank, class: classes.join(" ")) unless rank.between?(1, 3)

    classes << "leaderboards-rank--medal leaderboards-rank--#{leaderboard_medal_tier(rank)}"

    tag.span(class: classes.join(" "), title: t("leaderboards.table.rank_label", rank:)) do
      safe_join([
        safe_lucide_icon("medal", fallback: "award", class_name: "leaderboards-rank__medal"),
        tag.span(rank, class: "leaderboards-rank__number")
      ])
    end
  end

  private

  def leaderboard_rate_value(value, matches_count)
    return "—" if matches_count.to_i.zero?

    number_with_precision(value.to_d, precision: 2, strip_insignificant_zeros: true)
  end

  def leaderboard_win_rate(value, matches_count)
    return "—" if matches_count.to_i.zero?

    "#{value.to_d.round}%"
  end

  def leaderboard_signed_number(value)
    return "0" if value.zero?

    value.positive? ? "+#{value}" : value.to_s
  end

  def leaderboard_medal_tier(rank)
    { 1 => "gold", 2 => "silver", 3 => "bronze" }.fetch(rank)
  end

  def summary_card(key, icon, fallback, ranked_entry, value_method)
    player_stat = ranked_entry&.entry

    {
      key:,
      icon:,
      fallback:,
      player_stat:,
      value: player_stat ? player_stat.public_send(value_method) : nil
    }
  end
end
