class SiteStatistic
  include Mongoid::Document
  field :interval_end, type: DateTime
  field :year, type: Integer
  field :month, type: Integer
  field :day, type: Integer
  field :n_records, type: Integer
  field :n_records_marriages, type: Integer
  field :n_records_burials, type: Integer
  field :n_records_baptisms, type: Integer
  field :n_searches, type: Integer
  field :n_records_added, type: Integer
  field :n_records_added_marriages, type: Integer
  field :n_records_added_burials, type: Integer
  field :n_records_added_baptisms, type: Integer

  def self.calculate(time = Time.now)
    last_midnight = Time.new(time.year,time.month,time.day)
    
    # find the existing record if it exists
    stat = SiteStatistic.where(:interval_end => last_midnight).first
    if !stat
      stat = SiteStatistic.new
    end
    
    #populate it
    stat.interval_end = last_midnight
    stat.year = last_midnight.year
    stat.month = last_midnight.month
    stat.day = last_midnight.day    
    
    stat.n_records = SearchRecord.count
    stat.n_records_marriages = SearchRecord.marriages.count
    stat.n_records_burials = SearchRecord.burials.count
    stat.n_records_baptisms = SearchRecord.baptisms.count
    stat.n_searches = SearchStatistic.where(:year => stat.year, :month => stat.month, :day => stat.day).inject(0) { |accum, ss| accum += ss.n_searches }
    #find the previous one
    previous_stat = SiteStatistic.where(:interval_end => stat.interval_end - 1.day).first
    
    if previous_stat
      stat.n_records_added = stat.n_records - previous_stat.n_records
      stat.n_records_added_marriages = stat.n_records_marriages - previous_stat.n_records_marriages
      stat.n_records_added_burials = stat.n_records_burials - previous_stat.n_records_burials
      stat.n_records_added_baptisms = stat.n_records_baptisms - previous_stat.n_records_baptisms
    end
    
    stat.save!
  end

end
