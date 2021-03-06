require 'net_http_ssl_fix'
require 'mechanize'
require 'faraday'
require 'faraday_middleware'
require 'json'
require 'tty-prompt'

puts <<eos
┌────────────────────────────────────────────────────────────────────┐
│ Tinder Ruby AutoLiker v2.0                                         │
├────────────────────────────────────────────────────────────────────┤
│ Copyright © 2018 Matheus Vetor @matheusvetor                       │
├────────────────────────────────────────────────────────────────────┤
│ Licensed under the MIT license.                                    │
└────────────────────────────────────────────────────────────────────┘
eos

# -------------
# CONFIGURATION
# -------------

prompt          = TTY::Prompt.new
my_login        = prompt.ask  "What's your email?"
my_password     = prompt.mask "Enter your password"
age_filter_min  = prompt.ask  "Please set minimum age you want to like", convert: :int
age_filter_max  = prompt.ask  "Please set maximum age you want to like", convert: :int
distance_filter = prompt.ask  "Please set distance as Mile, max: 100",   convert: :int

puts '==== FACEBOOK ===='
puts '* Fetching Facebook data...'
puts '  - Fetching your Facebook Tinder token...'

tinder_oauth_url = 'https://www.facebook.com/v2.6/dialog/oauth?redirect_uri=fb464891386855067%3A%2F%2Fauthorize%2F&scope=user_birthday,user_photos,user_education_history,email,user_relationship_details,user_friends,user_work_history,user_likes&response_type=token%2Csigned_request&client_id=464891386855067'.freeze

mechanize = Mechanize.new
mechanize.user_agent = 'Mozilla/5.0 (Linux; U; en-gb; KFTHWI Build/JDQ39) AppleWebKit/535.19 (KHTML, like Gecko) Silk/3.16 Safari/535.19'.freeze

login_form = mechanize.get(tinder_oauth_url).form do |f|
  f.email = my_login
  f.pass = my_password
end

fb_token = login_form.submit.form.submit.body.split('access_token=')[1].split('&')[0]
puts '=> My FB_TOKEN is '+fb_token

puts '* DONE.'

puts '==== TINDER ===='
puts '* Connecting to the Tinder API...'
# Now, let's connect to the Tinder API
conn = Faraday.new(url: 'https://api.gotinder.com') do |faraday|
  faraday.request :json             # form-encode POST params
  faraday.response  :logger                  # log requests to STDOUT
  faraday.adapter Faraday.default_adapter  # make requests with Net::HTTP
end
# Tinder blocked the Faraday User-Agent.
# We now must provide the same User-Agent as the iPhone
conn.headers['User-Agent'] = "Tinder/4.0.9 (iPhone; iOS 8.1.1; Scale/2.00)"
puts '  - Fetching your Tinder token...'
# Authentication, the point is to get your Tinder token
rsp = conn.post '/auth', { facebook_token: fb_token}
jrsp = JSON.parse(rsp.body)
token = jrsp["token"]

# The resulting token will be used for every requests done on the Tinder API
conn.token_auth(token)
conn.headers['X-Auth-Token'] = token

puts '  - Fetching users in your area...'
# Let's fetch Tinder users in your area
targets = Array.new
begin
  while(true)
    fileTargets = File.open("targets.txt", "a")

    rsp = conn.post '/profile', { age_filter_min: age_filter_min, gender: 0, age_filter_max: age_filter_max, distance_filter: distance_filter }
    jrsp = JSON.parse(rsp.body)

    rsp = conn.post '/updates'
    jrsp = JSON.parse(rsp.body)

    rsp = conn.post 'user/recs'
    jrsp = JSON.parse(rsp.body)
    while(!jrsp['results'].nil?)
      puts '======== LIKING... ========='
      jrsp["results"].each do |target|
        if target['gender'] == 1
          targets.push(target["_id"])
          fileTargets.write(target["_id"]+"\n")
          trsp = conn.get 'like/'+target["_id"]
          trsp
        end
      end
      rsp = conn.post 'user/recs'
      jrsp = JSON.parse(rsp.body)
    end
  end
  puts '========= DONE! =========='
  puts 'Below are the targets you just liked.'
  puts targets
  puts '======== EXIT... ========='
rescue IOError
ensure
  fileTargets.close unless fileTargets == nil
end
