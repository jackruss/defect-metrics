require 'json'
require 'time'
require './defect'
require './table'

def add_to_table(output,table)
  #puts output
  story_data = JSON.parse(output)
  story_data.each do |story|
    defect = Defect.new
    defect.id = story["id"]

    # Get the created at timestamp
    defect.opened_date = Time.at(story["created_at"] / 1000)

    # Parse the PT name text
    name_text = story["name"]

    if name_text =~ /TI[0-9]+: /
      workitem_text = name_text.gsub(/: .*/,"")
      defect.fields["work item"] = workitem_text
    end


    # Parse the PT description text
    string_to_parse = story["description"]

    template_fields = ["ABSTRACT","DESCRIPTION","IMPACT","PRODUCT","ORIGINATOR","DETAILS","OPENED"]
    splitstring = "%%%JMR%PARSE%HERE%%%"
    template_fields.each do |template_field|
      string_to_parse = string_to_parse.gsub(/[\n ]*#{template_field}:[\n ]*/,"#{splitstring}#{template_field}: ")
    end
    string_to_parse = string_to_parse.gsub(/\n/,"<br />")
    field_array = string_to_parse.split(/#{splitstring}/)
    template_fields.each do |template_field|
      field_array.each do |entry|
        if entry =~ /#{template_field}: /
          defect.fields[template_field.downcase] = entry.gsub("#{template_field}: ","")
        end
      end
    end

    # Overwrite abstract if specified (otherwise pull from the story title)
    unless defect.fields["abstract"]
      abstract_text = name_text.gsub(/TI.....: /,"")
      defect.fields["abstract"] = abstract_text
    end

    # Compute age
    defect.opened_date = Time.parse(defect.fields["opened"]) if defect.fields["opened"]
      this_comment = Hash.new
      this_comment["status_update"] = "Defect opened."
      this_comment["status_time"] = defect.opened_date
      defect.comments << this_comment
    current_date = Time.now
    defect.age = (current_date - defect.opened_date).to_i / (24 * 60 * 60)

    # Parse the current_state
    defect.fields["state"] = story["current_state"]
    if defect.fields["state"] == "accepted"
      defect.accepted_date = Time.at(story["accepted_at"] / 1000)
      this_comment = Hash.new
      this_comment["status_update"] = "Fix accepted by QA."
      this_comment["status_time"] = defect.accepted_date
      defect.comments << this_comment
    end

    # Parse the labels
    labels = Hash.new
    story["labels"].each do |label|
      labels[label["name"]] = true
    end
    defect.fields["labels"] = labels

    if defect.fields["labels"]["new"]
      defect.priority = :unprioritized
      defect.fields["priority value"] = 10
    elsif defect.fields["labels"]["critical"]
      defect.priority = :critical
      defect.fields["priority value"] = 1
    elsif defect.fields["labels"]["major"]
      defect.priority = :major
      defect.fields["priority value"] = 2
    elsif defect.fields["labels"]["moderate"]
      defect.priority = :moderate
      defect.fields["priority value"] = 3
    elsif defect.fields["labels"]["minor"]
      defect.priority = :minor
      defect.fields["priority value"] = 4
    else
      defect.priority = :unprioritized
      defect.fields["priority value"] = 10
    end

    # Parse the comments
    story["comments"].each do |comment|
      if comment["text"] =~ /STATUS: /
        this_comment = Hash.new
        status_update = comment["text"].gsub(/.*STATUS: /,"")
        this_comment["status_update"] = status_update
        status_time = Time.at(comment["created_at"] / 1000)
        this_comment["status_time"] = status_time
        defect.comments << this_comment
      end
      if comment["text"] =~ /SHIPPED: /
        shipped_text = comment["text"].gsub(/.*STATUS: /,"")
        defect.shipped_date = Time.parse(shipped_text)
        this_comment = Hash.new
        this_comment["status_update"] = "Fix shipped to production."
        this_comment["status_time"] = defect.shipped_date
        defect.comments << this_comment
      end
    end

    defect.comments = defect.comments.sort_by { |comment| [comment["status_time"]] }
     
    table << defect

  end
end


def build_defect_list
  table = []
  projects = []
  projects << 1172458 #QA
  projects << 100817 #EireneRx
  projects << 872981 #InterOps
  projects << 889254 #ART
  projects << 846245 #niarx
  projects << 1049386 #MU2
  projects.each do |project|
    output = `export PROJECT_ID=#{project.to_s};
              curl -X GET -H "X-TrackerToken: #{ENV["PT_TOKEN"]}" "https://www.pivotaltracker.com/services/v5/projects/$PROJECT_ID/stories?fields=name,created_at,current_state,accepted_at,description,comments,labels&date_format=millis&filter=label%3Aqa_metric%20includedone%3Atrue"`
    add_to_table(output,table)
  end
  return table
end


def print_defect_status_count_table
  html = ""
  html << "    <table class=\"defect-counts\">\n"
  html << "      <tr>\n"
  html << "      <th>Priority</th>\n"
  html << "      <th>Defects</th>\n"
  html << "      </tr>\n"
  rows = [["Critical",:critical],["Major",:major],["Moderate",:moderate],["Minor",:minor],["Unprioritized",:unprioritized]]
  rows.each { |category,label|
    html << "      <tr>\n"
    html << "      <td>#{category}</td>\n"
    html << "      <td>#{Defect::get_priority_count(label)}</td>\n"
    html << "      </tr>\n"
  }
  html << "    </table>\n"
  return html
end


def print_page_header(title)
  html = ""
  html << "<html>\n"
  html << "  <head>\n"
  html << "    <link rel=\"stylesheet\" type=\"text/css\" href=\"style.css\">\n"
  html << "    <title>#{title}</title>\n"
  html << "  </head>\n"
  html << "  <body>\n"
  return html
end


def print_page_footer
  html = ""
  html << "  </body>\n"
  html << "</html>\n"
  return html
end


def active_defect_status(defects)
  priority_table = defects.sort_by { |defect| [defect.get_priority_value,defect.age] }
  active_defects = []
  priority_table.each {|defect|
    active_defects << defect unless defect.shipped_date
  }

  html = print_page_header("Active Defect Status")
  html << "    <h1>Active Defect Status - #{Time.now.strftime("%Y/%m/%d %H:%M")}</h1>\n"
  html << print_defect_status_count_table()
  html << "    <br />\n"
  html << "    <p>Defects are listed in priority order, as determined by QA and via the weekly bug scrub.</p>\n"
  active_defect_status = Table.new([:abstract,:workitem,:product,:description,:impact,:age,:prioritization,:status])
  html << active_defect_status.get_html(active_defects)
  html << print_page_footer

  File.open("defect_status.html", 'w') { |file| file.write(html) }
end


def all_defect_status(defects)
  priority_table = defects.sort_by { |defect| [defect.get_priority_value,defect.age] }

  all_defect_status = Table.new([:product,:workitem,:abstract,:description,:impact,:age,:prioritization,:originator,:status])
  html = print_page_header("All Defect Status")
  html << "    <h1>Defect Status - #{Time.now.strftime("%Y/%m/%d %H:%M")}</h1>\n"
  html << "    <p>Defects are listed in priority order, as determined by QA and via the weekly bug scrub.</p>\n"
  html << all_defect_status.get_html(priority_table)
  html << print_page_footer

  File.open("all_defect_status.html", 'w') { |file| file.write(html) }
end


def build_backlog_graph(defects)
  require 'gruff'
  first_date = Time.new(2014,9,1)
  today_date = Time.now
  next_date = first_date
  dates = []
  backlog_critical = []
  backlog_major = []
  backlog_moderate = []
  backlog_minor = []
  backlog_unprioritized = []
  backlog_total = []
  while next_date < today_date
    dates << next_date
    next_date = next_date + 86400 + 4000 # Get more than an hour into the next day
    next_date = Time.new(next_date.strftime("%Y"),next_date.strftime("%m"),next_date.strftime("%d"))
  end
  dates.each do |date|
    critical = 0
    major = 0
    moderate = 0
    minor = 0
    unprioritized = 0
    total = 0
    defects.each do |defect|
      if defect.was_active?(date)
        total += 1
        case defect.priority 
        when :critical
          critical += 1
        when :major
          major += 1
        when :moderate
          moderate += 1
        when :minor
          minor += 1
        else 
          unprioritized += 1
        end
      end
    end
    backlog_critical << critical
    backlog_major << major
    backlog_moderate << moderate
    backlog_minor << minor
    backlog_unprioritized << unprioritized
    backlog_total << total
  end

  label_hash = Hash.new
  [0, (dates.size/2).round, dates.size-1].each do |i|
    label_hash[i] = dates[i].strftime('%m/%d/%y') if dates[i]
  end

  g = Gruff::StackedArea.new
  g.title = "Defect Backlog"
  g.colors = ["#FF0000", "#FF8000", "#FFFF00", "#2F5597", "#D9D9D9"]
  g.labels = label_hash
  g.data :Critical, backlog_critical
  g.data :Major, backlog_major
  g.data :Moderate, backlog_moderate
  g.data :Minor, backlog_minor
  g.data :Unprioritized, backlog_unprioritized
  g.write('defect_backlog.png')

  html = "<html>\n"
  html << "  <head>\n"
  html << "    <link rel=\"stylesheet\" type=\"text/css\" href=\"style.css\">\n"
  html << "    <title>Defect Backlog</title>\n"
  html << "  </head>\n"
  html << "  <body>\n"
  html << "    <h1>Defect Backlog - #{Time.now.strftime("%Y/%m/%d %H:%M")}</h1>\n"
  html << "    <img src=\"defect_backlog.png\">\n"
  html << "  </body>\n"
  html << "</html>\n"

  File.open("defect_backlog.html", 'w') { |file| file.write(html) }
end


def build_arrivals_graph(defects)
  require 'gruff'
  first_date = Time.new(2014,9,1)
  today_date = Time.now
  next_date = first_date
  dates = []
  arrivals_critical = []
  arrivals_major = []
  arrivals_moderate = []
  arrivals_minor = []
  arrivals_unprioritized = []
  arrivals_total = []
  while next_date < today_date
    dates << next_date
    next_date = next_date + 86400*7 + 4000 # Get more than an hour into the next week
    next_date = Time.new(next_date.strftime("%Y"),next_date.strftime("%m"),next_date.strftime("%d"))
  end
  dates.each do |date|
    beginning_of_week = date
    end_date = date + 86400*7 + 4000
    end_of_week = Time.new(end_date.strftime("%Y"),end_date.strftime("%m"),end_date.strftime("%d"))
    critical = 0
    major = 0
    moderate = 0
    minor = 0
    unprioritized = 0
    total = 0
    defects.each do |defect|
      if defect.opened_between?(beginning_of_week,end_of_week)
        total += 1
        case defect.priority 
        when :critical
          critical += 1
        when :major
          major += 1
        when :moderate
          moderate += 1
        when :minor
          minor += 1
        else 
          unprioritized += 1
        end
      end
    end
    arrivals_critical << critical
    arrivals_major << major
    arrivals_moderate << moderate
    arrivals_minor << minor
    arrivals_unprioritized << unprioritized
    arrivals_total << total
  end

  label_hash = Hash.new
  [0, (dates.size/2).round, dates.size-1].each do |i|
    label_hash[i] = dates[i].strftime('%m/%d/%y') if dates[i]
  end

  g = Gruff::StackedBar.new
  g.title = "Defect Arrivals"
  g.colors = ["#FF0000", "#FF8000", "#FFFF00", "#2F5597", "#D9D9D9"]
  g.labels = label_hash
  g.data :Critical, arrivals_critical
  g.data :Major, arrivals_major
  g.data :Moderate, arrivals_moderate
  g.data :Minor, arrivals_minor
  g.data :Unprioritized, arrivals_unprioritized
  g.write('defect_arrivals.png')

  html = "<html>\n"
  html << "  <head>\n"
  html << "    <link rel=\"stylesheet\" type=\"text/css\" href=\"style.css\">\n"
  html << "    <title>Defect Arrivals</title>\n"
  html << "  </head>\n"
  html << "  <body>\n"
  html << "    <h1>Defect Arrivals - #{Time.now.strftime("%Y/%m/%d %H:%M")}</h1>\n"
  html << "    <img src=\"defect_arrivals.png\">\n"
  html << "  </body>\n"
  html << "</html>\n"

  File.open("defect_arrivals.html", 'w') { |file| file.write(html) }
end

puts "Building Defect List"
defects = build_defect_list()
puts "Creating Active Defect Report"
active_defect_status(defects)
puts "Creating All Defect Report"
all_defect_status(defects)
puts "Building Backlog Graph"
build_backlog_graph(defects)
puts "Building Arrivals Graph"
build_arrivals_graph(defects)
