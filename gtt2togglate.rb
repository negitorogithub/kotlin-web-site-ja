#!/usr/bin/ruby
# Google Translate Toolkitの翻訳結果と、togglateの結果をがっちゃんこするスクリプト。
require 'csv'
require 'pp'
TOGGLATE_OUTPUT_FILE_NAME = 'packages.md.tmp'
GTT_OUTPUT_FILE_NAME = 'packages.txt'
SPREADSHEET_OUTPUT_FILE_NAME = 'output.csv'
OUTPUT_FILE_NAME = 'output.md'

# Google Translation Toolkitの出力を全て読み込みキャッシュする
def read_gtt(file_name)
  File.open(file_name, 'r') do |gtt|
    gtt.read.gsub("\r\n", "\n").split("\n\n").map do |t|
      t.sub(/^\n/, '').sub(/\n$/, '')
    end
  end
end

# togglateの結果のファイルを読み込んでキャッシュする
def read_togglate(file_name)
  File.open(file_name, 'r') { |f|
    f.read.split('[translation here]').map do |t|
      next if t.empty?
      t.sub("\n\n<!--original\n", '').sub("\n-->\n\n", '').sub(/<script.*<\/script>\n/m, '')
    end
  }.compact
end

# togglateの実行結果をキャッシュする
def exec_togglate(file_name)
  togglate_output = `bundle exec togglate create ./docs/reference/#{file_name}`
  togglate_output.split('[translation here]').map { |t|
    next if t.empty?
    t.sub("\n\n<!--original\n", '').sub("\n-->\n\n", '').sub(/<script.*<\/script>\n/m, '')
  }.compact
end

def get_array(gtt_output, togglate_output)
  gtt_output_index = 0
  arr = []
  togglate_output.map do |tog|
    if tog.index('---') == 0 || tog.index('```') == 0
      arr << [tog, tog]
      next
    end
    arr << [gtt_output[gtt_output_index], tog]
    gtt_output_index += 1
  end
  arr
end

def output_csv(gtt_output, togglate)
  gtt_output_index = 0
  CSV.open(SPREADSHEET_OUTPUT_FILE_NAME, 'w') do |csv|
    togglate.each do |tog|
      if tog.index('---') == 0 || tog.index('```') == 0
        csv << [tog, tog]
        next
      end
      csv << [gtt_output[gtt_output_index], tog]
      gtt_output_index += 1
    end
  end
end

def output_togglate(file_name, data)
  File.open(file_name, 'w') do |f|
    data.each do |row|
      f << row[0]
      f << "\n\n"
      f << "<!--original\n"
      f << row[1]
      f << "\n-->\n"
      f << "\n"
    end
    js = %q{<script src="http://code.jquery.com/jquery-1.11.0.min.js"></script>
<script>
$(function() {
  $("*").contents().filter(function() {
    return this.nodeType==8 && this.nodeValue.match(/^original/);
  }).each(function(i, e) {
    var tooltips = e.nodeValue.replace(/^original *[\n\r]|[\n\r]$/g, '');
    $(this).prev().attr('title', tooltips);
  });
});
</script>}
    f << js
  end
end

class String
  def to_kebab
    self.downcase.tr(' ', '-')
  end
end

pp gtt = read_gtt("#{ARGV[0]}.txt")
tog = exec_togglate("#{ARGV[0].to_kebab}.md")
output_togglate("#{ARGV[0].to_kebab}.md", get_array(gtt, tog))
