class Message
  include Mongoid::Document
  include Mongoid::Timestamps
  field :subject, type: String
  field :source_message_id, type: String
  field :source_feedback_id, type: String
  field :source_contact_id, type: String
  field :body, type: String
  field :message_time, type: DateTime
  field :message_sent_time, type: DateTime
  field :userid, type: String
  field :attachment, type: String
  field :identifier, type: String
  field :path, type: String
  field :file_name, type: String
  field :images, type: String
  field :recipients, type: Array.new, default: nil
  field :archived, type: Boolean, default: false
  field :keep, type: Boolean, default: false
  field :syndicate, type: String
  attr_accessor :action, :inactive_reasons,:active
  embeds_many :sent_messages
  accepts_nested_attributes_for :sent_messages,allow_destroy: true, reject_if: :all_blank

  scope :fetch_replies, -> (id) { where(source_message_id: id) }
  scope :fetch_feedback_replies, -> (id) { where(source_feedback_id: id) }
  scope :non_feedback_contact_reply_messages, -> { where(source_feedback_id: nil, source_contact_id: nil) }
  scope :non_reply_messages, -> { where(source_feedback_id: nil, source_contact_id: nil, source_message_id: nil) }
  scope :feedback_replies, -> { where({ :source_feedback_id.ne => nil })}
  scope :contact_replies, -> { where({ :source_contact_id.ne => nil })}
  mount_uploader :attachment, AttachmentUploader
  mount_uploader :images, ScreenshotUploader
  before_create :add_identifier

  index({_id: 1, userid: 1},{name: 'id_userid'})
  index({_id: 1, sent_time: 1},{name: 'id_sent_time'})
  index({_id: 1, identifier: 1},{name: 'id_indentifier'})
  index({_id: 1, message_time: 1},{name: 'id_message_time'})

  class << self

    def archived(archived)
      where(:archived => archived)
    end

    def can_be_destroyed?(message)
      message.source_message_id.present? || Message.fetch_replies(message.id).count == 0 || message.keep.blank?
    end

    def id(id)
      where(:id => id)
    end

    def keep(status)
      where(keep: status)
    end

    def not_message_reply(status)
      if status
        where(source_message_id: nil)
      else
        where(:source_message_id.ne => nil)
      end
    end

    def syndicate(syndicate)
      where(:syndicate => syndicate)
    end

    def message_replies(id)
      where(:source_message_id => id)
    end

    def userid(userid)
      where(:userid => userid)
    end
  end
  #....................................................................Instance Methods...............................
  def a_reply?
    source_message_id.present? || source_feedback_id.present? || source_contact_id.present? ? answer = true : answer = false
    answer
  end

  def archive
    update_attribute(:archived, true)
    Message.message_replies(id).each do |message_rl1|
      message_rl1.update_attribute(:archived, true)
      Message.message_replies(message_rl1.id).each do |message_rl2|
        message_rl2.update_attribute(:archived, true)
        Message.message_replies(message_rl2.id).each do |message_rl3|
          message_rl3.update_attribute(:archived, true)
          Message.message_replies(message_rl3.id).each do |message_rl4|
            message_rl4.update_attribute(:archived, true)
            Message.message_replies(message_rl4.id).each do |message_rl5|
              message_rl5.update_attribute(:archived, true)
              Message.message_replies(message_rl5.id).each do |message_rl6|
                message_rl6.update_attribute(:archived, true)
                Message.message_replies(message_rl6.id).each do |message_rl7|
                  message_rl7.update_attribute(:archived, true)
                  Message.message_replies(message_rl7.id).each do |message_rl8|
                    message_rl8.update_attribute(:archived, true)
                    Message.message_replies(message_rl8.id).each do |message_rl9|
                      message_rl9.update_attribute(:archived, true)
                      Message.message_replies(message_rl9.id).each do |message_rl10|
                        message_rl10.update_attribute(:archived, true)
                        Message.message_replies(message_rl10.id).each do |message_rl11|
                          message_rl11.update_attribute(:archived, true)
                          Message.message_replies(message_rl11.id).each do |message_rl12|
                            message_rl12.update_attribute(:archived, true)
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  def archived?
    archived.present?
  end

  def add_identifier
    self.identifier = Time.now.to_i - Time.gm(2015).to_i
  end

  def add_syndicate?
    original_message = Message.find(source_message_id)
    original_message.present? && original_message.syndicate.present? ? answer = true : answer = false
    answer
  end

  def being_kept?
    self.keep.present? ? answer = true : answer = false
    answer
  end

  def communicate(recipient_roles, active, reasons, sender, open_data_status, syndicate = nil)
    p 'communicate'
    p recipient_roles
    p active
    p reasons
    p open_data_status
    ccs = Array.new
    recipient_roles.each do |recipient_role|
      p recipient_role
      ccs = get_actual_recipients(recipient_role, syndicate, active, open_data_status, reasons )
    end
    add_message_to_userid_messages(UseridDetail.look_up_id(sender)) unless sender.blank? || ccs.include?(sender)
    ccs << sender
    ccs = ccs.uniq
    p 'to whom'
    p ccs
    UserMailer.send_message(self, ccs, sender).deliver_now
  end

  def communicate_message_reply(original_message)
    to_userid = original_message.userid
    copy_to = syndicate_coordinator if syndicate.present?
    UserMailer.message_reply(self, to_userid, copy_to, original_message, userid).deliver_now
    add_message_to_userid_messages(UseridDetail.look_up_id(to_userid)) unless to_userid.blank?
    add_message_to_userid_messages(UseridDetail.look_up_id(copy_to)) unless copy_to.blank?
    recipients = Array.new
    recipients << to_userid
    recipients << copy_to unless copy_to.present? && copy_to == to_userid
    copies = Array.new
    reply_sent_messages(self, userid, recipients, copies)
  end

  def get_actual_recipients(recipient_role, syndicate, active, open_data_status, reasons)
    ccs = Array.new
    active_user = user_status(active)
    recipients = recipient_users(recipient_role, syndicate)
    if active_user
      get_active_users(recipients, open_data_status, active_user, ccs)
    elsif reasons.present? && !active_user
      get_inactive_users_with_reasons(recipients, open_data_status, active_user, reasons, ccs)
    elsif reasons.blank? && !active_user
      get_inactive_users_without_reasons(recipients, open_data_status, active_user, ccs)
    end
    ccs
  end

  def mine?(user)
    userid == user.userid ? answer = true : answer = false
    answer
  end

  def not_archived?
    archived.blank?
  end

  def not_a_reply?
    source_message_id.present? || source_feedback_id.present? || source_contact_id.present? ? answer = false : answer = true
    answer
  end

  def not_being_kept?
    self.keep.blank? ? answer = true : answer = false
    answer
  end

  def original_message_id
    original_message = Message.id(source_message_id).first if source_message_id.present?
    original_message = original_message.id if original_message.present?
    original_message
  end

  def reciever_notice(params)
    active_user = user_status(params[:active])
    if active_user
      return "Message sent to Recipients: #{params[:recipients]}; Open Data Status: #{open_data_status_value(params[:open_data_status])}; Active : #{active_user} "
    else
      return "Message sent to Recipients: #{params[:recipients]}; Open Data Status: #{open_data_status_value(params[:open_data_status])}; Active : #{active_user} #{params[:inactive_reasons]}"
    end
  end

  def restore
    update_attribute(:archived, false)
    Message.message_replies(id).each do |message_rl1|
      message_rl1.update_attribute(:archived, false)
      Message.message_replies(message_rl1.id).each do |message_rl2|
        message_rl2.update_attribute(:archived, false)
        Message.message_replies(message_rl2.id).each do |message_rl3|
          message_rl3.update_attribute(:archived, false)
          Message.message_replies(message_rl3.id).each do |message_rl4|
            message_rl4.update_attribute(:archived, false)
            Message.message_replies(message_rl4.id).each do |message_rl5|
              message_rl5.update_attribute(:archived, false)
              Message.message_replies(message_rl5.id).each do |message_rl6|
                message_rl6.update_attribute(:archived, false)
                Message.message_replies(message_rl6.id).each do |message_rl7|
                  message_rl7.update_attribute(:archived, false)
                  Message.message_replies(message_rl7.id).each do |message_rl8|
                    message_rl8.update_attribute(:archived, false)
                    Message.message_replies(message_rl8.id).each do |message_rl9|
                      message_rl9.update_attribute(:archived, false)
                      Message.message_replies(message_rl9.id).each do |message_rl10|
                        message_rl10.update_attribute(:archived, false)
                        Message.message_replies(message_rl10.id).each do |message_rl11|
                          message_rl11.update_attribute(:archived, false)
                          Message.message_replies(message_rl11.id).each do |message_rl12|
                            message_rl12.update_attribute(:archived, false)
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  def sent?
    sent_messages.deliveries.count != 0
  end

  def syndicate_coordinator
    synd = Syndicate.syndicate_code(syndicate).first
    coordinator = synd.syndicate_coordinator if syndicate.present?
    coordinator
  end

  def there_are_no_reply_messages?
    Message.fetch_replies(id).count == 0 ? answer = true : answer = false
    answer
  end

  def there_are_reply_messages?
    Message.fetch_replies(id).count >= 1 ? answer = true : answer = false
    answer
  end

  def update_keep
    update_attributes(archived: true, keep: true)
    Message.message_replies(id).each do |message_rl1|
      message_rl1.update_attributes(archived: true, keep: true)
      Message.message_replies(message_rl1.id).each do |message_rl2|
        message_rl2.update_attributes(archived: true, keep: true)
        Message.message_replies(message_rl2.id).each do |message_rl3|
          message_rl3.update_attributes(archived: true, keep: true)
          Message.message_replies(message_rl3.id).each do |message_rl4|
            message_rl4.update_attributes(archived: true, keep: true)
            Message.message_replies(message_rl4.id).each do |message_rl5|
              message_rl5.update_attributes(archived: true, keep: true)
              Message.message_replies(message_rl5.id).each do |message_rl6|
                message_rl6.update_attributes(archived: true, keep: true)
                Message.message_replies(message_rl6.id).each do |message_rl7|
                  message_rl7.update_attributes(archived: true, keep: true)
                  Message.message_replies(message_rl7.id).each do |message_rl8|
                    message_rl8.update_attributes(archived: true, keep: true)
                    Message.message_replies(message_rl8.id).each do |message_rl9|
                      message_rl9.update_attributes(archived: true, keep: true)
                      Message.message_replies(message_rl9.id).each do |message_rl10|
                        message_rl10.update_attributes(archived: true, keep: true)
                        Message.message_replies(message_rl10.id).each do |message_rl11|
                          message_rl11.update_attributes(archived: true, keep: true)
                          Message.message_replies(message_rl11.id).each do |message_rl12|
                            message_rl12.update_attributes(archived: true, keep: true)
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  def update_unkeep
    update_attributes(archived: true, keep: false)
    Message.message_replies(id).each do |message_rl1|
      message_rl1.update_attributes(archived: true, keep: false)
      Message.message_replies(message_rl1.id).each do |message_rl2|
        message_rl2.update_attributes(archived: true, keep: false)
        Message.message_replies(message_rl2.id).each do |message_rl3|
          message_rl3.update_attributes(archived: true, keep: false)
          Message.message_replies(message_rl3.id).each do |message_rl4|
            message_rl4.update_attributes(archived: true, keep: false)
            Message.message_replies(message_rl4.id).each do |message_rl5|
              message_rl5.update_attributes(archived: true, keep: false)
              Message.message_replies(message_rl5.id).each do |message_rl6|
                message_rl6.update_attributes(archived: true, keep: false)
                Message.message_replies(message_rl6.id).each do |message_rl7|
                  message_rl7.update_attributes(archived: true, keep: false)
                  Message.message_replies(message_rl7.id).each do |message_rl8|
                    message_rl8.update_attributes(archived: true, keep: false)
                    Message.message_replies(message_rl8.id).each do |message_rl9|
                      message_rl9.update_attributes(archived: true, keep: false)
                      Message.message_replies(message_rl9.id).each do |message_rl10|
                        message_rl10.update_attributes(archived: true, keep: false)
                        Message.message_replies(message_rl10.id).each do |message_rl11|
                          message_rl11.update_attributes(archived: true, keep: false)
                          Message.message_replies(message_rl11.id).each do |message_rl12|
                            message_rl12.update_attributes(archived: true, keep: false)
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  private

  class << self

    def formatted_time(message)
      if message.message_sent_time.blank?
        message.message_time.to_formatted_s(:long)
      else
        message.message_sent_time.to_formatted_s(:long) unless message.message_sent_time.blank?
      end
    end

    def list_messages(action, syndicate, archived, order)
      case action
      when 'list_unsent_messages'
        @messages = Message.non_feedback_contact_reply_messages.all.find_all do |message|
          !message.sent?
        end
      when 'list_feedback_reply_message'
        @messages = Message.feedback_replies.archived(archived).order_by(order)
      when 'list_contact_reply_message'
        @messages = Message.contact_replies.archived(archived).order_by(order)
      when 'list_syndicate_messages'
        @messages = Message.non_feedback_contact_reply_messages.syndicate(syndicate).archived(archived).not_message_reply(true).all.order_by(order)
      when 'list_archived_syndicate_messages'
        @messages = Message.non_feedback_contact_reply_messages.syndicate(syndicate).archived(archived).not_message_reply(true).all.order_by(order)
      else
        @messages = Message.non_feedback_contact_reply_messages.archived(archived).not_message_reply(true).all.order_by(order)
      end
      @messages
    end

    def sent_messages(messages)
      messages.order(message_sent_time: :asc).find_all do |message|
        message.sent?
      end
    end
  end

  #..............................................................Instance Methods

  def add_message_to_userid_messages(person)
    return if person.blank?

    @message_userid = person.userid_messages
    unless @message_userid.include? id.to_s
      @message_userid << id.to_s
      person.update_attribute(:userid_messages, @message_userid)
    end
  end

  def get_active_users(recipients, open_data_status, active_user, ccs)
    recipients.each do |person|
      if person.present? && person.email_address_valid?
        if person.active?
          if person.meets_open_status_requirement?(open_data_status)
            add_message_to_userid_messages(person)
            ccs << person.userid
          end
        end
      else
        p 'nil person'
        p person
      end
    end
  end


  def get_inactive_users_with_reasons(recipients, open_data_status, active_user, reasons, ccs)
    recipients.each do |person|
      if person.present? && person.email_address_valid?
        unless person.active?
          if person.meets_open_status_requirement?(open_data_status)
            if person.meets_reasons?(reasons)
              add_message_to_userid_messages(person)
              ccs << person.userid
            end
          end
        end
      end
    end
  end

  def get_inactive_users_without_reasons(recipients, open_data_status, active_user, ccs)
    recipients.each do |person|
      if person.present? && person.email_address_valid?
        unless person.active?
          if person.meets_open_status_requirement?(open_data_status)
            add_message_to_userid_messages(person)
            ccs << person.userid
          end
        end
      end
    end
  end

  def open_data_status_value(status)
    status.join('') unless status.nil?
    status
  end

  def recipient_users(recipients, syndicate = nil)
    users = Array.new
    case recipients
    when 'Members of Syndicate'
      UseridDetail.syndicate(syndicate).each do |user|
        users << user
      end
    when 'syndicate_coordinator'
      Syndicate.each do |syndicate|
        users << UseridDetail.look_up_id(syndicate.syndicate_coordinator)
      end
      UseridDetail.role(recipients).each do |user|
        users << user
      end
      UseridDetail.secondary(recipients).each do |user|
        users << user
      end

    when 'county_coordinator'
      County.each do |county|
        users << UseridDetail.look_up_id(county.county_coordinator)
      end
      UseridDetail.role(recipients).each do |user|
        users << user
      end
      UseridDetail.secondary(recipients).each do |user|
        users << user
      end
    else
      UseridDetail.role(recipients).each do |user|
        users << user
      end
      UseridDetail.secondary(recipients).each do |user|
        users << user
      end
    end
    users
  end

  def reply_sent_messages(message, sender_userid, contact_recipients, other_recipients)
    @message = message
    contact_recipients = contact_recipients.reject(&:blank?)
    @sent_message = SentMessage.new(message_id: @message.id, sender: sender_userid, recipients: contact_recipients, other_recipients: other_recipients, sent_time: Time.now)
    @message.sent_messages << [@sent_message]
    @sent_message.save
  end

  def user_status(status)
    status == 'true'
  end
end
