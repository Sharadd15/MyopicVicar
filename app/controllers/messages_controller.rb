class MessagesController < ApplicationController
  require 'freereg_options_constants'
  require 'userid_role'
  require 'reply_userid_role'

  #skip_before_filter :require_login, only: [:show]

  def archive
    @message = Message.id(params[:id]).first
    if @message.present?
      @message.archive
      session[:archived_contacts] = true
      flash.notice = 'Message archived'
      return_after_archive(params[:source], params[:id])
    else
      go_back('message', params[:id])
    end
  end

  def create
    @message = Message.new(message_params)
    @message.file_name = @message.attachment_identifier
    case params[:commit]
    when 'Submit'
      if @message.subject.blank?
        @message.subject = '...'
        flash[:notice] = 'There was no subject for your message. You will have to reattach any file or image'
        render :new
      elsif @message.save
        flash[:notice] = 'Message created'
        return_for_create
      else
        flash[:notice] = 'There was a problem with your message, possibly you attached a file with an incorrect file type or an image as a file'
        redirect_to action: :new
      end
      return
    when 'Save & Send'
      if @message.save
        flash[:notice] = 'Reply created'
        params[:id] = @message.id if @message
        send_message
        redirect_to send_message_messages_path(@message.id) and return
      else
        redirect_to reply_messages_path(@message.source_message_id) and return
      end
    when 'Reply Feedback'
      if @message.save
        reply_for_feedback; return if performed?
      end
    when 'Reply Contact'
      if @message.save
        flash[:notice] = 'Reply for Contact is created and sent'
        reply_for_contact; return if performed?
      end
    when 'Reply Message'
      get_user_info_from_userid
      @message.syndicate = @user.syndicate if @message.add_syndicate?
      if @message.save
        flash[:notice] = 'Reply for Message is created and sent'
        reply_for_message(@message); return if performed?
      end
    end
  end

  def force_destroy
    @message = Message.id(params[:id]).first
    if @message.present?
      @message.destroy
      flash.notice = 'Message destroyed'
      return_after_destroy
      return
    else
      go_back('message',params[:id])
    end
  end

  def edit
    @message = Message.id(params[:id]).first
    if @message.blank?
      go_back('message',params[:id])
    end
  end


  def index
    get_user_info_from_userid
    session[:message_base] = 'general'
    session[:archived_contacts] = false
    @syndicate = session[:syndicate]
    order = 'message_time DESC'
    @messages = Message.list_messages(params[:action], @syndicate, session[:archived_contacts], order)
  end

  def keep
    @message = Message.id(params[:id]).first
    go_back('message', params[:id])  if @message.blank?
    session[:archived_contacts] = true
    @message.update_keep
    flash.notice = 'Message to be retained'
    return_after_keep(params[:source], params[:id])
  end

  def list_archived
    get_user_info_from_userid
    session[:message_base] = 'general'
    session[:archived_contacts] = true
    @syndicate = session[:syndicate]
    order = 'message_time DESC'
    @messages = Message.list_messages(params[:action], @syndicate, session[:archived_contacts], order)
    render :index
  end

  def list_by_name
    get_user_info_from_userid
    @syndicate = session[:syndicate]
    order = 'name ASC'
    @messages = Message.list_messages(params[:action],session[:syndicate],session[:archived_contacts],order)
    render :index
  end

  def list_feedback_reply_message
    get_user_info_from_userid
    order = 'message_time DESC'
    @messages = Message.list_messages(params[:action],session[:syndicate],session[:archived_contacts],order)
    render :index
  end

  def list_contact_reply_message
    get_user_info_from_userid
    order = 'message_time DESC'
    @messages = Message.list_messages(params[:action],session[:syndicate],session[:archived_contacts],order)
    render :index
  end

  def list_by_date
    get_user_info_from_userid
    @syndicate = session[:syndicate]
    order = 'message_time ASC'
    @messages = Message.list_messages(params[:action], session[:syndicate], session[:archived_contacts], order)
    render :index
  end

  def list_by_most_recent
    get_user_info_from_userid
    @syndicate = session[:syndicate]
    order = 'message_time DESC'
    @messages = Message.list_messages(params[:action], session[:syndicate], session[:archived_contacts], order)
    render :index
  end

  def list_syndicate_messages
    get_user_info_from_userid
    session[:archived_contacts] = false
    session[:message_base] = 'syndicate'
    @syndicate = session[:syndicate]
    order = 'message_time DESC'
    @messages = Message.list_messages(params[:action], session[:syndicate], session[:archived_contacts], order)
    render :index
  end

  def list_archived_syndicate_messages
    get_user_info_from_userid
    session[:archived_contacts] = true
    session[:message_base] = 'syndicate'
    @syndicate = session[:syndicate]
    order = 'message_time DESC'
    @messages = Message.list_messages(params[:action], session[:syndicate], session[:archived_contacts], order)
    render :index
  end

  def list_unsent_messages
    get_user_info_from_userid
    @syndicate = session[:syndicate]
    order = 'message_time DESC'
    @messages = Message.list_messages(params[:action],session[:syndicate],session[:archived_contacts],order)
    render :index
  end

  def new
    get_user_info_from_userid
    @message = Message.new
    session[:hold_source] = params[:source]
    @message.message_time = Time.now
    @message.userid = @user.userid
    set_message_syndicate
  end

  def remove_from_userid_detail
    get_user_info_from_userid
    @user.remove_checked_messages(params[:id])
    flash[:notice] = 'Message removed'
    if @user.userid_messages.length > 0
      redirect_to userid_messages_path
    else
      redirect_to new_manage_resource_path
    end
  end

  def reply_for_contact
    sender = UseridDetail.where(userid: @message.userid).first
    @contact = Contact.id(@message.source_contact_id).first
    if sender.present? && @contact.present?
      @contact.communicate_contact_reply(@message, sender.userid)
      contact = Contact.id(@message.source_contact_id).first
      redirect_to contact_path(contact) and return
    else
      #need to add error handling
    end
    redirect_to reply_contact_path(@message.source_contact_id)
  end

  def reply_for_feedback
    sender = UseridDetail.where(userid: @message.userid).first
    @feedback = Feedback.id(@message.source_feedback_id).first
    if sender.present? && @feedback.present?
      @feedback.communicate_feedback_reply(@message, sender.userid)
      feedback = Feedback.id(@message.source_feedback_id).first
      redirect_to feedback_path(feedback) and return
    else
      #need to add error handling
    end
  end

  def reply_for_message(reply)
    original_message = Message.id(reply.source_message_id).first
    reply.communicate_message_reply(original_message)
    source = session[:hold_source]
    session.delete(:hold_source) if session[:hold_source].present?
    redirect_to message_path(reply.id, source: source) and return
  end

  def return_for_create
    case session[:message_base]
    when 'userid_messages'
      redirect_to action: 'userid_messages'
    when 'syndicate'
      redirect_to action: 'list_syndicate_messages'
    when 'general'
      redirect_to action: 'index'
    end
  end

  def return_after_archive(source, id)
    case
    when session[:message_base] == 'syndicate' && source == 'list_syndicate_messages'
      redirect_to action: 'list_syndicate_messages', source: 'list_syndicate_messages'
    when session[:message_base] == 'syndicate' && source == 'show'
      redirect_to action: 'show', id: id
    when session[:message_base] == 'general' && source == 'index'
      redirect_to action: 'index', source: 'index'
    when session[:message_base] == 'general' && source == 'show'
      redirect_to action: 'show', id: id
    else
      redirect_to action: 'list_archived'
    end
  end

  def return_after_destroy
    if @message.source_feedback_id.present?
      redirect_to list_feedback_reply_message_path
    elsif @message.source_contact_id.present?
      redirect_to list_contact_reply_message_path
    elsif @message.source_message_id.present?
      redirect_to show_reply_messages_path
    elsif session[:message_base] == 'syndicate'
      redirect_to list_syndicate_messages_path
    elsif session[:message_base] == 'general'
      redirect_to action: 'index'
    end
  end

  def return_after_keep(source, id)
    case
    when session[:message_base] == 'syndicate' && source == 'list_syndicate_messages'
      redirect_to action: 'list_syndicate_messages', source: 'list_syndicate_messages'
    when session[:message_base] == 'syndicate' && source == 'show'
      redirect_to action: 'show', id: id
    when session[:message_base] == 'general' && source == 'index'
      redirect_to action: 'list_archived', source: 'list_archived'
    when session[:message_base] == 'general' && source == 'show'
      redirect_to action: 'show', id: id
    else
      redirect_to action: 'index'
    end
  end

  def return_after_restore(source, id)
    case
    when session[:message_base] == 'syndicate' && source == 'list_archived_syndicate_messages'
      redirect_to action: 'list_archived_syndicate_messages', source: 'list_syndicate_messages'
    when session[:message_base] == 'syndicate' && source == 'show'
      redirect_to action: 'show', id: id
    when session[:message_base] == 'general' && source == 'list_archived'
      redirect_to action: 'list_archived', source: 'list_archived'
    when session[:message_base] == 'general' && source == 'show'
      redirect_to action: 'show', id: id
    else
      redirect_to action: 'index'
    end
  end

  def return_after_unkeep(source, id)
    case
    when session[:message_base] == 'syndicate' && source == 'list_syndicate_messages'
      redirect_to action: 'list_syndicate_messages', source: 'list_syndicate_messages'
    when session[:message_base] == 'syndicate' && source == 'show'
      redirect_to action: 'show', id: id
    when session[:message_base] == 'general' && source == 'index'
      redirect_to action: 'index', source: 'index'
    when session[:message_base] == 'general' && source == 'show'
      redirect_to action: 'show', id: id
    else
      redirect_to action: 'list_archived'
    end
  end

  def restore
    @message = Message.id(params[:id]).first
    if @message.present?
      @message.restore
      session[:archived_contacts] = false
      flash.notice = 'Message restored'
      return_after_restore(params[:source], params[:id])
    else
      go_back('message',params[:id])
    end
  end

  def select_by_identifier
    get_user_info_from_userid
    @options = Hash.new
    order = 'identifier ASC'
    @messages = Message.list_messages(params[:action],session[:syndicate],session[:archived_contacts],order)
    @messages.each do |message|
      @options[message.identifier] = message.id
    end
    @message = Message.new
    @location = 'location.href= "/messages/" + this.value'
    @prompt = 'Select Identifier'
    render '_form_for_selection'
  end

  def send_message
    get_user_info_from_userid
    @message = Message.id(params[:id]).first
    @syndicate = session[:syndicate]
    if @message.present?
      @options = UseridRole::VALUES
      @sent_message = SentMessage.new(:message_id => @message.id, :sender => @user_userid)
      @message.sent_messages << [@sent_message]
      @sent_message.save
      @sent_message.active = true
      @message.action =  @sent_message.id
      @inactive_reasons = Array.new
      UseridRole::REASONS_FOR_INACTIVATING.each_pair do |key,value|
        @inactive_reasons << value
      end
      @open_data_status = SentMessage::ALL_STATUS_MESSAGES
      @senders = Array.new
      @senders << ''
      if @syndicate.present?
        @senders << @user.userid
        @senders << Syndicate.syndicate_code(@syndicate).first.syndicate_coordinator if Syndicate.is_syndicate(@syndicate)
      else
        UseridDetail.active(true).all.order_by(userid_lower_case: 1).each do |sender|
          @senders << sender.userid
        end
      end
    else
      go_back('message',params[:id])
    end
  end

  def send_contact_message
    get_user_info_from_userid
    if @message.present?
      @sent_message = SentMessage.new(:message_id => @message.id,:sender => @user_userid, recipients: [params[:email]])
      @message.sent_messages << [@sent_message]
      @sent_message.save
    end
  end

  def show
    get_user_info_from_userid
    @user.reload
    @message = Message.id(params[:id]).first
    session[:message_id] = @message.id if @message.present?
    session[:original_message_id] = @message.original_message_id if @message.present?
    @reply_messages = Message.fetch_replies(params[:id])
    @sent_replies = Message.sent_messages(@reply_messages)
    if @message.blank?
      go_back('message', params[:id])
    end
    @sent = @message.sent_messages.order_by(sent_time: 1) unless @message.sent_messages.blank?
  end

  def show_reply_messages
    get_user_info_from_userid
    @user.reload
    @user_messages = UseridDetail.id(@user.id).first.userid_messages
    @reply_messages = Message.fetch_replies(params[:id])
    @messages = Message.sent_messages(@reply_messages)
    @main_message = Message.id(params[:id]).first
    @reply_messages.each do |reply|
    end
  end

  def unkeep
    get_user_info_from_userid
    @message = Message.id(params[:id]).first
    go_back('message', params[:id]) if @message.blank?
    @message.update_unkeep
    flash.notice = 'Message no longer being kept'
    return_after_unkeep(params[:source], params[:id])
  end

  def user_reply_messages
    get_user_info_from_userid
    @user.reload
    @main_message = Message.id(params[:id]).first
    @reply_messages = Message.fetch_replies(params[:id])
    @user_replies = @reply_messages.where(userid: @user.userid).all
    @messages = Message.sent_messages(@user_replies)
  end

  def userid_reply_messages
    get_user_info_from_userid
    @user.reload
    @reply_messages = Message.in(id: @user.userid_messages).where(:source_message_id.ne => nil).all.order_by(message_sent_time: -1)
    session[:syndicate].blank? ? @messages = @reply_messages : @messages = syndicate_messages(@reply_messages, session[:syndicate])
  end

  def userid_messages
    session[:message_base] = 'userid_messages'
    get_user_info_from_userid
    @user.reload
    session[:manager] = @manager
    @main_messages = Message.in(id: @user.userid_messages).all.order_by(message_time: -1)
    session[:syndicate].blank? ? @messages = @main_messages : @messages = syndicate_messages(@main_messages, session[:syndicate])
  end

  def update
    @message = Message.id(params[:id]).first
    if @message.present?
      case params[:commit]
      when 'Submit'
        @message.update_attributes(message_params)
      when 'Send'
        @respond_to_message = Message.id(@message.source_message_id).first
        if session[:syndicate].present?
          params[:recipients] = Array.new
          params[:recipients] << 'Members of Syndicate'
          @syndicate = session[:syndicate]
        end
        if params[:recipients].blank?
          flash[:notice] = 'You did not select any recipients'
          redirect_to :back and return
        else
          sender = params[:sender]
          @sent_message = @message.sent_messages.id(params[:message][:action]).first
          reasons = Array.new
          params[:inactive_reasons].blank? ? reasons << 'temporary' : reasons = params[:inactive_reasons]
          @sent_message.update_attributes(:recipients => params[:recipients], :active => params[:active], :inactive_reason => reasons, :sender => sender, open_data_status: params[:open_data_status], syndicate: @syndicate)
          if @sent_message.recipients.nil? || @sent_message.open_data_status.nil?
            flash[:notice] = 'Invalid Send: Please select Recipients and Open Data Status'
            redirect_to action:'send_message' and return
          else
            @message.communicate(params[:recipients],  params[:active], reasons, sender, params[:open_data_status], @syndicate)
            @sent_message.update_attributes(sent_time: Time.now)
            @message.update_attributes(message_sent_time: Time.now)
            flash[:notice] = @message.reciever_notice(params)
          end
        end
      end
      redirect_to :action => 'show'
      return
    else
      go_back('message',params[:id])
    end
  end

  private
  def message_params
    params.require(:message).permit!
  end

  def set_message_syndicate
    if params[:id].present?
      @respond_to_message = Message.id(params[:id]).first
      @reply_messages = Message.fetch_replies(params[:id])
      @sent_replies = Message.sent_messages(@reply_messages)
      @message.syndicate = @respond_to_message.syndicate
    else
      session[:syndicate].present? ? @message.syndicate = session[:syndicate] : @message.syndicate = nil
    end
    @message.syndicate
  end

  def syndicate_messages(messages, syndicate)
    syndicate_messages = messages.reject do |msg|
      msg.sent_messages.syndicate_messages(syndicate).blank?
    end
    messages = syndicate_messages
    messages
  end
end
