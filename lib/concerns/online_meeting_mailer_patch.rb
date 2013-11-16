module OnlineMeetingMailerPatch
  extend ActiveSupport::Concern
  def apply_online_meeting(to_email,meeting_agenda, message_text)
    @meeting_agenda = meeting_agenda
    @message_text = message_text
    subject = ::I18n.t(:mail_online_meeting_subject_format)
    mail(to: to_email, subject: subject, from: Setting[:plugin_redmine_online_meetings][:account_login])
  end
end