module OnlineMeetingsMeetingAgendasControllerPatch
  def send_invites
    (render_403; return false) unless can_send_invites?(@object)
    @object.meeting_members.reject(&:issue).each(&:send_invite)
    @object.notify_members_and_contacts
    redirect_to controller: 'meeting_agendas', action: 'show', id: @object.id
  end

  def resend_invites
    (render_403; return false) unless can_send_invites?(@object)
    @object.meeting_members.each(&:resend_invite)
    @object.notify_members_and_contacts
    redirect_to controller: 'meeting_agendas', action: 'show', id: @object.id
  end
end