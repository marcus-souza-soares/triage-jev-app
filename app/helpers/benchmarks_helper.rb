module BenchmarksHelper
  def milliseconds(value)
    return "—" if value.nil?

    value >= 1000 ? "#{number_with_precision(value / 1000.0, precision: 2, separator: ",")} s" : "#{value.round} ms"
  end

  def token_count(value)
    value.nil? ? "—" : number_with_delimiter(value.round, delimiter: ".")
  end

  # How many times larger `value` is than `base`, as "12,3×".
  def times_larger(value, base)
    return nil if value.nil? || base.to_f.zero?

    "#{number_with_precision(value / base.to_f, precision: 1, separator: ",")}×"
  end

  # A bar's width as a share of the larger of two values.
  def bar_width(value, other)
    max = [ value.to_f, other.to_f ].max
    max.zero? ? 0 : (value.to_f / max * 100).round(1)
  end

  def prediction_cell(run, expected)
    return tag.span("erro", class: "text-rose-600 dark:text-rose-400", title: run["error"]) unless run && run["ok"]
    return tag.span("resposta inválida", class: "text-rose-600 dark:text-rose-400", title: run["raw"]) unless run["prediction"]

    safe_join(%w[department urgent severity].map do |key|
      value = run["prediction"][key]
      label = key == "urgent" ? (value ? "urgente" : "normal") : (key == "department" ? department_name(value) : TicketsHelper::SEVERITY_NAMES.fetch(value.to_s, value.to_s))
      hit = value == expected[key]
      tag.span(label, class: hit ? "text-slate-700 dark:text-slate-300" : "font-semibold text-rose-600 dark:text-rose-400 line-through decoration-1")
    end, tag.span(" · ", class: "text-slate-400 dark:text-slate-600"))
  end
end
