# coding: utf-8
# HBW::Client
# coding: utf-8

require 'atomutil'
require 'yaml'

module Atom
  class Content
    def new_body=(value)
      @elem.add_text(value.chomp)
    end
    alias_method :old_body=, :body=
    alias_method :body=, :new_body=
  end
end

module HBW
  class EntryFile
    attr_accessor :location
    
    def initialize(filename)
      @filename = filename
      @header = {
        title: "",
        category: [],
        draft: 'no',
      }
      @content = ""
      @location = nil
      if File.exists?(filename)
        @header[:date] = File.mtime(filename)
        parse_file()
      else
        @header[:date] = Time.now
      end
    end
    
    def parse_file
      in_header = true
      content_lines = []
      File.open(@filename, "r").each_line { |line|
        line = line.chomp
        if in_header 
          m = /^(?<key>\w+):\s*(?<value>.*)$/.match(line)
          if m == nil
            in_header = false
            content_lines.push(line)
            next
          end
          key = m[:key].to_sym
          value = m[:value]
          if key 
            if key == :date
              value = Time.parse(value)
            elsif key == :category
              value = value.split(',')
            end
            if @header[key] != nil
              @header[key] = value
            else
              abort "ERROR: 不正なヘッダ属性: '#{key}'"
            end
          else
            in_header = false
          end
        else
          content_lines.push(line)
        end
      }
      first = content_lines.index {|line| line != ""}
      last = content_lines.rindex {|line| line != ""}
      if last && /^location:\s*(.+)$/.match(content_lines[last])
        @location = $1
        content_lines.pop(content_lines.size - last)
        last = content_lines.rindex {|line| line != ""}
      end
      if first && last
        content_lines = content_lines[first..last]
        @content = content_lines.join("\n")
      end
    end
    
    def entry
      entry = Atom::Entry.new
      entry.title = @header[:title]
      entry.updated = @header[:date]
      @header[:category].each { |cat|
        entry.add_category(Atom::Category.new(term: cat.strip()))
      }
      entry.content = @content
      entry.add_control(Atom::Control.new(draft: @header[:draft]))
      return entry
    end

    def set_posted(location)
      raise "don't mark entry as posted twice." if @location
      @location = location
      File.open(@filename, "a") { |f|
        f.puts
        f.puts("location: #{location}")
      }
    end

    def save
      save_as(@filename)
    end
    
    def save_as(filename)
      if File.exists?(filename)
        abort "ERROR: ファイルが存在します。"
      end
      File.open(filename, "w") { |f|
        f.puts("title: #{@header[:title]}")
        f.puts("date: #{@header[:date]}")
        f.puts("category: #{@header[:category].join(', ')}")
        f.puts("draft: #{@header[:draft]}")
        f.puts()
        f.puts(@contents)
        if @location
          f.puts(@location)
        end
      }
    end
  end
  
  class Client
    def initialize
      config = YAML.load_file("config.yml")
      @id = config['id']
      @blog_domain = config['blog_domain']
      @post_uri = "https://blog.hatena.ne.jp/#{@id}/#{@blog_domain}/atom/entry"
      auth = Atompub::Auth::Wsse.new(username: @id,
                                     password: config['api_key'])
      @client = Atompub::Client.new(auth: auth)
      @service_uri = "https://blog.hatena.ne.jp/#{@id}/#{@blog_domain}/atom"
      @service = nil
    end

    def ensure_get_service(reload=false)
      if reload || @service == nil
        @service = @client.get_service(@service_uri)
      end
    end
    
    def set_username(entry)
      author = Atom::Author.new
      author.name = @id
      entry.author = author
    end
    
    def post(filename)
      entry_file = EntryFile.new(filename)
      entry = entry_file.entry
      if entry_file.location
        abort "ERROR: 投稿済のエントリファイルです。投稿を中止しました。"
      end
      set_username(entry)
      ensure_get_service()
      location = @client.create_entry(@post_uri, entry);
      puts "OK: エントリを投稿しました。"
      entry_file.set_posted(location)
      puts "OK: エントリファイルを投稿済にマークしました。"
    end

    def update(filename)
      entry_file = EntryFile.new(filename)
      entry = entry_file.entry
      unless entry_file.location
        abort "ERROR: 未投稿のエントリファイルです。更新を中止しました。"
      end
      set_username(entry)
      ensure_get_service()
      @client.update_entry(entry_file.location, entry);
      puts "OK: エントリを更新しました。"
    end
  end
end
