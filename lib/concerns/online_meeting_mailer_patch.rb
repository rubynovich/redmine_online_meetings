module OnlineMeetingMailerPatch
  extend ActiveSupport::Concern
  def apply_online_meeting(to_email,meeting_agenda)
    @meeting_agenda = meeting_agenda
    subject = ::I18n.t(:mail_online_meeting_subject_format)
    mail(to: to_email, subject: subject)
  end
end