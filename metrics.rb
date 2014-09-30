require 'json'
require 'time'

def add_to_table(output,table)
  #puts output
  story_data = JSON.parse(output)
  story_data.each do |story|
    row = Hash.new
    row["id"] = story["id"]

    # Get the created at timestamp
    row["created_at"] = Time.at(story["created_at"] / 1000)

    # Parse the PT name text
    name_text = story["name"]

    if name_text =~ /TI[0-9]+: /
      workitem_text = name_text.gsub(/: .*/,"")
      row["work item"] = workitem_text
    end


    # Parse the PT description text
    string_to_parse = story["description"]

    template_fields = ["ABSTRACT","DESCRIPTION","IMPACT","PRODUCT","ORIGINATOR","DETAILS","OPENED"]
    splitstring = "%%%JMR%PARSE%HERE%%%"
    template_fields.each do |template_field|
      string_to_parse = string_to_parse.gsub(/#{template_field}: /,"#{splitstring}#{template_field}: ")
      string_to_parse = string_to_parse.gsub(/\n*#{splitstring}/,"#{splitstring}")
    end
    string_to_parse = string_to_parse.gsub(/\n/,"<br />")
    field_array = string_to_parse.split(/#{splitstring}/)
    template_fields.each do |template_field|
      field_array.each do |entry|
        if entry =~ /#{template_field}: /
          row[template_field.downcase] = entry.gsub("#{template_field}: ","")
        end
      end
    end

    # Overwrite abstract if specified (otherwise pull from the story title)
    unless row["abstract"]
      abstract_text = name_text.gsub(/TI.....: /,"")
      row["abstract"] = abstract_text
    end

    # Compute age
    opened_date = row["created_at"]
    opened_date = Time.parse(row["opened"]) if row["opened"]
    current_date = Time.now
    row["age"] = (current_date - opened_date).to_i / (24 * 60 * 60)

    # Parse the current_state
    row["state"] = story["current_state"]

    # Parse the labels
    labels = Hash.new
    story["labels"].each do |label|
      labels[label["name"]] = true
    end
    row["labels"] = labels

    if row["labels"]["new"]
      row["priority text"] = "Not yet prioritized"
      row["priority value"] = 10
    elsif row["labels"]["critical"]
      row["priority text"] = "Critical - ASAP"
      row["priority value"] = 1
    elsif row["labels"]["major"]
      row["priority text"] = "Major - Next Sprint"
      row["priority value"] = 2
    elsif row["labels"]["moderate"]
      row["priority text"] = "Moderate - Earliest Possible Roadmap Item"
      row["priority value"] = 3
    elsif row["labels"]["minor"]
      row["priority text"] = "Minor - To Be Assessed"
      row["priority value"] = 4
    else
      row["priority text"] = "Not yet prioritized"
      row["priority value"] = 10
    end

    # Parse the comments
    row["comments"] = []
    story["comments"].each do |comment|
      if comment["text"] =~ /STATUS: /
        this_comment = Hash.new
        status_update = comment["text"].gsub(/.*STATUS: /,"")
        this_comment["status_update"] = status_update
        status_time = Time.at(comment["created_at"] / 1000)
        this_comment["status_time"] = status_time
        row["comments"] << this_comment
      end
    end

    table << row

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
              curl -X GET -H "X-TrackerToken: #{ENV["PT_TOKEN"]}" "https://www.pivotaltracker.com/services/v5/projects/$PROJECT_ID/stories?fields=name,created_at,current_state,description,comments,labels&date_format=millis&filter=label%3Aqa_metric"`
    add_to_table(output,table)
  end
  return table
end


def print_compact_table()
end

def print_compact_table_header()
  html = ""
  html << "      <col class=\"abstract-col\" />\n"
  html << "      <col class=\"id-col\" />\n"
  html << "      <col class=\"description-col\" />\n"
  html << "      <col class=\"impact-col\" />\n"
  html << "      <col class=\"age-col\" />\n"
  html << "      <col class=\"prioritization-col\" />\n"
  html << "      <col class=\"status-col\" />\n"
  html << "      <tr>\n"
  html << "        <th>Abstract</th>\n"
  html << "        <th>Work Item</th>\n"
  html << "        <th>Description</th>\n"
  html << "        <th>Impact</th>\n"
  html << "        <th>Age</th>\n"
  html << "        <th>Prioritization</th>\n"
  html << "        <th>Status</th>\n"
  html << "      </tr>\n"
  return html
end


def print_compact_table_row(row)
      html = ""
      html << "      <tr>\n"
      html << "        <td><b><a href=\"https://www.pivotaltracker.com/story/show/#{row["id"]}\">#{row["abstract"]}</a></b></td>\n"
      html << "        <td>#{row["work item"]}</td>\n"
      html << "        <td>#{row["description"]}</td>\n"
      html << "        <td>#{row["impact"]}</td>\n"
      html << "        <td>#{row["age"]}</td>\n"
      html << "        <td>#{row["priority text"]}</td>\n"
      html << "        <td>\n"
      row["comments"].each do |comment|
        html << "<b>#{comment["status_time"].strftime("%m/%d/%Y")}</b> #{comment["status_update"]}<br />\n"
      end
      html << "</td>\n"
      html << "      </tr>\n"
      return html
end


def active_defect_status(defects)
  priority_table = defects.sort_by { |row| [row["priority value"],row["age"]] }

  html = "<html>\n"
  html << "  <head>\n"
  html << "    <link rel=\"stylesheet\" type=\"text/css\" href=\"style.css\">\n"
  html << "    <title>Defect Status</title>\n"
  html << "  </head>\n"
  html << "  <body>\n"
  html << "    <h1>Active Defect Status - #{Time.now.strftime("%Y/%m/%d %H:%M")}</h1>\n"
  html << "    <table class=\"defect-counts\">\n"
  html << "      <tr>\n"
  html << "      <th>Priority</th>\n"
  html << "      <th>Defects</th>\n"
  html << "      </tr>\n"
  html << "      <tr>\n"
  html << "      <td>Critical</td>\n"
  html << "      <td>#{}</td>\n"
  html << "      </tr>\n"
  html << "      <tr>\n"
  html << "      <td>Major</td>\n"
  html << "      <td>#{}</td>\n"
  html << "      </tr>\n"
  html << "      <tr>\n"
  html << "      <td>Moderate</td>\n"
  html << "      <td>#{}</td>\n"
  html << "      </tr>\n"
  html << "      <tr>\n"
  html << "      <td>Minor</td>\n"
  html << "      <td>#{}</td>\n"
  html << "      </tr>\n"
  html << "      <tr>\n"
  html << "      <td>Unprioritized</td>\n"
  html << "      <td>#{}</td>\n"
  html << "      </tr>\n"
  html << "    </table>\n"
  html << "    <br />\n"
  html << "    <p>Defects are listed in priority order, as determined by QA and via the weekly bug scrub.</p>\n"
  html << "    <table class=\"compact-table\">\n"
  html << print_compact_table_header()
  priority_table.each do |row|
    unless row["state"] == "accepted" 
      html << print_compact_table_row(row)
    end
  end
  html << "    </table>\n"
  html << "  </body>\n"
  html << "</html>\n"

  File.open("defect_status.html", 'w') { |file| file.write(html) }
end

def all_defect_status(defects)
  priority_table = defects.sort_by { |row| [row["priority value"],row["age"]] }

  html = "<html>\n"
  html << "  <head>\n"
  html << "    <link rel=\"stylesheet\" type=\"text/css\" href=\"style.css\">\n"
  html << "    <title>All Defect Status</title>\n"
  html << "  </head>\n"
  html << "  <body>\n"
  html << "    <h1>Defect Status - #{Time.now.strftime("%Y/%m/%d %H:%M")}</h1>\n"
  html << "    <p>Defects are listed in priority order, as determined by QA and via the weekly bug scrub.</p>\n"
  html << "    <table>\n"
  html << "      <col class=\"product-col\" />\n"
  html << "      <col class=\"id-col\" />\n"
  html << "      <col class=\"abstract-col\" />\n"
  html << "      <col class=\"description-col\" />\n"
  html << "      <col class=\"impact-col\" />\n"
  html << "      <col class=\"age-col\" />\n"
  html << "      <col class=\"prioritization-col\" />\n"
  html << "      <col class=\"originator-col\" />\n"
  html << "      <col class=\"status-col\" />\n"
  html << "      <tr>\n"
  html << "        <th>Product</th>\n"
  html << "        <th>Work Item</th>\n"
  html << "        <th>Abstract</th>\n"
  html << "        <th>Description</th>\n"
  html << "        <th>Impact</th>\n"
  html << "        <th>Age</th>\n"
  html << "        <th>Prioritization</th>\n"
  html << "        <th>Originator</th>\n"
  html << "        <th>Status</th>\n"
  html << "      </tr>\n"
  priority_table.each do |row|
    html << "      <tr>\n"
    html << "        <td><b><a href=\"https://www.pivotaltracker.com/story/show/#{row["id"]}\">#{row["abstract"]}</a></b></td>\n"
    html << "        <td>#{row["work item"]}</td>\n"
    html << "        <td>#{row["product"]}</td>\n"
    html << "        <td>#{row["abstract"]}</td>\n"
    html << "        <td>#{row["description"]}</td>\n"
    html << "        <td>#{row["impact"]}</td>\n"
    html << "        <td>#{row["age"]}</td>\n"
    html << "        <td>#{row["priority text"]}</td>\n"
    html << "        <td>#{row["originator"]}</td>\n"
    html << "        <td>\n"
    row["comments"].each do |comment|
      html << "<b>#{comment["status_time"].strftime("%m/%d/%Y")}</b> #{comment["status_update"]}<br />\n"
    end
    html << "</td>\n"
    html << "      </tr>\n"
  end
  html << "    </table>\n"
  html << "  </body>\n"
  html << "</html>\n"

  File.open("all_defect_status.html", 'w') { |file| file.write(html) }
end

def build_backlog_graph
  require 'gruff'
  g = Gruff::StackedArea.new
  g.title = "Defect Arrivals"
  g.colors = ["#FF0000", "#FFC000", "#FFFF00", "#2F5597", "#D9D9D9"]
  g.labels = { 0 => '5/6', 1 => '5/15', 2 => '5/24', 3 => '5/30', 4 => '6/4',
               5 => '6/12', 6 => '6/21', 7 => '6/28' }
  g.data :Critical, [25, 36, 86, 39, 25, 31, 79, 88]
  g.data :Major, [80, 54, 67, 54, 68, 70, 90, 95]
  g.data :Moderate, [22, 29, 35, 38, 36, 40, 46, 57]
  g.data :Minor, [95, 95, 95, 90, 85, 80, 88, 100]
  g.data :Unprioritized, [90, 34, 23, 12, 78, 89, 98, 88]
  g.write('arrivals.png')
end

puts "Building Defect List"
defects = build_defect_list()
puts "Creating Active Defect Report"
active_defect_status(defects)
puts "Creating All Defect Report"
all_defect_status(defects)
