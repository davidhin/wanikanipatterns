# Usage example: (scrapes level 1)
# ruby main.rb 1

require 'open-uri'
require 'nokogiri'
require 'csv'
require 'active_support/all'

USER_AGENT = 'Mozilla/5.0'

PROMPT = "
Please help me create a picture to help me remember the following kanji. It uses mnemonic technique.
Display the kanji on the top with its meaning, then a picture that is a combined representation of the meaning and reading mnemonic.
Include excerpts of the mnemonic text throughout the image.
".freeze

def join_with_condensed_blanks(arr, separator: "\n")
  collapsed =
    arr.chunk(&:empty?).flat_map do |is_blank, chunk|
      if is_blank
        # keep one "" only when there were 2+ in a row
        chunk.length.positive? ? [''] : []
      else
        chunk
      end
    end

  collapsed.join(separator)
end

def main(url)
  html = URI.open(url, 'User-Agent' => USER_AGENT).read
  doc  = Nokogiri::HTML(html)

  header = doc.css('.page-header').text.split.join(' ')
  radicals = doc.css('.subject-list__items').first.children.map(&:text).map { _1.split }.select { _1.length > 1 }
  meaning = doc.css('.subject-section--meaning').children.map { _1.text.strip }.map { join_with_condensed_blanks(_1.split("\n").map(&:strip), separator: "\n") }.select(&:present?)
  reading = doc.css('.subject-section--reading').children.map { _1.text.strip }.map { join_with_condensed_blanks(_1.split("\n").map(&:strip), separator: "\n") }.select(&:present?)

  "
#{PROMPT.gsub('the following kanji', "the #{header} kanji")}

#{header}

The kanji is composed of three radicals. Can you see where the radicals fit in the kanji?
#{radicals.join(' ')}

#{meaning.join("\n")}

#{reading.join("\n")}
"
end

def main_radical(url)
  html = URI.open(url, 'User-Agent' => USER_AGENT).read
  doc  = Nokogiri::HTML(html)

  header = doc.css('.page-header').text.split.join(' ')
  meaning = doc.css('.subject-section__subsection').children.map { _1.text.strip }.map { join_with_condensed_blanks(_1.split("\n").map(&:strip), separator: "\n") }.select(&:present?)

  "
#{PROMPT.gsub('the following kanji', "the #{header} kanji")}
#{header}
#{meaning.join("\n")}
"
end

if __FILE__ == $PROGRAM_NAME
  ARGV.first || 1

  levels = (1..60).to_a
  levels.each do |level|
    pp "Processing level #{level}"
    html = URI.open("https://www.wanikani.com/level/#{level}", 'User-Agent' => USER_AGENT).read
    doc  = Nokogiri::HTML(html)
    rows = []

    radical_urls = doc.css('.subject-character--radical').map { _1['href'] }
    radical_urls.each_with_index do |url, i|
      data = main_radical(url)
      rows.append(data)
      pp "Completed: #{i + 1}/#{radical_urls.size}"
    end

    urls = doc.css('.subject-character--kanji').map { _1['href'] }
    urls.each_with_index do |url, i|
      data = main(url)
      rows.append(data)
      pp "Completed: #{i + 1}/#{urls.size}"
    end

    # Write rows to txt file
    File.write("prompts_#{level}.txt", rows.join("\n------------------------------------------------------------------\n"))
  end
end
