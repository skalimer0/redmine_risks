module RisksHelper
  include IssuesHelper
  include QueriesHelper
  include Redmine::I18n 

  def find_risk
    risk_id = params[:risk_id] || params[:id]

    @risk = Risk.find(risk_id)
    raise Unauthorized unless @risk.visible?
    @project = @risk.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_risks
    @risks = Risk
      .where(:id => (params[:id] || params[:ids]))
      .preload(:project, :author, :assigned_to)
      .to_a

    raise ActiveRecord::RecordNotFound if @risks.empty?
    raise Unauthorized unless @risks.all?(&:visible?)

    @projects = @risks.collect(&:project).compact.uniq
    @project = @projects.first if @projects.size == 1
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def format_risk_status(status)
    l("label_risk_status_#{status}")
  end

  def self.format_risk_probability(probability)
    format_risk_level(Risk::RISK_PROBABILITY, probability) {|p| l("label_risk_probability_#{p}")}
  end

  def self.format_risk_impact(impact)
    format_risk_level(Risk::RISK_IMPACT, impact) {|i| l("label_risk_impact_#{i}")}
  end

  def format_risk_strategy(strategy)
    return unless Risk::RISK_STRATEGY.include?(strategy)
    l("label_risk_strategy_#{strategy}")
  end

  def self.format_risk_level(levels, level, &block)
    return if level.nil?

    increment = 100 / (levels.count - 1)

    if level % increment != 0
      return level.to_s + "%"
    end

    yield levels[level / increment]
  end

  def self.format_risk_levels(levels, value = nil, &block)
    index     = 0
    increment = 100 / (levels.count - 1)

    levels.collect do |level|
      value  = index * increment
      index += 1

      [yield(value), value]
    end
  end

  def render_risk_relations(risk)
    manage_relations = User.current.allowed_to?(:manage_risk_relations, risk.project)

    relations = risk.issues.visible.collect do |issue|
      delete_link = link_to(l(:label_relation_delete),
                            {:controller => 'risk_issues', :action => 'destroy', :risk_id => @risk, :issue_id => issue},
                            :remote => true,
                            :method => :delete,
                            :data => {:confirm => l(:text_are_you_sure)},
                            :title => l(:label_relation_delete),
                            :class => 'icon-only icon-link-break')

      relation = ''.html_safe

      relation << content_tag('td', check_box_tag("ids[]", issue.id, false, :id => nil), :class => 'checkbox')
      relation << content_tag('td', link_to_issue(issue, :project => Setting.cross_project_issue_relations?).html_safe, :class => 'subject', :style => 'width: 50%')
      relation << content_tag('td', issue.status, :class => 'status')
      relation << content_tag('td', issue.start_date, :class => 'start_date')
      relation << content_tag('td', issue.due_date, :class => 'due_date')
      relation << content_tag('td', progress_bar(issue.done_ratio), :class=> 'done_ratio') unless issue.disabled_core_fields.include?('done_ratio')
      relation << content_tag('td', delete_link, :class => 'buttons') if manage_relations

      content_tag('tr', relation, :id => "relation-#{issue.id}", :class => "issue hascontextmenu #{issue.css_classes}")
    end

    content_tag('table', relations.join.html_safe, :class => 'list issues odd-even')
  end

  def column_value_with_risks(column, item, value)
    case column.name
    when :id, :subject
      link_to value, risk_path(item)
    when :probability
      format_risk_probability(value)
    when :impact
      format_risk_impact(value)
    when :strategy
      format_risk_strategy(value)
    when :treatments
      item.treatments? ? content_tag('div', textilizable(item, :treatments), :class => "wiki") : ''
    when :lessons
      item.lessons? ? content_tag('div', textilizable(item, :lessons), :class => "wiki") : ''
    else
      column_value_without_risks(column, item, value)
    end
  end

  alias_method :column_value_without_risks, :column_value
  alias_method :column_value, :column_value_with_risks

  def normalize_blank_values(attributes)
    attributes
      .map {|column, value| [column, value.present? ? value : nil] }
      .to_h
  end

  def format_risk_levels(levels, value = nil, &block)
    RisksHelper.format_risk_levels(levels, value = nil, &block)
  end

  def format_risk_probability(probability)
    RisksHelper.format_risk_probability(probability)
  end

  def format_risk_impact(impact)
    RisksHelper.format_risk_impact(impact)
  end

  def format_risk_level(levels, level, &block)
    RisksHelper.format_risk_level(levels, level, &block)
  end

  def self.probabilities
    probabilities = ['']
    (format_risk_levels(Risk::RISK_PROBABILITY) {|p| format_risk_probability(p)}).each do |p|
      probabilities.insert(1, p[0])
    end
    probabilities.push('')
  end

  def self.impacts
    impacts = ['']
    (format_risk_levels(Risk::RISK_IMPACT) {|p| format_risk_impact(p)}).each do |p|
      impacts.push(p[0])
    end
    impacts.push('')
  end

  def self.datas(content_project)    
    @risks = Risk.where(:id => (content_project.id.to_i)).to_a
    allrisks = []
    (format_risk_levels(Risk::RISK_IMPACT) {|i| format_risk_impact(p)}).each do |i|
      (format_risk_levels(Risk::RISK_PROBABILITY) {|p| format_risk_probability(p)}).each do |p|
        allrisks[i[0].to_s + ':' + p[0].to_s] = []
      end
    end
    Rails.logger.info(allrisks)
    
    risks.each do |risk|
      Rails.logger.info(risk)
    end

    "[
      { x: 'Négligeable', y: 'Peu probable', v: 1 },
      { x: 'Négligeable', y: 'Basse', v: 1 },
      { x: 'Négligeable', y: 'Moyenne', v: 1 },
      { x: 'Négligeable', y: 'Haute', v: 1},
      { x: 'Négligeable', y: 'Attendue', v: 1 },
      { x: 'Mineur', y: 'Peu probable', v: 1 },
      { x: 'Mineur', y: 'Basse', v: 1 },
      { x: 'Mineur', y: 'Moyenne', v: 1},
      { x: 'Mineur', y: 'Haute', v: 1 },
      { x: 'Mineur', y: 'Attendue', v: 1 },
      { x: 'Modéré', y: 'Peu probable', v: 1 },
      { x: 'Modéré', y: 'Basse', v: 1 },
      { x: 'Modéré', y: 'Moyenne', v: 1 },
      { x: 'Modéré', y: 'Haute', v: 1 },
      { x: 'Modéré', y: 'Attendue', v: 1 },
      { x: 'Important', y: 'Peu probable', v: 1 },
      { x: 'Important', y: 'Basse', v: 1 },
      { x: 'Important', y: 'Moyenne', v: 1 },
      { x: 'Important', y: 'Haute', v: 1 },
      { x: 'Important', y: 'Attendue', v: 1 },
      { x: 'Sévère', y: 'Peu probable', v: 1 },
      { x: 'Sévère', y: 'Basse', v: 1 },
      { x: 'Sévère', y: 'Moyenne', v: 1 },
      { x: 'Sévère', y: 'Haute', v: 1},
      { x: 'Sévère', y: 'Attendue', v: 1 }
    ]"    
  end
end
