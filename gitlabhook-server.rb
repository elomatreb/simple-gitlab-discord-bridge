require "sinatra"
require "yaml"
require "json"
require "rest-client"
require "digest/sha1"

require "sinatra/reloader" if development?

helpers do
  def config
    @config ||= YAML.load(File.read("settings.yaml"))
  end

  def constant_time_equal(a, b)
    Digest::SHA1.hexdigest(a) == Digest::SHA1.hexdigest(b) rescue false
  end

  def gitlab_secret
    config.dig("gitlab", "secret") || raise("No gitlab secret configured!")
  end

  def discord_url
    config.dig("discord", "webhook_url") || raise("No Discord URL configured!")
  end

  # View helpers

  def md_link(text, url)
    format "[%s](%s)", text, url
  end

  def branch_from_ref(ref)
    ref[/\w+\z/]
  end
end

before do
  halt 400 unless request.env["CONTENT_TYPE"] == "application/json"
  halt 400 unless request.has_header? "HTTP_X_GITLAB_TOKEN"
  halt 401 unless constant_time_equal(gitlab_secret,
                                      request.env["HTTP_X_GITLAB_TOKEN"])

  # Pre-parse JSON body
  request.body.rewind
  @request_body = JSON.parse request.body.read
end

post "/push" do
  case @request_body["object_kind"]
  when "push"
    payload = JSON.dump(content: erb(:push, locals: @request_body))

    begin
      RestClient.post discord_url, payload, content_type: :json
      "OK"
    rescue RestClient::ExceptionWithResponse => err
      status 500
      "Discord Webhook error, see logs. Got status code #{err.response.code}"
    end
  else
    status 400
    format "Unkown object_kind: '%s'",
           Rack::Utils.escape_html(@request_body["object_kind"])
  end
end
