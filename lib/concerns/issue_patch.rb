module OnlineMeetingIssuePatch
  extend ActiveSupport::Concern
  included do
    before_update :set_old_value_for_status_id, if: -> { self.meeting_member }
    after_update :setup_calendar_for_meeting, if: -> { self.meeting_member }
  end

  private

  def set_old_value_for_status_id
    @old_status_id = self.class.where(id: self.id).first.try(:status_id)
  end

  def setup_calendar_for_meeting
    meeting_member.meeting_agenda.sidekiq_delay.add_calendar_event if Setting[:plugin_redmine_online_meetings][:account_login].present? && (@old_status_id != self.status_id)
    #if self.status_id == (Setting[:plugin_redmine_online_meetings][:failure_issue_status] || nil).try(:to_i)
      #calendar_update
    #  return true
    #end
  end


end