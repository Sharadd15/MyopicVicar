class LoadFilesIntoUseridDetails
  require 'chapman_code'
  require 'userid_detail'
  require 'freereg1_csv_file'
  require 'attic_file'
  require 'get_files'
  require 'digest/md5'
 
  def self.process(len,type,fr)
    file_for_warning_messages = "log/load_files_into_userid_details.log"
    FileUtils.mkdir_p(File.dirname(file_for_warning_messages) )  unless File.exists?(file_for_warning_messages)
    @@message_file = File.new(file_for_warning_messages, "w")
    Mongoid.load!("#{Rails.root}/config/mongoid.yml")
    puts "Loading files into useris_details and into attic files collection"
    #extract range of userids
    base_directory = Rails.application.config.datafiles if fr.to_i == 2
    base_directory = Rails.application.config.datafiles_changeset if fr.to_i == 1
    
    len =len.to_i
    #process files
    if type == "files" || type == "both"
      count = 0
      users = UseridDetail.all.order_by(userid_lower_case: 1)
      users.each do |user|
        count = count + 1
        break if count == len
         userid = user.userid
         unless userid.nil?
           pattern = File.join(base_directory,userid,"*.csv")
           files = Dir.glob(pattern, File::FNM_CASEFOLD).sort
           if files.nil?
            @@message_file.puts "#{userid}, has,0, files "
           else
            @@message_file.puts "#{userid}, has ,#{files.length}, files "
            files.each do |file|
               file_parts = file.split("/")
               file_name = file_parts[-1]
               if Freereg1CsvFile.where(:file_name => file_name, :userid => userid,).exists?
                my_file = Freereg1CsvFile.where(:file_name => file_name, :userid => userid).first
                existing_files = user.freereg1_csv_files
                  if existing_files.include?(my_file)
                    @@message_file.puts "#{userid}, has file,#{file_name}, already there "
                  else
                    user.freereg1_csv_files << my_file 
                    @@message_file.puts "#{userid}, has file,#{file_name}, added " 
                  end
               else
                @@message_file.puts "#{userid}, has file,#{file_name}, not processed "
               end 
             end
             user.save
           end
         end
      end
    end
    #process csv in attic
    if type == "attic" || type == "both"
      count = 0
      users = UseridDetail.all.order_by(userid_lower_case: 1)
      users.each do |user|
        count = count + 1
        break if count == len
         userid = user.userid
         unless userid.nil?
           pattern = File.join(base_directory,userid,".attic/*.csv.*")
           files = Dir.glob(pattern, File::FNM_CASEFOLD).sort
           if files.nil?
            @@message_file.puts "#{userid}, has ,0, attic files "
           else
            @@message_file.puts "#{userid}, has ,#{files.length}, attic files "
            files.each do |file|
              file_parts = file.split("/")
              date = file_parts[-1].split(".")
              date[2] = date[2].gsub(/\D/,"")
              date_file = DateTime.strptime(date[2],'%s') unless date[2].nil?
              if AtticFile.where(:name => file_parts[-1],:date_created => date_file,:userid => userid).exists?
               @@message_file.puts "#{userid}, has attic cdv file ,#{file_parts[-1]}, existing "  
              else
                attic_file =  AtticFile.new(:name => file_parts[-1],:date_created => date_file,:userid => userid)
                user.attic_files << attic_file
                @@message_file.puts "#{userid}, has attic file ,#{file_parts[-1]}, added "
              end 
             end
             user.save
           end
         end
      end
    end
    #process udetails in attic 
    if type == "attic" || type == "both"
      count = 0
      users = UseridDetail.all.order_by(userid_lower_case: 1)
      users.each do |user|
        count = count + 1
        break if count == len
         userid = user.userid
         unless userid.nil?
           pattern = File.join(base_directory,userid,".attic/.uDetails.*")
           files = Dir.glob(pattern, File::FNM_CASEFOLD).sort
           if files.nil?
            @@message_file.puts "#{userid}, has ,0, attic uDetails "
           else
            @@message_file.puts "#{userid}, has ,#{files.length}, attic uDetails "
            files.each do |file|
              file_parts = file.split("/")
              date = file_parts[-1].split(".")
              date[2] = date[2].gsub(/\D/,"")
              date_file = DateTime.strptime(date[2],'%s') unless date[2].nil?
              if AtticFile.where(:name => file_parts[-1],:date_created => date_file,:userid => userid).exists?
               @@message_file.puts "#{userid}, has attic uDetails ,#{file_parts[-1]}, existing "  
              else
                attic_file =  AtticFile.new(:name => file_parts[-1],:date_created => date_file,:userid => userid)
                 user.attic_files << attic_file
                @@message_file.puts "#{userid}, has attic uDetails ,#{file_parts[-1]}, added " 
              end
             end
             user.save
           end
         end
      end
    end     
  end #end process
end
