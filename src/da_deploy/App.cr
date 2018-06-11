
module DA_Deploy

  struct App

    getter name   : String
    getter latest : String
    getter dir    : String

    def initialize(@name)
      @dir = "/deploy/apps/#{@name}"
      @latest = DA_Deploy.releases(@dir).pop
    end # === def initialize

    def latest?
      !!@latest
    end # === def latest?

    def releases
      DA_Deploy.releases(@dir)
    end

    {% for x in "Public sv".split %}
      def {{x.id.downcase}}_dir
        File.join(latest, {{x}})
      end # === def public_dir

      def {{x.id.downcase}}_dir?
        File.directory?({{x.id.downcase}}_dir)
      end # === def public_dir
    {% end %}


  end # === struct App
end # === module DA_Deploy
