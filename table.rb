class Table

  def initialize(columns)
    @columns = columns

    @column_data = []
    @columns.each {|column|
      case column
      when :abstract
        col_class = "abstract-col"
        col_title = "Abstract"
      when :age
        col_class = "age-col"
        col_title = "Age"
      when :description
        col_class = "description-col"
        col_title = "Description"
      when :impact
        col_class = "impact-col"
        col_title = "Impact"
      when :originator
        col_class = "originator-col"
        col_title = "Originator"
      when :prioritization
        col_class = "prioritization-col"
        col_title = "Prioritization"
      when :product
        col_class = "product-col"
        col_title = "Product"
      when :status
        col_class = "status-col"
        col_title = "Status"
      when :workitem
        col_class = "workitem-col"
        col_title = "Work Item"
      else
        raise "Invalid column name declared to table"
      end
      @column_data << [col_class,col_title]
    }
  end


  def get_html(defects)
    html = ""
    html << "    <table class=\"status-table\">\n"
    @column_data.each { |col_class,col_title|
      html << "      <col class=\"#{col_class}\" />\n"
    }
    html << "      <tr>\n"
    @column_data.each { |col_class,col_title|
      html << "        <th>#{col_title}</th>\n"
    }
    html << "      </tr>\n"
    defects.each do |defect|
      html << "      <tr>\n"
      @columns.each do |column|
        case column
        when :abstract
          data = "<b><a href=\"https://www.pivotaltracker.com/story/show/#{defect.id}\">#{defect.fields["abstract"]}</a></b>"
        when :age
          data = defect.age.to_s
        when :description
          data = defect.fields["description"]
        when :impact
          data = defect.fields["impact"]
        when :originator
          data = defect.fields["originator"]
        when :prioritization
          data = defect.get_priority_text
        when :product
          data = defect.fields["product"]
        when :status
          data = ""
          defect.comments.each do |comment|
            data << "<b>#{comment["status_time"].strftime("%m/%d/%Y")}</b> #{comment["status_update"]}<br />\n"
          end
        when :workitem
          data = defect.fields["work item"]
        else
          raise "Invalid column name declared to table"
        end
        html << "        <td>#{data}</td>\n"
      end
      html << "      </tr>\n"
    end
    html << "    </table>\n"
    return html
  end


  def get_row_html
  end

end

