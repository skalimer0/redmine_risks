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

  def risk_details_to_strings(details, no_html=false, options={})
    # The plugin Redmine Checklists patch the method IssuesHelper::details_to_strings and suppose
    # that it's only used for issues. Thus, if the unpatched version exists, we'll use it instead.
    if respond_to?('details_to_strings_without_checklists')
      return details_to_strings_without_checklists(details, no_html, options)
    end

    details_to_strings(details, no_html, options)
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
    (format_risk_levels(Risk::RISK_IMPACT) {|p| format_risk_impact(p)}).each do |i|
      impacts.push(i[0])
    end
    impacts.push('')
  end

  def self.datas(content_project)    
    allrisks = []
    (format_risk_levels(Risk::RISK_IMPACT) {|i| format_risk_impact(i)}).each do |i|
      (format_risk_levels(Risk::RISK_PROBABILITY) {|p| format_risk_probability(p)}).each do |p|
        allrisks[((i[1] / 25) << 3) + (p[1] / 25)] = []
      end
    end
    sql = "with subprojects as (select id, lft, rgt from projects where id = #{content_project.id}),
    project_issues as (select distinct sp.id as subproject_id, s.project_id, s.id, s.root_id, s.lft, s.rgt
     from subprojects sp 
       join projects p on p.rgt <= sp.rgt and p.lft >= sp.lft 
       left join issues s on s.project_id = p.id and s.closed_on is null)
    select distinct pi.subproject_id, project_id from project_issues pi
    union distinct select distinct p.subproject_id, sub.project_id
     from project_issues p 
	  join issues sub on sub.root_id = p.id and sub.lft >= p.lft and sub.rgt <= p.rgt and sub.closed_on is null"

    link_projects = ActiveRecord::Base.connection.execute(sql).to_a
    ids = []
    link_projects.each do |p|
      unless ids.include? p['project_id']
        ids.push p['project_id'].to_i
      end            
    end

    sql = "select id, probability, impact from risks where status = 'open' "
    sql << "and project_id IN (%s)" % ids.uniq.join(',')
    project_risks = ActiveRecord::Base.connection.execute(sql).to_a
    project_risks.each do |r|
      unless r['impact'].nil? || r['probability'].nil? 
        allrisks[((r['impact'] / 25) << 3) + (r['probability'] / 25)].push r['id']
      end
    end

    datas = "["
    (format_risk_levels(Risk::RISK_IMPACT) {|i| format_risk_impact(i)}).each do |i|
      (format_risk_levels(Risk::RISK_PROBABILITY) {|p| format_risk_probability(p)}).each do |p|
        datas << "{ x: '" + i[0] + "', y: '" + p[0] + "', v: " + allrisks[((i[1] / 25) << 3) + (p[1] / 25)].length.to_s + "},"
      end
    end
    datas.sub(/.*\K,/, ']')
  end
end
