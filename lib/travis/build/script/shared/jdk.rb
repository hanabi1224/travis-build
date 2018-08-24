module Travis
  module Build
    class Script
      module Jdk

        include Template

        def configure
          super
          return unless uses_jdk?

          jdk = config[:jdk].gsub(/\s/,'')

          return if jdk == 'default'

          sh.raw(install_jdk(jdk), echo: true, timing: true, fold: 'install_jdk')
        end

        def export
          super
          sh.export 'TRAVIS_JDK_VERSION', config[:jdk], echo: false if uses_jdk?
        end

        def setup
          super

          sh.if '-f build.gradle || -f build.gradle.kts' do
            sh.export 'TERM', 'dumb'
          end

          sh.if '"$TRAVIS_DIST" == precise || "$TRAVIS_DIST" == trusty' do
            sh.echo "Disabling Gradle daemon", ansi: :yellow
            sh.cmd 'mkdir -p ~/.gradle && echo "org.gradle.daemon=false" >> ~/.gradle/gradle.properties', echo: true, timing: false
          end

        end

        def announce
          super
          if uses_java?
            sh.cmd 'java -Xmx32m -version'
            sh.cmd 'javac -J-Xmx32m -version'
          end
        end

        def cache_slug
          return super unless uses_jdk?
          super << '--jdk-' << config[:jdk].to_s
        end

        private

          def uses_java?
            true
          end

          def uses_jdk?
            !!config[:jdk]
          end

          def install_jdk(jdk)
            template('jdk.sh',
                     jdk: jdk,
                     jdk_glob: jdk_glob(jdk),
                     jinfo_file: jinfo_file(jdk),
                     app_host: app_host,
                     args: install_jdk_args(jdk),
                     cache_dir: cache_dir)
          end

          def jdk_glob(jdk)
            vendor, version = jdk_info(jdk)
            apt_glob = "/usr/lib/jvm/java-1.#{version}.*#{vendor}*"
            installjdk_glob = "/usr*/local/lib/jvm/#{jdk}"
            "#{apt_glob} #{installjdk_glob}"
          end

          def jdk_info(jdk)
            m = jdk.match(/(?<vendor>[a-z]+)-?(?<version>.+)?/)
            [ m[:vendor], m[:version] ]
          end

          def jinfo_file(jdk)
            vendor, version = jdk_info(jdk)
            if vendor == 'oracle'
              ".java-#{version}-#{vendor}.jinfo"
            elsif vendor == 'openjdk'
                ".java-1.#{version}.*-#{vendor}-*.jinfo"
            end
          end

          def install_jdk_args(jdk)
            vendor, version = jdk_info(jdk)
            if vendor.start_with? 'oracle'
              license = 'BCL'
            elsif vendor.start_with? 'openjdk'
              license = 'GPL'
            else
              return false
            end
            "--feature #{version} --license #{license}"
          end

          def cache_dir
            "$HOME/.cache/install-jdk"
          end
      end
    end
  end
end
