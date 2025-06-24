# Usage example: (scrapes level 1)
# ruby main.rb 1

require 'open-uri'
require 'nokogiri'
require 'csv'

USER_AGENT = 'Mozilla/5.0'

def main(url)
  html = URI.open(url, 'User-Agent' => USER_AGENT).read
  doc  = Nokogiri::HTML(html)

  # 1. Grab the pattern-name links: text → collocation-group id
  patterns = doc
             .css('.subject-collocations__pattern-names > a')
             .to_h { |a| [a.text.strip, a['href']] }

  # 2. For each pattern, collect its English / Japanese sentence pairs
  patterns.flat_map do |pattern_name, group_id|
    doc.css(group_id).css('> *').map do |row|
      english, japanese = row.css('> *').map(&:text)
      vocab = URI.decode_www_form_component(url.split('/').last)
      { vocab: vocab, pattern_name: pattern_name, english: english, japanese: japanese }
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  level = ARGV.first || 1
  html = URI.open("https://www.wanikani.com/level/#{level}", 'User-Agent' => USER_AGENT).read
  doc  = Nokogiri::HTML(html)
  urls = doc.css('.subject-character--vocabulary').map { _1['href'] }
  rows = []
  urls.each_with_index do |url, i|
    data = main(url)
    rows.concat(data)
    pp "Completed: #{i + 1}/#{urls.size}"
    pp data
  end

  CSV.open("patterns_level_#{level}.csv", 'wb', write_headers: true, headers: rows.first.keys) do |csv|
    rows.each { |row| csv << row.values }
  end
end
