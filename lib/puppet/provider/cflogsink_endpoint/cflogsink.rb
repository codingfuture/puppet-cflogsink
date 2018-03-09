#
# Copyright 2018 (c) Andrey Galkin
#


begin
    require File.expand_path( '../../../../puppet_x/cf_system', __FILE__ )
rescue LoadError
    require File.expand_path( '../../../../../../cfsystem/lib/puppet_x/cf_system', __FILE__ )
end

Puppet::Type.type(:cflogsink_endpoint).provide(
    :cfprov,
    :parent => PuppetX::CfSystem::ProviderBase
) do
    desc "Provider for cflogsink_endpoint"
    
    commands :sudo => PuppetX::CfSystem::SUDO
    commands :systemctl => PuppetX::CfSystem::SYSTEMD_CTL
    commands :logstash_plugin => '/usr/share/logstash/bin/logstash-plugin'
        
    def self.get_config_index
        'cf90logsink'
    end

    def self.get_generator_version
        cf_system().makeVersion(__FILE__)
    end
    
    def self.check_exists(params)
        debug("check_exists: #{params}")
        begin
            systemctl(['status', "#{params[:service_name]}.service"])
        rescue => e
            warning(e)
            #warning(e.backtrace)
            false
        end
    end

    def self.on_config_change(newconf)
        debug('on_config_change')

        new_services = []

        newconf.each do |name, conf|
            new_services << conf[:service_name]

            begin
                self.send("create_logstash", conf)
            rescue => e
                warning(e)
                #warning(e.backtrace)
                err("Transition error in setup")
            end
        end
 
        begin
            cf_system.cleanupSystemD("cflogstash-", new_services)
        rescue => e
            warning(e)
            #warning(e.backtrace)
            err("Transition error in setup")
        end
    end

    def self.create_logstash(conf)
        debug('on_config_change')
        
        service_name = conf[:service_name]
        user = conf[:user]
        root_dir = conf[:root_dir]
        settings_tune = conf[:settings_tune]
        cflogsink_settings = settings_tune.fetch('cflogsink', {})
        logstash_tune = settings_tune.fetch('logstash', {})
        
        avail_mem = cf_system.getMemory(service_name)
        
        if PuppetX::CfSystem::Util.is_jvm_metaspace
            meta_mem = (avail_mem * 0.2).to_i
            meta_mem = cf_system.fitRange(128, avail_mem, meta_mem)
            meta_param = 'MetaspaceSize'
        else
            meta_mem = (avail_mem * 0.05).to_i
            meta_mem = cf_system.fitRange(128, avail_mem, meta_mem)
            meta_param = 'PermSize'
        end
        
        heap_mem = ((avail_mem - meta_mem) * 0.95).to_i
        
        conf_dir = "#{root_dir}/config"
        log4j2_file = "#{conf_dir}/log4j2.properties"
        jvmopt_file = "#{conf_dir}/jvm.options"
        
        need_restart = false

        #---
        port = cflogsink_settings['port']
        secure_port = cflogsink_settings['secure_port']
        control_port = cflogsink_settings['control_port']
        
        # Config File
        #==================================================
        plugin_state = logstash_plugin( 'list', '--verbose', '--installed' )
        plugin_state_file = "#{conf_dir}/plugin_state.txt"
        cf_system.atomicWrite(plugin_state_file, plugin_state, { :user => user })

        #---
        
        conf_file = "#{conf_dir}/logstash.yml"
        conf_settings = {
            'log.level' => 'info',
            'log.format' => 'plain',
        }
        conf_settings.merge! logstash_tune
        conf_settings.merge! ({
            'path.logs' => "#{root_dir}/logs",
            'path.data' => "#{root_dir}/data",
            #'path.config' => "#{conf_dir}/pipelines.yml",
            'http.host' => '127.0.0.1',
            'http.port' => control_port,
        })

        # write
        cf_system.atomicWrite(conf_file, conf_settings.to_yaml, { :user => user })

        #---
        log4j2 = [
            'status = error',
            'appender.console.type = Console',
            'appender.console.name = console',
            'appender.console.layout.type = PatternLayout',
            'appender.console.layout.pattern = %m%n',
            'rootLogger.level = info',
            'rootLogger.appenderRef.console.ref = console',
        ]
        cf_system.atomicWrite(log4j2_file, log4j2, { :user => user })

        #---
        jvmopt = [
            "-Xms#{heap_mem}m",
            "-Xmx#{heap_mem}m",
            "-XX:Max#{meta_param}=#{meta_mem}m",
            "-Dlog4j2.disable.jmx=true",
            '-XX:+UseParNewGC',
            '-XX:+UseConcMarkSweepGC',
            '-XX:CMSInitiatingOccupancyFraction=75',
            '-XX:+UseCMSInitiatingOccupancyOnly',

            '-XX:+DisableExplicitGC',

            "-Djava.io.tmpdir=#{root_dir}/tmp",
            '-Djava.awt.headless=true',
            '-Dfile.encoding=UTF-8',
            #'-XX:+HeapDumpOnOutOfMemoryError',
            '7:-XX:OnOutOfMemoryError="kill -9 %p"',
            '8:-XX:+ExitOnOutOfMemoryError',
        ]
        cf_system.atomicWrite(jvmopt_file, jvmopt, { :user => user })

        # Service File
        #==================================================
        start_timeout = 60

        content_ini = {
            'Unit' => {
                'Description' => "CF LogStash",
            },
            'Service' => {
                '# Package Version' => PuppetX::CfSystem::Util.get_package_version('logstash'),
                '# Config Version' => PuppetX::CfSystem.makeVersion(conf_dir),
                'ExecReload' => '/bin/kill -HUP $MAINPID',
                'ExecStart' => "/usr/share/logstash/bin/logstash --path.settings #{conf_dir} -f #{conf_dir}/pipeline.conf",
                'LimitNOFILE' => '16384',
                'ExecStartPost' => "#{PuppetX::CfSystem::WAIT_SOCKET_BIN} #{port} #{start_timeout}",
                'WorkingDirectory' => '/',
                'TimeoutStartSec' => "#{start_timeout}",
                'TimeoutStopSec' => "60",
                'EnvironmentFile' => "#{root_dir}/.env",
            },
        }
        
        content_env = {
            'CF_PORT' => port,
            'CF_SECURE_PORT' => secure_port,
            'CF_TLS_CACERT' => "#{root_dir}/pki/puppet/ca.crt",
            'CF_TLS_CERT' => "#{root_dir}/pki/puppet/local.crt",
            'CF_TLS_KEY' => "#{root_dir}/pki/puppet/local.key",
            'LS_HOME' => '/usr/share/logstash',
            'LS_JVM_OPTS' => "-Xms#{heap_mem}m -Xmx#{heap_mem}m -XX:Max#{meta_param}=#{meta_mem}m",
        }

        service_changed = self.cf_system().createService({
            :service_name => service_name,
            :user => user,
            :content_ini => content_ini,
            :content_env => content_env,
            :cpu_weight => conf[:cpu_weight],
            :io_weight => conf[:io_weight],
            :mem_limit => avail_mem,
            :mem_lock => true,
        })
        
        need_restart ||= service_changed

        #==================================================
        
        if need_restart
            warning(">> reloading #{service_name}")
            systemctl('restart', "#{service_name}.service")
        else
            systemctl('start', "#{service_name}.service")
        end        
    end
end
