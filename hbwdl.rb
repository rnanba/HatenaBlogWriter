#!/usr/bin/env ruby
# coding: utf-8
require_relative './HatenaBlogWriter.rb'
require_relative './HatenaBlogDownloader.rb'

ENTRY_COUNT_LIMIT = ARGV.length == 0 ? 5 : ARGV[0].to_i

def load_db
  db = {}
  HBW::EntryMetaData.listData().each() { |data|
    db[data.location] = data
  }
  return db
end

def update_entry(data_file, entry_file, time_edited)
  entry_filename = data_file.entry_filename
  i = 0
  loop do
    i += 1
    filename = sprintf("#{entry_filename}.%d", i)
    next if File.exists?(filename)
    File.rename(entry_filename, filename)
    break
  end
  entry_file.save_as(entry_filename)
  puts "OK: #{entry_filename}: エントリファイルを更新しました。"
  data_file.set_updated(time_edited, entry_file.sha1)
  data_file.save()
end

def save_new_entry(entry_file, time_edited, location, url)
  base_filename = entry_file.date.strftime("%04Y-%02m-%02d")
  i = 0
  loop do
    i += 1
    filename = sprintf("#{base_filename}_%02d.txt", i)
    next if File.exists?(filename)
    entry_file.save_as(filename)
    puts "OK: #{filename}: エントリファイルを作成しました。"
    data_file = HBW::EntryMetaData.new(filename)
    data_file.set_posted(location, time_edited, entry_file.sha1)
    data_file.set_url(url)
    data_file.save()
    break
  end
end

def update_data(data_file, entry, entry_file)
  data_file.set_updated(Time.parse(entry.edited.text), entry_file.sha1)
  data_file.save
end

loader = HBW::FeedLoader.new()
db = load_db()
entry_count = 0
rnd = Random.new
loader.each_feed { |feed|
  sleep(0.5 + rnd.rand(0.5)) if entry_count > 0
  break if ENTRY_COUNT_LIMIT > 0 && ENTRY_COUNT_LIMIT <= entry_count
  feed.entries.each { |entry|
    break if ENTRY_COUNT_LIMIT >0 && ENTRY_COUNT_LIMIT <= entry_count
    entry_count += 1
    
    puts "---"
    puts "title: " + entry.title
    url = nil
    edit = nil
    entry.links.each { |link|
      if link.rel == "edit"
        edit = link.href
      elsif link.rel == "alternate"
        url = link.href
      end
    }
    entry_file = HBW::EntryFile.new(entry)
    time_edited = Time.parse(entry.edited.text)
    sha1 = entry_file.sha1()
    puts "URL: " + url
    puts "sha1: " + sha1
    data = db[edit]
    if data != nil then
      puts "既存のエントリです: " + data.entry_filename
      if data.sha1 == sha1 then
        puts "変更はありません。"
      else
        local_entry_file = HBW::EntryFile.new(data.entry_filename)
        if local_entry_file.date == nil then
          dateless_entry_file = HBW::EntryFile.new
          dateless_entry_file.parse_entry(entry, true)
          sha1 = dateless_entry_file.sha1()
          if data.sha1 == sha1 then
            puts "変更はありません。(date ヘッダなしのエントリ)"
            next
          end
        end
        puts "変更があります。"
        if data.mtime < File.mtime(data.entry_filename) then
          puts "警告: エントリファイルは投稿後に更新されています。"
        end
        puts "エントリファイルをリモートの内容で更新しますか? (yes/No)"
        if gets.chomp == 'yes'
          data.set_url(url)
          update_entry(data, entry_file, time_edited)
        end
      end
    else
      puts "新規エントリです。"
      save_new_entry(entry_file, time_edited, edit, url)
    end
  }
}
