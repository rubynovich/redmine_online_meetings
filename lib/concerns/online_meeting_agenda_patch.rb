module OnlineMeetingAgendaPatch
  extend ActiveSupport::Concern
  included do
    #after_create :notify_members_and_contacts
  end

  def add_calendar_event
    emails = []
    mobile_phones = []
    self.meeting_members.each do |member|
      if member.user
        emails << member.user.mail
      end
    end
    self.meeting_contacts do |contact|
      if contact.contact.email.present?
        emails << contact.contact.email
        #notify phone
        contact.phone.split(',').each do |phone|
          phone.gsub!(/\D/,'')
          phone.gsub!(/^8/,'7')
          if phone =~ /^79/ && (phone.length == 11)
            mobile_phones += phone
            #send sms
          end
        end
      end
    end
    service = GCal4Ruby::Service.new
    service.hangout_domain = Setting[:plugin_redmine_online_meetings][:hangout_domain]
    service.authenticate(Setting[:plugin_redmine_online_meetings][:account_login], Setting[:plugin_redmine_online_meetings][:account_password])
    event = GCal4Ruby::Event.new(service)
    event.calendar = service.calendars.first
    event.title = self.subject
    event.start_time = self.start_time
    event.end_time = self.end_time
    event.visibility = :private
    event.status = :confirmed
    event.transparency = :busy
    event.is_video_conference = true
    event.attendees = emails.map{|email| {email: email}}
    event.full_save
    #raise event.inspect
    self.update_attribute(:online_meeting_url, event.alternate_uri)
    #self.update_attribute(:online_meeting_url, event.alternate_uri)
    return emails, mobile_phones
  end

  def notify_members_and_contacts
    if self.is_online
      emails, mobile_phones = add_calendar_event
      emails.each do |email|
        Mailer.apply_online_meeting(email,self).deliver!
      end
      if mobile_phones.count > 0
        SmsApi.login(Setting[:plugin_redmine_online_meetings][:account_sms_login], Setting[:plugin_redmine_online_meetings][:account_sms_password])
        mobile_phones.each do |recipient_phone|
          SmsApi.push_msg(recipient_phone, 'sms_text', {})
        end
      end
    end
  end

end