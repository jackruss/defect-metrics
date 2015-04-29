class Table

  def initialize(columns)
    @columns = columns

    @column_data = []
    @columns.each {|column|
      col_label = column
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
      when :injected_in
        col_class = "injected-col"
        col_title = "Injected In"
      when :impact
        col_class = "impact-col"
        col_title = "Impact"
      when :opened_date
        col_class = "openeddate-col"
        col_title = "Date Opened"
      when :originator
        col_class = "originator-col"
        col_title = "Originator"
      when :prioritization
        col_class = "prioritization-col"
        col_title = "Prioritization"
      when :product
        col_class = "product-col"
        col_title = "Product"
      when :shipped_date
        col_class = "shippeddate-col"
        col_title = "Fix Shipped"
      when :status
        col_class = "status-col"
        col_title = "Status"
      when :workitem
        col_class = "workitem-col"
        col_title = "Work Item"
      else
        raise "Invalid column name declared to table"
      end
      @column_data << [col_label,col_class,col_title]
    }
    @defects = []
  end


  def add_defect_list(defects)
    @defects = defects
  end


  def add_defect(defect)
    @defects << defect
  end


  def get_html()
    html = ""
    html << "    <table class=\"status-table\">\n"
    @column_data.each { |col_label,col_class,col_title|
      html << "      <col class=\"#{col_class}\" />\n"
    }
    html << "      <tr>\n"
    @column_data.each { |col_label,col_class,col_title|
      html << "        <th class=\"#{col_class}\">#{col_title}</th>\n"
    }
    html << "      </tr>\n"
    @defects.each do |defect|
      html << "      <tr>\n"
      @column_data.each do |col_label,col_class,col_title|
        case col_label
        when :abstract
          data = "<b><a href=\"https://www.pivotaltracker.com/story/show/#{defect.id}\">#{defect.fields["abstract"]}</a></b>"
        when :age
          data = defect.age.to_s
        when :description
          data = defect.fields["description"]
        when :impact
          data = defect.fields["impact"]
        when :injected_in
          data = defect.fields["injected_in"]
        when :opened_date
          data = defect.opened_date.strftime("%m/%d/%Y")
        when :originator
          data = defect.fields["originator"]
        when :prioritization
          data = defect.get_priority_text
        when :product
          data = defect.product
        when :shipped_date
          if defect.shipped_date
            data = defect.shipped_date.strftime("%m/%d/%Y")
          else
            data = ""
          end
        when :status
          data = ""
          defect.comments.each do |comment|
            data << "<b>#{comment["status_time"].strftime("%m/%d/%Y")}</b> #{comment["status_update"]}<br />\n"
          end
        when :workitem
          data = defect.fields["work item"]
        else
          raise "Bad column data (coding error)"
        end
        if defect.shipped_date
          inactive_data = " inactive-data"
        else
          inactive_data = ""
        end
        html << "        <td class=\"#{col_class}#{inactive_data}\">#{data}</td>\n"
      end
      html << "      </tr>\n"
    end
    html << "    </table>\n"
    return html
  end


  def get_row_html
  end

end

