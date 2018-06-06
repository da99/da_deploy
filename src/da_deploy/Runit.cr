
module DA_Deploy
  struct Runit

    # =============================================================================
    # Class:
    # =============================================================================

    def self.status(service_link)
      `sudo sv status #{service_link}`.strip
    end # === def self.state

    # =============================================================================
    # Instance:
    # =============================================================================

    getter pids         : Array(Int32) = [] of Int32
    getter name         : String
    getter service_link : String

    def initialize(@service_link)
      @name = File.basename(@service_link)

      status = self.class.status(@service_link)
      is_running = status.split(':').first == "run"

      if is_running && status["(pid "]?
        status.scan(/\(pid (\d+)\)/).map(&.[1].to_i32).each { |pid|
          @pids.concat `pstree -A -p #{pid}`.scan(/\((\d+)\)/).map(&.[1].to_i32)
        }
      end

    end # === def initialize(name : String)

    def installed?
      File.exists?(@service_link)
    end # === def installed?

    def install!
      DA.system!("sudo ln -s #{dir}/sv #{@service_link}")
    end # === def install!

    {% for x in "run down exit".split %}
      def {{x.id}}?
        status == {{x}}
      end
    {% end %}

    def status
      self.class.status(service_link).split(':').first
    end # === def status

    def up!
      if !down?
        DA.exit_with_error!("Service is not in \"down\" state: #{service_link} -> #{status}")
      end

      DA.system!("sudo sv up #{service_link}")
      10.times do |i|
        if !run?
          sleep 1
          next
        end
        break
      end

      if !run?
        DA.exit_with_error!("Service is not in \"up\" state: #{service_link} -> #{status}")
      end
      Runit.new(service_link).pids.each { |pid|
        puts pid
      }
    end

    def down!
      if !run?
        DA.exit_with_error!("Not running: #{service_link}")
      end
      procs = pids

      STDERR.puts "PIDs: #{procs.join ' '}"

      DA.system!("sudo sv down #{service_link}")
      DA.system!("sudo sv down #{service_link}/log")
      10.times do |i|
        if any_pids_up?
          sleep 1
        else
          return true
        end
      end
      Dir.cd(service_link) {
        File.write("sv.pids.txt", procs.join('\n'), 'a')
      }
      STDERR.puts "!!! Processes for #{service_link} still up: "
      procs.each { |x| STDERR.puts(x) if Process.exists?(x) }
      Process.exit 1
    end

    def wait_pids
      max = 10
      counter = 0
      while counter < 10
        break unless any_pids_up?
        counter += 1
        sleep 1
      end
      max < 10
    end # === def wait_pids

    def pids_up
      pids.select { |x| Process.exists?(x) }
    end

    def any_pids_up?
      pids_up.empty?
    end # === def any_pids_up?

  end # === struct Runit

end # === module DA_Deploy
