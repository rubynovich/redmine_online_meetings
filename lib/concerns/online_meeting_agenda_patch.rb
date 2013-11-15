module OnlineMeetingAgendaPatch
  extend ActiveSupport::Concern
  included do
    attr_accessible :is_online
    #after_create :add_calendar_event
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
    #self.update_attributes({:online_meeting_url => event.alternate_uri, :online_meeting_uid => File.basename(event.id)})
    return emails, mobile_phones
  end

  def notify_members_and_contacts
    emails, mobile_phones = add_calendar_event
    if self.is_online?
      emails.each do |email|
        Mailer.apply_online_meeting(email,self).deliver
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