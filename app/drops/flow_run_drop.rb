class FlowRunDrop < BaseDrop
  def id
    @obj.id
  end

  def status
    @obj.status
  end

  def started_at
    @obj.started_at
  end
end
