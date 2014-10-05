class Defect

  attr_writer :fields, 
    :age,
    :accepted_date,
    :comments,
    :id,
    :opened_date,
    :priority,
    :shipped_date
  attr_reader :fields, 
    :age,
    :accepted_date,
    :comments,
    :id,
    :opened_date,
    :priority,
    :shipped_date

  @@all = []


  def initialize
    @id = nil
    @priority = nil
    @comments = []

    @opened_date = nil
    @accepted_date = nil
    @shipped_date = nil
    @age = nil

    @fields = Hash.new
  
    @@all << self
  end


  def get_priority_text
    case @priority
      when :unprioritized
        return "Not yet prioritized"
      when :critical
        return "Critical - ASAP"
      when :major
        return "Major - Next Sprint"
      when :moderate
        return "Moderate - Earliest Possible Roadmap Item"
      when :minor
        return "Minor - To Be Assessed"
    end
  end


  def get_priority_value
    case @priority
      when :unprioritized
        return 10
      when :critical
        return 1
      when :major
        return 2
      when :moderate
        return 3
      when :minor
        return 4
    end
  end


  def was_active?(date)
    if @opened_date <= date and (!@shipped_date or @shipped_date >= date)
      return true
    else
      return false
    end
  end


  def opened_between?(date1,date2)
    if @opened_date >= date1 and @opened_date < date2
      return true
    else
      return false
    end
  end


  def self.get_priority_count(priority)
    count = 0
    @@all.each { |defect|
      count += 1 if defect.priority == priority
    }
    count
  end

end
