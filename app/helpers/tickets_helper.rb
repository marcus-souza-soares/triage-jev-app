module TicketsHelper
  DEPARTMENT_NAMES = { "billing" => "Financeiro", "technical" => "Suporte técnico", "sales" => "Comercial" }.freeze
  SEVERITY_NAMES = { "trivial" => "Trivial", "minor" => "Baixa", "major" => "Alta", "critical" => "Crítica" }.freeze
  SEVERITY_STYLES = {
    "trivial"  => "bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 ring-slate-200 dark:ring-slate-700",
    "minor"    => "bg-sky-50 dark:bg-sky-500/10 text-sky-700 dark:text-sky-300 ring-sky-200 dark:ring-sky-500/30",
    "major"    => "bg-amber-50 dark:bg-amber-500/10 text-amber-800 dark:text-amber-300 ring-amber-200 dark:ring-amber-500/30",
    "critical" => "bg-rose-50 dark:bg-rose-500/10 text-rose-700 dark:text-rose-300 ring-rose-200 dark:ring-rose-500/30"
  }.freeze

  QUESTION_NAMES = { "urgent" => "Urgência", "department" => "Departamento", "severity" => "Gravidade" }.freeze
  NOUL_NAMES = { "true" => "Sim", "false" => "Não" }.freeze

  def question_name(name)
    QUESTION_NAMES.fetch(name.to_s, name.to_s.humanize)
  end

  # The option name as people read it, whatever kind of question it came from.
  def option_name(question, option)
    case question.to_s
    when "department" then department_name(option)
    when "severity" then SEVERITY_NAMES.fetch(option.to_s, option.to_s.humanize)
    when "urgent" then NOUL_NAMES.fetch(option.to_s, option.to_s.humanize)
    else option.to_s.humanize
    end
  end

  # A choice reads best most likely first; a score and a yes/no keep their order.
  def probability_rows(name, details)
    rows = details.fetch("probabilities", {}).to_a
    rows = rows.sort_by { |_, probability| -probability.to_f } if details["type"] == "choice"
    top = rows.map(&:last).max

    rows.map { |option, probability| [ option_name(name, option), probability.to_f, probability == top ] }
  end

  def percent(value)
    value.nil? ? "—" : "#{(value.to_f * 100).round}%"
  end

  # Margin above the floor, in percentage points. Negative means it missed.
  def margin(value)
    return "—" if value.nil?

    points = (value.to_f * 100).round
    "#{points.positive? ? "+" : ""}#{points} p.p."
  end

  def department_name(department)
    DEPARTMENT_NAMES.fetch(department.to_s, department.to_s.humanize)
  end

  def severity_badge(severity)
    tag.span SEVERITY_NAMES.fetch(severity.to_s, severity.to_s.humanize),
      class: "inline-flex rounded-full px-3 py-1 text-sm font-semibold ring-1 " \
             "#{SEVERITY_STYLES.fetch(severity.to_s, SEVERITY_STYLES["trivial"])}"
  end

  # Full class names, not interpolated ones: Tailwind only generates classes it can
  # find written out in the source.
  def urgent_badge(urgent)
    badge, dot = urgent ?
      [ "bg-rose-50 dark:bg-rose-500/10 text-rose-700 dark:text-rose-300 ring-rose-200 dark:ring-rose-500/30", "bg-rose-500" ] :
      [ "bg-emerald-50 dark:bg-emerald-500/10 text-emerald-700 dark:text-emerald-300 ring-emerald-200 dark:ring-emerald-500/30", "bg-emerald-500" ]

    tag.span class: "inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-sm font-semibold ring-1 #{badge}" do
      tag.span(class: "size-2 rounded-full #{dot}") + (urgent ? " Sim" : " Não")
    end
  end
end
