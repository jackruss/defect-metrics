require 'json'
require 'time'
require './defect'
require './table'
require './tools'

def add_to_table(output,table)
  #puts output
  story_data = JSON.parse(output)
  story_data.each do |story|

    puts "Reading story #{story["id"]}: #{story["name"]}"

    unless story["name"] =~ /QA Defect Template/
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

      template_fields = ["ABSTRACT","DESCRIPTION","IMPACT","PRODUCT","ORIGINATOR","DETAILS","OPENED","INJECTED_IN"]
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

      ##### THIS IS NO LONGER USED.  WE USE LABELS INSTEAD
      ##
      ##  # Parse the product name
      ##  case defect.fields["product"]
      ##    when /[Ee](irene)?[Oo][Mm]/
      ##      defect.product = "EireneOM"
      ##    when /[Ee]irene[Rr][Xx]/
      ##      defect.product = "EireneRx"
      ##    when /[Ii]nter[Oo][Pp][Ss]/
      ##      defect.product = "InterOps"
      ##    else
      ##      defect.product = "Unknown"
      ##  end

      # Compute age
      if defect.fields["opened"]
        date_text = Tools.pluck("(([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])).*",defect.fields["opened"])
        defect.opened_date = Time.parse(date_text)
      end
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

      # Determine priority
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

      # Determine product
      if defect.fields["labels"]["eirenerx"]
        defect.product = "EireneRx"
      elsif defect.fields["labels"]["eom"]
        defect.product = "EOM"
      elsif defect.fields["labels"]["interops"]
        defect.product = "InterOps"
      else
        defect.product = "Unknown"
      end

      # Parse the comments
      story["comments"].each do |comment|
        if comment["text"] =~ /STATUS: /i
          this_comment = Hash.new
          status_update = comment["text"].gsub(/.*STATUS: /i,"")
          this_comment["status_update"] = status_update
          status_time = Time.at(comment["created_at"] / 1000)
          this_comment["status_time"] = status_time
          defect.comments << this_comment
        end
        if comment["text"] =~ /ACCEPTED: /i
          accepted_text = comment["text"].gsub(/.*ACCEPTED: /i,"")
          defect.accepted_date = Time.parse(accepted_text) + 86400 - 3602 # add 22:59:58
          defect.comments.each do |a_comment|
            if a_comment["status_update"] == "Fix accepted by QA."
              a_comment["status_time"] = defect.accepted_date
            end
          end
        end
        if comment["text"] =~ /SHIPPED: /i
          shipped_text = comment["text"].gsub(/.*SHIPPED: /i,"")
          defect.shipped_date = Time.parse(shipped_text) + 86400 - 3601 # add 22:59:59
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
  html = print_page_header("Active Defect Status")
  html << "    <h1>Active Defect Status - #{Time.now.strftime("%Y/%m/%d %H:%M")}</h1>\n"
  html << "    <p>All defects in this report impact GA products.  The data presented here is updated hourly from the live Pivotal Tracker data.</p>\n"

  html << "    <h2>Active Defect Backlog by Priority</h2>\n"
  html << print_defect_status_count_table()
  html << "    <br />\n"

  html << "    <h2>Active Defects</h2>\n"
  html << "    <p>Defects are listed in priority order, as determined by QA and via the weekly bug scrub.  Hyperlinks in the \"Abstract\" column will take you directly to the associated Pivotal Tracker story for each defect.</p>\n"
  active_defect_status = Table.new([:abstract,:workitem,:product,:description,:impact,:age,:prioritization,:status])
  priority_table = defects.sort_by { |defect| [defect.get_priority_value,defect.age] }
  priority_table.each {|defect|
    active_defect_status.add_defect(defect) unless defect.shipped_date
  }
  html << active_defect_status.get_html()

  html << print_page_footer
  File.open("output/defect_status.html", 'w') { |file| file.write(html) }
end


def all_defect_info(defects)
  html = print_page_header("All Defect Info")
  html << "    <h1>All Defect Information - #{Time.now.strftime("%Y/%m/%d %H:%M")}</h1>\n"
  html << "    <p>All defects in this report impact GA products.  The data presented here is updated hourly from the live Pivotal Tracker data.  Defects are sorted by origination date, from newest to oldest.  Resolved defects are grayed out.  Hyperlinks in the \"Abstract\" column will take you directly to the associated Pivotal Tracker story for each defect.</p>\n"
  all_defect_info = Table.new([:product,:workitem,:abstract,:description,:impact,:opened_date,:shipped_date,:injected_in,:prioritization,:originator,:status])
  sorted_defect_list = defects.sort_by { |defect| [defect.opened_date] }.reverse
  all_defect_info.add_defect_list(sorted_defect_list)
  html << all_defect_info.get_html()

  html << print_page_footer
  File.open("output/all_defect_info.html", 'w') { |file| file.write(html) }
end


def weekly_defect_status(defects)

  html = print_page_header("Weekly Defect Update")
  html << "    <h1>Weekly Defect Update - #{Time.now.strftime("%Y/%m/%d %H:%M")}</h1>\n"
  html << "    <p>All defects in this report impact GA products.  This data is available online <b><a href=\"http://inet/wp-content/uploads/2013/02/weekly_defect_update.html\">here</a></b> and is updated hourly from the live Pivotal Tracker data.</p>\n"

  # Outstanding high priority defects
  html << "    <h2>Outstanding high-priority defects</h2>\n"
  opened_this_week = Table.new([:abstract,:workitem,:product,:description,:impact,:age,:prioritization,:status])
  sorted_defect_list = defects.sort_by { |defect| [defect.get_priority_value,defect.age] }
  chart_time = Time.now
  sorted_defect_list.each {|defect|
    opened_this_week.add_defect(defect) if !defect.shipped_date and ((defect.priority == :critical) or (defect.priority == :major))
  }
  html << opened_this_week.get_html()
  html << "<br /><br />"

  # New defects in the past 7 days
  html << "    <h2>Defects opened in the past 7 days</h2>\n"
  opened_this_week = Table.new([:abstract,:workitem,:product,:description,:impact,:age,:prioritization,:status])
  sorted_defect_list = defects.sort_by { |defect| [defect.opened_date] }.reverse
  chart_time = Time.now
  sorted_defect_list.each {|defect|
    opened_this_week.add_defect(defect) unless defect.opened_date + (7*24*60*60) < chart_time
  }
  html << opened_this_week.get_html()
  html << "<br /><br />"


  # Defects with fixes shipped in the past 7 days
  html << "    <h2>Defect fixes shipped in the past 7 days</h2>\n"
  shipped_this_week = Table.new([:abstract,:workitem,:product,:description,:impact,:age,:prioritization,:status])
  sorted_defect_list = defects.sort_by { |defect| [defect.get_priority_value] }
  chart_time = Time.now
  sorted_defect_list.each {|defect|
    shipped_this_week.add_defect(defect) unless !defect.shipped_date or (defect.shipped_date + (7*24*60*60) < chart_time)
  }
  html << shipped_this_week.get_html()
  html << "<br /><br />"

  # Defects with fixes ready for shipment
  html << "    <h2>Defect fixes ready for shipment</h2>\n"
  ready_to_ship = Table.new([:abstract,:workitem,:product,:description,:impact,:age,:prioritization,:status])
  sorted_defect_list = defects.sort_by { |defect| [defect.get_priority_value] }
  sorted_defect_list.each {|defect|
    ready_to_ship.add_defect(defect) unless defect.shipped_date or !defect.accepted_date
  }
  html << ready_to_ship.get_html()

  html << print_page_footer
  File.open("output/weekly_defect_update.html", 'w') { |file| file.write(html) }
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
  g.write('output/defect_backlog.png')

  html = "<html>\n"
  html << "  <head>\n"
  html << "    <link rel=\"stylesheet\" type=\"text/css\" href=\"style.css\">\n"
  html << "    <title>Defect Backlog</title>\n"
  html << "  </head>\n"
  html << "  <body>\n"
  html << "    <h1>Defect Backlog - #{Time.now.strftime("%Y/%m/%d %H:%M")}</h1>\n"
  html << "    <p>This graph shows the backlog of open defects products over time, grouped by priority.  Only defects against GA products are displayed.</p>\n"
  html << "    <img src=\"defect_backlog.png\">\n"
  html << "  </body>\n"
  html << "</html>\n"

  File.open("output/defect_backlog.html", 'w') { |file| file.write(html) }
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
  g.write('output/defect_arrivals.png')

  html = "<html>\n"
  html << "  <head>\n"
  html << "    <link rel=\"stylesheet\" type=\"text/css\" href=\"style.css\">\n"
  html << "    <title>Defect Arrivals</title>\n"
  html << "  </head>\n"
  html << "  <body>\n"
  html << "    <h1>Defect Arrivals - #{Time.now.strftime("%Y/%m/%d %H:%M")}</h1>\n"
  html << "    <p>This graph shows defect arrivals per week, grouped by priority.  Only defects against GA products are displayed.</p>\n"
  html << "    <img src=\"defect_arrivals.png\">\n"
  html << "  </body>\n"
  html << "</html>\n"

  File.open("output/defect_arrivals.html", 'w') { |file| file.write(html) }
end

puts "Building Defect List"
defects = build_defect_list()
puts "Creating Active Defect Report"
active_defect_status(defects)
puts "Creating All Defect Report"
all_defect_info(defects)
puts "Building Weekly Defect Status"
weekly_defect_status(defects)
puts "Building Backlog Graph"
build_backlog_graph(defects)
puts "Building Arrivals Graph"
build_arrivals_graph(defects)
