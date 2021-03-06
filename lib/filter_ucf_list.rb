class FilterUcfList
  attr_accessor :model_name, :output_directory

  def initialize(model_name, output_directory = nil)
    @model_name = model_name
    @output_directory = output_directory
  end

  # Rules to filter the special characters
  SPECIAL_CHARACTER_LISTS = /[?*{}\[\]]/

  # Print the special character ID's into the output directory
  def filter_id
    retrieve_name_columns.each do |name|
      next if name == "church_name"
      original_stdout = STDOUT.clone
      STDOUT.reopen(new_file(name), "w")
      special_character_records(name).each do |record| 
        puts "#{record.id}\n"
      end
      STDOUT.reopen(original_stdout)
      puts "Total number of ids for #{name}: #{special_character_records(name).count}"
    end
    single_ucf_file_lists
    remove_duplicate_entries
  end

  private

  # Fetch all the column attribute names from the table
  def fetch_columns
    raise "Model name can't be blank" if @model_name.nil?

    @model_name.attribute_names
  end

  # Retrieve the column attribute where like 'name'
  def retrieve_name_columns
    fetch_columns.grep /name/
  end

  # Retrieve the special character records from the model
  def special_character_records column_name
    @model_name.where(column_name.to_sym => SPECIAL_CHARACTER_LISTS)
  end

  # Validate the directory exists or not
  def valid_directory?
    File.directory?(output_directory_path)
  end

  # Create a new file named as current date and time
  def new_file name
    raise "Not a Valid Directory" unless valid_directory?

    file_name = "#{Time.now.strftime("%Y%m%d%H%M%S")}_#{name}.txt"
    "#{output_directory_path}#{file_name}"
  end

  # Set an output directory
  # If there is no ouput directory, then set the default
  # else check the trailing slash at the end of the directory
  def output_directory_path
    if @output_directory.nil?
      directory = File.join(Rails.root, 'script')
    else
      directory = File.join(@output_directory, "")
    end
    directory
  end

  def single_bad_ucf_file
    "#{output_directory_path}single_ucf_file_lists.txt"
  end

  # Merged all bad ucf file into single file in the output directory
  def single_ucf_file_lists
    File.open(single_bad_ucf_file, 'a') do |mergedfile|
      Dir.glob("#{output_directory_path}*name.txt").each do |file|
        File.foreach(file) do |line|
          mergedfile.write(line)
        end
      end
    end
  end

  # Remove duplicate entries from the merged text file
  def remove_duplicate_entries
    File.open("#{output_directory_path}unique_ucf_lists.txt", "w+") { |file|
      file.puts File.readlines(single_bad_ucf_file).uniq
    }
  end

end