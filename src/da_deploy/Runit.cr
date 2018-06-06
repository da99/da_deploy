
module DA_Deploy
  struct Runit

    def self.state(dir)
      `sv status #{dir}`.strip.split(':').first
    end # === def self.state

    getter dir : String
    getter pids : Array(Int32) = [] of Int32

    def initialize(raw_dir : String)
      if !File.directory?(raw_dir)
        DA.exit_with_error!("Not a directory: #{raw_dir.inspect}")
      end

      @dir = raw_dir
      if self.class.state(@dir) == "run"
        match = status.match(/\(pid (\d+)\)/)

        if match
          pid = match[1]
          @pids = `pstree -A -p #{pid}`.scan(/\((\d+)\)/).map(&.[1].to_i32)
        end
      end

    end # === def initialize(name : String)

    def status
      `sv status #{@dir}`.strip
    end

    def state
      self.class.state(dir)
    end # === def state

    {% for x in "run down exit".split %}
      def {{x.id}}?
        status.split(':').first == {{x}}
      end
    {% end %}

    def up!
      if !down?
        DA.exit_with_error!("Service is not in \"down\" state: #{dir} -> #{status}")
      end

      DA.system!("sv up #{dir}")
      10.times do |i|
        if !run?
          sleep 1
          next
        end
        break
      end

      if !run?
        DA.exit_with_error!("Service is not in \"up\" state: #{dir} -> #{status}")
      end
      Runit.new(dir).pids.each { |pid|
        puts pid
      }
    end

    def down!
      if !run?
        DA.exit_with_error!("Not running: #{dir}")
      end
      procs = pids
      STDERR.puts "PIDs: #{procs.join ' '}"
      DA.system!("sv down #{dir}")
      10.times do |i|
        if procs.any? { |id| Process.exists? id }
          sleep 1
        else
          return true
        end
      end
      STDERR.puts "!!! Processes for #{dir} still up: "
      procs.each { |x| STDERR.puts(x) if Process.exists?(x) }
      Process.exit 1
    end

  end # === struct Runit

  struct State

    getter raw : String
    getter state : String
    def initialize(@raw : String)
      @state = @raw.split(':').first
    end # === def initialize

    {% for x in "run down fail".split %}
      def {{x.id}}
        @state == {{x}}
      end
    {% end %}

  end # === struct State
end # === module DA_Deploy
