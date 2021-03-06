module OnlineMeetingAgendaPatch
  extend ActiveSupport::Concern
  included do
    attr_accessible :is_online
    #after_create :add_calendar_event
  end

  def add_calendar_event
    emails = []
    mobile_phones = {}
    self.meeting_members.each do |member|
      if member.user
        emails << member.user.mail unless [(Setting[:plugin_redmine_online_meetings][:failure_issue_status] || nil).try(:to_i)].include?(member.issue.try(:status_id))
      end
    end
    #internal_emails = emails.dup
    #raise emails.inspect
    meeting_contacts_arr = self.meeting_contacts || []
    meeting_contacts_arr.each do |cont|
      if cont.contact.present? && cont.contact.mail.present?
        emails << cont.contact.mail
        (cont.contact.mobile_phone || "").split(',').each do |phone|
          phone.gsub!(/\D/,'')
          phone.gsub!(/^8/,'7')
          if phone =~ /^79/ && (phone.length == 11)
            mobile_phones.merge!({phone => cont.contact.email})
          end
        end
      end
    end

    unless (mobile_phones == {})
      adv_persons = Person.active.where(id: Setting[:plugin_redmine_online_meetings][:send_advanced_user_ids].to_s.split(',').map{|item| item.to_i})
      adv_persons.each do |person|
        if person.present? && person.mail.present?
          (person.sanitized_phones || "").split(',').each do |phone|
            phone.gsub!(/\D/,'')
            phone.gsub!(/^8/,'7')
            if phone =~ /^79/ && (phone.length == 11)
              mobile_phones.merge!({"+#{phone}" => person.email})
            end
          end
        end
      end
    end


    meeting_members_sms_arr = self.meeting_members.where(user_id: Setting[:plugin_redmine_online_meetings][:send_internal_user_ids].to_s.split(',').map{|item| item.to_i}) || []
    meeting_members_sms_arr.each do |cont|
      if cont.user.present? && cont.user.mail.present?
        #emails << cont.user.mail
        (cont.user.becomes(Person).sanitized_phones || "").split(',').each do |phone|
          phone.gsub!(/\D/,'')
          phone.gsub!(/^8/,'7')
          if phone =~ /^79/ && (phone.length == 11)
            mobile_phones.merge!({"+#{phone}" => cont.user.becomes(Person).email})
          end
        end
      end
    end



    if Setting[:plugin_redmine_online_meetings][:account_login].present?# && (@old_status_id != self.status_id)
      service = GCal4Ruby::Service.get
      if self.online_meeting_uid
        event = GCal4Ruby::Event.find(service, {:id => self.online_meeting_uid})
      end
      unless event
        event = GCal4Ruby::Event.new(service)
      end
      event.calendar = service.calendars.first
      event.title = self.subject
      fix_time = (Setting[:plugin_redmine_online_meetings][:fix_time].try(:to_i) || 0).minutes
      event.start_time = (self.meet_on + self.start_time.seconds_since_midnight.to_i.second).utc + fix_time
      event.end_time = (self.meet_on + self.end_time.seconds_since_midnight.to_i.second).utc + fix_time
      event.visibility = :private
      event.status = :confirmed
      event.transparency = :busy
      event.is_video_conference = self.is_online?
      event.attendees = emails.map{|email| {email: email}}
      event.content = self.text_replace(Setting[:plugin_redmine_online_meetings][:calendar_message_text].dup || "")
      event.full_save
      #event.to_xml.inspect
      #raise event.alternate_uri.inspect
      self.online_meeting_url = event.alternate_uri
      self.online_meeting_uid = event.id
    end
    self.class.skip_callback(:save)
    self.save(:validate => false)
    self.class.set_callback(:save)
    return emails, mobile_phones
  end

  def recordable?(by_user=nil)
    user_condition = by_user.nil? ? true : (by_user.id == self.author_id)
    (! self.is_recording) &&
        self.is_online? &&
        user_condition &&
        ((self.end_time_utc+(Setting[:plugin_redmine_online_meetings][:time_fix_srv] || 0).to_i.minutes) > Time.now.utc) &&
        ((self.start_time_utc+(Setting[:plugin_redmine_online_meetings][:time_fix_srv] || 0).to_i.minutes-(Setting[:plugin_redmine_online_meetings][:timeout] || 0).to_i.minutes) <= Time.now.utc)
  end


  def end_time_utc
    #(Setting[:plugin_redmine_online_meetings][:fix_time].try(:to_i) || 0).minutes
    (self.meet_on + self.end_time.seconds_since_midnight.to_i.second).utc
  end

  def start_time_utc
    #(Setting[:plugin_redmine_online_meetings][:fix_time].try(:to_i) || 0).minutes
    (self.meet_on + self.start_time.seconds_since_midnight.to_i.second).utc
  end

  def notify_members_and_contacts
    emails, mobile_phones = add_calendar_event
    emails ||= []
    mobile_phones ||= {}
    if self.is_online?
      emails.each do |email|
        message_text = self.text_replace(Setting[:plugin_redmine_online_meetings][:mail_message_text], email)
        Mailer.apply_online_meeting(email,self, message_text).deliver if self.online_meeting_url
      end
    end
    if Setting[:plugin_redmine_online_meetings][:account_sms_login].present? && (mobile_phones.count > 0)
      #SmsApi.email = Setting[:plugin_redmine_online_meetings][:account_sms_login]
      #SmsApi.password = Setting[:plugin_redmine_online_meetings][:account_sms_password]
      #SmsApi.login
      Rails.logger.info "Phones to send sms #{mobile_phones.inspect}"
      sms = SMSC.new()
      sms.smsc_login = Setting[:plugin_redmine_online_meetings][:account_sms_login]
      sms.smsc_password = Digest::MD5.hexdigest(Setting[:plugin_redmine_online_meetings][:account_sms_password])
      mobile_phones.each_pair do |recipient_phone, email|
        sms_text = (self.is_online? ? Setting[:plugin_redmine_online_meetings][:sms_online_text] : Setting[:plugin_redmine_online_meetings][:sms_text]).dup
        sms_text = self.text_replace(sms_text, email)
        sms.send_sms(recipient_phone, sms_text, 0, 0, 0, 0, Setting[:plugin_redmine_online_meetings][:sms_phone])
      end
    end
  end

  def text_replace(text_d, email="")
    text = (text_d || '').dup
    text.gsub!('{{meeting_agenda}}', self.id.to_s)
    text.gsub!('{{meet_on}}', self.meet_on.strftime('%d.%m.%Y'))
    text.gsub!('{{start_time}}',self.start_time.strftime('%H:%M'))
    text.gsub!('{{end_time}}',self.end_time.strftime('%H:%M'))
    text.gsub!('{{org}}',self.meeting_company ? self.meeting_company.name : '')
    text.gsub!('{{author}}', self.author.name)
    text.gsub!('{{email}}', email)
    text.gsub!(/{{org\((.*)\)}}/, self.meeting_company ? self.meeting_company.try(:name) : ($1 || ""))
    text.gsub!('{{subject}}', self.subject)
    if self.is_external?
      text.gsub!('{{external_text}}',l(:external_text))
      case self.external_place_type
        when 'building_object'
          Rails.logger.error('external building object'.red)
          text.gsub!('{{address}}', "#{l(:external_building_template) % [self.address]}")
        when 'external_company'
          Rails.logger.error('external company'.red)
          text.gsub!('{{address}}', "#{l(:external_template) % [self.external_company.try(:name), (self.address.present? ? self.address : self.external_company.address)]}")
      end
    else
      text.gsub!('{{external_text}}',l(:internal_text))
      text.gsub!('{{address}}', "#{l(:internal_template) % [self.place]}")
    end
    text
  end

end
