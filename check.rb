require 'nokogiri'
require 'http'

CSS_SELECTORS = {
  case_no:       ['NO',       '#lblRegisteredNo'],
  case_date:     ['DATE',     '#lblDateOfIntroduction'],
  case_title:    ['TITLE',    '#lblCaseTitle'],
  case_rep_name: ['REP NAME', '#lblRepresentativeName'],

  current_state: ['CURRENT STATE',    '#lblCurrentSOP'],
  last_event:    ['LAST MAJOR EVENT', '#lblLME'],

  event:         ['', '#gvLMES tr:not(:first-child)'],
}

request_url = 'http://app.echr.coe.int/SOP/'
case_no     = ARGV[0]
output      = []

puts 'Collecting required params...'
parsed_data = Nokogiri::HTML.parse(HTTP.get(request_url).to_s)

headers = {
  'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.116 Safari/537.36',
  'Accept':     'text/html',
  'Cookie':     'SERVERID=Court177',
  'Referer':    request_url,
}

data = {
  '__EVENTTARGET':   '',
  '__EVENTARGUMENT': '',
  '__LASTFOCUS':     '',
  'tbregno':         case_no,
  'btngetdoc':       'submit',
}

data.merge! (['__VIEWSTATE', '__VIEWSTATEGENERATOR', '__EVENTVALIDATION'].inject({}) do |memo, item|
  memo[item] = parsed_data.css("[name='#{item}']").first.values.last
  memo
end)

puts 'Querying...'
response = HTTP.headers(headers).post(request_url, form: data)
status = response.status

if(response.status == 200)
  parsed_response = Nokogiri::HTML.parse(response.body.to_s)
  error_panel     = parsed_response.css('#ErrorPanel').first

  if(error_panel)
    output = error_panel.text.strip
  else
    output = ["INFO", "------"]

    CSS_SELECTORS.each_pair do |key, node_info|
      unless key.eql? :event
        text = parsed_response.css(node_info.last).text
        output << "#{node_info.first}: #{text}" unless text.eql? ''
      else
        output << "\nEVENTS"
        output << "------"
        parsed_response.css(node_info.last).each do |event_node|
          text = event_node.css('td')[0].text
          date = event_node.css('td')[1].text

          output << "[#{date}] #{text}"
        end
      end
    end
  end
end

puts output.join("\n")
