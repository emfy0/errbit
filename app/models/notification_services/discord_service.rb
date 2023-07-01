class NotificationServices::DiscordService < NotificationService
  LABEL = "discord"
  FIELDS = [
    [:api_token, {
      placeholder: 'URL to receive a POST request when an error occurs',
      label:       'URL'
    }]
  ]

  def check_params
    if FIELDS.detect { |f| self[f[0]].blank? }
      errors.add :base, 'You must specify the URL'
    end
  end

  def message_for_discord(problem)
    "[#{problem.where}]: #{problem.error_class}"
  end

  def post_payload(problem)
    {
      username:    "Errbit",
      avatar_url:    "https://raw.githubusercontent.com/errbit/errbit/master/docs/notifications/slack/errbit.png",
      embeds: [
        {
          title:       problem.message.to_s.truncate(100),
          url:         problem.url,
          description: message_for_discord(problem),
          color:       13631488,
          fields:      post_payload_fields(problem)
        }
      ]
    }.to_json
  end

  def create_notification(problem)
    HTTParty.post(
      api_token,
      headers: {
        'Content-Type' => 'application/json',
        'User-Agent' => 'Errbit'
      },
      body: post_payload(problem)
    )
  end

private

  def post_payload_fields(problem)
    [
      { name: "Application", value: problem.app.name, inline: true },
      { name: "Environment", value: problem.environment, inline: true },
      { name: "Times Occurred", value: problem.notices_count.try(:to_s),
        inline: true },
      { name: "First Noticed",
        value: problem.first_notice_at.try(:localtime).try(:to_s, :db),
        inline: true },
      { name: "Backtrace", value: backtrace_lines(problem) }
    ]
  end

  def backtrace_line(line)
    path = line.decorated_path.gsub(%r{</?strong>}, '')
    "#{path}#{line.file_name}:#{line.number} → #{line.method}\n"
  end

  def backtrace_lines(problem)
    notice = NoticeDecorator.new problem.notices.last
    return unless notice
    backtrace = notice.backtrace
    return unless backtrace

    output = ''
    backtrace.lines[0..4].each { |line| output << backtrace_line(line) }
    "```#{output}```"
  end
end
