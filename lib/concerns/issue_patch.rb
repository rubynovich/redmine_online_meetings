module OnlineMeetingIssuePatch
  extend ActiveSupport::Concern
  included do
    after_update :failred_remove_from_meeting
  end

  def failred_remove_from_meeting
    if self.status_id == (Setting[:plugin_redmine_online_meetings][:failure_issue_status] || nil).try(:to_i)
      #calendar_update
      meeting_member.meeting_agenda.add_calendar_event if meeting_member
      return true
    end
  end


end