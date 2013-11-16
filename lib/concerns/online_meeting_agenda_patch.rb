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
        emails << member.user.mail
      end
    end

    self.meeting_contacts.each do |cont|
      if cont.contact.mail.present?
        emails << cont.contact.mail
        cont.contact.phone.split(',').each do |phone|
          phone.gsub!(/\D/,'')
          phone.gsub!(/^8/,'7')
          if phone =~ /^79/ && (phone.length == 11)
            mobile_phones.merge!({phone => cont.contact.email})
          end
        end
      end
    end
    service = GCal4Ruby::Service.get
    if self.online_meeting_uid
      event = GCal4Ruby::Event.find(service, {:id => self.online_meeting_uid})
    end
    unless event
      event = GCal4Ruby::Event.new(service)
    end
    event.calendar = service.calendars.first
    event.title = self.subject
    event.start_time = self.meet_on + self.start_time.seconds_since_midnight.to_i.second
    event.end_time = self.meet_on + self.end_time.seconds_since_midnight.to_i.second
    event.visibility = :private
    event.status = :confirmed
    event.transparency = :busy
    event.is_video_conference = self.is_online?
    event.attendees = emails.map{|email| {email: email}}
    event.full_save
    #event.to_xml.inspect
    #raise event.alternate_uri.inspect
    self.online_meeting_url = event.alternate_uri
    self.online_meeting_uid = event.id
    self.class.skip_callback(:save)
    self.save(:validate => false)
    self.class.set_callback(:save)
    return emails, mobile_phones
  end

  def notify_members_and_contacts
    emails, mobile_phones = add_calendar_event
    emails.each do |email|
      message_text = self.text_replace(Setting[:plugin_redmine_online_meetings][:mail_message_text].dup || "", email)
      Mailer.apply_online_meeting(email,self, message_text).deliver
    end
    if mobile_phones.count > 0
      #SmsApi.email = Setting[:plugin_redmine_online_meetings][:account_sms_login]
      #SmsApi.password = Setting[:plugin_redmine_online_meetings][:account_sms_password]
      #SmsApi.login
      sms = SMSC.new()
      sms.smsc_login = Setting[:plugin_redmine_online_meetings][:account_sms_login]
      sms.smsc_password = Digest::MD5.hexdigest(Setting[:plugin_redmine_online_meetings][:account_sms_password])
      mobile_phones.each_pair do |recipient_phone, email|
        sms_text = (self.is_online? ? Setting[:plugin_redmine_online_meetings][:sms_online_text] : Setting[:plugin_redmine_online_meetings][:sms_text]).dup
        sms_text = self.text_replace(sms_text, email)
        sms.send_sms(recipient_phone, sms_text, 0, 0, 0, 1, Setting[:plugin_redmine_online_meetings][:sms_phone])
      end
    end
  end

  def text_replace(text, email="")
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
      text.gsub!('{{address}}', "#{l(:external_template) % [self.external_company.try(:name), self.place]}")
    else
      text.gsub!('{{external_text}}',l(:internal_text))
      text.gsub!('{{address}}', "#{l(:internal_template) % [self.place]}")
    end
    text
  end

end