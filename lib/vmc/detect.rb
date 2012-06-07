module VMC
  class Detector
    def initialize(client, path)
      @client = client
      @path = path
    end

    def all_frameworks
      info = @client.info
      info["frameworks"] || {}
    end

    def find_top(entries)
      found = false

      entries.each do |e|
        is_toplevel =
          e.ftype == :directory && e.name.index("/") + 1 == e.name.size

        if is_toplevel && e.name !~ /^(\.|__MACOSX)/
          if found
            return false
          else
            found = e.name
          end
        end
      end

      found
    end

    def frameworks
      info = @client.info

      matches = {}
      all_frameworks.each do |name, meta|
        matched = false

        # e.g. standalone has no detection
        next if meta["detection"].nil?

        meta["detection"].first.each do |file, match|
          files =
            if File.file? @path
              if File.fnmatch(file, @path)
                [@path]
              elsif @path =~ /\.(zip|jar|war)/
                lines = CFoundry::Zip.entry_lines(@path)
                top = find_top(lines)

                lines.collect(&:name).select do |path|
                  File.fnmatch(file, path) ||
                    top && File.fnmatch(top + file, path)
                end
              else
                []
              end
            else
              Dir.glob("#@path/#{file}")
            end

          unless files.empty?
            if match == true
              matched = true
            elsif match == false
              matched = false
              break
            else
              files.each do |f|
                contents = File.open(f, &:read)
                if contents =~ Regexp.new(match)
                  matched = true
                end
              end
            end
          end
        end

        if matched
          matches[name] = meta
        end
      end

      if matches.size == 1
        default = matches.keys.first
      end

      [matches, default]
    end
  end
end