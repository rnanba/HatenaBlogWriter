#!/usr/bin/env ruby
# coding: utf-8

VERSION = "0.2"

require_relative './HatenaBlogWriter.rb'

hbw = HBW::Client.new

def new_files_to_post(filenames=nil)
  unless filenames
    filenames = []
    Dir.foreach(".") { |filename|
      if /^(\d+-\d\d-\d\d_\d+).(txt|md)$/.match(filename)
        filenames.push(filename)
      end
    }
  end
  files = []
  filenames.each { |filename|
    unless File.exists?(HBW::EntryMetaData.data_filename(filename))
      files.push(filename)
    end
  }
  files
end

def modified_files_to_update()
  files = []
  Dir.foreach(HBW::DATA_DIR) { |filename|
    entry_filename = HBW::EntryMetaData.entry_filename(filename)
    if entry_filename
      data = HBW::EntryMetaData.new(entry_filename)
      if data.mtime < File.mtime(entry_filename) 
        files.push(entry_filename)
      end
    end
  }
  files
end

case ARGV[0]
when 'new'
  if ARGV[1]
    ef = HBW::EntryFile.new(ARGV[1])
    ef.save()
    puts "OK: エントリファイルを作成しました。"
  else
    base_filename = Time.now.strftime("%04Y-%02m-%02d")
    for i in 1..99
      filename = sprintf("#{base_filename}_%02d.txt", i)
      unless File.exists?(filename)
        ef = HBW::EntryFile.new(filename)
        ef.save()
        puts "OK: エントリファイル '#{filename}' を作成しました。"
        exit
      end
    end
    abort "ERROR: ファイル名を生成できませんでした。エントリファイル作成を中止しました。"
  end
when 'debug'
  abort 'USAGE: hbw.rb debug _entry_filename_' unless ARGV[1]
  ef = HBW::EntryFile.new(ARGV[1])
  p ef.entry.to_s
  p "sha1: #{ef.sha1}"
when 'post'
  abort 'USAGE: hbw.rb post _entry_filename_' unless ARGV[1]
  hbw.post(ARGV[1])
when 'update'
  abort 'USAGE: hbw.rb update _entry_filename_' unless ARGV[1]
  hbw.update(ARGV[1])
when 'version'
  puts "HatenaBlogWriter v#{VERSION}"
when nil, 'check'
  check = (ARGV[0] == 'check')
  files = new_files_to_post()
  if files.size > 0
    puts "新規エントリファイルが #{files.size} 件あります。"
    files.each {|f|
      if check 
        puts f
      else
        hbw.post(f)
      end
    }
  else
    puts "新規エントリファイルはありません。"
  end
  files = modified_files_to_update()
  if files.size > 0
    puts "修正されたエントリファイルが #{files.size} 件あります。"
    files.each {|f|
      if check
        puts f
      else
        hbw.update(f)
      end
    }
  else
    puts "修正されたエントリファイルはありません。"
  end
else
  abort "ERROR: 不正なサブコマンド: #{ARGV[0]}"
end
