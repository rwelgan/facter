# Fact: domain
#
# Purpose:
#   Return the host's primary DNS domain name.
#
# Resolution:
#   On UNIX (excluding Darwin), first try and use the hostname fact,
#   which uses the hostname system command, and then parse the output
#   of that.
#   Failing that it tries the dnsdomainname system command.
#   Failing that it uses /etc/resolv.conf and takes the domain from that, or as
#   a final resort, the search from that.
#   Otherwise returns nil.
#
#   On Windows uses the win32ole gem and winmgmts to get the DNSDomain value
#   from the Win32 networking stack.
#
# Caveats:
#

Facter.add(:domain) do
  setcode do
    # Get the domain from various sources; the order of these
    # steps is important

    # In some OS 'hostname -f' will change the hostname to '-f'
    # We know that Solaris and HP-UX exhibit this behavior
    # On good OS, 'hostname -f' will return the FQDN which is preferable
    # Due to dangerous behavior of 'hostname -f' on old OS, we will explicitly opt-in
    # 'hostname -f' --hkenney May 9, 2012
    basic_hostname = 'hostname 2> /dev/null'
    windows_hostname = 'hostname > NUL'
    full_hostname = 'hostname -f 2> /dev/null'
    can_do_hostname_f = Regexp.union /Linux/i, /FreeBSD/i, /Darwin/i

    hostname_command = if Facter.value(:kernel) =~ can_do_hostname_f
                         full_hostname
                       elsif Facter.value(:kernel) == "windows"
                         windows_hostname
                       else
                         basic_hostname
                       end

    if name = Facter::Util::Resolution.exec(hostname_command) \
      and name =~ /.*?\.(.+$)/

      return_value = $1
    elsif Facter.value(:kernel) != "windows" and domain = Facter::Util::Resolution.exec('dnsdomainname 2> /dev/null') \
      and domain =~ /.+/

      return_value = domain
    elsif FileTest.exists?("/etc/resolv.conf")
      domain = nil
      search = nil
      File.open("/etc/resolv.conf") { |file|
        file.each { |line|
          if line =~ /^\s*domain\s+(\S+)/
            domain = $1
          elsif line =~ /^\s*search\s+(\S+)/
            search = $1
          end
        }
      }
      return_value ||= domain
      return_value ||= search
    end
    return_value = '' if return_value.nil?
    return_value.gsub(/\.$/, '')
  end
end

Facter.add(:domain) do
  confine :kernel => :windows
  setcode do
    require 'facter/util/registry'
    domain = ""
    regvalue = Facter::Util::Registry.hklm_read('SYSTEM\CurrentControlSet\Services\Tcpip\Parameters', 'Domain')
    domain = regvalue if regvalue
    if domain == ""
      require 'facter/util/wmi'
      Facter::Util::WMI.execquery("select DNSDomain from Win32_NetworkAdapterConfiguration where IPEnabled = True").each { |nic|
        domain = nic.DNSDomain
        break
      }
    end

    domain ||= ''

    domain.gsub(/\.$/, '')
  end
end
