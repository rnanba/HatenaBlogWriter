#!/usr/bin/env ruby
# coding: utf-8

require_relative './HatenaBlogWriter.rb'

hbw = HBW::Client.new

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
when 'post'
  abort 'USAGE: hbw.rb post _entry_filename_' unless ARGV[1]
  hbw.post(ARGV[1])
when 'update'
  abort 'USAGE: hbw.rb update _entry_filename_' unless ARGV[1]
  hbw.update(ARGV[1])
when nil
  abort "ERROR: 一括投稿・更新機能は未実装"
else
  abort "ERROR: 不正なサブコマンド: #{ARGV[0]}"
end
