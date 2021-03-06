task :extract_information_on_register_types,[:limit] => [:environment] do |t, args|
  file_for_warning_messages = "#{Rails.root}/log/register_type.log"
  FileUtils.mkdir_p(File.dirname(file_for_warning_messages))
  output_file = File.new(file_for_warning_messages, "w")
  start = Time.now
  output_file.puts start
  record_number = 0
  types = Hash.new
  types["PR"] = 0
  types["TR"] = 0
  types["PH"] = 0
  types["DW"] = 0
  types[""] = 0
  types[" "] = 0
  types["AT"] = 0
  types["BT"] = 0
  types["EX"] = 0
  p "#{Register.count} registers"

  Register.no_timeout.each do |register| 
    record_number = record_number + 1
    break if record_number == args.limit.to_i
    if types.keys.include?(register.register_type)
      register.freereg1_csv_files.each do |file|
        types[register.register_type]  = types[register.register_type] + file.freereg1_csv_entries.count
      end
    end
  end
  output_file.puts "Total registers,#{Register.count}"
  output_file.puts "Total files, #{Freereg1CsvFile.count}"
  output_file.puts "Total entries, #{Freereg1CsvEntry.count}"
  output_file.puts "Total records, #{SearchRecord.count}"
  types.each_pair do |key,value|
    output_file.puts "#{key}, #{value}"
  end
  output_file.puts Time.now 
  elapse = Time.now - start
  output_file.puts elapse
  output_file.close
  p "finished"
end
