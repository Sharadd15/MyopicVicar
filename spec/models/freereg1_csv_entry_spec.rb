require 'spec_helper'
require 'record_type'
require 'freereg_csv_processor'
require 'pp'

RSpec::Matchers.define :be_in_result do |entry|
  match do |results|
    found = false
    results.each do |record|
      found = true if record.line_id == entry[:line_id]
    end
    found    
  end
end


describe Freereg1CsvEntry do



  before(:each) do
    FreeregCsvProcessor::delete_all
  end



  it "should create the correct number of entries" do
    Freereg1CsvFile.count.should eq(0)
    Freereg1CsvEntry.count.should eq(0)
    SearchRecord.count.should eq(0)
    FREEREG1_CSV_FILES.each_with_index do |file, index|
#      puts "Testing #{file[:filename]}"
      FreeregCsvProcessor.process(file[:filename])      
      record = Freereg1CsvFile.where(:file_name => File.basename(file[:filename])).first 
  
      record.freereg1_csv_entries.count.should eq(file[:entry_count])     
    end
  end

  it "should parse each entry correctly" do
    FREEREG1_CSV_FILES.each_with_index do |file, index|
#      puts "Testing #{file[:filename]}"
      FreeregCsvProcessor.process(file[:filename])      
      file_record = Freereg1CsvFile.where(:file_name => File.basename(file[:filename])).first 

      ['first', 'last'].each do |entry_key|
#        print "\n\t Testing #{entry_key}\n"
        entry = file_record.freereg1_csv_entries.asc(:file_line_number).send entry_key
        entry.should_not eq(nil)        
#        pp entry
        
        standard = file[:entries][entry_key.to_sym]
#        pp standard
        standard.keys.each do |key|
          standard_value = standard[key]
          entry_value = entry.send key
#          entry_value.should_not eq(nil)
          entry_value.should eq(standard_value)
        end

      end
    end
  end

  it "should create search records for baptisms" do
    FREEREG1_CSV_FILES.each_with_index do |file, index|
      next unless file[:type] == RecordType::BAPTISM
      puts "Testing searches on #{file[:filename]}. SearchRecord.count=#{SearchRecord.count}"
      FreeregCsvProcessor.process(file[:filename])      
 
      ['first', 'last'].each do |entry_key|
        entry = file[:entries][entry_key.to_sym]

#
#        unless entry[:mother_forename].blank?
#          q = SearchQuery.create!(:first_name => entry[:mother_forename],
#                                  :last_name => entry[:mother_surname]||entry[:father_surname],
#                                  :inclusive => true)
#          result = q.search
#          
#          result.count.should have_at_least(1).items
#          result.should be_in_result(entry)
#  
#        end


        check_record(entry, :father_forename, :father_surname, false)
        check_record(entry, :mother_forename, :mother_surname, false)
        check_record(entry, :person_forename, :father_surname, true)

      end
    end
  end

  it "should create search records for burials" do
    Freereg1CsvEntry.count.should eq(0)
    FREEREG1_CSV_FILES.each_with_index do |file, index|
      next unless file[:type] == RecordType::BURIAL
      FreeregCsvProcessor.process(file[:filename])      
 
      ['first', 'last'].each do |entry_key|
        entry = file[:entries][entry_key.to_sym]
 #       pp entry
        
        check_record(entry, :male_relative_forename, :relative_surname, false)
        check_record(entry, :female_relative_forename, :relative_surname, false)
        check_record(entry, :burial_person_forename, :burial_person_surname, true)

      end
    end
  end


  it "should create search records for marriages" do
    Freereg1CsvEntry.count.should eq(0)
    FREEREG1_CSV_FILES.each_with_index do |file, index|
      next unless file[:type] == RecordType::MARRIAGE
#
      FreeregCsvProcessor.process(file[:filename])      
 
      ['first', 'last'].each do |entry_key|
        entry = file[:entries][entry_key.to_sym]
        
        check_record(entry, :bride_forename, :bride_surname, true)
        check_record(entry, :groom_forename, :groom_surname, true)

        check_record(entry, :bride_father_forename, :bride_father_surname, false)
        check_record(entry, :groom_father_forename, :groom_father_surname, false)
        binding.pry
        
        # check types and counties
        check_record(entry, :groom_forename, :groom_surname, true, { :record_type => RecordType::MARRIAGE})
        check_record(entry, :groom_forename, :groom_surname, true, { :record_type => RecordType::BURIAL}, false)
        check_record(entry, :groom_forename, :groom_surname, true, { :chapman_code => file[:county]})
        check_record(entry, :groom_forename, :groom_surname, true, { :chapman_code => 'BOGUS'}, false)
      end
    end
  end

  it "should not create duplicate names" do
    [
      "#{Rails.root}/test_data/freereg1_csvs/artificial/double_latinization.csv",
      "#{Rails.root}/test_data/freereg1_csvs/artificial/multiple_expansions.csv"
    ].each do |filename|

      file_record = FreeregCsvProcessor.process(filename)      
      file_record.freereg1_csv_entries.count.should eq 1
      entry = file_record.freereg1_csv_entries.first
      search_record = entry.search_record
      names = search_record.inclusive_names
      seen = {}
      names.each do |name|
        key = [name.first_name, name.last_name]
        seen[key].should be nil
        seen[key] = key
      end
    end    
  end


  def check_record(entry, first_name_key, last_name_key, required, additional={}, should_find=true)
    unless entry[first_name_key].blank? ||required
      query_params = additional.merge({:first_name => entry[first_name_key],
                                 :last_name => entry[last_name_key],
                                 :inclusive => !required})
      q = SearchQuery.create!(query_params)
      result = q.search
      # print "\n\tSearching key #{first_name_key}\n"
      # print "\n\tQuery:\n"
      # pp q.attributes
      # print "\n\tResults:\n"
      # result.each { |r| pp r.attributes}
      if should_find
        result.count.should have_at_least(1).items
        result.should be_in_result(entry)
      else
        result.should_not be_in_result(entry)            
      end
    end    
  end


end
