class UserMailer < ActionMailer::Base
  if MyopicVicar::Application.config.template_set == 'freereg'
    default from: "reg-web@freereg.org.uk"
  elsif MyopicVicar::Application.config.template_set == 'freecen'
    default from: "cen-web@freecen.org.uk"
  end

  def batch_processing_success(user,batch,records,error,headers)
    @userid = UseridDetail.where(userid: user).first
    if @userid.present?
      @errors = error
      @headers = headers
      @records = records
      emails = Array.new
      unless @userid.nil? || !@userid.active
        user_email_with_name =  @userid.email_address    
        emails <<  user_email_with_name  
      end
      syndicate_coordinator = nil
      syndicate_coordinator = Syndicate.where(syndicate_code: @userid.syndicate).first
      if syndicate_coordinator.present?
        syndicate_coordinator = syndicate_coordinator.syndicate_coordinator
        sc = UseridDetail.where(userid: syndicate_coordinator).first
        if sc.present?
          sc_email_with_name =  sc.email_address
          emails << sc_email_with_name unless user_email_with_name == sc_email_with_name
        end
      end
      @batch = Freereg1CsvFile.where(file_name: batch, userid: user).first
      county = County.where(chapman_code: @batch.county).first unless @batch.nil?
      if county.present?
        county_coordinator = county.county_coordinator
        cc = UseridDetail.where(userid: county_coordinator).first
        if cc.present?
          cc_email_with_name =  cc.email_address
          emails << cc_email_with_name unless cc_email_with_name == sc_email_with_name
        end
      end
      if emails.length == 1
         mail(:to => emails[0],  :subject => "#{@userid.userid}/#{batch} was processed by FreeREG at #{Time.now}")
      elsif emails.length == 2
        mail(:to => emails[0], :cc => emails[1], :subject => "#{@userid.userid}/#{batch} was processed by FreeREG at #{Time.now}")
      elsif emails.length == 3
        first_mail = emails.shift
        mail(:to => first_mail, :cc => emails, :subject =>"#{@userid.userid}/#{batch} was processed by FreeREG at #{Time.now}") 
      end 
    end
  end

  def batch_processing_failure(message,user,batch)
    @message = message
    @userid = UseridDetail.where(userid: user).first
    if @userid.present?
      emails = Array.new
      unless @userid.nil? || !@userid.active
        user_email_with_name = @userid.email_address    
        emails <<  user_email_with_name  
      end
      syndicate_coordinator = nil
      syndicate_coordinator = Syndicate.where(syndicate_code: @userid.syndicate).first
      if syndicate_coordinator.present?
        syndicate_coordinator = syndicate_coordinator.syndicate_coordinator
        sc = UseridDetail.where(userid: syndicate_coordinator).first
        if sc.present?
          sc_email_with_name = sc.email_address
          emails << sc_email_with_name unless user_email_with_name == sc_email_with_name
        end
      end
      @batch = Freereg1CsvFile.where(file_name: batch, userid: user).first
      county = County.where(chapman_code: @batch.county).first unless @batch.nil?
      if county.present?
        county_coordinator = county.county_coordinator
        cc = UseridDetail.where(userid: county_coordinator).first
        if cc.present?
          cc_email_with_name = cc.email_address
          emails << cc_email_with_name unless cc_email_with_name == sc_email_with_name
        end
      end
      if emails.length == 1
         mail(:to => emails[0],  :subject => "#{@userid.userid}/#{batch} failed to be processed by FreeREG at #{Time.now}")
      elsif emails.length == 2
        mail(:to => emails[0], :cc => emails[1], :subject => "#{@userid.userid}/#{batch} failed to be processed by FreeREG at #{Time.now}")
      elsif emails.length == 3
        first_mail = emails.shift
        mail(:to => first_mail, :cc => emails, :subject => "#{@userid.userid}/#{batch} failed to be processed by FreeREG at #{Time.now}")
      end 
    end
  end

  def update_report_to_freereg_manager(file,user)
    appname = MyopicVicar::Application.config.freexxx_display_name
    attachments["report.log"] = File.read(file)
    @person_forename = user.person_forename
    @email_address = user.email_address
    mail(:to => "#{@person_forename} <#{@email_address}>", :subject => "#{appname} Update processing report")
  end

  def invitation_to_register_transcriber(user)
    appname = MyopicVicar::Application.config.freexxx_display_name
    @user = user
    get_coordinator_name
    get_token
    mail(:to => "#{@user.person_forename} <#{@user.email_address}>", :subject => "Invitation to complete #{appname} Registration")
  end

  def invitation_to_register_researcher(user)
    appname = MyopicVicar::Application.config.freexxx_display_name
    @user = user
    get_coordinator_name
    get_token
    mail(:to => "#{@user.person_forename} <#{@user.email_address}>", :subject => "Invitation to complete #{appname} Registration")
  end

  def invitation_to_register_technical(user)
    appname = MyopicVicar::Application.config.freexxx_display_name
    @user = user
    get_coordinator_name
    get_token
    mail(:to => "#{@user.person_forename} <#{@user.email_address}>", :subject => "Invitation to complete #{appname} Registration")
  end

  def invitation_to_reset_password(user)
    appname = MyopicVicar::Application.config.freexxx_display_name
    @user = user
    get_coordinator_name
    get_token
    mail(:to => "#{@user.person_forename} <#{@user.email_address}>", :subject => "Password Reset for #{appname}")
  end

  def notification_of_transcriber_creation(user)
    appname = MyopicVicar::Application.config.freexxx_display_name
    @user = user
    get_coordinator_name
    mail(:to => "#{@coordinator.person_forename} <#{@coordinator.email_address}>", :subject => "#{appname} Userid Creation") unless @coordinator.nil?
  end

  def notification_of_transcriber_registration(user)
    appname = MyopicVicar::Application.config.freexxx_display_name
    @user = user
    get_coordinator_name
    mail(:to => "#{@coordinator.person_forename} <#{@coordinator.email_address}>", :subject => "#{appname} Transcriber Registration") unless @coordinator.nil?
  end

  def notification_of_researcher_registration(user)
    appname = MyopicVicar::Application.config.freexxx_display_name
    @user = user
    get_coordinator_name
    mail(:to => "#{@coordinator.person_forename} <#{@coordinator.email_address}>", :subject => "#{appname} Research Registration") unless @coordinator.nil?
  end

  def notification_of_technical_registration(user)
    appname = MyopicVicar::Application.config.freexxx_display_name
    @user = user
    get_coordinator_name
    mail(:to => "#{@coordinator.person_forename} <#{@coordinator.email_address}>", :subject => "#{appname} Technical Registration notification") unless @coordinator.nil?
  end

  def notification_of_registration_completion(user)
    appname = MyopicVicar::Application.config.freexxx_display_name
    @user = user
    if MyopicVicar::Application.config.template_set == 'freereg'
      manager = UseridDetail.userid("REGManager").first
    elsif MyopicVicar::Application.config.template_set == 'freecen'
      manager = UseridDetail.userid("CENManager").first
    else
      manager = nil
    end
    get_coordinator_name
    if Time.now - 5.days <= @user.c_at
    mail(:to => "#{@coordinator.person_forename} <#{@coordinator.email_address}>", :subject => "#{appname} Registration Completion") unless @coordinator.nil?
    mail(:to => "#{manager.person_forename} <#{manager.email_address}>", :subject => "#{appname} Registration Completion") unless manager.nil?
    end
  end

  def reset_notification(user,z)
    user = UseridDetail.find(user.userid_detail_id)
    invitation_to_reset_password(user)
  end

  def get_coordinator_name
    coordinator = Syndicate.where(:syndicate_code => @user.syndicate).first
    if coordinator.nil?
      @coordinator = nil
    else
      coordinator = coordinator.syndicate_coordinator
      @coordinator = UseridDetail.where(:userid => coordinator).first
    end
  end

  def get_token
    refinery_user = Refinery::User.where(:username => @user.userid).first
    refinery_user.reset_password_token = Refinery::User.reset_password_token
    refinery_user.reset_password_sent_at = Time.now
    refinery_user.save!
    @user_token = refinery_user.reset_password_token
  end

  def copy_to_contact_person(contact)
    appname = MyopicVicar::Application.config.freexxx_display_name
    @contact = contact
    mail(:to => "#{@contact.name} <#{@contact.email_address}>", :subject => "Thank you for contacting us (#{appname})")
  end

  def contact_to_freexxx_manager(contact,person,ccs)
    appname = MyopicVicar::Application.config.freexxx_display_name
    @ccs = ccs
    @contact = contact
    @name = person.person_forename
    @email_address = person.email_address
    mail(:to => "#{@name} <#{@email_address}>", :subject => "Copy of a #{appname} Contact")
  end

  def contact_to_recipient(contact,person,ccs)
    appname = MyopicVicar::Application.config.freexxx_display_name
    @ccs = ccs
    @contact = contact
    @name = person.person_forename
    @email_address = person.email_address
    mail(:to => "#{@name} <#{@email_address}>", :subject => "Copy of a #{appname} Contact")
  end

  def contact_to_volunteer(contact,person,ccs)
    appname = MyopicVicar::Application.config.freexxx_display_name
    @ccs = ccs
    @contact = contact
    @name = person.person_forename
    @email_address = person.email_address
    mail(:to => "#{@name} <#{@email_address}>", :subject => "Copy of a #{appname} Contact")
  end

  def contact_to_data_manager(contact,person,ccs)
    appname = MyopicVicar::Application.config.freexxx_display_name
    @ccs = ccs
    @contact = contact
    @name = person.person_forename
    @email_address = person.email_address
    mail(:to => "#{@name} <#{@email_address}>", :subject => "Copy of a #{appname} Contact")
  end
  def contact_to_coordinator(contact,person,ccs)
    appname = MyopicVicar::Application.config.freexxx_display_name
    @ccs = ccs
    @contact = contact
    @name = person.person_forename
    @email_address = person.email_address
    mail(:to => "#{@name} <#{@email_address}>", :subject => "Data Error Report from a #{appname} contact")
  end
  def send_change_of_syndicate_notification_to_sc(user)
    appname = MyopicVicar::Application.config.freexxx_display_name
    @user = user
    get_coordinator_name
    mail(:to => "#{@coordinator.person_forename} <#{@coordinator.email_address}>", :subject => "#{appname}2 Change of Syndicate") unless @coordinator.blank?
  end
end
